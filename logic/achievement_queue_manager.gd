# scenes/achievements/achievement_queue_manager.gd
extends Node
class_name AchievementQueueManager

var achievement_queue: Array[Dictionary] = []
var is_showing_popup: bool = false
var current_popup: Control = null
var _delayed_achievements: Array[Dictionary] = []

func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	
	call_deferred("_process_delayed_achievements")

func _process_delayed_achievements():
	if _delayed_achievements.size() > 0:
		for achievement in _delayed_achievements:
			achievement_queue.append(achievement)
		_delayed_achievements.clear()
		call_deferred("_process_queue")

func add_achievement_to_queue(achievement_data: Dictionary):
	achievement_queue.append(achievement_data)
	if is_inside_tree():
		call_deferred("_process_queue")
	else:
		self.tree_entered.connect(_process_queue, CONNECT_ONE_SHOT)

func _process_queue():
	if is_showing_popup or achievement_queue.is_empty():
		return
	
	if not is_inside_tree():
		self.tree_entered.connect(_process_queue, CONNECT_ONE_SHOT)
		return
	
	is_showing_popup = true
	var next_achievement = achievement_queue.pop_front()
	_show_achievement_popup(next_achievement)

func _show_achievement_popup(achievement_data: Dictionary):
	
	var popup_scene = preload("res://scenes/achievements/achievement_pop_up.tscn")
	current_popup = popup_scene.instantiate()
	
	var root = get_tree().root
	var parent_node: Node = root
	var game_engine_node = root.get_node_or_null("GameEngine")
	if game_engine_node:
		var notifications_layer = game_engine_node.get_node_or_null("NotificationsLayer")
		if notifications_layer:
			parent_node = notifications_layer
	
	parent_node.add_child(current_popup)
	_setup_popup(current_popup, achievement_data)

func _setup_popup(popup: Control, achievement_data: Dictionary):
	popup.set_achievement_data(achievement_data)
	popup.anchor_right = 1.0
	popup.anchor_bottom = 1.0
	popup.offset_right = 0.0
	popup.offset_bottom = 0.0
	popup.position.x = 1420.0
	popup.position.y = 1081.0
	popup.z_index = 200
	
	if popup.has_signal("popup_finished"):
		popup.popup_finished.connect(_on_popup_finished, CONNECT_ONE_SHOT)
	else:
		get_tree().create_timer(6.5).timeout.connect(_on_popup_finished, CONNECT_ONE_SHOT)
	# Страховка на случай потери сигнала
	get_tree().create_timer(6.5).timeout.connect(_on_popup_finished, CONNECT_ONE_SHOT)

func _on_popup_entered_tree(achievement_data: Dictionary):
	if current_popup and current_popup.is_inside_tree():
		_setup_popup(current_popup, achievement_data)

func _on_popup_finished():
	if current_popup:
		current_popup.queue_free()
		current_popup = null
	
	is_showing_popup = false
	get_tree().create_timer(0.8).timeout.connect(_process_queue, CONNECT_ONE_SHOT)

func clear_queue():
	achievement_queue.clear()
	_delayed_achievements.clear()
	if current_popup:
		current_popup.queue_free()
		current_popup = null
	is_showing_popup = false

func get_queue_size() -> int:
	return achievement_queue.size() + _delayed_achievements.size()

func is_busy() -> bool:
	return is_showing_popup
 
