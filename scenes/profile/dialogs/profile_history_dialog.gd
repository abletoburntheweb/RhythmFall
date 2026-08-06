# Fullscreen History ritual: Timeline / Records / Capsules (profile IA).
class_name ProfileHistoryDialog
extends Control

signal closed()

const _ProfileRecordsView = preload("res://scenes/profile/components/profile_records_view.gd")
const _TimeCapsule = preload("res://logic/domain/profile/time_capsule.gd")
const _PlayerEvolution = preload("res://logic/domain/profile/player_evolution.gd")
const _ProfileEventLog = preload("res://logic/domain/profile/profile_event_log.gd")
const _GenreGroupIcons = preload("res://logic/domain/library/genre_group_icons.gd")
const _GradeDisplay = preload("res://logic/ui/grade_display.gd")
const _SongSelectUiStyles = preload("res://scenes/song_select/lib/song_select_ui_styles.gd")
const _UiIconHelper = preload("res://logic/ui/ui_icon_helper.gd")
const _UiCategoryButton = preload("res://logic/ui/ui_category_button.gd")
const _UiModifierSounds = preload("res://logic/ui/ui_modifier_sounds.gd")
const _UiFramedCover = preload("res://logic/ui/ui_framed_cover.gd")

const SECTION_TIMELINE := "timeline"
const SECTION_RECORDS := "records"
const SECTION_CAPSULES := "capsules"
const COMPARE_NOW := ""

const _SECTION_ACCENTS := {
	SECTION_TIMELINE: Color(0.72, 0.62, 0.95, 1.0),
	SECTION_RECORDS: Color(0.55, 0.72, 0.98, 1.0),
	SECTION_CAPSULES: Color(0.92, 0.55, 0.72, 1.0),
}
const _SECTION_ICONS := {
	SECTION_TIMELINE: "scroll-text.svg",
	SECTION_RECORDS: "trophy.svg",
	SECTION_CAPSULES: "archive.svg",
}

const _TEXT := Color(0.88, 0.92, 0.98, 1.0)
const _TEXT_MUTED := Color(0.55, 0.6, 0.7, 0.85)
const _STAT_ICON_CLEARS := Color(0.55, 0.85, 0.65, 1.0)
const _STAT_ICON_FAILS := Color(0.95, 0.55, 0.48, 1.0)
const _STAT_ICON_TRACKS := Color(0.55, 0.78, 0.98, 1.0)
const _STAT_ICON_GRADE := Color(0.95, 0.82, 0.45, 1.0)
const _STAT_ICON_SCORE := Color(0.7, 0.84, 0.98, 1.0)
const _STAT_ROW_BG := Color(0.1, 0.13, 0.2, 0.72)
const _CAPSULE_ACCENT := Color(0.92, 0.55, 0.72, 1.0)

var _section: String = SECTION_TIMELINE
var _pending_focus_section_id: String = ""
var _show_comparison := false
var _compare_left_key: String = COMPARE_NOW
var _compare_right_key: String = COMPARE_NOW
var _pick_slot: String = "left" ## next card tap fills left|right
var _refresh_token := 0
var _feed_filter: String = _ProfileEventLog.FILTER_ALL

@onready var _back_button: Button = %BackButton
@onready var _title_label: Label = %TitleLabel
@onready var _calendar_button: Button = %CalendarButton
@onready var _timeline_btn: Button = %TimelineButton
@onready var _records_btn: Button = %RecordsButton
@onready var _capsules_btn: Button = %CapsulesButton
@onready var _content_shell: PanelContainer = %ContentShell
@onready var _content_scroll: ScrollContainer = %ContentScroll
@onready var _content_vbox: VBoxContainer = %ContentVBox
@onready var _footer_label: Label = get_node_or_null("%FooterHintLabel") as Label


func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_to_group("locale_refresh")
	_UiIconHelper.configure_modal_overlay(self, 105)
	var bg := get_node_or_null("Background") as ColorRect
	if bg:
		bg.mouse_filter = Control.MOUSE_FILTER_STOP
		bg.color = Color(0.02, 0.03, 0.06, 0.9)
		bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_apply_content_shell_style()
	# Regular buttons (not ButtonGroup toggle) — same pattern as profile category bar.
	_setup_section_button(_timeline_btn, SECTION_TIMELINE)
	_setup_section_button(_records_btn, SECTION_RECORDS)
	_setup_section_button(_capsules_btn, SECTION_CAPSULES)
	if _back_button and not _back_button.pressed.is_connected(_on_back_pressed):
		_back_button.pressed.connect(_on_back_pressed)
	if _calendar_button and not _calendar_button.pressed.is_connected(_on_calendar_pressed):
		_calendar_button.pressed.connect(_on_calendar_pressed)
	if _timeline_btn and not _timeline_btn.pressed.is_connected(_on_section_timeline):
		_timeline_btn.pressed.connect(_on_section_timeline)
	if _records_btn and not _records_btn.pressed.is_connected(_on_section_records):
		_records_btn.pressed.connect(_on_section_records)
	if _capsules_btn and not _capsules_btn.pressed.is_connected(_on_section_capsules):
		_capsules_btn.pressed.connect(_on_section_capsules)
	_sync_section_buttons()
	apply_locale()


func _apply_content_shell_style() -> void:
	if _content_shell == null:
		return
	var box := StyleBoxFlat.new()
	box.bg_color = Color(0.06, 0.08, 0.12, 0.96)
	box.border_color = Color(1, 1, 1, 0.1)
	box.set_border_width_all(1)
	box.set_corner_radius_all(14)
	_content_shell.add_theme_stylebox_override("panel", box)


func _setup_section_button(btn: Button, section_id: String) -> void:
	if btn == null:
		return
	btn.toggle_mode = false
	btn.button_group = null
	btn.focus_mode = Control.FOCUS_NONE
	btn.custom_minimum_size = Vector2(120, 36)
	btn.theme_type_variation = &"CategoryKick"
	btn.set_meta("ui_variation_inactive", &"CategoryKick")
	btn.set_meta("ui_variation_active", &"ActiveKick")
	btn.set_meta("ui_icon_file", str(_SECTION_ICONS.get(section_id, "sparkles.svg")))
	btn.set_meta("ui_accent_color", _SECTION_ACCENTS.get(section_id, Color(0.72, 0.62, 0.95, 1.0)))


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("ui_cancel"):
		_close()
		get_viewport().set_input_as_handled()


func is_open() -> bool:
	return visible


func handle_hotkey(event: InputEvent) -> bool:
	if not visible:
		return false
	if event.is_action_pressed("ui_cancel"):
		_close()
		return true
	if not (event is InputEventKey) or not event.pressed or event.echo:
		return false
	if event.keycode >= KEY_1 and event.keycode <= KEY_3:
		var index := int(event.keycode - KEY_1)
		var sections := [SECTION_TIMELINE, SECTION_RECORDS, SECTION_CAPSULES]
		_select_section(str(sections[index]))
		return true
	# Feed filters only on Timeline section.
	if _section == SECTION_TIMELINE:
		var filter_keys := {
			KEY_Q: _ProfileEventLog.FILTER_ALL,
			KEY_W: _ProfileEventLog.FILTER_MILESTONES,
			KEY_E: _ProfileEventLog.FILTER_ACHIEVEMENTS,
			KEY_R: _ProfileEventLog.FILTER_RECORDS,
			KEY_T: _ProfileEventLog.FILTER_MODES,
		}
		if filter_keys.has(event.keycode):
			var fid := str(filter_keys[event.keycode])
			if fid == _feed_filter:
				return true
			_feed_filter = fid
			_UiModifierSounds.play_select()
			refresh()
			return true
	return false


