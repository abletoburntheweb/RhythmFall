# scenes/help/help_screen.gd
extends BaseScreen

const HELP_CONTENT_USER_PATH := "user://help_content.json"
const HELP_CONTENT_DEFAULT_PATH := "res://data/help_content.json"
const HELP_SECTION_SCENE := preload("res://scenes/help/help_section.tscn")
const HELP_CALLOUT_SCENE := preload("res://scenes/help/help_callout.tscn")
const HELP_FLOW_SCENE := preload("res://scenes/help/help_flow.tscn")
const HELP_SHOWCASE_SCENE := preload("res://scenes/help/help_showcase.tscn")
const _HelpFlow = preload("res://scenes/help/help_flow.gd")
const _HelpShowcase = preload("res://scenes/help/help_showcase.gd")
const _HelpLocale = preload("res://logic/i18n/help_locale.gd")
const _HelpContentParser = preload("res://scenes/help/lib/help_content_parser.gd")
const _HelpModList = preload("res://scenes/help/lib/help_mod_list.gd")
const _HelpTypography = preload("res://scenes/help/lib/help_typography.gd")
const _UiListSlideTransition = preload("res://logic/ui/ui_list_slide_transition.gd")

const BODY_BULLET_INDENT := 16.0

const ACCENT_TEAL := Color(0.38, 0.78, 0.74, 1.0)
const ACCENT_MINT := Color(0.62, 0.86, 0.72, 1.0)

const SECTION_META := {
	"start": {"icon": "circle-play.svg", "color": Color(0.98, 0.64, 0.31, 1.0)},
	"server": {"icon": "server.svg", "color": ACCENT_TEAL},
	"generation": {"icon": "sparkles.svg", "color": ACCENT_MINT},
	"instruments": {"icon": "drum.svg", "color": Color(0.38, 0.78, 0.74, 1.0)},
	"gameplay": {"icon": "gamepad-2.svg", "color": Color(0.42, 0.57, 0.82, 1.0)},
	"library": {"icon": "music.svg", "color": Color(0.66, 0.58, 0.86, 1.0)},
	"progress": {"icon": "trophy.svg", "color": Color(0.92, 0.78, 0.45, 1.0)},
	"play_modes": {"icon": "layout-dashboard.svg", "color": Color(0.66, 0.58, 0.86, 1.0)},
}

@onready var nav_list: VBoxContainer = $MainVBox/BodyHBox/SidebarPanel/SidebarVBox/NavScroll/NavList
@onready var nav_scroll: ScrollContainer = $MainVBox/BodyHBox/SidebarPanel/SidebarVBox/NavScroll
@onready var back_button: Button = $MainVBox/TopBar/BackButton
@onready var title_label: Label = $MainVBox/TopBar/TitleVBox/TitleLabel
@onready var subtitle_label: Label = $MainVBox/TopBar/TitleVBox/SubtitleLabel
@onready var search_bar: LineEdit = $MainVBox/BodyHBox/SidebarPanel/SidebarVBox/SearchBar
@onready var sidebar_empty_label: Label = $MainVBox/BodyHBox/SidebarPanel/SidebarVBox/SidebarEmptyLabel
@onready var category_badge: PanelContainer = $MainVBox/BodyHBox/ArticlePanel/ArticleMargin/ArticleVBox/ArticleHeaderRow/CategoryBadge
@onready var category_badge_label: Label = $MainVBox/BodyHBox/ArticlePanel/ArticleMargin/ArticleVBox/ArticleHeaderRow/CategoryBadge/CategoryBadgeLabel
@onready var page_label: Label = $MainVBox/BodyHBox/ArticlePanel/ArticleMargin/ArticleVBox/ArticleHeaderRow/PaginationHBox/PageLabel
@onready var prev_button: Button = $MainVBox/BodyHBox/ArticlePanel/ArticleMargin/ArticleVBox/ArticleHeaderRow/PaginationHBox/PrevButton
@onready var next_button: Button = $MainVBox/BodyHBox/ArticlePanel/ArticleMargin/ArticleVBox/ArticleHeaderRow/PaginationHBox/NextButton
@onready var article_title_label: Label = $MainVBox/BodyHBox/ArticlePanel/ArticleMargin/ArticleVBox/ArticleTitleLabel
@onready var article_summary_label: Label = $MainVBox/BodyHBox/ArticlePanel/ArticleMargin/ArticleVBox/ArticleSummaryLabel
@onready var article_scroll: ScrollContainer = $MainVBox/BodyHBox/ArticlePanel/ArticleMargin/ArticleVBox/ArticleScroll
@onready var article_body_vbox: VBoxContainer = $MainVBox/BodyHBox/ArticlePanel/ArticleMargin/ArticleVBox/ArticleScroll/ArticleBodyVBox
@onready var article_footer_vbox: VBoxContainer = $MainVBox/BodyHBox/ArticlePanel/ArticleMargin/ArticleVBox/ArticleFooterVBox
@onready var related_header_label: Label = $MainVBox/BodyHBox/ArticlePanel/ArticleMargin/ArticleVBox/ArticleFooterVBox/RelatedHeaderLabel
@onready var related_buttons_vbox: VBoxContainer = $MainVBox/BodyHBox/ArticlePanel/ArticleMargin/ArticleVBox/ArticleFooterVBox/RelatedButtonsVBox
@onready var links_header_label: Label = $MainVBox/BodyHBox/ArticlePanel/ArticleMargin/ArticleVBox/ArticleFooterVBox/LinksHeaderLabel
@onready var links_buttons_vbox: VBoxContainer = $MainVBox/BodyHBox/ArticlePanel/ArticleMargin/ArticleVBox/ArticleFooterVBox/LinksButtonsVBox
@onready var article_placeholder_label: Label = $MainVBox/BodyHBox/ArticlePanel/ArticleMargin/ArticleVBox/ArticlePlaceholderLabel
@onready var footer_label: Label = $MainVBox/FooterLabel
@onready var sidebar_panel: PanelContainer = $MainVBox/BodyHBox/SidebarPanel
@onready var body_hbox: HBoxContainer = $MainVBox/BodyHBox
@onready var article_panel: PanelContainer = $MainVBox/BodyHBox/ArticlePanel

