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
	c.add_command("achievement.unlock_random", _ach_unlock_random, [], 0, "Разблокировать случайное заблокированное достижение")
	c.add_command("achievement.show", _ach_show, ["id"], 1, "Поставить попап достижения в очередь")
	c.add_command("achievement.show_random", _ach_show_random, ["count"], 0, "Показать случайное достижение (1 или N) без разблокировки")
	c.add_command("notification.show_random", _notif_show_random, ["count"], 0, "Показать случайные обычные уведомления (1 или N)")
	c.add_command("notification.show_scan", _notif_show_scan, [], 0, "Тест сканирования: show_operation -> success")
	c.add_command("achievement.resync", _ach_resync, [], 0, "Пересчитать все достижения")
	c.add_command("achievement.queue_size", _ach_queue_size, [], 0, "Размер очереди ачивок")
	c.add_command("achievement.clear_queue", _ach_clear_queue, [], 0, "Очистить очередь ачивок")
	c.add_command("event.status", _event_status, [], 0, "Диагностика событий: дата и окна event-достижений (только чтение)")
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
	c.add_command("game.score.add", _game_score_add, ["amount"], 1, "Добавить очки с множителем")
	c.add_command("game.score.sub", _game_score_sub, ["amount"], 1, "Уменьшить счёт на значение")
	c.add_command("game.combo.add", _game_combo_add, ["amount"], 1, "Добавить к комбо")
	c.add_command("game.combo.sub", _game_combo_sub, ["amount"], 1, "Уменьшить комбо")
	c.add_command("game.seek.no_notes", _game_seek_to_no_notes, [], 0, "Переместиться к концу песни без нот")
	c.add_command("game.seek", _game_seek_to_time, ["pos"], 1, "Переместиться к позиции (сек или MM:SS)")
	c.add_command("game.seek.section", _game_seek_section, ["number"], 1, "Переместиться к началу секции (1-based, из sections.rfd)")
	c.add_command("game.seek.intro", _game_seek_intro, [], 0, "Переместиться к intro секции")
	c.add_command("game.seek.outro", _game_seek_outro, [], 0, "Переместиться к outro секции")
	c.add_command("game.seek.random", _game_seek_random, [], 0, "Переместиться к случайной секции")
	c.add_command("chart.sections", _chart_sections, [], 0, "Показать canonical секции текущего чарта (sections.rfd)")
	c.add_command("game.accuracy.set", _game_accuracy_set, ["percent"], 1, "Установить точность 0-100")
	c.add_command("game.win", _game_win, ["accuracy"], 0, "Симулировать победу (опционально точность)")
	c.add_command("game.win_nosave", _game_win_nosave, ["accuracy"], 0, "Симулировать победу без сохранения (опционально точность)")
	c.add_command("game.series.win", _game_series_win, ["accuracy"], 0, "Выживание/марафон: очистить трек и перейти дальше (точность 0-100)")
	c.add_command("game.autoplay.status", _game_autoplay_status, [], 0, "Показать состояние автоигры")
	c.add_command("game.autoplay", _game_autoplay_toggle, [], 0, "Переключить автоигру")
	c.add_command("diag.verify_data", _diag_verify_data, [], 0, "Проверить целостность пользовательских данных")
	c.add_command("timing.debug.status", _timing_debug_status, [], 0, "Флаги отладки тайминга (только до перезапуска игры, не в settings.json)")
	c.add_command("timing.debug.log", _timing_debug_log_toggle, [], 0, "Переключить CSV user://timing_hit_debug.csv и [TimingDebug] (сессия)")
	c.add_command("timing.debug.overlay", _timing_debug_overlay_toggle, [], 0, "Переключить оверлей latency/drift (сессия)")
	c.add_command("timing.autoplay.windows", _timing_autoplay_windows_toggle, [], 0, "Автоплей с теми же окнами ±мс, что и игрок (сессия)")
	c.add_command("tutorial.song_select.reset", _tutorial_song_select_reset, [], 0, "Сбросить флаг туториала библиотеки песен")
	c.add_command("tutorial.song_select.show", _tutorial_song_select_show, [], 0, "Сбросить флаг и показать туториал (если открыта библиотека)")
	c.add_command("tutorial.shop.reset", _tutorial_shop_reset, [], 0, "Сбросить флаг туториала магазина")
	c.add_command("tutorial.shop.show", _tutorial_shop_show, [], 0, "Сбросить флаг и показать туториал (если открыт магазин)")
	c.add_command("tutorial.first_steps.reset", _tutorial_first_steps_reset, [], 0, "Сбросить прогресс обучения «Первые шаги»")
	c.add_command("tutorial.first_steps.show", _tutorial_first_steps_show, [], 0, "Показать обучение «Первые шаги» с шага 1 (предпросмотр, без данных профиля)")
	c.add_command("tutorial.first_steps.next", _tutorial_first_steps_next, [], 0, "Следующий шаг предпросмотра «Первые шаги»")
	c.add_command("tutorial.first_steps.exit", _tutorial_first_steps_exit, [], 0, "Выйти из предпросмотра «Первые шаги»")
	c.add_command("tutorial.practice.show", _tutorial_practice_show, [], 0, "Сбросить флаг туториала практики (покажется при следующем открытии панели практики)")
	c.add_command("diary.toast.show", _diary_toast_show, ["kind"], 0, "Показать diary StatusDock toast: first_ss|first_fc|library|mastery|rr|genre_ss")
	c.add_command("ui.notice.show", _ui_notice_show, ["message"], 0, "Показать AppNoticeOverlay на текущем экране (если есть %NoticeOverlay)")
	c.add_command("perf.debug", _perf_debug, ["mode"], 0, "Perf debug: off|load|runtime|detail|status (уровень профилирования)")
	c.add_command("perf.stats", _perf_stats, [], 0, "Показать накопленную PerfTrace статистику (count/avg/min/max)")
	c.add_command("perf.reset", _perf_reset, [], 0, "Сбросить накопленную PerfTrace статистику")
	c.add_command("hitfx.debug", _hitfx_debug, ["mode"], 0, "Hit FX: legacy/current/status")
	c.add_command("debug.empty_state", _debug_empty_state, ["state"], 0, "Empty state debug: on|off|toggle — force Main Menu/Profile to show new-player empty state (runtime only, no save change)")
	c.add_command("debug.progress", _debug_progress, ["type", "value"], 0, "Progress debug: milestone <id> | genre_mastery <5|10|15|20> | rr_total <25000|50000|100000|250000|500000|1000000> | library <100|500|1000> | off — temporary Activity progress (runtime only)")
	c.add_command("debug.scenario", _debug_scenario, ["name"], 0, "Scenario debug: activity | off — temporary Main Menu Activity 5-row test set (runtime only)")
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
	c.add_command_autocomplete_list("diary.toast.show", [
		"first_ss", "first_fc", "first_track", "library", "mastery", "rr", "genre_ss"
	])
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
	c.add_command_autocomplete_list("game.seek", PackedStringArray(["30","60","90","120","01:00","01:30","02:00","section","intro","outro","random"]))
	c.add_command_autocomplete_list("game.score.add", PackedStringArray(["100","500","1000","5000"]))
	c.add_command_autocomplete_list("game.score.sub", PackedStringArray(["100","500","1000","5000"]))
	c.add_command_autocomplete_list("game.combo.add", PackedStringArray(["1","5","10","25"]))
	c.add_command_autocomplete_list("game.combo.sub", PackedStringArray(["1","5","10","25"]))
	c.add_command_autocomplete_list("game.win", PackedStringArray(["","90","95","100"]))
	c.add_command_autocomplete_list("game.win_nosave", PackedStringArray(["","90","95","100"]))
	c.add_command_autocomplete_list("game.series.win", PackedStringArray(["","90","95","100"]))
	c.add_command_autocomplete_list("perf.debug", PackedStringArray(["off","load","runtime","detail","status"]))
	c.add_command_autocomplete_list("debug.empty_state", PackedStringArray(["on","off","toggle"]))
	c.add_command_autocomplete_list("debug.progress", PackedStringArray(["milestone", "genre_mastery", "rr_total", "library", "off"]))
	c.add_command_autocomplete_list("debug.scenario", PackedStringArray(["activity", "off"]))
