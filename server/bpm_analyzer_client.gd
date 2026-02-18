# logic/bpm_analyzer_client.gd
class_name BPMAnalyzerClient
extends Node

signal bpm_analysis_started
signal bpm_analysis_completed(bpm_value: int)
signal bpm_analysis_error(error_message: String)

var http_thread: Thread
var is_analyzing: bool = false 
var _thread_request_data: Dictionary = {}
var _thread_result: Dictionary = {} 
var _thread_finished: bool = false 
var _cancel_requested: bool = false

func _set_is_analyzing(value: bool):
	is_analyzing = value

func analyze_bpm(song_path: String):
	if is_analyzing:
		print("BPMAnalyzerClient.gd: Анализ уже выполняется, игнорируем новый запрос.")
		return

	_set_is_analyzing(true)
	_cancel_requested = false
	emit_signal("bpm_analysis_started")

	_thread_request_data = { "song_path": song_path }
	_thread_result = {}
	_thread_finished = false

	http_thread = Thread.new()
	var thread_error = http_thread.start(func(): _thread_function(_thread_request_data.duplicate()))
	if thread_error != OK:
		print("BPMAnalyzerClient.gd: Ошибка запуска потока: ", thread_error)
		_set_is_analyzing(false)
		emit_signal("bpm_analysis_error", "Ошибка запуска потока.")
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
			_set_is_analyzing(false)
			emit_signal("bpm_analysis_error", _thread_result.error)
		elif _thread_result.has("bpm"):
			_set_is_analyzing(false)
			emit_signal("bpm_analysis_completed", _thread_result.bpm)
		else:
			_set_is_analyzing(false)
			emit_signal("bpm_analysis_error", "Неизвестная ошибка в потоке.")

func _thread_function(data_dict: Dictionary):
	var local_result = {}
	var local_error_occurred = false
	var local_error_msg = ""

	var song_path = data_dict.get("song_path", "")
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
			if _cancel_requested:
				_thread_result = {"error": "Операция отменена пользователем"}
				http_client.close()
				_thread_finished = true
				return

		if http_client.get_status() != HTTPClient.STATUS_CONNECTED:
			local_error_occurred = true
			local_error_msg = "Не удалось подключиться к серверу BPM. Статус: " + str(http_client.get_status())
		else:
			var file_access = FileAccess.open(song_path, FileAccess.READ)
			if not file_access:
				local_error_occurred = true
				local_error_msg = "Не удалось открыть файл для чтения: " + song_path
			else: 
				var file_data = file_access.get_buffer(file_access.get_length())
				file_access.close()

				var boundary = "----WebKitFormBoundary" + str(Time.get_ticks_msec())
				var body = PackedByteArray()
				body.append_array(_build_multipart_body(file_data, song_path.get_file(), boundary))

				var headers = PackedStringArray([
					"Host: localhost:5000",
					"Content-Type: multipart/form-data; boundary=" + boundary,
					"Content-Length: " + str(body.size())
				])

				var request_method = HTTPClient.METHOD_POST
				var request_url = "/analyze_bpm"
				http_client.request_raw(request_method, request_url, headers, body)
				http_client.poll()

				while http_client.get_status() == HTTPClient.STATUS_REQUESTING:
					http_client.poll()
					OS.delay_msec(100)
					if _cancel_requested:
						_thread_result = {"error": "Операция отменена пользователем"}
						http_client.close()
						_thread_finished = true
						return

				var response_code = http_client.get_response_code()
				print("BPMAnalyzerClient.gd (Thread): Код ответа от сервера: ", response_code)

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
						print("BPMAnalyzerClient.gd (Thread): Тело ответа от сервера: ", response_text)

						var response_json = JSON.parse_string(response_text)
						if response_json and response_json.has("bpm"):
							var calculated_bpm = response_json["bpm"]
							print("BPMAnalyzerClient.gd (Thread): Получен BPM: ", calculated_bpm)
							local_result = {"bpm": calculated_bpm}
						else:
							local_error_msg = response_json.get("error", "Неизвестная ошибка") if response_json else "Ответ не является JSON"
							print("BPMAnalyzerClient.gd (Thread): Ошибка от сервера BPM: ", local_error_msg)
							local_error_occurred = true
					else:
						local_error_msg = "Неожиданный статус HTTPClient после успешного ответа: " + str(http_client.get_status())
						local_error_occurred = true
				else:
					local_error_msg = "Сервер вернул ошибку: " + str(response_code)
					local_error_occurred = true

	http_client.close()

	if local_error_occurred:
		_thread_result = {"error": local_error_msg}
	else:
		_thread_result = local_result

	_thread_finished = true 

func _on_analysis_error(message: String):
	_set_is_analyzing(false)
	emit_signal("bpm_analysis_error", message)

func _build_multipart_body(file_data: PackedByteArray, filename: String, boundary: String) -> PackedByteArray:
	var body = PackedByteArray()
	var header = ("--%s\r\n" +
				  "Content-Disposition: form-data; name=\"audio_file\"; filename=\"%s\"\r\n" +
				  "Content-Type: application/octet-stream\r\n\r\n") % [boundary, filename]
	body.append_array(header.to_utf8_buffer())
	body.append_array(file_data) 
	body.append_array(("\r\n--%s--\r\n" % boundary).to_utf8_buffer())
	return body

func request_cancel():
	if is_analyzing:
		_cancel_requested = true
