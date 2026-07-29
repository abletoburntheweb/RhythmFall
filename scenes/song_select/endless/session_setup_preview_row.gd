# scenes/song_select/endless/session_setup_preview_row.gd
extends HBoxContainer
class_name SessionSetupPreviewRow

const _UiIconHelper = preload("res://logic/ui/ui_icon_helper.gd")

var _icon_host: PanelContainer = null
var _value_label: Label = null


func setup(icon_file: String, text: String, tint: Color = _UiIconHelper.ACCENT) -> void:
	add_theme_constant_override("separation", 10)
	if _icon_host == null:
		_icon_host = _UiIconHelper.make_icon_frame(icon_file, 32, 17, tint)
		_icon_host.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(_icon_host)
	if _value_label == null:
		_value_label = Label.new()
		_value_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_value_label.add_theme_font_size_override("font_size", 14)
		_value_label.add_theme_color_override("font_color", Color(0.72, 0.8, 0.92, 0.95))
		_value_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		add_child(_value_label)
	_value_label.text = text


func set_text(text: String) -> void:
	if _value_label:
		_value_label.text = text


func set_icon(icon_file: String, tint: Color = _UiIconHelper.ACCENT) -> void:
	if _icon_host == null:
		return
	var file := icon_file.strip_edges()
	if file == "":
		return
	_icon_host.set_meta("ui_icon_file", file)
	_icon_host.set_meta("ui_icon_tint", tint)
	_UiIconHelper.set_frame_tint(_icon_host as PanelContainer, tint, false)


func set_tone(tone: String) -> void:
	if _value_label == null:
		return
	match tone:
		"good":
			_value_label.add_theme_font_size_override("font_size", 15)
			_value_label.add_theme_color_override("font_color", Color(0.58, 0.92, 0.78, 1.0))
		"warn":
			_value_label.add_theme_font_size_override("font_size", 15)
			_value_label.add_theme_color_override("font_color", Color(0.95, 0.78, 0.42, 1.0))
		"bad":
			_value_label.add_theme_font_size_override("font_size", 15)
			_value_label.add_theme_color_override("font_color", Color(0.95, 0.48, 0.52, 1.0))
		"hero":
			_value_label.add_theme_font_size_override("font_size", 16)
			_value_label.add_theme_color_override("font_color", Color(0.78, 0.86, 0.98, 1.0))
		_:
			_value_label.add_theme_font_size_override("font_size", 14)
			_value_label.add_theme_color_override("font_color", Color(0.72, 0.8, 0.92, 0.95))