func _get_engine():
	return get_tree().root.get_node_or_null("GameEngine")

func _get_game_screen():
	var ge = _get_engine()
	if ge:
		var current := ge.get("current_screen")
		if current and current.has_method("end_game"):
			return current
		for child in ge.get_children():
			if child.has_method("end_game"):
				return child
	var found := get_tree().root.find_child("GameScreen", true, false)
	if found and found.has_method("end_game"):
		return found
	return null

func _get_score_manager(gs) -> Variant:
	if gs == null:
		return null
	return gs.get("score_manager")

func _get_note_manager(gs) -> Variant:
	if gs == null:
		return null
	return gs.get("note_manager")

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
	var user_path = "user://shop_data.json"
	var path = user_path if FileAccess.file_exists(user_path) else "res://data/shop_data.json"
	var json: Dictionary = JsonUtils.read_json_dict(path)
	if json is Dictionary:
		var items = json.get("items", [])
		if items is Array:
			for it in items:
				var id = String(it.get("item_id", ""))
				if id != "":
					res.append(id)
	return res

 
func _ach_unlock(id_str: String):
	var c = get_tree().root.get_node_or_null("Console")
	if not id_str.is_valid_int():
		if c:
			c.print_error("Неверный id достижения: " + id_str)
		return
	var ach_id := int(id_str)
	if not PlayerDataManager.is_achievement_unlocked(ach_id):
		PlayerDataManager.unlock_achievement(ach_id)
	var synced_runtime := false
	var ge = _get_engine()
	if ge and ge.has_method("get_achievement_manager"):
		var am = ge.get_achievement_manager()
		if am:
			if am.player_data_mgr == null:
				am.player_data_mgr = PlayerDataManager
			am.unlock_achievement_by_id(ach_id)
			synced_runtime = true
	if not synced_runtime:
		_unlock_achievement_in_user_json(ach_id)
	if c:
		if PlayerDataManager.is_achievement_unlocked(ach_id):
			c.print_info("Достижение разблокировано: " + id_str)
		else:
			c.print_error("Не удалось разблокировать достижение: " + id_str)

func _ach_unlock_random():
	var c = get_tree().root.get_node_or_null("Console")
	var ge = _get_engine()
	var candidates: Array = []
	if ge and ge.has_method("get_achievement_manager"):
		var am = ge.get_achievement_manager()
		if am:
			for a in am.achievements:
				if not bool(a.get("unlocked", false)) and not bool(a.get("deprecated", false)):
					candidates.append(int(a.get("id", -1)))
	if candidates.is_empty():
		if c: c.print_info("Нет заблокированных достижений")
		return
	candidates.shuffle()
	var pick: int = candidates[0]
	_ach_unlock(str(pick))


func _unlock_achievement_in_user_json(achievement_id: int) -> bool:
	var paths := [
		"user://achievements_data.json",
		"res://data/achievements_data.json",
		"res://scenes/achievements_data.json",
	]
	var source_path := ""
	for path in paths:
		if FileAccess.file_exists(path):
			source_path = path
			break
	if source_path == "":
		return false
	var parsed: Dictionary = JsonUtils.read_json_dict(source_path)
	if not parsed.has("achievements") or not (parsed["achievements"] is Array):
		return false
	var changed := false
	for item in parsed["achievements"]:
		if not (item is Dictionary):
			continue
		if int(item.get("id", -1)) != achievement_id:
			continue
		if bool(item.get("unlocked", false)):
			return true
		item["unlocked"] = true
		item["current"] = item.get("total", 1)
		var date = Time.get_date_dict_from_system()
		var time = Time.get_time_dict_from_system()
		var TimeUtils = preload("res://logic/platform/time_utils.gd")
		var date_text = TimeUtils.format_date_parts_ru(int(date.day), int(date.month), int(date.year))
		item["unlock_date"] = "%s, %02d:%02d" % [date_text, int(time.hour), int(time.minute)]
		changed = true
		break
	if not changed:
		return false
	return JsonUtils.write_json("user://achievements_data.json", parsed, true, true)

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


func _ach_show_random(count_str: String = ""):
	var c = get_tree().root.get_node_or_null("Console")
	var ge = _get_engine()
	var count := 1
	if count_str.strip_edges() != "" and count_str.is_valid_int():
		count = clampi(int(count_str), 1, 20)
	var am = null
	if ge and ge.has_method("get_achievement_manager"):
		am = ge.get_achievement_manager()
	if am == null or am.achievements.is_empty():
		if c: c.print_error("AchievementManager недоступен")
		return
	var pool: Array = []
	for a in am.achievements:
		if a is Dictionary and not bool(a.get("deprecated", false)):
			pool.append(a)
	if pool.is_empty():
		if c: c.print_error("Нет доступных достижений")
		return
	pool.shuffle()
	for i in range(mini(count, pool.size())):
		var pick: Dictionary = pool[i]
		if ge and ge.has_method("show_achievement_popup"):
			ge.show_achievement_popup(pick)
		elif ge and ge.has_method("get_achievement_queue_manager"):
			var qm = ge.get_achievement_queue_manager()
			if qm and qm.has_method("add_achievement_to_queue"):
				qm.add_achievement_to_queue(pick)
	if c:
		c.print_info("Показано достижений: %d (без разблокировки)" % mini(count, pool.size()))


func _notif_show_random(count_str: String = ""):
	var c = get_tree().root.get_node_or_null("Console")
	var count := 1
	if count_str.strip_edges() != "" and count_str.is_valid_int():
		count = clampi(int(count_str), 1, 20)
	var dock := _get_status_dock()
	if dock == null or not dock.has_method("show_transient"):
		# Fallback via StatusToast
		dock = null
	var pool: Array[Dictionary] = [
		{"id": "settings", "text": tr("STATUS_SAVED"), "kind": "success", "duration": 2.5},
		{"id": "library_scan", "text": tr("MISC_SCAN_SONGS_NONE"), "kind": "info", "duration": 2.5},
		{"id": "gen_queue_dup", "text": tr("GEN_QUEUE_ALREADY"), "kind": "info", "duration": 2.5},
		{"id": "gen_no_jobs", "text": tr("SONG_GEN_NOTHING_TO_DO"), "kind": "info", "duration": 2.5},
		{"id": "practice_need_range", "text": tr("PAUSE_PRACTICE_NEED_RANGE"), "kind": "warn", "duration": 2.0},
		{"id": "rhythm_dna_missing", "text": tr("DNA_TOAST_UNAVAILABLE"), "kind": "info", "duration": 2.5},
	]
	pool.shuffle()
	for i in range(count):
		var item: Dictionary = pool[i % pool.size()]
		var nid: String = str(item.get("id", "notif")) + ("_%d" % i)
		var ntext: String = str(item.get("text", ""))
		var nkind: String = str(item.get("kind", "info"))
		var ndur: float = float(item.get("duration", 2.5))
		if dock != null:
			dock.show_transient(nid, ntext, nkind, ndur)
		else:
			var st := get_tree().root.get_node_or_null("GameEngine")
			if st == null:
				var StatusToast = preload("res://logic/ui/status_toast.gd")
				StatusToast.show_from_node(c if c != null else get_tree().root, nid, ntext, nkind, ndur)
	if c:
		c.print_info("Показано уведомлений: %d" % count)


func _notif_show_scan():
	var c = get_tree().root.get_node_or_null("Console")
	var dock := _get_status_dock()
	if dock == null:
		if c:
			c.print_error("StatusDock не найден")
		return
	dock.show_operation({"id":"library_scan","title":tr("STATUS_LIBRARY_SCANNING"),"subtitle":"","progress":0.0,"indeterminate":true,"compact":false,"icon_kind":"scan"})
	if c:
		c.print_info("Сканирование... показано, через 3с будет success")
	await get_tree().create_timer(3.0).timeout
	dock.clear_operation("library_scan")
	dock.show_transient("library_scan", tr("MISC_SCAN_SONGS_ADDED") % 5, "success", 3.0)
	if c:
		c.print_info("Сканирование success показано")


