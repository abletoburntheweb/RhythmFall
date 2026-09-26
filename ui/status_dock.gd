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
	"diary": "sparkles.svg",
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
const ICON_TINT_DIARY := Color(0.95, 0.78, 0.42, 1.0)

const CRITICAL_SOUND_KINDS: Array[String] = ["error"]

const DOCK_MARGIN_LEFT := 10.0
const DOCK_MARGIN_BOTTOM := 24.0
const DOCK_MAX_WIDTH := 560.0
const DOCK_MIN_WIDTH := 280.0
const DOCK_PANEL_SEPARATION := 6.0
const MAX_VISIBLE := 3
const MAX_QUEUE := 20

var _last_sound_msec: int = -10000
const SOUND_DEBOUNCE_MS := 400

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

var _active_transients: Array[Dictionary] = []
var _transient_queue: Array[Dictionary] = []
# Bottom-anchored slot placeholders: plain Controls (NOT transients) that keep the
# freed vertical space while live panels below them still need their position,
# so the remaining stack does not jump up on natural VBoxContainer reflow.
var _transient_slots: Array[Control] = []


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
		UiClick.connect_clicked(text_col, _open_generation_queue_dialog, _primary_clickable_guard)
	_ensure_primary_open_hint()
	if _primary_panel:
		UiClick.connect_clicked(_primary_panel, _open_generation_queue_dialog, _primary_clickable_guard)
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


func _enqueue_transient(notif: Dictionary) -> void:
	var dedup_key: String = str(notif.get("dedup_key", notif.get("id", "")))
	var text: String = str(notif.get("text", ""))
	var kind: String = str(notif.get("kind", "info"))
	# Dedup/update: same id in active — update text/kind and bump timer (fixes infinite "Scanning..." hang)
	for i in range(_active_transients.size()):
		var a: Dictionary = _active_transients[i]
		if str(a.get("dedup_key", "")) == dedup_key:
			if str(a.get("text", "")) == text and str(a.get("kind", "")) == kind:
				var t: Timer = a.get("timer", null) as Timer
				if t and is_instance_valid(t):
					t.stop()
					var dur: float = float(notif.get("duration", 2.5))
					if dur > 0.0:
						t.wait_time = dur
						t.start()
				return
			# Same id but different text/kind — update in place instead of stacking
			var panel: Control = a.get("panel", null) as Control
			if panel and is_instance_valid(panel):
				var lbl: Label = panel.get_node_or_null("Row/Label") as Label
				if lbl:
					lbl.text = text
				var icon: TextureRect = panel.get_node_or_null("Row/Icon") as TextureRect
				if icon:
					var file_name: String = KIND_ICONS.get(kind, KIND_ICONS.get("info", "info.svg"))
					var tint: Color = ICON_TINT
					match kind:
						"success": tint = ICON_TINT_SUCCESS
						"error": tint = ICON_TINT_ERROR
						"warning": tint = ICON_TINT_WARNING
						"save": tint = ICON_TINT_SAVE
					icon.texture = _UiIconHelper.load_tinted_icon(file_name, tint)
				_active_transients[i]["text"] = text
				_active_transients[i]["kind"] = kind
				_active_transients[i]["duration"] = float(notif.get("duration", 2.5))
				var old_t: Timer = a.get("timer", null) as Timer
				if old_t and is_instance_valid(old_t):
					old_t.stop()
					old_t.queue_free()
				var dur2: float = float(notif.get("duration", 2.5))
				if dur2 > 0.0:
					var nt := Timer.new()
					nt.one_shot = true
					nt.wait_time = dur2
					add_child(nt)
					nt.timeout.connect(_on_transient_timeout.bind(panel), CONNECT_ONE_SHOT)
					nt.start()
					_active_transients[i]["timer"] = nt
				else:
					_active_transients[i].erase("timer")
				if bool(notif.get("play_sound", true)):
					_play_notification_sound(kind, str(notif.get("sound", "")))
				_sync_dock_geometry()
			return
	# Dedup: check queue — same id updates queued entry
	for i in range(_transient_queue.size()):
		var q: Dictionary = _transient_queue[i]
		if str(q.get("dedup_key", "")) == dedup_key:
			_transient_queue[i]["text"] = text
			_transient_queue[i]["kind"] = kind
			_transient_queue[i]["duration"] = float(notif.get("duration", 2.5))
			_transient_queue[i]["play_sound"] = bool(notif.get("play_sound", true))
			_transient_queue[i]["sound"] = str(notif.get("sound", ""))
			return
	if _active_transients.size() < MAX_VISIBLE:
		_show_transient_panel(notif)
	else:
		if _transient_queue.size() >= MAX_QUEUE:
			_transient_queue.pop_front()
		_transient_queue.append(notif)


