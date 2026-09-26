# scenes/settings_menu/dialogs/chart_editor_bindings_dialog.gd
extends Control

const ChartEditorBindings = preload("res://logic/domain/controls/chart_editor_bindings.gd")

const _SECTION_TINTS := {
	# Единая розово-фиолетовая палитра оригинального Controls UI — без зелёной/синей радуги
	"editing": Color(0.86, 0.52, 0.72, 1.0),
	"playback": Color(0.88, 0.54, 0.70, 1.0),
	"navigation": Color(0.82, 0.52, 0.74, 1.0),
	"chart": Color(0.84, 0.50, 0.72, 1.0),
}
const _PLUS_TINT := Color(0.35, 0.85, 0.45, 1.0)
const _TRASH_TINT := Color(0.95, 0.35, 0.35, 1.0)

signal closed

var _content_hbox: HBoxContainer = null
var _left_vbox: VBoxContainer = null
var _right_vbox: VBoxContainer = null
var _scroll: ScrollContainer = null
var _binding_buttons: Dictionary = {} # key: "action:index" -> Button
var _capture_active: bool = false
var _capture_action: String = ""
var _capture_index: int = -1
var _capture_button: Button = null
var _capture_old_binding: Dictionary = {}
var _capture_button_original_text: String = ""

var _ctx_menu: PopupMenu = null
var _ctx_action: String = ""
var _ctx_index: int = -1

@onready var _back_button: Button = $Container/BackButtonWrap/BackButton
@onready var _title_label: Label = $Container/TitleLabel
@onready var _subtitle_label: Label = $Container/SubtitleLabel
@onready var _reset_button: Button = $Container/BodyCenter/CardPanel/CardMargin/VBox/ResetButton

func _ready() -> void:
	UiIconHelper.configure_modal_overlay(self, 105)
	if _back_button:
		UiIconHelper.apply_standard_back_button(_back_button)
		if not _back_button.pressed.is_connected(_on_close_pressed):
			_back_button.pressed.connect(_on_close_pressed)
	if _reset_button:
		if not _reset_button.pressed.is_connected(_on_reset_pressed):
			_reset_button.pressed.connect(_on_reset_pressed)
	_ensure_ui()
	_apply_card_panel_style()
	_ensure_ctx_menu()
	_ensure_info_block()
	apply_locale()
	set_process_input(true)

func _apply_card_panel_style() -> void:
	var card_panel := get_node_or_null("Container/BodyCenter/CardPanel") as PanelContainer
	if card_panel == null:
		return
	var box := StyleBoxFlat.new()
	box.corner_radius_top_left = 12
	box.corner_radius_top_right = 12
	box.corner_radius_bottom_right = 12
	box.corner_radius_bottom_left = 12
	box.border_width_left = 2
	box.border_width_top = 2
	box.border_width_right = 2
	box.border_width_bottom = 2
	box.content_margin_left = 16.0
	box.content_margin_top = 10.0
	box.content_margin_right = 16.0
	box.content_margin_bottom = 10.0
	# Более тёмная вариация SectionPanelPink — заметно темнее KeysPanel, но та же палитра
	box.bg_color = Color(0.095, 0.085, 0.12, 1.0)
	box.border_color = Color(0.72, 0.40, 0.60, 0.55)
	box.shadow_color = Color(0, 0, 0, 0.32)
	box.shadow_size = 4
	box.shadow_offset = Vector2(0, 2)
	card_panel.add_theme_stylebox_override("panel", box)

func _ensure_ctx_menu() -> void:
	if _ctx_menu != null and is_instance_valid(_ctx_menu):
		return
	_ctx_menu = PopupMenu.new()
	_ctx_menu.name = "BindingCtxMenu"
	add_child(_ctx_menu)
	_ctx_menu.id_pressed.connect(_on_ctx_id_pressed)

