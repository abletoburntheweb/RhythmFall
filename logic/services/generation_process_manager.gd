# logic/services/generation_process_manager.gd
extends Node

const HEALTH_PATH := "/health"
const STARTUP_TIMEOUT_SEC := 90.0
const CONNECT_POLLS := 12
const REQUEST_POLLS := 24
const POLL_SLEEP_MS := 5

var _spawn_in_progress := false
var _spawned_by_game := false
var _spawn_tracks_pid := false
var _worker_pid := -1
var _startup_deadline_msec := 0
var _port_probe_cache_until_msec := 0
var _port_probe_cache_result := false

const PROBE_CACHE_MS := 1500

var _prewarm_poll_timer: Timer = null


func _ready() -> void:
	call_deferred("_prewarm_if_enabled")


func _exit_tree() -> void:
	shutdown_managed_worker()


func shutdown_managed_worker() -> void:
	if _prewarm_poll_timer and is_instance_valid(_prewarm_poll_timer):
		_prewarm_poll_timer.stop()
	stop_owned_worker()
	_kill_pid_file_worker()
	_spawned_by_game = false
	_spawn_in_progress = false
	_worker_pid = -1
	_invalidate_port_probe_cache()


## Stop any local generation process (owned PID, pid file, or listener on the API port).
func force_stop_local_worker() -> void:
	shutdown_managed_worker()
	if OS.get_name() == "Windows":
		_kill_listener_on_local_port(get_api_port())
	_invalidate_port_probe_cache()


func is_local_port_busy() -> bool:
	return _is_local_port_listening(get_api_port())


func resolve_server_root_dir() -> String:
	for server_dir in _server_search_dirs():
		var normalized := _normalize_dir(server_dir)
		if normalized == "":
			continue
		if FileAccess.file_exists(normalized.path_join("run.py")):
			return normalized
	var exe_base := OS.get_executable_path().get_base_dir()
	if exe_base != "":
		var sibling := exe_base.path_join("RhythmFallServer")
		if DirAccess.dir_exists_absolute(sibling):
			return sibling.replace("\\", "/")
	var res_server := ProjectSettings.globalize_path("res://RhythmFallServer-main")
	if FileAccess.file_exists(res_server.path_join("run.py")):
		return res_server.replace("\\", "/")
	return ""


func fetch_health_payload() -> Dictionary:
	return _ping_health()


func _kill_pid_file_worker() -> void:
	var pid_path := _worker_pid_file_path()
	if not FileAccess.file_exists(pid_path):
		return
	var pid_text := FileAccess.get_file_as_string(pid_path).strip_edges()
	if pid_text.is_valid_int():
		var pid := int(pid_text)
		if pid > 0 and OS.is_process_running(pid):
			OS.kill(pid)
	DirAccess.remove_absolute(pid_path)


func _kill_listener_on_local_port(port: int) -> void:
	if port <= 0:
		return
	var ps := (
		"$conns = Get-NetTCPConnection -LocalPort %d -State Listen -ErrorAction SilentlyContinue; "
		+ "foreach ($c in $conns) { Stop-Process -Id $c.OwningProcess -Force -ErrorAction SilentlyContinue }"
	) % port
	OS.execute(
		"powershell.exe",
		PackedStringArray(["-NoProfile", "-ExecutionPolicy", "Bypass", "-Command", ps]),
		[],
		true,
		false
	)


func _worker_pid_file_path() -> String:
	var base := String(OS.get_environment("APPDATA")).replace("\\", "/").strip_edges()
	if base == "":
		return "user://RhythmFall/server_worker.pid"
	return "%s/RhythmFall/server_worker.pid" % base

func _prewarm_if_enabled() -> void:
	if not should_auto_manage():
		return
	if is_backend_healthy():
		return
	var result := ensure_running()
	if result.get("pending", false):
		_start_prewarm_poll()


func _start_prewarm_poll() -> void:
	if _prewarm_poll_timer == null:
		_prewarm_poll_timer = Timer.new()
		_prewarm_poll_timer.wait_time = 1.0
		_prewarm_poll_timer.timeout.connect(_on_prewarm_poll)
		add_child(_prewarm_poll_timer)
	if _prewarm_poll_timer.is_stopped():
		_prewarm_poll_timer.start()


