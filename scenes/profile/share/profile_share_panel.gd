# scenes/profile/share/profile_share_panel.gd
class_name ProfileSharePanel
extends PanelContainer

signal selection_changed(index: int)

const _Snapshot = preload("res://scenes/profile/share/profile_share_snapshot.gd")
const _Exporter = preload("res://scenes/profile/share/profile_share_export.gd")
const _ExportMessages = preload("res://scenes/profile/share/profile_share_export_messages.gd")
const _NoticeScene = preload("res://ui/overlays/app_notice_overlay.tscn")
const _StatusToast = preload("res://logic/ui/status_toast.gd")
const CARD_SCENE := preload("res://scenes/profile/share/profile_share_card.tscn")

@onready var _title_label: Label = %ShareTitleLabel
@onready var _cards_row: HBoxContainer = %CardsRow
@onready var _hint_label: Label = %ShareHintLabel
@onready var _save_file_dialog: FileDialog = %SaveFileDialog
@onready var _save_dir_dialog: FileDialog = %SaveDirDialog

var _result_overlay: AppNoticeOverlay

var _cards: Array[Control] = []
var _snapshot: Dictionary = {}
var _selected_index: int = 0
var _export_all_pending := false


func _ready() -> void:
	_build_cards()
	_refresh_snapshot()
	_select_index(0)
	if not _save_file_dialog.file_selected.is_connected(_on_save_file_selected):
		_save_file_dialog.file_selected.connect(_on_save_file_selected)
	if not _save_dir_dialog.dir_selected.is_connected(_on_save_dir_selected):
		_save_dir_dialog.dir_selected.connect(_on_save_dir_selected)


func apply_locale() -> void:
	if _title_label:
		_title_label.text = tr("PROFILE_SHARE_SECTION_TITLE")
	if _hint_label:
		_hint_label.text = tr("PROFILE_SHARE_SECTION_HINT")
	if _save_file_dialog:
		_save_file_dialog.title = tr("PROFILE_SHARE_SAVE_DIALOG")
	if _save_dir_dialog:
		_save_dir_dialog.title = tr("PROFILE_SHARE_SAVE_ALL_DIALOG")
	for card in _cards:
		if card.has_method("apply_locale"):
			card.apply_locale()
	_refresh_snapshot()


func refresh_data() -> void:
	_refresh_snapshot()


func get_selected_index() -> int:
	return _selected_index


func select_index(index: int) -> void:
	_select_index(index)


func export_selected() -> void:
	if _cards.is_empty():
		return
	var card_id: String = _Snapshot.CARD_IDS[_selected_index]
	_export_all_pending = false
	if _save_file_dialog:
		_save_file_dialog.current_file = _Snapshot.export_filename(card_id)
		_save_file_dialog.popup_centered()


func export_all() -> void:
	_export_all_pending = true
	if _save_dir_dialog:
		_save_dir_dialog.popup_centered()


func _build_cards() -> void:
	if _cards_row == null:
		return
	for child in _cards_row.get_children():
		child.queue_free()
	_cards.clear()
	for i in range(_Snapshot.CARD_IDS.size()):
		var card_id: String = _Snapshot.CARD_IDS[i]
		var card := CARD_SCENE.instantiate()
		_cards_row.add_child(card)
		_cards.append(card)
		if card.has_method("setup"):
			card.setup(card_id, i)
		if card.has_signal("card_pressed"):
			card.card_pressed.connect(_on_card_pressed)


func _refresh_snapshot() -> void:
	_snapshot = _Snapshot.build_all()
	for i in range(_cards.size()):
		var card_id: String = _Snapshot.CARD_IDS[i]
		var card := _cards[i]
		if card.has_method("apply_data"):
			card.apply_data(card_id, _snapshot.get(card_id, {}), false)


func _select_index(index: int) -> void:
	if _cards.is_empty():
		return
	_selected_index = clampi(index, 0, _cards.size() - 1)
	for i in range(_cards.size()):
		var card := _cards[i]
		if card.has_method("set_selected"):
			card.set_selected(i == _selected_index)
	selection_changed.emit(_selected_index)


func _on_card_pressed(card_id: String) -> void:
	var idx := _Snapshot.CARD_IDS.find(card_id)
	if idx >= 0:
		_select_index(idx)


func _on_save_file_selected(path: String) -> void:
	var card_id: String = _Snapshot.CARD_IDS[_selected_index]
	_run_export_one(card_id, path)


func _on_save_dir_selected(path: String) -> void:
	_run_export_all(path)


func _run_export_one(card_id: String, path: String) -> void:
	var data: Dictionary = _snapshot.get(card_id, _Snapshot.build_card(card_id))
	var card := _find_card(card_id)
	var size := Vector2i(360, 480)
	if card and card.has_method("get_export_size"):
		size = card.get_export_size()
	var result: Dictionary = await _Exporter.save_card(card_id, data, path, size)
	_show_export_result(result)


func _run_export_all(dir_path: String) -> void:
	var base := String(dir_path).replace("\\", "/").trim_suffix("/")
	var saved: Array[String] = []
	for card_id in _Snapshot.CARD_IDS:
		var data: Dictionary = _snapshot.get(card_id, _Snapshot.build_card(card_id))
		var out_path := "%s/%s" % [base, _Snapshot.export_filename(card_id)]
		var result: Dictionary = await _Exporter.save_card(card_id, data, out_path, Vector2i(360, 480))
		if not result.get("ok", false):
			_show_export_result(result)
			return
		saved.append(out_path)
	if saved.is_empty():
		_show_export_result({"ok": false, "error_key": "PROFILE_SHARE_EXPORT_ERR_WRITE"})
	else:
		_show_export_result({"ok": true, "path": base, "count": saved.size()})


func _find_card(card_id: String) -> Control:
	var idx := _Snapshot.CARD_IDS.find(card_id)
	if idx < 0 or idx >= _cards.size():
		return null
	return _cards[idx]


func _show_export_result(result: Dictionary) -> void:
	var text := ""
	var ok := bool(result.get("ok", false))
	if ok:
		if result.has("count"):
			text = _ExportMessages.format_all_ok(
				int(result.get("count", 0)),
				str(result.get("path", "")),
			)
		else:
			text = tr("PROFILE_SHARE_EXPORT_OK") % str(result.get("path", ""))
		_StatusToast.show_from_node(self, "share_export_ok", text, "success", 3.2)
		return
	var key := str(result.get("error_key", "PROFILE_SHARE_EXPORT_ERR_WRITE"))
	var detail := str(result.get("detail", ""))
	text = tr(key)
	if detail != "":
		text = "%s (%s)" % [text, detail]
	_get_result_overlay().show_message(text)


func _get_result_overlay() -> AppNoticeOverlay:
	if _result_overlay and is_instance_valid(_result_overlay):
		return _result_overlay
	_result_overlay = _NoticeScene.instantiate() as AppNoticeOverlay
	get_tree().root.add_child(_result_overlay)
	return _result_overlay
