# scenes/game_screen/notes/base_note.gd
class_name BaseNote
extends RefCounted 

var lane: int
var y: float
var active: bool = true
var time: float = 0.0
var visual_node: Variant 
var note_type: String = "BaseNote" 
var was_hit: bool = false 
var is_missed: bool = false 

func _init(p_lane: int, p_y: float):
	lane = p_lane
	y = p_y
	visual_node = null

func update(speed: float):
	y += speed
	if visual_node:
		visual_node.position.y = y
	if y > 1080: 
		active = false 

func on_hit():
	was_hit = true
	is_missed = false
	active = false 
	return 100