func _show_transient_panel(notif: Dictionary) -> void:
	var panel := _create_transient_panel(notif)
	if panel == null:
		return
	# Reuse one freed slot instead of accumulating placeholder Controls.
	_reclaim_transient_slot()
	_vbox.add_child(panel)
	# Insert before PrimaryPanel to keep operation at bottom
	if _primary_panel and _primary_panel.get_parent() == _vbox:
		_vbox.move_child(panel, _vbox.get_child_count() - 2)
	_active_transients.append({
		"id": str(notif.get("id", "")),
		"dedup_key": str(notif.get("dedup_key", notif.get("id", ""))),
		"text": str(notif.get("text", "")),
		"kind": str(notif.get("kind", "info")),
		"panel": panel,
		"duration": float(notif.get("duration", 2.5)),
	})
	_fade_in_panel(panel)
	var kind: String = str(notif.get("kind", "info"))
	var do_sound: bool = bool(notif.get("play_sound", true))
	if do_sound:
		_play_notification_sound(kind, str(notif.get("sound", "")))
	var dur: float = float(notif.get("duration", 2.5))
	if dur > 0.0:
		var t := Timer.new()
		t.one_shot = true
		t.wait_time = dur
		add_child(t)
		t.timeout.connect(_on_transient_timeout.bind(panel), CONNECT_ONE_SHOT)
		t.start()
		# store timer for dedup bump
		_active_transients[_active_transients.size() - 1]["timer"] = t
	_sync_dock_geometry()


func _create_transient_panel(notif: Dictionary) -> PanelContainer:
	var panel := PanelContainer.new()
	var bg: Color = Color(0.14, 0.18, 0.24, 0.97)
	var border: Color = Color(0.52, 0.72, 0.58, 0.45)
	var accent_var: Variant = notif.get("accent", null)
	if accent_var is Color:
		border = accent_var as Color
	elif str(notif.get("kind", "")) == "achievement":
		var cat: String = str(notif.get("category", ""))
		if cat != "":
			var AchievementsUtils = preload("res://logic/domain/profile/achievements_utils.gd")
			border = AchievementsUtils.accent_color_for_category(cat)
	panel.add_theme_stylebox_override("panel", _make_panel_style(bg, border))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(row)
	var icon := TextureRect.new()
	icon.custom_minimum_size = Vector2(20, 20)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var icon_tex: Variant = notif.get("icon_tex", null)
	if icon_tex is Texture2D:
		icon.texture = icon_tex as Texture2D
	else:
		var kind: String = str(notif.get("kind", "info"))
		var file_name: String = KIND_ICONS.get(kind, KIND_ICONS.info)
		var tint: Color = ICON_TINT
		match kind:
			"success": tint = ICON_TINT_SUCCESS
			"error": tint = ICON_TINT_ERROR
			"warning": tint = ICON_TINT_WARNING
			"save": tint = ICON_TINT_SAVE
			"achievement": tint = border
		icon.texture = _UiIconHelper.load_tinted_icon(file_name, tint)
		# For achievement, override with trophy if provided
		var ach_icon: Variant = notif.get("achievement_icon", null)
		if ach_icon is Texture2D:
			icon.texture = ach_icon as Texture2D
	row.add_child(icon)
	var label := Label.new()
	label.text = str(notif.get("text", ""))
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_color_override("font_color", Color(0.88, 0.94, 0.9, 1.0))
	row.add_child(label)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return panel


