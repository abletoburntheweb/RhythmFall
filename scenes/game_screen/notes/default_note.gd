# scenes/game_screen/notes/default_note.gd
class_name DefaultNote
extends BaseNote

var color: Color = Color("#C83232")

func _init(p_lane: int, p_y: float, p_spawn_time: float = 0.0):
	super._init(p_lane, p_y, p_spawn_time)
	note_type = "DefaultNote"
