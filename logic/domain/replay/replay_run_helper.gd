# logic/domain/replay/replay_run_helper.gd
extends RefCounted
class_name ReplayRunHelper

const _ReplayRecorder = preload("res://logic/domain/replay/replay_recorder.gd")


static func begin_recording(
	recorder: ReplayRecorder,
	song_data: Dictionary,
	instrument: String,
	mode: String,
	lanes: int,
	modifiers: Array,
	modifier_params: Dictionary,
	play_mode: String,
	chart_tag: String = "",
) -> void:
	if recorder == null:
		return
	recorder.begin(
		ReplayResolver.build_track_ref(song_data),
		ReplayResolver.build_chart_ref(instrument, mode, lanes, chart_tag),
		ReplayResolver.build_run_ref(modifiers, modifier_params, play_mode),
	)


static func save_recording(
	recorder: ReplayRecorder,
	result: Dictionary,
	duration_ms: int,
) -> String:
	if recorder == null or not recorder.active():
		return ""
	return ReplayStore.save_payload(recorder.build_payload(result, duration_ms))
