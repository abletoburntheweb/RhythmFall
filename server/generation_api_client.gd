extends Node
class_name GenerationApiClient

signal bpm_started
signal bpm_completed(bpm_value: int)
signal bpm_error(error_message: String)

signal genres_started
signal genres_completed(artist: String, title: String, genres: Array)
signal genres_error(error_message: String)

signal notes_started
signal notes_completed(notes_data: Array, bpm_value: float, instrument_type: String)
signal notes_error(error_message: String)
signal bpm_status(status: String)
signal genres_status(status: String)
signal notes_status(status: String)

var _bpm_thread: Thread = null
var _genres_thread: Thread = null
var _notes_thread: Thread = null

var _bpm_req: Dictionary = {}
var _genres_req: Dictionary = {}
var _notes_req: Dictionary = {}

var _bpm_res: Dictionary = {}
var _genres_res: Dictionary = {}
var _notes_res: Dictionary = {}
var _bpm_status_queue: Array = []
var _genres_status_queue: Array = []
var _notes_status_queue: Array = []

var _bpm_done: bool = false
var _genres_done: bool = false
var _notes_done: bool = false

var _cancel_bpm: bool = false
var _cancel_notes: bool = false

func analyze_bpm(song_path: String):
	if _bpm_thread:
		return
	_bpm_req = {"song_path": song_path}
	_bpm_res = {}
	_bpm_done = false
	_cancel_bpm = false
	_bpm_status_queue.clear()
	emit_signal("bpm_started")
	_bpm_thread = Thread.new()
	var err = _bpm_thread.start(func(): _bpm_worker(_bpm_req.duplicate()))
	if err != OK:
		_bpm_thread = null
		emit_signal("bpm_error", "Ошибка запуска потока")
		return
	_start_timer(_check_bpm)

func detect_genres(artist: String, title: String):
	if _genres_thread:
		return
	_genres_req = {"artist": artist, "title": title}
	_genres_res = {}
	_genres_done = false
	_genres_status_queue.clear()
	emit_signal("genres_started")
	_genres_thread = Thread.new()
	var err = _genres_thread.start(func(): _genres_worker(_genres_req.duplicate()))
	if err != OK:
		_genres_thread = null
		emit_signal("genres_error", "Ошибка запуска потока")
		return
	_start_timer(_check_genres)

func generate_notes(song_path: String, instrument_type: String, bpm: float, lanes: int, sync_tolerance: float, auto_identify: bool, manual_artist: String, manual_title: String, generation_mode: String):
	if _notes_thread:
		return
	_notes_req = {
		"song_path": song_path,
		"instrument_type": instrument_type,
		"bpm": bpm,
		"lanes": lanes,
		"sync_tolerance": sync_tolerance,
		"auto_identify": auto_identify,
		"manual_artist": manual_artist,
		"manual_title": manual_title,
		"generation_mode": generation_mode
	}
	_notes_res = {}
	_notes_done = false
	_cancel_notes = false
	_notes_status_queue.clear()
	emit_signal("notes_started")
	_notes_thread = Thread.new()
	var err = _notes_thread.start(func(): _notes_worker(_notes_req.duplicate()))
	if err != OK:
		_notes_thread = null
		emit_signal("notes_error", "Ошибка запуска потока")
		return
	_start_timer(_check_notes)

func request_cancel_bpm():
	_cancel_bpm = true

func request_cancel_notes():
	_cancel_notes = true

func _start_timer(cb: Callable):
	var t = Timer.new()
	t.wait_time = 0.1
	t.timeout.connect(cb)
	add_child(t)
	t.start()

func _check_bpm():
	if _bpm_status_queue.size() > 0:
		for s in _bpm_status_queue:
			emit_signal("bpm_status", s)
		_bpm_status_queue.clear()
	if _bpm_done:
		var t = get_child(get_child_count() - 1)
		if t and t is Timer:
			t.stop()
			t.queue_free()
		if _bpm_thread:
			_bpm_thread.wait_to_finish()
			_bpm_thread = null
		if _bpm_res.has("error"):
			emit_signal("bpm_error", _bpm_res.error)
		elif _bpm_res.has("bpm"):
			emit_signal("bpm_completed", int(_bpm_res.bpm))
		else:
			emit_signal("bpm_error", "Неизвестная ошибка")

