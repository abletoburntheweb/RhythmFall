# scenes/profile/share/profile_share_html_export.gd
class_name ProfileShareHtmlExport
extends RefCounted

const _Payload = preload("res://scenes/profile/share/profile_share_html_payload.gd")
const _RenderWorker = preload("res://scenes/profile/share/profile_share_render_worker.gd")

const HTML_DIR := "res://scenes/profile/share/html"
const RENDER_SCRIPT := "render_card.py"
const RENDER_BATCH_SCRIPT := "render_batch.py"
const CACHE_DIR := "user://share_cards_cache"

static var _html_available: int = -1  # -1 unknown, 0 no, 1 yes
static var _resolved_python: String = ""
static var _last_error: String = ""
static var _last_error_code: String = ""


static func get_last_error() -> String:
	return _last_error


static func get_last_error_code() -> String:
	return _last_error_code


static func is_available() -> bool:
	if _html_available >= 0:
		return _html_available == 1
	_probe_availability()
	return _html_available == 1


static func has_cached_availability() -> bool:
	return _html_available >= 0


static func invalidate_availability() -> void:
	_html_available = -1
	_resolved_python = ""


## True when Python + HTML templates exist so pip/playwright install can run (also for repair).
static func can_install_export_toolchain() -> bool:
	if _resolve_html_dir() == "":
		return false
	return _pick_python() != ""


static func install_export_toolchain_async() -> Dictionary:
	_last_error = ""
	_last_error_code = ""
	var html_dir := _resolve_html_dir()
	if html_dir == "":
		_set_error_code("E004")
		return {"ok": false, "error_code": "E004", "detail": "HTML templates not found"}
	var python := _pick_python()
	if python == "":
		_set_error_code("E001")
		return {"ok": false, "error_code": "E001", "detail": "Python not found"}

	var req_path := html_dir.path_join("requirements.txt").replace("\\", "/")
	if not FileAccess.file_exists(req_path):
		_set_error_code("E004")
		return {"ok": false, "error_code": "E004", "detail": "requirements.txt missing"}

	var pip_args := PackedStringArray(["-m", "pip", "install", "-r", req_path])
	var pip_run: Dictionary = await _RenderWorker.execute_async(python, pip_args)
	if int(pip_run.get("exit_code", 1)) != 0:
		_last_error = str(pip_run.get("detail", ""))
		_set_error_code("E002")
		return {"ok": false, "error_code": "E002", "detail": _last_error}

	var browser_ok := false
	for browser in ["msedge", "chromium"]:
		var br_args := PackedStringArray(["-m", "playwright", "install", browser])
		var br_run: Dictionary = await _RenderWorker.execute_async(python, br_args)
		if int(br_run.get("exit_code", 1)) == 0:
			browser_ok = true
			break
		_last_error = str(br_run.get("detail", ""))

	invalidate_availability()
	_probe_availability()
	if _html_available == 1:
		return {"ok": true, "error_code": "", "detail": ""}
	if not browser_ok:
		_set_error_code("E003")
		return {"ok": false, "error_code": "E003", "detail": _last_error}
	_set_error_code("E002")
	return {"ok": false, "error_code": _last_error_code, "detail": _last_error}


