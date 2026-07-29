# scenes/song_select/run_modifiers/run_modifier_summary_panel.gd
extends VBoxContainer
class_name RunModifierSummaryPanel

const _RunModifiers = preload("res://logic/domain/modifiers/run_modifiers.gd")

signal confirm_pressed
signal reset_pressed

@onready var _summary_title: Label = $SummaryTitleLabel
@onready var _multiplier_value: Label = $HeroPanel/HeroVBox/MultiplierValueLabel
@onready var _multiplier_caption: Label = $HeroPanel/HeroVBox/MultiplierCaptionLabel
@onready var _mod_count_label: Label = $HeroPanel/HeroVBox/ModCountLabel
@onready var _ease_stat: Label = $StatsRow/EaseStatLabel
@onready var _hard_stat: Label = $StatsRow/HardStatLabel
@onready var _special_stat: Label = $StatsRow/SpecialStatLabel
@onready var _dna_stat: Label = $StatsRow/DnaStatLabel
@onready var _active_header: Label = $ActiveHeader
@onready var _active_area: PanelContainer = $ActiveArea
@onready var _active_scroll: ScrollContainer = $ActiveArea/ActiveStack/ActiveScroll
@onready var _active_vbox: VBoxContainer = $ActiveArea/ActiveStack/ActiveScroll/ActiveVBox
@onready var _empty_panel: PanelContainer = $ActiveArea/ActiveStack/EmptyPanel
@onready var _empty_title: Label = $ActiveArea/ActiveStack/EmptyPanel/EmptyVBox/EmptyTitleLabel
@onready var _empty_hint: Label = $ActiveArea/ActiveStack/EmptyPanel/EmptyVBox/EmptyHintLabel
@onready var _confirm_button: Button = $ConfirmButton
@onready var _reset_button: Button = $ResetButton

@onready var _compact_hidden: Array[CanvasItem] = [
	$SummaryTitleLabel,
	$HeroPanel,
	$StatsRow,
]

var _hide_active_list := false


func _ready() -> void:
	if _confirm_button:
		_confirm_button.pressed.connect(func(): confirm_pressed.emit())
	if _reset_button:
		_reset_button.pressed.connect(func(): reset_pressed.emit())
	if _active_scroll:
		_active_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_RESERVE
	UiIconHelper.setup_confirm_button(_confirm_button)
	UiIconHelper.setup_reset_button(_reset_button)
	UiIconHelper.add_icon_before_label(_multiplier_caption, "diamond.svg", true, Color(0.95, 0.82, 0.45, 1.0))
	call_deferred("apply_locale")


func apply_locale() -> void:
	if _summary_title:
		_summary_title.text = tr("MOD_SUMMARY_TITLE")
	if _multiplier_caption:
		_multiplier_caption.text = tr("MOD_SUMMARY_MULT_CAPTION")
	if _active_header:
		_active_header.text = tr("MOD_SUMMARY_ACTIVE_HEADER")
	if _empty_title:
		_empty_title.text = tr("MOD_SUMMARY_EMPTY_TITLE")
	if _empty_hint:
		_empty_hint.text = tr("MOD_SUMMARY_EMPTY_HINT")
	if _confirm_button:
		_confirm_button.text = tr("MOD_CONFIRM")
	if _reset_button:
		_reset_button.text = tr("MOD_RESET_ALL")
	var mod_ids: Array = get_meta("_last_active_mod_ids", [])
	if not mod_ids.is_empty():
		set_active_modifiers(mod_ids)


func set_summary(
	mult: float,
	active_modifiers: Array,
	ease_count: int,
	hard_count: int,
	special_count: int,
	dna_count: int = 0
) -> void:
	set_meta("_last_active_mod_ids", active_modifiers.duplicate())
	set_multiplier(mult)
	set_category_stats(ease_count, hard_count, special_count, dna_count)
	set_active_modifiers(active_modifiers)


