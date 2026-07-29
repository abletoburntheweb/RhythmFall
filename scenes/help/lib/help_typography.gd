# scenes/help/lib/help_typography.gd
extends RefCounted
class_name HelpTypography

const INTER_FONT_PATH := "res://ui/fonts/Inter-VariableFont_opsz,wght.ttf"

const SIZE_BODY := 22
const SIZE_SUBTITLE := 18
const SIZE_CAPTION := 17
const SIZE_SMALL := 15
const SIZE_MICRO := 13
const SIZE_ARROW := 22
const SIZE_DISPLAY := 28

const COLOR_BODY := Color(0.86, 0.89, 0.94, 1.0)
const COLOR_MUTED := Color(0.72, 0.78, 0.88, 1.0)
const COLOR_DIM := Color(0.62, 0.7, 0.82, 0.95)
const COLOR_FAINT := Color(0.5, 0.56, 0.66, 0.9)

static var _font: Font


static func font() -> Font:
	if _font == null:
		_font = load(INTER_FONT_PATH) as Font
	return _font


static func apply_label(
	label: Label,
	size: int = SIZE_BODY,
	color: Color = COLOR_BODY,
) -> void:
	apply_font_control(label, size, color)


## Works for any Control that uses "font" / "font_size" / "font_color" theme items
## (Label, Button, LineEdit, etc.).
static func apply_font_control(
	control: Control,
	size: int = SIZE_BODY,
	color: Color = COLOR_BODY,
) -> void:
	var f := font()
	if f != null:
		control.add_theme_font_override("font", f)
	control.add_theme_font_size_override("font_size", size)
	control.add_theme_color_override("font_color", color)


static func apply_richtext(
	label: RichTextLabel,
	size: int = SIZE_BODY,
	color: Color = COLOR_BODY,
) -> void:
	var f := font()
	if f != null:
		label.add_theme_font_override("normal_font", f)
		label.add_theme_font_override("bold_font", f)
		label.add_theme_font_override("italics_font", f)
		label.add_theme_font_override("bold_italics_font", f)
		label.add_theme_font_override("mono_font", f)
	label.add_theme_font_size_override("normal_font_size", size)
	label.add_theme_font_size_override("bold_font_size", size)
	label.add_theme_font_size_override("italics_font_size", size)
	label.add_theme_font_size_override("bold_italics_font_size", size)
	label.add_theme_font_size_override("mono_font_size", size)
	label.add_theme_color_override("default_color", color)
