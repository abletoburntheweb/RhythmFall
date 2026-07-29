# scenes/game_screen/notes/note.gd
class_name Note
extends BaseNote

var color: Color = Color("#C83232")
var height: float = 0.0
var duration: float = 0.0
var hold_time_ms: float = 0.0
var held_time: float = 0.0
var hit_progress: float = 0.0
var is_being_held: bool = false
var captured: bool = false
var fall_speed: float = 6.0
var note_kind: String = "DefaultNote"
var lane_end: int = -1
var is_ghost: bool = false
var is_multilane: bool = false
var perfect_hold_counted: bool = false
var hold_head_node: ColorRect = null
var hold_body_node: ColorRect = null
var hold_released_early: bool = false
var hold_last_tick_ms: float = 0.0
var uses_leading_edge: bool = false

const BASS_HOLD_KINDS := ["HoldNote", "BassHoldNote", "BassSustainNote"]


func _init(
	p_lane: int,
	p_y: float,
	p_spawn_time: float = 0.0,
	p_kind: String = "DefaultNote",
	p_height: float = 0.0,
	p_hold_time_ms: float = 0.0,
	p_lane_end: int = -1
):
	super._init(p_lane, p_y, p_spawn_time)
	note_kind = p_kind
	lane_end = p_lane_end
	if note_kind in BASS_HOLD_KINDS or note_kind == "BassSlideNote":
		height = p_height
		hold_time_ms = p_hold_time_ms
		duration = p_hold_time_ms / 1000.0
		uses_leading_edge = true
	note_type = note_kind


func current_chart_lane() -> int:
	if note_kind == "BassSlideNote" and is_being_held and lane_end >= 0 and hold_time_ms > 0.0:
		var t := clampf(hit_progress, 0.0, 1.0)
		return int(round(lerpf(float(lane), float(lane_end), t)))
	return int(lane)


func update(speed: float, despawn_y: float, scroll_sign: float = 1.0, song_time: float = -1.0):
	if note_kind in BASS_HOLD_KINDS or note_kind == "BassSlideNote":
		if song_time >= 0.0:
			if not hold_released_early:
				hit_progress = clampf((song_time - time) / maxf(duration, 0.001), 0.0, 1.0)
			if is_being_held and not captured and not hold_released_early:
				if hit_progress >= 1.0:
					captured = true
					active = false
			if was_hit and song_time > time + duration + 0.02:
				active = false
		var passed_despawn: bool = y < despawn_y if scroll_sign < 0.0 else y > despawn_y
		if passed_despawn and not was_hit:
			active = false
	else:
		super.update(speed, despawn_y)


func on_hit():
	if note_kind in BASS_HOLD_KINDS or note_kind == "BassSlideNote":
		if not captured:
			is_being_held = true
			was_hit = true
			is_missed = false
			return 100
		else:
			return 0
	return super.on_hit()
