# scenes/victory_screen/victory_accuracy_details.gd
# Окно «ТОЧНОСТЬ • БЕТА»: посекционная разбивка точности прогона по секциям
# RhythmDNA чарта. Открывается кликом по плитке ТОЧНОСТЬ на экране победы.
extends Control

const _RhythmDnaView = preload("res://logic/data/rhythm_dna_view.gd")

const COLOR_VALUE := Color(0.9, 0.94, 0.98, 1.0)
const COLOR_MUTED := Color(0.58, 0.64, 0.74, 0.92)
const COLOR_GOOD := Color(0.42, 0.9, 0.78, 1.0)
const COLOR_MID := Color(0.55, 0.78, 0.98, 1.0)
const COLOR_WARN := Color(0.95, 0.82, 0.42, 1.0)
const COLOR_LOW := Color(0.94, 0.44, 0.5, 1.0)
const ACCENT := Color(0.34902, 0.819608, 0.745098, 1.0)

const HERO_ICON_FILE := "crosshair.svg"

@onready var hero_icon: TextureRect = $CenterWrap/DialogPanel/Margin/DialogVBox/HeaderHBox/HeroIcon
@onready var title_label: Label = $CenterWrap/DialogPanel/Margin/DialogVBox/HeaderHBox/HeaderText/TitleLabel
@onready var subtitle_label: Label = $CenterWrap/DialogPanel/Margin/DialogVBox/HeaderHBox/HeaderText/SubtitleLabel
@onready var rows_vbox: VBoxContainer = $CenterWrap/DialogPanel/Margin/DialogVBox/RowsVBox
@onready var footer_total_label: Label = $CenterWrap/DialogPanel/Margin/DialogVBox/FooterHBox/FooterTotalLabel
@onready var footer_value_label: Label = $CenterWrap/DialogPanel/Margin/DialogVBox/FooterHBox/FooterValueLabel
@onready var close_button: Button = $CenterWrap/DialogPanel/Margin/DialogVBox/CloseButton

signal details_closed

var _section_accuracy: Array = []
var _overall_accuracy: float = 0.0


func _ready() -> void:
	add_to_group("locale_refresh")
	visible = false
	_apply_hero_icon()
	close_button.pressed.connect(_on_back_pressed)
	UiClick.connect_clicked(self, _on_back_pressed)
	UiIconHelper.configure_button_icon(close_button, "arrow-left.svg", Color(0.85, 0.9, 0.97, 1.0), 16)
	_stabilize_close_button(close_button)
	call_deferred("apply_locale")


func _apply_hero_icon() -> void:
	if hero_icon == null:
		return
	var tex := UiIconHelper.load_tinted_icon(HERO_ICON_FILE, ACCENT, UiIconHelper.raster_size_for_display(72))
	if tex:
		hero_icon.texture = tex
		hero_icon.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR


func apply_locale() -> void:
	if title_label:
		title_label.text = tr("VICTORY_ACC_DETAIL_TITLE").to_upper()
	if subtitle_label:
		subtitle_label.text = tr("VICTORY_ACC_DETAIL_SUBTITLE")
	if footer_total_label:
		footer_total_label.text = tr("VICTORY_ACC_DETAIL_TOTAL").to_upper()
	if close_button:
		close_button.text = tr("VICTORY_REWARD_BTN_CLOSE").to_upper()
	_rebuild_rows()


func show_details(section_accuracy: Array, overall_accuracy: float) -> void:
	_section_accuracy = section_accuracy
	_overall_accuracy = overall_accuracy
	_rebuild_rows()
	visible = true
	grab_focus()


func _rebuild_rows() -> void:
	if rows_vbox == null:
		return
	for child in rows_vbox.get_children():
		child.queue_free()
	for entry in _section_accuracy:
		if entry is Dictionary:
			rows_vbox.add_child(_build_row(entry as Dictionary))
	if footer_value_label:
		footer_value_label.text = "%.1f%%" % _overall_accuracy


func _build_row(entry: Dictionary) -> Control:
	var row := HBoxContainer.new()
	row.custom_minimum_size = Vector2(0, 34)
	row.add_theme_constant_override("separation", 12)

	var title := Label.new()
	title.text = _RhythmDnaView.format_section_headline(entry)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.add_theme_font_size_override("font_size", 15)
	title.add_theme_color_override("font_color", COLOR_VALUE)
	row.add_child(title)

	var hits := int(entry.get("hits", 0))
	var misses := int(entry.get("misses", 0))
	var total := hits + misses

	var stats := Label.new()
	if total > 0:
		stats.text = tr("VICTORY_ACC_DETAIL_STATS_FMT") % [hits, misses, total]
	else:
		stats.text = tr("VICTORY_ACC_DETAIL_NO_DATA")
	stats.add_theme_font_size_override("font_size", 13)
	stats.add_theme_color_override("font_color", COLOR_MUTED)
	stats.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	row.add_child(stats)

	var acc := Label.new()
	acc.custom_minimum_size = Vector2(80, 0)
	acc.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	acc.add_theme_font_size_override("font_size", 15)
	if total > 0:
		var pct := float(hits) / float(total) * 100.0
		acc.text = "%.1f%%" % pct
		acc.add_theme_color_override("font_color", _accuracy_color(pct))
	else:
		acc.text = "—"
		acc.add_theme_color_override("font_color", COLOR_MUTED)
	row.add_child(acc)

	return row


func _accuracy_color(pct: float) -> Color:
	if pct >= 95.0:
		return COLOR_GOOD
	if pct >= 85.0:
		return COLOR_MID
	if pct >= 70.0:
		return COLOR_WARN
	return COLOR_LOW


func _on_back_pressed() -> void:
	if not visible:
		return
	MusicManager.play_modifier_deselect_sound()
	visible = false
	_section_accuracy = []
	emit_signal("details_closed")


func _input(event: InputEvent) -> void:
	if visible and event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		_on_back_pressed()


func _stabilize_close_button(btn: Button) -> void:
	if btn == null:
		return
	btn.icon_alignment = HORIZONTAL_ALIGNMENT_LEFT
	btn.expand_icon = false
	btn.alignment = HORIZONTAL_ALIGNMENT_CENTER
	if btn.has_meta("_ui_hover_enabled"):
		btn.remove_meta("_ui_hover_enabled")
	var base_style := btn.get_theme_stylebox("normal")
	if base_style is StyleBoxFlat:
		var dup := (base_style as StyleBoxFlat).duplicate() as StyleBoxFlat
		for state in ["hover", "pressed", "focus", "disabled"]:
			btn.add_theme_stylebox_override(state, dup)
	btn.pivot_offset = Vector2.ZERO
	btn.scale = Vector2.ONE