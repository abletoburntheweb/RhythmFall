# logic/data/daily_quests_manager.gd
extends Node

const GenreSearch = preload("res://logic/domain/library/genre_search.gd")

signal daily_quests_updated()

const DAILY_QUESTS_USER_PATH := "user://daily_quests.json"
const DAILY_QUESTS_DEFAULT_PATH := "res://data/daily_quests.json"

var pdm = null
var _genre_group_map: Dictionary = {}

func set_player_data_manager(pdm_ref):
	pdm = pdm_ref

func ensure_daily_quests_for_today():
	if pdm == null:
		return
	_load_genre_group_map_if_needed()
	var today = Time.get_date_string_from_system()
	var current = pdm.data.get("daily_quests", {"date": "", "quests": []})
	if current.get("date", "") != today:
		_generate_daily_quests_for_date(today)
		pdm._save()
		emit_signal("daily_quests_updated")

func _default_daily_quests_path() -> String:
	if FileAccess.file_exists(DAILY_QUESTS_DEFAULT_PATH):
		return DAILY_QUESTS_DEFAULT_PATH
	var exe_dir := OS.get_executable_path().get_base_dir()
	var ext := exe_dir.path_join("data/daily_quests.json").replace("\\", "/")
	if FileAccess.file_exists(ext):
		return ext
	return ""

func _ensure_user_daily_quests() -> void:
	if FileAccess.file_exists(DAILY_QUESTS_USER_PATH):
		return
	var default_path := _default_daily_quests_path()
	if default_path == "":
		return
	var src := FileAccess.open(default_path, FileAccess.READ)
	if src == null:
		return
	var txt := src.get_as_text()
	src.close()
	var dst := FileAccess.open(DAILY_QUESTS_USER_PATH, FileAccess.WRITE)
	if dst == null:
		push_warning("DailyQuests: не удалось создать daily_quests.json в user://")
		return
	dst.store_string(txt)
	dst.close()

func _load_quest_pool() -> Array:
	_ensure_user_daily_quests()
	var path := DAILY_QUESTS_USER_PATH if FileAccess.file_exists(DAILY_QUESTS_USER_PATH) else _default_daily_quests_path()
	if path == "" or not FileAccess.file_exists(path):
		push_warning("DailyQuests: не найден файл daily_quests.json")
		return []
	var file = FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_warning("DailyQuests: не удалось открыть daily_quests.json: " + path)
		return []
	var json_text = file.get_as_text()
	file.close()
	var parsed = JSON.parse_string(json_text)
	if parsed is Dictionary and parsed.has("quests") and (parsed["quests"] is Array):
		return parsed["quests"]
	push_warning("DailyQuests: некорректный формат daily_quests.json: " + path)
	return []

func _generate_daily_quests_for_date(date_str: String):
	if pdm == null:
		return
	var quests_for_day: Array = []
	var quest_pool: Array = _load_quest_pool()
	if quest_pool.is_empty():
		pdm.data["daily_quests"] = {"date": date_str, "quests": []}
		return
	var count_per_day = 3
	var indices: Array = []
	for i in range(quest_pool.size()):
		indices.append(i)
	indices.shuffle()
	for i in range(min(count_per_day, quest_pool.size())):
		var q = quest_pool[indices[i]].duplicate(true)
		q["progress"] = 0
		q["completed"] = false
		quests_for_day.append(q)
	pdm.data["daily_quests"] = {"date": date_str, "quests": quests_for_day}

func _normalize_quest_states(quests: Array, date_str: String) -> bool:
	var changed := false
	var day := date_str.strip_edges()
	for q in quests:
		if not q is Dictionary:
			continue
		var goal := int(q.get("goal", 1))
		var progress := int(q.get("progress", 0))
		if progress >= goal and not bool(q.get("completed", false)):
			q["completed"] = true
			changed = true
		if not bool(q.get("completed", false)):
			continue
		var completed_at := str(q.get("completed_at", "")).strip_edges()
		if completed_at == "":
			var backfill := _backfill_completed_at(day)
			q["completed_at"] = backfill
			_record_last_daily_quest_completion(q, backfill, true)
			changed = true
	return changed