func get_footer_hint() -> String:
	if _section == SECTION_TIMELINE:
		var day_on := bool(SettingsManager.get_setting("diary_history_open_day", false))
		var track_on := bool(SettingsManager.get_setting("diary_history_open_track", false))
		if day_on and track_on:
			return tr("PROFILE_HISTORY_FOOTER_HINT_FEED_LINKS")
		if day_on:
			return tr("PROFILE_HISTORY_FOOTER_HINT_FEED_DAY")
		if track_on:
			return tr("PROFILE_HISTORY_FOOTER_HINT_FEED_TRACK")
		return tr("PROFILE_HISTORY_FOOTER_HINT_FEED")
	return tr("PROFILE_HISTORY_FOOTER_HINT")


func close(with_sound: bool = true) -> void:
	_close(with_sound)


func apply_locale() -> void:
	if _back_button:
		_back_button.text = tr("BTN_BACK")
		_UiIconHelper.apply_standard_back_button(_back_button)
	if _title_label:
		_title_label.text = tr("PROFILE_HISTORY_TITLE")
	if _calendar_button:
		_calendar_button.text = tr("PROFILE_CALENDAR_OPEN_BUTTON")
		_calendar_button.tooltip_text = tr("PROFILE_ACTIVITY_OPEN_TIP")
		_calendar_button.custom_minimum_size = _UiIconHelper.BACK_BUTTON_MIN_SIZE
		_calendar_button.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		_calendar_button.theme_type_variation = &"FlatBackButton"
		_UiIconHelper.configure_button_icon(
			_calendar_button,
			"calendar.svg",
			_UiIconHelper.MUTED,
			16
		)
	if _timeline_btn:
		_timeline_btn.text = tr("PROFILE_HISTORY_SEC_TIMELINE")
	if _records_btn:
		_records_btn.text = tr("PROFILE_HISTORY_SEC_RECORDS")
	if _capsules_btn:
		_capsules_btn.text = tr("PROFILE_HISTORY_SEC_CAPSULES")
	_refresh_section_button_styles()
	if visible:
		refresh()


func open(section: String = SECTION_TIMELINE, focus_section_id: String = "") -> void:
	_section = _normalize_section(section)
	_pending_focus_section_id = str(focus_section_id).strip_edges()
	_show_comparison = false
	_ensure_default_compare_keys()
	_sync_section_buttons()
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	visible = true
	move_to_front()
	_UiModifierSounds.play_select()
	if _back_button:
		_back_button.grab_focus()
	await refresh()


func refresh() -> void:
	_refresh_token += 1
	var token := _refresh_token
	_refresh_local_footer()
	if _section == SECTION_CAPSULES:
		_clear_content()
		if _show_comparison:
			_rebuild_comparison_panel()
		else:
			_rebuild_capsules_list()
		_notify_footer_changed()
		return
	var msg_key := (
		"PROFILE_HISTORY_LOADING_FEED"
		if _section == SECTION_TIMELINE
		else "PROFILE_HISTORY_LOADING_RECORDS"
	)
	var host := _profile_host()
	if host and host.has_method("with_profile_loading"):
		await host.with_profile_loading(_refresh_heavy.bind(token), msg_key)
	else:
		await _refresh_heavy(token)
	if token != _refresh_token:
		return
	_notify_footer_changed()
	var focus_id := _pending_focus_section_id
	_pending_focus_section_id = ""
	if focus_id != "":
		await _focus_section(focus_id)


func _refresh_heavy(token: int) -> void:
	_clear_content()
	if token != _refresh_token:
		return
	match _section:
		SECTION_TIMELINE:
			await _rebuild_timeline_async(token)
		SECTION_RECORDS:
			await _rebuild_records_staged(token)
		_:
			await _rebuild_timeline_async(token)


func _refresh_local_footer() -> void:
	if _footer_label:
		_footer_label.text = get_footer_hint()


func _rebuild_records_staged(token: int) -> void:
	var staging := VBoxContainer.new()
	staging.visible = false
	staging.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_child(staging)
	await _ProfileRecordsView.rebuild_async(staging, _card_style(), "records", false)
	if token != _refresh_token:
		staging.queue_free()
		return
	_clear_content()
	for child in staging.get_children():
		staging.remove_child(child)
		_content_vbox.add_child(child)
	staging.queue_free()


func _rebuild_timeline_async(token: int) -> void:
	var staging := VBoxContainer.new()
	staging.visible = false
	staging.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	staging.add_theme_constant_override("separation", 14)
	add_child(staging)
	if PlayerDataManager and PlayerDataManager.has_method("ensure_profile_event_log_backfill"):
		PlayerDataManager.ensure_profile_event_log_backfill()
	if PlayerDataManager and PlayerDataManager.has_method("check_track_anniversaries"):
		PlayerDataManager.check_track_anniversaries()
	if token != _refresh_token:
		staging.queue_free()
		return
	staging.add_child(_make_milestones_timeline_block())
	await get_tree().process_frame
	if token != _refresh_token:
		staging.queue_free()
		return
	staging.add_child(_make_filter_row())
	await get_tree().process_frame
	if token != _refresh_token:
		staging.queue_free()
		return
	var feed := await _make_feed_block_async(token)
	if token != _refresh_token:
		staging.queue_free()
		return
	if feed:
		staging.add_child(feed)
	_clear_content()
	for child in staging.get_children():
		staging.remove_child(child)
		_content_vbox.add_child(child)
	staging.queue_free()


func _notify_footer_changed() -> void:
	_refresh_local_footer()
	var host := _profile_host()
	if host and host.has_method("_refresh_footer_hint"):
		host._refresh_footer_hint()




func focus_records_section(section_id: String) -> void:
	var sid := str(section_id).strip_edges()
	if sid == "":
		return
	var group := _ProfileRecordsView.group_for_section_id(sid)
	_section = group if group == SECTION_TIMELINE else SECTION_RECORDS
	_pending_focus_section_id = sid
	_show_comparison = false
	_sync_section_buttons()
	if visible:
		await refresh()


func _normalize_section(section: String) -> String:
	var s := str(section).strip_edges().to_lower()
	match s:
		SECTION_RECORDS, "record":
			return SECTION_RECORDS
		SECTION_CAPSULES, "capsule", "journey":
			return SECTION_CAPSULES
		_:
			return SECTION_TIMELINE


func _sync_section_buttons() -> void:
	_refresh_section_button_styles()
	if get_tree():
		get_tree().create_timer(0.05).timeout.connect(
			func() -> void: _refresh_section_button_styles(),
			CONNECT_ONE_SHOT
		)


func _refresh_section_button_styles() -> void:
	for pair in [
		[_timeline_btn, SECTION_TIMELINE],
		[_records_btn, SECTION_RECORDS],
		[_capsules_btn, SECTION_CAPSULES],
	]:
		var btn: Button = pair[0]
		var sid := str(pair[1])
		if btn == null:
			continue
		var active := _section == sid
		# Like profile categories: per-tab text color when idle, dim icons.
		# Like chart metrics: when active, accent on both icon+text + outline.
		_UiCategoryButton.apply_selection(btn, active, 16, true, false)
		var accent: Color = _SECTION_ACCENTS.get(sid, Color(0.72, 0.62, 0.95, 1.0))
		for key in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
			btn.add_theme_color_override(key, accent)
		btn.modulate = Color.WHITE


func _reset_section_hover() -> void:
	for btn in [_timeline_btn, _records_btn, _capsules_btn]:
		_UiCategoryButton.reset_hover_state(btn)


func _select_section(section: String) -> void:
	var next := _normalize_section(section)
	if next == _section:
		_sync_section_buttons()
		return
	_reset_section_hover()
	UiScreenHotkeys.play_section_switch_sound()
	_section = next
	_show_comparison = false
	if next == SECTION_CAPSULES:
		_ensure_default_compare_keys()
	_sync_section_buttons()
	_notify_footer_changed()
	refresh()


func _on_section_timeline() -> void:
	_select_section(SECTION_TIMELINE)


func _on_section_records() -> void:
	_select_section(SECTION_RECORDS)


