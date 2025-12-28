# scenes/profile/profile_screen.gd
class_name ProfileScreen
extends BaseScreen

@onready var back_button: Button = $MainContent/MainVBox/BackButton
@onready var levels_completed_label: Label = $MainContent/MainVBox/StatsVBox/LevelsCompletedLabel
@onready var drum_levels_completed_label: Label = $MainContent/MainVBox/StatsVBox/DrumLevelsContainer/DrumLevelsCompletedLabel
@onready var total_earned_currency_label: Label = $MainContent/MainVBox/StatsVBox/TotalEarnedCurrencyLabel
@onready var spent_currency_label: Label = $MainContent/MainVBox/StatsVBox/SpentCurrencyLabel
@onready var total_notes_hit_label: Label = $MainContent/MainVBox/StatsVBox/TotalNotesHitLabel 
@onready var total_notes_missed_label: Label = $MainContent/MainVBox/StatsVBox/TotalNotesMissedLabel 

func _ready():
	var game_engine = get_parent()
	if game_engine and \
	   game_engine.has_method("get_music_manager") and \
	   game_engine.has_method("get_transitions") and \
	   game_engine.has_method("get_player_data_manager"):
		
		var music_mgr = game_engine.get_music_manager()
		var trans = game_engine.get_transitions()
		var player_data_mgr = game_engine.get_player_data_manager()

		setup_managers(trans, music_mgr, player_data_mgr)
		print("ProfileScreen.gd: setup_managers вызван из _ready().")
	else:
		printerr("ProfileScreen.gd: Не удалось получить один из менеджеров (music_manager, transitions, player_data_manager) через GameEngine.")

	refresh_stats()

	if back_button:
		back_button.pressed.connect(_on_back_pressed)
	else:
		printerr("ProfileScreen: Кнопка back_button не найдена!")

func refresh_stats():
	if player_data_manager == null:
		printerr("ProfileScreen: PlayerDataManager не установлен через setup_managers!")
		return

	levels_completed_label.text = "Завершено уровней: %d" % player_data_manager.get_levels_completed()
	drum_levels_completed_label.text = "Перкуссия: %d" % player_data_manager.get_drum_levels_completed()
	total_earned_currency_label.text = "Заработано всего: %d" % player_data_manager.data.get("total_earned_currency", 0)
	spent_currency_label.text = "Потрачено: %d" % player_data_manager.data.get("spent_currency", 0)

	total_notes_hit_label.text = "Попаданий: %d" % player_data_manager.get_total_notes_hit() 
	total_notes_missed_label.text = "Промахов: %d" % player_data_manager.get_total_notes_missed() 

func _execute_close_transition():
	if music_manager:
		music_manager.play_cancel_sound()

	if transitions:
		transitions.close_profile()
		
	if is_instance_valid(self):
		queue_free()
