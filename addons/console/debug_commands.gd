# addons/console/debug_commands.gd
extends Node

const INT64_MAX := 9223372036854775807
const MAX_INPUT_DELTA := 1000000000

func _ready():
	var c = get_tree().root.get_node_or_null("Console")
	if c:
		_remove_aliases(c)
		_register(c)
		_refresh_autocomplete(c)

func _register(c):
	c.add_command("achievement.unlock", _ach_unlock, ["id"], 1, "Разблокировать достижение по id")
	c.add_command("achievement.show", _ach_show, ["id"], 1, "Поставить попап достижения в очередь")
	c.add_command("achievement.resync", _ach_resync, [], 0, "Пересчитать все достижения")
	c.add_command("achievement.queue_size", _ach_queue_size, [], 0, "Размер очереди ачивок")
	c.add_command("achievement.clear_queue", _ach_clear_queue, [], 0, "Очистить очередь ачивок")
	c.add_command("player.currency.add", _player_add_currency, ["amount"], 1, "Добавить валюту")
	c.add_command("player.currency.set", _player_set_currency, ["amount"], 1, "Установить валюту")
	c.add_command("player.playtime.add_minutes", _player_add_minutes, ["minutes"], 1, "Добавить минуты времени")
	c.add_command("player.xp.add", _player_add_xp, ["amount"], 1, "Добавить опыт (XP)")
	c.add_command("player.level.set", _player_set_level, ["level"], 1, "Установить уровень (повышение)")
	c.add_command("stats.hits.add", _stats_add_hits, ["count"], 1, "Добавить попадания")
	c.add_command("stats.misses.add", _stats_add_misses, ["count"], 1, "Добавить промахи")
	c.add_command("stats.perfect.add", _stats_add_perfect, ["count"], 1, "Добавить PERFECT")
	c.add_command("items.unlock", _item_unlock, ["item_id"], 1, "Открыть предмет")
	c.add_command("items.activate", _item_set_active, ["category", "item_id"], 2, "Активировать предмет")
	c.add_command("daily.refresh", _daily_refresh, [], 0, "Пересоздать ежедневки на сегодня")
	c.add_command("daily.list", _daily_list, [], 0, "Показать текущие ежедневки")
	c.add_command("daily.progress", _daily_progress, ["quest_id", "value"], 2, "Добавить прогресс для ежедневки")
	c.add_command("daily.complete", _daily_complete, ["quest_id"], 1, "Завершить ежедневку")
	c.add_command("daily.complete_all", _daily_complete_all, [], 0, "Завершить все текущие ежедневки")
	c.add_command("daily.load_all", _daily_load_all, [], 0, "Загрузить все ежедневки из daily_quests.json на сегодня")
	c.add_command("game.info", _game_info, [], 0, "Показать параметры текущей игры")
	c.add_command("game.score.add_1000", _game_score_add_1000, [], 0, "Добавить 1000 очков с множителем")
	c.add_command("game.score.sub_1000", _game_score_sub_1000, [], 0, "Уменьшить счёт на 1000")
	c.add_command("game.combo.add_10", _game_combo_add_10, [], 0, "Добавить 10 к комбо")
	c.add_command("game.seek_to_no_notes", _game_seek_to_no_notes, [], 0, "Переместиться к концу песни без нот")
	c.add_command("game.seek", _game_seek_to_time, ["pos"], 1, "Переместиться к позиции (сек или MM:SS)")
	c.add_command("game.accuracy.set", _game_accuracy_set, ["percent"], 1, "Установить точность 0-100")
	c.add_command("game.win", _game_win, ["accuracy"], 0, "Симулировать победу (опционально точность)")
	c.add_command("game.autoplay.status", _game_autoplay_status, [], 0, "Показать состояние автоигры")
	c.add_command("game.autoplay", _game_autoplay_toggle, [], 0, "Переключить автоигру")
