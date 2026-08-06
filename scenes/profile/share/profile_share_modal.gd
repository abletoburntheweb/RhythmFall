# scenes/profile/share/profile_share_modal.gd
class_name ProfileShareModal
extends Control

signal closed

const _Snapshot = preload("res://scenes/profile/share/profile_share_snapshot.gd")
const _Exporter = preload("res://scenes/profile/share/profile_share_export.gd")
const _HtmlExport = preload("res://scenes/profile/share/profile_share_html_export.gd")
const _ExportMessages = preload("res://scenes/profile/share/profile_share_export_messages.gd")
const _PreviewSlotScene = preload("res://scenes/profile/share/profile_share_preview_slot.tscn")
const _UiModifierSounds = preload("res://logic/ui/ui_modifier_sounds.gd")
const _ClipboardImage = preload("res://logic/platform/clipboard_image.gd")
const _UiIconHelper = preload("res://logic/ui/ui_icon_helper.gd")
const _StatusToast = preload("res://logic/ui/status_toast.gd")
const EXPORT_SIZE := Vector2i(1080, 1920)

@onready var _back_button: Button = %BackButton
@onready var _title_label: Label = %TitleLabel
@onready var _hint_label: Label = %HintLabel
@onready var _footer_hint_label: Label = %FooterHintLabel
@onready var _copy_button: Button = %CopyButton
@onready var _save_button: Button = %SaveButton
@onready var _save_all_button: Button = %SaveAllButton
@onready var _save_file_dialog: FileDialog = %SaveFileDialog
@onready var _save_dir_dialog: FileDialog = %SaveDirDialog
@onready var _result_overlay: AppNoticeOverlay = %ExportResultOverlay
@onready var _cards_row: HBoxContainer = %CardsRow

var _slots: Array[ProfileSharePreviewSlot] = []
var _snapshot: Dictionary = {}
var _selected_index: int = -1
var _refresh_token: int = 0
var _busy := false
var _loading_overlay: LoadingOverlay
var _loading_overlay_depth := 0
var _pending_open_folder: String = ""


func _ready() -> void:
	visible = false
	_build_preview_slots()
	_setup_native_dialogs()
	_back_button.pressed.connect(_on_back_pressed)
	if _copy_button:
		_copy_button.pressed.connect(_on_copy_pressed)
	_save_button.pressed.connect(export_selected)
	_save_all_button.pressed.connect(export_all)
	if not _save_file_dialog.file_selected.is_connected(_on_save_file_selected):
		_save_file_dialog.file_selected.connect(_on_save_file_selected)
	if not _save_dir_dialog.dir_selected.is_connected(_on_save_dir_selected):
		_save_dir_dialog.dir_selected.connect(_on_save_dir_selected)
	if _result_overlay and not _result_overlay.action_chosen.is_connected(_on_result_action_chosen):
		_result_overlay.action_chosen.connect(_on_result_action_chosen)
	apply_locale()


func _build_preview_slots() -> void:
	if _cards_row == null:
		return
	for child in _cards_row.get_children():
		child.queue_free()
	_slots.clear()
	for i in range(_Snapshot.CARD_IDS.size()):
		var slot: ProfileSharePreviewSlot = _PreviewSlotScene.instantiate()
		slot.setup(i, _Snapshot.CARD_IDS[i])
		slot.slot_pressed.connect(_on_slot_pressed)
		_cards_row.add_child(slot)
		_slots.append(slot)


func _setup_native_dialogs() -> void:
	for dlg in [_save_file_dialog, _save_dir_dialog]:
		if dlg == null:
			continue
		dlg.use_native_dialog = true
		dlg.access = FileDialog.ACCESS_FILESYSTEM
		dlg.unresizable = true
	var docs := OS.get_system_dir(OS.SYSTEM_DIR_DOCUMENTS)
	if _save_file_dialog:
		_save_file_dialog.file_mode = FileDialog.FILE_MODE_SAVE_FILE
		_save_file_dialog.filters = PackedStringArray(["*.png ; PNG Images"])
		if docs != "":
			_save_file_dialog.current_dir = docs
	if _save_dir_dialog:
		_save_dir_dialog.file_mode = FileDialog.FILE_MODE_OPEN_DIR
		if docs != "":
			_save_dir_dialog.current_dir = docs


