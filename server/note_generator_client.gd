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

func generate_notes(song_path: String, instrument_type: String, bpm: float, lanes: int = -1, sync_tolerance: float = -1.0, auto_identify_track: bool = true):
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
		"auto_identify_track": auto_identify_track 
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
			print("NoteGeneratorClient.gd: Ошибка от сервера: ", _thread_result.error)
			emit_signal("notes_generation_error", _thread_result.error)
		elif _thread_result.has("manual_identification_required"):
			_set_is_generating(false)
			var song_path = _thread_result.song_path
			print("NoteGeneratorClient.gd: Требуется ручная идентификация для: ", song_path)
			emit_signal("manual_identification_needed", song_path)
		elif _thread_result.has("notes"):
			_set_is_generating(false)
			var notes = _thread_result.notes
			var bpm_val = _thread_result.bpm
			var inst_type = _thread_result.instrument_type
			var lanes_val = _thread_result.lanes
			
			_save_notes_locally(_thread_request_data.song_path, inst_type, notes)
			
			print("NoteGeneratorClient.gd: Ноты успешно получены: ", notes.size(), " нот")
			emit_signal("notes_generation_completed", notes, bpm_val, inst_type)
		else:
			_set_is_generating(false)
			print("NoteGeneratorClient.gd: Неожиданный формат ответа от сервера: ", _thread_result)
			emit_signal("notes_generation_error", "Неизвестная ошибка в потоке.")

func _thread_function(data_dict: Dictionary):
	var local_result = {}
	var local_error_occurred = false
	var local_error_msg = ""

	var song_path = data_dict.get("song_path", "")
	var instrument_type = data_dict.get("instrument_type", "standard")
	var bpm = data_dict.get("bpm", -1.0)
	var lanes = data_dict.get("lanes", default_lanes)
	var sync_tolerance = data_dict.get("sync_tolerance", default_sync_tolerance)
	var auto_identify_track = data_dict.get("auto_identify_track", true) 

	if song_path == "":
		local_error_occurred = true
		local_error_msg = "Пустой путь к файлу."
		local_result = {"error": local_error_msg}
		_thread_result = local_result
		_thread_finished = true
		return

	var track_info = null
	if auto_identify_track:
		var identification_result = _identify_track(song_path)
		if identification_result.success:
			track_info = identification_result.track_info
			print("NoteGeneratorClient.gd (Thread): Идентификация успешна: ", track_info.artist, " - ", track_info.title)
			if track_info.artist == "Unknown" or track_info.title == "Unknown":
				print("NoteGeneratorClient.gd (Thread): Идентификация вернула 'Unknown', требуется ручной ввод.")
				local_result = {
					"manual_identification_required": true,
					"song_path": song_path
				}
				_thread_result = local_result
				_thread_finished = true
				return
		else:
			print("NoteGeneratorClient.gd (Thread): Идентификация не удалась, требуется ручной ввод.")
			local_result = {
				"manual_identification_required": true,
				"song_path": song_path
			}
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

				var headers = PackedStringArray([
					"Host: localhost:5000",
					"Content-Type: application/octet-stream",
					"Content-Length: " + str(file_data.size()),
					"X-BPM: " + str(bpm),
					"X-Instrument: " + instrument_type,
					"X-Filename: " + song_path.get_file(),
					"X-Lanes: " + str(lanes),
					"X-Sync-Tolerance: " + str(sync_tolerance)
					, "X-Identify-Track: " + str(auto_identify_track).to_lower()
				])

				var request_method = HTTPClient.METHOD_POST
				var request_url = "/generate_drums" if instrument_type == "drums" else "/generate_notes"
				
				http_client.request_raw(request_method, request_url, headers, file_data)
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
						if response_json:
							if response_json.has("notes") and response_json.has("bpm"):
								var notes = response_json["notes"]
								var received_bpm = response_json["bpm"]
								var received_lanes = response_json.get("lanes", lanes)
								var received_instrument = response_json.get("instrument_type", instrument_type)
								print("NoteGeneratorClient.gd (Thread): Получено нот: ", notes.size(), ", BPM: ", received_bpm, ", Lanes: ", received_lanes)
								
								local_result = {
									"notes": notes, 
									"bpm": received_bpm, 
									"lanes": received_lanes,
									"instrument_type": received_instrument
								}
							elif response_json.has("error"):
								local_error_msg = response_json["error"]
								print("NoteGeneratorClient.gd (Thread): Ошибка от сервера: ", local_error_msg)
								local_error_occurred = true
							else:
								local_error_msg = "Ответ не содержит ожидаемые поля: notes и bpm"
								print("NoteGeneratorClient.gd (Thread): Неполный ответ от сервера: ", response_json)
								local_error_occurred = true
						else:
							local_error_msg = "Ответ не является валидным JSON"
							print("NoteGeneratorClient.gd (Thread): Ответ не является JSON: ", response_text)
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

func _save_notes_locally(song_path: String, instrument: String, notes_data: Array):
	var base_name = song_path.get_file().get_basename()
	var song_folder_name = base_name 
	var notes_filename = "%s_%s.json" % [base_name, instrument]
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
		print("NoteGeneratorClient.gd: Ноты сохранены локально: ", notes_path)
		print("NoteGeneratorClient.gd: Содержимое файла отформатировано.")
	else:
		print("NoteGeneratorClient.gd: Ошибка сохранения нот: ", notes_path)