func _remove_aliases(c):
	c.remove_command("ach.unlock")
	c.remove_command("ach.show")
	c.remove_command("ach.resync")
	c.remove_command("ach.queue_size")
	c.remove_command("ach.clear_queue")
	c.remove_command("item.unlock")
	c.remove_command("item.set_active")
	c.remove_command("player.add_currency")
	c.remove_command("player.set_currency")
	c.remove_command("player.add_minutes")
	c.remove_command("stats.add_hits")
	c.remove_command("stats.add_misses")
	c.remove_command("stats.add_perfect")
func _refresh_autocomplete(c):
	var ach_ids = _get_achievement_ids()
	if ach_ids.size() > 0:
		c.add_command_autocomplete_list("achievement.unlock", ach_ids)
		c.add_command_autocomplete_list("achievement.show", ach_ids)
	var categories = _get_item_categories()
	if categories.size() > 0:
		c.add_command_autocomplete_list("items.activate", categories)
	var item_ids = _load_shop_item_ids()
	if item_ids.size() > 0:
		c.add_command_autocomplete_list("items.unlock", item_ids)
	var dq_ids = _get_daily_ids()
	if dq_ids.size() > 0:
		c.add_command_autocomplete_list("daily.progress", dq_ids)
		c.add_command_autocomplete_list("daily.complete", dq_ids)
	c.add_command_autocomplete_list("player.currency.add", PackedStringArray(["100","500","1000","5000"]))
	c.add_command_autocomplete_list("player.currency.set", PackedStringArray(["0","100","500","1000","5000"]))
	c.add_command_autocomplete_list("player.playtime.add_minutes", PackedStringArray(["10","30","60","120"]))
	c.add_command_autocomplete_list("player.xp.add", PackedStringArray(["50","100","250","1000","10000"]))
	c.add_command_autocomplete_list("stats.hits.add", PackedStringArray(["10","50","100","500"]))
	c.add_command_autocomplete_list("stats.misses.add", PackedStringArray(["1","5","10","50"]))
	c.add_command_autocomplete_list("stats.perfect.add", PackedStringArray(["1","5","10","50"]))
	c.add_command_autocomplete_list("game.seek", PackedStringArray(["30","60","90","120","01:00","01:30","02:00"]))
func _get_engine():
	return get_tree().root.get_node_or_null("GameEngine")
 
func _get_game_screen():
	var ge = _get_engine()
	if ge:
		var gs = ge.get_node_or_null("GameScreen")
		if gs:
			return gs
	return get_tree().root.get_node_or_null("GameScreen")

func _get_achievement_ids() -> PackedStringArray:
	var res : PackedStringArray
	var ge = _get_engine()
	if ge and ge.has_method("get_achievement_manager"):
		var am = ge.get_achievement_manager()
		if am and am.has_method("get_achievement_by_id"):
			for a in am.achievements:
				res.append(str(a.get("id", 0)))
	return res
func _get_item_categories() -> PackedStringArray:
	var res : PackedStringArray
	for k in PlayerDataManager.DEFAULT_ACTIVE_ITEMS.keys():
		res.append(str(k))
	return res
func _get_daily_ids() -> PackedStringArray:
	var res : PackedStringArray
	var qs = PlayerDataManager.get_daily_quests()
	for q in qs:
		var qid = String(q.get("id",""))
		if qid != "":
			res.append(qid)
	return res
func _load_shop_item_ids() -> PackedStringArray:
	var res : PackedStringArray
	var f = FileAccess.open("res://data/shop_data.json", FileAccess.READ)
	if f:
		var txt = f.get_as_text()
		f.close()
		var json = JSON.parse_string(txt)
		if json is Dictionary:
			var items = json.get("items", [])
			if items is Array:
				for it in items:
					var id = String(it.get("item_id", ""))
					if id != "":
						res.append(id)
	return res

 
func _ach_unlock(id_str: String):
	var ge = _get_engine()
	if ge and ge.has_method("get_achievement_manager"):
		var am = ge.get_achievement_manager()
		if am:
			am.unlock_achievement_by_id(int(id_str))
	var c = get_tree().root.get_node_or_null("Console")
	if c:
		c.print_info("Достижение разблокировано: " + id_str)

