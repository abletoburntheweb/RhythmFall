# scenes/generation/generation_queue_dialog.gd
extends Control
class_name GenerationQueueDialog

signal closed()

const _UiIconHelper = preload("res://logic/ui/ui_icon_helper.gd")
const _UiModifierSounds = preload("res://logic/ui/ui_modifier_sounds.gd")
const _SongSelectUiStyles = preload("res://scenes/song_select/lib/song_select_ui_styles.gd")
const _TimeUtils = preload("res://logic/platform/time_utils.gd")
const _NotesUtils = preload("res://logic/domain/rhythm/notes_utils.gd")
const _SongSelectStrings = preload("res://logic/domain/library/song_select_strings.gd")
const _GoalDiff = preload("res://logic/domain/generation/generation_goal_difficulty.gd")

const HISTORY_VISIBLE_ROWS := 5
const HISTORY_ROW_HEIGHT := 26
const HISTORY_SCROLL_HEIGHT := HISTORY_VISIBLE_ROWS * HISTORY_ROW_HEIGHT + 6

var _service: GenerationService = null
var _summary_label: Label
var _footer_label: Label
var _list_vbox: VBoxContainer
var _history_vbox: VBoxContainer
var _history_section: VBoxContainer
var _history_scroll: ScrollContainer
var _empty_label: Label
var _back_button: Button
var _close_button: Button
var _clear_queue_button: Button
var _offline_banner: PanelContainer
var _offline_label: Label
var _offline_retry_button: Button
var _collapsed_groups: Dictionary = {}
var _queue_refresh_scheduled := false
var _last_queue_layout_key := ""
var _detail_song_path: String = ""
var _detail_instrument: String = "drums"
var _detail_lanes: int = 4
var _intents_cache: Dictionary = {}


func _ready() -> void:
	add_to_group("locale_refresh")
	UiIconHelper.configure_modal_overlay(self, 110)
	_build_ui()
	apply_locale()
	call_deferred("_bind_service")


func _bind_service() -> void:
	var engine := get_tree().root.get_node_or_null("GameEngine")
	if engine and engine.has_method("get_background_service"):
		_service = engine.get_background_service()
	if _service:
		if not _service.queue_changed.is_connected(_on_queue_changed):
			_service.queue_changed.connect(_on_queue_changed)
		if not _service.bpm_progress.is_connected(_on_progress_tick):
			_service.bpm_progress.connect(_on_progress_tick)
		if not _service.notes_progress.is_connected(_on_progress_tick):
			_service.notes_progress.connect(_on_progress_tick)
	refresh()