func set_multiplier(mult: float) -> void:
	if _multiplier_value:
		_multiplier_value.text = "%.2f×" % mult


func set_category_stats(
	ease_count: int, hard_count: int, special_count: int, dna_count: int = 0
) -> void:
	var total := ease_count + hard_count + special_count + dna_count
	if _mod_count_label:
		_mod_count_label.text = tr("MOD_SUMMARY_MOD_COUNT") % total
	if _ease_stat:
		_ease_stat.text = tr("MOD_SUMMARY_EASE_STAT") % ease_count
	if _hard_stat:
		_hard_stat.text = tr("MOD_SUMMARY_HARD_STAT") % hard_count
	if _special_stat:
		_special_stat.text = tr("MOD_SUMMARY_SPECIAL_STAT") % special_count
	if _dna_stat:
		_dna_stat.text = tr("MOD_SUMMARY_DNA_STAT") % dna_count
		_dna_stat.visible = true


func set_compact_mode(compact: bool, hide_active: bool = false) -> void:
	_hide_active_list = hide_active
	for node in _compact_hidden:
		if node:
			node.visible = not compact
	if _confirm_button:
		_confirm_button.visible = true
	if _reset_button:
		_reset_button.visible = true
	size_flags_vertical = Control.SIZE_SHRINK_END if compact else Control.SIZE_EXPAND_FILL
	_reapply_active_list_visibility()


func _reapply_active_list_visibility() -> void:
	var mod_ids: Array = get_meta("_last_active_mod_ids", [])
	var has_any := not mod_ids.is_empty()
	var show_list := not _hide_active_list
	if _active_header:
		_active_header.visible = show_list and has_any
	if _active_area:
		_active_area.visible = show_list
	if _empty_panel:
		_empty_panel.visible = show_list and not has_any
	if _active_scroll:
		_active_scroll.visible = show_list and has_any


func show_full_active_list(active_modifiers: Array) -> void:
	_hide_active_list = false
	for node in _compact_hidden:
		if node:
			node.visible = true
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	set_meta("_last_active_mod_ids", active_modifiers.duplicate())
	set_active_modifiers(active_modifiers)


func set_active_modifiers(modifier_ids: Array) -> void:
	if _active_vbox == null:
		return
	for child in _active_vbox.get_children():
		child.queue_free()
	var has_any := not modifier_ids.is_empty()
	if not has_any:
		_reapply_active_list_visibility()
		return
	for raw_id in modifier_ids:
		var mod_id := str(raw_id)
		_active_vbox.add_child(_make_active_row(mod_id))
	_reapply_active_list_visibility()


func _make_active_row(modifier_id: String) -> PanelContainer:
	var row := PanelContainer.new()
	row.custom_minimum_size = Vector2(0, 36)
	var box := StyleBoxFlat.new()
	box.bg_color = Color(0.1, 0.12, 0.17, 0.95)
	box.border_color = Color(1, 1, 1, 0.08)
	box.set_border_width_all(1)
	box.set_corner_radius_all(8)
	box.content_margin_left = 8
	box.content_margin_top = 6
	box.content_margin_right = 8
	box.content_margin_bottom = 6
	row.add_theme_stylebox_override("panel", box)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 10)
	hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(hbox)

	var icon_file := _RunModifiers.icon_file(modifier_id)
	var tint := _RunModifiers.category_tint(modifier_id, true)
	if icon_file.strip_edges() != "":
		var frame := UiIconHelper.make_icon_frame(icon_file, 30, 16, tint)
		hbox.add_child(frame)

	var title := Label.new()
	title.text = tr(_RunModifiers.title_i18n_key(modifier_id))
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.clip_text = true
	title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	title.add_theme_font_size_override("font_size", 14)
	title.add_theme_color_override("font_color", Color(0.86, 0.92, 0.98, 0.98))
	hbox.add_child(title)

	return row