static func render_to_png(card_id: String, data: Dictionary, out_path: String,
		size: Vector2i = Vector2i(1080, 1920), device_scale: float = 1.0) -> Dictionary:
	_last_error = ""
	_last_error_code = ""
	if not is_available():
		return {"ok": false, "error_key": "PROFILE_SHARE_EXPORT_ERR_CODE", "error_code": _last_error_code, "detail": _last_error}

	var html_dir := _resolve_html_dir()
	if html_dir == "":
		_last_error = "html dir missing"
		_set_error_code("E004")
		return {"ok": false, "error_key": "PROFILE_SHARE_EXPORT_ERR_CODE", "error_code": _last_error_code, "detail": _last_error}

	var payload := _Payload.build(card_id, data)
	var job_dir := _ensure_cache_dir()
	var payload_path := "%s/job_%s.json" % [job_dir, card_id]
	var write_err := _write_json(payload_path, payload)
	if write_err != OK:
		_last_error = "payload write %s" % str(write_err)
		_set_error_code("E006")
		return {"ok": false, "error_key": "PROFILE_SHARE_EXPORT_ERR_CODE", "error_code": _last_error_code, "detail": _last_error}

	var script_path := html_dir.path_join(RENDER_SCRIPT)
	var payload_abs := ProjectSettings.globalize_path(payload_path).replace("\\", "/")
	var out_abs := out_path.replace("\\", "/")

	var run := await _run_render_script_async(script_path, html_dir, payload_abs, out_abs, size, device_scale)
	if not run.get("ok", false):
		_last_error = str(run.get("detail", ""))
		return {
			"ok": false,
			"error_key": "PROFILE_SHARE_EXPORT_ERR_CODE",
			"error_code": str(run.get("error_code", _last_error_code)),
			"detail": _last_error,
		}

	if not FileAccess.file_exists(out_abs):
		_last_error = "png not created"
		_set_error_code("E005")
		return {"ok": false, "error_key": "PROFILE_SHARE_EXPORT_ERR_CODE", "error_code": _last_error_code, "detail": _last_error}

	return {"ok": true, "path": out_abs, "backend": "html"}


static func render_preview_batch(items: Array, render_size: Vector2i,
		device_scale: float = 1.0) -> Dictionary:
	_last_error = ""
	_last_error_code = ""
	var out: Dictionary = {}
	if items.is_empty():
		return out
	if not is_available():
		for item in items:
			out[str(item.get("card_id", ""))] = null
		return out

	var stats_hash := _items_data_hash(items)
	var all_cached := true
	for item in items:
		var card_id := str(item.get("card_id", ""))
		if card_id == "":
			continue
		var cache_path := "%s/%s_preview_%dx%d_%s.png" % [CACHE_DIR, card_id, render_size.x, render_size.y, stats_hash]
		var abs_cache := ProjectSettings.globalize_path(cache_path).replace("\\", "/")
		if FileAccess.file_exists(abs_cache):
			out[card_id] = Image.load_from_file(abs_cache)
		else:
			all_cached = false
	if all_cached and out.size() == items.size():
		_prune_cache_except(stats_hash)
		return out
	out.clear()

	var html_dir := _resolve_html_dir()
	if html_dir == "":
		_set_error_code("E004")
		for item in items:
			out[str(item.get("card_id", ""))] = null
		return out

	var job_dir := _ensure_cache_dir()
	var jobs: Array = []
	for item in items:
		var card_id := str(item.get("card_id", ""))
		var data: Dictionary = item.get("data", {})
		if card_id == "":
			continue
		var payload := _Payload.build(card_id, data)
		var payload_path := "%s/batch_%s_%s.json" % [job_dir, card_id, stats_hash]
		if _write_json(payload_path, payload) != OK:
			_set_error_code("E006")
			out[card_id] = null
			continue
		var cache_path := "%s/%s_preview_%dx%d_%s.png" % [CACHE_DIR, card_id, render_size.x, render_size.y, stats_hash]
		var abs_out := ProjectSettings.globalize_path(cache_path).replace("\\", "/")
		jobs.append({
			"payload": ProjectSettings.globalize_path(payload_path).replace("\\", "/"),
			"out": abs_out,
		})

	if jobs.is_empty():
		return out

	var manifest_path := "%s/batch_manifest.json" % job_dir
	var manifest := {
		"html_dir": html_dir,
		"width": render_size.x,
		"height": render_size.y,
		"device_scale_factor": device_scale,
		"jobs": jobs,
	}
	if _write_json(manifest_path, manifest) != OK:
		_set_error_code("E006")
		for item in items:
			out[str(item.get("card_id", ""))] = null
		return out

	var script_path := html_dir.path_join(RENDER_BATCH_SCRIPT)
	var manifest_abs := ProjectSettings.globalize_path(manifest_path).replace("\\", "/")
	var run := await _run_batch_script_async(script_path, manifest_abs)
	if not run.get("ok", false):
		_last_error = str(run.get("detail", ""))
		for item in items:
			out[str(item.get("card_id", ""))] = null
		return out

	for item in items:
		var card_id := str(item.get("card_id", ""))
		var cache_path := "%s/%s_preview_%dx%d_%s.png" % [CACHE_DIR, card_id, render_size.x, render_size.y, stats_hash]
		var abs_cache := ProjectSettings.globalize_path(cache_path).replace("\\", "/")
		if FileAccess.file_exists(abs_cache):
			out[card_id] = Image.load_from_file(abs_cache)
		else:
			out[card_id] = null
	_prune_cache_except(stats_hash)
	return out


