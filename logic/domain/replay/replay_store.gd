# logic/domain/replay/replay_store.gd
extends RefCounted
class_name ReplayStore

const _RfrCodec = preload("res://logic/platform/rfr_replay_codec.gd")

const REPLAYS_DIR := "user://replays/"


static func replays_dir() -> String:
	if SettingsManager:
		return SettingsManager.get_replay_save_folder()
	return REPLAYS_DIR


static func ensure_dir() -> void:
	var path := absolute_path(replays_dir())
	DirAccess.make_dir_recursive_absolute(path)


static func default_filename(payload: Dictionary) -> String:
	var track: Dictionary = payload.get("track", {}) if payload.get("track", {}) is Dictionary else {}
	var chart: Dictionary = payload.get("chart", {}) if payload.get("chart", {}) is Dictionary else {}
	var chart_id := String(track.get("chart_id", "")).strip_edges()
	if chart_id == "":
		chart_id = "run"
	var instrument := String(chart.get("instrument", "drums")).strip_edges().to_lower()
	var stamp := int(payload.get("created_at", Time.get_unix_time_from_system()))
	return "%s_%s_%d.%s" % [chart_id, instrument, stamp, _RfrCodec.FILE_EXTENSION]


static func absolute_path(rel_or_abs: String) -> String:
	var path := rel_or_abs.strip_edges().replace("\\", "/")
	if path.begins_with("user://") or path.begins_with("res://"):
		return ProjectSettings.globalize_path(path).replace("\\", "/")
	return path


static func save_payload(payload: Dictionary, rel_path: String = "") -> String:
	if payload.is_empty():
		return ""
	ensure_dir()
	var base_dir := replays_dir()
	var target_rel := rel_path.strip_edges()
	if target_rel == "":
		target_rel = "%s%s" % [base_dir, default_filename(payload)]
	elif not target_rel.begins_with("user://") and not target_rel.begins_with("res://"):
		if not target_rel.contains("/") and not target_rel.contains("\\"):
			target_rel = base_dir + target_rel.get_file()
	var abs := absolute_path(target_rel)
	DirAccess.make_dir_recursive_absolute(abs.get_base_dir())
	var file := FileAccess.open(abs, FileAccess.WRITE)
	if file == null:
		push_warning("ReplayStore: cannot write %s" % abs)
		return ""
	file.store_string(_RfrCodec.serialize(payload))
	if target_rel.begins_with("user://") or target_rel.begins_with("res://"):
		return target_rel
	return abs


static func import_external(abs_path: String) -> String:
	var payload := RfrReplayCodec.read_file(abs_path)
	if payload.is_empty():
		return ""
	var copied := save_payload(payload)
	return copied


static func list_for_chart(chart_id: String) -> Array[String]:
	var out: Array[String] = []
	var cid := chart_id.strip_edges()
	var dir_path := absolute_path(replays_dir())
	if cid == "" or not DirAccess.dir_exists_absolute(dir_path):
		return out
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return out
	dir.list_dir_begin()
	var name := dir.get_next()
	while name != "":
		if not dir.current_is_dir() and name.ends_with(".%s" % _RfrCodec.FILE_EXTENSION):
			if cid == "" or name.begins_with("%s_" % cid):
				out.append(dir_path.path_join(name))
		name = dir.get_next()
	dir.list_dir_end()
	out.sort()
	out.reverse()
	return out