func _on_section_capsules() -> void:
	_select_section(SECTION_CAPSULES)


func _on_back_pressed() -> void:
	if _show_comparison and _section == SECTION_CAPSULES:
		_UiModifierSounds.play_select()
		_show_comparison = false
		refresh()
		return
	_close()


func _on_calendar_pressed() -> void:
	# Calendar open() plays a single modifier_select — don't stack.
	var host := _profile_host()
	if host and host.has_method("open_activity_calendar"):
		_close(false)
		host.open_activity_calendar()


func _close(with_sound: bool = true) -> void:
	if not visible:
		return
	if with_sound:
		_UiModifierSounds.play_deselect()
	visible = false
	_show_comparison = false
	_pending_focus_section_id = ""
	_clear_content()
	closed.emit()


func _profile_host() -> Node:
	var p := get_parent()
	while p:
		if p.has_method("open_activity_calendar"):
			return p
		p = p.get_parent()
	return null


func _clear_content() -> void:
	if _content_vbox == null:
		return
	for child in _content_vbox.get_children():
		_content_vbox.remove_child(child)
		child.queue_free()
	if _content_scroll:
		_content_scroll.scroll_vertical = 0


func _card_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.094118, 0.094118, 0.121569, 1)
	style.border_color = Color(1, 1, 1, 0.08)
	style.set_border_width_all(1)
	style.set_corner_radius_all(8)
	style.content_margin_left = 12.0
	style.content_margin_top = 10.0
	style.content_margin_right = 12.0
	style.content_margin_bottom = 10.0
	return style


func _focus_section(section_id: String) -> void:
	if _content_vbox == null or _content_scroll == null:
		return
	await get_tree().process_frame
	for child in _content_vbox.get_children():
		if child.has_method("get_section_id") and str(child.call("get_section_id")) == section_id:
			_content_scroll.scroll_vertical = int(maxf(0.0, child.position.y - 8.0))
			break


# --- Timeline ---

func _rebuild_timeline() -> void:
	if _content_vbox == null:
		return
	if PlayerDataManager and PlayerDataManager.has_method("ensure_profile_event_log_backfill"):
		PlayerDataManager.ensure_profile_event_log_backfill()
	if PlayerDataManager and PlayerDataManager.has_method("check_track_anniversaries"):
		PlayerDataManager.check_track_anniversaries()
	_content_vbox.add_theme_constant_override("separation", 14)
	_content_vbox.add_child(_make_milestones_timeline_block())
	_content_vbox.add_child(_make_filter_row())
	_content_vbox.add_child(_make_feed_block())


func _make_milestones_timeline_block() -> PanelContainer:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel", _inner_section_style(Color(0.72, 0.62, 0.95, 0.35)))
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 10)
	panel.add_child(col)

	var head := HBoxContainer.new()
	head.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_child(head)
	var title := Label.new()
	title.text = tr("PROFILE_RECORDS_MILESTONES")
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.add_theme_font_size_override("font_size", 15)
	title.add_theme_color_override("font_color", _TEXT)
	head.add_child(title)

	var entries := _ProfileRecordsView.list_milestone_entries()
	if entries.is_empty():
		var empty := Label.new()
		empty.text = tr("PROFILE_HISTORY_FEED_EMPTY")
		empty.add_theme_font_size_override("font_size", 13)
		empty.add_theme_color_override("font_color", _TEXT_MUTED)
		col.add_child(empty)
		return panel

	var row1 := HBoxContainer.new()
	row1.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row1.add_theme_constant_override("separation", 8)
	col.add_child(row1)
	var preview_n := mini(5, entries.size())
	for i in range(preview_n):
		row1.add_child(_make_milestone_timeline_node(entries[i] as Dictionary))

	var more_wrap := HBoxContainer.new()
	more_wrap.visible = false
	more_wrap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	more_wrap.add_theme_constant_override("separation", 8)
	col.add_child(more_wrap)
	if entries.size() > 5:
		var rest_n := mini(10, entries.size())
		for i in range(5, rest_n):
			more_wrap.add_child(_make_milestone_timeline_node(entries[i] as Dictionary))
		var toggle := Button.new()
		toggle.text = tr("PROFILE_HISTORY_SHOW_MORE")
		toggle.focus_mode = Control.FOCUS_NONE
		toggle.theme_type_variation = &"FlatBackButton"
		toggle.custom_minimum_size = Vector2(0, 34)
		toggle.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		toggle.pressed.connect(func() -> void:
			more_wrap.visible = not more_wrap.visible
			if more_wrap.visible:
				_UiModifierSounds.play_select()
			else:
				_UiModifierSounds.play_deselect()
			toggle.text = tr("PROFILE_HISTORY_SHOW_LESS" if more_wrap.visible else "PROFILE_HISTORY_SHOW_MORE")
		)
		col.add_child(toggle)
	return panel


func _make_milestone_timeline_node(entry: Dictionary) -> PanelContainer:
	var achieved := bool(entry.get("achieved", false))
	var accent: Color = entry.get("tint", Color(0.72, 0.62, 0.95, 1.0))
	if not achieved:
		accent = Color(accent.r, accent.g, accent.b, 0.45)
	var card := PanelContainer.new()
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var box := StyleBoxFlat.new()
	box.bg_color = Color(0.07, 0.09, 0.13, 0.96)
	box.border_color = Color(accent.r, accent.g, accent.b, 0.55 if achieved else 0.18)
	box.set_border_width_all(1)
	box.set_corner_radius_all(12)
	box.content_margin_left = 8.0
	box.content_margin_right = 8.0
	box.content_margin_top = 10.0
	box.content_margin_bottom = 10.0
	card.add_theme_stylebox_override("panel", box)

	var col := VBoxContainer.new()
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", 8)
	card.add_child(col)

	var icon_wrap := CenterContainer.new()
	col.add_child(icon_wrap)
	icon_wrap.add_child(
		_UiIconHelper.make_icon_frame(str(entry.get("icon", "sparkles.svg")), 48, 26, accent)
	)

	var title := Label.new()
	title.text = tr(str(entry.get("title_key", "")))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title.add_theme_font_size_override("font_size", 11)
	title.add_theme_color_override("font_color", _TEXT if achieved else _TEXT_MUTED)
	col.add_child(title)

	var date := Label.new()
	const _TimeUtils = preload("res://logic/platform/time_utils.gd")
	var raw_date := str(entry.get("date", ""))
	date.text = _TimeUtils.format_iso_date_dmy(raw_date) if achieved and raw_date != "" else "—"
	date.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	date.clip_text = false
	date.add_theme_font_size_override("font_size", 10)
	date.add_theme_color_override("font_color", _TEXT_MUTED)
	col.add_child(date)
	return card


func _make_feed_block() -> PanelContainer:
	# Sync fallback (focus / rare paths). Prefer async rebuild for loading UX.
	return _make_feed_block_sync()


func _make_feed_block_sync() -> PanelContainer:
	var panel := _feed_panel_shell()
	var col: VBoxContainer = panel.get_child(0) as VBoxContainer
	_fill_feed_events(col, -1)
	return panel


func _make_feed_block_async(token: int) -> PanelContainer:
	var panel := _feed_panel_shell()
	var col: VBoxContainer = panel.get_child(0) as VBoxContainer
	await _fill_feed_events_async(col, token)
	if token != _refresh_token:
		panel.queue_free()
		return null
	return panel


func _feed_panel_shell() -> PanelContainer:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel", _inner_section_style(Color(0.55, 0.62, 0.78, 0.28)))
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 10)
	panel.add_child(col)
	var feed_title := Label.new()
	feed_title.text = tr("PROFILE_HISTORY_FEED_TITLE")
	feed_title.add_theme_font_size_override("font_size", 15)
	feed_title.add_theme_color_override("font_color", _TEXT)
	col.add_child(feed_title)
	return panel


