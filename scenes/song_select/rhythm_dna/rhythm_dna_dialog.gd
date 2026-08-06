# scenes/song_select/rhythm_dna/rhythm_dna_dialog.gd
extends Control
class_name RhythmDnaDialog

signal closed

const _RhythmDnaDialogContent = preload("res://scenes/song_select/rhythm_dna/rhythm_dna_dialog_content.gd")
const _CoverLoader = preload("res://scenes/song_select/rhythm_dna/lib/rhythm_dna_cover_loader.gd")

@onready var _back_button: Button = $Container/BackButton
@onready var _title_label: Label = $Container/TitleLabel
@onready var _subtitle_label: Label = $Container/SubtitleLabel
@onready var _content_host: VBoxContainer = $Container/BodyCenter/CardPanel/CardMargin/VBox/Scroll/ContentHost
@onready var _close_button: Button = $Container/BodyCenter/CardPanel/CardMargin/VBox/CloseButton

var _dna: Dictionary = {}
var _song_path: String = ""
var _cover: Texture2D = null


func _ready() -> void:
	UiIconHelper.configure_modal_overlay(self, 105)
	if _back_button:
		_back_button.pressed.connect(_on_close_pressed)
	if _close_button:
		_close_button.pressed.connect(_on_close_pressed)
	set_process_input(true)
	call_deferred("apply_locale")
	if not _dna.is_empty():
		_refresh_body()
		_ensure_cover()


func setup(dna: Dictionary, song_path: String = "", cover: Texture2D = null) -> void:
	_dna = dna.duplicate(true) if dna is Dictionary else {}
	_song_path = song_path.strip_edges()
	_cover = cover
	if is_node_ready():
		_refresh_body()
		_ensure_cover()


func apply_locale() -> void:
	if _title_label:
		_title_label.text = tr("DNA_DIALOG_TITLE")
	if _subtitle_label:
		_subtitle_label.text = tr("DNA_DIALOG_SUBTITLE")
	if _back_button:
		_back_button.text = tr("BTN_BACK")
	if _close_button:
		_close_button.text = tr("BTN_OK")
	_refresh_body()


func _ensure_cover() -> void:
	if _cover != null or _song_path == "":
		return
	call_deferred("_load_cover_deferred")


func _load_cover_deferred() -> void:
	if not is_instance_valid(self) or _cover != null or _song_path == "":
		return
	var loaded := _CoverLoader.load_cover(_song_path)
	if loaded == null:
		loaded = _CoverLoader.fallback_cover(_song_path)
	if loaded and is_instance_valid(self):
		_cover = loaded
		_refresh_body()


func _refresh_body() -> void:
	if _content_host == null:
		return
	for child in _content_host.get_children():
		child.free()
	var viewport_w := get_viewport_rect().size.x if is_inside_tree() else 1280.0
	var built: Control = _RhythmDnaDialogContent.build(_dna, _cover, viewport_w)
	_content_host.add_child(built)


func _on_close_pressed() -> void:
	closed.emit()
	queue_free()


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		accept_event()
		_on_close_pressed()
