# scenes/game_screen/_future/coop_duo/game_screen_coop_duo.gd
# ARCHIVED — local 2-player co-op (split playfield, per-player HUD).
# Not wired in the current build. Planned as a separate scene/mode (not a run modifier).
# See README.md in this folder for integration notes.
extends Node

const NoteManager = preload("res://logic/core/note_manager.gd")
const Player = preload("res://logic/core/player.gd")
const ScoreManager = preload("res://logic/core/score_manager.gd")
const _RunModifiers = preload("res://logic/domain/modifiers/run_modifiers.gd")
const _DuoMode = preload("res://logic/domain/rhythm/duo_mode.gd")
const RunHealth = preload("res://logic/domain/rhythm/run_health.gd")

const DUO_LEFT_CENTER := 0.25
const DUO_RIGHT_CENTER := 0.75

const HealthBarScene = preload("res://scenes/game_screen/components/health_bar.tscn")
const ErrorMeterScript = preload("res://scenes/game_screen/components/error_meter.gd")

var game_screen = null
var note_manager = null
var partner_player = null
var playfield: Panel = null
var lanes_container: Control = null
var notes_container: Node2D = null
var hit_zone: ColorRect = null
var hit_zone_y: int = 0
var partner_progress_container: Control = null
var partner_progress_bar: ProgressBar = null
var partner_combo_container: Control = null
var partner_combo_label: Label = null
var partner_bottom_hud: Control = null
var partner_score_label: Label = null
var partner_accuracy_label: Label = null
var partner_error_meter: ErrorMeter = null
var partner_health_hud: Control = null
var partner_health_bar: HealthBar = null
var partner_judgement_label: Label = null
var partner_score_manager = null
var partner_health_ratio: float = 1.0
var _partner_judgement_tween: Tween = null
var _last_partner_combo: int = 0

var lane_nodes: Array[ColorRect] = []
var lane_highlight_nodes: Array[ColorRect] = []
var lane_divider_nodes: Array[ColorRect] = []

var active: bool = false
var chart_lanes: int = 4
var play_lanes: int = 4


func initialize(gs: Control) -> void:
	game_screen = gs


func reset_runtime() -> void:
	active = false
	chart_lanes = 4
	play_lanes = 4
	_hide_playfield()
	_hide_partner_hud()
	if note_manager:
		note_manager.clear_notes()
	if partner_score_manager:
		partner_score_manager.reset()
	partner_health_ratio = 1.0
	_last_partner_combo = 0
	if partner_judgement_label:
		partner_judgement_label.visible = false
	if partner_player:
		partner_player.set_num_lanes(3)


var session_active: bool = false

func is_modifier_active() -> bool:
	return session_active


func can_start() -> bool:
	if not is_modifier_active():
		return false
	if _RunModifiers.is_single_lane(game_screen.run_modifiers):
		return false
	if _RunModifiers.is_dynamic_lanes(game_screen.run_modifiers):
		return false
	if _RunModifiers.is_reverse_scroll(game_screen.run_modifiers):
		return false
	if game_screen.chart_compare and game_screen.chart_compare.is_enabled():
		return false
	return true


func setup_for_run(_song_data: Dictionary) -> void:
	reset_runtime()
	if not can_start():
		return
	var main_nm = game_screen.note_manager
	if main_nm.get_spawn_queue_size() == 0:
		return
	play_lanes = game_screen.lanes
	chart_lanes = game_screen.get_chart_lanes()
	if play_lanes < 3 or chart_lanes < 3:
		return
	var full_queue: Array = main_nm.note_spawn_queue.duplicate()
	var p1_queue := _DuoMode.queue_for_player(full_queue, 0, chart_lanes)
	var p2_queue := _DuoMode.queue_for_player(full_queue, 1, chart_lanes)
	if p1_queue.is_empty() or p2_queue.is_empty():
		push_warning("Duo: not enough notes on both sides (chart_lanes=%d)" % chart_lanes)
		return
	main_nm.note_spawn_queue = p1_queue
	if game_screen.player:
		game_screen.player.set_num_lanes(play_lanes)
		game_screen.player.set_keymap(
			SettingsManager.build_layout_lane_keymap(ControlsBindings.LAYOUT_PRIMARY, play_lanes)
		)
	_ensure_partner_player()
	_ensure_split_playfield()
	_ensure_partner_hud_ui()
	_ensure_note_manager()
	note_manager.clear_notes()
	note_manager.note_spawn_queue = p2_queue
	if not main_nm.note_colors.is_empty():
		note_manager.set_note_colors(main_nm.note_colors.duplicate())
	_apply_partner_bindings()
	_setup_partner_run()
	active = true
	if playfield:
		playfield.visible = true
	if lane_highlight_nodes.size() > 0 and game_screen.lane_highlight_nodes.size() > 0:
		var main_hl: ColorRect = game_screen.lane_highlight_nodes[0]
		if main_hl:
			set_lane_highlight_colors(main_hl.color)
	_show_partner_hud()