func _check_genres():
	if _genres_status_queue.size() > 0:
		for s in _genres_status_queue:
			emit_signal("genres_status", s)
		_genres_status_queue.clear()
	if _genres_done:
		var t = get_child(get_child_count() - 1)
		if t and t is Timer:
			t.stop()
			t.queue_free()
		if _genres_thread:
			_genres_thread.wait_to_finish()
			_genres_thread = null
		if _genres_res.has("error"):
			emit_signal("genres_error", _genres_res.error)
		elif _genres_res.has("genres"):
			emit_signal("genres_completed", _genres_res.artist, _genres_res.title, _genres_res.genres)
		else:
			emit_signal("genres_error", "Неизвестная ошибка")

func _check_notes():
	if _notes_status_queue.size() > 0:
		for s in _notes_status_queue:
			emit_signal("notes_status", s)
		_notes_status_queue.clear()
	if _notes_done:
		var t = get_child(get_child_count() - 1)
		if t and t is Timer:
			t.stop()
			t.queue_free()
		if _notes_thread:
			_notes_thread.wait_to_finish()
			_notes_thread = null
		if _notes_res.has("error"):
			emit_signal("notes_error", _notes_res.error)
		elif _notes_res.has("manual_identification_required"):
			var req = _notes_req
			generate_notes(req.song_path, req.instrument_type, req.bpm, req.lanes, req.sync_tolerance, false, "Unknown", "Unknown", req.generation_mode)
		elif _notes_res.has("notes"):
			emit_signal("notes_completed", _notes_res.notes, float(_notes_res.bpm), _notes_res.instrument_type)
		else:
			emit_signal("notes_error", "Неизвестная ошибка")

func _bpm_worker(data_dict: Dictionary):
	var local_result = {}
	var local_error = ""
	var song_path = data_dict.get("song_path", "")
	if song_path == "":
		_bpm_res = {"error": "Пустой путь"}
		_bpm_done = true
		return
	_bpm_status_queue.append("Подключение к серверу...")
	var http_client = HTTPClient.new()
	var err = http_client.connect_to_host("localhost", 5000)
	if err != OK:
		local_error = "Не удалось подключиться: " + str(err)
	else:
		while http_client.get_status() in [HTTPClient.STATUS_CONNECTING, HTTPClient.STATUS_RESOLVING]:
			http_client.poll()
			OS.delay_msec(100)
			if _cancel_bpm:
				_bpm_res = {"error": "Операция отменена"}
				http_client.close()
				_bpm_done = true
				return
		_bpm_status_queue.append("Соединение установлено")
		if http_client.get_status() != HTTPClient.STATUS_CONNECTED:
			local_error = "Нет подключения. Статус: " + str(http_client.get_status())
		else:
			_bpm_status_queue.append("Открытие файла")
			var file_access = FileAccess.open(song_path, FileAccess.READ)
			if not file_access:
				local_error = "Не удалось открыть файл: " + song_path
			else:
				var file_data = file_access.get_buffer(file_access.get_length())
				file_access.close()
				_bpm_status_queue.append("Формирование запроса")
				var boundary = "bpm_boundary_" + str(Time.get_ticks_msec())
				var body = PackedByteArray()
				var header = ("--%s\r\n" + "Content-Disposition: form-data; name=\"audio_file\"; filename=\"%s\"\r\n" + "Content-Type: application/octet-stream\r\n\r\n") % [boundary, song_path.get_file()]
				body.append_array(header.to_utf8_buffer())
				body.append_array(file_data)
				body.append_array(("\r\n--%s--\r\n" % boundary).to_utf8_buffer())
				var headers = PackedStringArray(["Content-Type: multipart/form-data; boundary=" + boundary])
				_bpm_status_queue.append("Отправка данных")
				http_client.request_raw(HTTPClient.METHOD_POST, "/analyze_bpm", headers, body)
				http_client.poll()
				while http_client.get_status() == HTTPClient.STATUS_REQUESTING:
					http_client.poll()
					OS.delay_msec(100)
					if _cancel_bpm:
						_bpm_res = {"error": "Операция отменена"}
						http_client.close()
						_bpm_done = true
						return
				_bpm_status_queue.append("Получение ответа")
				var response_code = http_client.get_response_code()
				var response_body = PackedByteArray()
				while http_client.get_status() == HTTPClient.STATUS_BODY:
					var chunk = http_client.read_response_body_chunk()
					if chunk.size() == 0:
						break
					response_body.append_array(chunk)
					http_client.poll()
				_bpm_status_queue.append("Обработка ответа")
				var response_text = response_body.get_string_from_utf8()
				var response_json = JSON.parse_string(response_text)
				if response_code == 200 and response_json and response_json.has("bpm"):
					local_result = {"bpm": response_json["bpm"]}
				else:
					local_error = "Ошибка: " + str(response_code)
	http_client.close()
	_bpm_res = local_result if local_error == "" else {"error": local_error}
	_bpm_done = true