func _ach_show(id_str: String):
	var ge = _get_engine()
	if ge and ge.has_method("get_achievement_manager"):
		var am = ge.get_achievement_manager()
		if am:
			var a = am.get_achievement_by_id(int(id_str))
			if a:
				ge.show_achievement_popup(a)
	var c = get_tree().root.get_node_or_null("Console")
	if c:
		c.print_info("Попап ачивки поставлен в очередь: " + id_str)

func _ach_resync():
	var ge = _get_engine()
	if ge and ge.has_method("get_achievement_system"):
		var asys = ge.get_achievement_system()
		if asys:
			asys.resync_all()
	var c = get_tree().root.get_node_or_null("Console")
	if c:
		c.print_info("Достижения пересчитаны")

func _ach_queue_size():
	var size = 0
	var ge = _get_engine()
	if ge and ge.has_method("get_achievement_queue_manager"):
		var qm = ge.get_achievement_queue_manager()
		if qm:
			size = qm.get_queue_size()
	var c = get_tree().root.get_node_or_null("Console")
	if c:
		c.print_info("Размер очереди ачивок: " + str(size))

func _ach_clear_queue():
	var ge = _get_engine()
	if ge and ge.has_method("get_achievement_queue_manager"):
		var qm = ge.get_achievement_queue_manager()
		if qm:
			qm.clear_queue()
	var c = get_tree().root.get_node_or_null("Console")
	if c:
		c.print_info("Очередь ачивок очищена")

func _player_add_currency(amount_str: String):
	var amt = _parse_bounded_delta(amount_str)
	if amt <= 0:
		var c = get_tree().root.get_node_or_null("Console")
		if c: c.print_error("Сумма должна быть > 0")
		return
	PlayerDataManager.add_currency(amt)
	var c = get_tree().root.get_node_or_null("Console")
	if c:
		c.print_info("Добавлена валюта: " + str(amt) + (_clamped_suffix(amount_str, amt)))

func _player_set_currency(amount_str: String):
	var target = max(0, _parse_int_saturated(amount_str))
	var current = PlayerDataManager.get_currency()
	PlayerDataManager.add_currency(target - current)
	var c = get_tree().root.get_node_or_null("Console")
	if c:
		c.print_info("Валюта установлена: " + str(target) + (_clamped_suffix(amount_str, target)))

func _player_add_minutes(minutes_str: String):
	var mins = _parse_bounded_delta(minutes_str)
	if mins <= 0:
		var c = get_tree().root.get_node_or_null("Console")
		if c: c.print_error("Минуты должны быть > 0")
		return
	PlayerDataManager.add_play_time_seconds(mins * 60)
	var c = get_tree().root.get_node_or_null("Console")
	if c:
		c.print_info("Добавлено минут: " + str(mins) + (_clamped_suffix(minutes_str, mins)))

func _stats_add_hits(count_str: String):
	var count = max(0, _parse_int(count_str))
	if count == 0:
		var c0 = get_tree().root.get_node_or_null("Console")
		if c0: c0.print_error("Количество должно быть > 0")
		return
	PlayerDataManager.add_hit_notes(count)
	var ge = _get_engine()
	if ge and ge.has_method("get_achievement_manager"):
		var am = ge.get_achievement_manager()
		if am and PlayerDataManager.has_method("get_total_notes_hit"):
			am.check_rhythm_master_achievement(PlayerDataManager.get_total_notes_hit())
	var c = get_tree().root.get_node_or_null("Console")
	if c:
		c.print_info("Добавлены попадания: " + str(count))
		c.print_info("Всего попаданий: " + str(PlayerDataManager.get_total_notes_hit()))

func _stats_add_misses(count_str: String):
	var count = max(0, _parse_int(count_str))
	if count == 0:
		var c0 = get_tree().root.get_node_or_null("Console")
		if c0: c0.print_error("Количество должно быть > 0")
		return
	PlayerDataManager.add_missed_notes(count)
	var c = get_tree().root.get_node_or_null("Console")
	if c:
		c.print_info("Добавлены промахи: " + str(count))

