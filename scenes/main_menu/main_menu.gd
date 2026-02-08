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
	var quests = PlayerDataManager.get_daily_quests()
	for i in range(min(3, quests.size())):
		var q = quests[i]
		var label = Label.new()
		var title = str(q.get("title", "Задание"))
		var progress = int(q.get("progress", 0))
		var goal = int(q.get("goal", 1))
		var completed = bool(q.get("completed", false))
		var status = "Готово" if completed else "%d/%d" % [progress, goal]
		label.text = "%s — %s" % [title, status]
		list_node.add_child(label)