func _genres_worker(data_dict: Dictionary):
	var local_result = {}
	var local_error = ""
	var artist = data_dict.get("artist", "").strip_edges()
	var title = data_dict.get("title", "").strip_edges()
	if artist == "" or title == "":
		_genres_res = {"error": "Пустые поля"}
		_genres_done = true
		return
	_genres_status_queue.append("Подключение к серверу...")
	var http_client = HTTPClient.new()
	var err = http_client.connect_to_host("localhost", 5000)
	if err != OK:
		local_error = "Не удалось подключиться: " + str(err)
	else:
		while http_client.get_status() in [HTTPClient.STATUS_CONNECTING, HTTPClient.STATUS_RESOLVING]:
			http_client.poll()
			OS.delay_msec(100)
		_genres_status_queue.append("Соединение установлено")
		if http_client.get_status() != HTTPClient.STATUS_CONNECTED:
			local_error = "Нет подключения. Статус: " + str(http_client.get_status())
		else:
			_genres_status_queue.append("Отправка запроса")
			var payload = JSON.stringify({"artist": artist, "title": title}).to_utf8_buffer()
			var headers = PackedStringArray(["Content-Type: application/json", "Content-Length: " + str(payload.size())])
			http_client.request_raw(HTTPClient.METHOD_POST, "/get_genres_manual", headers, payload)
			http_client.poll()
			while http_client.get_status() == HTTPClient.STATUS_REQUESTING:
				http_client.poll()
				OS.delay_msec(100)
			_genres_status_queue.append("Получение ответа")
			var response_code = http_client.get_response_code()
			var response_body = PackedByteArray()
			while http_client.get_status() == HTTPClient.STATUS_BODY:
				var chunk = http_client.read_response_body_chunk()
				if chunk.size() == 0:
					break
				response_body.append_array(chunk)
				http_client.poll()
			_genres_status_queue.append("Обработка ответа")
			var response_text = response_body.get_string_from_utf8()
			var response_json = JSON.parse_string(response_text)
			if response_code == 200 and response_json and response_json.has("genres"):
				local_result = {"genres": response_json["genres"], "artist": response_json.get("artist", artist), "title": response_json.get("title", title)}
			else:
				local_error = "Ошибка: " + str(response_code)
	http_client.close()
	_genres_res = local_result if local_error == "" else {"error": local_error}
	_genres_done = true

