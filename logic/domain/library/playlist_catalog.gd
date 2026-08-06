# logic/domain/library/playlist_catalog.gd
class_name PlaylistCatalog
extends RefCounted

const BUILTIN_FAVORITES_ID := "favorites"

const SCHEMA_VERSION := 2

const DISPLAY_MODE_FILTERED := "filtered"
const DISPLAY_MODE_ALL_CHARTS := "all_charts"

const _GoalDiff = preload("res://logic/domain/generation/generation_goal_difficulty.gd")


static func all_playlists() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	out.append({
		"id": BUILTIN_FAVORITES_ID,
		"name": "",
		"name_key": "PLAYLIST_FAVORITES_TITLE",
		"builtin": true,
	})
	if PlayerDataManager == null:
		return out
	for raw in PlayerDataManager.get_user_playlists():
		if raw is not Dictionary:
			continue
		var entry := normalize_playlist_entry(raw as Dictionary)
		var pid := str(entry.get("id", "")).strip_edges()
		if pid == "":
			continue
		out.append({
			"id": pid,
			"name": str(entry.get("name", "")).strip_edges(),
			"name_key": "",
			"builtin": false,
		})
	return out


static func user_playlists_only() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for entry in all_playlists():
		if bool(entry.get("builtin", false)):
			continue
		out.append(entry)
	return out


static func display_name(playlist_id: String) -> String:
	var pid := str(playlist_id).strip_edges()
	for entry in all_playlists():
		if str(entry.get("id", "")) == pid:
			var key := str(entry.get("name_key", "")).strip_edges()
			if key != "":
				return TranslationServer.translate(key)
			var name := str(entry.get("name", "")).strip_edges()
			if name != "":
				return name
			break
	return pid


static func is_valid_playlist_id(playlist_id: String) -> bool:
	var pid := str(playlist_id).strip_edges()
	if pid == "":
		return false
	for entry in all_playlists():
		if str(entry.get("id", "")) == pid:
			return true
	return false


static func is_user_playlist(playlist_id: String) -> bool:
	var pid := str(playlist_id).strip_edges()
	return pid != "" and pid != BUILTIN_FAVORITES_ID and is_valid_playlist_id(pid)


static func normalize_playlist_id(playlist_id: String) -> String:
	var pid := str(playlist_id).strip_edges()
	if is_valid_playlist_id(pid):
		return pid
	return BUILTIN_FAVORITES_ID


static func default_view_filter() -> Dictionary:
	return {
		"display_mode": DISPLAY_MODE_FILTERED,
		"goals": [_GoalDiff.DEFAULT_GOAL],
		"difficulties": _GoalDiff.DIFFICULTIES.duplicate(),
		"instrument": "drums",
		"lanes": 4,
		"notes_ready_only": true,
	}


static func normalize_view_filter(raw: Variant) -> Dictionary:
	var out := default_view_filter()
	if raw is not Dictionary:
		return out
	var src := raw as Dictionary
	var mode := str(src.get("display_mode", DISPLAY_MODE_FILTERED)).strip_edges().to_lower()
	if mode == DISPLAY_MODE_ALL_CHARTS:
		out["display_mode"] = DISPLAY_MODE_ALL_CHARTS
	else:
		out["display_mode"] = DISPLAY_MODE_FILTERED
	var goals := _sanitize_string_list(src.get("goals", []), _GoalDiff.GOALS)
	if goals.is_empty():
		goals = [_GoalDiff.DEFAULT_GOAL]
	out["goals"] = goals
	out["difficulties"] = _sanitize_string_list(src.get("difficulties", []), _GoalDiff.DIFFICULTIES)
	if out["difficulties"].is_empty():
		out["difficulties"] = _GoalDiff.DIFFICULTIES.duplicate()
	# Original has no difficulty tiers — keep stored diffs only for Arcade stems.
	var inst := str(src.get("instrument", "drums")).strip_edges().to_lower()
	out["instrument"] = inst if inst != "" else "drums"
	out["lanes"] = clampi(int(src.get("lanes", 4)), 1, 8)
	out["notes_ready_only"] = bool(src.get("notes_ready_only", true))
	return out


