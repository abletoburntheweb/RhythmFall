# scenes/help/help_screen.gd
extends BaseScreen

const HELP_CONTENT_USER_PATH := "user://help_content.json"
const HELP_CONTENT_DEFAULT_PATH := "res://data/help_content.json"

@onready var help_list: VBoxContainer = $MainVBox/ContentContainer/HelpScroll/ScrollBottomMargin/HelpList
@onready var back_button = $MainVBox/BackButton

var help_card_template: HelpCard


func _ready():
	_reparent_help_template_out_of_list()
	help_card_template = $HelpCard as HelpCard
	assert(help_card_template != null, "Нужен узел HelpCard на корне HelpScreen (скрипт help_card.gd).")
	_setup_help_items()


func _reparent_help_template_out_of_list() -> void:
	var hl: Node = help_list
	for i in range(hl.get_child_count() - 1, -1, -1):
		var c: Node = hl.get_child(i)
		if c is HelpCard:
			hl.remove_child(c)
			add_child(c)
			c.visible = false
			c.name = "HelpCard"
			break


func _execute_close_transition() -> void:
	if transitions:
		transitions.open_main_menu()
	else:
		get_tree().change_scene_to_file("res://scenes/main_menu/main_menu.tscn")


func _setup_help_items() -> void:
	var data: Dictionary = _load_help_content()
	var colors: Dictionary = data.get("colors", {})
	var sections = data.get("sections", [])
	if not (sections is Array):
		return
	for section in sections:
		if not (section is Dictionary):
			continue
		var sec_title := str(section.get("title", "")).strip_edges()
		if sec_title == "":
			continue
		var items = section.get("items", [])
		if not (items is Array) or items.size() == 0:
			continue
		var section_inner: VBoxContainer = _add_help_category(sec_title)
		for item in items:
			if not (item is Dictionary):
				continue
			var item_title := str(item.get("title", ""))
			var content := _resolve_colors(str(item.get("content", "")), colors)
			_create_help_item_in(section_inner, item_title, content)


func _load_help_content() -> Dictionary:
	_ensure_user_help_content()
	var path := HELP_CONTENT_USER_PATH if FileAccess.file_exists(HELP_CONTENT_USER_PATH) else _default_help_path()
	if path == "" or not FileAccess.file_exists(path):
		push_warning("HelpScreen: не найден файл справки")
		return {}
	var fa := FileAccess.open(path, FileAccess.READ)
	if fa == null:
		push_warning("HelpScreen: не удалось открыть файл справки: " + path)
		return {}
	var txt := fa.get_as_text()
	fa.close()
	var parsed = JSON.parse_string(txt)
	if not (parsed is Dictionary):
		push_warning("HelpScreen: некорректный JSON справки: " + path)
		return {}
	return parsed


func _default_help_path() -> String:
	if FileAccess.file_exists(HELP_CONTENT_DEFAULT_PATH):
		return HELP_CONTENT_DEFAULT_PATH
	var exe_dir := OS.get_executable_path().get_base_dir()
	var ext := exe_dir.path_join("data/help_content.json").replace("\\", "/")
	if FileAccess.file_exists(ext):
		return ext
	return ""


func _ensure_user_help_content() -> void:
	if FileAccess.file_exists(HELP_CONTENT_USER_PATH):
		return
	var default_path := _default_help_path()
	if default_path == "":
		return
	var src := FileAccess.open(default_path, FileAccess.READ)
	if src == null:
		return
	var txt := src.get_as_text()
	src.close()
	var dst := FileAccess.open(HELP_CONTENT_USER_PATH, FileAccess.WRITE)
	if dst == null:
		push_warning("HelpScreen: не удалось создать файл справки в user://")
		return
	dst.store_string(txt)
	dst.close()


func _resolve_colors(text: String, colors: Dictionary) -> String:
	var result := text
	for key in colors.keys():
		result = result.replace("{%s}" % key, str(colors[key]))
	return result


func _add_help_category(section_title: String) -> VBoxContainer:
	var wrap := VBoxContainer.new()
	wrap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	help_list.add_child(wrap)

	var header := Button.new()
	header.toggle_mode = true
	header.alignment = HORIZONTAL_ALIGNMENT_LEFT
	header.custom_minimum_size.y = 72
	header.add_theme_font_size_override("font_size", 30)
	header.text = "> " + section_title

	var inner := VBoxContainer.new()
	inner.visible = false
	inner.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var title_ref := section_title
	header.toggled.connect(func(pressed: bool):
		inner.visible = pressed
		header.text = ("v " if pressed else "> ") + title_ref
		if pressed:
			header.modulate = Color(0.42, 0.57, 0.82)
		else:
			header.modulate = Color.WHITE
	)

	wrap.add_child(header)
	wrap.add_child(inner)
	return inner


func _create_help_item_in(container: Node, title: String, content: String) -> void:
	var row: HelpCard = help_card_template.duplicate() as HelpCard
	row.visible = true
	container.add_child(row)
	row.setup(title, content)