func _get_status_dock() -> Control:
	var ge = _get_engine()
	if ge:
		var nl := ge.get_node_or_null("NotificationsLayer")
		if nl:
			return nl.get_node_or_null("StatusDock") as Control
	return get_tree().root.get_node_or_null("GameEngine/NotificationsLayer/StatusDock") as Control

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

## Read-only диагностика календарных event-достижений (дни рождения/сезонные).
## Использует только pure API AchievementManager (get_event_date /
## get_calendar_event_ids / get_event_window) и read-only геттеры
## get_achievement_by_id / is_deprecated. НЕ вызывает check_event_achievements,
## unlock, save_achievements, resync и не меняет PlayerData.
func _event_status():
	var c = get_tree().root.get_node_or_null("Console")
	var date: Dictionary = AchievementManager.get_event_date()
	var stamp := "%04d-%02d-%02d" % [int(date.get("year", 0)), int(date.get("month", 0)), int(date.get("day", 0))]
	var am = null
	var ge = _get_engine()
	if ge and ge.has_method("get_achievement_manager"):
		am = ge.get_achievement_manager()
	if c:
		c.print_info("EVENT STATUS")
		c.print_info("Local system date: " + stamp)
	for event_id in AchievementManager.get_calendar_event_ids():
		var w: Dictionary = AchievementManager.get_event_window(event_id, date)
		var in_catalog := false
		var deprecated := false
		var unlocked := false
		if am and am.has_method("get_achievement_by_id"):
			var a = am.get_achievement_by_id(event_id)
			if a is Dictionary and not (a as Dictionary).is_empty():
				in_catalog = true
				deprecated = AchievementManager.is_deprecated(a)
				unlocked = bool((a as Dictionary).get("unlocked", false))
		if c:
			c.print_info("Event %d:" % event_id)
			c.print_info("  Window: %s..%s" % [str(w.get("start", "")), str(w.get("end", ""))])
			c.print_info("  Active now: " + str(bool(w.get("active", false))))
			c.print_info("  In catalog: " + str(in_catalog))
			c.print_info("  Deprecated: " + str(deprecated))
			c.print_info("  Unlocked: " + str(unlocked))
	if c:
		c.print_info("FINAL: read-only; no unlock/save performed.")

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

func _songs_dump_seed(path_opt := ""):
	pass

func _songs_apply_seed(path_opt := ""):
	pass

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
	PlayerDataManager.increment_daily_progress(ev, v, _daily_context_for_quest(q))
	if c: c.print_info("Прогресс обновлён")

func _daily_context_for_quest(q: Dictionary) -> Dictionary:
	var ev := String(q.get("event", ""))
	match ev:
		"accuracy_80", "accuracy_90", "accuracy_95":
			return {"accuracy": 100.0}
		"combo_reached", "combo_reached_60", "combo_reached_100":
			return {"max_combo": 100}
		"missless":
			return {"missed_notes": 0}
		"play_drum_level":
			return {"is_drum_mode": true}
		"play_bass_level":
			return {"is_bass_mode": true}
		"play_genre_group":
			var target_group := str(q.get("target_group", "")).strip_edges()
			if target_group != "":
				return {"group": target_group}
			return {}
		_:
			return {}

func _daily_complete(token: String):
	var c = get_tree().root.get_node_or_null("Console")
	var q = _resolve_daily_by_token(token)
	if q.is_empty():
		if c: c.print_error("Ежедневка не найдена: " + token)
		return
	var ev = String(q.get("event",""))
	PlayerDataManager.increment_daily_progress(ev, 999999, _daily_context_for_quest(q))
	if c: c.print_info("Ежедневка завершена")
	
func _daily_complete_all():
	var c = get_tree().root.get_node_or_null("Console")
	var qs = PlayerDataManager.get_daily_quests()
	if qs.is_empty():
		if c: c.print_error("Ежедневки отсутствуют")
		return
	for q in qs:
		var ev = String(q.get("event",""))
		PlayerDataManager.increment_daily_progress(ev, 999999, _daily_context_for_quest(q))
	if c: c.print_info("Все текущие ежедневки завершены")

func _game_seek_to_no_notes():
	var c = get_tree().root.get_node_or_null("Console")
	var gs = _get_game_screen()
	if not gs:
		if c: c.print_error("GameScreen не найден")
		return
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
	var target := 0.0
	if duration_seconds > 0.0:
		target = max(0.0, duration_seconds - 10.0)
	else:
		target = 0.0
	gs.game_time = target
	if MusicManager.has_method("set_music_position"):
		MusicManager.set_music_position(target)
	if gs.note_manager:
		gs.note_manager.clear_notes()
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

func _get_canonical_sections_for_current_game() -> Array:
	var gs = _get_game_screen()
	if gs == null:
		return []
	var song_path := ""
	if "selected_song_data" in gs and gs.selected_song_data is Dictionary:
		song_path = str(gs.selected_song_data.get("path", "")).strip_edges()
	if song_path == "" and "song_info" in gs and gs.song_info is Dictionary:
		song_path = str(gs.song_info.get("path", "")).strip_edges()
	if song_path == "" and gs.has_method("get_current_song_path"):
		song_path = str(gs.get_current_song_path()).strip_edges()
	if song_path == "":
		return []
	var NotesUtils = preload("res://logic/domain/rhythm/notes_utils.gd")
	var canon_secs := NotesUtils.load_canonical_sections(song_path)
	if canon_secs.is_empty():
		return []
	var RhythmDnaView = preload("res://logic/data/rhythm_dna_view.gd")
	var sections := RhythmDnaView.annotate_sections_with_names(canon_secs)
	if sections.is_empty():
		var raw_sections := RhythmDnaView.resolve_structure_timeline_for_ui({"structure_timeline": canon_secs})
		sections = RhythmDnaView.annotate_sections_with_names(raw_sections)
	return sections

func _seek_to_section_time(target: float, section_label: String) -> void:
	var c = get_tree().root.get_node_or_null("Console")
	var gs = _get_game_screen()
	if gs == null:
		if c:
			c.print_error("GameScreen не найден — открой уровень (игра), затем game.seek.*")
		return
	var t := maxf(0.0, target)
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
		if section_label != "":
			c.print_info("Перемещено к %s: %s сек (%s:%s)" % [section_label, str(t), str(m).pad_zeros(2), str(s).pad_zeros(2)])
		else:
			c.print_info("Перемещено к позиции: " + str(t) + " сек (" + str(m).pad_zeros(2) + ":" + str(s).pad_zeros(2) + ")")

func _game_seek_section(number_str: String):
	var c = get_tree().root.get_node_or_null("Console")
	var gs = _get_game_screen()
	if gs == null:
		if c:
			c.print_error("GameScreen не найден — открой уровень (игра), затем game.seek.section <number>")
		return
	var n := int(number_str.strip_edges())
	if number_str.strip_edges() == "" or not number_str.strip_edges().is_valid_int() or n <= 0:
		if c:
			c.print_error("Некорректный номер секции: '%s' (ожидается 1..N)" % number_str)
		return
	var sections := _get_canonical_sections_for_current_game()
	if sections.is_empty():
		if c:
			c.print_error("У текущего чарта нет секций (sections.rfd отсутствует)")
		return
	if n < 1 or n > sections.size():
		if c:
			c.print_error("Секция %d не существует (доступно 1..%d)" % [n, sections.size()])
		return
	var seg: Dictionary = sections[n - 1] if sections[n - 1] is Dictionary else {}
	var target := float(seg.get("start_s", 0.0))
	var label := "секции %d" % n
	if seg.has("display_full"):
		label = str(seg.get("display_full", label))
	elif seg.has("role"):
		label = str(seg.get("role", label))
	_seek_to_section_time(target, label)