func _build_ui() -> void:
	var bg := ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.02, 0.03, 0.06, 0.97)
	bg.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(bg)

	var center := MarginContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.add_theme_constant_override("margin_left", 32)
	center.add_theme_constant_override("margin_right", 32)
	center.add_theme_constant_override("margin_top", 28)
	center.add_theme_constant_override("margin_bottom", 28)
	add_child(center)

	var card := PanelContainer.new()
	var vp := get_viewport_rect().size
	card.custom_minimum_size = Vector2(minf(860.0, vp.x - 64.0), minf(680.0, vp.y - 56.0))
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.size_flags_vertical = Control.SIZE_EXPAND_FILL
	card.add_theme_stylebox_override("panel", _SongSelectUiStyles.card_panel_style())
	center.add_child(card)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 22)
	margin.add_theme_constant_override("margin_right", 22)
	margin.add_theme_constant_override("margin_top", 18)
	margin.add_theme_constant_override("margin_bottom", 18)
	card.add_child(margin)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 14)
	margin.add_child(root)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 12)
	root.add_child(header)

	_back_button = Button.new()
	_back_button.text = tr("BTN_BACK")
	_back_button.pressed.connect(_on_close_pressed)
	UiIconHelper.apply_standard_back_button(_back_button)
	header.add_child(_back_button)

	var title := Label.new()
	title.text = tr("GEN_QUEUE_DIALOG_TITLE")
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", Color(0.94, 0.96, 0.99, 1.0))
	header.add_child(title)

	var header_spacer := Control.new()
	header_spacer.custom_minimum_size = _back_button.custom_minimum_size
	header_spacer.size_flags_horizontal = Control.SIZE_SHRINK_END
	header.add_child(header_spacer)

	var summary_row := HBoxContainer.new()
	summary_row.add_theme_constant_override("separation", 12)
	root.add_child(summary_row)

	_summary_label = Label.new()
	_summary_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_summary_label.add_theme_font_size_override("font_size", 14)
	_summary_label.add_theme_color_override("font_color", Color(0.68, 0.76, 0.88, 1.0))
	summary_row.add_child(_summary_label)

	_clear_queue_button = Button.new()
	_clear_queue_button.text = tr("GEN_QUEUE_BTN_CLEAR")
	_clear_queue_button.theme_type_variation = &"FlatButton"
	_clear_queue_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_clear_queue_button.pressed.connect(_on_clear_queue_pressed)
	summary_row.add_child(_clear_queue_button)

	var modes_hint := Label.new()
	modes_hint.text = tr("GEN_QUEUE_SONG_MODES_HINT")
	modes_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	modes_hint.add_theme_font_size_override("font_size", 12)
	modes_hint.add_theme_color_override("font_color", Color(0.56, 0.64, 0.76, 0.95))
	root.add_child(modes_hint)

	_offline_banner = _new_row_panel()
	_offline_banner.visible = false
	var offline_outer := VBoxContainer.new()
	offline_outer.add_theme_constant_override("separation", 8)
	_offline_banner.add_child(offline_outer)
	var offline_style := _offline_banner.get_theme_stylebox("panel") as StyleBoxFlat
	if offline_style:
		offline_style.bg_color = Color(0.22, 0.08, 0.08, 0.96)
		offline_style.border_color = Color(0.95, 0.45, 0.38, 0.55)
	_offline_label = Label.new()
	_offline_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_offline_label.add_theme_font_size_override("font_size", 13)
	_offline_label.add_theme_color_override("font_color", Color(0.98, 0.82, 0.76, 1.0))
	offline_outer.add_child(_offline_label)
	var offline_actions := HBoxContainer.new()
	offline_actions.alignment = BoxContainer.ALIGNMENT_END
	offline_outer.add_child(offline_actions)
	_offline_retry_button = Button.new()
	_offline_retry_button.text = tr("GEN_QUEUE_OFFLINE_RETRY")
	_offline_retry_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_offline_retry_button.pressed.connect(_on_offline_retry_pressed)
	offline_actions.add_child(_offline_retry_button)
	root.add_child(_offline_banner)

	var body := VBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 12)
	root.add_child(body)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.custom_minimum_size = Vector2(0, 220)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	body.add_child(scroll)

	_list_vbox = VBoxContainer.new()
	_list_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list_vbox.add_theme_constant_override("separation", 10)
	scroll.add_child(_list_vbox)

	_empty_label = Label.new()
	_empty_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_empty_label.add_theme_color_override("font_color", Color(0.62, 0.68, 0.78, 1.0))
	_list_vbox.add_child(_empty_label)

	_history_section = VBoxContainer.new()
	_history_section.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	_history_section.custom_minimum_size = Vector2(0, HISTORY_SCROLL_HEIGHT + 28)
	body.add_child(_history_section)

	var history_title := Label.new()
	history_title.text = tr("GEN_QUEUE_HISTORY_TITLE")
	history_title.add_theme_font_size_override("font_size", 13)
	history_title.add_theme_color_override("font_color", Color(0.72, 0.78, 0.88, 1.0))
	_history_section.add_child(history_title)

	_history_scroll = ScrollContainer.new()
	_history_scroll.custom_minimum_size = Vector2(0, HISTORY_SCROLL_HEIGHT)
	_history_scroll.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	_history_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_history_section.add_child(_history_scroll)

	_history_vbox = VBoxContainer.new()
	_history_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_history_vbox.add_theme_constant_override("separation", 4)
	_history_scroll.add_child(_history_vbox)

	_footer_label = Label.new()
	_footer_label.add_theme_font_size_override("font_size", 12)
	_footer_label.add_theme_color_override("font_color", Color(0.58, 0.66, 0.76, 1.0))
	root.add_child(_footer_label)

	var footer_row := HBoxContainer.new()
	footer_row.alignment = BoxContainer.ALIGNMENT_END
	root.add_child(footer_row)

	_close_button = Button.new()
	_close_button.text = tr("GEN_QUEUE_BTN_CLOSE")
	_close_button.theme_type_variation = &"FlatButton"
	_close_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_close_button.pressed.connect(_on_close_pressed)
	footer_row.add_child(_close_button)