func _on_transient_timeout(panel: Control) -> void:
	if panel == null or not is_instance_valid(panel):
		return
	# Capture the real laid-out height now (after layout pass, before fade/free).
	var slot_h := panel.size.y
	if slot_h <= 0.0 and panel is Control:
		slot_h = (panel as Control).get_combined_minimum_size().y
	# Find and remove from active
	for i in range(_active_transients.size()):
		var a: Dictionary = _active_transients[i]
		if a.get("panel", null) == panel:
			_active_transients.remove_at(i)
			break
	var tw := create_tween()
	tw.tween_property(panel, "modulate:a", 0.0, 0.16)
	tw.tween_callback(func():
		var idx := -1
		if is_instance_valid(panel) and _vbox and panel.get_parent() == _vbox:
			idx = panel.get_index()
		if is_instance_valid(panel):
			panel.queue_free()
		if _active_transients.is_empty():
			# Stack fully gone (or single panel) — collapse, no eternal gaps.
			_clear_transient_slots()
		else:
			_hold_transient_slot(idx, slot_h)
		_sync_dock_geometry()
		_try_show_next_transient()
	)


func _hold_transient_slot(idx: int, slot_h: float) -> void:
	# Keep the freed space while anything below it (live transient panels or
	# the visible operation panel) still needs its position. PrimaryPanel
	# itself stays bottom-most; the slot only preserves the stack above it.
	if _vbox == null or idx < 0 or slot_h <= 0.0:
		return
	var has_below := false
	for a in _active_transients:
		var p: Control = a.get("panel", null) as Control
		if p and is_instance_valid(p) and p.get_parent() == _vbox and p.get_index() > idx:
			has_below = true
			break
	# A visible operation panel below also pins the slot: the bottom-most
	# transient expiry must not pull PrimaryPanel up either.
	if not has_below and _primary_panel and _primary_panel.visible and _primary_panel.get_parent() == _vbox and _primary_panel.get_index() > idx:
		has_below = true
	if not has_below:
		return
	var spacer := Control.new()
	spacer.name = "TransientSlot"
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	spacer.custom_minimum_size = Vector2(0, slot_h)
	_vbox.add_child(spacer)
	_vbox.move_child(spacer, mini(idx, _vbox.get_child_count() - 1))
	_transient_slots.append(spacer)


func _reclaim_transient_slot() -> void:
	# A newly arriving panel reuses one freed slot without accumulating
	# placeholders: the bottom-most slot is SUNK directly above PrimaryPanel
	# (moved, not freed), so panels above keep their coordinates and the
	# operation panel never shifts. Slot count never grows on arrival.
	if _transient_slots.is_empty():
		return
	var target: Control = null
	var best := -1
	for s in _transient_slots:
		if s == null or not is_instance_valid(s) or _vbox == null or s.get_parent() != _vbox:
			continue
		var i: int = s.get_index()
		if i > best:
			best = i
			target = s
	# Drop dead references, keep tracked slots (including a sunk target).
	var kept: Array[Control] = []
	for s in _transient_slots:
		if s != null and is_instance_valid(s):
			kept.append(s)
	_transient_slots = kept
	if target == null:
		return
	if _vbox and _primary_panel and _primary_panel.get_parent() == _vbox and target.get_parent() == _vbox:
		_vbox.remove_child(target)
		_vbox.add_child(target)
		_vbox.move_child(target, _primary_panel.get_index())
		return
	# Primary not available — fall back to freeing the slot.
	if target.get_parent() == _vbox:
		_vbox.remove_child(target)
	target.queue_free()
	var kept2: Array[Control] = []
	for s in _transient_slots:
		if s != null and is_instance_valid(s) and s != target:
			kept2.append(s)
	_transient_slots = kept2


