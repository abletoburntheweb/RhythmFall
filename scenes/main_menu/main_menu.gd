# scenes/main_menu/main_menu.gd
extends Control

var transitions = null

var is_game_open = false

var github_url = "https://github.com/abletoburntheweb/RhythmFall.git"
const SERVER_SETUP_NOTICE_URL := "https://github.com/abletoburntheweb/RhythmFallServer"
@onready var _exit_dialog: ConfirmationDialog = $ExitConfirmDialog
@onready var _server_setup_notice_dialog: AcceptDialog = $ServerSetupNoticeDialog
@onready var _shop_button: Button = $MenuPanel/MenuMargin/ButtonContainer/ShopButton
@onready var _shop_badge: PanelContainer = $MenuPanel/MenuMargin/ButtonContainer/ShopButton/NewRewardsBadge
@onready var _shop_badge_label: Label = $MenuPanel/MenuMargin/ButtonContainer/ShopButton/NewRewardsBadge/CountLabel

func _ready():
	MusicManager.play_menu_music()
	PlayerDataManager.ensure_daily_quests_for_today()
	if PlayerDataManager.has_signal("daily_quests_updated"):
		PlayerDataManager.connect("daily_quests_updated", Callable(self, "_render_daily_quests"))
	if PlayerDataManager.has_signal("shop_new_rewards_changed"):
		PlayerDataManager.shop_new_rewards_changed.connect(_update_shop_badge)
	if PlayerDataManager.has_signal("level_changed"):
		PlayerDataManager.level_changed.connect(func(_l, _x, _n): _update_shop_badge())
	_update_shop_badge()
	_render_daily_quests()
	_setup_server_setup_notice_dialog()
	call_deferred("_apply_menu_ui_interactions")
	call_deferred("_maybe_show_server_setup_notice")

func _setup_server_setup_notice_dialog() -> void:
	if not is_instance_valid(_server_setup_notice_dialog):
		return
	_server_setup_notice_dialog.add_button("Открыть репозиторий", true, "open_repo")

func _maybe_show_server_setup_notice() -> void:
	if not is_instance_valid(_server_setup_notice_dialog):
		return
	if not SettingsManager or not SettingsManager.has_method("get_seen_server_setup_notice"):
		return
	if SettingsManager.get_seen_server_setup_notice():
		return
	_server_setup_notice_dialog.popup_centered()

func _on_server_setup_notice_custom_action(action: StringName) -> void:
	if action == &"open_repo":
		OS.shell_open(SERVER_SETUP_NOTICE_URL)

func _on_server_setup_notice_dismissed() -> void:
	if SettingsManager and SettingsManager.has_method("set_seen_server_setup_notice"):
		SettingsManager.set_seen_server_setup_notice(true)

func _apply_menu_ui_interactions() -> void:
	UiInteractionApplier.apply_from_engine(self)

func set_transitions(transitions_instance):
	transitions = transitions_instance

func _on_github_pressed():
	OS.shell_open(github_url)

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

func _on_help_pressed():
	MusicManager.play_select_sound()
	if transitions:
		transitions.open_help()

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
	refresh_shop_badge()

func refresh_shop_badge() -> void:
	_update_shop_badge()

func _update_shop_badge() -> void:
	if not is_instance_valid(_shop_badge) or not is_instance_valid(_shop_badge_label):
		return
	var count := PlayerDataManager.get_unseen_shop_reward_count()
	if count <= 0:
		_shop_badge.visible = false
		return
	_shop_badge.visible = true
	_shop_badge_label.text = "99+" if count > 99 else str(count)

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

			if item is PanelContainer:
				_apply_quest_item_style(item, completed)

			if title_label:
				title_label.text = title
				if completed:
					title_label.add_theme_color_override("font_color", Color(0.95, 0.70, 0.30, 1.0))
				else:
					title_label.add_theme_color_override("font_color", Color(0.82, 0.88, 0.96))

			if desc_label:
				var desc_text = "%d • Цель: %d" % [reward, goal]
				if completed:
					desc_text += " (завершено)"
				else:
					desc_text += " (%d/%d)" % [progress, goal]
				desc_label.text = desc_text
				if completed:
					desc_label.add_theme_color_override("font_color", Color(0.92, 0.94, 0.98))
				else:
					desc_label.add_theme_color_override("font_color", Color(0.72, 0.78, 0.88))

			if pb:
				pb.max_value = goal
				pb.value = min(progress, goal)
				_apply_quest_progress_style(pb, completed)

			item.show() 
		else:
			item.hide()

func _apply_quest_item_style(item: PanelContainer, completed: bool) -> void:
	var shell := StyleBoxFlat.new()
	if completed:
		shell.bg_color = Color(0.13, 0.14, 0.18)
		shell.border_color = Color(0.95, 0.78, 0.35, 0.55)
	else:
		shell.bg_color = Color(0.11, 0.12, 0.16)
		shell.border_color = Color(0.62, 0.86, 0.72, 0.45)
	shell.border_width_top = 2
	shell.border_width_left = 1
	shell.border_width_right = 1
	shell.border_width_bottom = 1
	shell.set_corner_radius_all(10)
	item.add_theme_stylebox_override("panel", shell)

func _apply_quest_progress_style(pb: ProgressBar, completed: bool) -> void:
	if completed:
		var fill := StyleBoxFlat.new()
		fill.bg_color = Color(0.95, 0.78, 0.35)
		fill.set_corner_radius_all(5)
		pb.add_theme_stylebox_override("fill", fill)
	else:
		pb.remove_theme_stylebox_override("fill")

func _show_exit_dialog():
	if _exit_dialog:
		if MusicManager and MusicManager.has_method("play_cancel_sound"):
			MusicManager.play_cancel_sound()
		_exit_dialog.popup_centered()

func _on_exit_confirmed():
	if transitions:
		MusicManager.stop_music()
		transitions.exit_game()

func _unhandled_input(event):
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		_show_exit_dialog()
		get_viewport().set_input_as_handled()
