# scenes/shop/components/shop_collection_card.gd
extends PanelContainer

signal pressed(collection_id: String)

const _ShopCollectionLocale = preload("res://logic/i18n/shop_collection_locale.gd")
const _UiIconHelper = preload("res://logic/ui/ui_icon_helper.gd")

const ICON_FALLBACKS := {
	"leaf.svg": "earth.svg",
	"flower-2.svg": "heart-pulse.svg",
}
const ICON_FRAME_SIZE := 44
const ICON_INNER_SIZE := 26

var collection_data: Dictionary = {}
var _unlocked := 0
var _total := 0
var _selected := false
var _accent := Color("#52b788")
var _icon_frame: PanelContainer

@onready var _top_row: HBoxContainer = $Margin/MainVBox/TopRow
@onready var _name_label: Label = $Margin/MainVBox/TopRow/TextVBox/NameLabel
@onready var _tagline_label: Label = $Margin/MainVBox/TopRow/TextVBox/TaglineLabel
@onready var _progress_bar: ProgressBar = $Margin/MainVBox/ProgressRow/ProgressBar
@onready var _progress_label: Label = $Margin/MainVBox/ProgressRow/ProgressLabel


func _ready() -> void:
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	gui_input.connect(_on_gui_input)


func setup(collection: Dictionary, unlocked: int, total: int) -> void:
	collection_data = collection
	_unlocked = unlocked
	_total = total
	_accent = _parse_accent(str(collection.get("accent_color", "#52b788")))
	if is_node_ready():
		_apply_content()
		_apply_selection_visual()
	else:
		call_deferred("_apply_content")
		call_deferred("_apply_selection_visual")


func refresh_progress(unlocked: int, total: int) -> void:
	_unlocked = unlocked
	_total = total
	_update_progress()


func apply_locale() -> void:
	_apply_content()


func set_selected(selected: bool) -> void:
	_selected = selected
	_apply_selection_visual()


func get_collection_id() -> String:
	return str(collection_data.get("collection_id", ""))


func _apply_content() -> void:
	if collection_data.is_empty():
		return
	var icon_file := str(collection_data.get("icon", ""))
	if ICON_FALLBACKS.has(icon_file):
		icon_file = ICON_FALLBACKS[icon_file]
	_ensure_icon_frame(icon_file)
	if _name_label:
		_name_label.text = _ShopCollectionLocale.localized_short_name(collection_data).to_upper()
	if _tagline_label:
		_tagline_label.text = _ShopCollectionLocale.localized_tagline(collection_data)
	_update_progress()
	_apply_icon_frame_tint()


func _update_progress() -> void:
	if _progress_bar:
		_progress_bar.max_value = maxf(float(_total), 1.0)
		_progress_bar.value = float(_unlocked)
		_style_progress_bar(_progress_bar, _accent)
	if _progress_label:
		_progress_label.text = "%d / %d" % [_unlocked, _total]


func _apply_icon_frame_tint() -> void:
	if _icon_frame:
		_UiIconHelper.set_frame_tint(_icon_frame, _accent, _selected)


func _ensure_icon_frame(icon_file: String) -> void:
	if _top_row == null:
		return
	if _icon_frame == null or not is_instance_valid(_icon_frame) or _icon_frame.get_parent() != _top_row:
		var legacy := _top_row.get_node_or_null("IconFrame")
		var insert_idx := 0
		if legacy:
			insert_idx = legacy.get_index()
			legacy.queue_free()
		_icon_frame = _UiIconHelper.make_icon_frame(
			icon_file if icon_file != "" else "earth.svg",
			ICON_FRAME_SIZE,
			ICON_INNER_SIZE,
			_accent
		)
		_icon_frame.name = "IconFrame"
		_top_row.add_child(_icon_frame)
		_top_row.move_child(_icon_frame, insert_idx)
	else:
		_icon_frame.set_meta("ui_icon_file", icon_file)
		_icon_frame.set_meta("ui_icon_tint", _accent)
		var icon_rect := _icon_frame.get_meta("ui_icon_rect") as TextureRect
		if icon_rect and icon_file != "":
			icon_rect.texture = _UiIconHelper.load_tinted_icon(icon_file, _accent.lightened(0.08))


func _apply_selection_visual() -> void:
	var box := StyleBoxFlat.new()
	box.bg_color = Color(_accent.r, _accent.g, _accent.b, 0.14 if _selected else 0.08)
	box.set_border_width_all(2 if _selected else 1)
	box.border_color = _accent.lightened(0.12 if _selected else 0.0)
	box.border_color.a = 0.95 if _selected else 0.22
	box.set_corner_radius_all(12)
	box.content_margin_left = 12.0
	box.content_margin_right = 12.0
	box.content_margin_top = 10.0
	box.content_margin_bottom = 10.0
	add_theme_stylebox_override("panel", box)
	_apply_icon_frame_tint()


func _style_progress_bar(bar: ProgressBar, accent: Color) -> void:
	var track := StyleBoxFlat.new()
	track.bg_color = Color(0.09, 0.1, 0.14, 1)
	track.set_corner_radius_all(4)
	var fill := StyleBoxFlat.new()
	fill.bg_color = accent
	fill.set_corner_radius_all(4)
	bar.add_theme_stylebox_override("background", track)
	bar.add_theme_stylebox_override("fill", fill)


func _parse_accent(hex: String) -> Color:
	var color := Color.from_string(hex, Color("#52b788"))
	if color.a <= 0.001:
		color.a = 1.0
	return color


func _on_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed:
			var cid := get_collection_id()
			if cid != "":
				pressed.emit(cid)