func _ensure_info_block() -> void:
	var vbox := get_node_or_null("Container/BodyCenter/CardPanel/CardMargin/VBox") as VBoxContainer
	if vbox == null:
		return
	if vbox.get_node_or_null("InfoHeader") != null:
		# ensure third hint exists even if header already created (migration for older tscn)
		if vbox.get_node_or_null("InfoHint2") == null:
			var hint2 := Label.new()
			hint2.name = "InfoHint2"
			hint2.text = "ПКМ по клавише открывает дополнительные действия."
			hint2.add_theme_color_override("font_color", Color(0.58, 0.66, 0.78, 0.92))
			hint2.add_theme_font_size_override("font_size", 14)
			hint2.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			var hint_idx := vbox.get_node_or_null("InfoHint")
			var at := vbox.get_child_count()
			if hint_idx:
				at = hint_idx.get_index() + 1
			vbox.add_child(hint2)
			vbox.move_child(hint2, at)
		return
	var header := Label.new()
	header.name = "InfoHeader"
	header.text = "Привязка клавиш"
	header.theme_type_variation = &"SectionHeaderPink"
	header.add_theme_font_size_override("font_size", 22)
	vbox.add_child(header)
	vbox.move_child(header, 0)
	var hint := Label.new()
	hint.name = "InfoHint"
	hint.text = "Кнопка клавиши меняет её назначение."
	hint.add_theme_color_override("font_color", Color(0.58, 0.66, 0.78, 0.92))
	hint.add_theme_font_size_override("font_size", 14)
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(hint)
	vbox.move_child(hint, 1)
	var hint2b := Label.new()
	hint2b.name = "InfoHint2"
	hint2b.text = "ПКМ по клавише открывает дополнительные действия."
	hint2b.add_theme_color_override("font_color", Color(0.58, 0.66, 0.78, 0.92))
	hint2b.add_theme_font_size_override("font_size", 14)
	hint2b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(hint2b)
	vbox.move_child(hint2b, 2)

func _show_binding_context_menu(action: String, index: int, btn: Button, global_pos: Vector2) -> void:
	if _capture_active:
		return
	_ensure_ctx_menu()
	_ctx_action = action
	_ctx_index = index
	_ctx_menu.clear()
	_ctx_menu.add_item("Добавить привязку", 0)
	_ctx_menu.add_item("Удалить привязку", 1)
	var km := SettingsManager.get_chart_editor_keymap()
	var arr = km.get(action, []) as Array
	var can_remove: bool = false
	if arr is Array:
		if arr.size() > 1:
			can_remove = true
		elif arr.size() == 1:
			can_remove = false
		else:
			can_remove = false
		if index < arr.size() and arr[index] is Dictionary and (arr[index] as Dictionary).is_empty():
			can_remove = false
	if not can_remove:
		_ctx_menu.set_item_disabled(1, true)
	# Увеличенный текст как в остальных Settings UI
	OptionButtonPopupUtils.apply_context_menu_font_size(_ctx_menu, 18)
	_ctx_menu.position = global_pos
	_ctx_menu.popup()

func _on_ctx_id_pressed(id: int) -> void:
	match id:
		0:
			_handle_add_binding(_ctx_action)
		1:
			_handle_remove_binding(_ctx_action, _ctx_index)

func _handle_add_binding(action: String) -> void:
	if _capture_active:
		_clear_capture_state()
	var km := SettingsManager.get_chart_editor_keymap()
	var arr = km.get(action, []) as Array
	var new_index := arr.size() if arr is Array else 0
	_capture_active = true
	_capture_action = action
	_capture_index = new_index
	_capture_button = null
	_capture_button_original_text = ""
	_capture_old_binding = {}
	_rebuild_content()
	# _build_section создаст placeholder [...] вертикально и привяжет _capture_button

func _handle_remove_binding(action: String, index: int) -> void:
	if _capture_active:
		_clear_capture_state()
	var km := SettingsManager.get_chart_editor_keymap()
	var arr = km.get(action, []) as Array
	if arr is Array and arr.size() <= 1:
		return
	if index < 0 or index >= arr.size():
		return
	SettingsManager.remove_chart_editor_binding(action, index)
	_rebuild_content()

func _on_binding_gui_input(event: InputEvent, action: String, index: int, btn: Button) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
		_show_binding_context_menu(action, index, btn, (event as InputEventMouseButton).global_position)
		get_viewport().set_input_as_handled()

func _section_for_action(action: String) -> String:
	for sid in ChartEditorBindings.SECTIONS.keys():
		if action in ChartEditorBindings.SECTIONS[sid]:
			return sid
	return "editing"

