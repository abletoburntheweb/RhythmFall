# scenes/game_screen/game_screen_chart_compare.gd
class_name GameScreenChartCompare
extends Node

const NoteManager = preload("res://logic/core/note_manager.gd")
const _RunModifiers = preload("res://logic/domain/modifiers/run_modifiers.gd")

const SPLIT_COMPARE_MAIN_ANCHOR := Vector2(0.02, 0.48)
const SPLIT_COMPARE_SIDE_ANCHOR := Vector2(0.52, 0.98)

var game_screen = null
var note_manager = null
var playfield: Panel = null
var notes_container: Node2D = null
var hit_zone: ColorRect = null
var hit_zone_y: int = 0
var split_active_runtime: bool = false
var variant_ready: bool = false
var showing_variant: bool = false


func initialize(gs: Control) -> void:
	game_screen = gs


func reset_runtime() -> void:
	split_active_runtime = false
	variant_ready = false
	showing_variant = false
	_hide_playfield()
	if note_manager:
		note_manager.clear_notes()


func is_enabled() -> bool:
	if SettingsManager == null:
		return false
	if SettingsManager.has_method("get_chart_compare_enabled"):
		return SettingsManager.get_chart_compare_enabled()
	return bool(SettingsManager.get_setting("split_compare_enabled", false))


func is_split_mode() -> bool:
	if SettingsManager and SettingsManager.has_method("get_chart_compare_mode"):
		return SettingsManager.get_chart_compare_mode() == "split"
	return false


func is_hotkey_mode() -> bool:
	return is_enabled() and not is_split_mode()


func setup_for_run(song_data: Dictionary) -> void:
	variant_ready = false
	showing_variant = false
	split_active_runtime = false
	_hide_playfield()
	if not is_enabled():
		return
	if _RunModifiers.is_reverse_scroll(game_screen.run_modifiers):
		return
	if _RunModifiers.is_dynamic_lanes(game_screen.run_modifiers):
		return
	var song_path := String(song_data.get("path", ""))
	if song_path == "":
		return
	var tag := NotesUtils.get_split_compare_variant_tag()
	if tag == "":
		return
	if not NotesUtils.notes_exist(
		song_path, "drums", game_screen.current_generation_mode, game_screen.lanes, tag
	):
		push_warning("Chart compare: no chart with tag '%s' for %s" % [tag, song_path])
		return
	_ensure_note_manager()
	note_manager.clear_notes()
	note_manager.load_notes_from_file(
		song_data, game_screen.current_generation_mode, game_screen.lanes, tag
	)
	note_manager.prune_non_play_lanes(
		game_screen.run_modifiers, game_screen.lanes, game_screen.get_chart_lanes()
	)
	variant_ready = note_manager.get_spawn_queue_size() > 0
	if not variant_ready:
		return
	if is_split_mode():
		_ensure_split_playfield()
		note_manager.visual_only = true
		note_manager.visual_alpha = 0.58
		split_active_runtime = true
		if playfield:
			playfield.visible = true
	else:
		note_manager.visual_only = false


func hotkey_ready() -> bool:
	return (
		is_hotkey_mode()
		and variant_ready
		and game_screen.gameplay_started
		and not game_screen.countdown_active
		and not game_screen.game_finished
		and note_manager != null
	)


func swap_hotkey() -> void:
	if not hotkey_ready():
		return
	var main_nm = game_screen.note_manager
	var tmp_q: Array = main_nm.note_spawn_queue
	main_nm.note_spawn_queue = note_manager.note_spawn_queue
	note_manager.note_spawn_queue = tmp_q
	main_nm.clear_active_notes()
	note_manager.clear_active_notes()
	showing_variant = not showing_variant
	game_screen.score_manager.set_total_notes(main_nm.get_spawn_queue_size())
	game_screen._update_hint()


