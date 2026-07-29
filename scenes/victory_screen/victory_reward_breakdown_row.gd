# scenes/victory_screen/victory_reward_breakdown_row.gd
extends HBoxContainer

const _UiIconHelper = preload("res://logic/ui/ui_icon_helper.gd")

@onready var _icon: TextureRect = $Icon
@onready var _title: Label = $TitleLabel
@onready var _bar: Control = $BarSlot/RewardBar
@onready var _value: Label = $ValueLabel


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func configure(
	icon_file: String,
	icon_color: Color,
	title_text: String,
	amount: float,
	max_amount: float,
	accent: Color,
	hide_when_zero: bool = true
) -> void:
	var visible_row := not hide_when_zero or amount > 0.001
	visible = visible_row
	if not visible_row:
		return
	if _icon:
		if icon_file.strip_edges() != "":
			_icon.texture = _UiIconHelper.load_tinted_icon(icon_file, icon_color, 40)
			_icon.visible = _icon.texture != null
		else:
			_icon.texture = null
			_icon.visible = false
	if _title:
		_title.text = title_text
	if _value:
		_value.text = _format_amount(amount)
		_value.add_theme_color_override("font_color", accent.lightened(0.08))
	if _bar and _bar.has_method("set_fill"):
		var ratio := amount / maxf(max_amount, 0.001)
		_bar.set_fill(ratio, accent)


static func _format_amount(amount: float) -> String:
	if absf(amount - roundf(amount)) < 0.05:
		return "+%d" % int(roundf(amount))
	return "+%.1f" % amount