static func normalize_entry(raw: Dictionary) -> Dictionary:
	var pid := str(raw.get("id", "")).strip_edges()
	var name := str(raw.get("name", "")).strip_edges()
	var entries := _normalize_entries(raw)
	var view_filter := normalize_view_filter(raw.get("view_filter", {}))
	var preserve_order := bool(raw.get("preserve_order", true))
	return {
		"id": pid,
		"name": name,
		"schema_version": SCHEMA_VERSION,
		"view_filter": view_filter,
		"entries": entries,
		"preserve_order": preserve_order,
	}


static func normalize_playlist_entry(raw: Dictionary) -> Dictionary:
	if raw.is_empty():
		return {}
	var normalized := normalize_entry(raw)
	# Keep song_paths in sync for legacy readers until fully migrated.
	normalized["song_paths"] = entries_to_song_paths(normalized.get("entries", []))
	return normalized


static func playlist_raw(playlist_id: String) -> Dictionary:
	var pid := str(playlist_id).strip_edges()
	if pid == "" or pid == BUILTIN_FAVORITES_ID:
		return {}
	if PlayerDataManager == null:
		return {}
	var entry := PlayerDataManager.playlist_by_id(pid)
	if entry.is_empty():
		return {}
	return normalize_playlist_entry(entry)


static func entries_for(playlist_id: String) -> Array[Dictionary]:
	var pid := normalize_playlist_id(playlist_id)
	if pid == BUILTIN_FAVORITES_ID:
		var out: Array[Dictionary] = []
		for path in _favorite_song_paths():
			out.append({"song_path": path})
		return out
	var raw := playlist_raw(pid)
	return _normalize_entries(raw)


static func view_filter_for(playlist_id: String) -> Dictionary:
	if not is_user_playlist(playlist_id):
		return default_view_filter()
	var raw := playlist_raw(playlist_id)
	return normalize_view_filter(raw.get("view_filter", {}))


static func preserve_order_for(playlist_id: String) -> bool:
	if not is_user_playlist(playlist_id):
		return false
	var raw := playlist_raw(playlist_id)
	if raw.is_empty():
		return true
	return bool(raw.get("preserve_order", true))


static func song_paths_for(playlist_id: String) -> Array[String]:
	return entries_to_song_paths(entries_for(playlist_id))


static func entries_to_song_paths(entries: Variant) -> Array[String]:
	var out: Array[String] = []
	if entries is not Array:
		return out
	for item in entries:
		if item is not Dictionary:
			continue
		var path := str((item as Dictionary).get("song_path", "")).strip_edges()
		if path != "" and not out.has(path):
			out.append(path)
	return out


static func entry_key(entry: Dictionary) -> String:
	var path := str(entry.get("song_path", "")).strip_edges()
	if path == "":
		return ""
	var stem := str(entry.get("chart_stem", "")).strip_edges().to_lower()
	if stem == "":
		return path
	return "%s|%s" % [path, stem]


static func has_entry(entries: Array, song_path: String, chart_stem: String = "") -> bool:
	var key := entry_key({"song_path": song_path, "chart_stem": chart_stem})
	for item in entries:
		if item is not Dictionary:
			continue
		if entry_key(item as Dictionary) == key:
			return true
	return false


static func save_entries(
	playlist_id: String,
	entries: Variant,
	view_filter: Variant = null,
	name: String = ""
) -> bool:
	var pid := str(playlist_id).strip_edges()
	if pid == "" or pid == BUILTIN_FAVORITES_ID:
		return false
	if PlayerDataManager == null:
		return false
	var raw := PlayerDataManager.playlist_by_id(pid)
	if raw.is_empty():
		return false
	var normalized := normalize_playlist_entry(raw)
	normalized["entries"] = _normalize_entries({"entries": entries})
	normalized["song_paths"] = entries_to_song_paths(normalized["entries"])
	if view_filter is Dictionary:
		normalized["view_filter"] = normalize_view_filter(view_filter)
	if str(name).strip_edges() != "":
		normalized["name"] = str(name).strip_edges()
	PlayerDataManager.save_playlist(normalized)
	return true


