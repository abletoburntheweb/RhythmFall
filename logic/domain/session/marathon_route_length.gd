# logic/domain/session/marathon_route_length.gd
class_name MarathonRouteLength
extends RefCounted

const DEFAULT_TOLERANCE_PCT := 0.2
const MAX_TRACKS := 20


static func policy_from_template(template: Dictionary) -> Dictionary:
	var target_min := float(template.get("target_duration_minutes", 0.0))
	var min_tracks := int(template.get("min_tracks", 0))
	var max_tracks := int(template.get("max_tracks", 0))
	if target_min <= 0.0:
		var legacy_count := clampi(int(template.get("track_count", 5)), 3, MAX_TRACKS)
		if min_tracks <= 0:
			min_tracks = legacy_count
		if max_tracks <= 0:
			max_tracks = legacy_count
		target_min = _legacy_target_minutes(legacy_count)
	var tolerance := clampf(float(template.get("duration_tolerance_pct", DEFAULT_TOLERANCE_PCT)), 0.05, 0.45)
	var has_finale := bool(template.get("final_boss_track", false))
	var body_min := int(template.get("body_min_tracks", 0))
	var body_max := int(template.get("body_max_tracks", 0))
	if has_finale:
		if body_min <= 0:
			body_min = maxi(1, min_tracks - 1 if min_tracks > 0 else 1)
		if body_max <= 0:
			body_max = maxi(body_min, max_tracks - 1 if max_tracks > 0 else body_min)
		min_tracks = body_min + 1
		max_tracks = body_max + 1
	if min_tracks <= 0:
		min_tracks = 3
	if max_tracks < min_tracks:
		max_tracks = min_tracks
	max_tracks = clampi(max_tracks, min_tracks, MAX_TRACKS)
	min_tracks = clampi(min_tracks, 2, max_tracks)
	var target_sec := target_min * 60.0
	return {
		"target_duration_minutes": target_min,
		"target_duration_sec": target_sec,
		"min_duration_sec": target_sec * (1.0 - tolerance),
		"max_duration_sec": target_sec * (1.0 + tolerance),
		"min_tracks": min_tracks,
		"max_tracks": max_tracks,
		"min_songs_required": min_tracks,
		"tolerance_pct": tolerance,
		"has_finale": has_finale,
		"body_min_tracks": body_min if has_finale else min_tracks,
		"body_max_tracks": body_max if has_finale else max_tracks,
	}


static func uses_duration_policy(template: Dictionary) -> bool:
	return float(template.get("target_duration_minutes", 0.0)) > 0.0


static func has_finale(template: Dictionary) -> bool:
	return bool(template.get("final_boss_track", false))


static func hint_line(template: Dictionary) -> String:
	var policy := policy_from_template(template)
	var target_min := int(round(float(policy.get("target_duration_minutes", 0.0))))
	if bool(policy.get("has_finale", false)):
		var body_min := int(policy.get("body_min_tracks", 0))
		var body_max := int(policy.get("body_max_tracks", body_min))
		if body_min == body_max:
			return TranslationServer.translate("MARATHON_LENGTH_HINT_FINALE_FMT") % [target_min, body_min]
		return TranslationServer.translate("MARATHON_LENGTH_HINT_FINALE_RANGE_FMT") % [target_min, body_min, body_max]
	var min_tracks := int(policy.get("min_tracks", 0))
	var max_tracks := int(policy.get("max_tracks", 0))
	if min_tracks == max_tracks:
		return TranslationServer.translate("MARATHON_LENGTH_HINT_TRACKS_ONLY_FMT") % [target_min, min_tracks]
	return TranslationServer.translate("MARATHON_LENGTH_HINT_FMT") % [target_min, min_tracks, max_tracks]


static func tracks_range_label(template: Dictionary) -> String:
	var policy := policy_from_template(template)
	if bool(policy.get("has_finale", false)):
		var body_min := int(policy.get("body_min_tracks", 0))
		var body_max := int(policy.get("body_max_tracks", body_min))
		if body_min == body_max:
			return "%d+1" % body_min
		return "%d–%d+1" % [body_min, body_max]
	var min_tracks := int(policy.get("min_tracks", 0))
	var max_tracks := int(policy.get("max_tracks", 0))
	if min_tracks == max_tracks:
		return str(min_tracks)
	return "%d–%d" % [min_tracks, max_tracks]