func apply_locale() -> void:
	if _back_button:
		_back_button.text = tr("BTN_BACK")
	if _close_button:
		_close_button.text = tr("GEN_QUEUE_BTN_CLOSE")
	if _clear_queue_button:
		_clear_queue_button.text = tr("GEN_QUEUE_BTN_CLEAR")
		_clear_queue_button.tooltip_text = tr("GEN_QUEUE_BTN_CLEAR_TOOLTIP")
	refresh()


func refresh() -> void:
	if _service == null or _list_vbox == null:
		return
	_intents_cache.clear()
	_last_queue_layout_key = ""
	var snapshot: Dictionary = _service.get_queue_snapshot()
	_render_snapshot(snapshot)


func _queue_layout_key(snapshot: Dictionary) -> String:
	var parts: Array[String] = []
	for item in snapshot.get("items", []):
		if item is Dictionary:
			var d := item as Dictionary
			parts.append("%s:%s:%s" % [
				str(d.get("id", "")),
				str(d.get("state", "")),
				str(d.get("kind", "")),
			])
	for entry in snapshot.get("history", []):
		if entry is Dictionary:
			var h := entry as Dictionary
			parts.append("h:%s:%s" % [str(h.get("id", "")), str(h.get("status", ""))])
	parts.append("empty:%s" % str(snapshot.get("items", []).is_empty()))
	parts.append("off:%s" % str(snapshot.get("offline_paused", false)))
	return "|".join(parts)


func _apply_snapshot_chrome(snapshot: Dictionary) -> void:
	var items: Array = snapshot.get("items", [])
	var counts: Dictionary = snapshot.get("counts", {})
	var active_count := int(counts.get("active", 0))
	var waiting_count := int(counts.get("waiting", 0))

	if _summary_label:
		var summary_parts: Array[String] = [
			tr("GEN_QUEUE_DIALOG_SUMMARY_FMT") % [active_count, waiting_count],
		]
		var eta_sec := int(snapshot.get("eta_sec_remaining", 0))
		if eta_sec > 0:
			var eta_min := maxi(1, int(round(float(eta_sec) / 60.0)))
			summary_parts.append(tr("GEN_QUEUE_ETA_FMT") % eta_min)
		_summary_label.text = " · ".join(summary_parts)

	if _clear_queue_button:
		var has_work := active_count > 0 or waiting_count > 0 or bool(snapshot.get("offline_paused", false))
		_clear_queue_button.disabled = not has_work

	if _offline_banner:
		var offline := bool(snapshot.get("offline_paused", false))
		_offline_banner.visible = offline
		if offline and _offline_label:
			var msg := str(snapshot.get("offline_message", "")).strip_edges()
			if msg == "":
				msg = tr("GEN_WORKER_START_FAILED")
			_offline_label.text = tr("GEN_QUEUE_OFFLINE_BANNER") % msg
		if _offline_retry_button:
			_offline_retry_button.text = tr("GEN_QUEUE_OFFLINE_RETRY")

	if items.is_empty():
		_empty_label.visible = true
		_empty_label.text = tr("GEN_QUEUE_EMPTY")
	else:
		_empty_label.visible = false

	if _footer_label:
		var footer_parts: Array[String] = []
		if bool(snapshot.get("delay_active", false)):
			var sec := int(round(float(snapshot.get("delay_sec_remaining", 0.0))))
			if sec <= 0:
				sec = int(round(float(snapshot.get("delay_sec_default", 5.0))))
			footer_parts.append(tr("GEN_QUEUE_NEXT_IN_FMT") % sec)
		_footer_label.text = " · ".join(footer_parts)
		_footer_label.visible = not footer_parts.is_empty()


func _apply_snapshot_progress(snapshot: Dictionary) -> void:
	for item in snapshot.get("items", []):
		if not item is Dictionary:
			continue
		var d := item as Dictionary
		var item_id := str(d.get("id", ""))
		if item_id == "":
			continue
		var row := _list_vbox.get_node_or_null("Row_%s" % item_id)
		if row:
			_update_row_progress(row, d.get("progress", {}) as Dictionary)


