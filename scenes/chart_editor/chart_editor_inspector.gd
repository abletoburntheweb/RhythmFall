# scenes/chart_editor/chart_editor_inspector.gd
extends Control

signal drum_changed(new_drum: String)
signal quantize_requested(division: int)
signal delete_requested()
signal duplicate_requested()
signal copy_requested()
signal paste_requested()
signal hit_effects_toggled(enabled: bool)
signal hide_after_hit_toggled(enabled: bool)
signal note_color_mode_changed(mode: int)
signal lane_highlight_toggled(enabled: bool)
signal revert_requested()
signal select_all_requested()
signal clear_selection_requested()

var state: ChartEditorState = null
var undo_stack: ChartEditorCommands.UndoStack = null

var _header_label: Label = null
var _map_header: Label = null
var _map_label: Label = null
var _sel_header: Label = null
var _sel_label: Label = null
var _drum_header: Label = null
var _drum_option: OptionButton = null
var _drum_row: HBoxContainer = null
var _quant_header: Label = null
var _quant_label: Label = null
var _quant_row: HBoxContainer = null
var _quantize_btn: Button = null
var _actions_header: Label = null
var _actions_row: HBoxContainer = null
var _delete_btn: Button = null
var _copy_btn: Button = null
var _paste_btn: Button = null
var _hit_effects_check: CheckBox = null
var _hide_after_hit_check: CheckBox = null
var _lane_highlight_check: CheckBox = null
var _color_mode_option: OptionButton = null
var _status_header: Label = null
var _status_label: Label = null
var _changes_label: Label = null
var _timeline_header: Label = null
var _timeline_label: Label = null
var _chart_actions_header: Label = null
var _chart_actions_row: HBoxContainer = null
var _revert_btn: Button = null
var _select_all_btn: Button = null
var _clear_selection_btn: Button = null
var _settings_container: VBoxContainer = null

func _find_child_by_name(root: Node, name: String) -> Node:
	if root == null:
		return null
	if root.name == name:
		return root
	for c in root.get_children():
		var r := _find_child_by_name(c, name)
		if r:
			return r
	return null

