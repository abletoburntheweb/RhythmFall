extends Node

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
	c.add_command("stats.hits.add", _stats_add_hits, ["count"], 1, "Добавить попадания")
	c.add_command("stats.misses.add", _stats_add_misses, ["count"], 1, "Добавить промахи")
	c.add_command("stats.perfect.add", _stats_add_perfect, ["count"], 1, "Добавить PERFECT")
	c.add_command("items.unlock", _item_unlock, ["item_id"], 1, "Открыть предмет")
	c.add_command("items.activate", _item_set_active, ["category", "item_id"], 2, "Активировать предмет")
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
	c.add_command_autocomplete_list("player.currency.add", PackedStringArray(["100","500","1000","5000"]))
	c.add_command_autocomplete_list("player.currency.set", PackedStringArray(["0","100","500","1000","5000"]))
	c.add_command_autocomplete_list("player.playtime.add_minutes", PackedStringArray(["10","30","60","120"]))
	c.add_command_autocomplete_list("stats.hits.add", PackedStringArray(["10","50","100","500"]))
	c.add_command_autocomplete_list("stats.misses.add", PackedStringArray(["1","5","10","50"]))
	c.add_command_autocomplete_list("stats.perfect.add", PackedStringArray(["1","5","10","50"]))
func _get_engine():
	return get_tree().root.get_node_or_null("GameEngine")
 
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
	PlayerDataManager.add_currency(int(amount_str))
	var c = get_tree().root.get_node_or_null("Console")
	if c:
		c.print_info("Добавлена валюта: " + amount_str)

func _player_set_currency(amount_str: String):
	var target = int(amount_str)
	var current = PlayerDataManager.get_currency()
	PlayerDataManager.add_currency(target - current)
	var c = get_tree().root.get_node_or_null("Console")
	if c:
		c.print_info("Валюта установлена: " + amount_str)

func _player_add_minutes(minutes_str: String):
	PlayerDataManager.add_play_time_seconds(int(minutes_str) * 60)
	var c = get_tree().root.get_node_or_null("Console")
	if c:
		c.print_info("Добавлено минут: " + minutes_str)

func _stats_add_hits(count_str: String):
	var count = _parse_int(count_str)
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
	PlayerDataManager.add_missed_notes(int(count_str))
	var c = get_tree().root.get_node_or_null("Console")
	if c:
		c.print_info("Добавлены промахи: " + count_str)

func _stats_add_perfect(count_str: String):
	PlayerDataManager.add_perfect_hits(int(count_str))
	var c = get_tree().root.get_node_or_null("Console")
	if c:
		c.print_info("Добавлены PERFECT: " + count_str)

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
