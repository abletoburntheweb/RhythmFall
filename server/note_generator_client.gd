# logic/note_generator_client.gd
class_name NoteGeneratorClient
extends Node

signal notes_generation_started
signal notes_generation_completed(notes_data: Array, bpm_value: float, instrument_type: String)
signal notes_generation_error(error_message: String)
signal manual_identification_needed(song_path: String)

var http_thread: Thread
var is_generating: bool = false
var _thread_request_data: Dictionary = {}
var _thread_result: Dictionary = {}
var _thread_finished: bool = false

var default_lanes: int = 4
var default_sync_tolerance: float = 0.2 

var track_identification_needed: bool = true 

func set_track_identification(needed: bool):
	track_identification_needed = needed

func _set_is_generating(value: bool):
	is_generating = value

func generate_notes(
	song_path: String,
	instrument_type: String,
	bpm: float,
	lanes: int = -1,
	sync_tolerance: float = -1.0,
	auto_identify_track: bool = true,
	manual_artist: String = "",
	manual_title: String = "",
	generation_mode: String = "basic"
):
	if is_generating:
		print("NoteGeneratorClient.gd: Генерация уже выполняется, игнорируем новый запрос.")
		return

	_set_is_generating(true)
	emit_signal("notes_generation_started")

	var effective_lanes = lanes if lanes > 0 else default_lanes
	var effective_sync_tolerance = sync_tolerance if sync_tolerance > 0.0 else default_sync_tolerance
	
	_thread_request_data = {
		"song_path": song_path,
		"instrument_type": instrument_type,
		"bpm": bpm,
		"lanes": effective_lanes,
		"sync_tolerance": effective_sync_tolerance,
		"auto_identify_track": auto_identify_track,
		"manual_artist": manual_artist,
		"manual_title": manual_title,
		"generation_mode": generation_mode
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

		if _thread_result.has("error"):
			_set_is_generating(false)
			emit_signal("notes_generation_error", _thread_result["error"])
		elif _thread_result.has("manual_identification_required"):
			_set_is_generating(false)
			emit_signal("manual_identification_needed", _thread_result["song_path"])
		elif _thread_result.has("notes"):
			_set_is_generating(false)
			var notes = _thread_result["notes"]
			var bpm_val = _thread_result["bpm"]
			var inst_type = _thread_result["instrument_type"]
			var lanes_val = _thread_result["lanes"]
			
			_save_notes_locally(_thread_request_data.song_path, inst_type, notes, _thread_request_data.generation_mode, lanes_val)
			
			var track_info = _thread_result.get("track_info", {})
			if !track_info.is_empty() and track_info.has("genres"):
				SongMetadataManager.update_metadata(_thread_request_data.song_path, {"genres": track_info["genres"]})
			
			emit_signal("notes_generation_completed", notes, bpm_val, inst_type)
		else:
			_set_is_generating(false)
			emit_signal("notes_generation_error", "Неожиданный формат ответа от сервера")

func _thread_function(data_dict: Dictionary):
	var local_result = {}
	var local_error_occurred = false
	var local_error_msg = ""

	var song_path = data_dict.get("song_path", "")
	var instrument_type = data_dict.get("instrument_type", "drums")
	var bpm = data_dict.get("bpm", 120.0)
	var lanes = data_dict.get("lanes", default_lanes)
	var sync_tolerance = data_dict.get("sync_tolerance", default_sync_tolerance)
	var auto_identify_track = data_dict.get("auto_identify_track", true)
	var manual_artist = data_dict.get("manual_artist", "")
	var manual_title = data_dict.get("manual_title", "")
	var generation_mode = data_dict.get("generation_mode", "basic")

	if song_path == "":
		local_error_occurred = true
		local_error_msg = "Пустой путь к файлу."
		_thread_result = {"error": local_error_msg}
		_thread_finished = true
		return

	var file_access = FileAccess.open(song_path, FileAccess.READ)
	if not file_access:
		local_error_occurred = true
		local_error_msg = "Не удалось открыть аудиофайл: %s" % song_path
		_thread_result = {"error": local_error_msg}
		_thread_finished = true
		return

	var audio_data = file_access.get_buffer(file_access.get_length())
	file_access.close()

	var boundary = "godot_boundary_" + str(randi())
	var body = PackedByteArray()

	var metadata_json = JSON.stringify({
		"original_filename": song_path.get_file(),
		"bpm": bpm,
		"lanes": lanes,
		"instrument_type": instrument_type,
		"sync_tolerance": sync_tolerance,
		"generation_mode": generation_mode,
		"auto_identify_track": auto_identify_track,
		"manual_artist": manual_artist,
		"manual_title": manual_title
	})
	var metadata_part = "--" + boundary + "\r\n" + \
		"Content-Disposition: form-data; name=\"metadata\"\r\n" + \
		"Content-Type: application/json\r\n\r\n" + \
		metadata_json + "\r\n"
	body.append_array(metadata_part.to_utf8_buffer())

	var file_part_header = "--" + boundary + "\r\n" + \
		"Content-Disposition: form-data; name=\"audio_file\"; filename=\"upload.mp3\"\r\n" + \
		"Content-Type: audio/mpeg\r\n\r\n"
	body.append_array(file_part_header.to_utf8_buffer())
	body.append_array(audio_data)

	var closing_boundary = "\r\n--" + boundary + "--\r\n"
	body.append_array(closing_boundary.to_utf8_buffer())

	var http_client = HTTPClient.new()
	var error = http_client.connect_to_host("localhost", 5000)
	if error != OK:
		local_error_msg = "Не удалось подключиться к серверу: " + str(error)
		local_error_occurred = true
	else:
		while http_client.get_status() in [HTTPClient.STATUS_CONNECTING, HTTPClient.STATUS_RESOLVING]:
			http_client.poll()
			OS.delay_msec(100)

		if http_client.get_status() != HTTPClient.STATUS_CONNECTED:
			local_error_msg = "Не удалось подключиться к серверу. Статус: " + str(http_client.get_status())
			local_error_occurred = true
		else:
			var headers = PackedStringArray([
				"Content-Type: multipart/form-data; boundary=" + boundary
			])
			error = http_client.request_raw(HTTPClient.METHOD_POST, "/generate_drums", headers, body)
			if error != OK:
				local_error_msg = "Ошибка отправки запроса: " + str(error)
				local_error_occurred = true
			else:
				http_client.poll()
				while http_client.get_status() == HTTPClient.STATUS_REQUESTING:
					http_client.poll()
					OS.delay_msec(100)

				var response_code = http_client.get_response_code()
				var response_body_bytes = PackedByteArray()
				while http_client.get_status() == HTTPClient.STATUS_BODY:
					var chunk = http_client.read_response_body_chunk()
					if chunk.size() == 0:
						break
					response_body_bytes.append_array(chunk)
					http_client.poll()

				var response_text = response_body_bytes.get_string_from_utf8()
				var response_json = JSON.parse_string(response_text)

				if response_code == 200 and response_json is Dictionary:
					if response_json.has("status") and response_json["status"] == "requires_manual_input":
						local_result = {
							"manual_identification_required": true,
							"song_path": song_path
						}
					elif response_json.has("notes"):
						local_result = {
							"notes": response_json["notes"],
							"bpm": response_json.get("bpm", bpm),
							"lanes": response_json.get("lanes", lanes),
							"instrument_type": response_json.get("instrument_type", instrument_type),
							"track_info": response_json.get("track_info", {})
						}
					else:
						local_error_msg = "Ответ не содержит нот и не требует ручного ввода"
						local_error_occurred = true
				else:
					local_error_msg = "Сервер вернул ошибку: %s. Тело: %s" % [str(response_code), response_text]
					local_error_occurred = true

	http_client.close()

	if local_error_occurred:
		_thread_result = {"error": local_error_msg}
	else:
		_thread_result = local_result

	_thread_finished = true

func _identify_track(song_path: String) -> Dictionary:
	var result = {"success": false, "track_info": null}
	
	var http_client = HTTPClient.new()
	var error = http_client.connect_to_host("localhost", 5000)
	if error != OK:
		print("NoteGeneratorClient.gd (Identify): Не удалось подключиться к серверу: ", error)
		return result

	while http_client.get_status() == HTTPClient.STATUS_CONNECTING or http_client.get_status() == HTTPClient.STATUS_RESOLVING:
		http_client.poll()
		OS.delay_msec(100)

	if http_client.get_status() != HTTPClient.STATUS_CONNECTED:
		print("NoteGeneratorClient.gd (Identify): Не удалось подключиться к серверу. Статус: ", str(http_client.get_status()))
		http_client.close()
		return result

	var file_access = FileAccess.open(song_path, FileAccess.READ)
	if not file_access:
		print("NoteGeneratorClient.gd (Identify): Не удалось открыть файл для чтения: ", song_path)
		http_client.close()
		return result

	var file_data = file_access.get_buffer(file_access.get_length())
	file_access.close()

	var headers = PackedStringArray([
		"Host: localhost:5000",
		"Content-Type: application/octet-stream",
		"Content-Length: " + str(file_data.size()),
		"X-Filename: " + song_path.get_file()
	])

	http_client.request_raw(HTTPClient.METHOD_POST, "/identify_track", headers, file_data)
	http_client.poll()

	while http_client.get_status() == HTTPClient.STATUS_REQUESTING:
		http_client.poll()
		OS.delay_msec(100)

	var response_code = http_client.get_response_code()
	print("NoteGeneratorClient.gd (Identify): Код ответа идентификации: ", response_code)

	var track_info = null
	if response_code == 200:
		var response_body_bytes = PackedByteArray()
		while http_client.get_status() == HTTPClient.STATUS_BODY:
			var chunk = http_client.read_response_body_chunk()
			if chunk.size() == 0:
				break
			response_body_bytes.append_array(chunk)
			http_client.poll()
		
		var response_text = response_body_bytes.get_string_from_utf8()
		var response_json = JSON.parse_string(response_text)
		if response_json and response_json.has("track_info"):
			track_info = response_json["track_info"]
			result.success = true
			result.track_info = track_info
			print("NoteGeneratorClient.gd (Identify): Идентификация получена: ", track_info.artist, " - ", track_info.title)
		else:
			print("NoteGeneratorClient.gd (Identify): Ответ идентификации не содержит track_info: ", response_text)
	elif response_code == 404:
		var error_body = PackedByteArray()
		while http_client.get_status() == HTTPClient.STATUS_BODY:
			var chunk = http_client.read_response_body_chunk()
			if chunk.size() == 0:
				break
			error_body.append_array(chunk)
			http_client.poll()
		var error_text = error_body.get_string_from_utf8()
		print("NoteGeneratorClient.gd (Identify): Трек не найден (404): ", error_text)
	else:
		var error_body = PackedByteArray()
		while http_client.get_status() == HTTPClient.STATUS_BODY:
			var chunk = http_client.read_response_body_chunk()
			if chunk.size() == 0:
				break
			error_body.append_array(chunk)
			http_client.poll()
		var error_text = error_body.get_string_from_utf8()
		print("NoteGeneratorClient.gd (Identify): Ошибка идентификации (", response_code, "): ", error_text)

	http_client.close()
	return result

func _save_notes_locally(song_path: String, instrument: String, notes_data: Array, generation_mode: String = "basic", lanes: int = 4):
	var base_name = song_path.get_file().get_basename()
	var song_folder_name = base_name
	var notes_filename = "%s_%s_%s_lanes%d.json" % [base_name, instrument, generation_mode.to_lower(), lanes]
	var song_notes_path = "user://notes/%s" % song_folder_name 
	
	var dir = DirAccess.open("user://")
	if not dir:
		dir = DirAccess.open("res://")
	if dir:
		if not dir.dir_exists(song_notes_path):
			dir.make_dir_recursive(song_notes_path)
	
	var notes_path = "%s/%s" % [song_notes_path, notes_filename]
	
	var json_obj = JSON.new()
	var json_string = json_obj.stringify(notes_data, "  ") 
	
	var file = FileAccess.open(notes_path, FileAccess.WRITE)
	if file:
		file.store_string(json_string) 
		file.close()
	else:
		print("NoteGeneratorClient.gd: Ошибка сохранения нот: ", notes_path)