var _help_colors: Dictionary = {}
var _sections_cache: Array = []
var _search_query := ""
var _bbcode_strip_re: RegEx
var _help_skip_transition := true

var _section_nodes: Array[HelpSection] = []
var _current_section: HelpSection = null
var _current_section_title := ""
var _current_items: Array = []
var _current_item_index := -1
var _pending_item_id := ""
var _nav_scroll_generation := 0
var _article_layout_generation := 0
var _article_sync_width := -1.0
var _article_sync_busy := false
var _footer_summary_label: Label = null
var _search_revision := 0
const _SEARCH_DEBOUNCE_SEC := 0.12
var _suppress_search_handler := false


func _ready() -> void:
	add_to_group("locale_refresh")
	_bbcode_strip_re = RegEx.new()
	_bbcode_strip_re.compile("\\[[^\\]]*\\]")
	_setup_ui_icons()
	_apply_layout_balance()
	if article_scroll and not article_scroll.resized.is_connected(_on_article_scroll_resized):
		article_scroll.resized.connect(_on_article_scroll_resized)
	if article_body_vbox:
		article_body_vbox.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		article_body_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if article_panel:
		article_panel.clip_contents = true
		article_panel.custom_minimum_size.x = 0.0
	if article_scroll:
		article_scroll.custom_minimum_size = Vector2.ZERO
	set_process_input(true)
	if article_scroll:
		article_scroll.focus_mode = Control.FOCUS_NONE
	if nav_scroll:
		nav_scroll.focus_mode = Control.FOCUS_NONE


func _input(event: InputEvent) -> void:
	if _try_handle_nav_input(event):
		accept_event()


func _try_handle_nav_input(event: InputEvent) -> bool:
	if not (event is InputEventKey) or not event.pressed or event.echo:
		return false
	if search_bar and search_bar.has_focus():
		return false
	if UiScreenHotkeys.should_block_hotkeys(get_viewport()):
		return false
	if event.keycode >= KEY_1 and event.keycode <= KEY_6:
		var index := int(event.keycode - KEY_1)
		return _select_section_by_index(index)
	if _section_nodes.is_empty():
		return false
	match event.keycode:
		KEY_UP, KEY_LEFT:
			return _navigate_question(-1)
		KEY_DOWN, KEY_RIGHT:
			return _navigate_question(1)
	return false


func apply_locale() -> void:
	if back_button:
		back_button.text = tr("BTN_BACK")
	if title_label:
		title_label.text = tr("HELP_TITLE")
	if subtitle_label:
		subtitle_label.text = tr("HELP_SUBTITLE")
	if search_bar:
		search_bar.placeholder_text = tr("HELP_SEARCH_PLACEHOLDER")
	if sidebar_empty_label:
		sidebar_empty_label.text = tr("HELP_SEARCH_EMPTY")
	if article_placeholder_label:
		article_placeholder_label.text = tr("HELP_SELECT_TOPIC")
	if footer_label:
		footer_label.text = tr("HELP_FOOTER_HINT")
	if related_header_label:
		related_header_label.text = tr("HELP_RELATED_HEADER")
		_HelpTypography.apply_label(related_header_label, _HelpTypography.SIZE_BODY, Color(0.58, 0.64, 0.74, 0.95))
	if links_header_label:
		links_header_label.text = tr("HELP_LINKS_HEADER")
		_HelpTypography.apply_label(links_header_label, _HelpTypography.SIZE_BODY, Color(0.58, 0.64, 0.74, 0.95))
	if article_title_label:
		_HelpTypography.apply_label(article_title_label, 32)
	if category_badge_label:
		_HelpTypography.apply_label(category_badge_label, _HelpTypography.SIZE_CAPTION, Color(0.38, 0.78, 0.74, 1.0))
	var was_first := _help_skip_transition
	_rebuild_help_items()
	if was_first:
		_help_skip_transition = false


