# logic/services/generation_gpu_stack.gd
class_name GenerationGpuStack
extends RefCounted

## Reinstall CUDA / DirectML / CPU packages in the local RhythmFallServer .venv.

const ProfileShareRenderWorker = preload("res://scenes/profile/share/profile_share_render_worker.gd")

const GPU_MODES := ["auto", "nvidia", "amd", "cpu"]


static func normalize_mode(mode: String) -> String:
	var m := mode.strip_edges().to_lower()
	if m in GPU_MODES:
		return m
	return "auto"


static func is_windows() -> bool:
	return OS.get_name() == "Windows"


static func is_lan_mode() -> bool:
	if SettingsManager == null:
		return false
	return bool(SettingsManager.get_setting("generation_server_use_lan_host", false))


static func resolve_install_script() -> String:
	var candidates: PackedStringArray = PackedStringArray()
	var exe_base := OS.get_executable_path().get_base_dir()
	if exe_base != "":
		candidates.append(exe_base.path_join("worker").path_join("install_windows_server.ps1"))
	candidates.append(ProjectSettings.globalize_path("res://worker/install_windows_server.ps1"))
	for path in candidates:
		var p := str(path).strip_edges().replace("\\", "/")
		if p != "" and FileAccess.file_exists(p):
			return p
	return ""


static func resolve_server_root() -> String:
	if GenerationProcessManager and GenerationProcessManager.has_method("resolve_server_root_dir"):
		return str(GenerationProcessManager.resolve_server_root_dir())
	return ""


static func format_backend_status(health: Dictionary) -> String:
	var gpu: Variant = health.get("gpu", {})
	if gpu is Dictionary and not (gpu as Dictionary).is_empty():
		var stems := str((gpu as Dictionary).get("stems_detail", "")).strip_edges()
		if stems == "":
			stems = str((gpu as Dictionary).get("stems", "cpu")).strip_edges()
		var adtof := str((gpu as Dictionary).get("adtof_detail", "")).strip_edges()
		if adtof == "":
			adtof = str((gpu as Dictionary).get("adtof", "")).strip_edges()
		if adtof != "":
			return "%s · ADTOF %s" % [stems, adtof]
		return stems
	var marker := _read_gpu_marker()
	if marker != "":
		return marker
	return ""


## Returns nvidia | amd | cpu | "" for the packages currently on disk / reported by /health.
static func resolve_installed_mode(health: Dictionary = {}) -> String:
	var payload := health
	if payload.is_empty() and GenerationProcessManager:
		payload = GenerationProcessManager.fetch_health_payload()
	if payload.get("ok", false):
		var gpu: Variant = payload.get("gpu", {})
		if gpu is Dictionary:
			var stems := str((gpu as Dictionary).get("stems", "")).strip_edges().to_lower()
			if stems == "cuda":
				return "nvidia"
			if stems == "directml":
				return "amd"
			if stems == "cpu":
				return "cpu"
	return normalize_mode(_read_gpu_marker()) if _read_gpu_marker() in ["nvidia", "amd", "cpu"] else ""


static func _read_gpu_marker() -> String:
	var root := resolve_server_root()
	if root == "":
		return ""
	var marker := root.path_join(".gpu_stack")
	if not FileAccess.file_exists(marker):
		return ""
	return FileAccess.get_file_as_string(marker).strip_edges().to_lower()


## Probe Win32 video controllers. Fast; safe to call on the main thread.
static func detect_hardware() -> Dictionary:
	var empty := {
		"ok": false,
		"names": PackedStringArray(),
		"has_nvidia": false,
		"has_amd": false,
		"recommended": "cpu",
		"detail": "",
	}
	if not is_windows():
		empty["detail"] = "not windows"
		return empty
	var ps := (
		"Get-CimInstance Win32_VideoController "
		+ "| ForEach-Object { $_.Name } "
		+ "| Where-Object { $_ -and ($_ -notmatch 'Virtual|Basic Display|Microsoft Remote') }"
	)
	var output: Array = []
	var code := OS.execute(
		"powershell.exe",
		PackedStringArray(["-NoProfile", "-ExecutionPolicy", "Bypass", "-Command", ps]),
		output,
		true,
		false
	)
	var names := PackedStringArray()
	for line in output:
		var s := str(line).strip_edges()
		if s != "":
			names.append(s)
	var has_nvidia := false
	var has_amd := false
	for n in names:
		var low := str(n).to_lower()
		if "nvidia" in low:
			has_nvidia = true
		if "amd" in low or "radeon" in low:
			has_amd = true
	var recommended := "cpu"
	if has_nvidia:
		recommended = "nvidia"
	elif has_amd:
		recommended = "amd"
	return {
		"ok": code == 0,
		"names": names,
		"has_nvidia": has_nvidia,
		"has_amd": has_amd,
		"recommended": recommended,
		"detail": "\n".join(names),
	}