func _resolve_nodes() -> void:
	_header_label = get_node_or_null("HeaderLabel") as Label
	if _header_label == null:
		_header_label = get_node_or_null("../../InspectorTitle") as Label
	if _header_label == null:
		_header_label = get_node_or_null("../InspectorTitle") as Label
	if _header_label == null:
		var panel := _find_panel_ancestor()
		if panel:
			_header_label = _find_child_by_name(panel, "InspectorTitle") as Label
	_map_header = get_node_or_null("InfoHeader") as Label
	if _map_header == null:
		_map_header = get_node_or_null("MapHeader") as Label
	_map_label = get_node_or_null("InfoLabel") as Label
	if _map_label == null:
		_map_label = get_node_or_null("MapLabel") as Label
	_sel_header = get_node_or_null("SelHeader") as Label
	_sel_label = get_node_or_null("SelLabel") as Label
	_drum_header = get_node_or_null("DrumHeader") as Label
	_drum_row = get_node_or_null("DrumRow") as HBoxContainer
	_drum_option = get_node_or_null("DrumRow/DrumOption") as OptionButton
	if _drum_option == null:
		_drum_option = get_node_or_null("DrumOption") as OptionButton
	_quant_header = get_node_or_null("QuantHeader") as Label
	_quant_label = get_node_or_null("QuantLabel") as Label
	_quant_row = get_node_or_null("QuantRow") as HBoxContainer
	_quantize_btn = get_node_or_null("QuantizeButton") as Button
	_actions_header = get_node_or_null("ActionsHeader") as Label
	_actions_row = get_node_or_null("ActionsRow") as HBoxContainer
	_delete_btn = get_node_or_null("ActionsRow/DeleteButton") as Button
	if _delete_btn == null:
		_delete_btn = get_node_or_null("DeleteButton") as Button
	_copy_btn = get_node_or_null("ActionsRow/CopyButton") as Button
	if _copy_btn == null:
		_copy_btn = get_node_or_null("CopyButton") as Button
	_paste_btn = get_node_or_null("ActionsRow/PasteButton") as Button
	if _paste_btn == null:
		_paste_btn = get_node_or_null("PasteButton") as Button
	_status_header = get_node_or_null("StatusHeader") as Label
	_status_label = get_node_or_null("StatusLabel") as Label
	_changes_label = get_node_or_null("ChangesLabel") as Label
	_timeline_header = get_node_or_null("TimelineHeader") as Label
	_timeline_label = get_node_or_null("TimelineLabel") as Label
	_chart_actions_header = get_node_or_null("ChartActionsHeader") as Label
	_chart_actions_row = get_node_or_null("ChartActionsRow") as HBoxContainer
	_revert_btn = get_node_or_null("ChartActionsRow/RevertButton") as Button
	if _revert_btn == null:
		_revert_btn = get_node_or_null("RevertButton") as Button
	_select_all_btn = get_node_or_null("ChartActionsRow/SelectAllButton") as Button
	if _select_all_btn == null:
		_select_all_btn = get_node_or_null("SelectAllButton") as Button
	_clear_selection_btn = get_node_or_null("ClearSelectionButton") as Button
	_settings_container = get_node_or_null("../../SettingsContainer") as VBoxContainer
	if _settings_container == null:
		var panel := _find_panel_ancestor()
		if panel:
			_settings_container = panel.get_node_or_null("InspectorRoot/SettingsContainer") as VBoxContainer
			if _settings_container == null:
				_settings_container = _find_child_by_name(panel, "SettingsContainer") as VBoxContainer
	_ensure_status_ui()
	_ensure_timeline_ui()
	_ensure_chart_actions_ui()
	_enforce_fixed_layout()

func _enforce_fixed_layout() -> void:
	var panel := _find_panel_ancestor()
	if panel is PanelContainer:
		panel.custom_minimum_size = Vector2(320, 0)
		panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
		panel.clip_contents = true
	var scroll := get_parent()
	var has_scroll := scroll is ScrollContainer
	if has_scroll:
		(scroll as ScrollContainer).size_flags_horizontal = Control.SIZE_EXPAND_FILL
		(scroll as ScrollContainer).size_flags_vertical = Control.SIZE_EXPAND_FILL
		(scroll as ScrollContainer).horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		(scroll as ScrollContainer).vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
		(scroll as ScrollContainer).clip_contents = true
	self.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	self.size_flags_vertical = Control.SIZE_EXPAND_FILL
	if has_scroll:
		self.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	self.clip_contents = not has_scroll
	for lbl in [_map_label, _sel_label, _header_label, _map_header, _sel_header, _drum_header, _quant_header, _actions_header]:
		if lbl is Label:
			(lbl as Label).size_flags_horizontal = Control.SIZE_EXPAND_FILL
			(lbl as Label).autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			if lbl == _map_label or lbl == _sel_label:
				continue
			(lbl as Label).clip_text = true
			(lbl as Label).text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
			(lbl as Label).custom_minimum_size = Vector2(0, 0)
	for row in [_drum_row, _quant_row, _actions_row, _chart_actions_row]:
		if row is HBoxContainer:
			(row as Control).size_flags_horizontal = Control.SIZE_EXPAND_FILL
			(row as Control).clip_contents = true
			(row as Control).custom_minimum_size = Vector2(0, 0)
	for lbl in [_status_header, _timeline_header, _chart_actions_header, _quant_label]:
		if lbl is Label:
			(lbl as Label).size_flags_horizontal = Control.SIZE_EXPAND_FILL
			(lbl as Label).autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if panel and panel.get_parent() is HSplitContainer:
		var hsplit: HSplitContainer = panel.get_parent() as HSplitContainer
		hsplit.clip_contents = true