func _render_snapshot(snapshot: Dictionary) -> void:
	for child in _list_vbox.get_children():
		if child != _empty_label:
			child.queue_free()

	var items: Array = snapshot.get("items", [])
	_apply_snapshot_chrome(snapshot)

	if not items.is_empty():
		for entry in _build_grouped_entries(items):
			if entry is Dictionary:
				_render_entry(entry as Dictionary)

	_render_history(snapshot.get("history", []))


func _build_grouped_entries(items: Array) -> Array:
	var result: Array = []
	var i := 0
	while i < items.size():
		var item: Dictionary = items[i]
		if str(item.get("kind", "")) == "notes":
			var path_key := str(item.get("path", ""))
			var batch: Array = [item]
			var j := i + 1
			while j < items.size():
				var next: Dictionary = items[j]
				if str(next.get("kind", "")) != "notes":
					break
				if str(next.get("path", "")) != path_key:
					break
				batch.append(next)
				j += 1
			if batch.size() >= 2:
				result.append({
					"type": "group",
					"path": path_key,
					"display": str(item.get("display", "")),
					"children": batch,
				})
				i = j
				continue
		result.append({"type": "row", "item": item})
		i += 1
	return result


func _toggle_group_collapse(group_key: String, default_collapsed: bool) -> void:
	var collapsed := bool(_collapsed_groups.get(group_key, default_collapsed))
	_collapsed_groups[group_key] = not collapsed
	refresh()


func _toggle_song_detail(song_path: String, instrument: String, lanes: int) -> void:
	var key := song_path.strip_edges()
	if key == "":
		return
	if _detail_song_path == key:
		_detail_song_path = ""
	else:
		_detail_song_path = key
		_detail_instrument = instrument if instrument != "" else "drums"
		_detail_lanes = maxi(3, lanes)
	_sync_detail_panels()


func _song_node_key(song_path: String) -> String:
	return String(song_path).replace("\\", "/").md5_text()


func _sync_detail_panels() -> void:
	if _list_vbox == null:
		return
	for child in _list_vbox.get_children():
		if child == _empty_label:
			continue
		var detail := child.get_node_or_null("SongModesDetail")
		if detail:
			detail.queue_free()
	if _detail_song_path == "":
		return
	var anchor_name := "SongWrap_%s" % _song_node_key(_detail_song_path)
	var anchor := _list_vbox.get_node_or_null(anchor_name)
	if anchor == null:
		refresh()
		return
	var panel := _make_song_modes_panel(_detail_song_path, _detail_instrument, _detail_lanes)
	panel.name = "SongModesDetail"
	anchor.add_child(panel)


func _wire_song_row_open(panel: PanelContainer, song_path: String, instrument: String, lanes: int) -> void:
	if panel == null or song_path.strip_edges() == "":
		return
	if bool(panel.get_meta("song_open_wired", false)):
		return
	panel.set_meta("song_open_wired", true)
	panel.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	panel.gui_input.connect(_on_song_row_panel_gui_input.bind(song_path, instrument, lanes))


func _on_song_row_panel_gui_input(
	event: InputEvent,
	song_path: String,
	instrument: String,
	lanes: int,
) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_toggle_song_detail(song_path, instrument, lanes)
		get_viewport().set_input_as_handled()


func _render_entry(entry: Dictionary) -> void:
	if str(entry.get("type", "")) == "group":
		_list_vbox.add_child(_make_group_row(entry))
	else:
		_list_vbox.add_child(_wrap_row_with_detail(entry.get("item", {}) as Dictionary, 0))
	if _detail_song_path != "":
		call_deferred("_sync_detail_panels")


func _group_collapse_key(entry: Dictionary) -> String:
	return "notes:%s" % str(entry.get("path", ""))