func _game_seek_intro():
	var c = get_tree().root.get_node_or_null("Console")
	var gs = _get_game_screen()
	if gs == null:
		if c:
			c.print_error("GameScreen не найден — открой уровень (игра), затем game.seek.intro")
		return
	var sections := _get_canonical_sections_for_current_game()
	if sections.is_empty():
		if c:
			c.print_error("У текущего чарта нет секций (sections.rfd отсутствует)")
		return
	var found: Dictionary = {}
	for seg in sections:
		if not seg is Dictionary:
			continue
		var role_norm := str(seg.get("role", "")).strip_edges().to_lower().replace("_", "-")
		if role_norm == "intro":
			found = seg
			break
	if found.is_empty():
		if c:
			c.print_error("Intro секция не найдена (роль intro отсутствует)")
		return
	var target := float(found.get("start_s", 0.0))
	var label := "intro"
	if found.has("display_full"):
		label = str(found.get("display_full", label))
	_seek_to_section_time(target, label)

func _game_seek_outro():
	var c = get_tree().root.get_node_or_null("Console")
	var gs = _get_game_screen()
	if gs == null:
		if c:
			c.print_error("GameScreen не найден — открой уровень (игра), затем game.seek.outro")
		return
	var sections := _get_canonical_sections_for_current_game()
	if sections.is_empty():
		if c:
			c.print_error("У текущего чарта нет секций (sections.rfd отсутствует)")
		return
	var found: Dictionary = {}
	for i in range(sections.size() - 1, -1, -1):
		var seg = sections[i]
		if not seg is Dictionary:
			continue
		var role_norm := str(seg.get("role", "")).strip_edges().to_lower().replace("_", "-")
		if role_norm == "outro":
			found = seg
			break
	if found.is_empty():
		if c:
			c.print_error("Outro секция не найдена (роль outro отсутствует)")
		return
	var target := float(found.get("start_s", 0.0))
	var label := "outro"
	if found.has("display_full"):
		label = str(found.get("display_full", label))
	_seek_to_section_time(target, label)

func _game_seek_random():
	var c = get_tree().root.get_node_or_null("Console")
	var gs = _get_game_screen()
	if gs == null:
		if c:
			c.print_error("GameScreen не найден — открой уровень (игра), затем game.seek.random")
		return
	var sections := _get_canonical_sections_for_current_game()
	if sections.is_empty():
		if c:
			c.print_error("У текущего чарта нет секций (sections.rfd отсутствует)")
		return
	var idx := randi() % sections.size()
	var seg: Dictionary = sections[idx] if sections[idx] is Dictionary else {}
	var target := float(seg.get("start_s", 0.0))
	var label := "случайной секции %d" % (idx + 1)
	if seg.has("display_full"):
		label = str(seg.get("display_full", label))
	_seek_to_section_time(target, label)

func _chart_sections():
	var c = get_tree().root.get_node_or_null("Console")
	var gs = _get_game_screen()
	if gs == null:
		if c:
			c.print_error("GameScreen не найден — открой уровень (игра), затем chart.sections")
		return
	var sections := _get_canonical_sections_for_current_game()
	if sections.is_empty():
		if c:
			c.print_info("No canonical sections found for current chart.")
		return
	if c:
		c.print_info("Sections: %d" % sections.size())
		for i in range(sections.size()):
			var seg: Dictionary = sections[i] if sections[i] is Dictionary else {}
			var start_s := float(seg.get("start_s", 0.0))
			var end_s := float(seg.get("end_s", start_s))
			var role: String = ""
			if seg.has("display_full"):
				role = str(seg.get("display_full", ""))
			elif seg.has("role"):
				role = str(seg.get("role", ""))
			elif seg.has("section"):
				role = str(seg.get("section", ""))
			elif seg.has("label_key"):
				role = str(seg.get("label_key", ""))
			if role.strip_edges() == "":
				role = "—"
			var start_str := _format_section_time(start_s)
			var end_str := _format_section_time(end_s)
			c.print_info("%d. %s–%s  %s" % [i + 1, start_str, end_str, role])

func _format_section_time(t: float) -> String:
	var total_ms := int(round(t * 1000.0))
	var m := int(total_ms / 60000)
	var s := int((total_ms % 60000) / 1000)
	var ms := total_ms % 1000
	return "%02d:%02d.%03d" % [m, s, ms]

func _daily_load_all():
	var c = get_tree().root.get_node_or_null("Console")
	var today = Time.get_date_string_from_system()
	var quest_pool: Array = []
	var user_path = "user://daily_quests.json"
	var path = user_path if FileAccess.file_exists(user_path) else "res://data/daily_quests.json"
	var file = FileAccess.open(path, FileAccess.READ)
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

func _diag_verify_data():
	var c = get_tree().root.get_node_or_null("Console")
	var total_checks = 0
	var failed = 0
	var function_exists = func(path: String) -> bool:
		return ResourceLoader.exists(path)
	var parse_with_fallback = func(user_path: String, res_path: String):
		var used = ""
		var data = null
		var p = user_path if FileAccess.file_exists(user_path) else res_path
		var f = FileAccess.open(p, FileAccess.READ)
		if f:
			used = p
			var txt = f.get_as_text()
			f.close()
			data = JSON.parse_string(txt)
		return [data, used]
	var ach_res = parse_with_fallback.call("user://achievements_data.json", "res://data/achievements_data.json")
	total_checks += 1
	if ach_res[0] is Dictionary and ach_res[0].has("achievements") and (ach_res[0].achievements is Array):
		if c: c.print_info("OK: achievements_data.json -> " + String(ach_res[1]))
	else:
		failed += 1
		if c: c.print_error("FAIL: achievements_data.json")
	var shop_res = parse_with_fallback.call("user://shop_data.json", "res://data/shop_data.json")
	total_checks += 1
	if shop_res[0] is Dictionary and shop_res[0].has("items") and (shop_res[0].items is Array):
		if c: c.print_info("OK: shop_data.json -> " + String(shop_res[1]))
	else:
		failed += 1
		if c: c.print_error("FAIL: shop_data.json")
	var dq_res = parse_with_fallback.call("user://daily_quests.json", "res://data/daily_quests.json")
	total_checks += 1
	if dq_res[0] is Dictionary and dq_res[0].has("quests") and (dq_res[0].quests is Array):
		if c: c.print_info("OK: daily_quests.json -> " + String(dq_res[1]))
	else:
		failed += 1
		if c: c.print_error("FAIL: daily_quests.json")
	var gg_res = parse_with_fallback.call("user://genre_groups.json", "res://data/genre_groups.json")
	total_checks += 1
	if gg_res[0] is Dictionary:
		if c: c.print_info("OK: genre_groups.json -> " + String(gg_res[1]))
	else:
		failed += 1
		if c: c.print_error("FAIL: genre_groups.json")
	if shop_res[0] is Dictionary and shop_res[0].has("items") and (shop_res[0].items is Array):
		var items = shop_res[0].items
		var missing_assets = 0
		for it in items:
			if it is Dictionary:
				var ap = String(it.get("audio",""))
				if ap != "":
					if not ap.begins_with("res://"):
						ap = "res://assets/shop/sounds/" + ap
					if not function_exists.call(ap):
						missing_assets += 1
		total_checks += 1
		if missing_assets == 0:
			if c: c.print_info("OK: аудиофайлы магазина доступны")
		else:
			failed += 1
			if c: c.print_error("WARN: отсутствуют аудиофайлы магазина: " + str(missing_assets))
	if ach_res[0] is Dictionary and ach_res[0].has("achievements") and (ach_res[0].achievements is Array) and shop_res[0] is Dictionary:
		var ach_list: Array = ach_res[0].achievements
		var ach_titles := {}
		var ach_ids := {}
		for a in ach_list:
			if a is Dictionary:
				ach_titles[str(a.get("title","")).to_lower()] = true
				ach_ids[str(a.get("id",""))] = true
		var bad_links = 0
		for it in shop_res[0].get("items", []):
			if it is Dictionary and bool(it.get("is_achievement_reward", false)):
				var req = String(it.get("achievement_required","")).strip_edges()
				if req != "":
					var ok = ach_titles.has(req.to_lower()) or ach_ids.has(req)
					if not ok:
						bad_links += 1
		total_checks += 1
		if bad_links == 0:
			if c: c.print_info("OK: связи магазин↔достижения консистентны")
		else:
			failed += 1
			if c: c.print_error("WARN: неконсистентные ссылки магазин↔достижения: " + str(bad_links))
	if c:
		c.print_info("Итог: " + str(total_checks - failed) + " OK / " + str(total_checks) + " всего")

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