func _clear_transient_slots() -> void:
	for s in _transient_slots:
		if s != null and is_instance_valid(s):
			if _vbox and s.get_parent() == _vbox:
				_vbox.remove_child(s)
			s.queue_free()
	_transient_slots.clear()


func _try_show_next_transient() -> void:
	if _transient_queue.is_empty() or _active_transients.size() >= MAX_VISIBLE:
		return
	var next: Dictionary = _transient_queue.pop_front()
	_show_transient_panel(next)


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
	print("DEBUG_STATUSDOCK: show_transient id=%s text=%s kind=%s duration=%.1f" % [id, text, kind, duration_sec])
	if text.strip_edges() == "":
		return
	var notif := {
		"id": id,
		"dedup_key": id,
		"text": text,
		"kind": kind,
		"duration": duration_sec,
		"play_sound": play_sound,
	}
	_enqueue_transient(notif)


func show_achievement(achievement: Dictionary) -> void:
	var AchievementsUtils = preload("res://logic/domain/profile/achievements_utils.gd")
	var AchievementLocale = preload("res://logic/i18n/achievement_locale.gd")
	var ShopItemLocale = preload("res://logic/i18n/shop_item_locale.gd")
	var category := String(achievement.get("category", ""))
	var accent := AchievementsUtils.accent_color_for_category(category)
	var icon_tex := _UiIconHelper.load_tinted_icon("trophy.svg", accent, 48)
	var title_text := AchievementLocale.localized_title(achievement)
	var header_text := tr("ACH_POPUP_UNLOCKED")
	var text := "%s\n%s" % [header_text, title_text]
	# If achievement grants a Shop item, append reward line
	var ach_id_str := str(achievement.get("id", ""))
	if ach_id_str != "" and not bool(achievement.get("is_deprecated", false)):
		var shop_item := _find_shop_item_for_achievement(ach_id_str)
		if not shop_item.is_empty():
			var item_name: String = ShopItemLocale.localized_name(shop_item)
			if item_name == "":
				item_name = str(shop_item.get("name", ""))
			if item_name == "":
				item_name = str(shop_item.get("item_id", ""))
			var reward_fmt := tr("ACH_REWARD_RECEIVED_FMT")
			if reward_fmt == "ACH_REWARD_RECEIVED_FMT":
				reward_fmt = "Received item: %s"
			text += "\n%s" % (reward_fmt % item_name)
	var notif := {
		"id": "achievement_%s" % str(achievement.get("id", "")),
		"dedup_key": "achievement_%s" % str(achievement.get("id", "")),
		"text": text,
		"kind": "achievement",
		"duration": 5.0,
		"accent": accent,
		"icon_tex": icon_tex,
		"achievement_icon": icon_tex,
		"category": category,
	}
	_enqueue_transient(notif)