func _stats_add_perfect(count_str: String):
	var count = max(0, _parse_int(count_str))
	if count == 0:
		var c0 = get_tree().root.get_node_or_null("Console")
		if c0: c0.print_error("Количество должно быть > 0")
		return
	PlayerDataManager.add_perfect_hits(count)
	var c = get_tree().root.get_node_or_null("Console")
	if c:
		c.print_info("Добавлены PERFECT: " + str(count))

func _player_add_xp(amount_str: String):
	var amt = _parse_bounded_delta(amount_str)
	if amt <= 0:
		var c0 = get_tree().root.get_node_or_null("Console")
		if c0: c0.print_error("XP должно быть > 0")
		return
	PlayerDataManager.add_xp(amt)
	var c = get_tree().root.get_node_or_null("Console")
	if c:
		c.print_info("Добавлено XP: " + str(amt) + (_clamped_suffix(amount_str, amt)) + " | Текущий уровень: " + str(PlayerDataManager.get_current_level()))

func _player_set_level(level_str: String):
	var target = _parse_int_saturated(level_str)
	var c = get_tree().root.get_node_or_null("Console")
	if target <= PlayerDataManager.get_current_level():
		if c: c.print_error("Можно только повышать уровень")
		return
	target = clamp(target, PlayerDataManager.get_current_level() + 1, PlayerDataManager.MAX_LEVEL)
	while PlayerDataManager.get_current_level() < target:
		PlayerDataManager.add_xp(1000000)
	if c:
		c.print_info("Установлен уровень: " + str(PlayerDataManager.get_current_level()))

func _item_unlock(item_id: String):
	var c = get_tree().root.get_node_or_null("Console")
	var item = _get_shop_item(item_id)
	if item.is_empty():
		if c:
			c.print_error("Неизвестный item_id: " + item_id)
		return
	PlayerDataManager.unlock_item(item_id)
	if c:
		var name = String(item.get("name", item_id))
		c.print_info("Открыт предмет: " + item_id + " (" + name + ")")

func _item_set_active(category: String, item_id: String):
	var c = get_tree().root.get_node_or_null("Console")
	if not PlayerDataManager.DEFAULT_ACTIVE_ITEMS.has(category):
		if c:
			c.print_error("Неизвестная категория: " + category)
		return
	var item = _get_shop_item(item_id)
	if item.is_empty():
		if c:
			c.print_error("Неизвестный item_id: " + item_id)
		return
	PlayerDataManager.set_active_item(category, item_id)
	if c:
		c.print_info("Активирован предмет: " + category + " -> " + item_id)

func _daily_refresh():
	var c = get_tree().root.get_node_or_null("Console")
	PlayerDataManager.data["daily_quests"] = {"date": "", "quests": []}
	PlayerDataManager.ensure_daily_quests_for_today()
	if c:
		c.print_info("Ежедневки пересозданы на сегодняшнюю дату")

func _daily_list():
	var c = get_tree().root.get_node_or_null("Console")
	var qs = PlayerDataManager.get_daily_quests()
	if c:
		if qs.is_empty():
			c.print_info("Ежедневки отсутствуют")
		for i in range(qs.size()):
			var q = qs[i]
			var line = "%d) %s | %s | %d/%d %s" % [
				i + 1,
				String(q.get("id","")),
				String(q.get("title","")),
				int(q.get("progress",0)),
				int(q.get("goal",1)),
				("(done)" if q.get("completed", false) else "")
			]
			c.print_info(line)

func _daily_progress(token: String, val_str: String):
	var c = get_tree().root.get_node_or_null("Console")
	var q = _resolve_daily_by_token(token)
	if q.is_empty():
		if c: c.print_error("Ежедневка не найдена: " + token)
		return
	var ev = String(q.get("event",""))
	var v = int(val_str)
	if v <= 0:
		if c: c.print_error("Значение должно быть > 0")
		return
	PlayerDataManager.increment_daily_progress(ev, v, {})
	if c: c.print_info("Прогресс обновлён")

