# ui/status_dock.gd
extends Control
class_name StatusDock

const _UiIconHelper = preload("res://logic/ui/ui_icon_helper.gd")

const KIND_ICONS := {
	"info": "info.svg",
	"progress": "activity.svg",
	"music": "music.svg",
	"drums": "drum.svg",
	"bpm": "metronome.svg",
	"success": "circle-check.svg",
	"error": "triangle-alert.svg",
	"warning": "triangle-alert.svg",
	"save": "database.svg",
	"upload": "upload.svg",
	"queue": "list-checks.svg",
	"scan": "folder-search.svg",
	"network": "refresh-cw.svg",
}

const ICON_TINT := Color(0.62, 0.78, 0.96, 1.0)
const ICON_TINT_MUSIC := Color(0.62, 0.78, 0.96, 1.0)
const ICON_TINT_DRUMS := Color(0.38, 0.78, 0.74, 1.0)
const ICON_TINT_SUCCESS := Color(0.52, 0.9, 0.68, 1.0)
const ICON_TINT_ERROR := Color(0.95, 0.55, 0.48, 1.0)
const ICON_TINT_WARNING := Color(0.96, 0.78, 0.38, 1.0)
const ICON_TINT_SAVE := Color(0.72, 0.76, 0.9, 1.0)
const ICON_TINT_UPLOAD := Color(0.58, 0.82, 0.96, 1.0)
const ICON_TINT_QUEUE := Color(0.72, 0.76, 0.92, 1.0)
const ICON_TINT_SCAN := Color(0.62, 0.86, 0.78, 1.0)
const ICON_TINT_NETWORK := Color(0.66, 0.74, 0.98, 1.0)

const CRITICAL_SOUND_KINDS: Array[String] = ["error"]

const DOCK_MARGIN_LEFT := 10.0
const DOCK_MARGIN_BOTTOM := 24.0
const DOCK_MAX_WIDTH := 560.0
const DOCK_MIN_WIDTH := 280.0
const DOCK_PANEL_SEPARATION := 6.0

@onready var _vbox: VBoxContainer = $VBox
@onready var _secondary_panel: PanelContainer = $VBox/SecondaryPanel
@onready var _secondary_icon: TextureRect = $VBox/SecondaryPanel/Row/Icon
@onready var _secondary_label: Label = $VBox/SecondaryPanel/Row/Label
@onready var _primary_panel: PanelContainer = $VBox/PrimaryPanel
@onready var _primary_icon: TextureRect = $VBox/PrimaryPanel/Body/TopRow/Icon
@onready var _primary_title: Label = $VBox/PrimaryPanel/Body/TopRow/TextCol/Title
@onready var _primary_subtitle: Label = $VBox/PrimaryPanel/Body/TopRow/TextCol/Subtitle
@onready var _primary_progress: ProgressBar = $VBox/PrimaryPanel/Body/ProgressBar
@onready var _action_cancel: LinkButton = $VBox/PrimaryPanel/Body/TopRow/ActionCancel
@onready var _action_retry: LinkButton = $VBox/PrimaryPanel/Body/TopRow/ActionRetry
@onready var _clear_timer: Timer = $ClearTimer

var _secondary_clear_timer: Timer

var _primary_id: String = ""
var _primary_cancel: Callable = Callable()
var _primary_retry: Callable = Callable()
var _primary_operation_visible: bool = false
var _secondary_id: String = ""
var _clear_primary_on_timeout: bool = false
var _panel_tweens: Dictionary = {}
var _primary_panel_normal_style: StyleBoxFlat = null
var _primary_panel_hover_style: StyleBoxFlat = null
var _primary_clickable := false
var _primary_open_hint: Label = null


func _ready() -> void:
	set_process_unhandled_input(true)
	_apply_panel_styles()
	_hide_secondary_immediate()
	_hide_primary_immediate()
	if _clear_timer and not _clear_timer.timeout.is_connected(_on_clear_timeout):
		_clear_timer.timeout.connect(_on_clear_timeout)
	_ensure_secondary_clear_timer()
	_sync_mouse_filters()
	var text_col := get_node_or_null("VBox/PrimaryPanel/Body/TopRow/TextCol") as Control
	if text_col:
		text_col.mouse_filter = Control.MOUSE_FILTER_STOP
		if not text_col.gui_input.is_connected(_on_primary_text_gui_input):
			text_col.gui_input.connect(_on_primary_text_gui_input)
	_ensure_primary_open_hint()
	if _primary_panel:
		if not _primary_panel.gui_input.is_connected(_on_primary_panel_gui_input):
			_primary_panel.gui_input.connect(_on_primary_panel_gui_input)
		if not _primary_panel.mouse_entered.is_connected(_on_primary_panel_mouse_entered):
			_primary_panel.mouse_entered.connect(_on_primary_panel_mouse_entered)
			_primary_panel.mouse_exited.connect(_on_primary_panel_mouse_exited)
	apply_locale()
	call_deferred("_sync_dock_geometry")