func _on_prewarm_poll() -> void:
	if is_backend_healthy() or not _spawn_in_progress:
		if _prewarm_poll_timer:
			_prewarm_poll_timer.stop()
		return
	ensure_running()


func should_auto_manage() -> bool:
	if SettingsManager == null:
		return true
	if bool(SettingsManager.get_setting("generation_server_use_lan_host", false)):
		return false
	return bool(SettingsManager.get_setting("generation_auto_worker", true))


func get_api_host() -> String:
	if SettingsManager:
		if bool(SettingsManager.get_setting("generation_server_use_lan_host", false)):
			var lan := str(SettingsManager.get_setting("generation_server_lan_host", "")).strip_edges()
			return lan if not lan.is_empty() else "127.0.0.1"
		return "127.0.0.1"
	return str(ProjectSettings.get_setting("rhythmfall/generation_api/host", "127.0.0.1")).strip_edges()


func get_api_port() -> int:
	if SettingsManager:
		var p = SettingsManager.get_setting("generation_server_port", null)
		if p != null:
			return clampi(int(p), 1, 65535)
	return clampi(int(ProjectSettings.get_setting("rhythmfall/generation_api/port", 5000)), 1, 65535)


func is_backend_healthy() -> bool:
	return _ping_health().get("ok", false)


func ensure_running() -> Dictionary:
	if not should_auto_manage():
		if is_backend_healthy():
			return {"ok": true}
		return {
			"ok": false,
			"error_key": "GEN_WORKER_MANUAL_REQUIRED",
		}
	if is_backend_healthy():
		_spawn_in_progress = false
		_startup_deadline_msec = 0
		return {"ok": true}
	if _is_external_server_active():
		return _wait_for_external_server()
	if _spawn_in_progress:
		return _startup_status()
	return _spawn_worker()


func stop_owned_worker() -> void:
	if not _spawned_by_game or _worker_pid <= 0:
		return
	if OS.is_process_running(_worker_pid):
		OS.kill(_worker_pid)
	_spawned_by_game = false
	_worker_pid = -1


func _spawn_worker() -> Dictionary:
	if _is_external_server_active():
		return _wait_for_external_server()
	var launch := _resolve_worker_launch()
	if not launch.get("ok", false):
		var err_key := str(launch.get("error_key", "GEN_WORKER_NOT_CONFIGURED"))
		if err_key == "GEN_WORKER_ALREADY_RUNNING":
			return _wait_for_external_server()
		var err: Dictionary = {
			"ok": false,
			"error_key": str(launch.get("error_key", "GEN_WORKER_NOT_CONFIGURED")),
		}
		var detail := str(launch.get("detail", "")).strip_edges()
		if detail != "":
			err["detail"] = detail
		return err
	_spawn_in_progress = true
	var argv: PackedStringArray = launch.get("argv", PackedStringArray())
	var show_console := bool(launch.get("open_console", false))
	_spawn_tracks_pid = bool(launch.get("track_pid", true))
	_invalidate_port_probe_cache()
	var pid := OS.create_process(str(launch.get("path", "")), argv, show_console)
	if pid <= 0:
		_spawn_in_progress = false
		_spawn_tracks_pid = false
		return {"ok": false, "error_key": "GEN_WORKER_START_FAILED"}
	_worker_pid = pid if _spawn_tracks_pid else -1
	_spawned_by_game = true
	_startup_deadline_msec = Time.get_ticks_msec() + int(STARTUP_TIMEOUT_SEC * 1000.0)
	return _startup_status()


func _startup_status() -> Dictionary:
	if is_backend_healthy():
		_spawn_in_progress = false
		_startup_deadline_msec = 0
		return {"ok": true}
	if _spawn_tracks_pid and _worker_pid > 0 and not OS.is_process_running(_worker_pid):
		_spawn_in_progress = false
		_startup_deadline_msec = 0
		_spawn_tracks_pid = false
		return {"ok": false, "error_key": "GEN_WORKER_START_FAILED"}
	if _startup_deadline_msec > 0 and Time.get_ticks_msec() >= _startup_deadline_msec:
		_spawn_in_progress = false
		_startup_deadline_msec = 0
		return {"ok": false, "error_key": "GEN_WORKER_TIMEOUT"}
	return {"ok": false, "pending": true, "error_key": "GEN_WORKER_STARTING"}


