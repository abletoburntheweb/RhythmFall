# logic/domain/replay/replay_ui.gd
extends RefCounted
class_name ReplayUi

const _SongSelectStrings = preload("res://logic/domain/library/song_select_strings.gd")
const _ReplayStore = preload("res://logic/domain/replay/replay_store.gd")


static func format_watch_badge(payload: Dictionary) -> String:
	var track: Dictionary = payload.get("track", {}) if payload.get("track", {}) is Dictionary else {}
	var chart: Dictionary = payload.get("chart", {}) if payload.get("chart", {}) is Dictionary else {}
	var artist := _SongSelectStrings.display_track_artist(track.get("artist", ""))
	var title := _SongSelectStrings.display_track_title(
		track.get("title", ""),
		String(track.get("chart_id", "")),
	)
	var track_line := title
	if artist != "" and title != "":
		track_line = "%s — %s" % [artist, title]
	elif artist != "":
		track_line = artist
	var instrument := _SongSelectStrings.format_instrument_label(String(chart.get("instrument", "drums")))
	var mode := _SongSelectStrings.format_chart_mode_label(String(chart.get("mode", "")))
	if mode == "":
		mode = "—"
	return TranslationServer.translate("REPLAY_WATCH_BADGE_FMT") % [track_line, instrument, mode]


static func open_replays_folder() -> void:
	var dir := _ReplayStore.replays_dir()
	var abs_path := ReplayStore.absolute_path(dir)
	DirAccess.make_dir_recursive_absolute(abs_path)
	OS.shell_open(abs_path)
