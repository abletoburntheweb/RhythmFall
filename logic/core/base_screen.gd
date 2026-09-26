# logic/core/base_screen.gd
class_name BaseScreen
extends Control

var transitions = null 


func setup_managers(trans) -> void:  
	transitions = trans


func _get_loading_overlay() -> LoadingOverlay:
	var engine := get_parent()
	if engine and engine.has_method("get_loading_overlay"):
		return engine.get_loading_overlay()
	return null


func run_with_loading(message: String, task: Callable) -> void:
	var engine := get_parent()
	if engine and engine.has_method("run_async"):
		engine.run_async(_run_with_loading.bind(message, task))
	elif task.is_valid():
		task.call()


func _run_with_loading(message: String, task: Callable) -> void:
	var overlay := _get_loading_overlay()
	if overlay:
		overlay.show_loading(message, true)
		# Wait for the spinner to actually reach the screen before running the
		# heavy, blocking task; otherwise the overlay is never painted and the
		# user just sees a frozen frame during the load.
		await get_tree().process_frame
		await RenderingServer.frame_post_draw
	if task.is_valid():
		await task.call()
	if overlay:
		overlay.hide_loading()

func _on_back_pressed():
	var parent_node = get_parent()
	var game_engine = null
	if parent_node and parent_node.has_method("prepare_screen_exit"):
		game_engine = parent_node
	elif get_tree().root.has_node("GameEngine"):
		game_engine = get_tree().root.get_node("GameEngine")

	if game_engine and game_engine.has_method("prepare_screen_exit") and game_engine.current_screen == self:
		if game_engine.prepare_screen_exit(self):
			pass
		else:
			printerr("BaseScreen.gd: ОШИБКА подготовки экрана к выходу через GameEngine.")

	cleanup_before_exit()

	MusicManager.play_cancel_sound()

	_execute_close_transition()

func _execute_close_transition() -> void:
	push_warning("BaseScreen.gd: _execute_close_transition() не переопределён в " + get_script().resource_path)
	if transitions:
		transitions.open_main_menu()

func cleanup_before_exit() -> void:
	pass


func _enter_tree() -> void:
	if LocaleManager and not LocaleManager.locale_changed.is_connected(_on_locale_changed):
		LocaleManager.locale_changed.connect(_on_locale_changed)
	call_deferred("_apply_ui_interactions")
	call_deferred("apply_locale")


func _exit_tree() -> void:
	if LocaleManager and LocaleManager.locale_changed.is_connected(_on_locale_changed):
		LocaleManager.locale_changed.disconnect(_on_locale_changed)
	cleanup_before_exit()


func _on_locale_changed(_locale: String) -> void:
	apply_locale()


func apply_locale() -> void:
	pass


func _apply_ui_interactions() -> void:
	UiInteractionApplier.apply_from_engine(self)


func _unhandled_input(event: InputEvent) -> void:
	if UiScreenHotkeys.is_global_loading_active(get_viewport()):
		get_viewport().set_input_as_handled()
		return
	# Only ui_cancel — Esc is already mapped to it. Checking KEY_ESCAPE too
	# fires twice (InputEventKey + InputEventAction) and doubles cancel SFX.
	if event.is_action_pressed("ui_cancel"):
		accept_event()
		_on_back_pressed()