func _fill_feed_events(col: VBoxContainer, _token: int) -> void:
	var pdata: Dictionary = PlayerDataManager.data if PlayerDataManager else {}
	var events := _ProfileEventLog.list_events(pdata, _feed_filter)
	if events.is_empty():
		var empty := Label.new()
		empty.text = tr("PROFILE_HISTORY_FEED_EMPTY")
		empty.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		empty.add_theme_font_size_override("font_size", 13)
		empty.add_theme_color_override("font_color", _TEXT_MUTED)
		col.add_child(empty)
		return
	var rail := VBoxContainer.new()
	rail.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rail.add_theme_constant_override("separation", 0)
	col.add_child(rail)
	var event_list: Array = []
	for ev in events:
		if ev is Dictionary:
			event_list.append(ev)
	for i in range(event_list.size()):
		var prev_accent := Color(0, 0, 0, 0)
		if i > 0:
			prev_accent = _ProfileEventLog.tint_for_event(event_list[i - 1] as Dictionary)
		rail.add_child(_make_feed_event_row(
			event_list[i] as Dictionary,
			prev_accent,
			i == 0,
			i == event_list.size() - 1
		))


func _fill_feed_events_async(col: VBoxContainer, token: int) -> void:
	var pdata: Dictionary = PlayerDataManager.data if PlayerDataManager else {}
	var events := _ProfileEventLog.list_events(pdata, _feed_filter)
	if events.is_empty():
		var empty := Label.new()
		empty.text = tr("PROFILE_HISTORY_FEED_EMPTY")
		empty.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		empty.add_theme_font_size_override("font_size", 13)
		empty.add_theme_color_override("font_color", _TEXT_MUTED)
		col.add_child(empty)
		return
	var rail := VBoxContainer.new()
	rail.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rail.add_theme_constant_override("separation", 0)
	col.add_child(rail)
	var event_list: Array = []
	for ev in events:
		if ev is Dictionary:
			event_list.append(ev)
	for i in range(event_list.size()):
		if token != _refresh_token:
			return
		var prev_accent := Color(0, 0, 0, 0)
		if i > 0:
			prev_accent = _ProfileEventLog.tint_for_event(event_list[i - 1] as Dictionary)
		rail.add_child(_make_feed_event_row(
			event_list[i] as Dictionary,
			prev_accent,
			i == 0,
			i == event_list.size() - 1
		))
		if i > 0 and i % 6 == 0:
			await get_tree().process_frame


func _make_feed_event_row(
	ev: Dictionary,
	prev_accent: Color,
	is_first: bool,
	is_last: bool
) -> Control:
	var root := HBoxContainer.new()
	root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.add_theme_constant_override("separation", 10)
	root.custom_minimum_size = Vector2(0, 104)

	var accent: Color = _ProfileEventLog.tint_for_event(ev)
	var icon_file := _ProfileEventLog.icon_for_event(ev)

	var date_col := VBoxContainer.new()
	date_col.custom_minimum_size = Vector2(108, 0)
	date_col.size_flags_vertical = Control.SIZE_EXPAND_FILL
	date_col.alignment = BoxContainer.ALIGNMENT_CENTER
	root.add_child(date_col)
	var date_lbl := Label.new()
	date_lbl.text = _ProfileEventLog.relative_day_label(str(ev.get("ts", "")))
	date_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	date_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	date_lbl.add_theme_font_size_override("font_size", 13)
	date_lbl.add_theme_color_override("font_color", Color(accent.r, accent.g, accent.b, 0.95))
	date_col.add_child(date_lbl)

	# Colored segments that stop at the icon (do not pierce it).
	var rail_col := VBoxContainer.new()
	rail_col.custom_minimum_size = Vector2(48, 0)
	rail_col.size_flags_vertical = Control.SIZE_EXPAND_FILL
	rail_col.alignment = BoxContainer.ALIGNMENT_CENTER
	rail_col.add_theme_constant_override("separation", 0)
	root.add_child(rail_col)
	rail_col.add_child(_make_timeline_segment(
		Color(prev_accent.r, prev_accent.g, prev_accent.b, 0.55) if not is_first else Color(0, 0, 0, 0)
	))
	var icon_wrap := CenterContainer.new()
	icon_wrap.custom_minimum_size = Vector2(48, 48)
	icon_wrap.add_child(_UiIconHelper.make_icon_frame(icon_file, 44, 24, accent))
	rail_col.add_child(icon_wrap)
	rail_col.add_child(_make_timeline_segment(
		Color(accent.r, accent.g, accent.b, 0.55) if not is_last else Color(0, 0, 0, 0)
	))

	var body := PanelContainer.new()
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var box := StyleBoxFlat.new()
	box.bg_color = Color(0.08, 0.1, 0.14, 0.94)
	box.border_color = Color(accent.r, accent.g, accent.b, 0.28)
	box.set_border_width_all(1)
	box.set_corner_radius_all(12)
	box.content_margin_left = 14.0
	box.content_margin_right = 14.0
	box.content_margin_top = 12.0
	box.content_margin_bottom = 12.0
	body.add_theme_stylebox_override("panel", box)
	root.add_child(body)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	body.add_child(row)

	var text_col := VBoxContainer.new()
	text_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text_col.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	text_col.alignment = BoxContainer.ALIGNMENT_BEGIN
	text_col.add_theme_constant_override("separation", 3)
	row.add_child(text_col)

	var headline := Label.new()
	headline.text = _ProfileEventLog.format_headline(ev)
	headline.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	headline.add_theme_font_size_override("font_size", 13)
	headline.add_theme_color_override("font_color", _TEXT_MUTED)
	text_col.add_child(headline)

	const _TimeUtils = preload("res://logic/platform/time_utils.gd")
	var day_key := _TimeUtils.iso_date_only(str(ev.get("ts", "")))
	var song_path := str(ev.get("song_path", "")).replace("\\", "/").strip_edges()
	var day_on := bool(SettingsManager.get_setting("diary_history_open_day", false))
	var track_on := bool(SettingsManager.get_setting("diary_history_open_track", false)) \
		and song_path != ""

	# Keep text stack identical with/without track link — button was shifting the layout.
	var subtitle := _ProfileEventLog.format_subtitle(ev)
	if subtitle != "":
		var sub := Label.new()
		sub.text = subtitle
		sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		sub.add_theme_font_size_override("font_size", 17)
		sub.add_theme_color_override("font_color", _TEXT)
		text_col.add_child(sub)

	var detail := str(ev.get("detail", "")).strip_edges()
	if detail != "":
		var d := Label.new()
		d.text = detail
		d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		d.add_theme_font_size_override("font_size", 13)
		d.add_theme_color_override("font_color", _TEXT_MUTED)
		text_col.add_child(d)

	const _DiaryVoice = preload("res://logic/domain/profile/diary_voice.gd")
	var note := _DiaryVoice.memory_line(ev)
	if note != "":
		var n := Label.new()
		n.text = note
		n.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		n.add_theme_font_size_override("font_size", 12)
		n.add_theme_color_override("font_color", Color(0.55, 0.60, 0.68, 0.95))
		text_col.add_child(n)

	var badges: Array = ev.get("badges", []) if ev.get("badges", []) is Array else []
	if not badges.is_empty():
		var badges_row := HBoxContainer.new()
		badges_row.add_theme_constant_override("separation", 5)
		text_col.add_child(badges_row)
		const _MarathonRouteBadges = preload("res://logic/domain/session/marathon_route_badges.gd")
		for tier in _MarathonRouteBadges.TIER_ORDER:
			if str(tier) not in badges:
				continue
			var tint := _MarathonRouteBadges.tier_accent(str(tier))
			badges_row.add_child(_UiIconHelper.make_icon_frame(
				_MarathonRouteBadges.tier_icon_file(str(tier)), 30, 16, tint
			))

	var media := _make_feed_event_media(ev)
	if media:
		row.add_child(media)
		if track_on:
			# Click target must be the TextureRect — PanelContainer/host eat gui_input.
			var hit: Control = media.get_meta("feed_cover_hit", media) as Control
			if hit == null:
				hit = media
			_feed_cover_pass_clicks_to(media, hit)
			hit.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
			hit.tooltip_text = tr("PROFILE_HISTORY_OPEN_TRACK_TIP")
			_wire_feed_track_open(hit, song_path)

	if day_on and day_key.length() >= 10:
		var tip := tr("PROFILE_HISTORY_OPEN_DAY_TIP")
		body.tooltip_text = tip
		date_lbl.tooltip_text = tip
		body.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		date_col.mouse_filter = Control.MOUSE_FILTER_STOP
		date_col.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		_wire_feed_day_open(body, day_key)
		_wire_feed_day_open(date_col, day_key)
		_wire_feed_day_open(rail_col, day_key)
		rail_col.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		# Prefer track open on cover when both links are enabled.
		if media and not track_on:
			media.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
			_wire_feed_day_open(media, day_key)

	return root