func _game_score_add(amount_str: String):
	var c = get_tree().root.get_node_or_null("Console")
	var gs = _get_game_screen()
	if not gs or not gs.score_manager:
		if c: c.print_error("ScoreManager недоступен")
		return
	var amt = _parse_bounded_delta(amount_str)
	if amt <= 0:
		if c: c.print_error("Значение должно быть > 0")
		return
	var current_combo = gs.score_manager.combo
	var multiplier = min(4.0, 1.0 + float(int(current_combo / 10)))
	var actual_points = int(amt * multiplier)
	gs.score_manager.score += actual_points
	if gs.has_method("update_ui"):
		gs.update_ui()
	if c:
		c.print_info("Добавлено очков: %d (x%.1f)" % [actual_points, multiplier])

func _game_score_sub(amount_str: String):
	var c = get_tree().root.get_node_or_null("Console")
	var gs = _get_game_screen()
	if not gs or not gs.score_manager:
		if c: c.print_error("ScoreManager недоступен")
		return
	var amt = _parse_bounded_delta(amount_str)
	if amt <= 0:
		if c: c.print_error("Значение должно быть > 0")
		return
	gs.score_manager.score = max(0, gs.score_manager.score - amt)
	if gs.has_method("update_ui"):
		gs.update_ui()
	if c:
		c.print_info("Минус очков: %d | Текущий счёт: %d" % [amt, gs.score_manager.score])

func _game_combo_add(amount_str: String):
	var c = get_tree().root.get_node_or_null("Console")
	var gs = _get_game_screen()
	if not gs or not gs.score_manager:
		if c: c.print_error("ScoreManager недоступен")
		return
	var amt = max(0, _parse_int(amount_str))
	if amt <= 0:
		if c: c.print_error("Значение должно быть > 0")
		return
	var new_combo = gs.score_manager.combo + amt
	gs.score_manager.combo = new_combo
	if new_combo > gs.score_manager.max_combo:
		gs.score_manager.max_combo = new_combo
	gs.score_manager.combo_multiplier = min(4.0, 1.0 + float(int(new_combo / 10)))
	if gs.has_method("update_ui"):
		gs.update_ui()
	if c:
		c.print_info("Комбо: %d | Макс.: %d | Множитель: x%.1f" % [gs.score_manager.combo, gs.score_manager.max_combo, gs.score_manager.combo_multiplier])

func _game_combo_sub(amount_str: String):
	var c = get_tree().root.get_node_or_null("Console")
	var gs = _get_game_screen()
	if not gs or not gs.score_manager:
		if c: c.print_error("ScoreManager недоступен")
		return
	var amt = max(0, _parse_int(amount_str))
	if amt <= 0:
		if c: c.print_error("Значение должно быть > 0")
		return
	var new_combo = max(0, gs.score_manager.combo - amt)
	gs.score_manager.combo = new_combo
	gs.score_manager.combo_multiplier = min(4.0, 1.0 + float(int(new_combo / 10)))
	if gs.has_method("update_ui"):
		gs.update_ui()
	if c:
		c.print_info("Комбо: %d | Макс.: %d | Множитель: x%.1f" % [gs.score_manager.combo, gs.score_manager.max_combo, gs.score_manager.combo_multiplier])

func _resolve_game_total_notes(gs) -> int:
	var total := int(gs.score_manager.total_notes)
	if total <= 0 and gs.note_manager and gs.note_manager.has_method("get_spawn_queue_size"):
		total = int(gs.note_manager.get_spawn_queue_size())
	if total <= 0:
		total = gs.score_manager.get_hit_notes_count() + gs.score_manager.get_missed_notes_count()
	return maxi(total, 1)

func _parse_accuracy_arg(raw) -> float:
	var text := str(raw).strip_edges()
	if text == "" or not text.is_valid_float():
		return -1.0
	return clampf(text.to_float(), 0.0, 100.0)

func _apply_simulated_accuracy(gs, target_accuracy: float) -> Dictionary:
	var total_notes := _resolve_game_total_notes(gs)
	target_accuracy = clampf(target_accuracy, 0.0, 100.0)
	var missed_notes := int(floor(float(total_notes) * (100.0 - target_accuracy) / 100.0))
	missed_notes = clampi(missed_notes, 0, total_notes)
	var hit_notes := total_notes - missed_notes
	gs.score_manager.total_notes = total_notes
	gs.score_manager.missed_notes = missed_notes
	gs.score_manager.hit_notes = hit_notes
	gs.score_manager.set_accuracy(target_accuracy)
	return {
		"total_notes": total_notes,
		"hit_notes": hit_notes,
		"missed_notes": missed_notes,
		"accuracy": target_accuracy,
	}

func _game_accuracy_set(percent_str: String):
	var c = get_tree().root.get_node_or_null("Console")
	var gs = _get_game_screen()
	if not gs or not gs.score_manager:
		if c: c.print_error("ScoreManager недоступен")
		return
	var target := _parse_accuracy_arg(percent_str)
	if target < 0.0:
		if c: c.print_error("Процент должен быть числом")
		return
	var stats := _apply_simulated_accuracy(gs, target)
	if gs.has_method("update_ui"):
		gs.update_ui()
	if c:
		c.print_info(
			"Точность установлена: %.2f%% (total=%d, hit=%d, miss=%d)"
			% [stats.accuracy, stats.total_notes, stats.hit_notes, stats.missed_notes]
		)

func _game_series_win(accuracy_opt = ""):
	var c = get_tree().root.get_node_or_null("Console")
	var gs = _get_game_screen()
	if gs == null:
		if c:
			c.print_error("GameScreen недоступен — открой уровень (игра), затем series.win")
		return
	if not gs.has_method("_is_series_mode") or not bool(gs.call("_is_series_mode")):
		if c:
			c.print_error("series.win работает только в выживании или марафоне")
		return
	_game_win(accuracy_opt)
	if c:
		var mode := "endless"
		if gs.has_method("_is_marathon_mode") and bool(gs.call("_is_marathon_mode")):
			mode = "marathon"
		c.print_info("Серия (%s): трек засчитан, переход к следующему или итогам." % mode)