func _find_panel_ancestor() -> PanelContainer:
	var cur := get_parent()
	while cur:
		if cur is PanelContainer:
			return cur as PanelContainer
		cur = cur.get_parent()
	return null

const DRUMS: Array[String] = ["kick", "snare", "hat", "tom", "cymbal", "perc"]

func _ensure_extra_settings_ui() -> void:
	if _settings_container == null:
		_settings_container = get_node_or_null("../../SettingsContainer") as VBoxContainer
		if _settings_container == null:
			var panel := _find_panel_ancestor()
			if panel:
				_settings_container = _find_child_by_name(panel, "SettingsContainer") as VBoxContainer
		if _settings_container == null:
			return
	if _hit_effects_check == null and _settings_container:
		_hit_effects_check = _settings_container.get_node_or_null("HitEffectsCheck") as CheckBox
	if _hide_after_hit_check == null and _settings_container:
		_hide_after_hit_check = _settings_container.get_node_or_null("HideAfterHitCheck") as CheckBox
	if _lane_highlight_check == null and _settings_container:
		_lane_highlight_check = _settings_container.get_node_or_null("LaneHighlightCheck") as CheckBox
	if _color_mode_option == null and _settings_container:
		_color_mode_option = _settings_container.get_node_or_null("ColorModeRow/ColorModeOption") as OptionButton
		if _color_mode_option == null:
			_color_mode_option = _settings_container.get_node_or_null("ColorModeOption") as OptionButton
	if _color_mode_option and _color_mode_option.item_count == 0:
		_color_mode_option.add_item("По типу", 0)
		_color_mode_option.add_item("По линии", 1)
	if _hit_effects_check and not _hit_effects_check.toggled.is_connected(_on_hit_effects_toggled):
		_hit_effects_check.toggled.connect(_on_hit_effects_toggled)
		_hit_effects_check.add_theme_font_size_override("font_size", 14)
	if _hide_after_hit_check and not _hide_after_hit_check.toggled.is_connected(_on_hide_after_hit_toggled):
		_hide_after_hit_check.toggled.connect(_on_hide_after_hit_toggled)
		_hide_after_hit_check.add_theme_font_size_override("font_size", 14)
	if _lane_highlight_check and not _lane_highlight_check.toggled.is_connected(_on_lane_highlight_toggled):
		_lane_highlight_check.toggled.connect(_on_lane_highlight_toggled)
		_lane_highlight_check.add_theme_font_size_override("font_size", 14)
	if _color_mode_option and not _color_mode_option.item_selected.is_connected(_on_color_mode_selected):
		_color_mode_option.item_selected.connect(_on_color_mode_selected)
		_color_mode_option.add_theme_font_size_override("font_size", 14)
		if ResourceLoader.exists("res://logic/ui/option_button_popup_utils.gd"):
			var OBP = load("res://logic/ui/option_button_popup_utils.gd")
			if OBP and OBP.has_method("apply_popup_font_size"):
				OBP.apply_popup_font_size(_color_mode_option, 18)

func _move_settings_to_fixed_bottom() -> void:
	pass

func _ensure_status_ui() -> void:
	if _status_header == null:
		_status_header = get_node_or_null("StatusHeader") as Label
	if _status_label == null:
		_status_label = get_node_or_null("StatusLabel") as Label
	if _changes_label == null:
		_changes_label = get_node_or_null("ChangesLabel") as Label

func _ensure_timeline_ui() -> void:
	if _timeline_header == null:
		_timeline_header = get_node_or_null("TimelineHeader") as Label
	if _timeline_label == null:
		_timeline_label = get_node_or_null("TimelineLabel") as Label

