# scenes/profile/tabs/records_tab.gd
extends ScrollContainer

const _ProfileRecordsView = preload("res://scenes/profile/components/profile_records_view.gd")

var screen: ProfileScreen = null

var _records_refresh_running := false

@onready var records_content_vbox: VBoxContainer = get_node_or_null("RecordsContentVBox") as VBoxContainer


func bind(host: ProfileScreen) -> void:
	screen = host


func is_built() -> bool:
	return _ProfileRecordsView.is_built(records_content_vbox)


func refresh_panel() -> void:
	if records_content_vbox == null or _records_refresh_running:
		return
	_records_refresh_running = true
	if screen:
		await screen.with_profile_loading(_rebuild_async)
	_records_refresh_running = false


func rebuild_async() -> void:
	await _rebuild_async()


func get_content_vbox() -> VBoxContainer:
	return records_content_vbox


func focus_section(section_id: String) -> void:
	var sid := str(section_id).strip_edges()
	if sid == "" or records_content_vbox == null:
		return
	await get_tree().process_frame
	for child in records_content_vbox.get_children():
		if child.has_method("get_section_id") and str(child.call("get_section_id")) == sid:
			scroll_vertical = int(maxf(0.0, child.position.y - 8.0))
			break


func _rebuild_async() -> void:
	if records_content_vbox == null:
		return
	await _ProfileRecordsView.rebuild_async(records_content_vbox, _card_style())
	await get_tree().process_frame


func _card_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.094118, 0.094118, 0.121569, 1)
	style.border_color = Color(1, 1, 1, 0.08)
	style.set_border_width_all(1)
	style.set_corner_radius_all(8)
	style.content_margin_left = 12.0
	style.content_margin_top = 10.0
	style.content_margin_right = 12.0
	style.content_margin_bottom = 10.0
	return style
