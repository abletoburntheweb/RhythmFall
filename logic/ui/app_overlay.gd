# logic/ui/app_overlay.gd
class_name AppOverlay
extends RefCounted

const _NoticeScene := preload("res://ui/overlays/app_notice_overlay.tscn")
const _ConfirmScene := preload("res://ui/overlays/app_confirm_overlay.tscn")

static var _notice: AppNoticeOverlay
static var _confirm: AppConfirmOverlay


## Simple result / info — no title, soft frame, one OK button.
static func show_notice(host: Node, message: String) -> AppNoticeOverlay:
	var overlay := _ensure_notice(host)
	overlay.show_message(message)
	return overlay


## Important choice — title, accent frame, Cancel + Confirm.
static func show_confirm(
	host: Node,
	title: String,
	message: String,
	variant: String = "warning",
	confirm_text: String = "",
	cancel_text: String = "",
) -> AppConfirmOverlay:
	var overlay := _ensure_confirm(host)
	overlay.show_confirm(title, message, variant, confirm_text, cancel_text)
	return overlay


static func confirm_async(
	host: Node,
	title: String,
	message: String,
	variant: String = "warning",
	confirm_text: String = "",
	cancel_text: String = "",
) -> bool:
	var overlay := show_confirm(host, title, message, variant, confirm_text, cancel_text)
	return await overlay.finished


static func _ensure_notice(host: Node) -> AppNoticeOverlay:
	if _notice and is_instance_valid(_notice):
		return _notice
	_notice = _NoticeScene.instantiate() as AppNoticeOverlay
	_attach(host, _notice)
	return _notice


static func _ensure_confirm(host: Node) -> AppConfirmOverlay:
	if _confirm and is_instance_valid(_confirm):
		return _confirm
	_confirm = _ConfirmScene.instantiate() as AppConfirmOverlay
	_attach(host, _confirm)
	return _confirm


static func _attach(host: Node, overlay: Control) -> void:
	var parent := _overlay_parent(host)
	parent.add_child(overlay)
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.visible = false


static func _overlay_parent(host: Node) -> Node:
	var node: Node = host
	while node:
		if node is Control and node.get_parent() == host.get_tree().root:
			return node
		node = node.get_parent()
	return host.get_tree().root
