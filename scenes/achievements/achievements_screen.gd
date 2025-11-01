extends Control

const ACHIEVEMENT_CARD_SCENE := preload("res://scenes/achievements/achievement_card.tscn")
const ACHIEVEMENTS_JSON_PATH := "res://data/achievements_data.json"
const DEFAULT_ACHIEVEMENT_ICON_PATH := "res://assets/achievements/default.png"

@export var parent_node: Node  

@onready var back_button: Button = $MainVBox/BackButton
@onready var counter_label: Label = $MainVBox/CounterLabel
@onready var search_bar: LineEdit = $MainVBox/SearchAndFilterHBox/SearchBar
@onready var filter_box: OptionButton = $MainVBox/SearchAndFilterHBox/FilterBox
@onready var achievements_list: VBoxContainer = $MainVBox/ContentContainer/AchievementsScroll/BottomMargin/AchievementsList

var achievements: Array[Dictionary] = []
var filtered_achievements: Array[Dictionary] = []
var current_filter: String = "Все"

var transitions_manager = null

func _ready():
	if parent_node and parent_node.has_method("get_transitions"):
		transitions_manager = parent_node.get_transitions()
		if not transitions_manager:
			printerr("AchievementsScreen: get_transitions() вернул null!")
	else:
		printerr("AchievementsScreen: parent_node не задан или не содержит метода get_transitions!")

	search_bar.text_changed.connect(_on_search_text_changed)
	filter_box.item_selected.connect(_on_filter_selected)

	_init_filter_box()
	_load_achievements_data()
	_filter_achievements_internal(search_bar.text)

	if transitions_manager and transitions_manager.has_method("close_achievements"):
		back_button.pressed.connect(transitions_manager.close_achievements)
	else:
		printerr("AchievementsScreen: transitions_manager не задан или не содержит метода close_achievements!")


func _init_filter_box():
	filter_box.clear()
	filter_box.add_item("Все")
	filter_box.add_item("Открытые")
	filter_box.add_item("Закрытые")
	filter_box.select(0)


func _load_achievements_data():
	var file = FileAccess.open(ACHIEVEMENTS_JSON_PATH, FileAccess.READ)
	if file:
		var json_text = file.get_as_text()
		file.close()

		var json_parse_result = JSON.parse_string(json_text)
		if json_parse_result and json_parse_result.has("achievements"):
			if json_parse_result.achievements is Array:
				var loaded_achievements: Array[Dictionary] = []
				for item in json_parse_result.achievements:
					if item is Dictionary:
						loaded_achievements.append(item)
					else:
						printerr("AchievementsScreen: Найден элемент не типа Dictionary в списке достижений: ", item)

				achievements = loaded_achievements
				achievements.sort_custom(Callable(self, "_sort_by_id"))
			else:
				printerr("AchievementsScreen: Поле 'achievements' в JSON не является массивом.")
				achievements = []
		else:
			printerr("AchievementsScreen: Ошибка парсинга JSON или отсутствие ключа 'achievements'.")
			achievements = []
	else:
		printerr("AchievementsScreen: Не удалось открыть файл ", ACHIEVEMENTS_JSON_PATH)
		achievements = []


func _sort_by_id(a: Dictionary, b: Dictionary) -> bool:
	return a.id < b.id


func _update_display(achievements_to_display: Array[Dictionary]):
	for child in achievements_list.get_children():
		achievements_list.remove_child(child)
		child.queue_free() 

	for ach in achievements_to_display:
		var card = ACHIEVEMENT_CARD_SCENE.instantiate()
		card.title = ach.title
		card.description = ach.description
		card.progress_text = _get_progress_text(ach)
		card.is_unlocked = ach.unlocked
		card.icon_path = ach.image if ach.image and ResourceLoader.exists(ach.image) else DEFAULT_ACHIEVEMENT_ICON_PATH
		card.unlock_date_text = ach.unlock_date if ach.unlock_date else ""

		achievements_list.add_child(card)

	_update_counter()


func _get_progress_text(achievement: Dictionary) -> String:
	var current = achievement.get("current", 0)
	var total = achievement.get("total", 1)
	var unlocked = achievement.get("unlocked", false)

	var display_current = current
	if unlocked:
		display_current = min(current, total)

	if typeof(current) == TYPE_BOOL:
		return "%d / %d" % [int(current), 1]
	else:
		return "%d / %d" % [display_current, total]


func _update_counter():
	var unlocked_count = 0
	for a in achievements:
		if a.get("unlocked", false):
			unlocked_count += 1
	counter_label.text = "Открыто: %d / %d" % [unlocked_count, achievements.size()]



func _on_search_text_changed(new_text: String):
	_filter_achievements_internal(new_text)


func _on_filter_selected(index: int):
	match index:
		0: current_filter = "Все"
		1: current_filter = "Открытые"
		2: current_filter = "Закрытые"
	_filter_achievements_internal(search_bar.text)


func _filter_achievements_internal(query: String):
	var base_list = _apply_status_filter(achievements, current_filter)
	var query_lower = query.strip_edges().to_lower()

	var results: Array[Dictionary]
	if query_lower != "":
		results = []
		for ach in base_list:
			if ach.title.to_lower().contains(query_lower) or ach.description.to_lower().contains(query_lower):
				results.append(ach)
	else:
		results = base_list
	_update_display(results)


func _apply_status_filter(achievements_to_filter: Array[Dictionary], filter_type: String) -> Array[Dictionary]:
	if filter_type == "Все":
		return achievements_to_filter
	elif filter_type == "Открытые":
		return achievements_to_filter.filter(func(ach): return ach.get("unlocked", false))
	elif filter_type == "Закрытые":
		return achievements_to_filter.filter(func(ach): return not ach.get("unlocked", false))
	else:
		return achievements_to_filter


func _unhandled_input(event):
	if event.is_action_pressed("ui_cancel"): 
		if transitions_manager and transitions_manager.has_method("close_achievements"):
			transitions_manager.close_achievements()
			print("AchievementsScreen: Закрытие по Esc через transitions_manager.")
		else:
			printerr("AchievementsScreen: transitions_manager не задан или не содержит метода close_achievements! Невозможно закрыть экран по Esc.")
		get_viewport().set_input_as_handled()