func _make_group_row(entry: Dictionary) -> Control:
	var children: Array = entry.get("children", [])
	var group_key := _group_collapse_key(entry)
	var song_path := str(entry.get("path", "")).strip_edges()
	var first_child: Dictionary = children[0] if children.size() > 0 and children[0] is Dictionary else {}
	var group_has_active := false
	for probe in children:
		if probe is Dictionary and str((probe as Dictionary).get("state", "")) == "active":
			group_has_active = true
			break
	# Collapsed by default; keep the group with an active task open so progress stays visible.
	var default_collapsed := not group_has_active
	var collapsed: bool = bool(_collapsed_groups.get(group_key, default_collapsed))

	var outer_wrap := VBoxContainer.new()
	outer_wrap.add_theme_constant_override("separation", 6)
	if song_path != "":
		outer_wrap.name = "SongWrap_%s" % _song_node_key(song_path)

	var panel := _new_row_panel()
	var outer := VBoxContainer.new()
	outer.add_theme_constant_override("separation", 6)
	panel.add_child(outer)
	outer_wrap.add_child(panel)

	var header := HBoxContainer.new()
	header.mouse_filter = Control.MOUSE_FILTER_STOP
	header.add_theme_constant_override("separation", 8)
	outer.add_child(header)

	var toggle := Button.new()
	toggle.text = "▸" if collapsed else "▾"
	toggle.flat = true
	toggle.custom_minimum_size = Vector2(28, 28)
	toggle.focus_mode = Control.FOCUS_NONE
	toggle.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	toggle.pressed.connect(_toggle_group_collapse.bind(group_key, default_collapsed))
	header.add_child(toggle)

	var has_active := false
	var active_settings := ""
	for child_item in children:
		if child_item is Dictionary and str((child_item as Dictionary).get("state", "")) == "active":
			has_active = true
			active_settings = str((child_item as Dictionary).get("settings_line", "")).strip_edges()
			break
	header.add_child(_make_kind_icon("notes", has_active))

	var title := Label.new()
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.text = "%s %s" % [
		str(entry.get("display", "")),
		tr("GEN_QUEUE_GROUP_COUNT_FMT") % children.size(),
	]
	if active_settings != "":
		title.text = "%s · %s" % [title.text, active_settings]
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title.add_theme_font_size_override("font_size", 15)
	title.add_theme_color_override("font_color", Color(0.92, 0.95, 0.98, 1.0))
	header.add_child(title)

	if song_path != "":
		_wire_song_row_open(
			panel,
			song_path,
			str(first_child.get("instrument", "drums")),
			int(first_child.get("lanes", 4)),
		)

	if not collapsed:
		for child_item in children:
			if child_item is Dictionary:
				var child_dict := child_item as Dictionary
				var child_state := str(child_dict.get("state", ""))
				outer.add_child(_make_row(child_dict, 16, child_state == "active"))

	return outer_wrap


func _wrap_row_with_detail(item: Dictionary, indent_px: int) -> Control:
	var wrap := VBoxContainer.new()
	wrap.add_theme_constant_override("separation", 6)
	var song_path := str(item.get("path", "")).strip_edges()
	if song_path != "":
		wrap.name = "SongWrap_%s" % _song_node_key(song_path)
	wrap.add_child(_make_row(item, indent_px))
	return wrap


func _make_song_modes_panel(song_path: String, instrument: String, lanes: int) -> PanelContainer:
	const ChartStemChips = preload("res://scenes/song_select/lib/chart_stem_chips.gd")
	return ChartStemChips.build_panel(
		song_path,
		instrument,
		lanes,
		[],
		Callable(),
		tr("GEN_QUEUE_SONG_MODES_TITLE"),
	)


func _cached_intents_ready(song_path: String, instrument: String, lanes: int) -> Dictionary:
	var cache_key := "%s|%s|%d" % [song_path, instrument, lanes]
	if _intents_cache.has(cache_key):
		return _intents_cache[cache_key]
	var ready := _NotesUtils.chart_intents_exist(song_path, instrument, lanes)
	_intents_cache[cache_key] = ready
	return ready