func _wire_feed_track_open(ctrl: Control, song_path: String) -> void:
	if ctrl == null or song_path == "":
		return
	if ctrl.get_meta("feed_track_wired", false):
		return
	ctrl.set_meta("feed_track_wired", true)
	ctrl.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton \
				and event.pressed \
				and event.button_index == MOUSE_BUTTON_LEFT:
			_UiModifierSounds.play_select()
			_open_track_in_library(song_path)
			ctrl.accept_event()
	)


func _wire_feed_day_open(ctrl: Control, day_key: String) -> void:
	if ctrl == null or day_key == "":
		return
	ctrl.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton \
				and event.pressed \
				and event.button_index == MOUSE_BUTTON_LEFT:
			_open_day_in_calendar(day_key)
			accept_event()
	)


func _make_timeline_segment(color: Color) -> Control:
	var wrap := HBoxContainer.new()
	wrap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	wrap.size_flags_vertical = Control.SIZE_EXPAND_FILL
	wrap.add_theme_constant_override("separation", 0)
	var left := Control.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	wrap.add_child(left)
	var line := ColorRect.new()
	line.color = color
	line.custom_minimum_size = Vector2(3, 6)
	line.size_flags_vertical = Control.SIZE_EXPAND_FILL
	wrap.add_child(line)
	var right := Control.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	wrap.add_child(right)
	return wrap


