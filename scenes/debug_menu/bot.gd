# scenes/debug_menu/bot.gd
class_name AutoPlayer
extends RefCounted

var game_screen
var hit_tolerance: float = 30.0
var pressed_lanes: Dictionary = {}
var min_press_duration: float = 0.1 

func _init(screen):
	game_screen = screen

func simulate():
	if not game_screen.debug_menu.is_auto_play_enabled():
		return

	var current_time = game_screen.game_time

	var lanes_to_keep_pressed = []
	for note in game_screen.note_manager.get_notes():
		var in_hit_zone = abs(note.y - game_screen.hit_zone_y) < hit_tolerance

		if in_hit_zone:
			lanes_to_keep_pressed.append(note.lane)

			if not pressed_lanes.has(note.lane):
				pressed_lanes[note.lane] = {
					"time": current_time,
					"type": "tap"
				}
				if note.lane < game_screen.player.lanes_state.size():
					game_screen.player.lanes_state[note.lane] = true
				game_screen.check_hit(note.lane)
				game_screen.player.lane_pressed_changed.emit()

	var lanes_to_release = []
	for lane_key in pressed_lanes.keys():
		if not lanes_to_keep_pressed.has(lane_key):
			var press_info = pressed_lanes[lane_key]
			var time_held = current_time - press_info.time
			if time_held >= min_press_duration:
				lanes_to_release.append(lane_key)

	for lane in lanes_to_release:
		pressed_lanes.erase(lane)
		if lane < game_screen.player.lanes_state.size():
			game_screen.player.lanes_state[lane] = false
		game_screen.player.lane_pressed_changed.emit()

func reset():
	pressed_lanes.clear()
	for i in range(game_screen.player.lanes_state.size()):
		game_screen.player.lanes_state[i] = false
	game_screen.player.lane_pressed_changed.emit()