static func render_preview_one(card_id: String, data: Dictionary, render_size: Vector2i,
		device_scale: float = 1.0) -> Image:
	_last_error = ""
	_last_error_code = ""
	if card_id == "":
		return null
	var items: Array = [{"card_id": card_id, "data": data}]
	var stats_hash := _items_data_hash(items)
	var cache_path := "%s/%s_preview_%dx%d_%s.png" % [CACHE_DIR, card_id, render_size.x, render_size.y, stats_hash]
	var abs_cache := ProjectSettings.globalize_path(cache_path).replace("\\", "/")
	if FileAccess.file_exists(abs_cache):
		_prune_cache_except(stats_hash)
		return Image.load_from_file(abs_cache)
	if not is_available():
		return null
	var run := await render_to_png(card_id, data, abs_cache, render_size, device_scale)
	if not run.get("ok", false):
		return null
	_prune_cache_except(stats_hash)
	if FileAccess.file_exists(abs_cache):
		return Image.load_from_file(abs_cache)
	return null


static func render_export_batch(items: Array, size: Vector2i,
		device_scale: float = 1.0) -> Dictionary:
	_last_error = ""
	_last_error_code = ""
	if items.is_empty():
		return {"ok": true, "paths": []}
	if not is_available():
		return {"ok": false, "error_code": _last_error_code}

	var html_dir := _resolve_html_dir()
	if html_dir == "":
		_set_error_code("E004")
		return {"ok": false, "error_code": _last_error_code}

	var job_dir := _ensure_cache_dir()
	var jobs: Array = []
	var paths: Array[String] = []
	for item in items:
		var card_id := str(item.get("card_id", ""))
		var data: Dictionary = item.get("data", {})
		var out_path := str(item.get("out_path", "")).replace("\\", "/")
		if card_id == "" or out_path == "":
			continue
		var payload := _Payload.build(card_id, data)
		var payload_path := "%s/export_%s.json" % [job_dir, card_id]
		if _write_json(payload_path, payload) != OK:
			_set_error_code("E006")
			return {"ok": false, "error_code": _last_error_code}
		DirAccess.make_dir_recursive_absolute(out_path.get_base_dir())
		jobs.append({
			"payload": ProjectSettings.globalize_path(payload_path).replace("\\", "/"),
			"out": out_path,
		})
		paths.append(out_path)

	if jobs.is_empty():
		_set_error_code("E005")
		return {"ok": false, "error_code": _last_error_code}

	var manifest_path := "%s/export_manifest.json" % job_dir
	var manifest := {
		"html_dir": html_dir,
		"width": size.x,
		"height": size.y,
		"device_scale_factor": device_scale,
		"jobs": jobs,
	}
	if _write_json(manifest_path, manifest) != OK:
		_set_error_code("E006")
		return {"ok": false, "error_code": _last_error_code}

	var script_path := html_dir.path_join(RENDER_BATCH_SCRIPT)
	var manifest_abs := ProjectSettings.globalize_path(manifest_path).replace("\\", "/")
	var run := await _run_batch_script_async(script_path, manifest_abs)
	if not run.get("ok", false):
		return {"ok": false, "error_code": _last_error_code}
	return {"ok": true, "paths": paths}


static func render_to_image(card_id: String, data: Dictionary,
		size: Vector2i = Vector2i(1080, 1920), device_scale: float = 1.0) -> Image:
	var cache_path := "%s/%s_%dx%d.png" % [CACHE_DIR, card_id, size.x, size.y]
	var abs_cache := ProjectSettings.globalize_path(cache_path).replace("\\", "/")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(CACHE_DIR))

	var result: Dictionary = await render_to_png(card_id, data, abs_cache, size, device_scale)
	if not result.get("ok", false):
		return null
	return Image.load_from_file(abs_cache)