func compute_playfield_anchors() -> Dictionary:
	var bounds: Vector2 = game_screen._playfield_anchor_bounds()
	var w: float = bounds.y - bounds.x
	var half: float = w * 0.5
	return {
		"left": DUO_LEFT_CENTER - half,
		"right": DUO_LEFT_CENTER + half,
		"partner_left": DUO_RIGHT_CENTER - half,
		"partner_right": DUO_RIGHT_CENTER + half,
	}


func apply_playfield_width(main_playfield: Control) -> Dictionary:
	if not active:
		return {}
	var anchors: Dictionary = compute_playfield_anchors()
	var left: float = float(anchors.get("left", 0.0))
	var right: float = float(anchors.get("right", 1.0))
	var partner_left: float = float(anchors.get("partner_left", 0.5))
	var partner_right: float = float(anchors.get("partner_right", 1.0))
	if main_playfield:
		main_playfield.anchor_left = left
		main_playfield.anchor_right = right
	if playfield:
		playfield.anchor_left = partner_left
		playfield.anchor_right = partner_right
		playfield.anchor_top = main_playfield.anchor_top if main_playfield else 0.0
		playfield.anchor_bottom = main_playfield.anchor_bottom if main_playfield else 1.0
		playfield.offset_left = 0
		playfield.offset_right = 0
		playfield.offset_top = 0
		playfield.offset_bottom = 0
	return anchors


func apply_ui_layout(ui: Control, left: float, right: float, partner_left: float, partner_right: float) -> void:
	if not active:
		return
	if ui:
		_layout_side_hud(
			ui.get_node_or_null("SongProgressContainer") as Control,
			ui.get_node_or_null("TopLeftCombo") as Control,
			null,
			ui.get_node_or_null("HealthHud") as Control,
			left,
			right
		)
		_layout_judgement_label(game_screen.judgement_label, left, right)
	_layout_side_hud(
		partner_progress_container,
		partner_combo_container,
		partner_bottom_hud,
		partner_health_hud,
		partner_left,
		partner_right
	)
	_layout_judgement_label(partner_judgement_label, partner_left, partner_right)


func _layout_judgement_label(label: Label, pf_left: float, pf_right: float) -> void:
	if label == null:
		return
	label.anchor_left = pf_left
	label.anchor_right = pf_right
	label.anchor_top = 0.6
	label.anchor_bottom = 0.6
	label.offset_top = -90.0
	label.offset_bottom = -30.0
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER


func _layout_side_hud(
	progress: Control,
	combo: Control,
	bottom: Control,
	health: Control,
	pf_left: float,
	pf_right: float
) -> void:
	if progress:
		progress.anchor_left = pf_left
		progress.anchor_right = pf_right
		progress.anchor_top = 0.0
		progress.anchor_bottom = 0.0
		progress.offset_top = 10.0
		progress.offset_bottom = 28.0
	if combo:
		combo.anchor_left = pf_left
		combo.anchor_right = pf_right
		combo.anchor_top = 0.0
		combo.anchor_bottom = 0.0
		combo.offset_left = 18.0
		combo.offset_top = 36.0
		combo.offset_right = -18.0
		combo.offset_bottom = -36.0
		var combo_label := combo.get_node_or_null("ComboLabel") as Label
		if combo_label:
			combo_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	if bottom:
		bottom.anchor_left = pf_left
		bottom.anchor_right = pf_right
		bottom.anchor_top = 1.0
		bottom.anchor_bottom = 1.0
		bottom.offset_left = 10.0
		bottom.offset_top = -104.0
		bottom.offset_bottom = -14.0
	if health:
		health.anchor_left = pf_right
		health.anchor_right = pf_right
		health.anchor_top = 0.06
		health.anchor_bottom = 0.94
		health.offset_left = 5.0
		health.offset_right = 29.0


