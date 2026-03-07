# scenes/achievements/achievements_screen.gd
extends BaseScreen

const ACHIEVEMENT_CARD_SCENE := preload("res://scenes/achievements/achievement_card.tscn")
const ACHIEVEMENTS_JSON_PATH := "res://data/achievements_data.json"
var AchievementsUtils = preload("res://logic/utils/achievements_utils.gd").new()

@onready var back_button: Button = $MainVBox/BackButton
@onready var counter_label: Label = $MainVBox/CounterLabel
@onready var search_bar: LineEdit = $MainVBox/SearchAndFilterHBox/SearchBar
@onready var filter_box: OptionButton = $MainVBox/SearchAndFilterHBox/FilterBox
@onready var achievements_list: VBoxContainer = $MainVBox/ContentContainer/AchievementsScroll/BottomMargin/AchievementsList

var achievements: Array[Dictionary] = []
var filtered_achievements: Array[Dictionary] = []
var current_filter: String = "Все"
var achievement_manager: AchievementManager = null

func _ready():
	var game_engine = get_parent()
	if game_engine:
		var trans = null
		var ach_mgr = null

		if game_engine.has_method("get_transitions"):
			trans = game_engine.get_transitions()
		if game_engine.has_method("get_achievement_manager"):
			ach_mgr = game_engine.get_achievement_manager()

		setup_managers(trans)  

		achievement_manager = ach_mgr

		if not trans:
			printerr("AchievementsScreen: Не удалось получить Transitions через GameEngine!")
		if not ach_mgr:
			printerr("AchievementsScreen: Не удалось получить AchievementManager через GameEngine!")
	else:
		printerr("AchievementsScreen: GameEngine (get_parent()) не найден!")
	

	_load_achievements_data()
	_filter_achievements_internal(search_bar.text)
	


func _load_achievements_data():
	var ach_list = _get_achievements_data()
	achievements = []
	if ach_list != null:
		for item in ach_list:
			if item is Dictionary:
				achievements.append(item)
			else:
				printerr("AchievementsScreen: Найден элемент не типа Dictionary в списке достижений: ", item)
	_update_counter()


func _sort_by_title(a: Dictionary, b: Dictionary) -> bool:
	var title_a = str(a.get("title", "")).to_lower()
	var title_b = str(b.get("title", "")).to_lower()
	if title_a == title_b:
		return a.id < b.id 
	return title_a < title_b


func _update_display(achievements_to_display: Array[Dictionary]):
	achievements_list.visible = false
	_clear_achievements_list()
	_render_cards_chunked(achievements_to_display)
	achievements_list.visible = true


 



func _update_counter():
	var unlocked_count = 0
	for a in achievements:
		if a.get("unlocked", false):
			unlocked_count += 1
	counter_label.text = "Открыто: %d / %d" % [unlocked_count, achievements.size()]



func _on_search_text_changed(new_text: String):
	_filter_achievements_internal(new_text)


func _on_filter_selected(index: int):
	current_filter = filter_box.get_item_text(index)
	_filter_achievements_internal(search_bar.text)


func _filter_achievements_internal(query: String):
	var base_list = _apply_status_filter(achievements, current_filter)
	var query_lower = query.strip_edges().to_lower()

	var results: Array[Dictionary]
	if query_lower != "":
		results = []
		for ach in base_list:
			if not (ach is Dictionary) or not ach.has("title") or not ach.has("description"):
				continue
			var matches_search = ach.title.to_lower().contains(query_lower) or ach.description.to_lower().contains(query_lower)
			var matches_category = true
			if current_filter != "Все" and current_filter != "Открытые" and current_filter != "Закрытые":
				var internal = AchievementsUtils.category_ru_to_internal(current_filter)
				if internal != "":
					matches_category = ach.get("category", "").to_lower() == internal.to_lower()
			if matches_search and matches_category:
				results.append(ach)
	else:
		results = base_list

	results.sort_custom(Callable(self, "_sort_by_title"))

	_update_display(results)

func _apply_status_filter(achievements_to_filter: Array[Dictionary], filter_type: String) -> Array[Dictionary]:
	if filter_type == "Все":
		return achievements_to_filter
	elif filter_type == "Открытые":
		return achievements_to_filter.filter(func(ach): 
			if ach is Dictionary and ach.has("unlocked"):
				return ach.get("unlocked", false)
			else:
				return false 
		)
	elif filter_type == "Закрытые":
		return achievements_to_filter.filter(func(ach): 
			if ach is Dictionary and ach.has("unlocked"):
				return not ach.get("unlocked", false)
			else:
				return true  
		)
	else:
		var internal2 = AchievementsUtils.category_ru_to_internal(filter_type)
		if internal2 != "":
			var target_category = internal2.to_lower()
			return achievements_to_filter.filter(func(ach): 
				if ach is Dictionary and ach.has("category"):
					return ach.get("category", "").to_lower() == target_category
				else:
					return false
			)
		else:
			return achievements_to_filter
			
func _execute_close_transition():
	if is_instance_valid(transitions):
		transitions.close_achievements() 
	else:
		printerr("AchievementsScreen: transitions (из BaseScreen) не установлен, невозможно закрыть экран достижений.")

	if is_instance_valid(self):
		queue_free()
	
var _achievements_data_cache = null
var _texture_cache := {}
func _get_achievements_data():
	if _achievements_data_cache != null:
		return _achievements_data_cache
	var user_path = "user://achievements_data.json"
	var open_path = user_path if FileAccess.file_exists(user_path) else ACHIEVEMENTS_JSON_PATH
	var file = FileAccess.open(open_path, FileAccess.READ)
	if not file:
		return null
	var text = file.get_as_text()
	file.close()
	var parsed = JSON.parse_string(text)
	if not parsed or not parsed.has("achievements") or not (parsed.achievements is Array):
		return null
	_achievements_data_cache = parsed.achievements
	return _achievements_data_cache

func _clear_achievements_list():
	for child in achievements_list.get_children():
		achievements_list.remove_child(child)
		child.queue_free()

func _render_cards_chunked(achievements_to_display: Array[Dictionary]):
	var batch_size = 20
	var i = 0
	while i < achievements_to_display.size():
		var end = min(i + batch_size, achievements_to_display.size())
		for j in range(i, end):
			var ach = achievements_to_display[j]
			if not (ach is Dictionary):
				continue
			if not ach.has("title") or ach.title == null:
				continue
			var card = ACHIEVEMENT_CARD_SCENE.instantiate()
			achievements_list.add_child(card)
			card.apply_achievement(ach, achievement_manager)
		await get_tree().process_frame
		i = end
