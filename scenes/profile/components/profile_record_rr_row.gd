extends VBoxContainer

const _ModifierIconStrip = preload("res://logic/ui/modifier_icon_strip.gd")

const COLOR_CAPTION := Color(0.654902, 0.654902, 0.678431, 1)
const COLOR_VALUE := Color(0.784314, 0.823529, 0.901961, 1)
const COLOR_MUTED := Color(0.55, 0.58, 0.65, 0.92)
const COLOR_RR := Color(0.9490196, 0.7019608, 0.3529412, 1)


func apply_row(
	rank: int,
	rr: int,
	track_line: String,
	meta_line: String,
	show_separator: bool,
	modifiers: Array = []
) -> void:
	var rank_label := get_node_or_null("RowHBox/RankLabel") as Label
	var rr_label := get_node_or_null("RowHBox/InfoVBox/TitleRow/RrLabel") as Label
	var track_label := get_node_or_null("RowHBox/InfoVBox/TitleRow/TrackLabel") as Label
	var meta_label := get_node_or_null("RowHBox/InfoVBox/MetaLabel") as Label
	var mods_row := get_node_or_null("RowHBox/InfoVBox/ModsRow") as HBoxContainer
	var separator := get_node_or_null("Separator") as ColorRect
	if rank_label:
		rank_label.text = "%d." % rank
		rank_label.add_theme_color_override("font_color", COLOR_RR if rank <= 3 else COLOR_CAPTION)
	if rr_label:
		rr_label.text = "%d RR" % rr
	if track_label:
		track_label.text = track_line
	if meta_label:
		meta_label.text = meta_line
		meta_label.visible = meta_line != ""
	if mods_row:
		_ModifierIconStrip.fill_slot_chips(mods_row, modifiers, {}, 8)
		mods_row.visible = modifiers.size() > 0
	if separator:
		separator.visible = show_separator