func _setup_partner_run() -> void:
	if partner_score_manager == null:
		partner_score_manager = ScoreManager.new(game_screen)
	partner_score_manager.reset()
	partner_score_manager.set_score_reward_multiplier(game_screen._score_reward_multiplier)
	if note_manager:
		partner_score_manager.set_total_notes(note_manager.get_spawn_queue_size())
	partner_health_ratio = _RunModifiers.start_health_ratio(game_screen.run_modifiers)
	_last_partner_combo = 0
	if partner_health_bar and partner_health_bar.has_method("set_ratio"):
		partner_health_bar.set_ratio(0.0, true)


func setup_partner_note_total(count: int) -> void:
	if partner_score_manager:
		partner_score_manager.set_total_notes(count)


func reset_partner_health(animate: bool = true) -> void:
	partner_health_ratio = _RunModifiers.start_health_ratio(game_screen.run_modifiers)
	_apply_partner_health_bar(not animate, 0.55 if animate else 0.14)


func prepare_health_intro() -> void:
	if partner_health_bar and partner_health_bar.has_method("set_ratio"):
		partner_health_bar.set_ratio(0.0, true)


func set_lane_highlight_colors(color: Color) -> void:
	for lane_node in lane_highlight_nodes:
		if lane_node and lane_node is ColorRect:
			var b := 100.0
			if SettingsManager and SettingsManager.has_method("get_lane_highlight_brightness"):
				b = SettingsManager.get_lane_highlight_brightness()
			var a: float = clampf(color.a * (b / 100.0), 0.0, 1.0)
			lane_node.color = Color(color.r, color.g, color.b, a)


func update_partner_lane_highlights() -> void:
	if not active or partner_player == null:
		return
	var layout_lanes: int = play_lanes
	for i in range(lane_highlight_nodes.size()):
		var hl := lane_highlight_nodes[i]
		if hl == null:
			continue
		if i >= layout_lanes:
			hl.visible = false
		elif i >= partner_player.lanes_state.size():
			hl.visible = false
		else:
			hl.visible = partner_player.lanes_state[i]


func on_partner_health_hit(hit_kind: String) -> void:
	partner_health_ratio = RunHealth.apply_hit(partner_health_ratio, hit_kind)
	_apply_partner_health_bar(false)


func on_partner_health_miss() -> void:
	if game_screen._modifier_sudden_death():
		game_screen._try_sudden_death_end()
		return
	partner_health_ratio = RunHealth.apply_miss(partner_health_ratio)
	_apply_partner_health_bar(false)
	if partner_health_ratio <= 0.0 and not game_screen._modifier_no_fail():
		game_screen.call_deferred("end_game_defeat")


func update_partner_ui() -> void:
	if not active or partner_score_manager == null:
		return
	if partner_combo_label:
		var new_combo: int = partner_score_manager.get_combo()
		partner_combo_label.text = "%d (x%.1f)" % [new_combo, partner_score_manager.get_combo_multiplier()]
		if new_combo > _last_partner_combo and game_screen.has_method("_pulse_combo_label"):
			pass
		_last_partner_combo = new_combo
	if partner_score_label and game_screen.has_method("_format_score_text"):
		partner_score_label.text = game_screen._format_score_text(partner_score_manager.get_score())
	if partner_accuracy_label:
		partner_accuracy_label.text = "%.2f%%" % partner_score_manager.get_accuracy()
	if partner_progress_bar and game_screen.progress_bar:
		partner_progress_bar.value = game_screen.progress_bar.value
	if partner_error_meter and game_screen.error_meter:
		partner_error_meter.visible = game_screen.error_meter.visible
	elif partner_error_meter and game_screen.has_method("_error_meter_should_show"):
		partner_error_meter.visible = game_screen._error_meter_should_show()


