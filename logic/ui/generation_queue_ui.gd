# logic/ui/generation_queue_ui.gd
extends RefCounted
class_name GenerationQueueUi

const _DialogScene := preload("res://scenes/generation/generation_queue_dialog.tscn")
const _DialogScript := preload("res://scenes/generation/generation_queue_dialog.gd")


static func show_dialog(host: Node = null) -> Node:
	if host == null:
		host = _find_game_engine()
	if host == null:
		return null
	for child in host.get_children():
		if child.get_script() == _DialogScript:
			if child.has_method("refresh"):
				child.call("refresh")
			return child
	var dlg: Node = _DialogScene.instantiate()
	host.add_child(dlg)
	host.move_child(dlg, -1)
	return dlg


static func _find_game_engine() -> Node:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return null
	return tree.root.get_node_or_null("GameEngine")