func _backfill_completed_at(day: String) -> String:
	var day_key := day.strip_edges()
	var today := Time.get_date_string_from_system()
	if day_key == "":
		day_key = today
	var now_str := TimeUtils.now_local_datetime_string()
	if day_key < today:
		return "%s 12:00:00" % day_key
	if day_key == today:
		var noon := "%s 12:00:00" % day_key
		if TimeUtils.unix_from_local_iso_datetime(noon) <= TimeUtils.unix_from_local_iso_datetime(now_str):
			return noon
		return "%s 00:00:01" % day_key
	return "%s 12:00:00" % day_key


func _record_last_daily_quest_completion(
	quest: Dictionary,
	completed_at: String,
	estimated: bool = false
) -> void:
	if pdm == null or not quest is Dictionary:
		return
	var quest_id := str(quest.get("id", "")).strip_edges()
	var at := str(completed_at).strip_edges()
	if quest_id == "" or at == "":
		return
	var ts := TimeUtils.unix_from_local_iso_datetime(at)
	if ts <= 0:
		return
	var existing: Dictionary = pdm.data.get("last_daily_quest_completion", {})
	if existing is Dictionary and not existing.is_empty():
		var existing_ts := TimeUtils.unix_from_local_iso_datetime(str(existing.get("completed_at", "")))
		if existing_ts > ts:
			return
		if existing_ts == ts and estimated and not bool(existing.get("estimated", false)):
			return
	pdm.data["last_daily_quest_completion"] = {
		"id": quest_id,
		"completed_at": at,
		"date": str(pdm.data.get("daily_quests", {}).get("date", at.substr(0, 10))),
		"estimated": estimated,
	}


func _sync_last_daily_from_quests(quests: Array, _date_str: String) -> bool:
	var latest: Dictionary = {}
	var latest_ts := -1
	for q in quests:
		if not q is Dictionary or not bool(q.get("completed", false)):
			continue
		var at := str(q.get("completed_at", "")).strip_edges()
		var ts := TimeUtils.unix_from_local_iso_datetime(at)
		if ts <= 0:
			continue
		if ts > latest_ts:
			latest_ts = ts
			latest = q
	if latest.is_empty():
		return false
	var existing: Dictionary = pdm.data.get("last_daily_quest_completion", {})
	if existing is Dictionary and not existing.is_empty():
		var existing_ts := TimeUtils.unix_from_local_iso_datetime(str(existing.get("completed_at", "")))
		if existing_ts >= latest_ts:
			return false
	_record_last_daily_quest_completion(
		latest,
		str(latest.get("completed_at", "")),
		false
	)
	return true

func get_daily_quests() -> Array:
	if pdm == null:
		return []
	var dq: Dictionary = pdm.data.get("daily_quests", {"date": "", "quests": []})
	var quests: Array = dq.get("quests", [])
	var date_str := str(dq.get("date", ""))
	if _normalize_quest_states(quests, date_str):
		pdm.data["daily_quests"]["quests"] = quests
		pdm._save()
	var synced := _sync_last_daily_from_quests(quests, date_str)
	if synced:
		pdm._save()
	return quests

