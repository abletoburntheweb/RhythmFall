# logic/domain/session/marathon_genre_picker.gd
class_name MarathonGenrePicker
extends RefCounted

const _MarathonRouteLength = preload("res://logic/domain/session/marathon_route_length.gd")
const _MarathonSessionConfig = preload("res://logic/domain/session/marathon_session_config.gd")
const _SessionScopeResolver = preload("res://logic/domain/session/session_scope_resolver.gd")
const _ProfileGenrePortrait = preload("res://logic/domain/profile/profile_genre_portrait.gd")


static func pick_genre_for_template(
	template: Dictionary,
	seed_key: String,
	context_id: String = ""
) -> Dictionary:
	var min_required := int(
		_MarathonRouteLength.policy_from_template(template).get(
			"min_songs_required",
			template.get("min_songs_required", 3)
		)
	)
	var genres := _genre_candidates()
	var rng := _seeded_rng("%s_%s_genre" % [seed_key, context_id])
	var preferred_idx := rng.randi_range(0, maxi(0, genres.size() - 1)) if not genres.is_empty() else 0
	var preferred_id := str(genres[preferred_idx]) if not genres.is_empty() else "rock"
	var order: Array[String] = []
	if preferred_id != "":
		order.append(preferred_id)
	for genre_id in genres:
		if genre_id != preferred_id:
			order.append(genre_id)
	for genre_id in order:
		var probe := template.duplicate(true)
		probe["genre_group_id"] = genre_id
		probe["source_id"] = genre_id
		if genre_meets_requirements(probe, min_required):
			return {
				"genre_id": genre_id,
				"preferred_id": preferred_id,
				"used_fallback": genre_id != preferred_id,
			}
	return {
		"genre_id": preferred_id if preferred_id != "" else "rock",
		"preferred_id": preferred_id,
		"used_fallback": false,
	}


static func genre_meets_requirements(template: Dictionary, min_required: int) -> bool:
	var scope_config := _MarathonSessionConfig.to_scope_config({}, template)
	var scope := _SessionScopeResolver.resolve_scope(scope_config)
	var by_song: Dictionary = {}
	for raw in scope:
		if raw is not Dictionary:
			continue
		var song_path := str((raw as Dictionary).get("song_path", "")).strip_edges()
		if song_path == "":
			continue
		by_song[song_path] = true
	return by_song.size() >= min_required


static func _genre_candidates() -> Array[String]:
	var out: Array[String] = []
	for group_id in _ProfileGenrePortrait.all_group_ids():
		var gid := str(group_id).strip_edges()
		if gid == "" or gid == "_other":
			continue
		out.append(gid)
	return out


static func _seeded_rng(seed_text: String) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = int(absi(str(seed_text).hash()))
	return rng