func _game_win(accuracy_opt = ""):
	var c = get_tree().root.get_node_or_null("Console")
	var gs = _get_game_screen()
	var sm = _get_score_manager(gs)
	var nm = _get_note_manager(gs)
	if gs == null or sm == null or nm == null:
		if c:
			c.print_error("GameScreen недоступен — открой уровень (игра), затем game.win")
		return
	var parsed := _parse_accuracy_arg(accuracy_opt)
	var override := parsed >= 0.0
	var target_accuracy: float = parsed if override else float(sm.get_accuracy())
	var total_notes: int = int(sm.total_notes)
	if override:
		var stats := _apply_simulated_accuracy(gs, target_accuracy)
		total_notes = stats.total_notes
		target_accuracy = stats.accuracy
	var hits_for_combo = sm.get_hit_notes_count()
	if target_accuracy >= 100.0 and hits_for_combo > 0:
		sm.combo = hits_for_combo
		sm.max_combo = max(sm.max_combo, hits_for_combo)
		gs.perfect_hits_this_level = hits_for_combo
	elif override:
		gs.perfect_hits_this_level = hits_for_combo
	var base_score_per_hit = 100
	var multiplier = 1.0
	if target_accuracy >= 100.0:
		multiplier = min(4.0, 1.0 + (float(total_notes) / 10.0))
	elif target_accuracy >= 95.0:
		multiplier = 2.0
	elif target_accuracy >= 90.0:
		multiplier = 1.5
	var current_score = sm.get_score()
	var recompute = override or current_score <= 0
	if recompute:
		# Recompute reward mult from active run mods (can be stale/1.0 if runtime apply was skipped).
		var RunModifiers = load("res://logic/domain/modifiers/run_modifiers.gd")
		if RunModifiers and ("run_modifiers_player" in gs):
			var params: Dictionary = {}
			if "run_modifier_params" in gs and gs.run_modifier_params is Dictionary:
				params = gs.run_modifier_params
			gs._score_reward_multiplier = RunModifiers.reward_multiplier(gs.run_modifiers_player, params)
		if gs.has_method("_apply_score_reward_multiplier"):
			gs._apply_score_reward_multiplier()
		var hits_for_score = max(1, sm.get_hit_notes_count())
		var raw_total := int(hits_for_score * base_score_per_hit * multiplier)
		if sm.has_method("set_raw_score"):
			sm.set_raw_score(raw_total)
		else:
			sm.score = raw_total
	if gs.has_method("update_ui"):
		gs.update_ui()
	if nm.has_method("clear_notes"):
		nm.clear_notes()
	print("[RUN PIPELINE] debug_commands.game.win entered accuracy_opt=%s target_accuracy=%s play_mode=%s song_path=%s" % [str(accuracy_opt), str(target_accuracy), str(gs._play_mode), str(gs.selected_song_data.get("path",""))])
	if gs.has_method("end_game"):
		print("[RUN PIPELINE] debug_commands.game.win calling gs.end_game() source=debug_win")
		gs.end_game()
	if c:
		var reward_mult := 1.0
		if sm.has_method("get_score_reward_multiplier"):
			reward_mult = float(sm.get_score_reward_multiplier())
		c.print_info(
			"Симулировано завершение уровня (точность: %.2f%%, hit=%d, miss=%d, raw=%d, mod×%.2f, score=%d)"
			% [
				sm.get_accuracy(),
				sm.get_hit_notes_count(),
				sm.get_missed_notes_count(),
				sm.get_raw_score() if sm.has_method("get_raw_score") else sm.get_score(),
				reward_mult,
				sm.get_score(),
			]
		)

func _game_win_nosave(accuracy_opt = "") -> void:
	var c = get_tree().root.get_node_or_null("Console")
	var gs = _get_game_screen()
	var sm = _get_score_manager(gs)
	var nm = _get_note_manager(gs)
	if gs == null or sm == null or nm == null:
		if c:
			c.print_error("GameScreen недоступен — открой уровень (игра), затем game.win_nosave")
		return
	var parsed := _parse_accuracy_arg(accuracy_opt)
	var override := parsed >= 0.0
	var target_accuracy: float = parsed if override else float(sm.get_accuracy())
	var total_notes: int = int(sm.total_notes)
	if override:
		var stats := _apply_simulated_accuracy(gs, target_accuracy)
		total_notes = stats.total_notes
		target_accuracy = stats.accuracy
	var hits_for_combo = sm.get_hit_notes_count()
	if target_accuracy >= 100.0 and hits_for_combo > 0:
		sm.combo = hits_for_combo
		sm.max_combo = max(sm.max_combo, hits_for_combo)
		gs.perfect_hits_this_level = hits_for_combo
	elif override:
		gs.perfect_hits_this_level = hits_for_combo
	var base_score_per_hit = 100
	var multiplier = 1.0
	if target_accuracy >= 100.0:
		multiplier = min(4.0, 1.0 + (float(total_notes) / 10.0))
	elif target_accuracy >= 95.0:
		multiplier = 2.0
	elif target_accuracy >= 90.0:
		multiplier = 1.5
	var current_score = sm.get_score()
	var recompute = override or current_score <= 0
	if recompute:
		var RunModifiers = load("res://logic/domain/modifiers/run_modifiers.gd")
		if RunModifiers and ("run_modifiers_player" in gs):
			var params: Dictionary = {}
			if "run_modifier_params" in gs and gs.run_modifier_params is Dictionary:
				params = gs.run_modifier_params
			gs._score_reward_multiplier = RunModifiers.reward_multiplier(gs.run_modifiers_player, params)
		if gs.has_method("_apply_score_reward_multiplier"):
			gs._apply_score_reward_multiplier()
		var hits_for_score = max(1, sm.get_hit_notes_count())
		var raw_total := int(hits_for_score * base_score_per_hit * multiplier)
		if sm.has_method("set_raw_score"):
			sm.set_raw_score(raw_total)
		else:
			sm.score = raw_total
	if gs.has_method("update_ui"):
		gs.update_ui()
	if nm.has_method("clear_notes"):
		nm.clear_notes()
	print("[RUN PIPELINE] debug_commands.game.win_nosave entered accuracy_opt=%s target_accuracy=%s play_mode=%s song_path=%s" % [str(accuracy_opt), str(target_accuracy), str(gs._play_mode), str(gs.selected_song_data.get("path",""))])
	if gs.has_method("end_game"):
		print("[RUN PIPELINE] debug_commands.game.win_nosave calling gs.end_game() source=debug_win_nosave (non-persistent)")
		if "is_test_preview" in gs:
			gs.is_test_preview = true
		if gs.has_method("set_meta"):
			gs.set_meta("debug_win_no_save", true)
		# Ensure VictoryScreen can detect non-persistent via song_info
		if "selected_song_data" in gs and gs.selected_song_data is Dictionary:
			gs.selected_song_data["debug_win_no_save"] = true
			gs.selected_song_data["is_test_preview"] = true
		gs.end_game()
	if c:
		var reward_mult := 1.0
		if sm.has_method("get_score_reward_multiplier"):
			reward_mult = float(sm.get_score_reward_multiplier())
		c.print_info(
			"Симулировано завершение уровня (без сохранения) (точность: %.2f%%, hit=%d, miss=%d, raw=%d, mod×%.2f, score=%d)"
			% [
				sm.get_accuracy(),
				sm.get_hit_notes_count(),
				sm.get_missed_notes_count(),
				sm.get_raw_score() if sm.has_method("get_raw_score") else sm.get_score(),
				reward_mult,
				sm.get_score(),
			]
		)

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

func _timing_debug_status():
	var c = get_tree().root.get_node_or_null("Console")
	if SettingsManager == null:
		if c:
			c.print_error("SettingsManager недоступен")
		return
	var log_on := SettingsManager.get_timing_debug_log_hits()
	var ov_on := SettingsManager.get_timing_debug_overlay()
	var apw := SettingsManager.get_autoplay_respects_hit_windows()
	if c:
		c.print_info("(Только до выхода из игры; не сохраняется в settings.json)")
		c.print_info("Лог попаданий (CSV + консоль): " + ("ВКЛ." if log_on else "ВЫКЛ."))
		c.print_info("Оверлей на игровом экране: " + ("ВКЛ." if ov_on else "ВЫКЛ."))
		c.print_info("Автоплей с окнами судьи как у человека: " + ("ВКЛ." if apw else "ВЫКЛ."))
		c.print_info("Файл CSV: user://timing_hit_debug.csv")

func _timing_debug_log_toggle():
	var c = get_tree().root.get_node_or_null("Console")
	if SettingsManager == null or not SettingsManager.has_method("set_timing_debug_log_hits"):
		if c:
			c.print_error("SettingsManager: нет поддержки лога тайминга")
		return
	var v := not SettingsManager.get_timing_debug_log_hits()
	SettingsManager.set_timing_debug_log_hits(v)
	if c:
		c.print_info("timing.debug.log: " + ("ВКЛ." if v else "ВЫКЛ."))

func _timing_debug_overlay_toggle():
	var c = get_tree().root.get_node_or_null("Console")
	if SettingsManager == null or not SettingsManager.has_method("set_timing_debug_overlay"):
		if c:
			c.print_error("SettingsManager: нет поддержки оверлея")
		return
	var v := not SettingsManager.get_timing_debug_overlay()
	SettingsManager.set_timing_debug_overlay(v)
	if c:
		c.print_info("timing.debug.overlay: " + ("ВКЛ." if v else "ВЫКЛ."))