static func _probe_availability() -> void:
	_html_available = 0
	_resolved_python = ""
	_last_error = ""
	_last_error_code = ""

	if _resolve_html_dir() == "":
		_last_error = "HTML templates not found"
		_set_error_code("E004")
		return

	var python := _pick_python()
	if python == "":
		_last_error = "Python not found"
		_set_error_code("E001")
		return

	if not _python_has_playwright(python):
		_last_error = "Playwright missing"
		_set_error_code("E002")
		return

	_resolved_python = python
	_html_available = 1


static func _set_error_code(code: String) -> void:
	_last_error_code = code


static func _run_batch_script_async(script_path: String, manifest_abs: String) -> Dictionary:
	var tail := PackedStringArray(["--manifest", manifest_abs])
	for launch in _python_launch_attempts(script_path, tail):
		var exec_result: Dictionary = await _RenderWorker.execute_async(
			str(launch.get("cmd", "")),
			launch.get("args", PackedStringArray()),
		)
		var exit_code := int(exec_result.get("exit_code", 1))
		var detail := str(exec_result.get("detail", ""))
		if exit_code == 0:
			return {"ok": true, "detail": detail}
		_last_error = detail

	var err_code := _map_exit_error_code(_last_error)
	_set_error_code(err_code)
	return {"ok": false, "error_code": err_code, "detail": _last_error}


static func _run_render_script_async(script_path: String, html_dir: String,
		payload_abs: String, out_abs: String, size: Vector2i, device_scale: float = 1.0) -> Dictionary:
	DirAccess.make_dir_recursive_absolute(out_abs.get_base_dir())

	var tail := PackedStringArray([
		"--html-dir", html_dir,
		"--payload", payload_abs,
		"--out", out_abs,
		"--width", str(size.x),
		"--height", str(size.y),
		"--device-scale-factor", str(device_scale),
	])

	for launch in _python_launch_attempts(script_path, tail):
		var exec_result: Dictionary = await _RenderWorker.execute_async(
			str(launch.get("cmd", "")),
			launch.get("args", PackedStringArray()),
		)
		var exit_code := int(exec_result.get("exit_code", 1))
		var detail := str(exec_result.get("detail", ""))
		if exit_code == 0:
			return {"ok": true, "detail": detail}
		_last_error = detail

	var err_code := _map_exit_error_code(_last_error)
	_set_error_code(err_code)
	return {"ok": false, "error_code": err_code, "detail": _last_error}


static func _python_launch_attempts(script_path: String, tail: PackedStringArray) -> Array:
	var attempts: Array = []
	var seen: Dictionary = {}

	var add_attempt := func(cmd: String, prefix: PackedStringArray) -> void:
		if cmd == "" or seen.has(cmd):
			return
		seen[cmd] = true
		var args := prefix.duplicate()
		for a in tail:
			args.append(a)
		attempts.append({"cmd": cmd, "args": args})

	if _resolved_python != "":
		add_attempt.call(_resolved_python, PackedStringArray([script_path]))
	if OS.get_name() == "Windows":
		add_attempt.call("py", PackedStringArray(["-3", script_path]))
	add_attempt.call("python" if OS.get_name() == "Windows" else "python3", PackedStringArray([script_path]))

	for extra in _python_candidates():
		add_attempt.call(extra, PackedStringArray([script_path]))
	return attempts


static func _python_has_playwright(python: String) -> bool:
	var output: Array = []
	var code := OS.execute(python, ["-c", "import playwright"], output, true, false)
	return code == 0


static func _pick_python() -> String:
	for candidate in _python_candidates():
		if candidate == "":
			continue
		if _python_runnable(candidate):
			return candidate
	return ""


static func _python_runnable(python: String) -> bool:
	var cmd := python.strip_edges()
	if cmd == "":
		return false
	# Absolute paths: skip missing files instead of waiting on a failed OS.execute.
	var looks_path := cmd.contains("/") or cmd.contains("\\") or cmd.ends_with(".exe")
	if looks_path and not FileAccess.file_exists(cmd):
		return false
	var output: Array = []
	var code := OS.execute(cmd, ["--version"], output, true, false)
	return code == 0