func increment_daily_progress(event_name: String, value: int, context: Dictionary = {}):
	if pdm == null:
		return
	ensure_daily_quests_for_today()
	var quests := get_daily_quests()
	var changed = false
	for q in quests:
		if q.get("event", "") != event_name:
			continue
		if bool(q.get("completed", false)):
			continue
		var goal = int(q.get("goal", 1))
		var progress = int(q.get("progress", 0))
		match event_name:
			"play_genre_group":
				var target_group = str(q.get("target_group", "")).strip_edges()
				var actual_group = str(context.get("group", "")).strip_edges()
				if actual_group == "":
					var canonical_genre = GenreSearch.normalize_canonical(str(context.get("genre", "")))
					if canonical_genre != "":
						actual_group = _genre_group_map.get(canonical_genre, "")
				if actual_group != "" and target_group != "" and actual_group == target_group:
					progress = min(goal, progress + value)
			"accuracy_80":
				var acc = float(context.get("accuracy", 0.0))
				if acc >= 80.0:
					progress = goal
			"accuracy_90":
				var acc = float(context.get("accuracy", 0.0))
				if acc >= 90.0:
					progress = goal
			"accuracy_95":
				var acc = float(context.get("accuracy", 0.0))
				if acc >= 95.0:
					progress = goal
			"combo_reached":
				var max_combo = int(context.get("max_combo", 0))
				if max_combo >= 30:
					progress = goal
			"combo_reached_60":
				var max_combo = int(context.get("max_combo", 0))
				if max_combo >= 60:
					progress = goal
			"combo_reached_100":
				var max_combo = int(context.get("max_combo", 0))
				if max_combo >= 100:
					progress = goal
			"missless":
				var missed_notes = int(context.get("missed_notes", 0))
				if missed_notes <= 0:
					progress = goal
			"play_drum_level":
				var is_drum = bool(context.get("is_drum_mode", false))
				if is_drum:
					progress = min(goal, progress + value)
			"play_bass_level":
				var is_bass = bool(context.get("is_bass_mode", false))
				if is_bass:
					progress = min(goal, progress + value)
			"modifier_clear_hidden":
				if bool(context.get("hidden", false)):
					progress = min(goal, progress + value)
			"modifier_clear_sd":
				if bool(context.get("sudden_death", false)):
					progress = min(goal, progress + value)
			"modifier_clear_2plus":
				if int(context.get("challenge_count", 0)) >= 2:
					progress = min(goal, progress + value)
			_:
				progress = min(goal, progress + value)
		q["progress"] = progress
		if progress >= goal:
			q["completed"] = true
			var completed_now := TimeUtils.now_local_datetime_string()
			if str(q.get("completed_at", "")).strip_edges() == "":
				q["completed_at"] = completed_now
			_record_last_daily_quest_completion(q, str(q.get("completed_at", completed_now)), false)
			_add_daily_quest_reward(int(q.get("reward_currency", 0)))
			pdm.data["daily_quests_completed_total"] = int(pdm.data.get("daily_quests_completed_total", 0)) + 1
		changed = true
	if changed:
		pdm.data["daily_quests"]["quests"] = quests
		pdm._save()
		emit_signal("daily_quests_updated")

func _add_daily_quest_reward(amount: int):
	if pdm == null:
		return
	if amount > 0:
		pdm.add_currency(amount)

func get_daily_quests_completed_total() -> int:
	if pdm == null:
		return 0
	return int(pdm.data.get("daily_quests_completed_total", 0))

func _load_genre_group_map_if_needed():
	if not _genre_group_map.is_empty():
		return
	var user_path = "user://genre_groups.json"
	var path = user_path if FileAccess.file_exists(user_path) else "res://data/genre_groups.json"
	if not FileAccess.file_exists(path):
		var exe_dir = OS.get_executable_path().get_base_dir()
		var ext = exe_dir.path_join("data/genre_groups.json").replace("\\", "/")
		if FileAccess.file_exists(ext):
			path = ext
	if not FileAccess.file_exists(path):
		return
	var file = FileAccess.open(path, FileAccess.READ)
	if not file:
		return
	var json_text = file.get_as_text()
	file.close()
	var parsed = JSON.parse_string(json_text)
	if not (parsed is Dictionary):
		return
	for group_name in parsed:
		var genres = parsed[group_name]
		if genres is Array:
			for g in genres:
				if g is String:
					_genre_group_map[g.to_lower()] = group_name
	GenreSearch.enrich_group_map(_genre_group_map)