func _ensure_chart_actions_ui() -> void:
	if _chart_actions_header == null:
		_chart_actions_header = get_node_or_null("ChartActionsHeader") as Label
	if _chart_actions_row == null:
		_chart_actions_row = get_node_or_null("ChartActionsRow") as HBoxContainer
	if _revert_btn == null:
		_revert_btn = get_node_or_null("ChartActionsRow/RevertButton") as Button
		if _revert_btn == null:
			_revert_btn = get_node_or_null("RevertButton") as Button
	if _select_all_btn == null:
		_select_all_btn = get_node_or_null("ChartActionsRow/SelectAllButton") as Button
		if _select_all_btn == null:
			_select_all_btn = get_node_or_null("SelectAllButton") as Button
	if _revert_btn and not _revert_btn.pressed.is_connected(func(): revert_requested.emit()):
		_revert_btn.pressed.connect(func(): revert_requested.emit())
	if _select_all_btn and not _select_all_btn.pressed.is_connected(func(): select_all_requested.emit()):
		_select_all_btn.pressed.connect(func(): select_all_requested.emit())

func _ready() -> void:
	_resolve_nodes()
	_ensure_extra_settings_ui()
	if _drum_option and _drum_option.item_count == 0:
		var tr_keys := ["DRUM_KICK","DRUM_SNARE","DRUM_HAT","DRUM_TOM","DRUM_CYMBAL","DRUM_PERC"]
		for i in range(DRUMS.size()):
			var key := String(tr_keys[i]) if i < tr_keys.size() else ""
			var loc := tr(key) if key != "" else DRUMS[i].capitalize()
			if loc == "" or loc == key:
				loc = DRUMS[i].capitalize()
			_drum_option.add_item(loc, i)
	if _drum_option and not _drum_option.item_selected.is_connected(_on_drum_selected):
		_drum_option.item_selected.connect(_on_drum_selected)
	if _delete_btn and not _delete_btn.pressed.is_connected(_on_delete_pressed):
		_delete_btn.pressed.connect(_on_delete_pressed)
	if _copy_btn and not _copy_btn.pressed.is_connected(func(): copy_requested.emit()):
		_copy_btn.pressed.connect(func(): copy_requested.emit())
	if _paste_btn and not _paste_btn.pressed.is_connected(func(): paste_requested.emit()):
		_paste_btn.pressed.connect(func(): paste_requested.emit())
	if _clear_selection_btn and not _clear_selection_btn.pressed.is_connected(_on_clear_selection_pressed):
		_clear_selection_btn.pressed.connect(_on_clear_selection_pressed)
	if _quantize_btn and not _quantize_btn.pressed.is_connected(_on_quantize_pressed_for_button):
		_quantize_btn.pressed.connect(_on_quantize_pressed_for_button)
	if _quant_row:
		for child in _quant_row.get_children():
			if child is Button:
				var btn := child as Button
				if not btn.pressed.is_connected(_on_quantize_pressed):
					btn.pressed.connect(_on_quantize_pressed.bind(btn))
	_refresh_static_labels()

func _refresh_static_labels() -> void:
	if _header_label:
		var t := tr("CHART_EDITOR_INSPECTOR_TITLE")
		_header_label.text = t if t != "CHART_EDITOR_INSPECTOR_TITLE" and t != "" else "ИНСПЕКТОР"
		_header_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if _map_header:
		var t2 := tr("CHART_EDITOR_SECTION_MAP")
		_map_header.text = t2 if t2 != "CHART_EDITOR_SECTION_MAP" and t2 != "" else "ИНФОРМАЦИЯ О ЧАРТЕ"
	if _quant_header:
		var tq := tr("CHART_EDITOR_QUANTIZE_TITLE")
		_quant_header.text = tq if tq != "CHART_EDITOR_QUANTIZE_TITLE" and tq != "" else "КВАНТИЗАЦИЯ"
	if _actions_header:
		var ta := tr("CHART_EDITOR_SECTION_EDITING")
		if _actions_header.text == "ДЕЙСТВИЯ" and tr("CHART_EDITOR_SECTION_EDITING") != "CHART_EDITOR_SECTION_EDITING":
			pass

