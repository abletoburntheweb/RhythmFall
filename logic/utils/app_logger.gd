# logic/utils/app_logger.gd
extends RefCounted
class_name AppLogger

# Minimal logger with consistent INFO/WARN/ERROR semantics for client (GDScript).
# Server has separate app/app_logger.py — no shared file needed.
# verbose_rhythm_dna filter is preserved for RNA INFO logs.

static func _is_verbose_rhythm_dna() -> bool:
	return bool(ProjectSettings.get_setting("debug/verbose_rhythm_dna", false))


static func info(msg: String, verbose_only: bool = false) -> void:
	if verbose_only and not _is_verbose_rhythm_dna():
		return
	print(msg)


static func warn(msg: String, show_in_dock: bool = false, dock_kind: String = "warning", dock_id: String = "") -> void:
	push_warning(msg)
	if show_in_dock:
		var dock := _get_status_dock()
		if dock and dock.has_method("show_transient"):
			var did := dock_id if dock_id != "" else "logger_warn"
			dock.show_transient(did, msg, dock_kind, 4.0)


static func error(msg: String, show_in_dock: bool = false, dock_kind: String = "error", dock_id: String = "") -> void:
	push_error(msg)
	if show_in_dock:
		var dock := _get_status_dock()
		if dock and dock.has_method("show_transient"):
			var did := dock_id if dock_id != "" else "logger_error"
			dock.show_transient(did, msg, dock_kind, 5.0)


static func _get_status_dock() -> Control:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return null
	var root := tree.root
	if root == null:
		return null
	var ge := root.get_node_or_null("GameEngine")
	if ge == null:
		return null
	return ge.get_node_or_null("NotificationsLayer/StatusDock") as Control
