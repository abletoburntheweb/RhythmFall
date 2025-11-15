# scenes/achievements/achievements_screen.gd
extends BaseScreen

const ACHIEVEMENT_CARD_SCENE := preload("res://scenes/achievements/achievement_card.tscn")
const ACHIEVEMENTS_JSON_PATH := "res://data/achievements_data.json"
const DEFAULT_ACHIEVEMENT_ICON_PATH := "res://assets/achievements/default2.png"

@onready var back_button: Button = $MainVBox/BackButton
@onready var counter_label: Label = $MainVBox/CounterLabel
@onready var search_bar: LineEdit = $MainVBox/SearchAndFilterHBox/SearchBar
@onready var filter_box: OptionButton = $MainVBox/SearchAndFilterHBox/FilterBox
@onready var achievements_list: VBoxContainer = $MainVBox/ContentContainer/AchievementsScroll/BottomMargin/AchievementsList

var achievements: Array[Dictionary] = []
var filtered_achievements: Array[Dictionary] = []
var current_filter: String = "Все"

func _ready():
	var game_engine = get_parent()
	if game_engine:
		var trans = null
		var music_mgr = null
		if game_engine.has_method("get_transitions"):
			trans = game_engine.get_transitions()
		if game_engine.has_method("get_music_manager"):
			music_mgr = game_engine.get_music_manager()

		setup_managers(trans, music_mgr, null)
		
		if not trans:
			printerr("AchievementsScreen: Не удалось получить Transitions через GameEngine!")
		if not music_mgr:
			printerr("AchievementsScreen: Не удалось получить MusicManager через GameEngine!")
	else:
		printerr("AchievementsScreen: GameEngine (get_parent()) не найден!")

	search_bar.text_changed.connect(_on_search_text_changed)
	filter_box.item_selected.connect(_on_filter_selected)

	_init_filter_box()
	_load_achievements_data()
	_filter_achievements_internal(search_bar.text)

	if back_button:
		back_button.pressed.connect(_on_back_pressed)
	else:
		printerr("AchievementsScreen: Кнопка back_button не найдена!")


func _init_filter_box():
	filter_box.clear()
	filter_box.add_item("Все")
	filter_box.add_item("Открытые")
	filter_box.add_item("Закрытые")
	filter_box.add_item("Геймплей")
	filter_box.add_item("Системные")
	filter_box.add_item("Магазин")
	filter_box.add_item("Экономика")
	filter_box.add_item("Ежедневные")
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
			var default_path = "res://assets/achievements/default2.png"
			if FileAccess.file_exists(default_path):
				var loaded_default_resource = ResourceLoader.load(default_path, "ImageTexture", ResourceLoader.CACHE_MODE_IGNORE)
				if loaded_default_resource and loaded_default_resource is ImageTexture:
					icon_texture = loaded_default_resource
				else:
					var image = Image.new()
					var err = image.load(default_path)
					if err == OK:
						icon_texture = ImageTexture.create_from_image(image)
					else:
						printerr("AchievementsScreen: Ошибка загрузки дефолтной иконки через Image: ", default_path, ", ошибка: ", err)
						var dummy_image = Image.create(1, 1, false, Image.FORMAT_RGBA8)
						dummy_image.set_pixel(0, 0, Color.WHITE)
						var dummy_texture = ImageTexture.create_from_image(dummy_image)
						icon_texture = dummy_texture
			else:
				printerr("AchievementsScreen: Дефолтная иконка не найдена (FileAccess): ", default_path)
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
		3: current_filter = "Геймплей"
		4: current_filter = "Системные"
		5: current_filter = "Магазин"
		6: current_filter = "Экономика"
		7: current_filter = "Ежедневные"
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
					"Геймплей": "gameplay",
					"Системные": "system", 
					"Магазин": "shop",
					"Экономика": "economy",
					"Ежедневные": "daily"
				}
				if category_map.has(current_filter):
					matches_category = ach.get("category", "").to_lower() == category_map[current_filter].to_lower()
			if matches_search and matches_category:
				results.append(ach)
	else:
		results = base_list
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
			"Геймплей": "gameplay",
			"Системные": "system", 
			"Магазин": "shop",
			"Экономика": "economy",
			"Ежедневные": "daily"
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
	if music_manager:
		music_manager.play_cancel_sound()

	if transitions:
		transitions.close_achievements() 
	else:
		printerr("AchievementsScreen: transitions (из BaseScreen) не установлен, невозможно закрыть экран достижений.")

	if is_instance_valid(self):
		queue_free()
