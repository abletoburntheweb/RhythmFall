# scenes/song_select/manual_track_input.gd
class_name ManualTrackInput
extends Control

signal confirmed
signal cancelled
signal manual_entry_confirmed(artist: String, title: String)

@onready var label_confirmation: Label = $ModalPanel/VBoxContainer/LabelConfirmation
@onready var button_yes: Button = $ModalPanel/VBoxContainer/HBoxContainer/ButtonYes
@onready var button_no: Button = $ModalPanel/VBoxContainer/HBoxContainer/ButtonNo
@onready var line_edit_artist: LineEdit = $ModalPanel/VBoxContainer/LineEditArtist
@onready var line_edit_title: LineEdit = $ModalPanel/VBoxContainer/LineEditTitle
@onready var button_save: Button = $ModalPanel/VBoxContainer/ButtonSave

var expected_artist: String = ""
var expected_title: String = ""

func _ready():
	if not label_confirmation:
		push_error("ManualTrackInput: LabelConfirmation не найден!")
	if not button_yes:
		push_error("ManualTrackInput: ButtonYes не найден!")
	if not button_no:
		push_error("ManualTrackInput: ButtonNo не найден!")
	if not line_edit_artist:
		push_error("ManualTrackInput: LineEditArtist не найден!")
	if not line_edit_title:
		push_error("ManualTrackInput: LineEditTitle не найден!")
	if not button_save:
		push_error("ManualTrackInput: ButtonSave не найден!")

	button_yes.pressed.connect(_on_yes_pressed)
	button_no.pressed.connect(_on_no_pressed)
	line_edit_artist.text_submitted.connect(_on_save_pressed)
	line_edit_title.text_submitted.connect(_on_save_pressed)
	button_save.pressed.connect(_on_save_pressed)

func set_expected_track(artist: String, title: String):
	if label_confirmation:
		expected_artist = artist
		expected_title = title
		label_confirmation.text = "Ваш трек: %s - %s?" % [artist, title]
	else:
		push_error("ManualTrackInput: label_confirmation is null")

func _on_yes_pressed():
	hide() 
	emit_signal("confirmed")

func _on_no_pressed():
	if button_yes: button_yes.hide()
	if button_no: button_no.hide()
	if line_edit_artist: line_edit_artist.show()
	if line_edit_title: line_edit_title.show()
	if button_save: button_save.show()
	if line_edit_artist: line_edit_artist.grab_focus()

func _on_save_pressed(dummy_text := ""): 
	var artist = line_edit_artist.text.strip_edges() if line_edit_artist else ""
	var title = line_edit_title.text.strip_edges() if line_edit_title else ""

	if artist.is_empty() or title.is_empty():
		print("ManualTrackInput.gd: Артист или название пусты.")
		return

	hide()
	emit_signal("manual_entry_confirmed", artist, title)

func _on_gui_input(event):
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var panel_rect = $ModalPanel.get_global_rect() if $ModalPanel else Rect2()
		if not panel_rect.is_empty() and not panel_rect.has_point(get_viewport().get_mouse_position()):
			hide()
			emit_signal("cancelled")

func show_modal_for_track(artist: String, title: String):
	set_expected_track(artist, title)
	if button_yes: button_yes.show()
	if button_no: button_no.show()
	if line_edit_artist: line_edit_artist.hide()
	if line_edit_title: line_edit_title.hide()
	if button_save: button_save.hide()
	show()
	if line_edit_artist: line_edit_artist.text = ""
	if line_edit_title: line_edit_title.text = ""
