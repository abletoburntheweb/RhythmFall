extends VBoxContainer

const _UiIconHelper = preload("res://logic/ui/ui_icon_helper.gd")

const COLOR_TITLE := Color(0.419608, 0.568627, 0.823529, 1)

var section_id := ""


func set_section_id(id: String) -> void:
	section_id = str(id).strip_edges()


func get_section_id() -> String:
	return section_id


func set_section_title(title: String, icon_file: String = "", icon_tint: Color = COLOR_TITLE) -> void:
	var label := get_node_or_null("TitleRow/TitleLabel") as Label
	if label:
		label.text = title
	_clear_title_icon()
	if icon_file.strip_edges() != "":
		var row := get_node_or_null("TitleRow") as HBoxContainer
		if row:
			var frame := _UiIconHelper.make_icon_frame(icon_file, 26, 14, icon_tint)
			row.add_child(frame)
			row.move_child(frame, 0)


func _clear_title_icon() -> void:
	var row := get_node_or_null("TitleRow") as HBoxContainer
	if row == null:
		return
	for child in row.get_children():
		if child.name == "TitleLabel":
			continue
		row.remove_child(child)
		child.queue_free()


func set_panel_style(style: StyleBox) -> void:
	var card := get_node_or_null("CardPanel") as PanelContainer
	if card and style:
		card.add_theme_stylebox_override("panel", style)


func get_body() -> VBoxContainer:
	return get_node_or_null("CardPanel/BodyVBox") as VBoxContainer
