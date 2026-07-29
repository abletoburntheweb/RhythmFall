# scenes/marathon/marathon_summary_mods_panel.gd
extends VBoxContainer
class_name MarathonSummaryModsPanel

const _MarathonSessionConfig = preload("res://logic/domain/session/marathon_session_config.gd")
const _EndlessSessionConfig = preload("res://logic/domain/session/endless_session_config.gd")
const _SongSelectUiStyles = preload("res://scenes/song_select/lib/song_select_ui_styles.gd")
const _ModPoolIconScript = preload("res://scenes/song_select/endless/session_mod_pool_icon.gd")
const _RunModifiers = preload("res://logic/domain/modifiers/run_modifiers.gd")

var _accent := Color(0.79, 0.57, 0.35, 1.0)
var _title_label: Label = null
var _fixed_section: VBoxContainer = null
var _fixed_title: Label = null
var _fixed_icons_row: HBoxContainer = null
var _fixed_none_label: Label = null
var _random_section: VBoxContainer = null
var _random_title: Label = null
var _random_summary_label: Label = null
var _pool_section: VBoxContainer = null
var _pool_title: Label = null
var _pool_icons_row: HBoxContainer = null


func _ready() -> void:
	add_theme_constant_override("separation", 6)
	if _title_label == null:
		_build_ui()


func setup(accent: Color) -> void:
	_accent = accent
	if _title_label == null:
		_build_ui()
	if _title_label:
		_title_label.add_theme_color_override("font_color", _accent.lerp(Color.WHITE, 0.12))


func apply_locale() -> void:
	if _title_label:
		_title_label.text = tr("MARATHON_SUMMARY_MODS_TITLE")
	if _fixed_title:
		_fixed_title.text = tr("MARATHON_SUMMARY_MODS_FIXED_TITLE")
	if _random_title:
		_random_title.text = tr("MARATHON_SUMMARY_MODS_RANDOM_TITLE")
	if _pool_title:
		_pool_title.text = tr("MARATHON_SUMMARY_MODS_POOL_TITLE")


func refresh(template: Dictionary, effective_config: Dictionary = {}) -> void:
	if _title_label == null:
		_build_ui()
	var cfg := _MarathonSessionConfig.resolve_effective_run_config(
		effective_config if not effective_config.is_empty() else _MarathonSessionConfig.default_config(),
		template
	)
	var policy := str(cfg.get("mod_policy", _EndlessSessionConfig.MOD_POLICY_NONE))
	_clear_row(_fixed_icons_row)
	_clear_row(_pool_icons_row)

	_fixed_section.visible = false
	_random_section.visible = false
	_pool_section.visible = false
	_fixed_none_label.visible = false

	if policy == _EndlessSessionConfig.MOD_POLICY_NONE:
		_fixed_section.visible = true
		_fixed_none_label.visible = true
		visible = true
		return

	if policy == _EndlessSessionConfig.MOD_POLICY_FIXED:
		_fixed_section.visible = true
		var fixed_ids := _mod_ids_from_pool(cfg.get("mod_pool", []))
		if fixed_ids.is_empty():
			_fixed_none_label.visible = true
		else:
			_populate_mod_icons(_fixed_icons_row, fixed_ids)
		visible = true
		return

	if policy == _EndlessSessionConfig.MOD_POLICY_RANDOM_POOL:
		_random_section.visible = true
		_pool_section.visible = true
		var count := int(cfg.get("mod_random_count", _EndlessSessionConfig.DEFAULT_MOD_RANDOM_COUNT))
		if _random_summary_label:
			_random_summary_label.text = tr("MARATHON_SUMMARY_MODS_RANDOM_FMT") % count
		_populate_mod_icons(_pool_icons_row, _mod_ids_from_pool(cfg.get("mod_pool", [])))
		visible = true
		return

	visible = false


func _mod_ids_from_pool(raw: Variant) -> Array[String]:
	var out: Array[String] = []
	if raw is Array:
		for item in raw:
			var sid := str(item).strip_edges()
			if sid != "" and not out.has(sid):
				out.append(sid)
	return out


