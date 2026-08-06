# logic/ui/status_toast.gd
extends RefCounted
class_name StatusToast


static func show_from_node(
	host: Node,
	id: String,
	text: String,
	kind: String = "success",
	duration_sec: float = 2.5,
) -> void:
	if host == null or text.strip_edges() == "":
		return
	var dock: StatusDock = _find_status_dock(host)
	if dock and dock.has_method("show_transient"):
		dock.show_transient(id, text, kind, duration_sec)


static func _find_status_dock(host: Node) -> StatusDock:
	var node: Node = host
	while node:
		if node.has_method("get_status_dock"):
			return node.get_status_dock()
		node = node.get_parent()
	if host.get_tree().root.has_node("GameEngine"):
		var engine = host.get_tree().root.get_node("GameEngine")
		if engine.has_method("get_status_dock"):
			return engine.get_status_dock()
	return null
