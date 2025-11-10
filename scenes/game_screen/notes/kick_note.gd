# scenes/game_screen/notes/kick_note.gd
class_name KickNote
extends BaseNote

var color: Color = Color("#32C832")

func _init(p_lane: int, p_y: float):
	super._init(p_lane, p_y)
	note_type = "KickNote"