func _setup_ui_icons() -> void:
	if search_bar:
		UiIconHelper.setup_search_field(search_bar)


func _apply_layout_balance() -> void:
	if sidebar_panel:
		sidebar_panel.custom_minimum_size.x = 420.0
		sidebar_panel.size_flags_stretch_ratio = 0.42
	if article_panel:
		article_panel.size_flags_stretch_ratio = 0.58


func apply_contextual_overlay_layout() -> void:
	# Full-screen help over the current host (keep host alive). Soft dim only.
	var bg := get_node_or_null("Background") as ColorRect
	if bg:
		bg.color = Color(0.02, 0.03, 0.05, 0.72)
		bg.mouse_filter = Control.MOUSE_FILTER_STOP
	var main := get_node_or_null("MainVBox") as Control
	if main:
		main.set_anchors_preset(Control.PRESET_FULL_RECT)
		main.set_offsets_preset(Control.PRESET_FULL_RECT)
		main.offset_left = 24.0
		main.offset_top = 10.0
		main.offset_right = -24.0
		main.offset_bottom = -10.0
	_apply_layout_balance()
	set_meta("help_contextual_overlay", true)


func _execute_close_transition() -> void:
	if transitions:
		var parent_node := get_parent()
		var from_overlay := bool(get_meta("help_contextual_overlay", false))
		if parent_node and parent_node.has_method("open_help_topic"):
			from_overlay = true
		elif transitions.game_engine and transitions.game_engine.current_screen:
			if parent_node == transitions.game_engine.current_screen:
				from_overlay = true
		if transitions.game_engine and parent_node == transitions.game_engine:
			from_overlay = true
		if parent_node and (
			parent_node.has_method("set_active_modifiers")
			or parent_node.has_method("set_current_song_data")
			or parent_node.has_signal("selector_closed")
			or parent_node.has_signal("screen_closed")
		):
			from_overlay = true
		if from_overlay:
			transitions.close_help(true)
		else:
			transitions.open_main_menu()
	else:
		get_tree().change_scene_to_file("res://scenes/main_menu/main_menu.tscn")


func _on_search_text_changed(new_text: String) -> void:
	if _suppress_search_handler:
		return
	_search_query = new_text
	_schedule_search_rebuild()


func _on_search_text_submitted(new_text: String) -> void:
	if _suppress_search_handler:
		return
	_search_query = new_text
	_search_revision += 1
	_rebuild_help_items()


func _schedule_search_rebuild() -> void:
	_search_revision += 1
	var revision := _search_revision
	await get_tree().create_timer(_SEARCH_DEBOUNCE_SEC).timeout
	if revision != _search_revision:
		return
	_rebuild_help_items()


func set_initial_search(query: String) -> void:
	if query.strip_edges() == "":
		return
	if search_bar:
		search_bar.text = query
	_search_query = query
	_rebuild_help_items()


func open_item_by_id(item_id: String) -> void:
	var target := item_id.strip_edges()
	if target == "":
		return
	if search_bar and search_bar.text.strip_edges() != "":
		_suppress_search_handler = true
		search_bar.text = ""
		_search_query = ""
		_suppress_search_handler = false
	_pending_item_id = target
	_rebuild_help_items()


func _rebuild_help_items() -> void:
	if nav_list == null:
		return
	_nav_scroll_generation += 1
	if _pending_item_id == "":
		_store_selection_for_restore()
	var rebuild := func() -> void:
		for child in nav_list.get_children():
			nav_list.remove_child(child)
			child.queue_free()
		_section_nodes.clear()
		_current_section = null
		_current_items = []
		_current_item_index = -1
		_setup_help_items()
	if nav_scroll:
		_UiListSlideTransition.crossfade(nav_scroll, rebuild, _help_skip_transition)
	else:
		rebuild.call()


func _store_selection_for_restore() -> void:
	if _current_item_index >= 0 and _current_item_index < _current_items.size():
		_pending_item_id = str(_current_items[_current_item_index].get("id", ""))


func _setup_help_items() -> void:
	var data: Dictionary = _load_help_content()
	_help_colors = data.get("colors", {})
	_sections_cache = data.get("sections", [])
	if not (_sections_cache is Array):
		_sections_cache = []

	var visible_sections := 0
	var query_active := _search_query.strip_edges() != ""
	var first_section: HelpSection = null
	var first_item: Dictionary = {}

	for section in _sections_cache:
		if not (section is Dictionary):
			continue
		var sec_title := _HelpLocale.localized_section_title(section)
		if sec_title.strip_edges() == "":
			continue
		var filtered_items := _filter_items_for_section(section)
		if query_active and filtered_items.is_empty():
			continue
		var section_node := _add_help_category(section, filtered_items, query_active)
		if section_node == null:
			continue
		visible_sections += 1
		if first_section == null:
			first_section = section_node
			if not filtered_items.is_empty() and filtered_items[0] is Dictionary:
				first_item = filtered_items[0]

	if sidebar_empty_label:
		sidebar_empty_label.visible = query_active and visible_sections == 0

	_restore_or_select_default(first_section, first_item)