func _section_base_tint(section_id: String) -> Color:
	return _SECTION_TINTS.get(section_id, _SECTION_TINTS["editing"])

func _shaded_border_color(base: Color, index: int) -> Color:
	var t := base
	# Небольшое различие оттенков внутри секции — только для border, не для текста
	match index % 4:
		0:
			return t
		1:
			return t.lightened(0.10)
		2:
			return t.darkened(0.08)
		3:
			return t.lightened(0.18)
	return t

func _apply_key_button_border(btn: Button, border: Color) -> void:
	# Повторяем принцип оригинального Controls UI (FlatButton) — меняется только border/style,
	# текст остаётся единым оригинальным (белый), как в controls_tab.gd.
	btn.theme_type_variation = &"FlatButton"
	var states := ["normal", "hover", "pressed", "focus", "disabled"]
	for state in states:
		var box := StyleBoxFlat.new()
		box.content_margin_left = 16.0
		box.content_margin_top = 10.0
		box.content_margin_right = 16.0
		box.content_margin_bottom = 10.0
		box.corner_radius_top_left = 10
		box.corner_radius_top_right = 10
		box.corner_radius_bottom_right = 10
		box.corner_radius_bottom_left = 10
		box.shadow_color = Color(0, 0, 0, 0.35)
		box.shadow_size = 6
		box.shadow_offset = Vector2(0, 2)
		match state:
			"hover":
				box.bg_color = Color(1, 1, 1, 0.1232)
				box.draw_center = true
				box.border_color = border.lightened(0.12)
				box.border_width_left = 2
				box.border_width_top = 2
				box.border_width_right = 2
				box.border_width_bottom = 2
				box.shadow_size = 7
				box.shadow_color = Color(0, 0, 0, 0.40)
			"pressed":
				box.bg_color = Color(0, 0, 0, 0)
				box.draw_center = true
				box.border_color = border.darkened(0.10)
				box.border_width_left = 2
				box.border_width_top = 2
				box.border_width_right = 2
				box.border_width_bottom = 2
			"focus":
				box.bg_color = Color(0, 0, 0, 0)
				box.draw_center = false
				box.border_color = border
				box.border_width_left = 3
				box.border_width_top = 3
				box.border_width_right = 3
				box.border_width_bottom = 3
			"disabled":
				box.bg_color = Color(0, 0, 0, 0)
				box.draw_center = false
				box.border_color = Color(border.r, border.g, border.b, 0.35)
				box.border_width_left = 2
				box.border_width_top = 2
				box.border_width_right = 2
				box.border_width_bottom = 2
			_:
				box.bg_color = Color(0, 0, 0, 0)
				box.draw_center = false
				box.border_color = Color(border.r, border.g, border.b, 0.85)
				box.border_width_left = 2
				box.border_width_top = 2
				box.border_width_right = 2
				box.border_width_bottom = 2
		btn.add_theme_stylebox_override(state, box)
	# Текст клавиш — единый оригинальный цвет из controls_tab.gd / app_theme FlatButton (белый), не меняется от клавиши к клавише
	btn.add_theme_color_override("font_color", Color(1, 1, 1, 1))
	btn.add_theme_color_override("font_hover_color", Color(1, 1, 1, 1))
	btn.add_theme_color_override("font_pressed_color", Color(1, 1, 1, 1))
	btn.add_theme_color_override("font_focus_color", Color(1, 1, 1, 1))
	btn.add_theme_color_override("font_disabled_color", Color(0.5, 0.5, 0.5, 1))

func _make_compact_icon_button(icon_file: String, tint: Color, tooltip: String) -> Button:
	var btn := Button.new()
	btn.custom_minimum_size = Vector2(28, 28)
	btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	btn.tooltip_text = tooltip
	btn.theme_type_variation = &"FlatButton"
	UiIconHelper.configure_button_icon(btn, icon_file, tint, 14)
	btn.text = ""
	# Компактный размер — не увеличиваем высоту строки (binding button 44, icon 28)
	# Визуально соответствует иконке удаления: тот же размер и механизм
	btn.add_theme_constant_override("icon_max_width", 14)
	return btn

