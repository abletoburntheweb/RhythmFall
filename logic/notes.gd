# logic/notes.gd

class BaseNote:
	var lane: int
	var y: float
	var height: float = 20.0
	var active: bool = true
	var color: Color = Color.RED 

	func _init(lane_num: int, y_pos: float = 0):
		lane = lane_num
		y = y_pos

	func update(speed: float = 6.0):
		y += speed
		if y > 1080:
			active = false

	func on_hit() -> int:
		active = false
		return 100

class DefaultNote extends BaseNote:
	func _init(lane_num: int, y_pos: float = 0):
		super(lane_num, y_pos)
		color = Color.RED  

class HoldNote extends BaseNote:
	var length: float
	var hold_time: float
	var held_time: float = 0.0
	var hit_progress: float = 0.0
	var is_being_held: bool = false
	var captured: bool = false
	var fall_speed: float = 6.0

	func _init(lane_num: int, y_pos: float = 0, length_val: float = 150.0, hold_time_val: float = 1000.0):
		super(lane_num, y_pos)
		length = length_val
		height = length_val
		hold_time = hold_time_val
		color = Color.RED  

	func update(speed: float = 6.0, delta_ms: float = 16.0):
		var current_fall_speed = speed

		if is_being_held and not captured:
			held_time += delta_ms
			hit_progress = min(held_time / hold_time, 1.0)

			if hit_progress >= 1.0:
				captured = true
				active = false
		else:
			y += current_fall_speed

		if y > 1080 and not captured:
			active = false

	func on_hit() -> int:
		if not captured:
			return 100
		else:
			return 0

class KickNote extends BaseNote:
	func _init(lane_num: int, y_pos: float = 0):
		super(lane_num, y_pos)
		color = Color.GREEN 

class SnareNote extends BaseNote:
	func _init(lane_num: int, y_pos: float = 0):
		super(lane_num, y_pos)
		color = Color.BLUE 
