# scenes/game_screen/notes/default_note.gd
class_name DefaultNote
extends BaseNote

var color: Color = Color("#C83232")

func _init(p_lane: int, p_y: float):
	super._init(p_lane, p_y)
	note_type = "DefaultNote"