func _notes_worker(data_dict: Dictionary):
	var local_result = {}
	var local_error = ""
	var song_path = data_dict.get("song_path", "")
	if song_path == "":
		_notes_res = {"error": "Пустой путь"}
		_notes_done = true
		return
	_notes_status_queue.append("Подключение к серверу...")
	var instrument_type = data_dict.get("instrument_type", "drums")
	var bpm = data_dict.get("bpm", 120.0)
	var lanes = data_dict.get("lanes", 4)
	var sync_tolerance = data_dict.get("sync_tolerance", 0.2)
	var auto_identify = data_dict.get("auto_identify", true)
	var manual_artist = data_dict.get("manual_artist", "")
	var manual_title = data_dict.get("manual_title", "")
	var generation_mode = data_dict.get("generation_mode", "basic")
	var file_access = FileAccess.open(song_path, FileAccess.READ)
	if not file_access:
		_notes_res = {"error": "Не удалось открыть файл"}
		_notes_done = true
		return
	var audio_data = file_access.get_buffer(file_access.get_length())
	file_access.close()
	_notes_status_queue.append("Формирование запроса")
	var boundary = "notes_boundary_" + str(randi())
	var body = PackedByteArray()
	var metadata_json = JSON.stringify({
		"original_filename": song_path.get_file(),
		"bpm": bpm,
		"lanes": lanes,
		"instrument_type": instrument_type,
		"sync_tolerance": sync_tolerance,
		"generation_mode": generation_mode,
		"auto_identify_track": auto_identify,
		"manual_artist": manual_artist,
		"manual_title": manual_title
	})
	var metadata_part = "--" + boundary + "\r\n" + "Content-Disposition: form-data; name=\"metadata\"\r\n" + "Content-Type: application/json\r\n\r\n" + metadata_json + "\r\n"
	body.append_array(metadata_part.to_utf8_buffer())
	var file_part_header = "--" + boundary + "\r\n" + "Content-Disposition: form-data; name=\"audio_file\"; filename=\"upload.mp3\"\r\n" + "Content-Type: audio/mpeg\r\n\r\n"
	body.append_array(file_part_header.to_utf8_buffer())
	body.append_array(audio_data)
	var closing_boundary = "\r\n--" + boundary + "--\r\n"
	body.append_array(closing_boundary.to_utf8_buffer())
	var http_client = HTTPClient.new()
	var err = http_client.connect_to_host("localhost", 5000)
	if err != OK:
		local_error = "Не удалось подключиться: " + str(err)
	else:
		while http_client.get_status() in [HTTPClient.STATUS_CONNECTING, HTTPClient.STATUS_RESOLVING]:
			http_client.poll()
			OS.delay_msec(100)
			if _cancel_notes:
				_notes_res = {"error": "Операция отменена"}
				http_client.close()
				_notes_done = true
				return
		_notes_status_queue.append("Соединение установлено")
		if http_client.get_status() != HTTPClient.STATUS_CONNECTED:
			local_error = "Нет подключения. Статус: " + str(http_client.get_status())
		else:
			var headers = PackedStringArray(["Content-Type: multipart/form-data; boundary=" + boundary])
			err = http_client.request_raw(HTTPClient.METHOD_POST, "/generate_drums", headers, body)
			if err != OK:
				local_error = "Ошибка отправки: " + str(err)
			else:
				http_client.poll()
				while http_client.get_status() == HTTPClient.STATUS_REQUESTING:
					http_client.poll()
					OS.delay_msec(100)
					if _cancel_notes:
						_notes_res = {"error": "Операция отменена"}
						http_client.close()
						_notes_done = true
						return
				_notes_status_queue.append("Получение ответа")
				var response_code = http_client.get_response_code()
				var response_body = PackedByteArray()
				while http_client.get_status() == HTTPClient.STATUS_BODY:
					var chunk = http_client.read_response_body_chunk()
					if chunk.size() == 0:
						break
					response_body.append_array(chunk)
					http_client.poll()
				_notes_status_queue.append("Обработка ответа")
				var response_text = response_body.get_string_from_utf8()
				var response_json = JSON.parse_string(response_text)
				if response_code == 200 and response_json is Dictionary:
					if response_json.has("status") and str(response_json["status"]) == "requires_manual_input":
						local_result = {"manual_identification_required": true, "song_path": song_path}
					elif response_json.has("notes"):
						local_result = {
							"notes": response_json["notes"],
							"bpm": response_json.get("bpm", bpm),
							"lanes": response_json.get("lanes", lanes),
							"instrument_type": response_json.get("instrument_type", instrument_type)
						}
					else:
						local_error = "Ответ не содержит нот"
				else:
					local_error = "Ошибка: " + str(response_code)
	http_client.close()
	_notes_res = local_result if local_error == "" else {"error": local_error}
	_notes_done = true
