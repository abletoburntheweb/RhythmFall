# scenes/game_screen/notes/base_note.gd
class_name BaseNote
extends RefCounted 

var lane: int
var y: float
var active: bool = true
var time: float = 0.0
var visual_node: Variant 
var note_type: String = "BaseNote" 
var was_hit: bool = false  # Добавляем флаг, что нота была поймана
var is_missed: bool = false # Добавляем флаг, что нота была пропущена

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
	# Помечаем, что нота была поймана
	was_hit = true
	# Помечаем, что она не пропущена (на всякий случай, хотя если сюда дошло, то is_missed = false)
	is_missed = false
	active = false
	return 100
