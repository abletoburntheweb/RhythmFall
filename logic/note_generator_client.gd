# logic/note_generator_client.gd
class_name NoteGeneratorClient
extends Node

signal notes_generation_started
signal notes_generation_completed(notes_data: Array, bpm_value: float, instrument_type: String)
signal notes_generation_error(error_message: String)

var http_thread: Thread
var is_generating: bool = false
var _thread_request_data: Dictionary = {}
var _thread_result: Dictionary = {}
var _thread_finished: bool = false

func _set_is_generating(value: bool):
	is_generating = value

func generate_notes(song_path: String, instrument_type: String, bpm: float):
	if is_generating:
		print("NoteGeneratorClient.gd: Генерация уже выполняется, игнорируем новый запрос.")
		return

	_set_is_generating(true)
	emit_signal("notes_generation_started")

	_thread_request_data = {
		"song_path": song_path,
		"instrument_type": instrument_type,
		"bpm": bpm
	}
	_thread_result = {}
	_thread_finished = false

	http_thread = Thread.new()
	var thread_error = http_thread.start(func(): _thread_function(_thread_request_data.duplicate()))
	if thread_error != OK:
		print("NoteGeneratorClient.gd: Ошибка запуска потока: ", thread_error)
		_set_is_generating(false)
		emit_signal("notes_generation_error", "Ошибка запуска потока.")
		return

	call_deferred("_start_checking_thread_status")

func _start_checking_thread_status():
	var timer = Timer.new()
	timer.wait_time = 0.1
	timer.timeout.connect(_check_thread_status)
	add_child(timer)
	timer.start()

func _check_thread_status():
	if _thread_finished:
		var timer = get_child(get_child_count() - 1)
		if timer and timer is Timer:
			timer.stop()
			timer.queue_free()

		if http_thread:
			http_thread.wait_to_finish()
			http_thread = null

		if _thread_result.has("error"):
			_set_is_generating(false)
			emit_signal("notes_generation_error", _thread_result.error)
		elif _thread_result.has("notes"):
			_set_is_generating(false)
			emit_signal("notes_generation_completed", _thread_result.notes, _thread_result.bpm, _thread_result.instrument_type)
		else:
			_set_is_generating(false)
			emit_signal("notes_generation_error", "Неизвестная ошибка в потоке.")