func _ensure_secondary_clear_timer() -> void:
	if _secondary_clear_timer != null:
		return
	_secondary_clear_timer = Timer.new()
	_secondary_clear_timer.one_shot = true
	add_child(_secondary_clear_timer)
	_secondary_clear_timer.timeout.connect(_fade_out_and_hide_secondary)


func apply_locale() -> void:
	if _action_cancel:
		_action_cancel.text = tr("STATUS_HINT_CANCEL")
	if _action_retry:
		_action_retry.text = tr("NOTIF_RETRY")


func show_transient(
	id: String,
	text: String,
	kind: String = "info",
	duration_sec: float = 2.5,
	play_sound: bool = true
) -> void:
	if text.strip_edges() == "":
		return
	_secondary_id = id
	_set_icon(_secondary_icon, kind)
	if _secondary_label:
		_secondary_label.text = text
		_secondary_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if _secondary_panel:
		var max_w := maxf(240.0, minf(420.0, get_viewport_rect().size.x - 24.0))
		_secondary_panel.custom_minimum_size.x = max_w
	_fade_in_panel(_secondary_panel)
	if play_sound:
		_play_notification_sound(kind)
	_ensure_secondary_clear_timer()
	_secondary_clear_timer.stop()
	if duration_sec <= 0.0:
		return
	_secondary_clear_timer.wait_time = duration_sec
	_secondary_clear_timer.start()


func show_operation(payload: Dictionary) -> void:
	var op_id := String(payload.get("id", "")).strip_edges()
	if op_id == "":
		return
	var same_op := op_id == _primary_id and _primary_panel and _primary_panel.visible and _primary_operation_visible
	_primary_id = op_id
	_primary_cancel = payload.get("cancel", Callable()) as Callable
	_primary_retry = Callable()
	_primary_operation_visible = true
	_stop_auto_clear_timer()
	_apply_operation_content(payload)
	if _action_retry:
		_action_retry.visible = false
	if same_op:
		return
	_play_notification_sound(String(payload.get("icon_kind", "progress")))
	_fade_in_panel(_primary_panel)
	_sync_generation_click_hint()


func show_operation_message(payload: Dictionary) -> void:
	var op_id := String(payload.get("id", "")).strip_edges()
	if op_id == "":
		return
	var kind := String(payload.get("kind", "info"))
	var text := String(payload.get("text", ""))
	var duration := float(payload.get("duration_sec", 5.0))
	if (
		_primary_panel
		and _primary_panel.visible
		and _primary_id == op_id
		and not _primary_operation_visible
		and _primary_title
		and _primary_title.text == text
	):
		_primary_cancel = payload.get("cancel", Callable()) as Callable
		_primary_retry = payload.get("retry", Callable()) as Callable
		if _action_cancel:
			_action_cancel.visible = _primary_cancel.is_valid() and kind != "success"
		if _action_retry:
			_action_retry.visible = _primary_retry.is_valid() and kind in ["error", "warning"]
		return
	_primary_id = op_id
	_primary_cancel = payload.get("cancel", Callable()) as Callable
	_primary_retry = payload.get("retry", Callable()) as Callable
	_primary_operation_visible = false
	_set_icon(_primary_icon, kind)
	if _primary_title:
		_primary_title.text = text
	if _primary_subtitle:
		_primary_subtitle.text = ""
		_primary_subtitle.visible = false
	if _primary_progress:
		_primary_progress.visible = false
	if _action_cancel:
		_action_cancel.visible = _primary_cancel.is_valid() and kind != "success"
	if _action_retry:
		_action_retry.visible = _primary_retry.is_valid() and kind in ["error", "warning"]
	_play_notification_sound(kind, String(payload.get("sound", "")))
	_fade_in_panel(_primary_panel)
	if duration > 0.0 and kind != "error":
		_clear_primary_on_timeout = true
		if _clear_timer:
			_clear_timer.stop()
			_clear_timer.wait_time = duration
			_clear_timer.start()
	_sync_generation_click_hint()