func _find_shop_item_for_achievement(ach_id_str: String) -> Dictionary:
	if ach_id_str == "":
		return {}
	var shop_path := "res://data/shop_data.json"
	if FileAccess.file_exists("user://shop_data.json"):
		shop_path = "user://shop_data.json"
	var f := FileAccess.open(shop_path, FileAccess.READ)
	if f == null:
		return {}
	var txt := f.get_as_text()
	f.close()
	var parsed = JSON.parse_string(txt)
	var items: Array = []
	if parsed is Dictionary and parsed.has("items") and parsed["items"] is Array:
		items = parsed["items"] as Array
	elif parsed is Array:
		items = parsed
	for it in items:
		if it is Dictionary:
			if str(it.get("required_achievement", "")) == ach_id_str or str(it.get("achievement_required", "")) == ach_id_str:
				return it
	return {}


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
	print("DEBUG_STATUSDOCK: show_operation_message id=%s text=%s kind=%s duration=%.1f visible_before=%s operation_visible_before=%s" % [op_id, text, kind, duration, str(_primary_panel.visible if _primary_panel else false), str(_primary_operation_visible)])
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
	for a in _active_transients:
		var p: Control = a.get("panel", null) as Control
		if p and is_instance_valid(p):
			var t: Timer = a.get("timer", null) as Timer
			if t and is_instance_valid(t):
				t.stop()
				t.queue_free()
			p.queue_free()
	_active_transients.clear()
	_transient_queue.clear()
	_clear_transient_slots()
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
	var vp := get_viewport_rect().size
	var dock_w := clampf(minf(DOCK_MAX_WIDTH, vp.x - 24.0), DOCK_MIN_WIDTH, vp.x - 24.0)
	# Y-jump root cause: heights were measured before Label autowrap width was pinned,
	# so first frame used ~0px width → phantom multi-line height → dock too tall → jump on next frame.
	# Fix: pin widths first, force a minimum-size recalc, then measure VBox's combined height directly.
	# This makes first frame already correct, no deferred jump. X is untouched.
	if _secondary_panel:
		_secondary_panel.custom_minimum_size.x = dock_w
	if _primary_panel:
		_primary_panel.custom_minimum_size.x = dock_w
	for a in _active_transients:
		var p: Control = a.get("panel", null) as Control
		if p:
			p.custom_minimum_size.x = dock_w
			var lbl: Label = p.get_node_or_null("Row/Label") as Label
			if lbl:
				lbl.custom_minimum_size.x = maxf(1.0, dock_w - 46.0)
				# Force label to recalc with new width before VBox measures
				lbl.get_combined_minimum_size()
			p.get_combined_minimum_size()
	if _secondary_label:
		_secondary_label.custom_minimum_size.x = maxf(1.0, dock_w - 46.0)
		_secondary_label.get_combined_minimum_size()
	var row_actions_w := _primary_row_action_width()
	if _primary_title:
		_primary_title.custom_minimum_size.x = maxf(1.0, dock_w - 48.0 - row_actions_w)
		_primary_title.get_combined_minimum_size()
	if _primary_subtitle:
		_primary_subtitle.custom_minimum_size.x = maxf(1.0, dock_w - 48.0 - row_actions_w)
		_primary_subtitle.get_combined_minimum_size()
	if _secondary_panel:
		_secondary_panel.get_combined_minimum_size()
	if _primary_panel:
		_primary_panel.get_combined_minimum_size()
	_vbox.get_combined_minimum_size()
	# Use VBox's combined minimum as source of truth — avoids manual sum drift and includes separations.
	var total_h := _vbox.get_combined_minimum_size().y
	if total_h <= 0.0:
		# Fallback manual sum if VBox not yet laid out (should not happen after pinning)
		total_h = 0.0
		for a in _active_transients:
			var p: Control = a.get("panel", null) as Control
			if p and p.visible:
				var h := maxf(p.get_combined_minimum_size().y, p.size.y)
				if h <= 0.0:
					h = 48.0
				if total_h > 0.0:
					total_h += DOCK_PANEL_SEPARATION
				total_h += h
		if _active_transients.is_empty() and _secondary_panel and _secondary_panel.visible:
			var h2 := maxf(_secondary_panel.get_combined_minimum_size().y, _secondary_panel.size.y)
			if h2 <= 0.0:
				h2 = 48.0
			if total_h > 0.0:
				total_h += DOCK_PANEL_SEPARATION
			total_h += h2
		if _primary_panel and _primary_panel.visible:
			var primary_h := maxf(_primary_panel.get_combined_minimum_size().y, _primary_panel.size.y)
			if total_h > 0.0:
				total_h += DOCK_PANEL_SEPARATION
			total_h += primary_h
	total_h = maxf(total_h, 1.0)
	offset_left = DOCK_MARGIN_LEFT
	offset_right = DOCK_MARGIN_LEFT + dock_w
	offset_bottom = -DOCK_MARGIN_BOTTOM
	offset_top = offset_bottom - total_h


