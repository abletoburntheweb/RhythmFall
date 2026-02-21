# scenes/main_menu/main_menu.gd
extends Control

var transitions = null

var is_game_open = false

var github_url = "https://github.com/abletoburntheweb/RhythmFall.git"

func _ready():
	MusicManager.play_menu_music()
	PlayerDataManager.ensure_daily_quests_for_today()
	if PlayerDataManager.has_signal("daily_quests_updated"):
		PlayerDataManager.connect("daily_quests_updated", Callable(self, "_render_daily_quests"))
	_render_daily_quests()

func set_transitions(transitions_instance):
	transitions = transitions_instance

func _on_github_pressed():
	OS.shell_open(github_url)

func _on_play_pressed():
	MusicManager.stop_music()
	if transitions:
		transitions.open_game()

func _on_song_select_pressed():
	MusicManager.play_select_sound()
	MusicManager.pause_menu_music()
	if transitions:
		transitions.open_song_select()

func _on_achievements_pressed():
	MusicManager.play_select_sound()
	if transitions:
		transitions.open_achievements()

func _on_shop_pressed():
	MusicManager.play_select_sound()
	MusicManager.pause_menu_music()
	if transitions:
		transitions.open_shop()

func _on_profile_pressed(): 
	MusicManager.play_select_sound()
	if transitions:
		transitions.open_profile()

func _on_settings_pressed():
	MusicManager.play_select_sound()
	if transitions:
		transitions.open_settings()

func _on_exit_pressed():
	MusicManager.stop_music()
	if transitions:
		transitions.exit_game()

func exit_to_main_menu():
	MusicManager.play_menu_music()
	if transitions:
		transitions.exit_to_main_menu()

func _render_daily_quests():
	var quests = PlayerDataManager.get_daily_quests()
	for i in range(3):
		var item_name = "QuestItem%d" % (i + 1)
		var item = find_child(item_name, true, false)
		if not item:
			continue
		if item is Control:
			item.clip_contents = true

		var title_label = item.find_child("QuestTitleLabel", true, false)
		var desc_label = item.find_child("QuestDescriptionLabel", true, false)
		var pb = item.find_child("QuestProgressBar", true, false)

		if i < quests.size():
			var q = quests[i]
			var title = str(q.get("title", "Задание"))
			var goal = int(q.get("goal", 1))
			var reward = int(q.get("reward_currency", 0))
			var progress = int(q.get("progress", 0))
			var completed = bool(q.get("completed", false))

			if title_label:
				title_label.text = title
				if completed:
					title_label.add_theme_color_override("font_color", Color(0.95, 0.70, 0.30, 1.0))
				else:
					title_label.add_theme_color_override("font_color", Color.GRAY)

			if desc_label:
				var desc_text = "Награда: %d • Цель: %d" % [reward, goal]
				if completed:
					desc_text += " (завершено)"
				else:
					desc_text += " (%d/%d)" % [progress, goal]
				desc_label.text = desc_text
				if completed:
					desc_label.add_theme_color_override("font_color", Color.WHITE)
				else:
					desc_label.add_theme_color_override("font_color", Color.LIGHT_GRAY)

			if pb:
				pb.max_value = goal
				pb.value = min(progress, goal)

			item.show() 
		else:
			item.hide()