func _restore_or_select_default(first_section: HelpSection, first_item: Dictionary) -> void:
	var restored := false
	if _pending_item_id != "":
		for section_node in _section_nodes:
			for item in section_node.get_items():
				if not (item is Dictionary):
					continue
				if str(item.get("id", "")) == _pending_item_id:
					for i in range(_section_nodes.size()):
						_section_nodes[i].set_expanded(_section_nodes[i] == section_node, false)
					_select_item_in_section(section_node, item)
					restored = true
					break
			if restored:
				break
	_pending_item_id = ""

	if restored:
		return
	if first_section != null and not first_item.is_empty():
		first_section.set_expanded(true, false)
		_select_item_in_section(first_section, first_item)
	else:
		_show_article_placeholder()


func _filter_items_for_section(section: Dictionary) -> Array:
	var items: Array = section.get("items", [])
	if not (items is Array):
		return []
	var query := _search_query.strip_edges().to_lower()
	if query == "":
		return items

	var sec_title := _HelpLocale.localized_section_title(section).to_lower()
	var section_matches := sec_title.contains(query)
	var out: Array = []
	for item in items:
		if not (item is Dictionary):
			continue
		if section_matches or _item_matches_query(item, query):
			out.append(item)
	return out


func _item_matches_query(item: Dictionary, query: String) -> bool:
	var title_text := _HelpLocale.localized_item_title(item).to_lower()
	var content_text := _plain_help_text(_HelpLocale.localized_item_content(item)).to_lower()
	return title_text.contains(query) or content_text.contains(query)


func _plain_help_text(text: String) -> String:
	var stripped := _HelpContentParser.strip_callouts(text)
	var resolved := _resolve_colors(stripped, _help_colors)
	if _bbcode_strip_re:
		return _bbcode_strip_re.sub(resolved, "", true)
	return resolved


func _load_help_content() -> Dictionary:
	_ensure_user_help_content()
	var path := HELP_CONTENT_USER_PATH if FileAccess.file_exists(HELP_CONTENT_USER_PATH) else _default_help_path()
	if path == "":
		push_warning("HelpScreen: не найден файл справки")
		return {}
	return _read_help_json(path)


func _read_help_json(path: String) -> Dictionary:
	if path == "" or not FileAccess.file_exists(path):
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
	var default_path := _default_help_path()
	if default_path == "":
		return
	var should_copy := not FileAccess.file_exists(HELP_CONTENT_USER_PATH)
	if not should_copy:
		var default_data := _read_help_json(default_path)
		var user_data := _read_help_json(HELP_CONTENT_USER_PATH)
		var default_version := int(default_data.get("version", 0))
		var user_version := int(user_data.get("version", 0))
		if default_version > user_version:
			should_copy = true
		elif default_version == user_version:
			should_copy = _help_content_text_differs(default_path, HELP_CONTENT_USER_PATH)
	if not should_copy:
		return
	if not _copy_help_content_file(default_path, HELP_CONTENT_USER_PATH):
		push_warning("HelpScreen: не удалось обновить справку в user://")


func _help_content_text_differs(src_path: String, dst_path: String) -> bool:
	var src := FileAccess.open(src_path, FileAccess.READ)
	if src == null:
		return false
	var src_txt := src.get_as_text()
	src.close()
	if not FileAccess.file_exists(dst_path):
		return true
	var dst := FileAccess.open(dst_path, FileAccess.READ)
	if dst == null:
		return true
	var dst_txt := dst.get_as_text()
	dst.close()
	return src_txt != dst_txt


func _copy_help_content_file(src_path: String, dst_path: String) -> bool:
	var src := FileAccess.open(src_path, FileAccess.READ)
	if src == null:
		return false
	var txt := src.get_as_text()
	src.close()
	var dst := FileAccess.open(dst_path, FileAccess.WRITE)
	if dst == null:
		return false
	dst.store_string(txt)
	dst.close()
	return true


func _resolve_colors(text: String, colors: Dictionary) -> String:
	var result := text
	for key in colors.keys():
		result = result.replace("{%s}" % key, str(colors[key]))
	return result


func _section_meta(section: Dictionary) -> Dictionary:
	var sid := str(section.get("id", ""))
	if SECTION_META.has(sid):
		return SECTION_META[sid]
	return {"icon": "circle-question-mark.svg", "color": ACCENT_TEAL}


func _add_help_category(section: Dictionary, items: Array, auto_expand: bool) -> HelpSection:
	if items.is_empty():
		return null

	var meta := _section_meta(section)
	var section_node := HELP_SECTION_SCENE.instantiate() as HelpSection
	section_node.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	nav_list.add_child(section_node)
	section_node.configure(section, items, auto_expand, meta.color, meta.icon)
	if not section_node.question_selected.is_connected(_on_section_question_selected):
		section_node.question_selected.connect(_on_section_question_selected.bind(section_node))
	_section_nodes.append(section_node)
	return section_node