func show_judgement(text: String, color: Color) -> void:
	if partner_judgement_label == null:
		return
	if _partner_judgement_tween and _partner_judgement_tween.is_valid():
		_partner_judgement_tween.kill()
	partner_judgement_label.visible = true
	partner_judgement_label.text = text
	var c := color
	c.a = 1.0
	partner_judgement_label.modulate = c
	partner_judgement_label.pivot_offset = partner_judgement_label.size * 0.5
	partner_judgement_label.scale = Vector2(1.4, 1.4)
	_partner_judgement_tween = game_screen.create_tween()
	_partner_judgement_tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_partner_judgement_tween.tween_property(partner_judgement_label, "scale", Vector2.ONE, 0.18)
	_partner_judgement_tween.tween_interval(0.22)
	_partner_judgement_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	_partner_judgement_tween.tween_property(partner_judgement_label, "modulate:a", 0.0, 0.3)


func sync_hud_from_main() -> void:
	update_partner_ui()


func sync_hud_visibility(show_health: bool, show_error: bool, visible_in_run: bool) -> void:
	var show_h := show_health and visible_in_run
	var show_e := show_error and visible_in_run
	if partner_health_hud:
		partner_health_hud.visible = show_h
	if partner_error_meter:
		partner_error_meter.visible = show_e


func configure_partner_error_meter(max_ms: float) -> void:
	if partner_error_meter:
		partner_error_meter.set_max_display_ms(max_ms)
		partner_error_meter.clear()


func push_partner_error_meter(kind: String, signed_ms: float = 0.0) -> void:
	if partner_error_meter:
		partner_error_meter.push_entry(kind, signed_ms)


func _apply_partner_health_bar(instant: bool, tween_duration: float = 0.14) -> void:
	var nf_at_zero: bool = game_screen._modifier_no_fail() and partner_health_ratio <= 0.0
	apply_partner_health_bar(partner_health_ratio, instant, nf_at_zero, tween_duration)


func apply_partner_health_bar(ratio: float, instant: bool, nf_at_zero: bool, tween_duration: float = 0.14) -> void:
	if partner_health_bar:
		partner_health_bar.set_ratio(ratio, instant, tween_duration)
		partner_health_bar.set_nf_at_zero(nf_at_zero)


func sync_partner_hit_zone(main_hit_zone: ColorRect) -> void:
	if not active or playfield == null or hit_zone == null or main_hit_zone == null:
		return
	hit_zone.anchor_left = 0.0
	hit_zone.anchor_right = 1.0
	hit_zone.anchor_top = main_hit_zone.anchor_top
	hit_zone.anchor_bottom = main_hit_zone.anchor_bottom
	hit_zone.offset_left = main_hit_zone.offset_left
	hit_zone.offset_right = main_hit_zone.offset_right
	hit_zone.offset_top = main_hit_zone.offset_top
	hit_zone.offset_bottom = main_hit_zone.offset_bottom
	hit_zone.color = main_hit_zone.color
	hit_zone_y = int(hit_zone.global_position.y - playfield.global_position.y)
	update_partner_lane_layout()


func update_partner_lane_layout() -> void:
	if not active or playfield == null or hit_zone == null or lanes_container == null:
		return
	var playfield_width: float = maxf(playfield.size.x, hit_zone.size.x)
	var playfield_height: float = playfield.size.y
	var lane_y: float = hit_zone.position.y
	if lanes_container:
		lane_y = hit_zone.global_position.y - lanes_container.global_position.y
	var layout_lanes: int = play_lanes
	var lane_edges: PackedFloat32Array = game_screen._lane_left_edges_px(playfield_width, layout_lanes)
	for i in range(5):
		var is_lane_active := i < layout_lanes
		var x0 := 0.0
		var lw := 0.0
		if is_lane_active:
			x0 = lane_edges[i]
			lw = lane_edges[i + 1] - lane_edges[i]
		if i < lane_nodes.size() and lane_nodes[i]:
			lane_nodes[i].visible = is_lane_active
			if is_lane_active:
				lane_nodes[i].position = Vector2(x0, lane_y)
				lane_nodes[i].size = Vector2(lw, hit_zone.size.y)
		if i < lane_highlight_nodes.size() and lane_highlight_nodes[i]:
			if is_lane_active:
				lane_highlight_nodes[i].position = Vector2(x0, 0.0)
				lane_highlight_nodes[i].size = Vector2(lw, playfield_height)
				lane_highlight_nodes[i].visible = false
			else:
				lane_highlight_nodes[i].visible = false
	for d in range(lane_divider_nodes.size()):
		var divider := lane_divider_nodes[d]
		if divider == null:
			continue
		var lane_idx := d + 1
		divider.visible = lane_idx < layout_lanes
		if divider.visible:
			var x_edge: float = lane_edges[lane_idx]
			divider.position = Vector2(x_edge - 1.0, 0.0)
			divider.size = Vector2(2.0, playfield_height)
	update_partner_lane_highlights()


