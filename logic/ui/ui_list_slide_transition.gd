# logic/ui/ui_list_slide_transition.gd
extends RefCounted
class_name UiListSlideTransition

const OUT_DURATION := 0.14
const IN_DURATION := 0.2
const SLIDE_OFFSET := 14.0
const CROSSFADE_OFFSET := 5.0
const ACTIVE_META := &"_content_transition_active"


static func run(list_control: Control, rebuild: Callable, skip: bool = false) -> void:
	if skip or list_control == null or not is_instance_valid(list_control):
		rebuild.call()
		return
	var host := list_control.get_parent() as Control
	if host == null:
		rebuild.call()
		return
	if host.has_meta(ACTIVE_META) and bool(host.get_meta(ACTIVE_META)):
		rebuild.call()
		return
	var base_x: float = float(host.get_meta("_list_slide_base_x", host.position.x))
	if not host.has_meta("_list_slide_base_x"):
		host.set_meta("_list_slide_base_x", base_x)
	host.set_meta(ACTIVE_META, true)
	var host_id: int = host.get_instance_id()
	var tw: Tween = host.create_tween()
	tw.tween_property(host, "modulate:a", 0.0, OUT_DURATION).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.parallel().tween_property(host, "position:x", base_x - SLIDE_OFFSET, OUT_DURATION).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_callback(_slide_rebuild_mid.bind(host_id, rebuild, base_x))
	tw.tween_property(host, "modulate:a", 1.0, IN_DURATION).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(host, "position:x", base_x, IN_DURATION).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_callback(_finish_slide.bind(host_id, base_x))


static func crossfade(control: Control, apply_change: Callable, skip: bool = false, subtle_slide: bool = true) -> void:
	if skip or control == null or not is_instance_valid(control):
		apply_change.call()
		return
	if control.has_meta(ACTIVE_META) and bool(control.get_meta(ACTIVE_META)):
		apply_change.call()
		return
	control.set_meta(ACTIVE_META, true)
	var base_y: float = float(control.get_meta("_crossfade_base_y", control.position.y))
	if not control.has_meta("_crossfade_base_y"):
		control.set_meta("_crossfade_base_y", base_y)
	var control_id: int = control.get_instance_id()
	var out_duration := OUT_DURATION * 0.85
	var in_duration := IN_DURATION * 0.9
	var tw: Tween = control.create_tween()
	tw.tween_property(control, "modulate:a", 0.0, out_duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_callback(_crossfade_apply.bind(control_id, apply_change, base_y, subtle_slide))
	tw.tween_property(control, "modulate:a", 1.0, in_duration).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	if subtle_slide:
		tw.parallel().tween_property(control, "position:y", base_y, in_duration).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_callback(_finish_crossfade.bind(control_id, base_y))


static func _control_from_id(node_id: int) -> Control:
	var node := instance_from_id(node_id)
	if node is Control and is_instance_valid(node):
		return node as Control
	return null


static func _slide_rebuild_mid(host_id: int, rebuild: Callable, base_x: float) -> void:
	rebuild.call()
	var host := _control_from_id(host_id)
	if host:
		host.position.x = base_x + SLIDE_OFFSET


static func _finish_slide(host_id: int, base_x: float) -> void:
	var host := _control_from_id(host_id)
	if host == null:
		return
	host.position.x = base_x
	host.modulate.a = 1.0
	if host.has_meta(ACTIVE_META):
		host.remove_meta(ACTIVE_META)


static func _crossfade_apply(control_id: int, apply_change: Callable, base_y: float, subtle_slide: bool) -> void:
	apply_change.call()
	if not subtle_slide:
		return
	var control := _control_from_id(control_id)
	if control:
		control.position.y = base_y + CROSSFADE_OFFSET


static func _finish_crossfade(control_id: int, base_y: float) -> void:
	var control := _control_from_id(control_id)
	if control == null:
		return
	control.position.y = base_y
	control.modulate.a = 1.0
	if control.has_meta(ACTIVE_META):
		control.remove_meta(ACTIVE_META)
