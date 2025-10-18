# logic/creation.gd
extends Node


func song_select_search_bar(parent: Control) -> LineEdit:
	var search_bar = LineEdit.new()
	search_bar.placeholder_text = "Поиск по названию или исполнителю..."
	search_bar.custom_minimum_size = Vector2(400, 40)
	search_bar.add_theme_color_override("font_color", Color.WHITE)
	search_bar.add_theme_color_override("font_placeholder_color", Color(0.8, 0.8, 0.8, 0.6))
	search_bar.add_theme_stylebox_override("normal", _make_style(Color(0,0,0,0.7), 12, Color(1,1,1,0.5)))
	search_bar.add_theme_stylebox_override("focus", _make_style(Color(0,0,0,0.8), 12, Color(0,0.75,1,1)))
	parent.add_child(search_bar)
	return search_bar

func song_select_song_count_label(parent: Control, count: int) -> Label:
	var label = Label.new()
	label.text = "Песен: %d" % count
	label.add_theme_color_override("font_color", Color.WHITE)
	label.add_theme_font_size_override("font_size", 18)
	parent.add_child(label)
	return label

func song_select_top_bar_button(parent: Control, text: String, callback: Callable) -> Button:
	var btn = Button.new()
	btn.text = text
	btn.custom_minimum_size = Vector2(120, 40)
	_apply_button_style(btn, false)
	btn.pressed.connect(callback)
	parent.add_child(btn)
	return btn

func song_select_edit_button(parent: Control, text: String, callback: Callable, is_active := false) -> Button:
	var btn = Button.new()
	btn.text = text
	btn.custom_minimum_size = Vector2(120, 40)
	_apply_button_style(btn, is_active)
	btn.pressed.connect(callback)
	parent.add_child(btn)
	return btn

func song_select_instrument_button(parent: Control, text: String, callback: Callable, preset := "standard") -> Button:
	var btn = Button.new()
	btn.text = text
	btn.custom_minimum_size = Vector2(250, 60)
	btn.add_theme_font_size_override("font_size", 16)
	btn.add_theme_constant_override("corner_radius", 10)
	match preset:
		"standard":
			_apply_button_color(btn, Color("#4CAF50"), Color("#45a049"), Color("#3d8b40"))
		"drums":
			_apply_button_color(btn, Color("#2196F3"), Color("#1976D2"), Color("#1565C0"))
	btn.pressed.connect(callback)
	parent.add_child(btn)
	return btn

func song_select_list_widget(parent: Control) -> ItemList:
	var list = ItemList.new()
	list.custom_minimum_size = Vector2(400, 300)
	list.add_theme_stylebox_override("panel", _make_style(Color(0,0,0,0.65), 15))
	list.add_theme_color_override("font_color", Color.WHITE)
	list.add_theme_font_size_override("font_size", 20)
	parent.add_child(list)
	return list

func song_select_details_frame(parent: Control) -> Panel:
	var frame = Panel.new()
	frame.custom_minimum_size = Vector2(400, 300)
	frame.add_theme_stylebox_override("panel", _make_style(Color(0,0,0,0.6), 15))
	parent.add_child(frame)
	return frame

func song_select_cover_label(parent: Control) -> TextureRect:
	var cover = TextureRect.new()
	cover.custom_minimum_size = Vector2(400, 400)
	cover.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	cover.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	cover.add_theme_stylebox_override("panel", _make_style(Color(0.5,0.5,0.5,1), 10))
	parent.add_child(cover)
	return cover

func song_select_info_label(parent: Control, text: String, font_size := 22, bold := true) -> Label:
	var label = Label.new()
	label.text = text
	label.add_theme_color_override("font_color", Color.WHITE)
	var font_res = _make_font(bold)
	if font_res != null:
		label.add_theme_font_override("font", font_res)
	label.add_theme_font_size_override("font_size", font_size)

	parent.add_child(label)
	return label

func song_select_action_button(parent: Control, text: String, callback: Callable, fixed_height := 60) -> Button:
	var btn = Button.new()
	btn.text = text
	btn.custom_minimum_size = Vector2(200, fixed_height)
	btn.add_theme_stylebox_override("normal", _make_style(Color(0,0,0,0.5), 10))
	btn.add_theme_stylebox_override("hover", _make_style(Color(1,1,1,0.2), 10))
	btn.pressed.connect(callback)
	parent.add_child(btn)
	return btn

func song_select_separator(parent: Control) -> HSeparator:
	var sep = HSeparator.new()
	sep.custom_minimum_size = Vector2(0, 2)
	sep.add_theme_stylebox_override("separator", _make_style(Color(1,1,1,0.1), 0))
	parent.add_child(sep)
	return sep


func _apply_button_style(btn: Button, active := false):
	var bg_color = Color(0.24, 0.24, 0.24, 0.9) if active else Color(0, 0, 0, 0.7)
	var border_color = Color(1, 1, 1, 0.7) if active else Color(1, 1, 1, 0.5)
	btn.add_theme_stylebox_override("normal", _make_style(bg_color, 12, border_color))
	btn.add_theme_stylebox_override("hover", _make_style(bg_color.lightened(0.2), 12, Color(0,0.75,1,1)))
	btn.add_theme_color_override("font_color", Color.WHITE)
	btn.add_theme_font_size_override("font_size", 18)

func _apply_button_color(btn: Button, normal_color: Color, hover_color: Color, pressed_color: Color):
	btn.add_theme_stylebox_override("normal", _make_style(normal_color, 10))
	btn.add_theme_stylebox_override("hover", _make_style(hover_color, 10))
	btn.add_theme_stylebox_override("pressed", _make_style(pressed_color, 10))
	btn.add_theme_color_override("font_color", Color.WHITE)

func _make_style(bg: Color, radius := 8, border := Color(0,0,0,0)) -> StyleBoxFlat:
	var style = StyleBoxFlat.new()
	style.bg_color = bg
	style.corner_radius_top_left = radius
	style.corner_radius_top_right = radius
	style.corner_radius_bottom_left = radius
	style.corner_radius_bottom_right = radius
	if border.a > 0:
		style.border_color = border
		style.border_width_left = 1
		style.border_width_top = 1
		style.border_width_right = 1
		style.border_width_bottom = 1
	return style


func _make_font(bold := true) -> Font:
	var path := "res://assets/fonts/your_bold_font.ttf"
	if ResourceLoader.exists(path):
		var font_file := load(path) as FontFile
		return font_file
	return null