func _is_external_server_active() -> bool:
	return _is_local_port_listening(get_api_port())


func _wait_for_external_server() -> Dictionary:
	if _startup_deadline_msec <= 0:
		_startup_deadline_msec = Time.get_ticks_msec() + int(STARTUP_TIMEOUT_SEC * 1000.0)
	if is_backend_healthy():
		_startup_deadline_msec = 0
		return {"ok": true}
	if Time.get_ticks_msec() >= _startup_deadline_msec:
		_startup_deadline_msec = 0
		return {"ok": false, "error_key": "GEN_WORKER_TIMEOUT"}
	return {"ok": false, "pending": true, "error_key": "GEN_WORKER_STARTING"}


func _is_local_port_listening(port: int) -> bool:
	var now := Time.get_ticks_msec()
	if now < _port_probe_cache_until_msec:
		return _port_probe_cache_result
	_port_probe_cache_result = _probe_tcp_port("127.0.0.1", port)
	_port_probe_cache_until_msec = now + PROBE_CACHE_MS
	return _port_probe_cache_result


func _invalidate_port_probe_cache() -> void:
	_port_probe_cache_until_msec = 0
	_port_probe_cache_result = false


func _probe_tcp_port(host: String, port: int) -> bool:
	var tcp := StreamPeerTCP.new()
	if tcp.connect_to_host(host, port) != OK:
		return false
	for _i in range(8):
		var status := tcp.get_status()
		if status == StreamPeerTCP.STATUS_CONNECTED:
			tcp.disconnect_from_host()
			return true
		if status == StreamPeerTCP.STATUS_NONE or status == StreamPeerTCP.STATUS_ERROR:
			tcp.disconnect_from_host()
			return false
		OS.delay_msec(8)
	tcp.disconnect_from_host()
	return false


func _ping_health() -> Dictionary:
	var http := HTTPClient.new()
	var host := get_api_host()
	var port := get_api_port()
	if http.connect_to_host(host, port) != OK:
		http.close()
		return {"ok": false}
	for _i in range(CONNECT_POLLS):
		if http.get_status() not in [HTTPClient.STATUS_CONNECTING, HTTPClient.STATUS_RESOLVING]:
			break
		http.poll()
		OS.delay_msec(POLL_SLEEP_MS)
	if http.get_status() != HTTPClient.STATUS_CONNECTED:
		http.close()
		return {"ok": false}
	http.request(HTTPClient.METHOD_GET, HEALTH_PATH, PackedStringArray())
	for _j in range(REQUEST_POLLS):
		if http.get_status() != HTTPClient.STATUS_REQUESTING:
			break
		http.poll()
		OS.delay_msec(POLL_SLEEP_MS)
	if http.get_status() == HTTPClient.STATUS_REQUESTING:
		http.close()
		return {"ok": false}
	var code := http.get_response_code()
	var body := PackedByteArray()
	for _k in range(REQUEST_POLLS):
		if http.get_status() != HTTPClient.STATUS_BODY:
			break
		http.poll()
		var chunk := http.read_response_body_chunk()
		if chunk.size() > 0:
			body.append_array(chunk)
		OS.delay_msec(POLL_SLEEP_MS)
	http.close()
	if code != 200:
		return {"ok": false}
	var parsed = JSON.parse_string(body.get_string_from_utf8())
	if parsed is Dictionary and str(parsed.get("status", "")) == "healthy":
		var out: Dictionary = parsed
		out["ok"] = true
		return out
	return {"ok": false}


func _prefer_wsl_worker() -> bool:
	return false