func _ensure_ui() -> void:
	# Find nodes from tscn (new compact modal)
	_content_hbox = get_node_or_null("Container/BodyCenter/CardPanel/CardMargin/VBox/Scroll/ContentHost") as HBoxContainer
	_scroll = get_node_or_null("Container/BodyCenter/CardPanel/CardMargin/VBox/Scroll") as ScrollContainer
	if _content_hbox:
		_left_vbox = _content_hbox.get_node_or_null("LeftVBox") as VBoxContainer
		_right_vbox = _content_hbox.get_node_or_null("RightVBox") as VBoxContainer
	# Fallback for programmatic creation (when instanced via Script.new without tscn)
	if _content_hbox == null:
		var container := get_node_or_null("Container")
		if container == null:
			return
		var body_center := get_node_or_null("Container/BodyCenter")
		if body_center == null:
			return
		var card_panel := body_center.get_node_or_null("CardPanel")
		if card_panel == null:
			return
		var card_margin := card_panel.get_node_or_null("CardMargin")
		var vbox := card_margin.get_node_or_null("VBox") if card_margin else null
		if vbox == null:
			return
		_scroll = vbox.get_node_or_null("Scroll") as ScrollContainer
		if _scroll == null:
			return
		_content_hbox = _scroll.get_node_or_null("ContentHost") as HBoxContainer
		if _content_hbox:
			_left_vbox = _content_hbox.get_node_or_null("LeftVBox") as VBoxContainer
			_right_vbox = _content_hbox.get_node_or_null("RightVBox") as VBoxContainer

func apply_locale() -> void:
	if _title_label:
		_title_label.text = _tr_title()
	if _subtitle_label:
		_subtitle_label.text = _tr_hint()
	if _reset_button:
		_reset_button.text = tr("CONTROLS_RESET_KEYS") if tr("CONTROLS_RESET_KEYS") != "CONTROLS_RESET_KEYS" else "Сбросить назначение клавиш"

func _tr_title() -> String:
	var t := tr("CHART_EDITOR_BINDINGS_TITLE")
	if t != "CHART_EDITOR_BINDINGS_TITLE" and t != "":
		return t
	return "Привязка клавиш редактора" if TranslationServer.get_locale().begins_with("ru") else "Chart Editor Bindings"

func _tr_hint() -> String:
	var t := tr("CHART_EDITOR_BINDINGS_HINT")
	if t != "CHART_EDITOR_BINDINGS_HINT" and t != "":
		return t
	return "Нажмите на кнопку, затем нажмите новую комбинацию. Поддерживаются Ctrl/Shift/Alt + клавиши." if TranslationServer.get_locale().begins_with("ru") else "Click a button, then press a new combo. Ctrl/Shift/Alt supported."

func _tr_action_label(action: String) -> String:
	var key := "CHART_EDITOR_ACTION_" + action.to_upper()
	var t := tr(key)
	if t != key and t != "":
		return t
	var ru := TranslationServer.get_locale().begins_with("ru")
	var map_ru := {
		"undo": "Отменить",
		"redo": "Повторить",
		"save": "Сохранить",
		"select_all": "Выделить всё",
		"copy": "Копировать",
		"paste": "Вставить",
		"duplicate": "Дублировать",
		"delete": "Удалить",
		"clear_selection": "Снять выделение",
		"play_pause": "Игра / Пауза",
		"song_start": "Начало песни",
		"song_end": "Конец песни",
		"prev_beat": "Предыдущий бит",
		"next_beat": "Следующий бит",
		"prev_measure": "Предыдущий такт",
		"next_measure": "Следующий такт",
		"quantize": "Квантовать",
	}
	var map_en := {
		"undo": "Undo",
		"redo": "Redo",
		"save": "Save",
		"select_all": "Select All",
		"copy": "Copy",
		"paste": "Paste",
		"duplicate": "Duplicate",
		"delete": "Delete",
		"clear_selection": "Clear Selection",
		"play_pause": "Play / Pause",
		"song_start": "Song Start",
		"song_end": "Song End",
		"prev_beat": "Previous Beat",
		"next_beat": "Next Beat",
		"prev_measure": "Previous Measure",
		"next_measure": "Next Measure",
		"quantize": "Quantize",
	}
	return map_ru.get(action, map_en.get(action, action.capitalize())) if ru else map_en.get(action, action.capitalize())

