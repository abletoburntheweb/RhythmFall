# scenes/game_screen/notes/snare_note.gd
class_name SnareNote
extends BaseNote

var color: Color = Color("#3296FF")

func _init(p_lane: int, p_y: float, p_spawn_time: float = 0.0):
	super._init(p_lane, p_y, p_spawn_time)
	note_type = "SnareNote"
