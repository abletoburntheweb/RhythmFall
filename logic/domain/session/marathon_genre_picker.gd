# logic/domain/session/marathon_genre_picker.gd
class_name MarathonGenrePicker
extends RefCounted

const _MarathonRouteLength = preload("res://logic/domain/session/marathon_route_length.gd")
const _MarathonSessionConfig = preload("res://logic/domain/session/marathon_session_config.gd")
const _SessionScopeResolver = preload("res://logic/domain/session/session_scope_resolver.gd")
const _ProfileGenrePortrait = preload("res://logic/domain/profile/profile_genre_portrait.gd")

static var _meets_cache: Dictionary = {}
static var _diag_per_route: Dictionary = {}
static var _diag_all_calls: int = 0
static var _diag_all_hits: int = 0
static var _diag_all_misses: int = 0


static func clear_meets_cache() -> void:
	_meets_cache.clear()
	_diag_per_route.clear()
	_diag_all_calls = 0
	_diag_all_hits = 0
	_diag_all_misses = 0


static func _diag_ensure_route(route_id: String) -> Dictionary:
	var rid := str(route_id).strip_edges()
	if rid == "":
		rid = "<no_route>"
	if not _diag_per_route.has(rid):
		_diag_per_route[rid] = {"calls": 0, "hits": 0, "misses": 0, "resolve_calls": 0, "resolve_total": 0}
	return _diag_per_route[rid] as Dictionary


static func _meets_cache_key(genre_id: String, template: Dictionary, min_required: int) -> String:
	# Key must include all template fields that affect to_scope_config / resolve_scope for genre check
	var gid := str(genre_id).strip_edges()
	var dmin := str(template.get("difficulty_min", ""))
	var dmax := str(template.get("difficulty_max", ""))
	var dmin_s := str(template.get("duration_min_sec", ""))
	var dmax_s := str(template.get("duration_max_sec", ""))
	var mod_pol := str(template.get("mod_policy", ""))
	var len_class := str(template.get("length_class", ""))
	return "%s|%d|%s|%s|%s|%s|%s|%s" % [gid, min_required, dmin, dmax, dmin_s, dmax_s, mod_pol, len_class]


static func pick_genre_for_template(
	template: Dictionary,
	seed_key: String,
	context_id: String = ""
) -> Dictionary:
	var _diag_route_id := str(template.get("route_id", "")).strip_edges()
	if _diag_route_id == "":
		_diag_route_id = "<no_route>"
	_diag_ensure_route(_diag_route_id)
	var _diag_before_calls: int = int((_diag_per_route[_diag_route_id] as Dictionary).get("calls", 0))
	var _diag_before_hits: int = int((_diag_per_route[_diag_route_id] as Dictionary).get("hits", 0))
	var _diag_before_resolve: float = float((_diag_per_route[_diag_route_id] as Dictionary).get("resolve_total", 0.0))
	var _diag_t0 := Time.get_ticks_usec()
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
			var _diag_after := _diag_per_route[_diag_route_id] as Dictionary
			var _calls: int = int(_diag_after.get("calls", 0)) - _diag_before_calls
			var _hits: int = int(_diag_after.get("hits", 0)) - _diag_before_hits
			var _misses: int = _calls - _hits
			var _res_total: float = float(_diag_after.get("resolve_total", 0.0)) - _diag_before_resolve
			var _uniq_genres: int = order.size()
			# For this pick, difficulty/duration/mod/len are from template (same for all probes), so unique=1
			return {
				"genre_id": genre_id,
				"preferred_id": preferred_id,
				"used_fallback": genre_id != preferred_id,
			}
	var _diag_after2 := _diag_per_route[_diag_route_id] as Dictionary
	var _calls2: int = int(_diag_after2.get("calls", 0)) - _diag_before_calls
	var _hits2: int = int(_diag_after2.get("hits", 0)) - _diag_before_hits
	var _misses2: int = _calls2 - _hits2
	var _res_total2: float = float(_diag_after2.get("resolve_total", 0.0)) - _diag_before_resolve
	var _uniq_genres2: int = order.size()
	# No genre had enough songs — fallback to preferred (still considered fallback)
	return {
		"genre_id": preferred_id if preferred_id != "" else "rock",
		"preferred_id": preferred_id,
		"used_fallback": true,
	}


static func genre_meets_requirements(template: Dictionary, min_required: int) -> bool:
	var genre_id := str(template.get("genre_group_id", "")).strip_edges()
	var route_id := str(template.get("route_id", "")).strip_edges()
	if route_id == "":
		route_id = "<no_route>"
	_diag_ensure_route(route_id)
	var d: Dictionary = _diag_per_route[route_id] as Dictionary
	d["calls"] = int(d.get("calls", 0)) + 1
	_diag_all_calls += 1
	var key := _meets_cache_key(genre_id, template, min_required)
	var dmin := str(template.get("difficulty_min", ""))
	var dmax := str(template.get("difficulty_max", ""))
	var dmin_s := str(template.get("duration_min_sec", ""))
	var dmax_s := str(template.get("duration_max_sec", ""))
	var mod_pol := str(template.get("mod_policy", ""))
	var len_class := str(template.get("length_class", ""))
	if _meets_cache.has(key):
		d["hits"] = int(d.get("hits", 0)) + 1
		_diag_all_hits += 1
		return bool(_meets_cache[key])
	d["misses"] = int(d.get("misses", 0)) + 1
	_diag_all_misses += 1
	var _t := Time.get_ticks_usec()
	var scope_config := _MarathonSessionConfig.to_scope_config({}, template)
	var res: bool = false
	var via_index := false
	var dt: float = 0.0
	# Library-side index: single lazy build, then in-memory query without filesystem scan
	if SongLibrary != null and SongLibrary.has_method("has_minimum_matching_songs_via_index"):
		var _t_idx := Time.get_ticks_usec()
		res = SongLibrary.has_minimum_matching_songs_via_index(scope_config, min_required)
		dt = (Time.get_ticks_usec() - _t_idx) / 1000.0
		via_index = true
	else:
		res = _SessionScopeResolver.has_minimum_matching_songs(scope_config, min_required)
		dt = (Time.get_ticks_usec() - _t) / 1000.0
	d["resolve_calls"] = int(d.get("resolve_calls", 0)) + 1
	d["resolve_total"] = float(d.get("resolve_total", 0.0)) + dt
	if not d.has("index_calls"):
		d["index_calls"] = 0
		d["index_total"] = 0.0
	if via_index:
		d["index_calls"] = int(d.get("index_calls", 0)) + 1
		d["index_total"] = float(d.get("index_total", 0.0)) + dt
	_meets_cache[key] = res
	return res


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