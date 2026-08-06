# One-shot discovery events for History → Timeline (not milestone shelf).
extends RefCounted
class_name ProfileDiscoveryFirsts

const _RhythmRating = preload("res://logic/domain/rhythm/rhythm_rating.gd")
const _RunModifiers = preload("res://logic/domain/modifiers/run_modifiers.gd")
const _GoalDiff = preload("res://logic/domain/generation/generation_goal_difficulty.gd")
const _GenrePortrait = preload("res://logic/domain/profile/profile_genre_portrait.gd")
const _GenreGroupIcons = preload("res://logic/domain/library/genre_group_icons.gd")

# Kind strings (avoid preload cycle with ProfileEventLog).
const KIND_INSTRUMENT_FIRST := "instrument_first"
const KIND_CHART_STYLE_FIRST := "chart_style_first"
const KIND_MOD_FIRST := "mod_first"
const KIND_GENRE_GROUP_FIRST := "genre_group_first"


## Mutates `discovery` (id → date). Returns event payloads when `emit_events` is true.
static func apply_run(discovery: Dictionary, run: Dictionary, emit_events: bool) -> Array:
	if discovery == null:
		return []
	if _RunModifiers.blocks_track_result_save(run.get("modifiers", [])):
		return []
	var grade := str(run.get("grade", "")).strip_edges().to_upper()
	if grade == "" or grade == "F":
		return []
	var date_str := str(run.get("date", "")).strip_edges()
	if date_str == "":
		date_str = Time.get_datetime_string_from_system(true)
	var song_path := str(run.get("song_path", "")).replace("\\", "/").trim_suffix("/")
	var detail := _track_line(run)
	var events: Array = []

	_claim_instrument(discovery, run, date_str, song_path, detail, emit_events, events)
	_claim_chart_style(discovery, run, date_str, song_path, detail, emit_events, events)
	_claim_mods(discovery, run, date_str, song_path, detail, emit_events, events)
	_claim_genre_group(discovery, run, date_str, song_path, detail, emit_events, events)
	return events


## Claims first SS in a genre group. Returns group id when newly claimed, else "".
static func claim_genre_group_ss_first(discovery: Dictionary, run: Dictionary) -> String:
	if discovery == null:
		return ""
	if _RunModifiers.blocks_track_result_save(run.get("modifiers", [])):
		return ""
	var grade := str(run.get("grade", "")).strip_edges().to_upper()
	if grade != "SS":
		return ""
	var date_str := str(run.get("date", "")).strip_edges()
	if date_str == "":
		date_str = Time.get_datetime_string_from_system(true)
	var song_path := str(run.get("song_path", "")).replace("\\", "/").trim_suffix("/")
	var group := _resolve_genre_group(run, song_path)
	if group == "" or group == "_other":
		return ""
	var key := "ss_ggroup_%s" % group
	if discovery.has(key):
		return ""
	discovery[key] = date_str
	return group


static func normalize_discovery_instrument(instrument: String) -> String:
	# standard/fullmix → drums (same idea as ActivityCalendar); only drums/bass count.
	var key := _RhythmRating.normalize_instrument(instrument)
	match key:
		"bass":
			return "bass"
		"drums", "standard", "fullmix", "":
			return "drums"
		_:
			return ""


static func instrument_locale_key(instrument: String) -> String:
	match normalize_discovery_instrument(instrument):
		"bass":
			return "GEN_INST_BASS"
		"drums":
			return "GEN_INST_DRUMS"
		_:
			return ""


static func chart_style_key(mode: String) -> String:
	var stem := _RhythmRating.normalize_mode(mode)
	var pair := _GoalDiff.pair_from_stem(stem)
	var goal := _GoalDiff.sanitize_goal(str(pair.get("goal", _GoalDiff.DEFAULT_GOAL)))
	if goal == "original":
		return "style_original"
	var diff := _GoalDiff.sanitize_difficulty(str(pair.get("difficulty", _GoalDiff.DEFAULT_DIFFICULTY)))
	return "style_%s_%s" % [goal, diff]


static func chart_style_title_arg(mode: String) -> String:
	var stem := _RhythmRating.normalize_mode(mode)
	var pair := _GoalDiff.pair_from_stem(stem)
	var goal := _GoalDiff.sanitize_goal(str(pair.get("goal", _GoalDiff.DEFAULT_GOAL)))
	if goal == "original":
		return "original"
	var diff := _GoalDiff.sanitize_difficulty(str(pair.get("difficulty", _GoalDiff.DEFAULT_DIFFICULTY)))
	return "%s|%s" % [goal, diff]


