# scenes/game_screen/notes/snare_note.gd
class_name SnareNote
extends BaseNote

var color: Color = Color("#3296FF")

func _init(p_lane: int, p_y: float):
	super._init(p_lane, p_y)
	note_type = "SnareNote"