func _daily_complete(token: String):
	var c = get_tree().root.get_node_or_null("Console")
	var q = _resolve_daily_by_token(token)
	if q.is_empty():
		if c: c.print_error("Ежедневка не найдена: " + token)
		return
	var ev = String(q.get("event",""))
	var ctx := {}
	match ev:
		"accuracy_80", "accuracy_90", "accuracy_95":
			ctx = {"accuracy": 100.0}
		"combo_reached", "combo_reached_60", "combo_reached_100":
			ctx = {"max_combo": 100}
		"missless":
			ctx = {"missed_notes": 0}
		"play_drum_level":
			ctx = {"is_drum_mode": true}
		_:
			ctx = {}
	PlayerDataManager.increment_daily_progress(ev, 999999, ctx)
	if c: c.print_info("Ежедневка завершена")
	
func _daily_complete_all():
	var c = get_tree().root.get_node_or_null("Console")
	var qs = PlayerDataManager.get_daily_quests()
	if qs.is_empty():
		if c: c.print_error("Ежедневки отсутствуют")
		return
	for q in qs:
		var ev = String(q.get("event",""))
		var ctx := {}
		match ev:
			"accuracy_80", "accuracy_90", "accuracy_95":
				ctx = {"accuracy": 100.0}
			"combo_reached", "combo_reached_60", "combo_reached_100":
				ctx = {"max_combo": 100}
			"missless":
				ctx = {"missed_notes": 0}
			"play_drum_level":
				ctx = {"is_drum_mode": true}
			_:
				ctx = {}
		PlayerDataManager.increment_daily_progress(ev, 999999, ctx)
	if c: c.print_info("Все текущие ежедневки завершены")

func _game_seek_to_no_notes():
	var c = get_tree().root.get_node_or_null("Console")
	var gs = _get_game_screen()
	if not gs:
		if c: c.print_error("GameScreen не найден")
		return
	# Определяем длительность трека
	var duration_seconds: float = 0.0
	var dur = gs.selected_song_data.get("duration", 0)
	if typeof(dur) == TYPE_STRING:
		var parts = String(dur).split(":")
		if parts.size() == 2:
			var minutes = int(parts[0])
			var seconds = int(parts[1])
			duration_seconds = float(minutes * 60 + seconds)
	elif typeof(dur) == TYPE_FLOAT:
		duration_seconds = float(dur)
	# Целимся ближе к концу, но оставляем немного музыки
	var target := 0.0
	if duration_seconds > 0.0:
		target = max(0.0, duration_seconds - 10.0)
	else:
		target = 0.0
	gs.game_time = target
	if MusicManager.has_method("set_music_position"):
		MusicManager.set_music_position(target)
	# Очищаем ноты и очередь спавна, чтобы имитировать отсутствие нот
	if gs.note_manager:
		gs.note_manager.clear_notes()
	# Принудительно проверить окончание нот и обновить подсказку
	if gs.has_method("_check_song_end"):
		gs._check_song_end()
	if gs.has_method("_update_hint"):
		gs._update_hint()
	if c: c.print_info("Перемещено к времени без нот: " + str(target) + " сек")

func _parse_time_to_seconds(s: String) -> float:
	var txt := String(s).strip_edges()
	if ":" in txt:
		var parts = txt.split(":")
		if parts.size() == 2 and parts[0].is_valid_int() and parts[1].is_valid_int():
			var minutes = int(parts[0])
			var seconds = int(parts[1])
			return float(max(0, minutes) * 60 + max(0, seconds))
		return -1.0
	else:
		var val := 0.0
		if txt.is_valid_float():
			val = float(txt)
		elif txt.is_valid_int():
			val = float(int(txt))
		else:
			return -1.0
		return max(0.0, val)

func _game_seek_to_time(pos: String):
	var c = get_tree().root.get_node_or_null("Console")
	var gs = _get_game_screen()
	if not gs:
		if c: c.print_error("GameScreen не найден")
		return
	var t = _parse_time_to_seconds(pos)
	if t < 0.0:
		if c: c.print_error("Некорректный формат позиции. Используйте секунды или MM:SS")
		return
	gs.game_time = t
	if MusicManager.has_method("set_music_position"):
		MusicManager.set_music_position(t)
	if gs.note_manager:
		if gs.note_manager.has_method("clear_active_notes"):
			gs.note_manager.clear_active_notes()
		gs.note_manager.skip_notes_before_time(t)
	if gs.has_method("_update_hint"):
		gs._update_hint()
	if gs.has_method("_check_song_end"):
		gs._check_song_end()
	if gs.has_method("update_ui"):
		gs.update_ui()
	if c:
		var m := int(floor(t / 60.0))
		var s := int(floor(fmod(t, 60.0)))
		c.print_info("Перемещено к позиции: " + str(t) + " сек (" + str(m).pad_zeros(2) + ":" + str(s).pad_zeros(2) + ")")