func _make_mode_chip(
	song_path: String,
	instrument: String,
	stem_id: String,
	lanes: int,
	ready: Dictionary,
) -> Label:
	var exists := bool(ready.get(stem_id, false))
	var abbrev := _GoalDiff.abbrev_for_stem(stem_id)
	var chip := Label.new()
	chip.text = "%s %s" % [abbrev, "✓" if exists else "—"]
	chip.add_theme_font_size_override("font_size", 13)
	chip.add_theme_color_override(
		"font_color",
		Color(0.52, 0.9, 0.68, 1.0) if exists else Color(0.58, 0.64, 0.74, 0.95)
	)
	var pair := _GoalDiff.pair_from_stem(stem_id)
	var goal := str(pair.get("goal", _GoalDiff.DEFAULT_GOAL))
	var goal_key := "GEN_GOAL_%s" % goal.to_upper()
	if _GoalDiff.sanitize_goal(goal) == "original":
		chip.tooltip_text = tr(goal_key)
	else:
		var diff_key := _GoalDiff.difficulty_label_key(
			goal,
			str(pair.get("difficulty", _GoalDiff.DEFAULT_DIFFICULTY)),
		)
		chip.tooltip_text = "%s · %s" % [tr(goal_key), tr(diff_key)]
	return chip


func _new_row_panel() -> PanelContainer:
	var panel := PanelContainer.new()
	var box := StyleBoxFlat.new()
	box.bg_color = Color(0.08, 0.1, 0.14, 0.95)
	box.border_color = Color(1, 1, 1, 0.08)
	box.set_border_width_all(1)
	box.set_corner_radius_all(10)
	box.content_margin_left = 12
	box.content_margin_right = 12
	box.content_margin_top = 10
	box.content_margin_bottom = 10
	panel.add_theme_stylebox_override("panel", box)
	return panel


func _make_kind_icon(kind: String, active: bool) -> TextureRect:
	var icon := TextureRect.new()
	icon.custom_minimum_size = Vector2(22, 22)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	var icon_file := "metronome.svg" if kind == "bpm" else "music.svg"
	var tint := Color(0.95, 0.78, 0.35, 1.0) if kind == "bpm" else Color(0.55, 0.82, 0.95, 1.0)
	if active:
		tint = tint.lightened(0.12)
	icon.texture = _UiIconHelper.load_tinted_icon(icon_file, tint, 22)
	return icon


