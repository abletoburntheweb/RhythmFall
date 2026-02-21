class_name Note
extends BaseNote

var color: Color = Color("#C83232")
var height: float = 0.0
var duration: float = 0.0
var hold_time_ms: float = 0.0
var held_time: float = 0.0
var hit_progress: float = 0.0
var is_being_held: bool = false
var captured: bool = false
var fall_speed: float = 6.0
var note_kind: String = "DefaultNote"

func _init(p_lane: int, p_y: float, p_spawn_time: float = 0.0, p_kind: String = "DefaultNote", p_height: float = 0.0, p_hold_time_ms: float = 0.0):
	super._init(p_lane, p_y, p_spawn_time)
	note_kind = p_kind
	if note_kind == "HoldNote":
		height = p_height
		hold_time_ms = p_hold_time_ms
		duration = p_hold_time_ms / 1000.0
	note_type = note_kind

func update(speed: float):
	if note_kind == "HoldNote":
		var current_fall_speed = speed if speed != 0 else fall_speed
		if is_being_held and not captured:
			held_time += 16.0
			hit_progress = min(held_time / hold_time_ms, 1.0)
			if hit_progress >= 1.0:
				captured = true
				active = false
		else:
			y += current_fall_speed
			if visual_node:
				visual_node.position.y = y
		if y > 1080 and not captured:
			active = false
	else:
		super.update(speed)

func on_hit():
	if note_kind == "HoldNote":
		if not captured:
			is_being_held = true
			was_hit = true
			is_missed = false
			return 100
		else:
			return 0
	return super.on_hit()