static func save_song_paths(playlist_id: String, paths: Variant) -> bool:
	var entries: Array[Dictionary] = []
	if paths is Array:
		for item in paths:
			var path := str(item).strip_edges()
			if path == "":
				continue
			entries.append({"song_path": path})
	return save_entries(playlist_id, entries)


static func rename_playlist(playlist_id: String, name: String) -> bool:
	var pid := str(playlist_id).strip_edges()
	if not is_user_playlist(pid):
		return false
	var trimmed := str(name).strip_edges()
	if trimmed == "":
		return false
	var raw := playlist_raw(pid)
	if raw.is_empty():
		return false
	raw["name"] = trimmed
	PlayerDataManager.save_playlist(raw)
	return true


static func delete_playlist(playlist_id: String) -> bool:
	var pid := str(playlist_id).strip_edges()
	if not is_user_playlist(pid):
		return false
	if PlayerDataManager == null:
		return false
	return PlayerDataManager.delete_playlist(pid)


static func create_playlist(name: String) -> String:
	if PlayerDataManager == null:
		return ""
	var trimmed := str(name).strip_edges()
	if trimmed == "":
		trimmed = TranslationServer.translate("PLAYLIST_DEFAULT_NAME")
	var id := "pl_%d" % int(Time.get_unix_time_from_system())
	var entry := normalize_entry({
		"id": id,
		"name": trimmed,
		"entries": [],
		"view_filter": default_view_filter(),
	})
	PlayerDataManager.save_playlist(entry)
	return id


static func toggle_song_entry(playlist_id: String, song_path: String, chart_stem: String = "") -> bool:
	var pid := str(playlist_id).strip_edges()
	if not is_user_playlist(pid):
		return false
	var entries: Array = []
	for item in entries_for(pid):
		entries.append((item as Dictionary).duplicate(true))
	var key := entry_key({"song_path": song_path, "chart_stem": chart_stem})
	var found_idx := -1
	for i in range(entries.size()):
		if entry_key(entries[i] as Dictionary) == key:
			found_idx = i
			break
	if found_idx >= 0:
		entries.remove_at(found_idx)
	else:
		var new_entry := {"song_path": str(song_path).strip_edges()}
		var stem := str(chart_stem).strip_edges().to_lower()
		if stem != "" and _GoalDiff.is_chart_stem(stem):
			new_entry["chart_stem"] = stem
		entries.append(new_entry)
	return save_entries(pid, entries)


static func _normalize_entries(raw: Dictionary) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var seen: Dictionary = {}
	if raw.has("entries"):
		var entries_raw: Variant = raw.get("entries", [])
		if entries_raw is Array:
			for item in entries_raw:
				if item is not Dictionary:
					continue
				var entry := _sanitize_entry(item as Dictionary)
				if entry.is_empty():
					continue
				var key := entry_key(entry)
				if key == "" or seen.has(key):
					continue
				seen[key] = true
				out.append(entry)
	if not out.is_empty():
		return out
	for path in _sanitize_paths(raw.get("song_paths", [])):
		var entry := {"song_path": path}
		var key := entry_key(entry)
		if seen.has(key):
			continue
		seen[key] = true
		out.append(entry)
	return out


static func _sanitize_entry(raw: Dictionary) -> Dictionary:
	var path := str(raw.get("song_path", "")).strip_edges()
	if path == "":
		return {}
	var out := {"song_path": path}
	var stem := str(raw.get("chart_stem", "")).strip_edges().to_lower()
	if stem != "" and _GoalDiff.is_chart_stem(stem):
		out["chart_stem"] = stem
	return out


static func _sanitize_string_list(raw: Variant, allowed: Array) -> Array[String]:
	var out: Array[String] = []
	if raw is not Array:
		return out
	for item in raw:
		var key := str(item).strip_edges().to_lower()
		if key == "" or not allowed.has(key):
			continue
		if not out.has(key):
			out.append(key)
	return out