func _feed_cover_pass_clicks_to(root: Node, cover: Control) -> void:
	## Containers / border overlays default to STOP and swallow cover clicks.
	if root == null or cover == null:
		return
	if root is Control and root != cover:
		(root as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
	for child in root.get_children():
		_feed_cover_pass_clicks_to(child, cover)
	cover.mouse_filter = Control.MOUSE_FILTER_STOP


func _make_feed_framed_texture(tex: Texture2D, size_px: int, accent: Color) -> Control:
	## Square media with UiFramedCover (same as Last Track / achievement icons).
	if tex == null:
		return null
	var frame := PanelContainer.new()
	frame.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var cover := TextureRect.new()
	cover.custom_minimum_size = Vector2(size_px, size_px)
	cover.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	cover.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	cover.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	cover.texture = tex
	frame.add_child(cover)
	var stroke := Color(accent.r, accent.g, accent.b, 0.72)
	_UiFramedCover.apply(
		frame,
		cover,
		8,
		2,
		stroke,
		Color(0.05, 0.06, 0.09, 1.0),
		float(size_px)
	)
	cover.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	frame.set_meta("feed_cover_hit", cover)
	return frame


func _make_feed_event_media(ev: Dictionary) -> Control:
	var song_path := str(ev.get("song_path", "")).strip_edges()
	const MEDIA := 76
	var accent: Color = _ProfileEventLog.tint_for_event(ev)
	if song_path != "":
		var cover := TextureRect.new()
		cover.custom_minimum_size = Vector2(MEDIA, MEDIA)
		cover.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		cover.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		_SongSelectUiStyles.apply_row_cover_texture(cover, song_path, MEDIA)
		var frame := PanelContainer.new()
		frame.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		frame.add_child(cover)
		_UiFramedCover.apply(
			frame,
			cover,
			8,
			2,
			Color(accent.r, accent.g, accent.b, 0.72),
			Color(0.05, 0.06, 0.09, 1.0),
			float(MEDIA)
		)
		cover.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		frame.set_meta("feed_cover_hit", cover)
		return frame
	var kind := str(ev.get("kind", ""))
	if kind == _ProfileEventLog.KIND_ACHIEVEMENT:
		var ach_id := -1
		var id_str := str(ev.get("id", ""))
		if id_str.begins_with("bf_ach_"):
			ach_id = int(id_str.substr(7))
		elif id_str.begins_with("ach_"):
			var rest := id_str.substr(4)
			var cut := rest.find("_")
			ach_id = int(rest.substr(0, cut)) if cut > 0 else int(rest)
		var category := ""
		if ach_id >= 0 and PlayerDataManager and PlayerDataManager.achievement_manager:
			var a = PlayerDataManager.achievement_manager.get_achievement_by_id(ach_id)
			if a is Dictionary:
				category = str(a.get("category", ""))
		const _AchievementsUtils = preload("res://logic/domain/profile/achievements_utils.gd")
		var tex: Texture2D = _AchievementsUtils.load_icon_texture_for_category(category)
		return _make_feed_framed_texture(tex, MEDIA, accent)
	if kind == _ProfileEventLog.KIND_MARATHON_MEDAL:
		var route_id := str(ev.get("route_id", ev.get("title_arg", ""))).strip_edges()
		var group_id := ""
		if route_id != "":
			const _Catalog = preload("res://logic/domain/session/marathon_route_catalog.gd")
			var tpl: Dictionary = _Catalog.template_for_route(route_id)
			group_id = str(tpl.get("genre_group_id", "")).strip_edges()
		const _GenreGroupIcons = preload("res://logic/domain/library/genre_group_icons.gd")
		var tint := _GenreGroupIcons.tint_for_group(group_id) if group_id != "" else accent
		if group_id != "":
			return _GenreGroupIcons.make_icon_frame_for_group(group_id, tint, MEDIA, 36, true)
		return _UiIconHelper.make_icon_frame("trophy.svg", MEDIA, 36, tint)
	if kind == _ProfileEventLog.KIND_GENRE_GROUP_FIRST \
			or kind == _ProfileEventLog.KIND_GENRE_GROUP_SS_FIRST:
		var group_from_id := str(ev.get("id", ""))
		if kind == _ProfileEventLog.KIND_GENRE_GROUP_FIRST:
			group_from_id = group_from_id.trim_prefix("ggroup_first_")
		else:
			group_from_id = group_from_id.trim_prefix("ss_ggroup_")
		const _GenreGroupIcons2 = preload("res://logic/domain/library/genre_group_icons.gd")
		var g_tint := _GenreGroupIcons2.tint_for_group(group_from_id)
		return _GenreGroupIcons2.make_icon_frame_for_group(group_from_id, g_tint, MEDIA, 36, true)
	return null


func _inner_section_style(border_tint: Color) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = Color(0.09, 0.11, 0.16, 0.98)
	box.border_color = Color(border_tint.r, border_tint.g, border_tint.b, 0.45)
	box.set_border_width_all(1)
	box.set_corner_radius_all(12)
	box.content_margin_left = 12.0
	box.content_margin_right = 12.0
	box.content_margin_top = 10.0
	box.content_margin_bottom = 12.0
	return box


func _make_filter_row() -> HBoxContainer:
	var row := HBoxContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("separation", 8)
	var filters := [
		[_ProfileEventLog.FILTER_ALL, "PROFILE_HISTORY_FILTER_ALL", "list-checks.svg", Color(0.72, 0.62, 0.95, 1.0)],
		[_ProfileEventLog.FILTER_MILESTONES, "PROFILE_HISTORY_FILTER_MILESTONES", "flag.svg", Color(0.72, 0.62, 0.95, 1.0)],
		[_ProfileEventLog.FILTER_ACHIEVEMENTS, "PROFILE_HISTORY_FILTER_ACHIEVEMENTS", "sparkles.svg", Color(0.55, 0.78, 0.98, 1.0)],
		[_ProfileEventLog.FILTER_RECORDS, "PROFILE_HISTORY_FILTER_RECORDS", "fingerprint-pattern.svg", Color(0.95, 0.70, 0.35, 1.0)],
		[_ProfileEventLog.FILTER_MODES, "PROFILE_HISTORY_FILTER_MODES", "layers.svg", Color(0.42, 0.88, 0.82, 1.0)],
	]
	var buttons: Array[Button] = []
	var group := ButtonGroup.new()
	group.allow_unpress = false
	for spec in filters:
		var fid := str(spec[0])
		var accent: Color = spec[3]
		var btn := Button.new()
		btn.text = tr(str(spec[1]))
		btn.toggle_mode = true
		btn.button_group = group
		btn.focus_mode = Control.FOCUS_NONE
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.custom_minimum_size = Vector2(0, 36)
		btn.theme_type_variation = &"CategoryKick"
		btn.set_meta("ui_variation_inactive", &"CategoryKick")
		btn.set_meta("ui_variation_active", &"ActiveKick")
		btn.set_meta("ui_icon_file", str(spec[2]))
		btn.set_meta("ui_accent_color", accent)
		btn.button_pressed = fid == _feed_filter
		btn.pressed.connect(func() -> void:
			if _feed_filter == fid:
				_UiCategoryButton.apply_selection(btn, true, 14, true, false)
				for key in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
					btn.add_theme_color_override(key, accent)
				btn.modulate = Color.WHITE
				return
			_feed_filter = fid
			_UiModifierSounds.play_select()
			refresh()
		)
		row.add_child(btn)
		buttons.append(btn)
	for btn in buttons:
		var active := btn.button_pressed
		var accent: Color = btn.get_meta("ui_accent_color")
		_UiCategoryButton.apply_selection(btn, active, 14, true, false)
		if active:
			for key in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
				btn.add_theme_color_override(key, accent)
			btn.modulate = Color.WHITE
	return row


# --- Capsules ---

func _past_capsule_keys() -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	if PlayerDataManager == null:
		return out
	var store: Dictionary = PlayerDataManager.get_time_capsules()
	for mk in _TimeCapsule.list_month_keys(store):
		var month_key := str(mk)
		if not _TimeCapsule.is_past_month(month_key):
			continue
		if PlayerDataManager.get_time_capsule(month_key).is_empty():
			continue
		out.append(month_key)
	return out


func _ensure_default_compare_keys() -> void:
	var keys := _past_capsule_keys()
	if _compare_left_key == COMPARE_NOW or not keys.has(_compare_left_key):
		_compare_left_key = str(keys[0]) if keys.size() > 0 else COMPARE_NOW
	if _compare_right_key != COMPARE_NOW and not keys.has(_compare_right_key):
		_compare_right_key = COMPARE_NOW
	if _compare_left_key == COMPARE_NOW and keys.size() > 0:
		_compare_left_key = str(keys[0])


func _rebuild_capsules_list() -> void:
	if _content_vbox == null:
		return
	_ensure_default_compare_keys()
	_content_vbox.add_theme_constant_override("separation", 12)
	var shell := PanelContainer.new()
	shell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	shell.add_theme_stylebox_override("panel", _inner_section_style(Color(_CAPSULE_ACCENT.r, _CAPSULE_ACCENT.g, _CAPSULE_ACCENT.b, 0.4)))
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 10)
	shell.add_child(col)
	_content_vbox.add_child(shell)

	var blurb := Label.new()
	blurb.text = tr("PROFILE_HISTORY_CAPSULES_BLURB")
	blurb.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	blurb.add_theme_font_size_override("font_size", 13)
	blurb.add_theme_color_override("font_color", _TEXT_MUTED)
	col.add_child(blurb)

	var keys := _past_capsule_keys()
	if keys.is_empty():
		var empty := Label.new()
		empty.text = tr("PROFILE_HISTORY_CAPSULES_EMPTY")
		empty.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		empty.add_theme_font_size_override("font_size", 14)
		empty.add_theme_color_override("font_color", _TEXT_MUTED)
		col.add_child(empty)
		return

	var shelf_title := Label.new()
	shelf_title.text = tr("PROFILE_HISTORY_CAPSULES_SHELF")
	shelf_title.add_theme_font_size_override("font_size", 15)
	shelf_title.add_theme_color_override("font_color", _TEXT)
	col.add_child(shelf_title)

	var shelf_scroll := ScrollContainer.new()
	shelf_scroll.custom_minimum_size = Vector2(0, 180)
	shelf_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	shelf_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	col.add_child(shelf_scroll)
	var shelf := HBoxContainer.new()
	shelf.add_theme_constant_override("separation", 10)
	shelf_scroll.add_child(shelf)
	for mk in keys:
		var capsule: Dictionary = PlayerDataManager.get_time_capsule(str(mk))
		shelf.add_child(_make_capsule_card(str(mk), capsule))

	col.add_child(_make_compare_picker())

	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 8)
	col.add_child(actions)

	var compare_btn := Button.new()
	compare_btn.text = tr("PROFILE_HISTORY_COMPARE")
	compare_btn.custom_minimum_size = Vector2(0, 40)
	compare_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	compare_btn.theme_type_variation = &"FlatPlayButton"
	compare_btn.focus_mode = Control.FOCUS_NONE
	_UiIconHelper.configure_button_icon(compare_btn, "chart-column.svg", _CAPSULE_ACCENT, 16)
	compare_btn.disabled = not _can_run_comparison()
	compare_btn.pressed.connect(func() -> void:
		_UiModifierSounds.play_select()
		if not _can_run_comparison():
			return
		_show_comparison = true
		refresh()
	)
	actions.add_child(compare_btn)

	var cal_btn := Button.new()
	cal_btn.text = tr("PROFILE_HISTORY_OPEN_CALENDAR_MONTH")
	cal_btn.custom_minimum_size = Vector2(0, 40)
	cal_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cal_btn.theme_type_variation = &"FlatBackButton"
	cal_btn.focus_mode = Control.FOCUS_NONE
	cal_btn.disabled = _compare_left_key == COMPARE_NOW
	cal_btn.pressed.connect(func() -> void:
		_open_month_in_calendar(_compare_left_key)
	)
	actions.add_child(cal_btn)


func _make_capsule_card(month_key: String, capsule: Dictionary) -> PanelContainer:
	var selected := month_key == _compare_left_key or month_key == _compare_right_key
	var genre := str(capsule.get("favorite_genre", ""))
	var accent := _CAPSULE_ACCENT
	if genre != "" and genre != "unknown":
		accent = _GenreGroupIcons.tint_for_genre(genre)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(168, 168)
	var box := StyleBoxFlat.new()
	# Keep cards quiet: dark shell, thin accent edge only.
	box.bg_color = Color(0.08, 0.09, 0.13, 0.97).lerp(Color(accent.r, accent.g, accent.b, 1.0), 0.06)
	box.border_color = Color(accent.r, accent.g, accent.b, 0.7 if selected else 0.2)
	box.set_border_width_all(2 if selected else 1)
	box.set_corner_radius_all(14)
	box.content_margin_left = 12.0
	box.content_margin_right = 12.0
	box.content_margin_top = 12.0
	box.content_margin_bottom = 12.0
	panel.add_theme_stylebox_override("panel", box)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 6)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(col)
	var title := Label.new()
	var title_text := _PlayerEvolution.month_title(month_key)
	if bool(capsule.get("demo", false)):
		title_text = "%s · %s" % [title_text, tr("PROFILE_HISTORY_CAPSULE_DEMO_TAG")]
	title.text = title_text
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title.add_theme_font_size_override("font_size", 15)
	title.add_theme_color_override("font_color", _TEXT)
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(title)
	var meta := Label.new()
	meta.text = tr("PROFILE_HISTORY_CAPSULE_META_FMT") % [
		int(capsule.get("level", 1)),
		int(capsule.get("total_rr", 0)),
	]
	meta.add_theme_font_size_override("font_size", 12)
	meta.add_theme_color_override("font_color", _TEXT_MUTED)
	meta.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(meta)
	col.add_child(_make_capsule_grade_row(capsule))
	var tip := Label.new()
	tip.text = tr("PROFILE_HISTORY_SELECT_MONTH")
	tip.add_theme_font_size_override("font_size", 10)
	tip.add_theme_color_override("font_color", Color(accent.r, accent.g, accent.b, 0.75))
	tip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(tip)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			_UiModifierSounds.play_select()
			_assign_compare_key(month_key)
			refresh()
			panel.accept_event()
	)
	return panel