func apply_locale() -> void:
	if _title_label:
		_title_label.text = tr("PROFILE_SHARE_MODAL_TITLE")
	if _hint_label and not _busy:
		_update_renderer_hint()
	if _footer_hint_label:
		_footer_hint_label.text = tr("PROFILE_SHARE_MODAL_FOOTER")
	if _back_button:
		_back_button.text = tr("BTN_BACK")
		_UiIconHelper.apply_standard_back_button(_back_button)
	if _copy_button:
		_copy_button.text = tr("PROFILE_SHARE_COPY")
	if _save_button:
		_save_button.text = tr("PROFILE_SHARE_SAVE_ONE")
	if _save_all_button:
		_save_all_button.text = tr("PROFILE_SHARE_SAVE_ALL")
	if _save_file_dialog:
		_save_file_dialog.title = tr("PROFILE_SHARE_SAVE_DIALOG")
	if _save_dir_dialog:
		_save_dir_dialog.title = tr("PROFILE_SHARE_SAVE_ALL_DIALOG")
	if _result_overlay:
		_result_overlay.apply_locale()


func open_modal() -> void:
	prepare_and_open()


func prepare_and_open() -> void:
	visible = true
	move_to_front()
	_UiModifierSounds.play_select()
	_push_loading(tr("PROFILE_SHARE_PREVIEW_LOADING"))
	await get_tree().process_frame
	_update_renderer_hint()
	_snapshot = await _build_snapshot_async()
	_refresh_token += 1
	var token := _refresh_token
	var preview_scale := _compute_preview_scale()
	var preview_size := Vector2(EXPORT_SIZE) * preview_scale
	_selected_index = -1
	for i in range(_slots.size()):
		var slot: ProfileSharePreviewSlot = _slots[i]
		if slot == null:
			continue
		slot.set_preview_size(preview_size)
		slot.set_selected(false)
		slot.set_loading(true)
	await _refresh_previews_async(token)
	_pop_loading()
	call_deferred("_grab_focus_back")


func _update_renderer_hint() -> void:
	if _hint_label == null:
		return
	if _HtmlExport.is_available():
		_hint_label.text = tr("PROFILE_SHARE_MODAL_HINT")
		return
	var code := _HtmlExport.get_last_error_code()
	if _HtmlExport.can_install_export_toolchain():
		_hint_label.text = tr("PROFILE_SHARE_EXPORT_NEED_INSTALL")
	elif code != "":
		_hint_label.text = tr("PROFILE_SHARE_EXPORT_ERR_CODE") % code
	else:
		_hint_label.text = tr("PROFILE_SHARE_MODAL_HINT")


func close_modal(with_sound: bool = true) -> void:
	if not visible:
		return
	if with_sound:
		_UiModifierSounds.play_deselect()
	visible = false
	_pop_loading(true)
	closed.emit()


func is_open() -> bool:
	return visible


func refresh_data() -> void:
	_snapshot = await _build_snapshot_async()
	_refresh_token += 1
	var token := _refresh_token
	var preview_scale := _compute_preview_scale()
	var preview_size := Vector2(EXPORT_SIZE) * preview_scale
	_selected_index = -1
	for i in range(_slots.size()):
		var slot: ProfileSharePreviewSlot = _slots[i]
		if slot == null:
			continue
		slot.set_preview_size(preview_size)
		slot.set_selected(false)
		slot.set_loading(true)
	_push_loading(tr("PROFILE_SHARE_PREVIEW_LOADING"))
	await _refresh_previews_async(token)
	_pop_loading()


func _build_snapshot_async() -> Dictionary:
	await get_tree().process_frame
	return _Snapshot.build_all_cached()


func _refresh_previews_async(token: int) -> void:
	var preview_scale := _compute_preview_scale()
	var preview_size := Vector2(EXPORT_SIZE) * preview_scale
	var display_size := Vector2i(maxi(1, int(preview_size.x)), maxi(1, int(preview_size.y)))
	# Native card CSS size (1080×1920). Batch = one browser for all five cards.
	var render_size := EXPORT_SIZE

	var items: Array = []
	for i in range(_slots.size()):
		var card_id: String = _Snapshot.CARD_IDS[i]
		items.append({
			"card_id": card_id,
			"data": _snapshot.get(card_id, _Snapshot.build_card(card_id)),
		})

	var textures: Dictionary = await _Exporter.render_preview_batch(items, render_size, display_size)
	if token != _refresh_token:
		return

	for i in range(_slots.size()):
		var card_id: String = _Snapshot.CARD_IDS[i]
		var slot: ProfileSharePreviewSlot = _slots[i]
		if slot == null:
			continue
		slot.set_loading(false)
		var tex: Variant = textures.get(card_id)
		if tex == null or not tex is Texture2D:
			slot.set_loading(true, _format_preview_error())
		else:
			slot.set_texture(tex as Texture2D)

	_update_renderer_hint()