static func _favorite_song_paths() -> Array[String]:
	if PlayerDataManager == null:
		return []
	if PlayerDataManager.has_method("_ensure_favorite_song_paths"):
		PlayerDataManager._ensure_favorite_song_paths()
	var raw: Variant = PlayerDataManager.data.get("favorite_song_paths", PackedStringArray())
	var out: Array[String] = []
	if raw is PackedStringArray:
		for path in raw:
			var sid := str(path).strip_edges()
			if sid != "" and not out.has(sid):
				out.append(sid)
	elif raw is Array:
		for item in raw:
			var sid := str(item).strip_edges()
			if sid != "" and not out.has(sid):
				out.append(sid)
	return out


static func _sanitize_paths(raw: Variant) -> Array[String]:
	var out: Array[String] = []
	if raw is Array:
		for item in raw:
			var path := str(item).strip_edges()
			if path == "" or out.has(path):
				continue
			out.append(path)
	return out


## Endless playlist activity (launches + clears inside those runs).
static func get_activity(playlist_id: String) -> Dictionary:
	var pid := str(playlist_id).strip_edges()
	if pid == "" or PlayerDataManager == null:
		return {"run_count": 0, "session_clears": 0, "last_played": ""}
	var root: Variant = PlayerDataManager.data.get("playlist_activity", {})
	if root is not Dictionary:
		return {"run_count": 0, "session_clears": 0, "last_played": ""}
	var entry: Variant = (root as Dictionary).get(pid, {})
	if entry is not Dictionary:
		return {"run_count": 0, "session_clears": 0, "last_played": ""}
	var d := entry as Dictionary
	return {
		"run_count": maxi(0, int(d.get("run_count", 0))),
		"session_clears": maxi(0, int(d.get("session_clears", 0))),
		"last_played": str(d.get("last_played", "")).strip_edges(),
	}


static func _ensure_activity_root() -> Dictionary:
	if PlayerDataManager == null:
		return {}
	if not PlayerDataManager.data.has("playlist_activity") \
		or not PlayerDataManager.data["playlist_activity"] is Dictionary:
		PlayerDataManager.data["playlist_activity"] = {}
	return PlayerDataManager.data["playlist_activity"] as Dictionary


static func _write_activity_entry(playlist_id: String, entry: Dictionary) -> void:
	var pid := str(playlist_id).strip_edges()
	if pid == "" or PlayerDataManager == null:
		return
	var root := _ensure_activity_root()
	root[pid] = entry
	PlayerDataManager.data["playlist_activity"] = root
	if PlayerDataManager.has_method("flush_save"):
		PlayerDataManager.flush_save()


static func record_playlist_run(playlist_id: String, datetime_iso: String = "") -> void:
	var pid := str(playlist_id).strip_edges()
	if pid == "" or PlayerDataManager == null:
		return
	var prev := get_activity(pid)
	var iso := datetime_iso.strip_edges()
	if iso == "":
		iso = TimeUtils.now_local_datetime_string() if typeof(TimeUtils) != TYPE_NIL else ""
	_write_activity_entry(pid, {
		"run_count": int(prev.get("run_count", 0)) + 1,
		"session_clears": int(prev.get("session_clears", 0)),
		"last_played": iso if iso != "" else str(prev.get("last_played", "")),
	})


static func record_playlist_session_clear(playlist_id: String) -> void:
	var pid := str(playlist_id).strip_edges()
	if pid == "" or PlayerDataManager == null:
		return
	var prev := get_activity(pid)
	var iso := TimeUtils.now_local_datetime_string() if typeof(TimeUtils) != TYPE_NIL else ""
	_write_activity_entry(pid, {
		"run_count": int(prev.get("run_count", 0)),
		"session_clears": int(prev.get("session_clears", 0)) + 1,
		"last_played": iso if iso != "" else str(prev.get("last_played", "")),
	})