static func format_chart_style_arg(arg: String) -> String:
	var a := arg.strip_edges().to_lower()
	if a == "" or a == "original":
		return TranslationServer.translate("GEN_GOAL_ORIGINAL")
	var parts := a.split("|")
	if parts.size() < 2:
		return arg
	var goal := _GoalDiff.sanitize_goal(str(parts[0]))
	var diff := _GoalDiff.sanitize_difficulty(str(parts[1]))
	var goal_label := TranslationServer.translate("GEN_GOAL_%s" % goal.to_upper())
	var diff_label := TranslationServer.translate(_GoalDiff.difficulty_label_key(goal, diff))
	return "%s · %s" % [goal_label, diff_label]


static func _claim_instrument(
	discovery: Dictionary,
	run: Dictionary,
	date_str: String,
	song_path: String,
	detail: String,
	emit_events: bool,
	events: Array
) -> void:
	var inst := normalize_discovery_instrument(str(run.get("instrument", "")))
	if inst == "":
		return
	var key := "inst_%s" % inst
	if discovery.has(key):
		return
	discovery[key] = date_str
	if not emit_events:
		return
	var icon := "drum.svg" if inst == "drums" else "audio-lines.svg"
	events.append({
		"kind": KIND_INSTRUMENT_FIRST,
		"id": "inst_first_%s" % inst,
		"ts": date_str,
		"title_key": "PROFILE_EVENT_INSTRUMENT_FIRST",
		"title_arg": instrument_locale_key(inst),
		"detail": detail,
		"song_path": song_path,
		"icon": icon,
	})


static func _claim_chart_style(
	discovery: Dictionary,
	run: Dictionary,
	date_str: String,
	song_path: String,
	detail: String,
	emit_events: bool,
	events: Array
) -> void:
	var mode := str(run.get("mode", ""))
	var key := chart_style_key(mode)
	if key == "" or discovery.has(key):
		return
	discovery[key] = date_str
	if not emit_events:
		return
	events.append({
		"kind": KIND_CHART_STYLE_FIRST,
		"id": "style_first_%s" % key.trim_prefix("style_"),
		"ts": date_str,
		"title_key": "PROFILE_EVENT_CHART_STYLE_FIRST",
		"title_arg": chart_style_title_arg(mode),
		"detail": detail,
		"song_path": song_path,
		"icon": "layers.svg",
	})


static func _claim_mods(
	discovery: Dictionary,
	run: Dictionary,
	date_str: String,
	song_path: String,
	detail: String,
	emit_events: bool,
	events: Array
) -> void:
	var mods: Array = run.get("modifiers", [])
	if not mods is Array:
		return
	for mod_id in _RunModifiers.sanitize(mods):
		var id := str(mod_id).strip_edges()
		if id == "" or id == _RunModifiers.ID_AUTOPLAY:
			continue
		var key := "mod_%s" % id
		if discovery.has(key):
			continue
		discovery[key] = date_str
		if not emit_events:
			continue
		events.append({
			"kind": KIND_MOD_FIRST,
			"id": "mod_first_%s" % id,
			"ts": date_str,
			"title_key": "PROFILE_EVENT_MOD_FIRST",
			"title_arg": _RunModifiers.title_i18n_key(id),
			"detail": detail,
			"song_path": song_path,
			"icon": "eye-off.svg",
		})


static func _claim_genre_group(
	discovery: Dictionary,
	run: Dictionary,
	date_str: String,
	song_path: String,
	detail: String,
	emit_events: bool,
	events: Array
) -> void:
	var group := _resolve_genre_group(run, song_path)
	if group == "" or group == "_other":
		return
	var key := "ggroup_%s" % group
	if discovery.has(key):
		return
	discovery[key] = date_str
	if not emit_events:
		return
	events.append({
		"kind": KIND_GENRE_GROUP_FIRST,
		"id": "ggroup_first_%s" % group,
		"ts": date_str,
		"title_key": "PROFILE_EVENT_GENRE_GROUP_FIRST",
		"title_arg": _GenrePortrait.group_locale_key(group),
		"detail": detail,
		"song_path": song_path,
		"icon": _GenreGroupIcons.icon_file_for_group(group),
	})


static func _resolve_genre_group(run: Dictionary, song_path: String) -> String:
	var primary := str(run.get("primary_genre", "")).strip_edges()
	if primary != "":
		return _GenreGroupIcons.group_id_for_genre(primary)
	if song_path != "":
		return _GenrePortrait.resolve_song_group_id(song_path)
	return ""


static func _track_line(run: Dictionary) -> String:
	var title := str(run.get("title", "")).strip_edges()
	var artist := str(run.get("artist", "")).strip_edges()
	if title == "" and artist == "":
		return ""
	if artist == "":
		return title
	if title == "":
		return artist
	return "%s — %s" % [artist, title]
