# scenes/victory_screen/victory_screen.gd
extends Control

signal song_select_requested
signal replay_requested

var score: int
var combo: int
var max_combo: int
var accuracy: float
var song_info: Dictionary = {}
var earned_currency: int = 0

var calculated_combo_multiplier: float = 1.0 
var calculated_total_notes: int = 0
var calculated_missed_notes: int = 0
var perfect_hits_this_level: int = 0
var hit_notes_this_level: int = 0

var results_manager = null

var music_manager = null

@onready var background: ColorRect = $Background
@onready var title_label: Label = $TitleLabel
@onready var song_label: Label = $SongLabel
@onready var stats_frame: Panel = $StatsFrame
@onready var score_label: Label = $StatsFrame/ScoreLabel
@onready var combo_label: Label = $StatsFrame/ComboLabel
@onready var max_combo_label: Label = $StatsFrame/MaxComboLabel
@onready var accuracy_label: Label = $StatsFrame/AccuracyLabel
@onready var grade_label: Label = $StatsFrame/GradeLabel
@onready var currency_label: Label = $StatsFrame/CurrencyLabel
@onready var hit_notes_label: Label = $StatsFrame/HitNotesLabel 
@onready var missed_notes_label: Label = $StatsFrame/MissedNotesLabel 
@onready var replay_button: Button = $ButtonsContainer/ReplayButton
@onready var song_select_button: Button = $ButtonsContainer/SongSelectButton

func _ready():
	var game_engine = get_parent()
	if game_engine and game_engine.has_method("get_music_manager"):
		music_manager = game_engine.get_music_manager()
	
	replay_button.pressed.connect(_on_replay_button_pressed)
	song_select_button.pressed.connect(_on_song_select_button_pressed)
	
	if currency_label:
		currency_label.mouse_filter = Control.MOUSE_FILTER_STOP
		currency_label.gui_input.connect(_on_currency_label_clicked)

func _calculate_grade() -> String:
	if accuracy == 100.0: 
		return "SS"
	elif accuracy >= 95.0: 
		return "S"
	elif accuracy >= 90.0:
		return "A"
	elif accuracy >= 80.0: 
		return "B"
	elif accuracy >= 70.0:
		return "C"
	elif accuracy >= 60.0:
		return "D"
	else: 
		return "F"
		
func _get_grade_color(grade: String) -> Color:
	match grade:
		"SS": return Color.GOLD
		"S": return Color.SILVER 
		"A": return Color.GREEN 
		"B": return Color.BLUE 
		"C": return Color.HOT_PINK # Color.PURPLE
		"D": return Color.RED
		"F": return Color.DARK_RED
		_: return Color.WHITE

func _on_replay_button_pressed():
	if music_manager and music_manager.has_method("stop_game_music"):
		music_manager.stop_game_music()
		print("VictoryScreen.gd: Игровая музыка остановлена перед реплеем.")
	
	if music_manager and music_manager.has_method("play_select_sound"):
		music_manager.play_select_sound()
	
	var game_engine = get_parent()
	if game_engine and game_engine.has_method("get_transitions"):
		var transitions = game_engine.get_transitions()
		if transitions and transitions.has_method("open_game_with_song"):
			var instrument_to_use = song_info.get("instrument", "standard")
			transitions.open_game_with_song(song_info, instrument_to_use)
	
	queue_free()


func _on_song_select_button_pressed():
	if music_manager and music_manager.has_method("stop_game_music"):
		music_manager.stop_game_music()
		print("VictoryScreen.gd: Игровая музыка остановлена перед переходом к выбору песни.")
	
	if music_manager and music_manager.has_method("play_select_sound"):
		music_manager.play_select_sound()
	
	var game_engine = get_parent()
	if game_engine and game_engine.has_method("get_transitions"):
		var transitions = game_engine.get_transitions()
		if transitions and transitions.has_method("open_song_select"):
			transitions.open_song_select()

	queue_free()

func _on_currency_label_clicked(event):
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		_show_currency_details()

func _show_currency_details():
	var currency_details_scene = load("res://scenes/victory_screen/victory_currency_details.tscn")
	var currency_details = currency_details_scene.instantiate()
	
	currency_details.details_closed.connect(_on_currency_details_closed)
	
	add_child(currency_details)
	
	currency_details.show_details(
		score, 
		max_combo, 
		accuracy, 
		calculated_total_notes, 
		calculated_missed_notes, 
		calculated_combo_multiplier, 
		earned_currency
	)

func _on_currency_details_closed():
	pass

func set_results_manager(results_mgr):
	print("VictoryScreen.gd: [ДИАГНОСТИКА] set_results_manager вызван с: ", results_mgr)
	results_manager = results_mgr
	print("VictoryScreen.gd: [ДИАГНОСТИКА] ResultsManager установлен в: ", results_mgr)