func _resolve_worker_launch() -> Dictionary:
	var tried: PackedStringArray = PackedStringArray()
	var exe_base := OS.get_executable_path().get_base_dir()
	if exe_base != "":
		tried.append(exe_base)
		var server_exe := exe_base.path_join("RhythmFallServer.exe")
		if OS.get_name() == "Windows" and FileAccess.file_exists(server_exe):
			if _is_local_port_listening(get_api_port()):
				return {"ok": false, "error_key": "GEN_WORKER_ALREADY_RUNNING"}
			return _launch_server_exe(server_exe)
	for server_dir in _server_search_dirs():
		var normalized := _normalize_dir(server_dir)
		if normalized == "":
			continue
		tried.append(normalized)
		if FileAccess.file_exists(normalized.path_join("run.py")):
			var hidden := _launch_hidden_python_server(normalized)
			if hidden.get("ok", false):
				return hidden
	var custom := ""
	if SettingsManager:
		custom = str(SettingsManager.get_setting("generation_worker_path", "")).strip_edges()
	if custom != "":
		var custom_dir := _normalize_dir(custom)
		if custom_dir != "":
			tried.append(custom_dir)
			var custom_bat := custom_dir.path_join("start_worker.bat")
			if FileAccess.file_exists(custom_bat):
				return _launch_cmd_bat(custom_bat)
			var custom_run := custom_dir.path_join("run.py")
			if FileAccess.file_exists(custom_run):
				return _launch_hidden_python_server(custom_dir)
	for root in _worker_search_roots():
		var normalized := _normalize_dir(root)
		if normalized == "":
			continue
		if custom != "" and normalized == _normalize_dir(custom):
			continue
		tried.append(normalized)
		if _prefer_wsl_worker():
			var wsl_bat := normalized.path_join("start_worker_wsl.bat")
			if FileAccess.file_exists(wsl_bat):
				return _launch_cmd_bat(wsl_bat)
		var bat := normalized.path_join("start_worker.bat")
		if FileAccess.file_exists(bat):
			return _launch_cmd_bat(bat)
	return {
		"ok": false,
		"error_key": "GEN_WORKER_NOT_CONFIGURED",
		"detail": "tried: %s" % ", ".join(tried),
	}


func _server_search_dirs() -> PackedStringArray:
	var dirs := PackedStringArray()
	var custom := ""
	if SettingsManager:
		custom = str(SettingsManager.get_setting("generation_worker_path", "")).strip_edges()
	if custom != "":
		dirs.append(custom)
	dirs.append(ProjectSettings.globalize_path("res://RhythmFallServer"))
	dirs.append(ProjectSettings.globalize_path("res://RhythmFallServer-main"))
	var exe_base := OS.get_executable_path().get_base_dir()
	if exe_base != "":
		dirs.append(exe_base.path_join("RhythmFallServer"))
		dirs.append(exe_base.path_join("RhythmFallWorker"))
	return dirs


func _worker_search_roots() -> PackedStringArray:
	var roots := PackedStringArray()
	var custom := ""
	if SettingsManager:
		custom = str(SettingsManager.get_setting("generation_worker_path", "")).strip_edges()
	if custom != "":
		roots.append(custom)
	# Project-local server folder (sibling of worker/).
	roots.append(ProjectSettings.globalize_path("res://RhythmFallServer"))
	# worker/ with start_worker.bat
	roots.append(ProjectSettings.globalize_path("res://worker"))
	var exe_base := OS.get_executable_path().get_base_dir()
	if exe_base != "":
		roots.append(exe_base.path_join("RhythmFallWorker"))
		roots.append(exe_base.path_join("worker"))
	return roots


func _normalize_dir(path: String) -> String:
	var p := String(path).strip_edges().replace("\\", "/")
	if p.ends_with("/start_worker.bat"):
		return p.get_base_dir()
	if p.ends_with("/run.py"):
		return p.get_base_dir()
	return p


func _gpu_env_fragment() -> String:
	var mode := "auto"
	if SettingsManager:
		mode = str(SettingsManager.get_setting("generation_gpu_stack", "auto")).strip_edges().to_lower()
	if mode not in ["auto", "nvidia", "amd", "cpu"]:
		mode = "auto"
	return "set RFALL_GPU=%s&& " % mode


func _chart_variant_env_fragment() -> String:
	if SettingsManager == null:
		return ""
	if not bool(SettingsManager.get_setting("generation_save_experimental_chart", false)):
		return ""
	var tag := NotesUtils.normalize_chart_tag(String(SettingsManager.get_setting("split_compare_variant_tag", "exp")))
	if tag == "":
		return ""
	return "set RFALL_CHART_VARIANT=%s&& " % tag