func setup(p_state: ChartEditorState) -> void:
	state = p_state
	refresh()

func setup_with_undo(p_state: ChartEditorState, p_undo_stack: ChartEditorCommands.UndoStack) -> void:
	state = p_state
	undo_stack = p_undo_stack
	refresh()

func set_undo_stack(p_undo_stack: ChartEditorCommands.UndoStack) -> void:
	undo_stack = p_undo_stack
	refresh()

func update_timeline(time: float) -> void:
	if _timeline_label == null:
		_timeline_label = get_node_or_null("TimelineLabel") as Label
	if _timeline_label:
		_timeline_label.text = _format_time_mmss(time)

func refresh() -> void:
	_resolve_nodes()
	_refresh_static_labels()
	if state == null:
		if _map_label:
			_map_label.text = "Нет чарта"
		if _sel_label:
			_sel_label.text = tr("CHART_EDITOR_NOTHING_SELECTED") if tr("CHART_EDITOR_NOTHING_SELECTED") != "CHART_EDITOR_NOTHING_SELECTED" else "Ничего не выбрано"
			_update_quant_buttons(16)
		_set_inspector_visibility(false, false, false)
		if _status_header: _status_header.visible = false
		if _status_label: _status_label.visible = false
		if _changes_label: _changes_label.visible = false
		if _timeline_header: _timeline_header.visible = false
		if _timeline_label: _timeline_label.visible = false
		if _chart_actions_header: _chart_actions_header.visible = false
		if _chart_actions_row: _chart_actions_row.visible = false
		_ensure_extra_settings_ui()
		if _hit_effects_check:
			var he2 := true
			if SettingsManager and SettingsManager.has_method("get_chart_editor_hit_effects_enabled"):
				he2 = SettingsManager.get_chart_editor_hit_effects_enabled()
			_hit_effects_check.set_block_signals(true)
			_hit_effects_check.button_pressed = he2
			_hit_effects_check.set_block_signals(false)
		if _hide_after_hit_check:
			var hh2 := false
			if SettingsManager and SettingsManager.has_method("get_chart_editor_hide_notes_after_hit"):
				hh2 = SettingsManager.get_chart_editor_hide_notes_after_hit()
			_hide_after_hit_check.set_block_signals(true)
			_hide_after_hit_check.button_pressed = hh2
			_hide_after_hit_check.set_block_signals(false)
		if _lane_highlight_check:
			var lh2 := true
			if SettingsManager and SettingsManager.has_method("get_replay_hide_option"):
				lh2 = not SettingsManager.get_replay_hide_option("lane_highlights")
			elif SettingsManager and SettingsManager.has_method("get_lane_highlight_brightness"):
				lh2 = SettingsManager.get_lane_highlight_brightness() > 0.0
			_lane_highlight_check.set_block_signals(true)
			_lane_highlight_check.button_pressed = lh2
			_lane_highlight_check.set_block_signals(false)
		if _color_mode_option:
			var cm2 := 0
			if SettingsManager and SettingsManager.has_method("get_chart_editor_note_color_mode"):
				cm2 = SettingsManager.get_chart_editor_note_color_mode()
			_color_mode_option.set_block_signals(true)
			_color_mode_option.select(cm2)
			_color_mode_option.set_block_signals(false)
		return
	var count := state.note_count()
	var sel := state.selected_keys.size()
	if _map_label:
		var bpm_str := "%.1f" % state.bpm if state.bpm > 0 else "—"
		var dur_str := _format_duration(state.duration_s)
		var lanes_str := tr("CHART_EDITOR_LABEL_LANES_FMT") % state.lanes if tr("CHART_EDITOR_LABEL_LANES_FMT") != "CHART_EDITOR_LABEL_LANES_FMT" else "%d дорожек" % state.lanes
		var notes_str := tr("CHART_EDITOR_LABEL_NOTES_FMT") % count if tr("CHART_EDITOR_LABEL_NOTES_FMT") != "CHART_EDITOR_LABEL_NOTES_FMT" else "%d нот" % count
		var ver_str := ""
		if state.version > 0:
			ver_str = " • v%d" % state.version
		elif state.is_corrected:
			ver_str = " • corrected"
		_map_label.text = "%s\n%s\nBPM: %s\n%s%s" % [notes_str, lanes_str, bpm_str, dur_str, ver_str]
	_ensure_status_ui()
	if _status_header:
		_status_header.visible = true
	if _status_label and _changes_label and state:
		var is_dirty := state.is_dirty
		if undo_stack and undo_stack.has_method("is_dirty"):
			is_dirty = undo_stack.is_dirty()
		var changes := 0
		if undo_stack and undo_stack.has_method("get_changes_count"):
			changes = undo_stack.get_changes_count()
		elif is_dirty:
			changes = 1
		var status_txt := "Не сохранено" if is_dirty else "Сохранено"
		var key := "CHART_EDITOR_STATUS_UNSAVED" if is_dirty else "CHART_EDITOR_STATUS_SAVED"
		var loc := tr(key)
		if loc != key and loc != "":
			status_txt = loc
		_status_label.text = status_txt
		_status_label.add_theme_color_override("font_color", Color(0.95, 0.45, 0.45, 1.0) if is_dirty else Color(0.35, 0.95, 0.65, 1.0))
		var changes_fmt := tr("CHART_EDITOR_STATUS_CHANGES_FMT")
		if changes_fmt == "CHART_EDITOR_STATUS_CHANGES_FMT" or changes_fmt == "":
			changes_fmt = "Изменений: %d"
		if "%d" in changes_fmt:
			_changes_label.text = changes_fmt % changes
		else:
			_changes_label.text = "Изменений: %d" % changes
		_changes_label.visible = true
		_status_label.visible = true
		if _changes_label:
			_changes_label.visible = true
	_ensure_timeline_ui()
	if _timeline_header:
		_timeline_header.visible = true
	if _timeline_label and state:
		_timeline_label.text = _format_time_mmss(state.song_time)
		_timeline_label.visible = true
	_ensure_chart_actions_ui()
	if _chart_actions_header:
		_chart_actions_header.visible = true
	if _chart_actions_row:
		_chart_actions_row.visible = true
	if _revert_btn and state:
		var can_revert := state.is_dirty
		if undo_stack and undo_stack.has_method("is_dirty"):
			can_revert = undo_stack.is_dirty()
		_revert_btn.disabled = not can_revert
	if _select_all_btn and state:
		_select_all_btn.disabled = state.note_count() == 0
	if sel == 0:
		if _sel_header:
			var t := tr("CHART_EDITOR_SECTION_SELECTED")
			_sel_header.text = t if t != "CHART_EDITOR_SECTION_SELECTED" and t != "" else "ВЫДЕЛЕНИЕ"
		if _sel_label:
			var ns := tr("CHART_EDITOR_NOTHING_SELECTED")
			_sel_label.text = ns if ns != "CHART_EDITOR_NOTHING_SELECTED" and ns != "" else "Ничего не выбрано"
		_set_inspector_visibility(false, false, false)
	elif sel == 1:
		if _sel_header:
			var t := tr("CHART_EDITOR_SECTION_SELECTED_NOTE")
			_sel_header.text = t if t != "CHART_EDITOR_SECTION_SELECTED_NOTE" and t != "" else "ВЫДЕЛЕНИЕ"
		var key := state.primary_key
		var n: Dictionary = {}
		for item in state.document.notes:
			if EditorNoteUtils.note_key(item as Dictionary) == key:
				n = item
				break
		if n.is_empty() and not state.selected_keys.is_empty():
			for item in state.document.notes:
				var k := EditorNoteUtils.note_key(item as Dictionary)
				if state.selected_keys.has(k):
					n = item
					break
		var t_val := float(n.get("time", 0.0))
		var lane := int(n.get("lane", 0))
		var drum := String(n.get("drum", "kick"))
		if _sel_label:
			var time_str := _format_time_mmss(t_val)
			var lane_lbl := tr("CHART_EDITOR_LABEL_LANE") if tr("CHART_EDITOR_LABEL_LANE") != "CHART_EDITOR_LABEL_LANE" else "Дорожка"
			_sel_label.text = "%s   %s\n%s: %s" % [format_drum_label(drum), time_str, lane_lbl, str(lane)]
		if _drum_option:
			_drum_option.disabled = false
			var idx := DRUMS.find(drum.to_lower())
			if idx >= 0:
				_drum_option.select(idx)
		_set_inspector_visibility(true, true, true)
	else:
		if _sel_header:
			var fmt := tr("CHART_EDITOR_SECTION_SELECTED_MULTI")
			if fmt != "CHART_EDITOR_SECTION_SELECTED_MULTI" and fmt.contains("%d"):
				_sel_header.text = fmt % sel
			else:
				_sel_header.text = "ВЫДЕЛЕНИЕ: %d" % sel
		if _sel_label:
			_sel_label.text = "Мульти-правка: барабан, квантизация"
		if _drum_option:
			_drum_option.disabled = false
			var first_drum := _first_selected_drum()
			var idx2 := DRUMS.find(first_drum)
			if idx2 >= 0:
				_drum_option.select(idx2)
		_set_inspector_visibility(true, true, true)
	_update_quant_buttons(state.snap_division if state else 16)
	if _copy_btn:
		_copy_btn.disabled = sel == 0
	if _paste_btn:
		_paste_btn.disabled = state.clipboard.is_empty() if state else true
	if _clear_selection_btn:
		_clear_selection_btn.disabled = sel == 0
	if _delete_btn:
		_delete_btn.disabled = sel == 0
	_ensure_extra_settings_ui()
	if _hit_effects_check:
		var he := true
		if SettingsManager and SettingsManager.has_method("get_chart_editor_hit_effects_enabled"):
			he = SettingsManager.get_chart_editor_hit_effects_enabled()
		_hit_effects_check.set_block_signals(true)
		_hit_effects_check.button_pressed = he
		_hit_effects_check.set_block_signals(false)
	if _hide_after_hit_check:
		var hh := false
		if SettingsManager and SettingsManager.has_method("get_chart_editor_hide_notes_after_hit"):
			hh = SettingsManager.get_chart_editor_hide_notes_after_hit()
		_hide_after_hit_check.set_block_signals(true)
		_hide_after_hit_check.button_pressed = hh
		_hide_after_hit_check.set_block_signals(false)
	if _lane_highlight_check:
		var lh := true
		if SettingsManager and SettingsManager.has_method("get_replay_hide_option"):
			lh = not SettingsManager.get_replay_hide_option("lane_highlights")
		elif SettingsManager and SettingsManager.has_method("get_lane_highlight_brightness"):
			lh = SettingsManager.get_lane_highlight_brightness() > 0.0
		_lane_highlight_check.set_block_signals(true)
		_lane_highlight_check.button_pressed = lh
		_lane_highlight_check.set_block_signals(false)
	if _color_mode_option:
		var cm := 0
		if SettingsManager and SettingsManager.has_method("get_chart_editor_note_color_mode"):
			cm = SettingsManager.get_chart_editor_note_color_mode()
		_color_mode_option.set_block_signals(true)
		_color_mode_option.select(cm)
		_color_mode_option.set_block_signals(false)