func set_achievement_system(ach_sys):
	print("VictoryScreen.gd: [ДИАГНОСТИКА] set_achievement_system вызван с: ", ach_sys)
	if results_manager and results_manager.has_method("set_achievement_system"):
		results_manager.set_achievement_system(ach_sys)
		print("VictoryScreen.gd: [ДИАГНОСТИКА] AchievementSystem передан в ResultsManager из VictoryScreen.")
	else:
		print("VictoryScreen.gd: [ДИАГНОСТИКА] ResultsManager не имеет метода set_achievement_system или не установлен.")

func set_victory_data(p_score: int, p_combo: int, p_max_combo: int, p_accuracy: float, p_song_info: Dictionary = {}, p_combo_multiplier: float = 1.0, p_total_notes: int = 0, p_missed_notes: int = 0, p_perfect_hits: int = 0, p_hit_notes: int = 0):
	score = p_score
	combo = p_combo
	max_combo = p_max_combo
	accuracy = p_accuracy
	song_info = p_song_info.duplicate() 
	
	var game_screen = get_parent()
	if game_screen and game_screen.score_manager:
		calculated_combo_multiplier = game_screen.score_manager.get_combo_multiplier()
	else:
		calculated_combo_multiplier = p_combo_multiplier 
	
	calculated_total_notes = p_total_notes
	calculated_missed_notes = p_missed_notes
	perfect_hits_this_level = p_perfect_hits
	hit_notes_this_level = p_hit_notes 
	
	earned_currency = _calculate_currency_new()

	call_deferred("_deferred_update_ui")

func _calculate_currency_new() -> int:
	var base_currency = float(score) / 100.0
	var combo_bonus = sqrt(float(max_combo)) * 2.0
	var accuracy_bonus = 0.0
	if accuracy >= 95.0 and accuracy < 100.0:
		accuracy_bonus = (accuracy - 90.0) * 1.5
	elif accuracy >= 100.0:
		accuracy_bonus = 50.0 
	var full_combo_bonus = 0.0
	if calculated_missed_notes == 0 and calculated_total_notes > 0:
		full_combo_bonus = 20.0
	var multiplier_bonus = (calculated_combo_multiplier - 1.0) * 5.0
	var total_currency = base_currency + combo_bonus + accuracy_bonus + full_combo_bonus + multiplier_bonus
	var final_currency = int(total_currency)
	return max(1, final_currency)