func _tr_section_label(section_id: String) -> String:
	var key := "CHART_EDITOR_SECTION_" + section_id.to_upper()
	var t := tr(key)
	if t != key and t != "":
		return t
	var ru := TranslationServer.get_locale().begins_with("ru")
	var map_ru := {"editing":"Редактирование","playback":"Воспроизведение","navigation":"Навигация","chart":"Чарт"}
	var map_en := {"editing":"Editing","playback":"Playback","navigation":"Navigation","chart":"Chart"}
	return map_ru.get(section_id, section_id.capitalize()) if ru else map_en.get(section_id, section_id.capitalize())

func present_dialog() -> void:
	visible = true
	_rebuild_content()

func dismiss_dialog() -> void:
	visible = false

func _rebuild_content() -> void:
	if _left_vbox == null or _right_vbox == null:
		# Fallback: try to find via ContentHost
		_content_hbox = get_node_or_null("Container/BodyCenter/CardPanel/CardMargin/VBox/Scroll/ContentHost") as HBoxContainer
		if _content_hbox:
			_left_vbox = _content_hbox.get_node_or_null("LeftVBox") as VBoxContainer
			_right_vbox = _content_hbox.get_node_or_null("RightVBox") as VBoxContainer
		if _left_vbox == null or _right_vbox == null:
			return
	for child in _left_vbox.get_children():
		child.queue_free()
	for child in _right_vbox.get_children():
		child.queue_free()
	_binding_buttons.clear()

	var keymap := SettingsManager.get_chart_editor_keymap()
	var left_sections := ["editing"]
	var right_sections := ["playback", "navigation", "chart"]
	for section_id in left_sections:
		_build_section(_left_vbox, section_id, keymap)
	for section_id in right_sections:
		_build_section(_right_vbox, section_id, keymap)

func _build_section(container: VBoxContainer, section_id: String, keymap: Dictionary) -> void:
	if container == null:
		return
	var section_label := Label.new()
	section_label.text = _tr_section_label(section_id)
	# Заголовки секций должны быть не меньше текста линий (фикс: было 16 < 20)
	section_label.add_theme_font_size_override("font_size", 20)
	var tint_map := {
		"editing": Color(0.86, 0.52, 0.72, 1.0),
		"playback": Color(0.88, 0.54, 0.70, 1.0),
		"navigation": Color(0.82, 0.52, 0.74, 1.0),
		"chart": Color(0.84, 0.50, 0.72, 1.0),
	}
	section_label.add_theme_color_override("font_color", tint_map.get(section_id, Color(0.86, 0.52, 0.72, 1.0)))
	container.add_child(section_label)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 8)
	var hdr_action := Label.new()
	hdr_action.text = "Действие" if TranslationServer.get_locale().begins_with("ru") else "Action"
	hdr_action.custom_minimum_size = Vector2(160, 0)
	hdr_action.size_flags_horizontal = 0
	hdr_action.add_theme_font_size_override("font_size", 17)
	hdr_action.add_theme_color_override("font_color", Color(0.72, 0.78, 0.9, 0.95))
	header.add_child(hdr_action)
	container.add_child(header)

	for action in ChartEditorBindings.SECTIONS.get(section_id, []):
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		row.alignment = BoxContainer.ALIGNMENT_BEGIN
		var action_label := Label.new()
		action_label.text = _tr_action_label(action)
		action_label.custom_minimum_size = Vector2(160, 0)
		action_label.size_flags_horizontal = 0
		action_label.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		action_label.add_theme_font_size_override("font_size", 20)
		action_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		action_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
		row.add_child(action_label)

		var bindings_vbox := VBoxContainer.new()
		bindings_vbox.add_theme_constant_override("separation", 4)
		bindings_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		bindings_vbox.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		bindings_vbox.alignment = BoxContainer.ALIGNMENT_BEGIN
		row.add_child(bindings_vbox)

		var bindings: Array = keymap.get(action, [])
		if bindings.is_empty():
			# если в режиме добавления для этого action — покажем только placeholder
			if _capture_active and _capture_action == action and _capture_index == 0:
				var ph := Button.new()
				ph.custom_minimum_size = Vector2(120, 44)
				ph.add_theme_font_size_override("font_size", 20)
				ph.text = "..."
				ph.disabled = true
				var base_t := _section_base_tint(section_id)
				var border_t := _shaded_border_color(base_t, 0)
				_apply_key_button_border(ph, border_t)
				bindings_vbox.add_child(ph)
				if _capture_button == null:
					_capture_button = ph
					_capture_button_original_text = ""
			else:
				var btn := _create_binding_button(action, 0, {})
				bindings_vbox.add_child(btn)
		else:
			for idx in range(bindings.size()):
				var binding: Dictionary = bindings[idx] if bindings[idx] is Dictionary else {}
				var btn := _create_binding_button(action, idx, binding)
				bindings_vbox.add_child(btn)
			# placeholder для добавления — вертикально под существующими
			if _capture_active and _capture_action == action and _capture_index == bindings.size():
				var ph2 := Button.new()
				ph2.custom_minimum_size = Vector2(120, 44)
				ph2.add_theme_font_size_override("font_size", 20)
				ph2.text = "..."
				ph2.disabled = true
				var base_t2 := _section_base_tint(section_id)
				var border_t2 := _shaded_border_color(base_t2, bindings.size())
				_apply_key_button_border(ph2, border_t2)
				bindings_vbox.add_child(ph2)
				if _capture_button == null:
					_capture_button = ph2
					_capture_button_original_text = ""

		container.add_child(row)