func _timing_autoplay_windows_toggle():
	var c = get_tree().root.get_node_or_null("Console")
	if SettingsManager == null or not SettingsManager.has_method("set_autoplay_respects_hit_windows"):
		if c:
			c.print_error("SettingsManager: нет поддержки режима автоплея")
		return
	var v := not SettingsManager.get_autoplay_respects_hit_windows()
	SettingsManager.set_autoplay_respects_hit_windows(v)
	if c:
		c.print_info("timing.autoplay.windows: " + ("ВКЛ." if v else "ВЫКЛ."))

func _tutorial_song_select_reset() -> void:
	var c = get_tree().root.get_node_or_null("Console")
	if SettingsManager == null or not SettingsManager.has_method("set_tutorial_song_select_done"):
		if c:
			c.print_error("SettingsManager: нет флага tutorial_song_select_done")
		return
	SettingsManager.set_tutorial_song_select_done(false)
	if c:
		c.print_info("Туториал библиотеки сброшен. Зайди в song select или выполни tutorial.song_select.show")

func _tutorial_song_select_show() -> void:
	var c = get_tree().root.get_node_or_null("Console")
	if SettingsManager == null or not SettingsManager.has_method("set_tutorial_song_select_done"):
		if c:
			c.print_error("SettingsManager: нет флага tutorial_song_select_done")
		return
	SettingsManager.set_tutorial_song_select_done(false)
	var ge = _get_engine()
	var screen: Node = ge.get("current_screen") if ge else null
	if screen and screen.has_method("debug_show_tutorial"):
		screen.debug_show_tutorial()
		if c:
			c.print_info("Туториал библиотеки запущен на текущем экране")
		return
	if c:
		c.print_info("Туториал сброшен. Открой библиотеку песен — overlay появится автоматически")

func _tutorial_shop_reset() -> void:
	var c = get_tree().root.get_node_or_null("Console")
	if SettingsManager == null or not SettingsManager.has_method("set_tutorial_shop_done"):
		if c:
			c.print_error("SettingsManager: нет флага tutorial_shop_done")
		return
	SettingsManager.set_tutorial_shop_done(false)
	if c:
		c.print_info("Туториал магазина сброшен. Зайди в магазин или выполни tutorial.shop.show")

func _tutorial_shop_show() -> void:
	var c = get_tree().root.get_node_or_null("Console")
	if SettingsManager == null or not SettingsManager.has_method("set_tutorial_shop_done"):
		if c:
			c.print_error("SettingsManager: нет флага tutorial_shop_done")
		return
	SettingsManager.set_tutorial_shop_done(false)
	var ge = _get_engine()
	var screen: Node = ge.get("current_screen") if ge else null
	if screen and screen.has_method("debug_show_tutorial"):
		screen.debug_show_tutorial()
		if c:
			c.print_info("Туториал магазина запущен на текущем экране")
		return
	if c:
		c.print_info("Туториал сброшен. Открой магазин — overlay появится автоматически")


func _tutorial_first_steps_reset() -> void:
	var c = get_tree().root.get_node_or_null("Console")
	if FirstStepsManager == null or not FirstStepsManager.has_method("reset_progress"):
		if c:
			c.print_error("FirstStepsManager недоступен")
		return
	FirstStepsManager.reset_progress()
	if c:
		c.print_info("Прогресс «Первых шагов» сброшен. Открой главное меню — блок появится снова")


func _tutorial_first_steps_show() -> void:
	var c = get_tree().root.get_node_or_null("Console")
	if FirstStepsManager == null or not FirstStepsManager.has_method("enter_preview"):
		if c:
			c.print_error("FirstStepsManager недоступен")
		return
	FirstStepsManager.enter_preview()
	if c:
		c.print_info("Предпросмотр «Первых шагов» включён с шага 1. Открой главное меню, затем tutorial.first_steps.next — следующий шаг")


func _tutorial_first_steps_next() -> void:
	var c = get_tree().root.get_node_or_null("Console")
	if FirstStepsManager == null or not FirstStepsManager.has_method("advance_preview"):
		if c:
			c.print_error("FirstStepsManager недоступен")
		return
	if not FirstStepsManager.is_preview_active():
		if c:
			c.print_info("Предпросмотр не активен. Сначала выполни tutorial.first_steps.show")
		return
	FirstStepsManager.advance_preview()
	if c:
		c.print_info("Показан шаг %d из %d" % [FirstStepsManager.get_step() + 1, FirstStepsManager.get_step_count()])


func _tutorial_practice_show() -> void:
	var c = get_tree().root.get_node_or_null("Console")
	if SettingsManager == null or not SettingsManager.has_method("set_tutorial_practice_done"):
		if c:
			c.print_error("SettingsManager недоступен")
		return
	SettingsManager.set_tutorial_practice_done(false)
	if c:
		c.print_info("Флаг туториала практики сброшен. Открой паузу → «Практика» — спотлайт покажется снова")


func _tutorial_first_steps_exit() -> void:
	var c = get_tree().root.get_node_or_null("Console")
	if FirstStepsManager == null or not FirstStepsManager.has_method("exit_preview"):
		if c:
			c.print_error("FirstStepsManager недоступен")
		return
	FirstStepsManager.exit_preview()
	if c:
		c.print_info("Предпросмотр «Первых шагов» выключен")


func _diary_toast_show(kind: String = "first_ss") -> void:
	var c = get_tree().root.get_node_or_null("Console")
	var ge = _get_engine()
	var host: Node = ge if ge else get_tree().root
	const _DiaryCelebration = preload("res://logic/ui/diary_celebration.gd")
	var sample := str(kind).strip_edges().to_lower()
	if sample == "":
		sample = "first_ss"
	_DiaryCelebration.debug_show(host, sample)
	if c:
		c.print_info("Diary toast: " + sample)


func _ui_notice_show(message: String = "") -> void:
	var c = get_tree().root.get_node_or_null("Console")
	var text := str(message).strip_edges()
	if text == "":
		text = "Test notice"
	var notice: Node = null
	var ge = _get_engine()
	var screen: Node = ge.get("current_screen") if ge else null
	if screen:
		notice = screen.find_child("NoticeOverlay", true, false)
	if notice == null:
		notice = get_tree().root.find_child("NoticeOverlay", true, false)
	if notice == null or not notice.has_method("show_message"):
		if c:
			c.print_error("NoticeOverlay не найден на текущем экране (нужен %NoticeOverlay / AppNoticeOverlay)")
		return
	notice.show_message(text)
	if c:
		c.print_info("Notice shown")


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
func _perf_debug(mode: String = "") -> void:
	var c = get_tree().root.get_node_or_null("Console")
	var arg := str(mode).strip_edges().to_lower()
	if arg == "":
		arg = "status"
	match arg:
		"off":
			PerfTrace.set_level(PerfTrace.Level.OFF)
			if c: c.print_info(PerfTrace.status_text())
		"load":
			PerfTrace.set_level(PerfTrace.Level.LOAD)
			if c: c.print_info(PerfTrace.status_text())
		"runtime":
			PerfTrace.set_level(PerfTrace.Level.RUNTIME)
			if c: c.print_info(PerfTrace.status_text())
		"detail":
			PerfTrace.set_level(PerfTrace.Level.DETAIL)
			if c: c.print_info(PerfTrace.status_text())
		"status":
			if c: c.print_info(PerfTrace.status_text())
		_:
			if c:
				c.print_error("perf.debug: неизвестный режим '%s' (ожидается off|load|runtime|detail|status)" % str(mode))
				c.print_info(PerfTrace.status_text())

func _perf_stats() -> void:
	var c = get_tree().root.get_node_or_null("Console")
	var text := PerfTrace.format_stats_text()
	if c:
		c.print_info(text)
	else:
		print(text)

func _perf_reset() -> void:
	PerfTrace.reset()
	var c = get_tree().root.get_node_or_null("Console")
	if c:
		c.print_info("[PERF] stats reset")