func _make_row(item: Dictionary, indent_px: int, highlight_active: bool = false) -> Control:
	var item_id := str(item.get("id", ""))
	var wrap := MarginContainer.new()
	if item_id != "":
		wrap.name = "Row_%s" % item_id
	if indent_px > 0:
		wrap.add_theme_constant_override("margin_left", indent_px)
	var panel := _new_row_panel()
	if highlight_active:
		var hi := panel.get_theme_stylebox("panel") as StyleBoxFlat
		if hi:
			var box := hi.duplicate() as StyleBoxFlat
			box.border_color = Color(0.52, 0.82, 0.72, 0.55)
			box.bg_color = Color(0.1, 0.14, 0.18, 0.98)
			panel.add_theme_stylebox_override("panel", box)
	wrap.add_child(panel)

	var kind := str(item.get("kind", "notes"))
	var song_path := str(item.get("path", "")).strip_edges()
	if indent_px == 0 and kind == "notes" and song_path != "":
		_wire_song_row_open(
			panel,
			song_path,
			str(item.get("instrument", "drums")),
			int(item.get("lanes", 4)),
		)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	panel.add_child(row)

	var state := str(item.get("state", ""))
	var active := state == "active"
	row.add_child(_make_kind_icon(kind, active))

	var text_col := VBoxContainer.new()
	text_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text_col.add_theme_constant_override("separation", 3)
	row.add_child(text_col)

	if indent_px > 0:
		var settings_only := str(item.get("settings_line", "")).strip_edges()
		if settings_only != "":
			var settings_label := Label.new()
			settings_label.text = "· %s" % settings_only
			settings_label.add_theme_font_size_override("font_size", 13)
			settings_label.add_theme_color_override("font_color", Color(0.78, 0.84, 0.92, 1.0))
			text_col.add_child(settings_label)
	else:
		var title := Label.new()
		title.text = str(item.get("display", ""))
		title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		title.add_theme_font_size_override("font_size", 15)
		title.add_theme_color_override("font_color", Color(0.92, 0.95, 0.98, 1.0))
		text_col.add_child(title)
		var settings := str(item.get("settings_line", "")).strip_edges()
		if settings != "":
			var settings_label := Label.new()
			settings_label.text = settings
			settings_label.add_theme_font_size_override("font_size", 13)
			settings_label.add_theme_color_override("font_color", Color(0.68, 0.76, 0.88, 1.0))
			text_col.add_child(settings_label)

	if active:
		var progress: Dictionary = item.get("progress", {})
		var stage_label := str(progress.get("stage_label", "")).strip_edges()
		if stage_label != "":
			var stage_lbl := Label.new()
			stage_lbl.name = "StageLabel"
			stage_lbl.text = stage_label
			stage_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			stage_lbl.add_theme_font_size_override("font_size", 12)
			stage_lbl.add_theme_color_override("font_color", Color(0.55, 0.92, 0.78, 1.0))
			text_col.add_child(stage_lbl)
		var bar := ProgressBar.new()
		bar.name = "ProgressBar"
		bar.custom_minimum_size = Vector2(0, 8)
		bar.show_percentage = false
		bar.max_value = 100.0
		bar.value = float(progress.get("progress01", 0.0)) * 100.0
		text_col.add_child(bar)
	elif state == "pending":
		var blocked := str(item.get("blocked_by", ""))
		if blocked != "":
			var wait_lbl := Label.new()
			wait_lbl.text = _blocked_text(blocked)
			wait_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			wait_lbl.add_theme_font_size_override("font_size", 11)
			wait_lbl.add_theme_color_override("font_color", Color(0.62, 0.68, 0.78, 1.0))
			text_col.add_child(wait_lbl)

	if state == "pending" and kind in ["bpm", "notes"]:
		var actions := HBoxContainer.new()
		actions.add_theme_constant_override("separation", 2)
		row.add_child(actions)
		if bool(item.get("can_promote", false)):
			var promote := Button.new()
			promote.text = "↑"
			promote.tooltip_text = tr("GEN_QUEUE_PROMOTE")
			promote.flat = true
			promote.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
			promote.pressed.connect(func(): _on_promote_item(item_id))
			actions.add_child(promote)
		if bool(item.get("can_demote", false)):
			var demote := Button.new()
			demote.text = "↓"
			demote.tooltip_text = tr("GEN_QUEUE_DEMOTE")
			demote.flat = true
			demote.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
			demote.pressed.connect(func(): _on_demote_item(item_id))
			actions.add_child(demote)
		var cancel := Button.new()
		cancel.text = "✕"
		cancel.tooltip_text = tr("STATUS_HINT_CANCEL")
		cancel.flat = true
		cancel.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		cancel.pressed.connect(func(): _on_cancel_item(item_id))
		actions.add_child(cancel)
	elif state == "active" and kind in ["bpm", "notes"]:
		var actions := HBoxContainer.new()
		actions.add_theme_constant_override("separation", 2)
		row.add_child(actions)
		var cancel_active := Button.new()
		cancel_active.text = "✕"
		cancel_active.tooltip_text = tr("STATUS_HINT_CANCEL")
		cancel_active.flat = true
		cancel_active.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		cancel_active.pressed.connect(func(): _on_cancel_item(item_id))
		actions.add_child(cancel_active)

	return wrap


func _render_history(history: Array) -> void:
	if _history_vbox == null or _history_section == null:
		return
	for child in _history_vbox.get_children():
		child.queue_free()
	_history_section.visible = true
	if history.is_empty():
		var empty := Label.new()
		empty.text = tr("GEN_QUEUE_HISTORY_EMPTY")
		empty.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		empty.custom_minimum_size = Vector2(0, HISTORY_ROW_HEIGHT)
		empty.add_theme_font_size_override("font_size", 12)
		empty.add_theme_color_override("font_color", Color(0.52, 0.58, 0.68, 0.92))
		_history_vbox.add_child(empty)
		return
	for entry in history:
		if not entry is Dictionary:
			continue
		var row := Label.new()
		row.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		row.custom_minimum_size = Vector2(0, HISTORY_ROW_HEIGHT)
		row.add_theme_font_size_override("font_size", 12)
		var status_key := "GEN_QUEUE_HISTORY_%s" % str(entry.get("status", "done")).to_upper()
		var status_label := tr(status_key)
		if status_label == status_key:
			status_label = str(entry.get("status", ""))
		var settings := str(entry.get("settings_line", "")).strip_edges()
		var when := _TimeUtils.format_relative_ago_or_date_from_unix(int(entry.get("finished_at_unix", 0)))
		var line := "%s %s" % [_history_status_icon(str(entry.get("status", ""))), str(entry.get("display", ""))]
		if settings != "":
			line = "%s · %s" % [line, settings]
		line = "%s — %s" % [line, status_label]
		if when != "":
			line = "%s · %s" % [line, when]
		row.text = line
		row.add_theme_color_override("font_color", _history_color(str(entry.get("status", ""))))
		_history_vbox.add_child(row)


