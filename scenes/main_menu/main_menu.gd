# scenes/main_menu/main_menu.gd
extends Control

var transitions = null

var is_game_open = false

var github_url = "https://github.com/abletoburntheweb/RhythmFall.git"

var button_configs = {
	"PlayButton": _on_play_pressed,
	"SongSelectButton": _on_song_select_pressed,
	"AchievementsButton": _on_achievements_pressed,
	"ShopButton": _on_shop_pressed,
	"ProfileButton": _on_profile_pressed,
	"SettingsButton": _on_settings_pressed,
	"ExitButton": _on_exit_pressed,
}

func _ready():
	MusicManager.play_menu_music()
	PlayerDataManager.ensure_daily_quests_for_today()
	if PlayerDataManager.has_signal("daily_quests_updated"):
		PlayerDataManager.connect("daily_quests_updated", Callable(self, "_render_daily_quests"))
	_render_daily_quests()

	var all_buttons_connected = true
	for button_name in button_configs:
		var button = get_node_or_null(button_name)
		if button:
			button.pressed.connect(button_configs[button_name])
		else:
			push_error("MainMenu.gd: ОШИБКА! Узел $%s не найден!" % button_name)
			all_buttons_connected = false

	var github_button = get_node_or_null("GitHubButton")
	if github_button:
		github_button.pressed.connect(_on_github_pressed)
	else:
		push_error("MainMenu.gd: ОШИБКА! Узел $GitHubButton не найден!")

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
	var list_node = find_child("DailyQuestsList", true, false)
	if not list_node:
		return
	for child in list_node.get_children():
		list_node.remove_child(child)
		child.queue_free()
	var template = list_node.get_node_or_null("QuestItem")
	if template == null:
		template = PanelContainer.new()
		template.name = "QuestItem"
		var content_vbox = VBoxContainer.new()
		content_vbox.name = "ContentVBox"
		template.add_child(content_vbox)
		var title_label = Label.new()
		title_label.name = "QuestTitleLabel"
		title_label.text = "Заголовок задания"
		content_vbox.add_child(title_label)
		var desc_label = Label.new()
		desc_label.name = "QuestDescriptionLabel"
		desc_label.text = "Описание задания"
		content_vbox.add_child(desc_label)
		var pb = ProgressBar.new()
		pb.name = "QuestProgressBar"
		pb.min_value = 0
		pb.max_value = 100
		content_vbox.add_child(pb)
	var quests = PlayerDataManager.get_daily_quests()
	var count = min(3, quests.size())
	for i in range(count):
		var q = quests[i]
		var item = template.duplicate(true)
		item.name = "QuestItem%d" % (i + 1)
		var title_label = item.find_child("QuestTitleLabel", true, false)
		var desc_label = item.find_child("QuestDescriptionLabel", true, false)
		var pb = item.find_child("QuestProgressBar", true, false)
		var title = str(q.get("title", "Задание"))
		var goal = int(q.get("goal", 1))
		var reward = int(q.get("reward_currency", 0))
		var progress = int(q.get("progress", 0))
		var completed = bool(q.get("completed", false))
		if title_label:
			title_label.text = title
		if desc_label:
			var desc_text = "Награда: %d • Цель: %d • Прогресс: %d/%d" % [reward, goal, progress, goal]
			if completed:
				desc_text = desc_text + " (завершено)"
			desc_label.text = desc_text
		if pb:
			var pct = 100 if completed else int(round(100.0 * float(progress) / float(max(1, goal))))
			pb.min_value = 0
			pb.max_value = 100
			pb.value = pct
		list_node.add_child(item)
