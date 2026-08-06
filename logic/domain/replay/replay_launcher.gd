# logic/domain/replay/replay_launcher.gd
extends RefCounted
class_name ReplayLauncher

const _RfrCodec = preload("res://logic/platform/rfr_replay_codec.gd")
const _ReplayStore = preload("res://logic/domain/replay/replay_store.gd")
const _StatusToast = preload("res://logic/ui/status_toast.gd")

static var _pending_path: String = ""


static func queue_path(abs_path: String) -> void:
	_pending_path = abs_path.strip_edges()


static func take_pending_path() -> String:
	var path := _pending_path
	_pending_path = ""
	return path


static func consume_cmdline_args(args: PackedStringArray) -> void:
	for raw in args:
		var arg := String(raw).strip_edges()
		if arg.begins_with('"'):
			arg = arg.trim_prefix('"').trim_suffix('"')
		if arg.to_lower().ends_with(".%s" % _RfrCodec.FILE_EXTENSION):
			queue_path(arg)
			return


static func open_file_dialog(_on_tree: SceneTree, host: Node, callback: Callable = Callable()) -> void:
	if host == null:
		return
	var start_dir := ProjectSettings.globalize_path(_ReplayStore.replays_dir()).replace("\\", "/")
	DisplayServer.file_dialog_show(
		TranslationServer.translate("REPLAY_OPEN_DIALOG_TITLE"),
		start_dir,
		"",
		false,
		DisplayServer.FILE_DIALOG_MODE_OPEN_FILE,
		PackedStringArray(["*.%s ; RhythmFall Replay" % _RfrCodec.FILE_EXTENSION]),
		func(status: bool, paths: PackedStringArray, _idx: int) -> void:
			if not status or paths.is_empty():
				return
			var path := String(paths[0])
			if callback.is_valid():
				callback.call(path)
			else:
				open_replay_path(host, path)
	)


static func save_file_dialog(host: Node, default_name: String, payload: Dictionary) -> void:
	if host == null or payload.is_empty():
		return
	var start_dir := ProjectSettings.globalize_path(_ReplayStore.replays_dir()).replace("\\", "/")
	DisplayServer.file_dialog_show(
		TranslationServer.translate("REPLAY_SAVE_DIALOG_TITLE"),
		start_dir,
		default_name,
		false,
		DisplayServer.FILE_DIALOG_MODE_SAVE_FILE,
		PackedStringArray(["*.%s ; RhythmFall Replay" % _RfrCodec.FILE_EXTENSION]),
		func(status: bool, paths: PackedStringArray, _idx: int) -> void:
			if not status or paths.is_empty():
				return
			var path := String(paths[0])
			if not path.to_lower().ends_with(".%s" % _RfrCodec.FILE_EXTENSION):
				path += ".%s" % _RfrCodec.FILE_EXTENSION
			var file := FileAccess.open(path, FileAccess.WRITE)
			if file == null:
				_notify(host, TranslationServer.translate("REPLAY_ERR_READ"), "error")
				return
			file.store_string(_RfrCodec.serialize(payload))
			_notify(host, TranslationServer.translate("REPLAY_SAVED_TOAST"), "success")
	)


static func open_replay_path(host: Node, abs_path: String) -> bool:
	var payload := _RfrCodec.read_file(abs_path)
	if payload.is_empty():
		_notify(host, TranslationServer.translate("REPLAY_ERR_READ"), "error")
		return false
	return launch_payload(host, payload, abs_path)


static func launch_payload(host: Node, payload: Dictionary, source_path: String = "") -> bool:
	var resolved := ReplayResolver.resolve(payload)
	if not bool(resolved.get("ok", false)):
		_notify(host, _format_resolve_error(resolved), "warning")
		return false
	var song_data: Dictionary = resolved.get("song_data", {})
	var chart: Dictionary = resolved.get("chart", {})
	var run: Dictionary = resolved.get("run", {})
	var modifiers: Array = run.get("modifiers", []) if run.get("modifiers", []) is Array else []
	var transitions: Variant = _find_transitions(host)
	if transitions == null:
		_notify(host, TranslationServer.translate("REPLAY_ERR_NO_TRANSITIONS"), "error")
		return false
	if transitions.has_method("open_replay_run"):
		transitions.call(
			"open_replay_run",
			song_data,
			String(chart.get("instrument", "drums")),
			String(chart.get("mode", "original")),
			int(chart.get("lanes", 4)),
			modifiers,
			String(chart.get("chart_tag", "")),
			payload,
			source_path,
		)
		return true
	_notify(host, TranslationServer.translate("REPLAY_ERR_NO_TRANSITIONS"), "error")
	return false


static func _format_resolve_error(resolved: Dictionary) -> String:
	var key := String(resolved.get("message_key", "REPLAY_ERR_INVALID"))
	var args: Variant = resolved.get("message_args", [])
	var template := TranslationServer.translate(key)
	if template == key:
		return template
	if args is Array and not args.is_empty():
		return template % args
	return template


static func _find_transitions(host: Node) -> Variant:
	if host == null:
		return null
	if host.has_method("get_transitions"):
		return host.call("get_transitions")
	var tree := host.get_tree()
	if tree == null:
		return null
	for child in tree.root.get_children():
		if child.has_method("get_transitions"):
			return child.call("get_transitions")
	return null


static func _notify(host: Node, text: String, kind: String) -> void:
	if host:
		_StatusToast.show_from_node(host, "replay", text, kind)