func _deferred_update_ui():
	if is_instance_valid(song_label) and song_info.get("title"):
		song_label.text = song_info["title"]
	
	if is_instance_valid(score_label):
		score_label.text = "Счёт: %d" % score  
		
	if is_instance_valid(combo_label):
		combo_label.text = "Комбо: %d" % combo  
	
	if is_instance_valid(max_combo_label):
		max_combo_label.text = "Макс. комбо: %d" % max_combo 
	
	if is_instance_valid(accuracy_label):
		accuracy_label.text = "Точность: %.1f%%" % accuracy  

	if is_instance_valid(grade_label):
		var grade = _calculate_grade()
		var grade_color = _get_grade_color(grade)
		grade_label.text = "Оценка: %s" % grade
		grade_label.modulate = grade_color
	
	if is_instance_valid(currency_label):
		currency_label.text = "Валюта за уровень: %d" % earned_currency 

	if is_instance_valid(hit_notes_label):
		hit_notes_label.text = "Попаданий: %d" % hit_notes_this_level 
	if is_instance_valid(missed_notes_label):
		missed_notes_label.text = "Промахов: %d" % calculated_missed_notes

	var game_engine = get_parent()
	if game_engine and game_engine.has_method("get_player_data_manager"):
		var player_data_manager = game_engine.get_player_data_manager()
		if player_data_manager:
			player_data_manager.add_hit_notes(hit_notes_this_level)
			player_data_manager.add_missed_notes(calculated_missed_notes)
			print("VictoryScreen.gd: Обновлены глобальные счётчики: Попаданий +%d, Промахов +%d" % [hit_notes_this_level, calculated_missed_notes])
		else:
			printerr("VictoryScreen.gd: Не удалось получить player_data_manager для обновления статистики.")
	else:
		printerr("VictoryScreen.gd: Не удалось получить game_engine или метод get_player_data_manager для обновления статистики.")

	if game_engine and game_engine.has_method("get_player_data_manager"):
		var player_data_manager = game_engine.get_player_data_manager()
		if player_data_manager:
			player_data_manager.add_currency(earned_currency)
			player_data_manager.add_perfect_hits(perfect_hits_this_level)

			var current_max_combo = player_data_manager.data.get("max_combo_ever", 0)
			if max_combo > current_max_combo:
				player_data_manager.data["max_combo_ever"] = max_combo
				player_data_manager._save()
				print("VictoryScreen.gd: Обновлен рекордный комбо: ", max_combo)
			else:
				print("VictoryScreen.gd: max_combo (", max_combo, ") не превышает текущий max_combo_ever (", current_max_combo, ")")

			var current_max_drum_combo = player_data_manager.data.get("max_drum_combo_ever", 0)
			var instrument_used_for_combo_check = song_info.get("instrument", "standard")
			print("VictoryScreen.gd: [ДИАГНОСТИКА] instrument для проверки max_combo: ", instrument_used_for_combo_check, ", max_combo: ", max_combo, ", current_max_drum_combo: ", current_max_drum_combo)

			if instrument_used_for_combo_check == "drums" and max_combo > current_max_drum_combo:
				player_data_manager.data["max_drum_combo_ever"] = max_combo
				player_data_manager._save()
				print("VictoryScreen.gd: Обновлен рекордный комбо на барабанах: ", max_combo)
			else:
				print("VictoryScreen.gd: Условие для обновления max_drum_combo_ever не выполнено.")

			var instrument_used_for_drums = song_info.get("instrument", "standard")
			if instrument_used_for_drums == "drums":
				var current_drum_hits = player_data_manager.data.get("total_drum_hits", 0)
				var new_drum_hits = current_drum_hits + hit_notes_this_level
				player_data_manager.data["total_drum_hits"] = new_drum_hits
				print("VictoryScreen.gd: Обновлены барабанные попадания: +%d, всего: %d" % [hit_notes_this_level, new_drum_hits])
				
				var current_drum_misses = player_data_manager.data.get("total_drum_misses", 0)
				var new_drum_misses = current_drum_misses + calculated_missed_notes
				player_data_manager.data["total_drum_misses"] = new_drum_misses
				print("VictoryScreen.gd: Обновлены барабанные промахи: +%d, всего: %d" % [calculated_missed_notes, new_drum_misses])
				
				player_data_manager._save()

			var should_save_result_later = (results_manager and song_info and song_info.get("path"))

			var grade = _calculate_grade()
			
			var achievement_system = null
			var achievement_manager = null
			
			if game_engine and game_engine.has_method("get_achievement_system"):
				achievement_system = game_engine.get_achievement_system()
			
			if game_engine and game_engine.has_method("get_achievement_manager"):
				achievement_manager = game_engine.get_achievement_manager()
			
			if achievement_manager and game_engine:
				achievement_manager.notification_mgr = game_engine
				print("VictoryScreen.gd: [ДИАГНОСТИКА] GameEngine передан в AchievementManager как notification_mgr.")

			var instrument_used = song_info.get("instrument", "standard")
			var is_drum_mode = (instrument_used == "drums")
			
			if is_drum_mode:
				print("🥁 Режим перкуссии - проверяем drum-ачивки...")
				player_data_manager.add_drum_level_completed()
				var total_drum_levels = player_data_manager.get_drum_levels_completed()
				print("🥁 Пройдено drum-уровней: ", total_drum_levels)
			
			if achievement_system:
				print("🎯 Вызываем ачивки за уровень через AchievementSystem...")
				achievement_system.on_level_completed(accuracy, is_drum_mode)
				
			elif achievement_manager:
				print("🎯 Вызываем ачивки за уровень через AchievementManager (fallback)...")
				achievement_manager.check_first_level_achievement()
				achievement_manager.check_perfect_accuracy_achievement(accuracy)
				player_data_manager.add_completed_level()
				var total_levels_completed = player_data_manager.get_levels_completed()
				achievement_manager.check_levels_completed_achievement(total_levels_completed)
				
				if is_drum_mode:
					print(" dru Проверяем drum-ачивки через AchievementManager...")
					var total_drum_levels = player_data_manager.get_drum_levels_completed()
					achievement_manager.check_drum_level_achievements(player_data_manager, accuracy, total_drum_levels)

			if should_save_result_later:
				var instrument_for_result = song_info.get("instrument", "standard")
				if instrument_for_result == "drums":
					instrument_for_result = "Перкуссия"
				var grade_for_result = _calculate_grade()
				var grade_color_for_result = _get_grade_color(grade_for_result)
				var result_datetime_for_result = Time.get_datetime_string_from_system(true, true)
				results_manager.save_result_for_song(
					song_info.get("path", ""), 
					instrument_for_result,          
					score,                    
					accuracy,                  
					grade_for_result,                   
					grade_color_for_result,              
					result_datetime_for_result           
				)
				print("VictoryScreen.gd: Результат отправлен в ResultsManager для сохранения (после ачивок).")
			else:
				print("VictoryScreen.gd: ResultsManager не установлен или путь к песне отсутствует.")
			
			if achievement_manager and achievement_manager.has_method("show_all_delayed_gameplay_achievements"):
				print("🎯 Показываем *новые* накопленные геймплейные ачивки...")
				achievement_manager.show_all_delayed_gameplay_achievements()
				
				achievement_manager.clear_new_gameplay_achievements()
			else:
				print("⚠️ AchievementManager не имеет метода show_all_delayed_gameplay_achievements или clear_new_gameplay_achievements.")
			
			print("💰 Игрок заработал валюту: %d" % earned_currency)
			print("🎯 Получена оценка: %s (%.1f%%)" % [grade, accuracy])
		else:
			printerr("VictoryScreen: Не удалось получить player_data_manager")
	else:
		printerr("VictoryScreen: Не удалось получить game_engine или метод get_player_data_manager")
