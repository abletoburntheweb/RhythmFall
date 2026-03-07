# logic/daily_quests_manager.gd
extends Node

signal daily_quests_updated()

var pdm = null

func set_player_data_manager(pdm_ref):
	pdm = pdm_ref

func ensure_daily_quests_for_today():
	if pdm == null:
		return
	var today = Time.get_date_string_from_system()
	var current = pdm.data.get("daily_quests", {"date": "", "quests": []})
	if current.get("date", "") != today:
		_generate_daily_quests_for_date(today)
		pdm._save()
		emit_signal("daily_quests_updated")

func _generate_daily_quests_for_date(date_str: String):
	if pdm == null:
		return
	var quests_for_day: Array = []
	var quest_pool: Array = []
	var user_path = "user://daily_quests.json"
	var res_path = "res://data/daily_quests.json"
	var open_path = user_path if FileAccess.file_exists(user_path) else res_path
	var file = FileAccess.open(open_path, FileAccess.READ)
	if file:
		var json_text = file.get_as_text()
		file.close()
		var parsed = JSON.parse_string(json_text)
		if parsed is Dictionary and parsed.has("quests") and (parsed["quests"] is Array):
			quest_pool = parsed["quests"]
	if quest_pool.is_empty():
		quest_pool = [
			{"id": "complete_levels", "title": "Заверши уровни (3)", "event": "levels_completed", "goal": 3, "reward_currency": 50},
			{"id": "perfect_hits", "title": "Сделай PERFECT попадания (30)", "event": "perfect_hits", "goal": 30, "reward_currency": 40},
			{"id": "accuracy_80", "title": "Заверши уровень с точностью ≥ 80%", "event": "accuracy_80", "goal": 1, "reward_currency": 30},
			{"id": "play_drum", "title": "Сыграй уровень на барабанах", "event": "play_drum_level", "goal": 1, "reward_currency": 30},
			{"id": "combo_30", "title": "Достигни комбо ≥ 30", "event": "combo_reached", "goal": 1, "reward_currency": 20},
			{"id": "missless", "title": "Пройди без промахов", "event": "missless", "goal": 1, "reward_currency": 50},
			{"id": "notes_generated", "title": "Сгенерируй ноты для трека", "event": "notes_generated", "goal": 1, "reward_currency": 10}
		]
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

func get_daily_quests() -> Array:
	if pdm == null:
		return []
	return pdm.data.get("daily_quests", {"date": "", "quests": []}).get("quests", [])

func increment_daily_progress(event_name: String, value: int, context: Dictionary = {}):
	if pdm == null:
		return
	ensure_daily_quests_for_today()
	var dq = pdm.data.get("daily_quests", {"date": "", "quests": []})
	var quests = dq.get("quests", [])
	var changed = false
	for q in quests:
		if q.get("event", "") != event_name:
			continue
		if q.get("completed", false):
			continue
		var goal = int(q.get("goal", 1))
		var progress = int(q.get("progress", 0))
		match event_name:
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
			_:
				progress = min(goal, progress + value)
		q["progress"] = progress
		if progress >= goal:
			q["completed"] = true
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