func _on_section_question_selected(item: Dictionary, section_node: HelpSection) -> void:
	_select_item_in_section(section_node, item)


func _select_item_in_section(section_node: HelpSection, item: Dictionary, scroll_sidebar: bool = true) -> void:
	if not (item is Dictionary) or section_node == null:
		return
	for node in _section_nodes:
		if node != section_node:
			node.set_selected_item_id("")
	_current_section = section_node
	_current_section_title = _HelpLocale.localized_section_title(section_node.get_section())
	_current_items = section_node.get_items()
	_current_item_index = _index_of_item(item)
	section_node.set_selected_item_id(str(item.get("id", "")))
	_display_current_item()
	if scroll_sidebar:
		call_deferred("_scroll_selected_question_into_view")


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey) or not event.pressed:
		super._unhandled_input(event)
		return
	if event.echo:
		return
	if event.keycode == KEY_ESCAPE or event.is_action_pressed("ui_cancel"):
		super._unhandled_input(event)
		return


func _select_section_by_index(index: int) -> bool:
	if index < 0 or index >= _section_nodes.size():
		return false
	var section_node := _section_nodes[index]
	var items := section_node.get_items()
	if items.is_empty():
		return false
	for i in range(_section_nodes.size()):
		_section_nodes[i].set_expanded(i == index, false)
	var item: Dictionary = items[0]
	_select_item_in_section(section_node, item, false)
	UiScreenHotkeys.play_section_switch_sound()
	call_deferred("_scroll_selected_question_into_view")
	return true


func _navigate_question(delta: int) -> bool:
	var entries := _build_flat_nav_entries()
	if entries.is_empty():
		return false
	var current := _flat_nav_index_of_current(entries)
	if current < 0:
		current = 0 if delta >= 0 else entries.size() - 1
		_select_flat_nav_entry(entries[current])
		return true
	var new_index := current + delta
	if new_index < 0 or new_index >= entries.size():
		return false
	_select_flat_nav_entry(entries[new_index])
	return true


func _build_flat_nav_entries() -> Array:
	var entries: Array = []
	for section_node in _section_nodes:
		var items := section_node.get_items()
		for i in range(items.size()):
			if items[i] is Dictionary:
				entries.append({"section": section_node, "index": i, "item": items[i]})
	return entries


func _flat_nav_index_of_current(entries: Array) -> int:
	if _current_section == null or _current_item_index < 0:
		return -1
	for i in range(entries.size()):
		var entry: Dictionary = entries[i]
		if entry.get("section") == _current_section and int(entry.get("index", -1)) == _current_item_index:
			return i
	return -1


func _select_flat_nav_entry(entry: Dictionary) -> void:
	if not (entry is Dictionary):
		return
	var section_node: HelpSection = entry.get("section")
	var item: Dictionary = entry.get("item", {})
	if section_node == null or item.is_empty():
		return
	for i in range(_section_nodes.size()):
		_section_nodes[i].set_expanded(_section_nodes[i] == section_node, false)
	_select_item_in_section(section_node, item, false)
	UiScreenHotkeys.play_section_switch_sound()
	call_deferred("_scroll_selected_question_into_view")


func _scroll_selected_question_into_view() -> void:
	if _current_section == null or nav_scroll == null:
		return
	var target := _current_section.get_selected_nav_control()
	if target == null:
		target = _current_section
	_ensure_control_visible_in_nav_scroll(target)


func _ensure_control_visible_in_nav_scroll(control: Control) -> void:
	if control == null or nav_scroll == null or not is_instance_valid(control):
		return
	var generation := _nav_scroll_generation
	var control_id := control.get_instance_id()
	await get_tree().process_frame
	if generation != _nav_scroll_generation:
		return
	if nav_scroll == null or not is_instance_valid(nav_scroll):
		return
	control = instance_from_id(control_id) as Control
	if control == null or not is_instance_valid(control) or not control.is_inside_tree():
		return
	var scroll_rect := nav_scroll.get_global_rect()
	var ctrl_rect := control.get_global_rect()
	var margin := 10.0
	if ctrl_rect.position.y < scroll_rect.position.y + margin:
		nav_scroll.scroll_vertical += int(ctrl_rect.position.y - scroll_rect.position.y - margin)
	elif ctrl_rect.end.y > scroll_rect.end.y - margin:
		nav_scroll.scroll_vertical += int(ctrl_rect.end.y - scroll_rect.end.y + margin)
	nav_scroll.scroll_vertical = maxi(0, nav_scroll.scroll_vertical)


func _index_of_item(item: Dictionary) -> int:
	var target_id := str(item.get("id", ""))
	for i in range(_current_items.size()):
		var entry: Dictionary = _current_items[i]
		if str(entry.get("id", "")) == target_id:
			return i
	return 0


func _display_current_item() -> void:
	if _current_item_index < 0 or _current_item_index >= _current_items.size():
		_show_article_placeholder()
		return
	var item: Dictionary = _current_items[_current_item_index]
	_show_article(item)
	_update_pagination()


