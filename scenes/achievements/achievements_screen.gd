# scenes/achievements/achievements_screen.gd
extends BaseScreen

const ACHIEVEMENT_CARD_SCENE := preload("res://scenes/achievements/achievement_card.tscn")
const ACHIEVEMENTS_JSON_PATH := "res://data/achievements_data.json"
const DEFAULT_ACHIEVEMENT_ICON_PATH := "res://assets/achievements/default.png"

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
		var music_mgr = null
		var ach_mgr = null

		if game_engine.has_method("get_transitions"):
			trans = game_engine.get_transitions()
		if game_engine.has_method("get_music_manager"):
			music_mgr = game_engine.get_music_manager()
		if game_engine.has_method("get_achievement_manager"):
			ach_mgr = game_engine.get_achievement_manager()

		setup_managers(trans, music_mgr)

		achievement_manager = ach_mgr

		if not trans:
			printerr("AchievementsScreen: Не удалось получить Transitions через GameEngine!")
		if not music_mgr:
			printerr("AchievementsScreen: Не удалось получить MusicManager через GameEngine!")
		if not ach_mgr:
			printerr("AchievementsScreen: Не удалось получить AchievementManager через GameEngine!")
	else:
		printerr("AchievementsScreen: GameEngine (get_parent()) не найден!")

	search_bar.text_changed.connect(_on_search_text_changed)
	filter_box.item_selected.connect(_on_filter_selected)

	_load_achievements_data()
	_filter_achievements_internal(search_bar.text)

	if back_button:
		back_button.pressed.connect(_on_back_pressed)
	else:
		printerr("AchievementsScreen: Кнопка back_button не найдена!")


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
			else:
				printerr("AchievementsScreen: Поле 'achievements' в JSON не является массивом.")
				achievements = []
		else:
			printerr("AchievementsScreen: Ошибка парсинга JSON или отсутствие ключа 'achievements'.")
			achievements = []
	else:
		printerr("AchievementsScreen: Не удалось открыть файл ", ACHIEVEMENTS_JSON_PATH)
		achievements = []


func _sort_by_title(a: Dictionary, b: Dictionary) -> bool:
	var title_a = str(a.get("title", "")).to_lower()
	var title_b = str(b.get("title", "")).to_lower()
	if title_a == title_b:
		return a.id < b.id 
	return title_a < title_b


func _update_display(achievements_to_display: Array[Dictionary]):
	for child in achievements_list.get_children():
		achievements_list.remove_child(child)
		child.queue_free() 

	for ach in achievements_to_display:
		if not (ach is Dictionary):
			printerr("AchievementsScreen.gd: Найден элемент не типа Dictionary в списке для отображения: ", ach)
			continue 
		
		if not ach.has("title"):
			printerr("AchievementsScreen.gd: У элемента ачивки отсутствует ключ 'title': ", ach)
			continue 
		
		if ach.title == null:
			printerr("AchievementsScreen.gd: Ключ 'title' для ачивки равен null: ", ach)
			continue 
		
		var card = ACHIEVEMENT_CARD_SCENE.instantiate()
		card.title = ach.title 
		card.description = ach.get("description", "") if ach.has("description") else "Нет описания"
		card.progress_text = _get_progress_text(ach)
		card.is_unlocked = ach.get("unlocked", false) if ach.has("unlocked") else false

		var icon_texture: ImageTexture = null
		var used_default = false
		
		var image_path = ach.get("image", "") if ach.has("image") else ""
		if image_path and image_path != "":
			if FileAccess.file_exists(image_path):
				var loaded_resource = ResourceLoader.load(image_path, "ImageTexture", ResourceLoader.CACHE_MODE_IGNORE)
				if loaded_resource and loaded_resource is ImageTexture:
					icon_texture = loaded_resource
				else:
					var image = Image.new()
					var err = image.load(image_path)
					if err == OK:
						icon_texture = ImageTexture.create_from_image(image)
					else:
						printerr("AchievementsScreen: Ошибка загрузки изображения через Image: ", image_path, ", ошибка: ", err)
						used_default = true
			else:
				used_default = true
		else:
			used_default = true

		if not icon_texture or used_default:
			var fallback_path = ""
			var category = ach.get("category", "")
			
			match category:
				"mastery": fallback_path = "res://assets/achievements/mastery.png"
				"drums": fallback_path = "res://assets/achievements/drums.png"
				"genres":  fallback_path = "res://assets/achievements/genres.png"  
				"system": fallback_path = "res://assets/achievements/system.png"
				"shop": fallback_path = "res://assets/achievements/shop.png"
				"economy": fallback_path = "res://assets/achievements/economy.png"
				"daily": fallback_path = "res://assets/achievements/daily.png"
				"playtime": fallback_path = "res://assets/achievements/playtime.png"
				"events": fallback_path = "res://assets/achievements/events.png"
				"level": fallback_path = "res://assets/achievements/level.png"  
				_: fallback_path = "res://assets/achievements/default.png"
			
			if FileAccess.file_exists(fallback_path):
				var loaded_default_resource = ResourceLoader.load(fallback_path, "ImageTexture", ResourceLoader.CACHE_MODE_IGNORE)
				if loaded_default_resource and loaded_default_resource is ImageTexture:
					icon_texture = loaded_default_resource
				else:
					var image = Image.new()
					var err = image.load(fallback_path)
					if err == OK:
						icon_texture = ImageTexture.create_from_image(image)
					else:
						printerr("AchievementsScreen: Ошибка загрузки fallback иконки через Image: ", fallback_path, ", ошибка: ", err)
						var dummy_image = Image.create(1, 1, false, Image.FORMAT_RGBA8)
						dummy_image.set_pixel(0, 0, Color.WHITE)
						var dummy_texture = ImageTexture.create_from_image(dummy_image)
						icon_texture = dummy_texture
			else:
				printerr("AchievementsScreen: Fallback иконка не найдена (FileAccess): ", fallback_path)
				var dummy_image = Image.create(1, 1, false, Image.FORMAT_RGBA8)
				dummy_image.set_pixel(0, 0, Color.WHITE)
				var dummy_texture = ImageTexture.create_from_image(dummy_image)
				icon_texture = dummy_texture

		card.icon_texture = icon_texture 

		var unlock_date_val = ach.get("unlock_date", null)
		if unlock_date_val == null:
			card.unlock_date_text = ""
		else:
			card.unlock_date_text = str(unlock_date_val) 

		achievements_list.add_child(card)

	_update_counter()