func tick_spawn_and_update() -> void:
	if not active or note_manager == null:
		return
	note_manager.spawn_notes()
	note_manager.update_notes()


func layout_lanes_for_target(_target: int) -> int:
	if active:
		return play_lanes
	return game_screen._layout_lane_count()


func get_playfield_width() -> float:
	if playfield == null:
		return 600.0
	var w: float = playfield.size.x
	if hit_zone:
		w = maxf(w, hit_zone.size.x)
	return w if w > 1.0 else 600.0


func get_playfield_height() -> float:
	if playfield:
		return maxf(playfield.size.y, 1.0)
	return maxf(float(game_screen.get_viewport_rect().size.y), 400.0)


func handle_partner_key_press(keycode: int) -> void:
	if not active or partner_player == null:
		return
	partner_player.handle_key_press(keycode)


func handle_partner_key_release(keycode: int) -> void:
	if not active or partner_player == null:
		return
	partner_player.handle_key_release(keycode)


func hint_line() -> String:
	return ""


func reload_partner_bindings() -> void:
	if not active:
		return
	_apply_partner_bindings()


func copy_note_colors_from_main() -> void:
	if not active or note_manager == null or game_screen.note_manager == null:
		return
	var colors: Array = game_screen.note_manager.note_colors
	if not colors.is_empty():
		note_manager.set_note_colors(colors.duplicate())


func _apply_partner_bindings() -> void:
	if partner_player == null:
		return
	partner_player.set_num_lanes(play_lanes)
	partner_player.set_keymap(
		SettingsManager.build_layout_lane_keymap(ControlsBindings.LAYOUT_ALT, play_lanes)
	)


func _ensure_partner_player() -> void:
	if partner_player != null:
		return
	partner_player = Player.new({}, 3)
	partner_player.name = "DuoPartnerPlayer"
	game_screen.add_child(partner_player)
	if not partner_player.lane_pressed_changed.is_connected(_on_partner_lane_pressed_changed):
		partner_player.lane_pressed_changed.connect(_on_partner_lane_pressed_changed)
	partner_player.note_hit.connect(_on_partner_hit)


func _on_partner_lane_pressed_changed() -> void:
	update_partner_lane_highlights()


func _on_partner_hit(lane: int) -> void:
	if game_screen.has_method("check_hit_duo"):
		game_screen.check_hit_duo(lane)


func _ensure_note_manager() -> void:
	if note_manager != null:
		return
	note_manager = NoteManager.new(game_screen)
	note_manager.playfield_target = NoteManager.PLAYFIELD_COMPARE


