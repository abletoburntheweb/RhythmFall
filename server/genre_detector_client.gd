# server/genre_detector_client.gd
class_name GenreDetectionClient
extends Node

signal genres_detection_started
signal genres_detection_completed(artist: String, title: String, genres: Array)
signal genres_detection_error(error_message: String)

var http_thread: Thread
var is_detecting: bool = false
var _thread_request_data: Dictionary = {}
var _thread_result: Dictionary = {}
var _thread_finished: bool = false

func _set_is_detecting(value: bool):
	is_detecting = value

func get_genres_for_manual_entry(artist: String, title: String):
	if is_detecting:
		print("GenreDetectionClient.gd: Определение жанров уже выполняется, игнорируем новый запрос.")
		return

	_set_is_detecting(true)
	emit_signal("genres_detection_started")

	_thread_request_data = {
		"artist": artist,
		"title": title
	}
	_thread_result = {}
	_thread_finished = false

	http_thread = Thread.new()
	var thread_error = http_thread.start(func(): _thread_function(_thread_request_data.duplicate()))
	if thread_error != OK:
		print("GenreDetectionClient.gd: Ошибка запуска потока: ", thread_error)
		_set_is_detecting(false)
		emit_signal("genres_detection_error", "Ошибка запуска потока.")
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
			_set_is_detecting(false)
			var error_msg = _thread_result.error
			print("GenreDetectionClient.gd: Ошибка от сервера: ", error_msg)
			emit_signal("genres_detection_error", error_msg)
		elif _thread_result.has("genres"):
			_set_is_detecting(false)
			var received_artist = _thread_result.artist
			var received_title = _thread_result.title
			var received_genres = _thread_result.genres
			print("GenreDetectionClient.gd: Жанры получены для '%s - %s': %s" % [received_artist, received_title, received_genres])
			emit_signal("genres_detection_completed", received_artist, received_title, received_genres)
		else:
			_set_is_detecting(false)
			print("GenreDetectionClient.gd: Неожиданный формат ответа от сервера: ", _thread_result)
			emit_signal("genres_detection_error", "Неизвестная ошибка в потоке.")

func _thread_function(data_dict: Dictionary):
	var local_result = {}
	var local_error_occurred = false
	var local_error_msg = ""

	var artist = data_dict.get("artist", "").strip_edges()
	var title = data_dict.get("title", "").strip_edges()

	if artist == "" or title == "":
		local_error_occurred = true
		local_error_msg = "Пустое поле исполнителя или названия."
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
			var request_data = {
				"artist": artist,
				"title": title
			}
			var json_obj = JSON.new()
			var json_string = json_obj.stringify(request_data)
			var request_body = json_string.to_utf8_buffer()

			var headers = PackedStringArray([
				"Host: localhost:5000",
				"Content-Type: application/json",
				"Content-Length: " + str(request_body.size())
			])

			http_client.request_raw(HTTPClient.METHOD_POST, "/get_genres_manual", headers, request_body)
			http_client.poll()

			while http_client.get_status() == HTTPClient.STATUS_REQUESTING:
				http_client.poll()
				OS.delay_msec(100)

			var response_code = http_client.get_response_code()
			print("GenreDetectionClient.gd (Thread): Код ответа от сервера /get_genres_manual: ", response_code)

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
					print("GenreDetectionClient.gd (Thread): Тело ответа от сервера: ", response_text)

					var response_json = JSON.parse_string(response_text)
					if response_json:
						if response_json.has("genres"):
							var genres = response_json["genres"]
							var received_artist = response_json.get("artist", artist)
							var received_title = response_json.get("title", title)
							print("GenreDetectionClient.gd (Thread): Получено жанров: ", genres.size(), " - ", genres)
							local_result = {
								"genres": genres,
								"artist": received_artist,
								"title": received_title
							}
						elif response_json.has("error"):
							local_error_msg = response_json["error"]
							print("GenreDetectionClient.gd (Thread): Ошибка от сервера: ", local_error_msg)
							local_error_occurred = true
						else:
							local_error_msg = "Ответ не содержит ожидаемые поля: genres"
							print("GenreDetectionClient.gd (Thread): Неполный ответ от сервера: ", response_json)
							local_error_occurred = true
					else:
						local_error_msg = "Ответ не является валидным JSON"
						print("GenreDetectionClient.gd (Thread): Ответ не является JSON: ", response_text)
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