func hint_line() -> String:
	if not is_enabled() or not variant_ready:
		return ""
	if is_split_mode():
		return game_screen.tr("EXP_COMPARE_SPLIT_HINT")
	var tag := NotesUtils.get_split_compare_variant_tag()
	if showing_variant:
		return game_screen.tr("EXP_COMPARE_CHART_B") % tag
	return game_screen.tr("EXP_COMPARE_CHART_A")


func apply_playfield_width(main_playfield: Control) -> Dictionary:
	# Returns {left, right} anchors for the main playfield when split is inactive.
	if split_active_runtime:
		var left := SPLIT_COMPARE_MAIN_ANCHOR.x
		var right := SPLIT_COMPARE_MAIN_ANCHOR.y
		var compare_left := SPLIT_COMPARE_SIDE_ANCHOR.x
		var compare_right := SPLIT_COMPARE_SIDE_ANCHOR.y
		if main_playfield:
			main_playfield.anchor_left = left
			main_playfield.anchor_right = right
		if playfield:
			playfield.anchor_left = compare_left
			playfield.anchor_right = compare_right
			playfield.anchor_top = main_playfield.anchor_top if main_playfield else 0.0
			playfield.anchor_bottom = main_playfield.anchor_bottom if main_playfield else 1.0
			playfield.offset_left = 0
			playfield.offset_right = 0
			playfield.offset_top = 0
			playfield.offset_bottom = 0
		return {"left": left, "right": right}
	return {}


func deactivate_runtime() -> void:
	split_active_runtime = false
	if note_manager:
		note_manager.clear_active_notes()
	_hide_playfield()


func sync_compare_hit_zone(main_hit_zone: ColorRect) -> void:
	if not split_active_runtime or playfield == null or hit_zone == null or main_hit_zone == null:
		return
	hit_zone.anchor_left = 0.0
	hit_zone.anchor_right = 1.0
	hit_zone.anchor_top = main_hit_zone.anchor_top
	hit_zone.anchor_bottom = main_hit_zone.anchor_bottom
	hit_zone.offset_left = main_hit_zone.offset_left
	hit_zone.offset_right = main_hit_zone.offset_right
	hit_zone.offset_top = main_hit_zone.offset_top
	hit_zone.offset_bottom = main_hit_zone.offset_bottom
	hit_zone_y = int(hit_zone.global_position.y - playfield.global_position.y)


func tick_spawn_and_update() -> void:
	if not split_active_runtime or note_manager == null:
		return
	note_manager.spawn_notes()
	note_manager.update_notes()


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


func _ensure_note_manager() -> void:
	if note_manager != null:
		return
	note_manager = NoteManager.new(game_screen)


func _ensure_split_playfield() -> void:
	if playfield != null:
		return
	var main_pf := game_screen.get_node_or_null("Playfield") as Panel
	if main_pf == null:
		return
	playfield = Panel.new()
	playfield.name = "ComparePlayfield"
	playfield.mouse_filter = Control.MOUSE_FILTER_IGNORE
	playfield.z_index = main_pf.z_index
	game_screen.add_child(playfield)
	playfield.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	if main_pf.has_theme_stylebox_override("panel"):
		playfield.add_theme_stylebox_override("panel", main_pf.get_theme_stylebox("panel"))
	notes_container = Node2D.new()
	notes_container.name = "NotesContainer"
	playfield.add_child(notes_container)
	hit_zone = ColorRect.new()
	hit_zone.name = "HitZone"
	hit_zone.color = Color(0.98, 0.64, 0.3, 0.12)
	hit_zone.mouse_filter = Control.MOUSE_FILTER_IGNORE
	playfield.add_child(hit_zone)
	_ensure_note_manager()
	note_manager.playfield_target = NoteManager.PLAYFIELD_COMPARE
	note_manager.visual_only = true
	note_manager.visual_alpha = 0.58
	note_manager.notes_container_override = notes_container


func _hide_playfield() -> void:
	if playfield:
		playfield.visible = false