func _ensure_partner_hud_ui() -> void:
	if partner_progress_container != null:
		return
	var ui := game_screen.get_node_or_null("UIContainer") as Control
	if ui == null:
		return
	var main_stats := game_screen.get_node_or_null("Playfield/BottomHud/StatsPanel") as PanelContainer
	var main_score := game_screen.get_node_or_null("Playfield/BottomHud/StatsPanel/StatsContainer/ScoreLabel") as Label
	var main_accuracy := game_screen.get_node_or_null("Playfield/BottomHud/StatsPanel/StatsContainer/AccuracyLabel") as Label
	var main_progress_bar := ui.get_node_or_null("SongProgressContainer/SongProgressBar") as ProgressBar
	var main_combo_label := ui.get_node_or_null("TopLeftCombo/ComboLabel") as Label

	partner_progress_container = HBoxContainer.new()
	partner_progress_container.name = "DuoPartnerSongProgressContainer"
	partner_progress_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(partner_progress_container)
	partner_progress_bar = ProgressBar.new()
	partner_progress_bar.name = "SongProgressBar"
	partner_progress_bar.custom_minimum_size = Vector2(0, 10)
	partner_progress_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if main_progress_bar and main_progress_bar.theme:
		partner_progress_bar.theme = main_progress_bar.theme
	partner_progress_container.add_child(partner_progress_bar)

	partner_combo_container = Control.new()
	partner_combo_container.name = "DuoPartnerTopLeftCombo"
	partner_combo_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(partner_combo_container)
	partner_combo_label = Label.new()
	partner_combo_label.name = "ComboLabel"
	if main_combo_label:
		partner_combo_label.add_theme_font_size_override("font_size", main_combo_label.get_theme_font_size("font_size"))
		partner_combo_label.add_theme_color_override("font_color", main_combo_label.get_theme_color("font_color"))
	else:
		partner_combo_label.add_theme_font_size_override("font_size", 34)
	partner_combo_label.text = "0 (x1.0)"
	partner_combo_container.add_child(partner_combo_label)
	partner_combo_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	partner_bottom_hud = HBoxContainer.new()
	partner_bottom_hud.name = "DuoPartnerBottomHud"
	partner_bottom_hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	partner_bottom_hud.add_theme_constant_override("separation", 10)
	ui.add_child(partner_bottom_hud)
	var stats_panel := PanelContainer.new()
	stats_panel.name = "StatsPanel"
	stats_panel.custom_minimum_size = Vector2(196, 0)
	if main_stats:
		var panel_style := main_stats.get_theme_stylebox("panel")
		if panel_style:
			stats_panel.add_theme_stylebox_override("panel", panel_style)
	partner_bottom_hud.add_child(stats_panel)
	var stats_vbox := VBoxContainer.new()
	stats_vbox.name = "StatsContainer"
	stats_vbox.add_theme_constant_override("separation", 4)
	stats_panel.add_child(stats_vbox)
	partner_accuracy_label = Label.new()
	partner_accuracy_label.name = "AccuracyLabel"
	if main_accuracy:
		partner_accuracy_label.add_theme_font_size_override("font_size", main_accuracy.get_theme_font_size("font_size"))
		partner_accuracy_label.add_theme_color_override("font_color", main_accuracy.get_theme_color("font_color"))
	partner_accuracy_label.text = "100.00%"
	stats_vbox.add_child(partner_accuracy_label)
	partner_score_label = Label.new()
	partner_score_label.name = "ScoreLabel"
	if main_score:
		partner_score_label.add_theme_font_size_override("font_size", main_score.get_theme_font_size("font_size"))
		partner_score_label.add_theme_color_override("font_color", main_score.get_theme_color("font_color"))
	partner_score_label.text = main_score.text if main_score else "0"
	stats_vbox.add_child(partner_score_label)
	partner_error_meter = ErrorMeterScript.new()
	partner_error_meter.name = "ErrorMeter"
	partner_error_meter.custom_minimum_size = Vector2(0, 20)
	partner_error_meter.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	partner_error_meter.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	partner_bottom_hud.add_child(partner_error_meter)
	if game_screen.has_method("_sync_error_meter_theme") and game_screen.error_meter:
		partner_error_meter.color_perfect = game_screen.error_meter.color_perfect
		partner_error_meter.color_good = game_screen.error_meter.color_good
		partner_error_meter.color_miss = game_screen.error_meter.color_miss

	partner_health_hud = MarginContainer.new()
	partner_health_hud.name = "DuoPartnerHealthHud"
	partner_health_hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	partner_health_hud.add_theme_constant_override("margin_top", 16)
	partner_health_hud.add_theme_constant_override("margin_bottom", 16)
	ui.add_child(partner_health_hud)
	partner_health_bar = HealthBarScene.instantiate() as HealthBar
	partner_health_bar.name = "HealthBar"
	partner_health_bar.size_flags_vertical = Control.SIZE_EXPAND_FILL
	partner_health_hud.add_child(partner_health_bar)

	var main_judgement := ui.get_node_or_null("JudgementLabel") as Label
	partner_judgement_label = Label.new()
	partner_judgement_label.name = "DuoPartnerJudgementLabel"
	partner_judgement_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	partner_judgement_label.visible = false
	if main_judgement:
		partner_judgement_label.add_theme_font_size_override("font_size", main_judgement.get_theme_font_size("font_size"))
		partner_judgement_label.add_theme_color_override("font_outline_color", main_judgement.get_theme_color("font_outline_color"))
		partner_judgement_label.add_theme_constant_override("outline_size", main_judgement.get_theme_constant("outline_size"))
	partner_judgement_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	partner_judgement_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	ui.add_child(partner_judgement_label)

	_hide_partner_hud()