func _create_binding_button(action: String, index: int, binding: Dictionary) -> Control:
	var btn := Button.new()
	btn.custom_minimum_size = Vector2(120, 44)
	btn.add_theme_font_size_override("font_size", 20)
	if binding.is_empty():
		btn.text = "—"
	else:
		btn.text = ChartEditorBindings.binding_to_string(binding)
	var section_id := _section_for_action(action)
	var base_tint := _section_base_tint(section_id)
	var border := _shaded_border_color(base_tint, index)
	_apply_key_button_border(btn, border)
	btn.pressed.connect(_on_binding_button_pressed.bind(action, index, btn))
	btn.gui_input.connect(_on_binding_gui_input.bind(action, index, btn))
	_binding_buttons["%s:%d" % [action, index]] = btn
	return btn

func _on_binding_button_pressed(action: String, index: int, btn: Button) -> void:
	if _capture_active and _capture_button:
		if _capture_button_original_text != "":
			_capture_button.text = _capture_button_original_text
		elif not _capture_old_binding.is_empty():
			_capture_button.text = ChartEditorBindings.binding_to_string(_capture_old_binding)
		else:
			_capture_button.text = "—"
		if _capture_button:
			_capture_button.disabled = false
	_clear_capture_state()
	_capture_active = true
	_capture_action = action
	_capture_index = index
	_capture_button = btn
	_capture_button_original_text = btn.text
	_capture_old_binding = {}
	var km := SettingsManager.get_chart_editor_keymap()
	var arr = km.get(action, [])
	if arr is Array and index >= 0 and index < arr.size():
		_capture_old_binding = (arr[index] as Dictionary).duplicate(true) if arr[index] is Dictionary else {}
	btn.text = tr("CONTROLS_PRESS_COMBO") if tr("CONTROLS_PRESS_COMBO") != "CONTROLS_PRESS_COMBO" else "Нажмите комбинацию..."
	btn.disabled = true

func _on_add_binding_pressed(action: String, btn: Button) -> void:
	if _capture_active and _capture_button:
		if _capture_button_original_text != "":
			_capture_button.text = _capture_button_original_text
		elif not _capture_old_binding.is_empty():
			_capture_button.text = ChartEditorBindings.binding_to_string(_capture_old_binding)
		else:
			_capture_button.text = "—" if _capture_button.text != "+" else "+"
		if _capture_button:
			_capture_button.disabled = false
	_clear_capture_state()
	var km := SettingsManager.get_chart_editor_keymap()
	var arr = km.get(action, [])
	var new_index: int = arr.size() if arr is Array else 0
	_capture_active = true
	_capture_action = action
	_capture_index = new_index
	_capture_button = btn
	_capture_button_original_text = btn.text
	_capture_old_binding = {}
	btn.text = tr("CONTROLS_PRESS_COMBO") if tr("CONTROLS_PRESS_COMBO") != "CONTROLS_PRESS_COMBO" else "Нажмите комбинацию..."
	btn.disabled = true