func _show_article(item: Dictionary) -> void:
	if not (item is Dictionary):
		_show_article_placeholder()
		return
	var item_title := _HelpLocale.localized_item_title(item)
	var content := _resolve_colors(_HelpLocale.localized_item_content(item), _help_colors)
	var summary := _resolve_colors(_HelpLocale.localized_item_summary(item), _help_colors)
	if article_placeholder_label:
		article_placeholder_label.visible = false
	if category_badge:
		category_badge.visible = true
	if category_badge_label:
		category_badge_label.text = _current_section_title
	if _current_section:
		_apply_category_badge_style(_section_meta(_current_section.get_section()).color)
	if article_title_label:
		article_title_label.text = item_title
		article_title_label.visible = true
	if article_summary_label:
		article_summary_label.visible = false
	if article_scroll:
		article_scroll.visible = true
	_reset_article_layout_width()
	_build_article_body(content)
	_build_article_footer(item, summary)
	call_deferred("_sync_article_body_height")


func _clear_vbox(container: VBoxContainer) -> void:
	if container == null:
		return
	for child in container.get_children():
		container.remove_child(child)
		child.queue_free()


func _prepare_article_block(node: Control) -> void:
	if node == null:
		return
	node.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	node.size_flags_horizontal = Control.SIZE_EXPAND_FILL


func _build_article_body(content: String) -> void:
	_article_layout_generation += 1
	_article_sync_width = -1.0
	_clear_vbox(article_body_vbox)
	if article_body_vbox:
		article_body_vbox.custom_minimum_size = Vector2.ZERO
	if article_body_vbox == null:
		return
	for segment in _HelpContentParser.parse(content):
		if not (segment is Dictionary):
			continue
		if segment.get("type") == "callout":
			var callout := HELP_CALLOUT_SCENE.instantiate() as HelpCallout
			_prepare_article_block(callout)
			article_body_vbox.add_child(callout)
			var body := _resolve_colors(str(segment.get("text", "")), _help_colors)
			callout.setup(str(segment.get("callout_type", "info")), body)
		elif segment.get("type") == "flow":
			var flow = HELP_FLOW_SCENE.instantiate()
			match str(segment.get("flow_type", "")):
				"split":
					flow.setup_split(segment.get("left", {}), segment.get("right", {}), _help_colors)
				"branch":
					flow.setup_branch(segment.get("hub", {}), segment.get("arms", []), _help_colors)
				_:
					flow.setup_linear(segment.get("steps", []), _help_colors)
			_prepare_article_block(flow)
			article_body_vbox.add_child(flow)
		elif segment.get("type") == "showcase":
			var showcase = HELP_SHOWCASE_SCENE.instantiate()
			var params: Dictionary = segment.get("params", {})
			if not (params is Dictionary):
				params = {}
			if showcase.has_method("setup"):
				showcase.setup(str(segment.get("showcase_kind", "")), params)
			_prepare_article_block(showcase)
			article_body_vbox.add_child(showcase)
		elif segment.get("type") == "mod_list":
			var mod_params: Dictionary = segment.get("params", {})
			if not (mod_params is Dictionary):
				mod_params = {}
			var mod_list_text := _resolve_colors(
				HelpContentParser.normalize_inline_markup(_HelpModList.bbcode_for_params(mod_params)),
				_help_colors,
			)
			if mod_list_text.strip_edges() != "":
				_add_article_text_block(mod_list_text, true)
		elif segment.get("type") == "text":
			var chunk := str(segment.get("text", "")).strip_edges()
			if chunk == "":
				continue
			_add_article_text_block(_resolve_colors(chunk, _help_colors), _text_has_bullet_lines(chunk))
	_layout_article_blocks_immediate()


func _add_article_text_block(text: String, bullet_indent: bool) -> void:
	var label := RichTextLabel.new()
	label.bbcode_enabled = true
	label.fit_content = true
	label.scroll_active = false
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	label.add_theme_color_override("default_color", _HelpTypography.COLOR_BODY)
	_HelpTypography.apply_richtext(label, _HelpTypography.SIZE_BODY)
	label.text = text
	if bullet_indent:
		var margin := MarginContainer.new()
		margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		margin.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		margin.add_theme_constant_override("margin_left", int(BODY_BULLET_INDENT))
		margin.add_child(label)
		_prepare_article_block(margin)
		article_body_vbox.add_child(margin)
	else:
		_prepare_article_block(label)
		article_body_vbox.add_child(label)


func _text_has_bullet_lines(text: String) -> bool:
	for line in text.split("\n", false):
		var trimmed := line.strip_edges()
		if trimmed.begins_with("·") or trimmed.begins_with("* "):
			return true
	return false


func _reset_article_layout_width() -> void:
	_article_sync_width = -1.0
	if article_panel:
		article_panel.custom_minimum_size.x = 0.0
	if article_scroll:
		article_scroll.custom_minimum_size = Vector2.ZERO
	if article_body_vbox:
		article_body_vbox.custom_minimum_size = Vector2.ZERO