func _launch_server_exe(exe_path: String) -> Dictionary:
	var variant_env := _chart_variant_env_fragment()
	var gpu_env := _gpu_env_fragment()
	var pid_file := _worker_pid_file_path().replace("/", "\\")
	var pid_env := "set RF_PID_FILE=%s&& " % pid_file
	if _prefer_wsl_worker() and OS.get_name() == "Windows":
		return {
			"ok": true,
			"path": "cmd.exe",
			"argv": PackedStringArray([
				"/c",
				"%s%s%sset RFALL_USE_WSL=1&& start \"RhythmFallServer\" /B \"%s\"" % [
					variant_env, gpu_env, pid_env, exe_path.replace("\\", "/"),
				],
			]),
			"open_console": false,
			"track_pid": false,
		}
	return {
		"ok": true,
		"path": "cmd.exe",
		"argv": PackedStringArray([
			"/c",
			"%s%s%sstart \"RhythmFallServer\" \"%s\"" % [
				variant_env, gpu_env, pid_env, exe_path.replace("\\", "/"),
			],
		]),
		"open_console": true,
		"track_pid": false,
	}


func _launch_cmd_bat(bat_path: String) -> Dictionary:
	if OS.get_name() == "Windows":
		return {
			"ok": true,
			"path": "cmd.exe",
			"argv": PackedStringArray(["/c", "start \"RhythmFallServer\" /B cmd /c \"%s\"" % bat_path.replace("\\", "/")]),
			"open_console": false,
			"track_pid": false,
		}
	return {"ok": false, "error_key": "GEN_WORKER_START_FAILED"}


func _launch_hidden_python_server(server_dir: String) -> Dictionary:
	var python := _resolve_python_for_server(server_dir, false)
	if python == "":
		return {"ok": false, "error_key": "GEN_WORKER_NOT_CONFIGURED"}
	var port := str(get_api_port())
	var variant_env := _chart_variant_env_fragment()
	var gpu_env := _gpu_env_fragment()
	var server_win := server_dir.replace("/", "\\")
	if OS.get_name() == "Windows":
		var pid_file := _worker_pid_file_path().replace("/", "\\")
		var cmd := (
			"cd /d \"%s\" && %s%sset RF_BIND_HOST=127.0.0.1&& set RF_BIND_PORT=%s&& "
			+ "set RF_FLASK_DEBUG=0&& set PYTHONUNBUFFERED=1&& "
			+ "set RF_PID_FILE=%s&& "
			+ "start \"RhythmFallServer\" /B \"%s\" -u run.py"
		) % [server_win, variant_env, gpu_env, port, pid_file, python]
		return {
			"ok": true,
			"path": "cmd.exe",
			"argv": PackedStringArray(["/c", cmd]),
			"open_console": false,
			"track_pid": false,
		}
	return {
		"ok": true,
		"path": python,
		"argv": PackedStringArray(["-u", server_dir.path_join("run.py")]),
		"open_console": false,
		"track_pid": true,
	}


func _resolve_python_for_server(server_dir: String, allow_pythonw: bool = true) -> String:
	var env_py := OS.get_environment("RFALL_PYTHON")
	if env_py != "" and FileAccess.file_exists(env_py):
		return env_py
	var exe_base := OS.get_executable_path().get_base_dir()
	if exe_base != "":
		var path_file := exe_base.path_join("worker").path_join("windows_python.path")
		if FileAccess.file_exists(path_file):
			var from_file := FileAccess.get_file_as_string(path_file).strip_edges()
			if from_file != "" and FileAccess.file_exists(from_file):
				return from_file
	var venv_py := server_dir.path_join(".venv").path_join("Scripts").path_join("python.exe")
	if FileAccess.file_exists(venv_py):
		return venv_py
	var fallback := _resolve_python_executable()
	if fallback == "":
		return ""
	if allow_pythonw:
		return _maybe_pythonw(fallback)
	return fallback


func _maybe_pythonw(python: String) -> String:
	if OS.get_name() != "Windows":
		return python
	if python.get_file().to_lower() == "python.exe":
		var pythonw := python.get_base_dir().path_join("pythonw.exe")
		if FileAccess.file_exists(pythonw):
			return pythonw
	return python


func _resolve_python_executable() -> String:
	var env_py := OS.get_environment("RFALL_PYTHON")
	if env_py != "" and FileAccess.file_exists(env_py):
		return env_py
	if OS.get_name() == "Windows":
		return "python"
	return "python3"