func _hitfx_debug(mode: String = "") -> void:
	var c = get_tree().root.get_node_or_null("Console")
	var key := mode.strip_edges().to_lower()
	const HitFX = preload("res://logic/domain/rhythm/hit_particle_presets.gd")
	if key == "":
		key = "status"
	match key:
		"legacy":
			HitFX.set_debug_mode(HitFX.DebugMode.LEGACY)
			if c: c.print_info("Hit FX debug: LEGACY")
		"current":
			HitFX.set_debug_mode(HitFX.DebugMode.CURRENT)
			if c: c.print_info("Hit FX debug: CURRENT")
		"status":
			if c:
				c.print_info("Hit FX debug: " + HitFX.get_debug_mode_name())
				var is_legacy := HitFX.get_debug_mode() == HitFX.DebugMode.LEGACY
				c.print_info("Hit FX rendering: " + ("null texture" if is_legacy else "procedural texture"))
				c.print_info("Hit FX secondary ring: " + ("disabled" if is_legacy else "enabled"))
		_:
			if c:
				c.print_error("hitfx.debug: неизвестный режим '%s' (ожидается legacy/current/status)" % mode)
				c.print_info("Hit FX debug: " + HitFX.get_debug_mode_name())
				var is_legacy2 := HitFX.get_debug_mode() == HitFX.DebugMode.LEGACY
				c.print_info("Hit FX rendering: " + ("null texture" if is_legacy2 else "procedural texture"))
				c.print_info("Hit FX secondary ring: " + ("disabled" if is_legacy2 else "enabled"))


func _debug_empty_state(state: String = "") -> void:
	var c = get_tree().root.get_node_or_null("Console")
	var key := str(state).strip_edges().to_lower()
	var DebugEmptyState = preload("res://logic/debug/debug_empty_state.gd")
	var new_state: bool
	match key:
		"on", "1", "true", "enable":
			new_state = true
			DebugEmptyState.set_enabled(true)
		"off", "0", "false", "disable":
			new_state = false
			DebugEmptyState.set_enabled(false)
		"", "toggle":
			new_state = DebugEmptyState.toggle()
		_:
			if c:
				c.print_error("debug.empty_state: неизвестный аргумент '%s' (ожидается on/off/toggle)" % state)
			return
	if c:
		c.print_info("debug.empty_state: " + ("ON — Main Menu/Profile показывают пустое состояние нового игрока (runtime only)" if new_state else "OFF — реальная история снова видима"))
	# Refresh already open Main Menu / Profile without restart if possible
	var tree := get_tree()
	if tree:
		for node in tree.root.find_children("*", "Control", true, false):
			if node.has_method("_render_last_track_panel") and node.has_method("queue_refresh_on_show"):
				if node.has_method("_render_last_track_panel"):
					node.call_deferred("_render_last_track_panel")
				if node.has_method("_render_hub_panels"):
					node.call_deferred("_render_hub_panels")
			if node is Control and node.has_method("_refresh_favorite_track"):
				node.call_deferred("_refresh_favorite_track")
				if node.has_method("_update_recent_achievements"):
					node.call_deferred("_update_recent_achievements")
			if node.has_method("_update_genre_portrait"):
				node.call_deferred("_update_genre_portrait")

func _debug_progress(type: String = "", value: String = "") -> void:
	var c = get_tree().root.get_node_or_null("Console")
	var t := str(type).strip_edges().to_lower()
	var v := str(value).strip_edges()
	var DebugProgress = preload("res://logic/debug/debug_progress.gd")
	var ok := false
	var msg := ""
	match t:
		"milestone":
			if v == "":
				if c:
					c.print_error("debug.progress milestone <id> — нужен id из whitelist (first_track_played, first_ss, first_fc, first_mod_clear, unique_100_tracks, clears_250, genre_group_level_10, total_rr_10000, endless_unlocked, marathon_unlocked)")
				return
			ok = DebugProgress.set_milestone(v)
			if not ok and c:
				c.print_error("debug.progress: неизвестный milestone '%s' (разрешённые: first_track_played, first_ss, first_fc, first_mod_clear, unique_100_tracks, clears_250, genre_group_level_10, total_rr_10000, endless_unlocked, marathon_unlocked)" % v)
				return
			msg = "milestone %s" % v
		"genre_mastery", "genre", "mastery":
			if v == "":
				if c:
					c.print_error("debug.progress genre_mastery <5|10|15|20>")
				return
			ok = DebugProgress.set_genre_mastery(v)
			if not ok and c:
				c.print_error("debug.progress: неизвестный уровень '%s' (разрешённые: 5, 10, 15, 20)" % v)
				return
			msg = "genre_mastery %s" % v
		"rr_total", "rr", "rr_ladder":
			if v == "":
				if c:
					c.print_error("debug.progress rr_total <25000|50000|100000|250000|500000|1000000>")
				return
			ok = DebugProgress.set_rr_total(v)
			if not ok and c:
				c.print_error("debug.progress: неизвестный порог '%s' (разрешённые: 25000, 50000, 100000, 250000, 500000, 1000000)" % v)
				return
			msg = "rr_total %s" % v
		"library", "lib":
			if v == "":
				if c:
					c.print_error("debug.progress library <100|500|1000>")
				return
			ok = DebugProgress.set_library(v)
			if not ok and c:
				c.print_error("debug.progress: неизвестный порог '%s' (разрешённые: 100, 500, 1000)" % v)
				return
			msg = "library %s" % v
		"off", "clear", "disable", "hide":
			DebugProgress.clear()
			if c:
				c.print_info("debug.progress: OFF — временное progress событие удалено (runtime only)")
			var tree2 := get_tree()
			if tree2:
				for node in tree2.root.find_children("*", "Control", true, false):
					if node.has_method("_render_last_track_panel") and node.has_method("queue_refresh_on_show"):
						if node.has_method("_render_hub_panels"):
							node.call_deferred("_render_hub_panels")
			return
		"":
			if c:
				c.print_error("debug.progress: нужен тип (milestone, genre_mastery, rr_total, library, off)")
			return
		_:
			if c:
				c.print_error("debug.progress: неизвестный тип '%s' (ожидается milestone|genre_mastery|rr_total|library|off)" % type)
			return
	if ok and c:
		c.print_info("debug.progress: %s — временное progress событие установлено (runtime only, now)" % msg)
	var tree := get_tree()
	if tree:
		for node in tree.root.find_children("*", "Control", true, false):
			if node.has_method("_render_last_track_panel") and node.has_method("queue_refresh_on_show"):
				if node.has_method("_render_hub_panels"):
					node.call_deferred("_render_hub_panels")

func _debug_scenario(name: String = "") -> void:
	var c = get_tree().root.get_node_or_null("Console")
	var key := str(name).strip_edges().to_lower()
	var DebugScenario = preload("res://logic/debug/debug_scenario.gd")
	var DebugEmptyState = preload("res://logic/debug/debug_empty_state.gd")
	match key:
		"activity":
			if DebugEmptyState.is_enabled() and c:
				c.print_warning("debug.scenario activity: включён debug.empty_state — Activity покажет empty, а не сценарий (empty_state имеет приоритет)")
			DebugScenario.set_activity()
			if c:
				c.print_info("debug.scenario activity — временный набор 5 Activity событий установлен (runtime only, now)")
		"off", "clear", "disable", "hide", "":
			var had := DebugScenario.has_activity_override()
			DebugScenario.clear_activity()
			if c:
				if had:
					c.print_info("debug.scenario: OFF — временный Activity сценарий удалён, возвращены реальные данные (runtime only)")
				else:
					c.print_info("debug.scenario: уже выключен")
		_:
			if c:
				c.print_error("debug.scenario: неизвестный сценарий '%s' (ожидается activity|off)" % name)
			return
	var tree2 := get_tree()
	if tree2:
		for node in tree2.root.find_children("*", "Control", true, false):
			if node.has_method("_render_last_track_panel") and node.has_method("queue_refresh_on_show"):
				if node.has_method("_render_hub_panels"):
					node.call_deferred("_render_hub_panels")
				if node.has_method("_render_last_track_panel"):
					node.call_deferred("_render_last_track_panel")

func _get_shop_item(id: String) -> Dictionary:
	var user_path = "user://shop_data.json"
	var path = user_path if FileAccess.file_exists(user_path) else "res://data/shop_data.json"
	var f = FileAccess.open(path, FileAccess.READ)
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
 