static func not_enough_songs_message(template: Dictionary = {}, preview: Dictionary = {}) -> String:
	var min_need := _required_track_count(template, preview)
	return TranslationServer.translate("MARATHON_NOT_ENOUGH_SONGS_MIN_FMT") % min_need


static func catalog_status_message(template: Dictionary = {}, preview: Dictionary = {}) -> String:
	if preview.is_empty() or bool(preview.get("ok", false)):
		return ""
	var error := str(preview.get("error", "")).strip_edges()
	var available := int(preview.get("available_songs", 0))
	var required := _required_track_count(template, preview)
	var built := int(preview.get("track_count", 0))
	if error == "empty_scope" or available <= 0:
		return not_enough_songs_message(template, preview)
	if available < required:
		return not_enough_songs_message(template, preview)
	if error == "duration_short" or _is_duration_short(preview):
		var policy: Dictionary = preview.get("length_policy", {}) if preview.get("length_policy") is Dictionary else {}
		if policy.is_empty() and not template.is_empty():
			policy = policy_from_template(template)
		var need_min := float(policy.get("min_duration_sec", 0.0)) / 60.0
		var have_min := float(preview.get("estimated_duration_sec", 0.0)) / 60.0
		return TranslationServer.translate("MARATHON_ROUTE_DURATION_SHORT_FMT") % [
			_format_minutes_label(need_min),
			_format_minutes_label(have_min),
		]
	if built > 0 and built < required:
		return not_enough_songs_message(template, preview)
	return TranslationServer.translate("MARATHON_ROUTE_BUILD_BLOCKED_FMT") % hint_line(template)


static func catalog_list_subtitle(template: Dictionary, preview: Dictionary) -> String:
	if bool(preview.get("ok", false)):
		var built_count := int(preview.get("track_count", 0))
		return TranslationServer.translate("MARATHON_CATALOG_LIST_READY_FMT") % [
			built_count,
			_format_minutes_label(float(preview.get("estimated_duration_sec", 0.0)) / 60.0),
		]
	var status := catalog_status_message(template, preview)
	var hint := hint_line(template)
	if status == "":
		return hint
	return "%s · %s" % [status, hint]


static func _required_track_count(template: Dictionary, preview: Dictionary) -> int:
	var min_need := int(preview.get("required_track_count", 0))
	if min_need <= 0:
		var policy: Dictionary = preview.get("length_policy", {}) if preview.get("length_policy") is Dictionary else {}
		if policy.is_empty() and not template.is_empty():
			policy = policy_from_template(template)
		min_need = int(policy.get("min_tracks", template.get("min_songs_required", 3)))
	return maxi(min_need, 1)


static func _is_duration_short(preview: Dictionary) -> bool:
	var policy: Dictionary = preview.get("length_policy", {}) if preview.get("length_policy") is Dictionary else {}
	var min_sec := float(policy.get("min_duration_sec", 0.0))
	var est_sec := float(preview.get("estimated_duration_sec", 0.0))
	return min_sec > 0.0 and est_sec > 0.0 and est_sec + 0.001 < min_sec


static func _format_minutes_label(minutes: float) -> String:
	return TranslationServer.translate("MARATHON_CATALOG_DURATION_MIN_FMT") % maxi(1, int(round(minutes)))


static func apply_policy_to_template(raw: Dictionary) -> Dictionary:
	var out := raw.duplicate(true)
	if not uses_duration_policy(out):
		return out
	var policy := policy_from_template(out)
	out["min_tracks"] = int(policy.get("min_tracks", 3))
	out["max_tracks"] = int(policy.get("max_tracks", out["min_tracks"]))
	out["min_songs_required"] = int(policy.get("min_songs_required", out["min_tracks"]))
	out["track_count"] = out["max_tracks"]
	if bool(policy.get("has_finale", false)):
		out["body_min_tracks"] = int(policy.get("body_min_tracks", out["min_tracks"] - 1))
		out["body_max_tracks"] = int(policy.get("body_max_tracks", out["max_tracks"] - 1))
	return out


static func _legacy_target_minutes(track_count: int) -> float:
	match clampi(track_count, 3, MAX_TRACKS):
		3:
			return 10.0
		4, 5:
			return 20.0
		6, 7:
			return 25.0
		8, 9, 10:
			return 35.0
		11, 12, 13, 14, 15:
			return 60.0
		_:
			return 60.0