func clear_operation(op_id: String) -> void:
	if _primary_id != op_id:
		return
	_hide_primary_immediate()
	_primary_id = ""
	_primary_cancel = Callable()
	_primary_retry = Callable()
	_primary_operation_visible = false
	_sync_generation_click_hint()


func clear_immediately() -> void:
	_hide_secondary_immediate()
	_hide_primary_immediate()
	_primary_id = ""
	_secondary_id = ""
	_primary_cancel = Callable()
	_primary_retry = Callable()
	_primary_operation_visible = false
	if _clear_timer:
		_clear_timer.stop()
	if _secondary_clear_timer:
		_secondary_clear_timer.stop()
	_sync_generation_click_hint()
	call_deferred("_sync_dock_geometry")


func _sync_dock_geometry() -> void:
	if not is_inside_tree() or _vbox == null:
		return
	var total_h := 0.0
	if _secondary_panel and _secondary_panel.visible:
		total_h = maxf(total_h, _secondary_panel.get_minimum_size().y)
		if total_h <= 0.0:
			total_h = _secondary_panel.size.y
	if _primary_panel and _primary_panel.visible:
		var primary_h := maxf(_primary_panel.get_minimum_size().y, _primary_panel.size.y)
		if total_h > 0.0:
			total_h += DOCK_PANEL_SEPARATION
		total_h += primary_h
	total_h = maxf(total_h, 1.0)
	var vp := get_viewport_rect().size
	var dock_w := clampf(minf(DOCK_MAX_WIDTH, vp.x - 24.0), DOCK_MIN_WIDTH, vp.x - 24.0)
	offset_left = DOCK_MARGIN_LEFT
	offset_right = DOCK_MARGIN_LEFT + dock_w
	offset_bottom = -DOCK_MARGIN_BOTTOM
	offset_top = offset_bottom - total_h


func _play_notification_sound(kind: String, sound: String = "") -> void:
	if MusicManager == null:
		return
	if sound == "analysis_success":
		if MusicManager.has_method("play_analysis_success"):
			MusicManager.play_analysis_success()
		return
	if kind in CRITICAL_SOUND_KINDS:
		if MusicManager.has_method("play_analysis_error"):
			MusicManager.play_analysis_error()
		return
	if MusicManager.has_method("play_status_toast"):
		MusicManager.play_status_toast()


func _apply_operation_content(payload: Dictionary) -> void:
	var compact := bool(payload.get("compact", false))
	var title := String(payload.get("title", ""))
	var subtitle := String(payload.get("subtitle", ""))
	if compact and subtitle.length() > 48:
		subtitle = subtitle.substr(0, 45) + "..."
	_set_icon(_primary_icon, String(payload.get("icon_kind", "progress")))
	if _primary_title:
		_primary_title.text = title
	if _primary_subtitle:
		_primary_subtitle.text = subtitle
		_primary_subtitle.visible = subtitle.strip_edges() != ""
	var progress := clampf(float(payload.get("progress", 0.0)), 0.0, 1.0)
	if _primary_progress:
		_primary_progress.visible = progress > 0.0 or not compact
		_primary_progress.value = progress * 100.0
	if _action_cancel:
		_action_cancel.visible = _primary_cancel.is_valid()
	_sync_generation_click_hint()


func _ensure_primary_open_hint() -> void:
	if _primary_open_hint != null:
		return
	var body := get_node_or_null("VBox/PrimaryPanel/Body") as VBoxContainer
	if body == null:
		return
	_primary_open_hint = Label.new()
	_primary_open_hint.name = "OpenHint"
	_primary_open_hint.visible = false
	_primary_open_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_primary_open_hint.add_theme_font_size_override("font_size", 11)
	_primary_open_hint.add_theme_color_override("font_color", Color(0.52, 0.82, 0.72, 0.95))
	body.add_child(_primary_open_hint)