static func mode_label_key(mode: String) -> String:
	match normalize_mode(mode):
		"nvidia":
			return "MISC_GPU_STACK_NVIDIA"
		"amd":
			return "MISC_GPU_STACK_AMD"
		"cpu":
			return "MISC_GPU_STACK_CPU"
		_:
			return "MISC_GPU_STACK_AUTO"


static func reinstall_async(mode: String, preference: String = "") -> Dictionary:
	if not is_windows():
		return {"ok": false, "error_key": "MISC_GPU_STACK_WINDOWS_ONLY"}
	if is_lan_mode():
		return {"ok": false, "error_key": "MISC_GPU_STACK_LAN_BLOCKED"}
	var script := resolve_install_script()
	if script == "":
		return {"ok": false, "error_key": "MISC_GPU_STACK_SCRIPT_MISSING"}
	var server_root := resolve_server_root()
	if server_root == "":
		return {"ok": false, "error_key": "MISC_GPU_STACK_SERVER_MISSING"}
	var gpu := normalize_mode(mode)
	var pref := normalize_mode(preference) if preference.strip_edges() != "" else gpu
	if SettingsManager:
		SettingsManager.set_setting("generation_gpu_stack", pref)

	if GenerationProcessManager:
		GenerationProcessManager.force_stop_local_worker()
	await _wait_local_port_free(12.0)

	var args := PackedStringArray([
		"-NoProfile",
		"-ExecutionPolicy",
		"Bypass",
		"-File",
		script.replace("/", "\\"),
		"-ServerRoot",
		server_root.replace("/", "\\"),
		"-Gpu",
		gpu,
	])
	var result: Dictionary = await ProfileShareRenderWorker.execute_async("powershell.exe", args)
	var exit_code := int(result.get("exit_code", -1))
	if exit_code != 0:
		return {
			"ok": false,
			"error_key": "MISC_GPU_STACK_FAILED",
			"detail": str(result.get("detail", "")).strip_edges(),
			"exit_code": exit_code,
		}

	var restart: Dictionary = {}
	if GenerationProcessManager and GenerationProcessManager.should_auto_manage():
		restart = await _restart_worker()
	return {
		"ok": true,
		"mode": gpu,
		"restart": restart,
		"detail": str(result.get("detail", "")).strip_edges(),
	}


static func _wait_local_port_free(timeout_sec: float) -> void:
	if GenerationProcessManager == null:
		return
	var tree := Engine.get_main_loop() as SceneTree
	var deadline := Time.get_ticks_msec() + int(timeout_sec * 1000.0)
	while Time.get_ticks_msec() < deadline:
		if not GenerationProcessManager.is_local_port_busy():
			return
		GenerationProcessManager.force_stop_local_worker()
		if tree:
			await tree.process_frame
			await tree.create_timer(0.25).timeout
		else:
			await Engine.get_main_loop().process_frame


static func _restart_worker() -> Dictionary:
	if GenerationProcessManager == null:
		return {"ok": false}
	var tree := Engine.get_main_loop() as SceneTree
	var result := GenerationProcessManager.ensure_running()
	var deadline := Time.get_ticks_msec() + 90000
	while result.get("pending", false) and Time.get_ticks_msec() < deadline:
		if tree:
			await tree.create_timer(0.5).timeout
		else:
			await Engine.get_main_loop().process_frame
		result = GenerationProcessManager.ensure_running()
	return result