func _show_partner_hud() -> void:
	for node in [
		partner_progress_container,
		partner_combo_container,
		partner_bottom_hud,
		partner_health_hud,
	]:
		if node:
			node.visible = true


func _hide_partner_hud() -> void:
	for node in [
		partner_progress_container,
		partner_combo_container,
		partner_bottom_hud,
		partner_health_hud,
	]:
		if node:
			node.visible = false


func _ensure_split_playfield() -> void:
	if playfield != null:
		return
	var main_pf := game_screen.get_node_or_null("Playfield") as Panel
	if main_pf == null:
		return
	playfield = Panel.new()
	playfield.name = "DuoPartnerPlayfield"
	playfield.mouse_filter = Control.MOUSE_FILTER_IGNORE
	playfield.z_index = main_pf.z_index
	game_screen.add_child(playfield)
	var ui_container := game_screen.get_node_or_null("UIContainer") as Node
	var ui_index: int = ui_container.get_index() if ui_container else -1
	if ui_index >= 0:
		game_screen.move_child(playfield, ui_index)
	playfield.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	if main_pf.has_theme_stylebox_override("panel"):
		playfield.add_theme_stylebox_override("panel", main_pf.get_theme_stylebox("panel"))
	lanes_container = Control.new()
	lanes_container.name = "LanesContainer"
	lanes_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	playfield.add_child(lanes_container)
	lanes_container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var main_lanes := main_pf.get_node_or_null("LanesContainer") as Control
	for i in range(5):
		var main_hl := main_lanes.get_node_or_null("Lane%dHighlight" % i) as ColorRect if main_lanes else null
		var hl := ColorRect.new()
		hl.name = "Lane%dHighlight" % i
		hl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		if main_hl:
			hl.color = main_hl.color
		lanes_container.add_child(hl)
		lane_highlight_nodes.append(hl)
		var main_lane := main_lanes.get_node_or_null("Lane%d" % i) as ColorRect if main_lanes else null
		var lane := ColorRect.new()
		lane.name = "Lane%d" % i
		lane.mouse_filter = Control.MOUSE_FILTER_IGNORE
		if main_lane:
			lane.color = main_lane.color
		lanes_container.add_child(lane)
		lane_nodes.append(lane)
	for d in range(4):
		var main_div := main_lanes.get_node_or_null("LaneDivider%d" % d) as ColorRect if main_lanes else null
		var divider := ColorRect.new()
		divider.name = "LaneDivider%d" % d
		divider.mouse_filter = Control.MOUSE_FILTER_IGNORE
		if main_div:
			divider.color = main_div.color
		lanes_container.add_child(divider)
		lane_divider_nodes.append(divider)
	notes_container = Node2D.new()
	notes_container.name = "DuoNotesContainer"
	notes_container.z_index = 4
	playfield.add_child(notes_container)
	hit_zone = ColorRect.new()
	hit_zone.name = "DuoHitZone"
	hit_zone.color = Color(1, 1, 1, 0.28)
	hit_zone.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hit_zone.z_index = 8
	playfield.add_child(hit_zone)
	_ensure_note_manager()
	note_manager.notes_container_override = notes_container


func _hide_playfield() -> void:
	if playfield:
		playfield.visible = false