func _thread_function(data_dict: Dictionary):
	var local_result = {}
	var local_error_occurred = false
	var local_error_msg = ""

	var song_path = data_dict.get("song_path", "")
	var instrument_type = data_dict.get("instrument_type", "standard")
	var bpm = data_dict.get("bpm", -1.0)

	if song_path == "":
		local_error_occurred = true
		local_error_msg = "Пустой путь к файлу."
		local_result = {"error": local_error_msg}
		_thread_result = local_result
		_thread_finished = true
		return

	var http_client = HTTPClient.new()
	var error = http_client.connect_to_host("localhost", 5000)
	if error != OK:
		local_error_occurred = true
		local_error_msg = "Не удалось подключиться к серверу: " + str(error)
	else:
		while http_client.get_status() == HTTPClient.STATUS_CONNECTING or http_client.get_status() == HTTPClient.STATUS_RESOLVING:
			http_client.poll()
			OS.delay_msec(100)

		if http_client.get_status() != HTTPClient.STATUS_CONNECTED:
			local_error_occurred = true
			local_error_msg = "Не удалось подключиться к серверу. Статус: " + str(http_client.get_status())
		else:
			var file_access = FileAccess.open(song_path, FileAccess.READ)
			if not file_access:
				local_error_occurred = true
				local_error_msg = "Не удалось открыть файл для чтения: " + song_path
			else:
				var file_data = file_access.get_buffer(file_access.get_length())
				file_access.close()

				# Создаём multipart тело
				var boundary = "----WebKitFormBoundary" + str(Time.get_ticks_msec())
				var body = PackedByteArray()
				
				# Добавляем параметры
				body.append_array(_build_form_field("bpm", str(bpm), boundary))
				body.append_array(_build_form_field("instrument", instrument_type, boundary))
				
				# Добавляем аудиофайл
				body.append_array(_build_file_field(file_data, song_path.get_file(), boundary))

				# Завершаем multipart
				body.append_array(("\r\n--%s--\r\n" % boundary).to_utf8_buffer())

				var headers = PackedStringArray([
					"Host: localhost:5000",
					"Content-Type: multipart/form-data; boundary=" + boundary,
					"Content-Length: " + str(body.size())
				])

				var request_method = HTTPClient.METHOD_POST
				var request_url = "/generate_drums" if instrument_type == "drums" else "/generate_notes"
				if instrument_type != "drums":
					request_url = "/generate_notes"  # если будет другой endpoint для других инструментов
					
				http_client.request_raw(request_method, request_url, headers, body)
				http_client.poll()

				while http_client.get_status() == HTTPClient.STATUS_REQUESTING:
					http_client.poll()
					OS.delay_msec(100)

				var response_code = http_client.get_response_code()
				print("NoteGeneratorClient.gd (Thread): Код ответа от сервера: ", response_code)

				if response_code == 200:
					if http_client.get_status() == HTTPClient.STATUS_BODY or http_client.get_status() == HTTPClient.STATUS_CONNECTED:
						var response_body_bytes = PackedByteArray()
						while http_client.get_status() == HTTPClient.STATUS_BODY:
							var chunk = http_client.read_response_body_chunk()
							if chunk.size() == 0:
								break
							response_body_bytes.append_array(chunk)
							http_client.poll()

						var response_text = response_body_bytes.get_string_from_utf8()
						print("NoteGeneratorClient.gd (Thread): Тело ответа от сервера: ", response_text)

						var response_json = JSON.parse_string(response_text)
						if response_json and response_json.has("notes") and response_json.has("bpm"):
							var notes = response_json["notes"]
							var received_bpm = response_json["bpm"]
							var received_instrument = response_json.get("instrument_type", instrument_type)
							print("NoteGeneratorClient.gd (Thread): Получено нот: ", notes.size(), ", BPM: ", received_bpm)
							local_result = {
								"notes": notes, 
								"bpm": received_bpm, 
								"instrument_type": received_instrument
							}
						else:
							local_error_msg = response_json.get("error", "Неизвестная ошибка") if response_json else "Ответ не содержит ожидаемые поля"
							print("NoteGeneratorClient.gd (Thread): Ошибка от сервера: ", local_error_msg)
							local_error_occurred = true
					else:
						local_error_msg = "Неожиданный статус HTTPClient после успешного ответа: " + str(http_client.get_status())
						local_error_occurred = true
				else:
					var error_body = PackedByteArray()
					while http_client.get_status() == HTTPClient.STATUS_BODY:
						var chunk = http_client.read_response_body_chunk()
						if chunk.size() == 0:
							break
						error_body.append_array(chunk)
						http_client.poll()
					var error_text = error_body.get_string_from_utf8()
					local_error_msg = "Сервер вернул ошибку: " + str(response_code) + ". " + error_text
					local_error_occurred = true

	http_client.close()

	if local_error_occurred:
		_thread_result = {"error": local_error_msg}
	else:
		_thread_result = local_result

	_thread_finished = true

func _build_form_field(field_name: String, field_value: String, boundary: String) -> PackedByteArray:
	var body = PackedByteArray()
	var header = ("--%s\r\n" +
				  "Content-Disposition: form-data; name=\"%s\"\r\n" +
				  "Content-Type: text/plain\r\n\r\n") % [boundary, field_name]
	body.append_array(header.to_utf8_buffer())
	body.append_array(field_value.to_utf8_buffer())
	return body

func _build_file_field(file_data: PackedByteArray, filename: String, boundary: String) -> PackedByteArray:
	var body = PackedByteArray()
	var header = ("--%s\r\n" +
				  "Content-Disposition: form-data; name=\"audio_file\"; filename=\"%s\"\r\n" +
				  "Content-Type: application/octet-stream\r\n\r\n") % [boundary, filename]
	body.append_array(header.to_utf8_buffer())
	body.append_array(file_data)
	return body