func _set_inspector_visibility(show_drum: bool, show_quant: bool, show_actions: bool) -> void:
	if _drum_header:
		_drum_header.visible = show_drum
	if _drum_row:
		_drum_row.visible = show_drum
	if _quant_header:
		_quant_header.visible = show_quant
	if _quant_label:
		_quant_label.visible = show_quant
	if _quant_row:
		_quant_row.visible = show_quant
	if _quantize_btn:
		_quantize_btn.visible = show_quant
	if _actions_header:
		_actions_header.visible = show_actions
	if _actions_row:
		_actions_row.visible = show_actions

func _format_duration(s: float) -> String:
	var dur_fmt := tr("CHART_EDITOR_LABEL_DURATION_FMT")
	var time_str := _format_time_mmss(s)
	if dur_fmt != "CHART_EDITOR_LABEL_DURATION_FMT" and dur_fmt.contains("%s"):
		return dur_fmt % time_str
	return "Длительность %s" % time_str

func _format_time_mmss(t: float) -> String:
	var total_ms := int(round(maxf(0.0, t) * 1000.0))
	var mins := total_ms / 60000
	var secs := (total_ms % 60000) / 1000
	var ms := total_ms % 1000
	return "%02d:%02d.%03d" % [mins, secs, ms]

func format_drum_label(drum: String) -> String:
	var d := drum.strip_edges().to_lower()
	var idx := DRUMS.find(d)
	if idx >= 0:
		var keys: Array[String] = ["DRUM_KICK","DRUM_SNARE","DRUM_HAT","DRUM_TOM","DRUM_CYMBAL","DRUM_PERC"]
		var key: String = keys[idx]
		var loc := tr(key)
		if loc != key and loc != "":
			return loc
		return DRUMS[idx].capitalize()
	return drum.capitalize()