func _on_remove_binding_pressed(action: String, index: int) -> void:
	if _capture_active:
		_clear_capture_state()
	SettingsManager.remove_chart_editor_binding(action, index)
	_rebuild_content()

func _on_reset_pressed() -> void:
	SettingsManager.reset_chart_editor_keymap_to_default()
	_rebuild_content()

func _on_close_pressed() -> void:
	if MusicManager and MusicManager.has_method("play_modifier_deselect_sound"):
		MusicManager.play_modifier_deselect_sound()
	dismiss_dialog()
	closed.emit()
	queue_free()

func _clear_capture_state() -> void:
	if _capture_button:
		_capture_button.disabled = false
	_capture_active = false
	_capture_action = ""
	_capture_index = -1
	_capture_button = null
	_capture_old_binding = {}
	_capture_button_original_text = ""

func _input(event: InputEvent) -> void:
	if not visible or not _capture_active:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		var ke := event as InputEventKey
		if ke.keycode == KEY_ESCAPE and not ke.ctrl_pressed and not ke.shift_pressed and not ke.alt_pressed:
			var is_new := false
			var km_chk := SettingsManager.get_chart_editor_keymap()
			var arr_chk = km_chk.get(_capture_action, []) as Array
			if _capture_index >= arr_chk.size():
				is_new = true
			if not is_new and _capture_button:
				if _capture_button_original_text != "":
					_capture_button.text = _capture_button_original_text
				elif not _capture_old_binding.is_empty():
					_capture_button.text = ChartEditorBindings.binding_to_string(_capture_old_binding)
				else:
					_capture_button.text = "—"
				_capture_button.disabled = false
			_clear_capture_state()
			if is_new:
				_rebuild_content()
			get_viewport().set_input_as_handled()
			return
		if ke.keycode == KEY_CTRL or ke.keycode == KEY_SHIFT or ke.keycode == KEY_ALT or ke.keycode == KEY_META:
			return
		var sc := int(ke.keycode)
		if sc == 0:
			sc = int(ke.physical_keycode)
		if sc == 0 or sc == KEY_NONE:
			return
		var new_binding := {
			"key": sc,
			"ctrl": ke.ctrl_pressed,
			"shift": ke.shift_pressed,
			"alt": ke.alt_pressed
		}
		var sanitized := ChartEditorBindings.sanitize_binding(new_binding)
		if sanitized.is_empty():
			return
		var km_before := SettingsManager.get_chart_editor_keymap()
		var is_new_index: bool = false
		var arr_before = km_before.get(_capture_action, [])
		if _capture_index >= (arr_before as Array).size():
			is_new_index = true
		if is_new_index:
			SettingsManager.add_chart_editor_binding(_capture_action, sanitized)
		else:
			SettingsManager.set_chart_editor_binding(_capture_action, _capture_index, sanitized)
		_rebuild_content()
		_clear_capture_state()
		get_viewport().set_input_as_handled()

func _on_backdrop_pressed() -> void:
	if _capture_active:
		var is_new := false
		var km_chk := SettingsManager.get_chart_editor_keymap()
		var arr_chk = km_chk.get(_capture_action, []) as Array
		if _capture_index >= arr_chk.size():
			is_new = true
		if not is_new and _capture_button:
			if _capture_button_original_text != "":
				_capture_button.text = _capture_button_original_text
			elif not _capture_old_binding.is_empty():
				_capture_button.text = ChartEditorBindings.binding_to_string(_capture_old_binding)
			else:
				_capture_button.text = "—"
			_capture_button.disabled = false
		_clear_capture_state()
		if is_new:
			_rebuild_content()
		return
	dismiss_dialog()
	closed.emit()
	queue_free()

func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		if _capture_active:
			return
		dismiss_dialog()
		closed.emit()
		get_viewport().set_input_as_handled()