func _populate_mod_icons(row: HBoxContainer, mod_ids: Array[String]) -> void:
	if row == null:
		return
	for mod_id in mod_ids:
		var icon := _ModPoolIconScript.new()
		if icon == null:
			continue
		icon.setup(mod_id)
		icon.set_pool_selected(true)
		icon.disabled = false
		icon.focus_mode = Control.FOCUS_NONE
		var title := tr(_RunModifiers.title_i18n_key(mod_id))
		var desc := _RunModifiers.format_modifier_description(mod_id, {}).strip_edges()
		icon.tooltip_text = "%s\n%s" % [title, desc] if desc != "" else title
		row.add_child(icon)


func _clear_row(row: HBoxContainer) -> void:
	if row == null:
		return
	for child in row.get_children():
		child.queue_free()


func _build_ui() -> void:
	for child in get_children():
		child.queue_free()

	_title_label = Label.new()
	_title_label.text = tr("MARATHON_SUMMARY_MODS_TITLE")
	_title_label.add_theme_font_size_override("font_size", 13)
	add_child(_title_label)

	var panel := PanelContainer.new()
	var box := _SongSelectUiStyles.card_panel_style().duplicate() as StyleBoxFlat
	box.bg_color = Color(0.07, 0.09, 0.13, 0.94)
	box.border_color = Color(_accent.r, _accent.g, _accent.b, 0.28)
	box.content_margin_left = 10.0
	box.content_margin_right = 10.0
	box.content_margin_top = 10.0
	box.content_margin_bottom = 10.0
	panel.add_theme_stylebox_override("panel", box)
	add_child(panel)

	var outer := VBoxContainer.new()
	outer.add_theme_constant_override("separation", 10)
	panel.add_child(outer)

	_fixed_section = VBoxContainer.new()
	_fixed_section.add_theme_constant_override("separation", 4)
	_fixed_title = Label.new()
	_fixed_title.text = tr("MARATHON_SUMMARY_MODS_FIXED_TITLE")
	_fixed_title.add_theme_font_size_override("font_size", 11)
	_fixed_title.add_theme_color_override("font_color", Color(0.58, 0.66, 0.78, 0.95))
	_fixed_section.add_child(_fixed_title)
	_fixed_icons_row = HBoxContainer.new()
	_fixed_icons_row.add_theme_constant_override("separation", 8)
	_fixed_section.add_child(_fixed_icons_row)
	outer.add_child(_fixed_section)
	_fixed_none_label = Label.new()
	_fixed_none_label.text = tr("MARATHON_SUMMARY_MODS_NONE")
	_fixed_none_label.add_theme_font_size_override("font_size", 12)
	_fixed_none_label.add_theme_color_override("font_color", Color(0.62, 0.68, 0.78, 0.95))
	_fixed_none_label.visible = false
	_fixed_section.add_child(_fixed_none_label)

	_random_section = VBoxContainer.new()
	_random_section.add_theme_constant_override("separation", 4)
	_random_title = Label.new()
	_random_title.text = tr("MARATHON_SUMMARY_MODS_RANDOM_TITLE")
	_random_title.add_theme_font_size_override("font_size", 11)
	_random_title.add_theme_color_override("font_color", Color(0.58, 0.66, 0.78, 0.95))
	_random_section.add_child(_random_title)
	_random_summary_label = Label.new()
	_random_summary_label.add_theme_font_size_override("font_size", 12)
	_random_summary_label.add_theme_color_override("font_color", Color(0.78, 0.86, 0.96, 0.98))
	_random_section.add_child(_random_summary_label)
	outer.add_child(_random_section)

	_pool_section = VBoxContainer.new()
	_pool_section.add_theme_constant_override("separation", 4)
	_pool_title = Label.new()
	_pool_title.text = tr("MARATHON_SUMMARY_MODS_POOL_TITLE")
	_pool_title.add_theme_font_size_override("font_size", 11)
	_pool_title.add_theme_color_override("font_color", Color(0.58, 0.66, 0.78, 0.95))
	_pool_section.add_child(_pool_title)
	_pool_icons_row = HBoxContainer.new()
	_pool_icons_row.add_theme_constant_override("separation", 8)
	_pool_section.add_child(_pool_icons_row)
	outer.add_child(_pool_section)