func _first_selected_drum() -> String:
	if state == null or state.selected_keys.is_empty():
		return "kick"
	var key := state.primary_key
	for n in state.document.notes:
		if EditorNoteUtils.note_key(n as Dictionary) == key:
			return String(n.get("drum", "kick")).to_lower()
	for k in state.selected_keys.keys():
		for n in state.document.notes:
			if EditorNoteUtils.note_key(n as Dictionary) == String(k):
				return String(n.get("drum", "kick")).to_lower()
	return "kick"

func _update_quant_buttons(active_div: int) -> void:
	if _quant_row == null:
		return
	for child in _quant_row.get_children():
		if child is Button:
			var btn := child as Button
			var div := int(btn.get_meta("division", 0))
			if div == 0:
				var txt := btn.text
				if "/" in txt:
					var parts := txt.split("/")
					if parts.size() > 1 and String(parts[1]).is_valid_int():
						div = int(parts[1])
			btn.button_pressed = (div == active_div)

func _measure_label(t: float) -> String:
	if state and state.grid:
		return state.grid.format_time_label(t)
	return "%.2f" % t

func _on_drum_selected(index: int) -> void:
	if index < 0 or index >= DRUMS.size():
		return
	drum_changed.emit(DRUMS[index])

func _on_delete_pressed() -> void:
	delete_requested.emit()

func _on_quantize_pressed_for_button() -> void:
	var div := 16
	if state:
		div = state.snap_division
	if div <= 0:
		div = 16
	quantize_requested.emit(div)

func _on_quantize_pressed(btn: Button) -> void:
	var div := int(btn.get_meta("division", 16))
	if div == 0:
		var txt := btn.text
		if "/" in txt:
			var parts := txt.split("/")
			if parts.size() > 1 and String(parts[1]).is_valid_int():
				div = int(parts[1])
	if div == 0:
		div = 16
	quantize_requested.emit(div)

func _on_clear_selection_pressed() -> void:
	clear_selection_requested.emit()

func _on_hit_effects_toggled(enabled: bool) -> void:
	hit_effects_toggled.emit(enabled)

func _on_hide_after_hit_toggled(enabled: bool) -> void:
	hide_after_hit_toggled.emit(enabled)

func _on_lane_highlight_toggled(enabled: bool) -> void:
	lane_highlight_toggled.emit(enabled)

func _on_color_mode_selected(index: int) -> void:
	note_color_mode_changed.emit(index)