func _make_capsule_grade_row(capsule: Dictionary) -> HBoxContainer:
	# Same placement as hardest-chart extreme: zap icon, then the rating/letter.
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var letter := _TimeCapsule.average_grade_letter(capsule.get("grades", {}))
	var tint := _GradeDisplay.grade_color(letter) if letter != "" else Color(0.55, 0.58, 0.65, 0.55)
	var frame := _UiIconHelper.make_icon_frame("zap.svg", 24, 14, tint)
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(frame)
	var grade_lbl := Label.new()
	grade_lbl.text = letter if letter != "" else "—"
	grade_lbl.add_theme_font_size_override("font_size", 18)
	grade_lbl.add_theme_color_override("font_color", tint)
	grade_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(grade_lbl)
	return row


func _assign_compare_key(month_key: String) -> void:
	if _pick_slot == "right":
		_compare_right_key = month_key
		_pick_slot = "left"
	else:
		_compare_left_key = month_key
		_pick_slot = "right"
	if _compare_left_key == _compare_right_key and _compare_right_key != COMPARE_NOW:
		_compare_right_key = COMPARE_NOW


func _make_compare_picker() -> PanelContainer:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel", _card_style())
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 8)
	panel.add_child(col)
	var head := Label.new()
	head.text = tr("PROFILE_HISTORY_COMPARE")
	head.add_theme_font_size_override("font_size", 14)
	head.add_theme_color_override("font_color", _TEXT)
	col.add_child(head)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	col.add_child(row)
	row.add_child(_make_slot_button("left", _compare_left_key))
	var arrow := Label.new()
	arrow.text = "↔"
	arrow.add_theme_font_size_override("font_size", 18)
	arrow.add_theme_color_override("font_color", _CAPSULE_ACCENT)
	row.add_child(arrow)
	row.add_child(_make_slot_button("right", _compare_right_key))
	var hint := Label.new()
	hint.text = tr("PROFILE_HISTORY_COMPARE_HINT")
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.add_theme_font_size_override("font_size", 11)
	hint.add_theme_color_override("font_color", _TEXT_MUTED)
	col.add_child(hint)
	return panel


func _make_slot_button(slot: String, key: String) -> Button:
	var btn := Button.new()
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn.custom_minimum_size = Vector2(0, 44)
	btn.focus_mode = Control.FOCUS_NONE
	btn.theme_type_variation = &"FlatPlayButton"
	btn.text = _slot_label(key)
	btn.pressed.connect(func() -> void:
		_UiModifierSounds.play_select()
		_pick_slot = slot
		if slot == "right" and key != COMPARE_NOW:
			# Toggle right slot back to Now on second tap of filled slot.
			_compare_right_key = COMPARE_NOW
			refresh()
		elif slot == "left":
			_pick_slot = "left"
		else:
			_pick_slot = "right"
	)
	return btn


func _slot_label(key: String) -> String:
	if key == COMPARE_NOW:
		return tr("PROFILE_HISTORY_COMPARE_NOW")
	return _PlayerEvolution.month_title(key)


func _can_run_comparison() -> bool:
	if _compare_left_key == COMPARE_NOW:
		return false
	if _compare_left_key == _compare_right_key:
		return false
	if PlayerDataManager == null:
		return false
	return not PlayerDataManager.get_time_capsule(_compare_left_key).is_empty()


func _snapshot_for_key(key: String) -> Dictionary:
	if key == COMPARE_NOW:
		var pdata: Dictionary = PlayerDataManager.data if PlayerDataManager else {}
		return _PlayerEvolution.build_now_snapshot(pdata)
	if PlayerDataManager == null:
		return {}
	return PlayerDataManager.get_time_capsule(key)


func _rebuild_comparison_panel() -> void:
	if _content_vbox == null or PlayerDataManager == null:
		return
	_content_vbox.add_theme_constant_override("separation", 6)
	var left := _snapshot_for_key(_compare_left_key)
	var right := _snapshot_for_key(_compare_right_key)
	if left.is_empty() or right.is_empty():
		_show_comparison = false
		_rebuild_capsules_list()
		return

	var header := PanelContainer.new()
	header.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var box := StyleBoxFlat.new()
	box.bg_color = Color(_CAPSULE_ACCENT.r, _CAPSULE_ACCENT.g, _CAPSULE_ACCENT.b, 0.14)
	box.border_color = Color(_CAPSULE_ACCENT.r, _CAPSULE_ACCENT.g, _CAPSULE_ACCENT.b, 0.45)
	box.set_border_width_all(1)
	box.set_corner_radius_all(10)
	box.content_margin_left = 12.0
	box.content_margin_right = 12.0
	box.content_margin_top = 10.0
	box.content_margin_bottom = 10.0
	header.add_theme_stylebox_override("panel", box)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 4)
	header.add_child(col)
	var title := Label.new()
	title.text = tr("PROFILE_HISTORY_COMPARE_TITLE") % [
		_slot_label(_compare_left_key),
		_slot_label(_compare_right_key),
	]
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title.add_theme_font_size_override("font_size", 16)
	title.add_theme_color_override("font_color", Color(0.98, 0.86, 0.92, 1.0))
	col.add_child(title)
	var blurb := Label.new()
	blurb.text = tr("PROFILE_HISTORY_COMPARE_BLURB")
	blurb.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	blurb.add_theme_font_size_override("font_size", 12)
	blurb.add_theme_color_override("font_color", _TEXT_MUTED)
	col.add_child(blurb)
	if bool(left.get("demo", false)) or bool(right.get("demo", false)):
		var demo_note := Label.new()
		demo_note.text = tr("PLAYER_EVOLUTION_DEMO_NOTE")
		demo_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		demo_note.add_theme_font_size_override("font_size", 11)
		demo_note.add_theme_color_override("font_color", Color(0.86, 0.72, 0.42, 0.95))
		col.add_child(demo_note)
	_content_vbox.add_child(header)

	var back_btn := Button.new()
	back_btn.text = tr("PROFILE_HISTORY_CAPSULES_BACK")
	back_btn.custom_minimum_size = Vector2(0, 36)
	back_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	back_btn.theme_type_variation = &"FlatBackButton"
	back_btn.focus_mode = Control.FOCUS_NONE
	back_btn.pressed.connect(func() -> void:
		_UiModifierSounds.play_select()
		_show_comparison = false
		refresh()
	)
	_content_vbox.add_child(back_btn)

	var legend := Label.new()
	legend.text = "%s → %s" % [_slot_label(_compare_left_key), _slot_label(_compare_right_key)]
	legend.add_theme_font_size_override("font_size", 12)
	legend.add_theme_color_override("font_color", _TEXT_MUTED)
	_content_vbox.add_child(legend)

	for row in _PlayerEvolution.build_comparison_snapshots(left, right):
		if row is Dictionary:
			_content_vbox.add_child(_make_evolution_row(row as Dictionary))

	if _compare_left_key != COMPARE_NOW:
		var cal_btn := Button.new()
		cal_btn.text = tr("PROFILE_HISTORY_OPEN_CALENDAR_MONTH")
		cal_btn.custom_minimum_size = Vector2(0, 38)
		cal_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		cal_btn.theme_type_variation = &"FlatBackButton"
		cal_btn.focus_mode = Control.FOCUS_NONE
		cal_btn.pressed.connect(func() -> void:
			_open_month_in_calendar(_compare_left_key)
		)
		_content_vbox.add_child(cal_btn)