func _format_preview_error() -> String:
	var code := _HtmlExport.get_last_error_code()
	if code != "":
		return tr("PROFILE_SHARE_EXPORT_ERR_CODE") % code
	return tr("PROFILE_SHARE_EXPORT_ERR_CODE") % "E005"


func _compute_preview_scale() -> float:
	const EXPORT_W := float(EXPORT_SIZE.x)
	const GAP := 8.0
	var card_n := float(_Snapshot.CARD_IDS.size())
	var avail := 880.0
	if _cards_row and _cards_row.size.x > 4.0:
		avail = _cards_row.size.x
	else:
		var p := get_node_or_null("Container/BodyCenter/Card/CardMargin/ContentVBox") as Control
		if p and p.size.x > 4.0:
			avail = p.size.x
	var scale := (avail - GAP * (card_n - 1.0)) / (EXPORT_W * card_n)
	return clampf(scale, 0.12, 0.22)


func select_index(index: int) -> void:
	_select_index(index)


func export_selected() -> void:
	if _slots.is_empty() or _save_file_dialog == null or _busy:
		return
	if _selected_index < 0:
		_select_index(0)
	var card_id: String = _Snapshot.CARD_IDS[_selected_index]
	_save_file_dialog.current_file = _Snapshot.export_filename(card_id)
	_save_file_dialog.popup_centered()


func export_all() -> void:
	if _save_dir_dialog == null or _busy:
		return
	_save_dir_dialog.popup_centered()


func handle_hotkey(event: InputEvent) -> bool:
	if _busy:
		return false
	if not (event is InputEventKey) or not event.pressed or event.echo:
		return false
	if event.keycode >= KEY_1 and event.keycode <= KEY_5:
		select_index(int(event.keycode - KEY_1))
		return true
	if event.keycode == KEY_ENTER or event.keycode == KEY_KP_ENTER:
		if event.shift_pressed:
			export_all()
		else:
			export_selected()
		return true
	if event.keycode == KEY_C and event.ctrl_pressed:
		_on_copy_pressed()
		return true
	if event.is_action_pressed("ui_cancel"):
		close_modal()
		return true
	return false


func _grab_focus_back() -> void:
	if _back_button:
		_back_button.grab_focus()


func _select_index(index: int) -> void:
	if _slots.is_empty():
		return
	_selected_index = clampi(index, 0, _slots.size() - 1)
	for i in range(_slots.size()):
		var slot: ProfileSharePreviewSlot = _slots[i]
		if slot:
			slot.set_selected(i == _selected_index)


func _on_slot_pressed(card_id: String) -> void:
	if _busy:
		return
	var idx := _Snapshot.CARD_IDS.find(card_id)
	if idx >= 0:
		_select_index(idx)


func _on_back_pressed() -> void:
	if _busy:
		return
	close_modal()


func _on_save_file_selected(path: String) -> void:
	var card_id: String = _Snapshot.CARD_IDS[_selected_index]
	_run_export_one(card_id, path)


func _on_save_dir_selected(path: String) -> void:
	_run_export_all(path)


func _run_export_one(card_id: String, path: String) -> void:
	_push_loading(tr("PROFILE_SHARE_EXPORT_SAVING"))
	_set_buttons_enabled(false)
	var data: Dictionary = _snapshot.get(card_id, _Snapshot.build_card(card_id))
	var result: Dictionary = await _Exporter.save_card(card_id, data, path, EXPORT_SIZE)
	_pop_loading()
	_set_buttons_enabled(true)
	_show_export_result(result)


func _run_export_all(dir_path: String) -> void:
	_push_loading(tr("PROFILE_SHARE_EXPORT_SAVING"))
	_set_buttons_enabled(false)
	var base := String(dir_path).replace("\\", "/").trim_suffix("/")
	var batch_items: Array = []
	for card_id in _Snapshot.CARD_IDS:
		var data: Dictionary = _snapshot.get(card_id, _Snapshot.build_card(card_id))
		var out_path := "%s/%s" % [base, _Snapshot.export_filename(card_id)]
		batch_items.append({"card_id": card_id, "data": data, "out_path": out_path})
	var result: Dictionary = await _Exporter.save_all_cards(batch_items, EXPORT_SIZE)
	_pop_loading()
	_set_buttons_enabled(true)
	if not result.get("ok", false):
		_show_export_result({"ok": false, "error_code": str(result.get("error_code", "E005"))})
		return
	var paths: Array = result.get("paths", [])
	if paths.is_empty():
		_show_export_result({"ok": false, "error_code": "E006"})
	else:
		_show_export_result({"ok": true, "path": base, "count": paths.size()})


