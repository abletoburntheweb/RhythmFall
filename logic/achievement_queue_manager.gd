# scenes/achievements/achievement_queue_manager.gd
extends Node
class_name AchievementQueueManager

var achievement_queue: Array[Dictionary] = []
var is_showing_popup: bool = false
var current_popup: Control = null
var _delayed_achievements: Array[Dictionary] = []

func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	print("🎯 AchievementQueueManager инициализирован")
	
	call_deferred("_process_delayed_achievements")

func _process_delayed_achievements():
	if _delayed_achievements.size() > 0:
		print("🎯 Обработка отложенных ачивок: ", _delayed_achievements.size())
		for achievement in _delayed_achievements:
			achievement_queue.append(achievement)
		_delayed_achievements.clear()
		call_deferred("_process_queue")

func add_achievement_to_queue(achievement_data: Dictionary):
	print("🎯 Добавление ачивки в очередь: ", achievement_data.get("title", "Unknown"))
	
	if not is_inside_tree():
		print("🎯 Менеджер не в дереве, откладываем ачивку")
		_delayed_achievements.append(achievement_data)
		return
	
	achievement_queue.append(achievement_data)
	
	call_deferred("_process_queue")

func _process_queue():
	if is_showing_popup or achievement_queue.is_empty():
		return
	
	if not is_inside_tree():
		print("🎯 Дерево сцены не готово, откладываем показ ачивки")
		return
	
	is_showing_popup = true
	var next_achievement = achievement_queue.pop_front()
	_show_achievement_popup(next_achievement)

func _show_achievement_popup(achievement_data: Dictionary):
	print("🎯 Показ ачивки из очереди: ", achievement_data.get("title", "Unknown"))
	
	var popup_scene = preload("res://scenes/achievements/achievement_pop_up.tscn")
	current_popup = popup_scene.instantiate()
	
	var root = get_tree().root
	
	root.add_child.call_deferred(current_popup)
	
	if current_popup.is_inside_tree():
		_setup_popup(current_popup, achievement_data)
	else:
		current_popup.tree_entered.connect(_on_popup_entered_tree.bind(achievement_data), CONNECT_ONE_SHOT)

func _setup_popup(popup: Control, achievement_data: Dictionary):
	print("🎯 Настройка попапа...")
	popup.set_achievement_data(achievement_data)
	
	if popup.has_signal("popup_finished"):
		popup.popup_finished.connect(_on_popup_finished, CONNECT_ONE_SHOT)
	else:
		print("🎯 Сигнал popup_finished не найден, используем таймер")
		get_tree().create_timer(5.0).timeout.connect(_on_popup_finished, CONNECT_ONE_SHOT)

func _on_popup_entered_tree(achievement_data: Dictionary):
	if current_popup and current_popup.is_inside_tree():
		_setup_popup(current_popup, achievement_data)

func _on_popup_finished():
	print("🎯 Ачивка завершила показ, проверяем очередь...")
	if current_popup:
		current_popup.queue_free()
		current_popup = null
	
	is_showing_popup = false
	
	call_deferred("_process_queue")

func clear_queue():
	print("🎯 Очистка очереди ачивок")
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