func _estimate_article_width() -> float:
	var body_w := 0.0
	if body_hbox and body_hbox.size.x > 80.0:
		body_w = body_hbox.size.x
	elif is_inside_tree():
		body_w = get_viewport().get_visible_rect().size.x
	if body_w <= 80.0:
		return 520.0
	var sidebar_w := 420.0
	if sidebar_panel:
		sidebar_w = maxf(sidebar_panel.custom_minimum_size.x, sidebar_panel.size.x)
	var sep := 14.0
	if body_hbox:
		sep = float(body_hbox.get_theme_constant("separation", "HBoxContainer"))
	return clampf(body_w - sidebar_w - sep - 56.0, 280.0, 640.0)


func _layout_article_blocks_immediate() -> void:
	if article_body_vbox == null:
		return
	var width := _estimate_article_width()
	_article_sync_width = width
	for child in article_body_vbox.get_children():
		if not is_instance_valid(child):
			continue
		_prepare_article_block(child as Control)
		if child is RichTextLabel or child is MarginContainer:
			_layout_text_block(child, width)
		elif child is HelpCallout:
			child.custom_minimum_size.x = width
		elif child.get_script() == _HelpFlow:
			if child.has_method("finalize_layout"):
				child.finalize_layout(width)
		elif child.get_script() == _HelpShowcase and child.has_method("apply_content_width"):
			child.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			child.custom_minimum_size.x = 0.0
			child.apply_content_width(width)
		else:
			_layout_text_block(child, width)


func _layout_text_block(node: Control, width: float) -> void:
	if node is RichTextLabel:
		var rtl := node as RichTextLabel
		rtl.custom_minimum_size = Vector2(width, 0.0)
		rtl.custom_minimum_size.y = maxf(rtl.get_content_height(), 24.0)
	elif node is MarginContainer:
		var inner_w := maxf(width - BODY_BULLET_INDENT, 200.0)
		for sub in node.get_children():
			if sub is RichTextLabel:
				var rtl := sub as RichTextLabel
				rtl.custom_minimum_size = Vector2(inner_w, 0.0)
				rtl.custom_minimum_size.y = maxf(rtl.get_content_height(), 24.0)


func _build_article_footer(item: Dictionary, summary: String = "") -> void:
	_clear_footer_summary()
	_clear_vbox(related_buttons_vbox)
	_clear_vbox(links_buttons_vbox)
	var has_related := false
	var has_links := false
	var summary_text := summary.strip_edges()
	if summary_text != "":
		_footer_summary_label = Label.new()
		_footer_summary_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_footer_summary_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_HelpTypography.apply_label(_footer_summary_label, _HelpTypography.SIZE_BODY, Color(0.7, 0.75, 0.84, 1.0))
		_footer_summary_label.text = summary_text
		if article_footer_vbox:
			article_footer_vbox.add_child(_footer_summary_label)
			article_footer_vbox.move_child(_footer_summary_label, 0)
	var related: Array = item.get("related", [])
	if related is Array:
		for rel_id in related:
			var rel_item := _find_item_dict(str(rel_id))
			if rel_item.is_empty():
				continue
			has_related = true
			var btn := _make_footer_link_button(_HelpLocale.localized_item_title(rel_item))
			btn.pressed.connect(_on_related_item_pressed.bind(str(rel_id)))
			related_buttons_vbox.add_child(btn)
	var links: Array = item.get("links", [])
	if links is Array:
		for link in links:
			if not (link is Dictionary):
				continue
			var action := str(link.get("action", "")).strip_edges()
			if action == "":
				continue
			has_links = true
			var label := _HelpLocale.localized_link_label(link)
			if label.strip_edges() == "":
				label = tr(_default_link_label_key(action))
			var btn := _make_footer_link_button(label)
			btn.pressed.connect(_on_help_link_pressed.bind(action))
			links_buttons_vbox.add_child(btn)
	if article_footer_vbox:
		article_footer_vbox.visible = has_related or has_links or summary_text != ""
	if related_header_label:
		related_header_label.visible = has_related
	if related_buttons_vbox:
		related_buttons_vbox.visible = has_related
	if links_header_label:
		links_header_label.visible = has_links
	if links_buttons_vbox:
		links_buttons_vbox.visible = has_links


func _make_footer_link_button(text: String) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn.custom_minimum_size = Vector2(0, 42)
	btn.focus_mode = Control.FOCUS_NONE
	var box := StyleBoxFlat.new()
	box.bg_color = Color(0.09, 0.1, 0.14, 0.65)
	box.border_color = Color(1, 1, 1, 0.08)
	box.set_border_width_all(1)
	box.set_corner_radius_all(8)
	box.content_margin_left = 12.0
	box.content_margin_right = 12.0
	box.content_margin_top = 8.0
	box.content_margin_bottom = 8.0
	for state in ["normal", "hover", "pressed", "focus"]:
		btn.add_theme_stylebox_override(state, box)
	_HelpTypography.apply_font_control(btn, _HelpTypography.SIZE_BODY, Color(0.78, 0.84, 0.92, 1.0))
	return btn


