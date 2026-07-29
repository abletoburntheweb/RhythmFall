# scenes/song_select/run_modifiers/run_modifier_ce_order_row.gd
extends Button

const _RunModifiers = preload("res://logic/domain/modifiers/run_modifiers.gd")

@onready var _rank: Label = $HBox/RankLabel
@onready var _icon: TextureRect = $HBox/Icon
@onready var _title: Label = $HBox/TitleLabel

var modifier_id: String = ""


func setup(rank: int, p_mod_id: String, title_text: String, selected: bool) -> void:
	modifier_id = p_mod_id
	flat = true
	alignment = HORIZONTAL_ALIGNMENT_LEFT
	if _rank:
		_rank.text = "%d." % rank
	if _title:
		_title.text = title_text
	if _icon:
		var file_name := _RunModifiers.icon_file(p_mod_id)
		if file_name != "":
			_icon.texture = UiIconHelper.load_tinted_icon(
				file_name,
				_RunModifiers.category_tint(p_mod_id, true)
			)
			_icon.visible = true
		else:
			_icon.visible = false
	_set_selected(selected)


func _set_selected(selected: bool) -> void:
	if selected:
		add_theme_color_override("font_color", Color(0.42, 0.92, 0.78, 1.0))
	else:
		remove_theme_color_override("font_color")
