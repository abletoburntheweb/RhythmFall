# scenes/game_screen/notes/kick_note.gd
class_name KickNote
extends BaseNote

var color: Color = Color("#32C832")

func _init(p_lane: int, p_y: float, p_spawn_time: float = 0.0):
	super._init(p_lane, p_y, p_spawn_time)
	note_type = "KickNote"