func _get_loading_overlay() -> LoadingOverlay:
	if _loading_overlay and is_instance_valid(_loading_overlay):
		return _loading_overlay
	var ge := get_tree().root.get_node_or_null("GameEngine")
	if ge and ge.has_method("get_loading_overlay"):
		_loading_overlay = ge.get_loading_overlay()
	return _loading_overlay


func _push_loading(message: String) -> void:
	_busy = true
	var overlay := _get_loading_overlay()
	if overlay == null:
		return
	if _loading_overlay_depth == 0:
		overlay.show_loading(message, true)
	_loading_overlay_depth += 1
	if _back_button:
		_back_button.disabled = true


func _pop_loading(force: bool = false) -> void:
	if force:
		_loading_overlay_depth = 0
	elif _loading_overlay_depth > 0:
		_loading_overlay_depth -= 1
	if _loading_overlay_depth > 0:
		return
	_busy = false
	var overlay := _get_loading_overlay()
	if overlay:
		overlay.hide_loading()
	if _back_button:
		_back_button.disabled = false


func _set_buttons_enabled(enabled: bool) -> void:
	if _copy_button:
		_copy_button.disabled = not enabled
	if _save_button:
		_save_button.disabled = not enabled
	if _save_all_button:
		_save_all_button.disabled = not enabled


func _show_export_result(result: Dictionary) -> void:
	_pending_open_folder = ""
	var text := ""
	var ok := bool(result.get("ok", false))
	if ok:
		if str(result.get("message_key", "")) != "":
			text = tr(str(result.get("message_key", "")))
		elif result.has("count"):
			text = _ExportMessages.format_all_ok(
				int(result.get("count", 0)),
				str(result.get("path", "")),
			)
		else:
			text = tr("PROFILE_SHARE_EXPORT_OK") % str(result.get("path", ""))
		_pending_open_folder = _folder_from_export_path(str(result.get("path", "")))
		# Success: toast only (no blocking modal). Folder can still be opened from Save dialog next time.
		_StatusToast.show_from_node(self, "share_export_ok", text, "success", 3.2)
		return
	var code := str(result.get("error_code", _HtmlExport.get_last_error_code()))
	if code == "":
		code = "E005"
	text = tr("PROFILE_SHARE_EXPORT_ERR_CODE") % code
	if _result_overlay:
		_result_overlay.show_message(text)
	else:
		_StatusToast.show_from_node(self, "share_export_err", text, "error", 3.5)


func _show_copy_result(ok: bool, _used_full_export: bool = true) -> void:
	_pending_open_folder = ""
	var key := "PROFILE_SHARE_COPIED" if ok else "PROFILE_SHARE_COPY_FAILED"
	var kind := "success" if ok else "error"
	_StatusToast.show_from_node(self, "share_copy", tr(key), kind, 2.8)


func _folder_from_export_path(path: String) -> String:
	var p := path.replace("\\", "/").strip_edges()
	if p == "":
		return ""
	if p.get_extension().to_lower() == "png":
		return p.get_base_dir()
	return p.trim_suffix("/")


func _on_result_action_chosen(action: String) -> void:
	if action != "secondary":
		return
	var folder := _pending_open_folder.strip_edges()
	_pending_open_folder = ""
	if folder == "":
		return
	var abs_path := folder
	if not abs_path.contains(":") and not abs_path.begins_with("/"):
		abs_path = ProjectSettings.globalize_path(folder)
	OS.shell_open(abs_path)


func _on_copy_pressed() -> void:
	if _busy or _slots.is_empty():
		return
	if _selected_index < 0:
		_select_index(0)
	var card_id: String = _Snapshot.CARD_IDS[_selected_index]
	_copy_card_async(card_id)


func _copy_card_async(card_id: String) -> void:
	# Selected card only (one of five). Full export size — no Save required.
	_push_loading(tr("PROFILE_SHARE_COPYING"))
	_set_buttons_enabled(false)
	var img: Image = null
	var used_full := false
	if _HtmlExport.is_available():
		var data: Dictionary = _snapshot.get(card_id, _Snapshot.build_card(card_id))
		img = await _Exporter.render_card_image(card_id, data, EXPORT_SIZE)
		used_full = img != null
	if img == null and _selected_index >= 0 and _selected_index < _slots.size():
		var slot: ProfileSharePreviewSlot = _slots[_selected_index]
		if slot:
			img = slot.get_preview_image()
	var ok := false
	if img != null:
		ok = _ClipboardImage.copy_image(img)
	_pop_loading()
	_set_buttons_enabled(true)
	_show_copy_result(ok, used_full)