func _get_progress_text(achievement: Dictionary) -> String:
	var current = achievement.get("current", 0)
	var total = achievement.get("total", 1)
	var unlocked = achievement.get("unlocked", false)
	var category = achievement.get("category", "")

	if category == "playtime" and achievement_manager:
		var formatted_progress = achievement_manager.get_formatted_achievement_progress(achievement.get("id", -1))
		if formatted_progress:
			var display_current = formatted_progress.current
			var raw_total = achievement.get("total", 1.0) 

			var display_total: String
			if raw_total == floor(raw_total):
				display_total = str(int(raw_total)) 
			else:
				display_total = "%0.2f" % [raw_total] 

			if unlocked:
				return "%s / %s" % [display_total, display_total]
			else:
				return "%s / %s" % [display_current, display_total]

	if category == "level":
		if unlocked:
			return "%d / %d" % [int(total), int(total)]
		else:
			return "%d / %d" % [int(current), int(total)]


	var display_current = current
	if unlocked and typeof(current) != TYPE_FLOAT:
		display_current = min(current, total)

	if typeof(current) == TYPE_BOOL:
		return "%d / %d" % [int(current), 1]
	else:
		if typeof(display_current) == TYPE_FLOAT:
			return "%d / %d" % [int(display_current), int(total)]
		else:
			return "%d / %d" % [int(display_current), int(total)]



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
				var category_map = {
					"Мастерство": "mastery",
					"Перкуссия": "drums",
					"Жанры": "genres",
					"Системные": "system", 
					"Магазин": "shop",
					"Экономика": "economy",
					"Ежедневные": "daily",
					"Время в игре": "playtime",
					"Событийные": "events",
					"Уровень": "level" 
				}
				if category_map.has(current_filter):
					matches_category = ach.get("category", "").to_lower() == category_map[current_filter].to_lower()
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
		var category_map = {
			"Мастерство": "mastery",
			"Перкуссия": "drums",
			"Жанры": "genres",
			"Системные": "system", 
			"Магазин": "shop",
			"Экономика": "economy",
			"Ежедневные": "daily",
			"Время в игре": "playtime",
			"Событийные": "events",
			"Уровень": "level" 
		}
		if category_map.has(filter_type):
			var target_category = category_map[filter_type].to_lower()
			return achievements_to_filter.filter(func(ach): 
				if ach is Dictionary and ach.has("category"):
					return ach.get("category", "").to_lower() == target_category
				else:
					return false
			)
		else:
			return achievements_to_filter

func _unhandled_input(event):
	if event.is_action_pressed("ui_cancel"): 
		_on_back_pressed()
		get_viewport().set_input_as_handled()

func _execute_close_transition():
	if is_instance_valid(music_manager): 
		music_manager.play_cancel_sound()

	if is_instance_valid(transitions):
		transitions.close_achievements() 
	else:
		printerr("AchievementsScreen: transitions (из BaseScreen) не установлен, невозможно закрыть экран достижений.")

	if is_instance_valid(self):
		queue_free()
