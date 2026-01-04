# scenes/game_screen/notes/hold_note.gd
class_name HoldNote
extends BaseNote

var color: Color = Color("#C83232")
var height: float
var duration: float
var hold_time_ms: float
var held_time: float = 0.0
var hit_progress: float = 0.0
var is_being_held: bool = false
var captured: bool = false
var fall_speed: float = 6.0

func _init(p_lane: int, p_y: float, p_spawn_time: float, p_height: float, p_hold_time_ms: float):
	super._init(p_lane, p_y, p_spawn_time) 
	height = p_height
	duration = p_hold_time_ms / 1000.0
	hold_time_ms = p_hold_time_ms
	note_type = "HoldNote"
	
func update(speed: float):
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

func on_hit():
	if not captured:
		return 100
	else:
		return 0