func _daily_load_all():
	var c = get_tree().root.get_node_or_null("Console")
	var today = Time.get_date_string_from_system()
	var quest_pool: Array = []
	var file = FileAccess.open("res://data/daily_quests.json", FileAccess.READ)
	if file:
		var json_text = file.get_as_text()
		file.close()
		var parsed = JSON.parse_string(json_text)
		if parsed is Dictionary and parsed.has("quests") and (parsed["quests"] is Array):
			quest_pool = parsed["quests"]
	if quest_pool.is_empty():
		if c: c.print_error("daily_quests.json пуст или не найден")
		return
	var quests_for_day: Array = []
	for q in quest_pool:
		if q is Dictionary:
			var qcopy = q.duplicate(true)
			qcopy["progress"] = 0
			qcopy["completed"] = false
			quests_for_day.append(qcopy)
	PlayerDataManager.data["daily_quests"] = {"date": today, "quests": quests_for_day}
	PlayerDataManager.flush_save()
	if c:
		c.print_info("Загружены все ежедневки (%d) на сегодня" % quests_for_day.size())
	
func _parse_int_saturated(s: String) -> int:
	var n := int(s)
	if n < 0:
		return 0
	return n

func _parse_bounded_delta(s: String) -> int:
	var n := _parse_int_saturated(s)
	return clamp(n, 0, MAX_INPUT_DELTA)

func _clamped_suffix(original: String, applied: int) -> String:
	var parsed := _parse_int_saturated(original)
	if parsed != applied or parsed > MAX_INPUT_DELTA:
		return " (ограничено)"
	return ""

func _resolve_daily_by_token(token: String) -> Dictionary:
	var qs = PlayerDataManager.get_daily_quests()
	if token.is_valid_int():
		var idx = int(token) - 1
		if idx >= 0 and idx < qs.size():
			return qs[idx]
	for q in qs:
		if String(q.get("id","")) == token:
			return q
	return {}

func _game_info():
	var c = get_tree().root.get_node_or_null("Console")
	var gs = _get_game_screen()
	if not gs:
		if c: c.print_error("GameScreen не найден")
		return
	if c:
		var notes_active = 0
		if gs.note_manager and gs.note_manager.has_method("get_notes"):
			notes_active = gs.note_manager.get_notes().size()
		var notes_total = 0
		if gs.note_manager and gs.note_manager.has_method("get_spawn_queue_size"):
			notes_total = gs.note_manager.get_spawn_queue_size()
		var score := 0
		var combo := 0
		var max_combo := 0
		var mult := 1.0
		var acc := 0.0
		if gs.score_manager:
			score = int(gs.score_manager.get_score())
			combo = int(gs.score_manager.get_combo())
			max_combo = int(gs.score_manager.get_max_combo())
			mult = float(gs.score_manager.get_combo_multiplier())
			acc = float(gs.score_manager.get_accuracy())
		var t := max(0.0, gs.game_time)
		var m := int(floor(t / 60.0))
		var s := int(floor(fmod(t, 60.0)))
		var mm := str(m).pad_zeros(2)
		var ss := str(s).pad_zeros(2)
		var mult_txt := "x" + str(snapped(mult, 0.1))
		var acc_txt := str(snapped(acc, 0.01)) + "%"
		var bpm_txt := str(snapped(gs.bpm, 0.1))
		var t_txt := str(snapped(t, 0.01)) + "s"
		c.print_info("Счёт: " + str(score))
		c.print_info("Комбо: " + str(combo))
		c.print_info("Макс. комбо: " + str(max_combo))
		c.print_info("Множитель: " + mult_txt)
		c.print_info("Точность: " + acc_txt)
		c.print_info("Активных нот: " + str(notes_active))
		c.print_info("Всего нот: " + str(notes_total))
		c.print_info("BPM: " + bpm_txt)
		c.print_info("Время: " + t_txt + " (" + mm + ":" + ss + ")")