func _history_status_icon(status: String) -> String:
	match status:
		"done":
			return "✓"
		"error":
			return "✗"
		"cancelled":
			return "○"
		_:
			return "·"


func _history_color(status: String) -> Color:
	match status:
		"done":
			return Color(0.52, 0.9, 0.68, 1.0)
		"error":
			return Color(0.95, 0.55, 0.48, 1.0)
		"cancelled":
			return Color(0.62, 0.68, 0.78, 1.0)
		_:
			return Color(0.72, 0.78, 0.88, 1.0)


func _blocked_text(blocked_by: String) -> String:
	match blocked_by:
		"bpm":
			return tr("GEN_QUEUE_BLOCKED_BPM")
		"notes":
			return tr("GEN_QUEUE_BLOCKED_NOTES")
		"delay":
			return tr("GEN_QUEUE_BLOCKED_DELAY")
		_:
			return ""


func _on_promote_item(item_id: String) -> void:
	if _service and _service.promote_queue_item(item_id):
		_UiModifierSounds.play_select()


func _on_demote_item(item_id: String) -> void:
	if _service and _service.demote_queue_item(item_id):
		_UiModifierSounds.play_select()


func _on_cancel_item(item_id: String) -> void:
	if _service and _service.cancel_queue_item(item_id):
		_UiModifierSounds.play_deselect()


func _on_queue_changed(_snapshot: Dictionary) -> void:
	if _queue_refresh_scheduled:
		return
	_queue_refresh_scheduled = true
	call_deferred("_flush_queue_refresh")


func _flush_queue_refresh() -> void:
	_queue_refresh_scheduled = false
	if _service == null or _list_vbox == null:
		return
	var snapshot: Dictionary = _service.get_queue_snapshot()
	var layout_key := _queue_layout_key(snapshot)
	if layout_key == _last_queue_layout_key and _list_vbox.get_child_count() > 1:
		_apply_snapshot_progress(snapshot)
		_apply_snapshot_chrome(snapshot)
		return
	_last_queue_layout_key = layout_key
	_render_snapshot(snapshot)


func _on_progress_tick(_path: String, _idx: int, _total: int, _status: String) -> void:
	_update_active_progress_only()


func _update_active_progress_only() -> void:
	if _service == null or _list_vbox == null:
		return
	var snapshot: Dictionary = _service.get_queue_snapshot()
	for item in snapshot.get("items", []):
		if str(item.get("state", "")) != "active":
			continue
		var item_id := str(item.get("id", ""))
		if item_id == "":
			continue
		var row := _list_vbox.get_node_or_null("Row_%s" % item_id)
		if row == null:
			_on_queue_changed(snapshot)
			return
		_update_row_progress(row, item.get("progress", {}) as Dictionary)


func _update_row_progress(row: Control, progress: Dictionary) -> void:
	var bar := row.find_child("ProgressBar", true, false) as ProgressBar
	if bar:
		bar.value = float(progress.get("progress01", 0.0)) * 100.0
	var stage_lbl := row.find_child("StageLabel", true, false) as Label
	if stage_lbl:
		stage_lbl.text = str(progress.get("stage_label", "")).strip_edges()


func _on_offline_retry_pressed() -> void:
	if _service and _service.has_method("retry_offline_pipeline"):
		_service.retry_offline_pipeline()
		_UiModifierSounds.play_select()


func _on_clear_queue_pressed() -> void:
	if _service == null:
		return
	_service.clear_all_queue_work(true)
	_UiModifierSounds.play_deselect()
	refresh()


func _on_close_pressed() -> void:
	_UiModifierSounds.play_deselect()
	closed.emit()
	queue_free()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		_on_close_pressed()
		get_viewport().set_input_as_handled()