func _clear_footer_summary() -> void:
	if _footer_summary_label != null and is_instance_valid(_footer_summary_label):
		if _footer_summary_label.get_parent():
			_footer_summary_label.get_parent().remove_child(_footer_summary_label)
		_footer_summary_label.queue_free()
	_footer_summary_label = null


func _default_link_label_key(action: String) -> String:
	return "HELP_LINK_%s" % action.replace(":", "_").to_upper()


func _find_item_dict(item_id: String) -> Dictionary:
	for section in _sections_cache:
		if not (section is Dictionary):
			continue
		for entry in section.get("items", []):
			if entry is Dictionary and str(entry.get("id", "")) == item_id:
				return entry
	return {}


func _on_related_item_pressed(item_id: String) -> void:
	open_item_by_id(item_id)
	UiScreenHotkeys.play_section_switch_sound()


func _on_help_link_pressed(action: String) -> void:
	if action.begins_with("help:"):
		open_item_by_id(action.substr(5))
		return
	if action.begins_with("settings:") and transitions:
		transitions.open_settings_with_page(action.substr(9))


func _show_article_placeholder() -> void:
	_article_layout_generation += 1
	_reset_article_layout_width()
	_clear_footer_summary()
	if category_badge:
		category_badge.visible = false
	if article_title_label:
		article_title_label.visible = false
	if article_summary_label:
		article_summary_label.visible = false
	if article_scroll:
		article_scroll.visible = false
	if article_footer_vbox:
		article_footer_vbox.visible = false
	_clear_vbox(article_body_vbox)
	if article_placeholder_label:
		article_placeholder_label.visible = true
	if page_label:
		page_label.text = ""
	if prev_button:
		prev_button.disabled = true
	if next_button:
		next_button.disabled = true


func _apply_category_badge_style(accent: Color) -> void:
	if category_badge == null:
		return
	var box := StyleBoxFlat.new()
	box.set_corner_radius_all(999)
	box.content_margin_left = 10.0
	box.content_margin_right = 10.0
	box.content_margin_top = 4.0
	box.content_margin_bottom = 4.0
	box.bg_color = Color(accent.r, accent.g, accent.b, 0.16)
	box.set_border_width_all(1)
	box.border_color = Color(accent.r, accent.g, accent.b, 0.45)
	category_badge.add_theme_stylebox_override("panel", box)
	if category_badge_label:
		category_badge_label.add_theme_color_override("font_color", accent)


func _on_article_scroll_resized() -> void:
	if article_scroll == null or not article_scroll.visible or _article_sync_busy:
		return
	if article_body_vbox == null or article_body_vbox.get_child_count() == 0:
		return
	var width := _estimate_article_width()
	if _article_sync_width >= 0.0:
		if absf(width - _article_sync_width) < 2.0:
			return
		# Ignore width growth caused by wide showcase content (feedback loop).
		if width > _article_sync_width + 2.0:
			return
	call_deferred("_sync_article_body_height")


func _sync_article_body_height() -> void:
	if article_body_vbox == null or article_scroll == null or _article_sync_busy:
		return
	_article_sync_busy = true
	var generation := _article_layout_generation
	await get_tree().process_frame
	if generation != _article_layout_generation:
		_article_sync_busy = false
		return
	if article_body_vbox == null or article_scroll == null:
		_article_sync_busy = false
		return
	var width := _estimate_article_width()
	_article_sync_width = width
	for child in article_body_vbox.get_children():
		if generation != _article_layout_generation:
			_article_sync_busy = false
			return
		if not is_instance_valid(child):
			continue
		_prepare_article_block(child as Control)
		if child is RichTextLabel or child is MarginContainer:
			_layout_text_block(child, width)
		elif child is HelpCallout:
			child.custom_minimum_size.x = width
		elif child.get_script() == _HelpFlow and child.has_method("finalize_layout"):
			child.finalize_layout(width)
		elif child.get_script() == _HelpShowcase and child.has_method("apply_content_width"):
			child.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			child.custom_minimum_size.x = 0.0
			child.apply_content_width(width)
		else:
			_layout_text_block(child, width)
	if generation == _article_layout_generation and article_scroll and is_instance_valid(article_scroll):
		article_scroll.scroll_vertical = 0
		if article_panel:
			article_panel.custom_minimum_size.x = 0.0
		article_scroll.custom_minimum_size = Vector2.ZERO
	_article_sync_busy = false


func _update_pagination() -> void:
	var entries := _build_flat_nav_entries()
	var total := entries.size()
	var current := _flat_nav_index_of_current(entries)
	if page_label:
		if total <= 0 or current < 0:
			page_label.text = ""
		else:
			page_label.text = "%d / %d" % [current + 1, total]
	if prev_button:
		prev_button.disabled = current <= 0
	if next_button:
		next_button.disabled = current >= total - 1


func _on_prev_article_pressed() -> void:
	_navigate_question(-1)


func _on_next_article_pressed() -> void:
	_navigate_question(1)