func _game_score_add_1000():
	var c = get_tree().root.get_node_or_null("Console")
	var gs = _get_game_screen()
	if not gs or not gs.score_manager:
		if c: c.print_error("ScoreManager недоступен")
		return
	var current_combo = gs.score_manager.combo
	var multiplier = min(4.0, 1.0 + float(int(current_combo / 10)))
	var actual_points = int(1000 * multiplier)
	gs.score_manager.score += actual_points
	if gs.has_method("update_ui"):
		gs.update_ui()
	if c:
		c.print_info("Добавлено очков: %d (x%.1f)" % [actual_points, multiplier])

func _game_score_sub_1000():
	var c = get_tree().root.get_node_or_null("Console")
	var gs = _get_game_screen()
	if not gs or not gs.score_manager:
		if c: c.print_error("ScoreManager недоступен")
		return
	gs.score_manager.score = max(0, gs.score_manager.score - 1000)
	if gs.has_method("update_ui"):
		gs.update_ui()
	if c:
		c.print_info("Минус 1000 очков. Текущий счёт: %d" % gs.score_manager.score)

func _game_combo_add_10():
	var c = get_tree().root.get_node_or_null("Console")
	var gs = _get_game_screen()
	if not gs or not gs.score_manager:
		if c: c.print_error("ScoreManager недоступен")
		return
	var new_combo = gs.score_manager.combo + 10
	gs.score_manager.combo = new_combo
	if new_combo > gs.score_manager.max_combo:
		gs.score_manager.max_combo = new_combo
	gs.score_manager.combo_multiplier = min(4.0, 1.0 + float(int(new_combo / 10)))
	if gs.has_method("update_ui"):
		gs.update_ui()
	if c:
		c.print_info("Комбо: %d | Макс.: %d | Множитель: x%.1f" % [gs.score_manager.combo, gs.score_manager.max_combo, gs.score_manager.combo_multiplier])

func _game_accuracy_set(percent_str: String):
	var c = get_tree().root.get_node_or_null("Console")
	var gs = _get_game_screen()
	if not gs or not gs.score_manager:
		if c: c.print_error("ScoreManager недоступен")
		return
	if not percent_str.is_valid_float():
		if c: c.print_error("Процент должен быть числом")
		return
	var target = clampf(percent_str.to_float(), 0.0, 100.0)
	var total_notes = gs.score_manager.total_notes
	if total_notes <= 0 and gs.note_manager and gs.note_manager.has_method("get_spawn_queue_size"):
		total_notes = gs.note_manager.get_spawn_queue_size()
	if total_notes <= 0:
		total_notes = 1
	var missed_notes = int(round(total_notes * (100.0 - target) / 100.0))
	missed_notes = clamp(missed_notes, 0, total_notes)
	var hit_notes = total_notes - missed_notes
	gs.score_manager.total_notes = total_notes
	gs.score_manager.missed_notes = missed_notes
	gs.score_manager.hit_notes = hit_notes
	gs.score_manager.update_accuracy()
	if gs.has_method("update_ui"):
		gs.update_ui()
	if c:
		c.print_info("Точность установлена: %.2f%% (total=%d, hit=%d, miss=%d)" % [gs.score_manager.get_accuracy(), total_notes, hit_notes, missed_notes])