func _sync_generation_click_hint() -> void:
	_primary_clickable = _primary_operation_visible and _primary_id in ["bpm", "notes"]
	var text_col := get_node_or_null("VBox/PrimaryPanel/Body/TopRow/TextCol") as Control
	if text_col:
		text_col.mouse_default_cursor_shape = (
			Control.CURSOR_POINTING_HAND if _primary_clickable else Control.CURSOR_ARROW
		)
		text_col.tooltip_text = ""
	if _primary_icon:
		_primary_icon.mouse_filter = Control.MOUSE_FILTER_STOP if _primary_clickable else Control.MOUSE_FILTER_IGNORE
		_primary_icon.mouse_default_cursor_shape = (
			Control.CURSOR_POINTING_HAND if _primary_clickable else Control.CURSOR_ARROW
		)
		_primary_icon.tooltip_text = ""
		if _primary_clickable and not _primary_icon.gui_input.is_connected(_on_primary_text_gui_input):
			_primary_icon.gui_input.connect(_on_primary_text_gui_input)
	if _primary_open_hint:
		_primary_open_hint.text = tr("GEN_QUEUE_OPEN_HINT") if _primary_clickable else ""
		_primary_open_hint.visible = _primary_clickable
	_apply_primary_panel_hover_state(false)


func _apply_panel_styles() -> void:
	_style_panel(_secondary_panel, Color(0.14, 0.18, 0.24, 0.97), Color(0.52, 0.72, 0.58, 0.45))
	_primary_panel_normal_style = _make_panel_style(
		Color(0.12, 0.16, 0.24, 0.97),
		Color(0.42, 0.68, 0.92, 0.5),
	)
	_primary_panel_hover_style = _make_panel_style(
		Color(0.14, 0.19, 0.28, 0.98),
		Color(0.52, 0.82, 0.72, 0.72),
	)
	if _primary_panel:
		_primary_panel.add_theme_stylebox_override("panel", _primary_panel_normal_style)
	if _primary_title:
		_primary_title.add_theme_color_override("font_color", Color(0.94, 0.96, 0.99, 1.0))
	if _primary_subtitle:
		_primary_subtitle.add_theme_color_override("font_color", Color(0.72, 0.8, 0.9, 0.98))
	if _secondary_label:
		_secondary_label.add_theme_color_override("font_color", Color(0.88, 0.94, 0.9, 1.0))
		_secondary_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if _primary_progress:
		var fill := StyleBoxFlat.new()
		fill.bg_color = Color(0.48, 0.82, 0.78, 1.0)
		fill.set_corner_radius_all(3)
		var bg := StyleBoxFlat.new()
		bg.bg_color = Color(0.04, 0.06, 0.1, 0.85)
		bg.set_corner_radius_all(3)
		_primary_progress.add_theme_stylebox_override("fill", fill)
		_primary_progress.add_theme_stylebox_override("background", bg)
		_primary_progress.custom_minimum_size.y = 6.0
		_primary_progress.show_percentage = false


func _style_panel(panel: PanelContainer, bg_color: Color, border_color: Color) -> void:
	if panel == null:
		return
	panel.add_theme_stylebox_override("panel", _make_panel_style(bg_color, border_color))


func _make_panel_style(bg_color: Color, border_color: Color) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = bg_color
	box.border_color = border_color
	box.set_border_width_all(1)
	box.set_corner_radius_all(10)
	box.content_margin_left = 10.0
	box.content_margin_right = 12.0
	box.content_margin_top = 8.0
	box.content_margin_bottom = 8.0
	return box


func _apply_primary_panel_hover_state(hovered: bool) -> void:
	if _primary_panel == null or _primary_panel_normal_style == null:
		return
	if not _primary_clickable:
		_primary_panel.add_theme_stylebox_override("panel", _primary_panel_normal_style)
		return
	var style := _primary_panel_hover_style if hovered else _primary_panel_normal_style
	_primary_panel.add_theme_stylebox_override("panel", style)


func _on_primary_panel_mouse_entered() -> void:
	if _primary_clickable:
		_apply_primary_panel_hover_state(true)


func _on_primary_panel_mouse_exited() -> void:
	_apply_primary_panel_hover_state(false)


func _on_primary_panel_gui_input(event: InputEvent) -> void:
	_on_primary_text_gui_input(event)


func _set_icon(target: TextureRect, kind: String) -> void:
	if target == null:
		return
	var file_name: String = KIND_ICONS.get(kind, KIND_ICONS.info)
	var tint := ICON_TINT
	match kind:
		"success":
			tint = ICON_TINT_SUCCESS
		"error":
			tint = ICON_TINT_ERROR
		"warning":
			tint = ICON_TINT_WARNING
		"save":
			tint = ICON_TINT_SAVE
		"upload":
			tint = ICON_TINT_UPLOAD
		"queue":
			tint = ICON_TINT_QUEUE
		"scan":
			tint = ICON_TINT_SCAN
		"network":
			tint = ICON_TINT_NETWORK
		"music":
			tint = ICON_TINT_MUSIC
		"drums":
			tint = ICON_TINT_DRUMS
	target.texture = _UiIconHelper.load_tinted_icon(file_name, tint)


