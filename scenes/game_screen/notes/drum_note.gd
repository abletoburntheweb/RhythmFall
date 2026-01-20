# scenes/game_screen/notes/drum_note.gd
class_name DrumNote
extends BaseNote

const LANE_COLORS = [
	Color("#32C832"),  
	Color("#FF3333"), 
	Color("#FFD700"), 
	Color("#33CCFF") 
]

var color: Color

func _init(p_lane: int, p_y: float, p_spawn_time: float = 0.0):
	super._init(p_lane, p_y, p_spawn_time) 
	note_type = "DrumNote"
	if p_lane >= 0 and p_lane < LANE_COLORS.size():
		color = LANE_COLORS[p_lane]
	else:
		color = Color.WHITE