func _game_win(accuracy_opt := ""):
	var c = get_tree().root.get_node_or_null("Console")
	var gs = _get_game_screen()
	if not gs or not gs.score_manager or not gs.note_manager:
		if c: c.print_error("GameScreen или компоненты недоступны")
		return
	var target_accuracy = gs.score_manager.get_accuracy()
	var override = false
	if accuracy_opt is String and accuracy_opt != "" and accuracy_opt.is_valid_float():
		target_accuracy = clampf(accuracy_opt.to_float(), 0.0, 100.0)
		override = true
	var total_notes = gs.score_manager.total_notes
	if total_notes <= 0:
		if gs.note_manager and gs.note_manager.has_method("get_spawn_queue_size"):
			total_notes = gs.note_manager.get_spawn_queue_size()
	if total_notes <= 0:
		total_notes = 1
	if override:
		var missed_notes = int(round(total_notes * (100.0 - target_accuracy) / 100.0))
		missed_notes = clamp(missed_notes, 0, total_notes)
		var hit_notes = total_notes - missed_notes
		gs.score_manager.total_notes = total_notes
		gs.score_manager.missed_notes = missed_notes
		gs.score_manager.hit_notes = hit_notes
		gs.score_manager.update_accuracy()
	var hits_for_combo = gs.score_manager.get_hit_notes_count()
	if target_accuracy >= 100.0 and hits_for_combo > 0:
		gs.score_manager.combo = hits_for_combo
	var base_score_per_hit = 100
	var multiplier = 1.0
	if target_accuracy >= 100.0:
		multiplier = min(4.0, 1.0 + (float(total_notes) / 10.0))
	elif target_accuracy >= 95.0:
		multiplier = 2.0
	elif target_accuracy >= 90.0:
		multiplier = 1.5
	var current_score = gs.score_manager.get_score()
	var recompute = override or current_score <= 0
	if recompute:
		var hits_for_score = max(1, gs.score_manager.get_hit_notes_count())
		gs.score_manager.score = int(hits_for_score * base_score_per_hit * multiplier)
	if gs.has_method("update_ui"):
		gs.update_ui()
	if gs.note_manager and gs.note_manager.has_method("clear_notes"):
		gs.note_manager.clear_notes()
	if gs.has_method("end_game"):
		gs.end_game()
	if c:
		c.print_info("Симулировано завершение уровня (точность: %.2f%%)" % target_accuracy)
		
func _game_autoplay_on():
	var c = get_tree().root.get_node_or_null("Console")
	var gs = _get_game_screen()
	if not gs:
		if c: c.print_error("GameScreen не найден")
		return
	if gs.has_method("set_autoplay_enabled"):
		gs.set_autoplay_enabled(true)
		if c: c.print_info("Автоигра: ВКЛ.")
	else:
		if c: c.print_error("Автоигра не поддерживается в текущей сцене")

func _game_autoplay_status():
	var c = get_tree().root.get_node_or_null("Console")
	var gs = _get_game_screen()
	if not gs:
		if c: c.print_error("GameScreen не найден")
		return
	if gs.has_method("is_autoplay_enabled"):
		var st = gs.is_autoplay_enabled()
		if c: c.print_info("Автоигра: " + ("ВКЛ." if st else "ВЫКЛ."))
	else:
		if c: c.print_error("Автоигра не поддерживается в текущей сцене")

func _game_autoplay_toggle():
	var c = get_tree().root.get_node_or_null("Console")
	var gs = _get_game_screen()
	if not gs:
		if c: c.print_error("GameScreen не найден")
		return
	if gs.has_method("is_autoplay_enabled") and gs.has_method("set_autoplay_enabled"):
		var st = gs.is_autoplay_enabled()
		gs.set_autoplay_enabled(not st)
		if c: c.print_info("Автоигра: " + ("ВКЛ." if (not st) else "ВЫКЛ."))
	else:
		if c: c.print_error("Автоигра не поддерживается в текущей сцене")
func _parse_int(s: String) -> int:
	var out := ""
	var seen_sign := false
	for ch in s:
		if ch == '-' and not seen_sign and out == "":
			out += ch
			seen_sign = true
		elif ch.is_valid_int():
			out += ch
	var val := 0
	if out != "" and out != "-" and out != "+":
		val = int(out)
	return val
func _get_shop_item(id: String) -> Dictionary:
	var f = FileAccess.open("res://data/shop_data.json", FileAccess.READ)
	if f:
		var txt = f.get_as_text()
		f.close()
		var json = JSON.parse_string(txt)
		if json is Dictionary:
			var items = json.get("items", [])
			if items is Array:
				for it in items:
					if String(it.get("item_id", "")) == id:
						return it
	return {}