func _fade_in_panel(panel: Control) -> void:
	if panel == null:
		return
	if _panel_tweens.has(panel) and (_panel_tweens[panel] as Tween).is_valid():
		(_panel_tweens[panel] as Tween).kill()
	panel.visible = true
	panel.modulate.a = 0.0
	panel.pivot_offset = Vector2(0.0, panel.size.y)
	var tw := create_tween()
	_panel_tweens[panel] = tw
	tw.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(panel, "modulate:a", 1.0, 0.18)
	tw.tween_callback(_sync_dock_geometry)
	_sync_mouse_filters()


func _hide_secondary_immediate() -> void:
	_kill_panel_tween(_secondary_panel)
	if _secondary_panel:
		_secondary_panel.visible = false
		_secondary_panel.modulate.a = 1.0
	_secondary_id = ""
	if _secondary_clear_timer:
		_secondary_clear_timer.stop()
	_sync_mouse_filters()
	call_deferred("_sync_dock_geometry")


func _hide_primary_immediate() -> void:
	_kill_panel_tween(_primary_panel)
	if _primary_panel:
		_primary_panel.visible = false
		_primary_panel.modulate.a = 1.0
	_sync_mouse_filters()
	_sync_generation_click_hint()
	call_deferred("_sync_dock_geometry")


func _sync_mouse_filters() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if _vbox:
		_vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if _primary_panel:
		var primary_active := _primary_panel.visible
		_primary_panel.mouse_filter = Control.MOUSE_FILTER_STOP if primary_active else Control.MOUSE_FILTER_IGNORE
	if _secondary_panel:
		var secondary_active := _secondary_panel.visible
		_secondary_panel.mouse_filter = Control.MOUSE_FILTER_STOP if secondary_active else Control.MOUSE_FILTER_IGNORE


func _kill_panel_tween(panel: Control) -> void:
	if panel and _panel_tweens.has(panel):
		var tw_v: Variant = _panel_tweens[panel]
		if tw_v is Tween and (tw_v as Tween).is_valid():
			(tw_v as Tween).kill()
		_panel_tweens.erase(panel)


func _stop_auto_clear_timer() -> void:
	_clear_primary_on_timeout = false
	if _clear_timer:
		_clear_timer.stop()


func _on_clear_timeout() -> void:
	if _primary_retry.is_valid():
		return
	if _clear_primary_on_timeout and not _primary_operation_visible:
		_fade_out_and_hide_primary()


func _fade_out_and_hide_primary() -> void:
	if _primary_panel == null or not _primary_panel.visible:
		return
	var tw := create_tween()
	tw.tween_property(_primary_panel, "modulate:a", 0.0, 0.16)
	tw.tween_callback(_hide_primary_immediate)


func _fade_out_and_hide_secondary() -> void:
	if _secondary_panel == null or not _secondary_panel.visible:
		return
	var tw := create_tween()
	tw.tween_property(_secondary_panel, "modulate:a", 0.0, 0.16)
	tw.tween_callback(_hide_secondary_immediate)


func _on_action_cancel_pressed() -> void:
	if _primary_cancel.is_valid():
		_primary_cancel.call()
	_action_cancel.visible = false
	if not _primary_operation_visible:
		_hide_primary_immediate()
		_primary_id = ""
		_primary_retry = Callable()
		_sync_generation_click_hint()


func _on_action_retry_pressed() -> void:
	if _primary_retry.is_valid():
		_primary_retry.call()
	_action_retry.visible = false


func _on_primary_text_gui_input(event: InputEvent) -> void:
	if not _primary_clickable:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var engine := get_tree().root.get_node_or_null("GameEngine")
		if engine and engine.has_method("open_generation_queue_dialog"):
			engine.open_generation_queue_dialog()
			get_viewport().set_input_as_handled()


func _unhandled_input(event: InputEvent) -> void:
	if not is_visible_in_tree():
		return
	if _primary_panel == null or not _primary_panel.visible:
		return
	if not _primary_cancel.is_valid() or not _action_cancel.visible:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_SPACE:
			_on_action_cancel_pressed()
			get_viewport().set_input_as_handled()