func _primary_row_action_width() -> float:
	var w := 0.0
	for btn in [_action_cancel, _action_retry]:
		if btn and btn.visible:
			w += btn.get_combined_minimum_size().x
			w += 8.0
	return w


func _play_notification_sound(kind: String, sound: String = "") -> void:
	if MusicManager == null:
		return
	# Debounce: не спамить звуком если много уведомлений за раз
	var now := Time.get_ticks_msec()
	if now - _last_sound_msec < SOUND_DEBOUNCE_MS and sound == "" and kind in ["info", "warning"]:
		# Пропускаем повторный тост-звук, но критичные, success и analysis_success всегда играют
		return
	if sound == "analysis_success":
		_last_sound_msec = now
		if MusicManager.has_method("play_analysis_success"):
			MusicManager.play_analysis_success()
		return
	if kind in CRITICAL_SOUND_KINDS:
		_last_sound_msec = now
		if MusicManager.has_method("play_analysis_error"):
			MusicManager.play_analysis_error()
		return
	if kind == "achievement":
		_last_sound_msec = now
		if MusicManager.has_method("play_achievement_sound"):
			MusicManager.play_achievement_sound()
		return
	# Sparkle diary celebrations — distinct from ordinary status toasts.
	if kind == "diary":
		_last_sound_msec = now
		if MusicManager.has_method("play_diary_celebration"):
			MusicManager.play_diary_celebration()
		elif MusicManager.has_method("play_achievement_sound"):
			MusicManager.play_achievement_sound()
		return
	_last_sound_msec = now
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
	var indeterminate: bool = bool(payload.get("indeterminate", false))
	var progress := clampf(float(payload.get("progress", 0.0)), 0.0, 1.0)
	if _primary_progress:
		_primary_progress.indeterminate = indeterminate
		_primary_progress.visible = indeterminate or progress > 0.0 or not compact
		if not indeterminate:
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
	_primary_clickable = (
		_primary_panel
		and _primary_panel.visible
		and _primary_id in ["bpm", "notes", "queue"]
	)
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
		UiClick.connect_clicked(_primary_icon, _open_generation_queue_dialog, _primary_clickable_guard)
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
		fill.bg_color = Color(0.62, 0.92, 0.88, 1.0)
		fill.set_corner_radius_all(3)
		var bg := StyleBoxFlat.new()
		bg.bg_color = Color(0.08, 0.10, 0.16, 0.9)
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
		"diary":
			tint = ICON_TINT_DIARY
	target.texture = _UiIconHelper.load_tinted_icon(file_name, tint)


func _fade_in_panel(panel: Control) -> void:
	if panel == null:
		return
	if _panel_tweens.has(panel) and (_panel_tweens[panel] as Tween).is_valid():
		(_panel_tweens[panel] as Tween).kill()
	panel.visible = true
	panel.modulate.a = 0.0
	panel.pivot_offset = Vector2(0.0, panel.size.y)
	# Position the dock for the incoming panel NOW, and again after this frame's
	# layout pass (call_deferred), so the toast/panel appears at its final place
	# from the very first rendered frame. Otherwise the first show renders at the
	# stale pre-show geometry (a ~1px strip at the bottom) and only jumps to the
	# correct size when the post-fade callback re-syncs — the "arrives/jumps"
	# artifact seen on the first toast.
	_sync_dock_geometry()
	call_deferred("_sync_dock_geometry")
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
	for a in _active_transients:
		var p: Control = a.get("panel", null) as Control
		if p:
			p.mouse_filter = Control.MOUSE_FILTER_STOP if p.visible else Control.MOUSE_FILTER_IGNORE


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


func _primary_clickable_guard() -> bool:
	return _primary_clickable


func _open_generation_queue_dialog() -> void:
	var engine := get_tree().root.get_node_or_null("GameEngine")
	if engine and engine.has_method("open_generation_queue_dialog"):
		engine.open_generation_queue_dialog()


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