static func probe_availability_async() -> bool:
	## Non-blocking availability check for Settings → Data (Playwright probe).
	if _html_available >= 0:
		return _html_available == 1
	_html_available = 0
	_resolved_python = ""
	_last_error = ""
	_last_error_code = ""

	if _resolve_html_dir() == "":
		_last_error = "HTML templates not found"
		_set_error_code("E004")
		return false

	var python := _pick_python()
	if python == "":
		_last_error = "Python not found"
		_set_error_code("E001")
		return false

	var run: Dictionary = await _RenderWorker.execute_async(
		python,
		PackedStringArray(["-c", "import playwright"])
	)
	if int(run.get("exit_code", 1)) != 0:
		_last_error = "Playwright missing"
		_set_error_code("E002")
		return false

	_resolved_python = python
	_html_available = 1
	return true


static func _python_candidates() -> Array[String]:
	var out: Array[String] = []

	var env_py := OS.get_environment("RFALL_PYTHON").strip_edges()
	if env_py != "":
		out.append(env_py.replace("\\", "/"))

	for path_file in [
		ProjectSettings.globalize_path("res://worker/windows_python.path"),
		OS.get_executable_path().get_base_dir().path_join("worker").path_join("windows_python.path"),
	]:
		if path_file != "" and FileAccess.file_exists(path_file):
			var custom := FileAccess.get_file_as_string(path_file).strip_edges()
			if custom != "":
				out.append(custom.replace("\\", "/"))

	for server_dir in [
		ProjectSettings.globalize_path("res://RhythmFallServer-main"),
		ProjectSettings.globalize_path("res://RhythmFallServer"),
	]:
		if server_dir != "" and DirAccess.dir_exists_absolute(server_dir):
			out.append(server_dir.path_join(".venv").path_join("Scripts").path_join("python.exe").replace("\\", "/"))

	if OS.get_name() == "Windows":
		var local := OS.get_environment("LOCALAPPDATA")
		if local != "":
			for ver in ["Python313", "Python312", "Python311", "Python310"]:
				out.append(local.path_join("Programs/Python").path_join(ver).path_join("python.exe").replace("\\", "/"))
		out.append("py")
		out.append("python")
	else:
		out.append("python3")
		out.append("python")

	return out


static func _items_data_hash(items: Array) -> String:
	var ctx := HashingContext.new()
	ctx.start(HashingContext.HASH_SHA256)
	for item in items:
		if not item is Dictionary:
			continue
		var card_id := str(item.get("card_id", ""))
		var data: Variant = item.get("data", {})
		ctx.update((card_id + JSON.stringify(data)).to_utf8_buffer())
	return ctx.finish().hex_encode().substr(0, 12)


static func _ensure_cache_dir() -> String:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(CACHE_DIR))
	return CACHE_DIR


## Drop stale preview PNGs / job JSON that do not belong to the current stats hash.
static func _prune_cache_except(keep_token: String) -> void:
	var token := keep_token.strip_edges()
	if token == "":
		return
	var abs_dir := ProjectSettings.globalize_path(CACHE_DIR)
	var dir := DirAccess.open(abs_dir)
	if dir == null:
		return
	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if not dir.current_is_dir() and not file_name.contains(token):
			dir.remove(file_name)
		file_name = dir.get_next()
	dir.list_dir_end()


static func _write_json(path: String, payload: Dictionary) -> Error:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return ERR_CANT_CREATE
	file.store_string(JSON.stringify(payload, "\t"))
	file.close()
	return OK


static func _resolve_html_dir() -> String:
	var rel := HTML_DIR
	if not DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(rel)):
		return ""
	return ProjectSettings.globalize_path(rel).replace("\\", "/")


static func _format_process_output(output: Array) -> String:
	var lines: PackedStringArray = PackedStringArray()
	for line in output:
		var s := str(line).strip_edges()
		if s != "":
			lines.append(s)
	return "\n".join(lines)


static func _map_exit_error_code(detail: String) -> String:
	if detail.contains("PLAYWRIGHT_MISSING"):
		return "E002"
	if detail.contains("BROWSER_MISSING") or detail.contains("Could not launch browser"):
		return "E003"
	if detail.contains("SHELL_MISSING") or detail.contains("MANIFEST_MISSING"):
		return "E004"
	if detail.contains("RENDER_FAILED"):
		return "E005"
	return "E005"