func _open_month_in_calendar(month_key: String) -> void:
	var host := _profile_host()
	if host == null:
		return
	if host.has_method("open_activity_calendar_month"):
		host.open_activity_calendar_month(month_key)
	elif host.has_method("open_activity_calendar"):
		close()
		host.open_activity_calendar()


func _open_day_in_calendar(date_iso: String) -> void:
	if not bool(SettingsManager.get_setting("diary_history_open_day", false)):
		return
	var host := _profile_host()
	if host == null:
		return
	if host.has_method("open_activity_calendar_day"):
		host.open_activity_calendar_day(date_iso)
	elif host.has_method("open_activity_calendar"):
		_close(false)
		host.open_activity_calendar()


func _open_track_in_library(song_path: String) -> void:
	if not bool(SettingsManager.get_setting("diary_history_open_track", false)):
		return
	var host := _profile_host()
	if host == null:
		return
	if host.has_method("open_library_song"):
		host.open_library_song(song_path)


func _make_evolution_row(row: Dictionary) -> PanelContainer:
	var hint := str(row.get("tint_hint", ""))
	var then_text := str(row.get("then_text", "—"))
	var now_text := str(row.get("now_text", "—"))
	var delta := str(row.get("delta_text", "")).strip_edges()
	var icon := str(row.get("icon", "sparkles.svg")).strip_edges()
	if icon == "":
		icon = "sparkles.svg"
	var numeric := bool(row.get("numeric", false))
	var then_v := float(row.get("then_value", 0.0))
	var now_v := float(row.get("now_value", 0.0))

	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var style := StyleBoxFlat.new()
	style.bg_color = _STAT_ROW_BG
	style.set_corner_radius_all(8)
	style.content_margin_left = 12.0
	style.content_margin_right = 12.0
	style.content_margin_top = 10.0
	style.content_margin_bottom = 10.0
	panel.add_theme_stylebox_override("panel", style)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 6)
	panel.add_child(col)

	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 8)
	col.add_child(head)
	head.add_child(_UiIconHelper.make_icon_frame(icon, 28, 16, _evolution_icon_tint(icon)))
	var cap := Label.new()
	cap.text = tr(str(row.get("caption_key", "")))
	cap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cap.add_theme_font_size_override("font_size", 14)
	cap.add_theme_color_override("font_color", _TEXT_MUTED)
	head.add_child(cap)
	if delta != "" and delta != "→":
		var delta_lbl := Label.new()
		delta_lbl.text = delta
		delta_lbl.add_theme_font_size_override("font_size", 14)
		var delta_color := _TEXT_MUTED
		match hint:
			"up":
				delta_color = _STAT_ICON_CLEARS
			"down":
				delta_color = _STAT_ICON_FAILS
			"changed":
				delta_color = Color(0.86, 0.80, 0.98, 1.0)
		delta_lbl.add_theme_color_override("font_color", delta_color)
		head.add_child(delta_lbl)

	var vals := HBoxContainer.new()
	vals.add_theme_constant_override("separation", 10)
	col.add_child(vals)
	var then_lbl := Label.new()
	then_lbl.text = then_text
	then_lbl.custom_minimum_size = Vector2(84, 0)
	then_lbl.add_theme_font_size_override("font_size", 16)
	then_lbl.add_theme_color_override("font_color", _TEXT_MUTED)
	vals.add_child(then_lbl)

	var bar_host := Control.new()
	bar_host.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar_host.custom_minimum_size = Vector2(48, 14)
	vals.add_child(bar_host)
	if numeric:
		var scale_max := maxf(maxf(then_v, now_v), 1.0)
		var bg := ColorRect.new()
		bg.color = Color(0.16, 0.18, 0.24, 1.0)
		bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		bg.offset_top = 3
		bg.offset_bottom = -3
		bar_host.add_child(bg)
		var fill := ColorRect.new()
		fill.color = Color(_CAPSULE_ACCENT.r, _CAPSULE_ACCENT.g, _CAPSULE_ACCENT.b, 0.75)
		fill.set_anchors_preset(Control.PRESET_LEFT_WIDE)
		fill.anchor_right = clampf(now_v / scale_max, 0.0, 1.0)
		fill.offset_top = 3
		fill.offset_bottom = -3
		fill.offset_left = 0
		fill.offset_right = 0
		bar_host.add_child(fill)
		# Marker for "then" so the bar reads as progress between snapshots.
		if then_v > 0.0 and absf(then_v - now_v) > 0.001:
			var mark := ColorRect.new()
			mark.color = Color(0.92, 0.94, 0.98, 0.85)
			mark.custom_minimum_size = Vector2(2, 14)
			mark.set_anchors_preset(Control.PRESET_LEFT_WIDE)
			mark.anchor_left = clampf(then_v / scale_max, 0.0, 1.0)
			mark.anchor_right = mark.anchor_left
			mark.offset_left = -1
			mark.offset_right = 1
			mark.offset_top = 0
			mark.offset_bottom = 0
			bar_host.add_child(mark)
	else:
		var dash := ColorRect.new()
		dash.color = Color(_CAPSULE_ACCENT.r, _CAPSULE_ACCENT.g, _CAPSULE_ACCENT.b, 0.28 if hint == "changed" else 0.12)
		dash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		dash.offset_top = 5
		dash.offset_bottom = -5
		bar_host.add_child(dash)

	var now_lbl := Label.new()
	now_lbl.text = now_text
	now_lbl.custom_minimum_size = Vector2(84, 0)
	now_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	now_lbl.add_theme_font_size_override("font_size", 16)
	now_lbl.add_theme_color_override("font_color", _TEXT)
	vals.add_child(now_lbl)
	return panel


func _evolution_icon_tint(icon_file: String) -> Color:
	match icon_file:
		"chart-column.svg":
			return Color(0.72, 0.58, 0.95, 1.0)
		"fingerprint-pattern.svg":
			return Color(0.75, 0.52, 0.98, 1.0)
		"target.svg":
			return _STAT_ICON_SCORE
		"calendar.svg":
			return _STAT_ICON_TRACKS
		"trophy.svg":
			return _STAT_ICON_GRADE
		"headphones.svg":
			return Color(0.86, 0.72, 0.98, 1.0)
		"circle-play.svg", "music.svg":
			return _STAT_ICON_TRACKS
		"zap.svg":
			return _STAT_ICON_GRADE
		_:
			return Color(0.72, 0.62, 0.95, 1.0)


func _make_stat_row(icon_file: String, icon_tint: Color, caption: String, value: String, value_color: Color = _TEXT) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var style := StyleBoxFlat.new()
	style.bg_color = _STAT_ROW_BG
	style.set_corner_radius_all(8)
	style.content_margin_left = 10.0
	style.content_margin_right = 10.0
	style.content_margin_top = 8.0
	style.content_margin_bottom = 8.0
	panel.add_theme_stylebox_override("panel", style)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	panel.add_child(row)
	row.add_child(_UiIconHelper.make_icon_frame(icon_file, 28, 16, icon_tint))
	var cap := Label.new()
	cap.text = caption
	cap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cap.add_theme_font_size_override("font_size", 13)
	cap.add_theme_color_override("font_color", _TEXT_MUTED)
	row.add_child(cap)
	var val := Label.new()
	val.text = value
	val.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	val.add_theme_font_size_override("font_size", 13)
	val.add_theme_color_override("font_color", value_color)
	row.add_child(val)
	return panel
