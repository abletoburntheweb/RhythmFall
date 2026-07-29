# logic/utils/notes_utils.gd
extends RefCounted
class_name NotesUtils

const GENERATION_MODES := ["original", "groove", "sparse"]  # legacy intents; use generation_chart_stems()
const _GenerationIntents := preload("res://logic/domain/generation/generation_intents.gd")
const _GoalDiff = preload("res://logic/domain/generation/generation_goal_difficulty.gd")
const LANE_COUNTS := [3, 4, 5]
const CANONICAL_MAX_LANES := 5
const DEFAULT_NOTES_ROOT := "user://notes"

const _RfcChartCodec := preload("res://logic/domain/charts/rfc_chart_codec.gd")

static var _exist_cache: Dictionary = {}
static var _exist_cache_epoch: String = ""
static var _ready_scope_cache: Dictionary = {}


static func normalize_notes_ready_scope(raw: int) -> int:
	# Legacy int scope; prefer resolve_ready_axes / ready_axes_is_mass.
	return _GoalDiff.clamp_scope(int(raw))


static func _cache_epoch() -> String:
	var fingerprint := ""
	if SettingsManager:
		fingerprint = _GoalDiff.ready_axes_fingerprint(_GoalDiff.resolve_ready_axes())
	return "%s|%s" % [get_notes_root(), fingerprint]


static func _sync_cache_epoch() -> void:
	var epoch := _cache_epoch()
	if epoch == _exist_cache_epoch:
		return
	_exist_cache.clear()
	_ready_scope_cache.clear()
	_exist_cache_epoch = epoch


static func invalidate_notes_cache() -> void:
	_exist_cache.clear()
	_ready_scope_cache.clear()
	_exist_cache_epoch = ""


static func normalize_song_path(song_path: String) -> String:
	return String(song_path).replace("\\", "/").strip_edges()


static func normalize_notes_root(path: String) -> String:
	var p := String(path).replace("\\", "/").strip_edges()
	while p.ends_with("/"):
		p = p.substr(0, p.length() - 1)
	return p


static func get_notes_root() -> String:
	if SettingsManager == null:
		return DEFAULT_NOTES_ROOT
	var configured := normalize_notes_root(String(SettingsManager.get_setting("user_notes_path", "")))
	if configured == "":
		return DEFAULT_NOTES_ROOT
	return configured


## Single lookup root: configured notes folder, or AppData default when unset.
static func active_notes_roots() -> Array[String]:
	return [get_notes_root()]


static func chart_id_from_song_path(song_path: String) -> String:
	var normalized := normalize_song_path(song_path)
	var ctx := HashingContext.new()
	ctx.start(HashingContext.HASH_SHA256)
	ctx.update(normalized.to_utf8_buffer())
	return ctx.finish().hex_encode().substr(0, 16)


static func base_name_from_song_path(song_path: String) -> String:
	return FileUtils.sanitize_name_for_fs(song_path.get_file().get_basename())


static func chart_dir_for_root(root: String, chart_id: String) -> String:
	return "%s/%s" % [normalize_notes_root(root), chart_id]


static func chart_dir(chart_id: String) -> String:
	return chart_dir_for_root(get_notes_root(), chart_id)


static func normalize_chart_tag(tag: String) -> String:
	var t := String(tag).strip_edges().to_lower()
	if t in ["", "production", "prod", "default", "main"]:
		return ""
	return t.replace(" ", "_")


static func chart_tag_for_preset_slot(slot: int) -> String:
	if slot < 1 or slot > 10:
		return ""
	return normalize_chart_tag("p%02d" % slot)


static func get_active_generation_preset_slot() -> int:
	if SettingsManager == null:
		return 0
	return int(SettingsManager.get_generation_presets().get("active_slot", 0))


static func resolve_chart_tag_for_generation(
	mode: String,
	active_slot: int,
	preset_dirty: bool,
) -> String:
	if String(mode).strip_edges().to_lower() != "custom":
		return ""
	if active_slot <= 0:
		return ""
	if preset_dirty:
		return ""
	return chart_tag_for_preset_slot(active_slot)


static func resolve_play_chart_tag(
	song_path: String,
	instrument: String,
	mode: String,
	lanes: int,
) -> String:
	if String(mode).strip_edges().to_lower() != "custom":
		return ""
	var slot := get_active_generation_preset_slot()
	if slot <= 0:
		return ""
	var preset_tag := chart_tag_for_preset_slot(slot)
	if UserPresets.is_active_generation_preset_dirty():
		if notes_exist(song_path, instrument, "custom", lanes, preset_tag):
			return preset_tag
		return ""
	return preset_tag


static func preset_chart_exists(song_path: String, instrument: String, slot: int, lanes: int = CANONICAL_MAX_LANES) -> bool:
	if song_path == "" or slot <= 0:
		return false
	var tag := chart_tag_for_preset_slot(slot)
	if tag == "":
		return false
	return notes_exist(song_path, instrument, "custom", lanes, tag)


static func resolve_generation_save_chart_tag(task: Dictionary) -> String:
	if task.has("chart_tag"):
		var explicit := normalize_chart_tag(str(task.get("chart_tag", "")))
		if explicit != "":
			return explicit
	var mode := str(task.get("mode", "basic")).strip_edges().to_lower()
	var slot := int(task.get("preset_slot", get_active_generation_preset_slot()))
	var dirty := bool(task.get("preset_dirty", false))
	if mode == "custom" and not task.has("preset_dirty"):
		dirty = UserPresets.is_active_generation_preset_dirty()
	var tag := resolve_chart_tag_for_generation(mode, slot, dirty)
	if tag != "":
		return tag
	return get_generation_save_variant_tag()


static func generation_chart_stems() -> Array[String]:
	return _GoalDiff.all_stems()


static func resolve_mode_stem_key(mode_or_stem: String) -> String:
	var key := mode_or_stem.strip_edges().to_lower()
	if _GoalDiff.is_chart_stem(key):
		# Normalize legacy original_* → canonical "original".
		var pair := _GoalDiff.pair_from_stem(key)
		return _GoalDiff.chart_stem(
			str(pair.get("goal", _GoalDiff.DEFAULT_GOAL)),
			str(pair.get("difficulty", _GoalDiff.DEFAULT_DIFFICULTY)),
		)
	if key == "custom":
		if SettingsManager:
			var g := str(SettingsManager.get_setting("generation_goal", _GoalDiff.DEFAULT_GOAL)).strip_edges().to_lower()
			var d := str(SettingsManager.get_setting("generation_difficulty", _GoalDiff.DEFAULT_DIFFICULTY)).strip_edges().to_lower()
			return _GoalDiff.chart_stem(g, d)
		return _GoalDiff.chart_stem(_GoalDiff.DEFAULT_GOAL, _GoalDiff.DEFAULT_DIFFICULTY)
	return _GenerationIntents.resolve_chart_stem(key)


static func chart_intents_exist(song_path: String, instrument: String, _lanes: int = 4) -> Dictionary:
	return chart_stems_exist(song_path, instrument, _lanes)


static func _mode_stem_with_alias(instrument: String, stem_alias: String, chart_tag: String = "") -> String:
	var base := "%s_%s" % [instrument.to_lower(), stem_alias.strip_edges().to_lower()]
	var tag := normalize_chart_tag(chart_tag)
	if tag == "":
		return base
	return "%s_%s" % [base, tag]


static func chart_stems_exist(song_path: String, instrument: String, _lanes: int = 4) -> Dictionary:
	var present := _present_variant_stems(song_path)
	var ready: Dictionary = {}
	for stem_id in generation_chart_stems():
		var found := false
		for alias in _GoalDiff.stem_read_aliases(stem_id):
			if present.has(_mode_stem_with_alias(instrument, alias)):
				found = true
				break
		ready[stem_id] = found
	return ready


static func chart_variant_stem(instrument: String, mode: String, lanes: int, chart_tag: String = "") -> String:
	var stem_key := resolve_mode_stem_key(mode)
	var base := "%s_%s_lanes%d" % [instrument.to_lower(), stem_key, lanes]
	var tag := normalize_chart_tag(chart_tag)
	if tag == "":
		return base
	return "%s_%s" % [base, tag]


static func chart_mode_stem(instrument: String, mode: String, chart_tag: String = "") -> String:
	var stem_key := resolve_mode_stem_key(mode)
	var base := "%s_%s" % [instrument.to_lower(), stem_key]
	var tag := normalize_chart_tag(chart_tag)
	if tag == "":
		return base
	return "%s_%s" % [base, tag]


static func chart_mode_stem_from_chart_stem(stem: String) -> String:
	var cleaned := String(stem).strip_edges()
	if cleaned == "":
		return ""
	var re := RegEx.new()
	re.compile("_lanes\\d+$")
	var match := re.search(cleaned)
	if match:
		return cleaned.substr(0, match.get_start())
	return cleaned


static func chart_filename(instrument: String, mode: String, lanes: int, chart_tag: String = "") -> String:
	return "%s.rf" % chart_variant_stem(instrument, mode, lanes, chart_tag)


static func flat_chart_filename(chart_id: String, instrument: String, mode: String, lanes: int, chart_tag: String = "") -> String:
	return "%s_%s" % [chart_id, chart_filename(instrument, mode, lanes, chart_tag)]


static func preferred_chart_path(song_path: String, instrument: String, mode: String, lanes: int, chart_tag: String = "") -> String:
	var chart_id := chart_id_from_song_path(song_path)
	return "%s/%s" % [chart_dir(chart_id), chart_filename(instrument, mode, lanes, chart_tag)]


static func get_split_compare_variant_tag() -> String:
	if SettingsManager == null:
		return ""
	if not bool(SettingsManager.get_setting("split_compare_enabled", false)):
		return ""
	return normalize_chart_tag(String(SettingsManager.get_setting("split_compare_variant_tag", "exp")))


static func get_generation_save_variant_tag() -> String:
	if SettingsManager == null:
		return ""
	if not bool(SettingsManager.get_setting("generation_save_experimental_chart", false)):
		return ""
	return normalize_chart_tag(String(SettingsManager.get_setting("split_compare_variant_tag", "exp")))


static func _flat_chart_basename(chart_id: String, instrument: String, mode: String, lanes: int, chart_tag: String = "") -> String:
	return "%s_%s" % [chart_id, chart_variant_stem(instrument, mode, lanes, chart_tag)]


static func legacy_notes_dir(base_name: String, root: String = DEFAULT_NOTES_ROOT) -> String:
	return "%s/%s" % [root, base_name]


static func legacy_notes_filename(base_name: String, instrument: String, mode: String, lanes: int, compressed: bool) -> String:
	var ext := "json.gz" if compressed else "json"
	return "%s_%s_%s_lanes%d.%s" % [base_name, instrument, mode.to_lower(), lanes, ext]


static func legacy_notes_path(song_path: String, instrument: String, mode: String, lanes: int, compressed: bool, root: String = DEFAULT_NOTES_ROOT) -> String:
	var base_name := base_name_from_song_path(song_path)
	var dir := legacy_notes_dir(base_name, root)
	return "%s/%s" % [dir, legacy_notes_filename(base_name, instrument, mode, lanes, compressed)]


static func notes_dir(_base_name: String = "") -> String:
	return get_notes_root()


static func notes_filename(chart_id: String, instrument: String, mode: String, lanes: int) -> String:
	return flat_chart_filename(chart_id, instrument, mode, lanes)


static func _candidate_read_paths_for_mode_stem(
	song_path: String,
	instrument: String,
	mode: String,
	chart_tag: String = ""
) -> Array[String]:
	var paths: Array[String] = []
	var stem_key := resolve_mode_stem_key(mode)
	for root in active_notes_roots():
		var chart_id := chart_id_from_song_path(song_path)
		for alias in _GoalDiff.stem_read_aliases(stem_key):
			var stem := _mode_stem_with_alias(instrument, alias, chart_tag)
			for suffix in [".rf", ".rfc.gz", ".rfc", ".rf.gz"]:
				var p_nested := "%s/%s/%s%s" % [root, chart_id, stem, suffix]
				if not paths.has(p_nested):
					paths.append(p_nested)
			var flat_base := "%s_%s" % [chart_id, stem]
			for suffix in [".rf", ".rfc.gz", ".rfc", ".rf.gz"]:
				var p_flat := "%s/%s%s" % [root, flat_base, suffix]
				if not paths.has(p_flat):
					paths.append(p_flat)
	return paths


static func resolve_unified_mode_path(
	song_path: String,
	instrument: String,
	mode: String,
	chart_tag: String = ""
) -> String:
	var stem_key := resolve_mode_stem_key(mode)
	var stems := _present_variant_stems(song_path)
	for alias in _GoalDiff.stem_read_aliases(stem_key):
		var mode_stem := _mode_stem_with_alias(instrument, alias, chart_tag)
		if stems.has(mode_stem):
			return String(stems[mode_stem])
	for path in _candidate_read_paths_for_mode_stem(song_path, instrument, mode, chart_tag):
		var abs := DirectoryUtils.to_absolute(path)
		if abs != "" and FileAccess.file_exists(abs):
			return path
	return ""


static func unified_mode_chart_exists(
	song_path: String,
	instrument: String,
	mode: String,
	chart_tag: String = ""
) -> bool:
	return resolve_unified_mode_path(song_path, instrument, mode, chart_tag) != ""


static func read_chart_lanes(path: String, fallback: int = 4) -> int:
	return _RfcChartCodec.read_header_lanes(path, fallback)


static func _candidate_read_paths(song_path: String, instrument: String, mode: String, lanes: int, chart_tag: String = "") -> Array[String]:
	var paths: Array[String] = []
	var stem_key := resolve_mode_stem_key(mode)
	var tag := normalize_chart_tag(chart_tag)
	for root in active_notes_roots():
		var chart_id := chart_id_from_song_path(song_path)
		for alias in _GoalDiff.stem_read_aliases(stem_key):
			var stem := "%s_%s_lanes%d" % [instrument.to_lower(), alias, lanes]
			if tag != "":
				stem = "%s_%s" % [stem, tag]
			for suffix in [".rf", ".rfc.gz", ".rfc", ".rf.gz"]:
				var p_nested := "%s/%s/%s%s" % [root, chart_id, stem, suffix]
				if not paths.has(p_nested):
					paths.append(p_nested)
			var flat_base := "%s_%s" % [chart_id, stem]
			for suffix in [".rf", ".rfc.gz", ".rfc", ".rf.gz"]:
				var p_flat := "%s/%s%s" % [root, flat_base, suffix]
				if not paths.has(p_flat):
					paths.append(p_flat)
	return paths


static func _filename_to_variant_stem(filename: String) -> String:
	for ext in [".rfc.gz", ".rf.gz", ".rfc", ".rf", ".json.gz", ".json"]:
		if filename.ends_with(ext):
			return filename.substr(0, filename.length() - ext.length())
	return ""


static func _legacy_file_variant_stem(filename: String, base_name: String) -> String:
	var stem := _filename_to_variant_stem(filename)
	if stem == "":
		return ""
	var prefix := base_name + "_"
	if stem.begins_with(prefix):
		return stem.substr(prefix.length())
	return stem


static func _register_stem_path(present: Dictionary, stem: String, path: String) -> void:
	if stem != "":
		present[stem] = path


static func _present_variant_stems(song_path: String) -> Dictionary:
	_sync_cache_epoch()
	var cache_key := "stems|%s" % song_path
	if _exist_cache.has(cache_key) and _exist_cache[cache_key] is Dictionary:
		return _exist_cache[cache_key]
	var present: Dictionary = {}
	var chart_id := chart_id_from_song_path(song_path)
	for root in active_notes_roots():
		var nested_dir := chart_dir_for_root(root, chart_id)
		var nested_abs := DirectoryUtils.to_absolute(nested_dir)
		if nested_abs != "" and DirAccess.dir_exists_absolute(nested_abs):
			var d := DirAccess.open(nested_abs)
			if d:
				d.list_dir_begin()
				var name := d.get_next()
				while name != "":
					if not d.current_is_dir():
						var stem := _filename_to_variant_stem(name)
						if stem != "":
							_register_stem_path(present, stem, "%s/%s" % [nested_dir, name])
					name = d.get_next()
				d.list_dir_end()
		var abs_root := DirectoryUtils.to_absolute(normalize_notes_root(root))
		if abs_root != "":
			var rd := DirAccess.open(abs_root)
			if rd:
				var prefix := chart_id + "_"
				rd.list_dir_begin()
				var fname := rd.get_next()
				while fname != "":
					if not rd.current_is_dir() and fname.begins_with(prefix):
						var rest := fname.substr(prefix.length())
						var stem := _filename_to_variant_stem(rest)
						if stem != "":
							_register_stem_path(present, stem, "%s/%s" % [normalize_notes_root(root), fname])
					fname = rd.get_next()
				rd.list_dir_end()
	_exist_cache[cache_key] = present
	return present


static func resolve_existing_path(song_path: String, instrument: String, mode: String, lanes: int, chart_tag: String = "") -> String:
	_sync_cache_epoch()
	var tag_key := normalize_chart_tag(chart_tag)
	var cache_key := "%s|%s|%s|%d|%s" % [song_path, instrument, mode, lanes, tag_key]
	if _exist_cache.has(cache_key):
		return String(_exist_cache[cache_key])
	# Canonical: drums_original.rf (lanes in RFC header). Legacy: drums_original_lanes4.rf.
	var unified := resolve_unified_mode_path(song_path, instrument, mode, chart_tag)
	if unified != "":
		_exist_cache[cache_key] = unified
		return unified
	var stems := _present_variant_stems(song_path)
	var stem_key := resolve_mode_stem_key(mode)
	var tag := normalize_chart_tag(chart_tag)
	for alias in _GoalDiff.stem_read_aliases(stem_key):
		var variant_stem := "%s_%s_lanes%d" % [instrument.to_lower(), alias, lanes]
		if tag != "":
			variant_stem = "%s_%s" % [variant_stem, tag]
		if stems.has(variant_stem):
			var found_path := String(stems[variant_stem])
			_exist_cache[cache_key] = found_path
			return found_path
	for path in _candidate_read_paths(song_path, instrument, mode, lanes, chart_tag):
		var abs := DirectoryUtils.to_absolute(path)
		if abs != "" and FileAccess.file_exists(abs):
			_exist_cache[cache_key] = path
			return path
	_exist_cache[cache_key] = ""
	return ""


static func notes_path_by_song(song_path: String, instrument: String, mode: String, lanes: int, chart_tag: String = "") -> String:
	var existing := resolve_existing_path(song_path, instrument, mode, lanes, chart_tag)
	if existing != "":
		return existing
	if normalize_chart_tag(chart_tag) == "":
		return preferred_mode_chart_path(song_path, instrument, mode, chart_tag)
	return preferred_chart_path(song_path, instrument, mode, lanes, chart_tag)


static func notes_exist(song_path: String, instrument: String, mode: String, lanes: int, chart_tag: String = "") -> bool:
	return resolve_existing_path(song_path, instrument, mode, lanes, chart_tag) != ""


static func load_notes_array(song_path: String, instrument: String, mode: String, lanes: int, chart_tag: String = "") -> Array:
	var path := resolve_existing_path(song_path, instrument, mode, lanes, chart_tag)
	if path == "":
		return []
	return _RfcChartCodec.read_file(path)


static func resolve_track_labels(song_path: String) -> Dictionary:
	var artist := ""
	var title := ""
	if SongLibrary:
		var meta := SongLibrary.get_metadata_for_song(song_path)
		artist = String(meta.get("artist", "")).strip_edges()
		title = String(meta.get("title", "")).strip_edges()
	var artist_lc := artist.to_lower()
	var title_lc := title.to_lower()
	if artist_lc in ["неизвестен", "unknown", ""]:
		artist = ""
	if title_lc in ["н/д", "без названия", "unknown", ""]:
		title = ""
	if artist == "" or title == "":
		var stem := song_path.get_file().get_basename()
		for sep in [" — ", " - ", " – "]:
			if sep in stem:
				var parts := stem.split(sep, false, 1)
				if parts.size() == 2:
					if artist == "":
						artist = String(parts[0]).strip_edges()
					if title == "":
						title = String(parts[1]).strip_edges()
				break
		if title == "":
			title = stem
	return {"artist": artist, "title": title}


static func _chart_stem_from_filename(filename: String) -> String:
	var base := String(filename).replace("\\", "/").get_file()
	if base.ends_with(".rf"):
		return base.substr(0, base.length() - 3)
	if base.ends_with(".rfc.gz"):
		return base.substr(0, base.length() - 7)
	if base.ends_with(".rf.gz"):
		return base.substr(0, base.length() - 6)
	if base.ends_with(".rfc"):
		return base.substr(0, base.length() - 4)
	return ""


static func rhythm_dna_path_for_chart(chart_path: String) -> String:
	var rel := String(chart_path).replace("\\", "/").strip_edges()
	if rel == "":
		return ""
	var stem := _chart_stem_from_filename(rel.get_file())
	if stem == "":
		return ""
	var mode_stem := chart_mode_stem_from_chart_stem(stem)
	return "%s/%s.rfd" % [rel.get_base_dir(), mode_stem]


static func rhythm_dna_path_for_mode(
	song_path: String,
	instrument: String,
	mode: String,
	chart_tag: String = ""
) -> String:
	var chart_id := chart_id_from_song_path(song_path)
	if chart_id == "":
		return ""
	return "%s/%s.rfd" % [chart_dir(chart_id), chart_mode_stem(instrument, mode, chart_tag)]


static func legacy_rhythm_dna_path_for_chart(chart_path: String) -> String:
	var rel := String(chart_path).replace("\\", "/").strip_edges()
	if rel == "":
		return ""
	var stem := _chart_stem_from_filename(rel.get_file())
	if stem == "":
		return ""
	return "%s/%s.rhythm_dna.json" % [rel.get_base_dir(), stem]


static func _legacy_lane_rhythm_dna_path(chart_path: String) -> String:
	var rel := String(chart_path).replace("\\", "/").strip_edges()
	if rel == "":
		return ""
	var stem := _chart_stem_from_filename(rel.get_file())
	if stem == "":
		return ""
	return "%s/%s.rfd" % [rel.get_base_dir(), stem]


static func _sidecar_file_exists(rel_path: String) -> bool:
	if rel_path == "":
		return false
	var abs := DirectoryUtils.to_absolute(rel_path)
	if abs == "":
		return false
	return FileAccess.file_exists(abs) or (
		OS.get_name() == "Windows"
		and abs.find("\\") == -1
		and FileAccess.file_exists(abs.replace("/", "\\"))
	)


static func _read_sidecar_dictionary(rel_path: String, legacy_json_only: bool = false) -> Dictionary:
	if not _sidecar_file_exists(rel_path):
		return {}
	var file := DirectoryUtils.open_file(rel_path, FileAccess.READ)
	if file == null:
		return {}
	var text := file.get_as_text()
	if legacy_json_only:
		var parsed: Variant = JSON.parse_string(text)
		return parsed if parsed is Dictionary else {}
	return RfdPassportCodec.parse(text)


static func rhythm_dna_path(song_path: String, instrument: String, mode: String, lanes: int, chart_tag: String = "") -> String:
	var mode_path := rhythm_dna_path_for_mode(song_path, instrument, mode, chart_tag)
	if _sidecar_file_exists(mode_path):
		return mode_path
	var chart_path := resolve_existing_path(song_path, instrument, mode, lanes, chart_tag)
	if chart_path == "":
		return mode_path
	return rhythm_dna_path_for_chart(chart_path)


static func _rhythm_dna_sidecar_exists(chart_rel_path: String) -> bool:
	if _sidecar_file_exists(rhythm_dna_path_for_chart(chart_rel_path)):
		return true
	if _sidecar_file_exists(_legacy_lane_rhythm_dna_path(chart_rel_path)):
		return true
	return _sidecar_file_exists(legacy_rhythm_dna_path_for_chart(chart_rel_path))


static func rhythm_dna_exists(song_path: String, instrument: String, mode: String, lanes: int, chart_tag: String = "") -> bool:
	return has_full_rhythm_dna(song_path, instrument, mode, lanes, chart_tag)


static func has_full_rhythm_dna(
	song_path: String,
	instrument: String,
	mode: String,
	lanes: int,
	chart_tag: String = ""
) -> bool:
	var payload := load_rhythm_dna(song_path, instrument, mode, lanes, chart_tag)
	return not payload.is_empty() and not is_minimal_rhythm_dna(payload)


static func load_rhythm_dna(song_path: String, instrument: String, mode: String, lanes: int, chart_tag: String = "") -> Dictionary:
	var mode_rfd := rhythm_dna_path_for_mode(song_path, instrument, mode, chart_tag)
	var payload := _read_sidecar_dictionary(mode_rfd, false)
	if not payload.is_empty():
		return payload
	var chart_path := resolve_existing_path(song_path, instrument, mode, lanes, chart_tag)
	if chart_path == "":
		return {}
	var rfd_path := rhythm_dna_path_for_chart(chart_path)
	payload = _read_sidecar_dictionary(rfd_path, false)
	if not payload.is_empty():
		return payload
	payload = _read_sidecar_dictionary(_legacy_lane_rhythm_dna_path(chart_path), false)
	if not payload.is_empty():
		return payload
	return _read_sidecar_dictionary(legacy_rhythm_dna_path_for_chart(chart_path), true)


static func save_rhythm_dna_at_chart(chart_rel_path: String, payload: Variant) -> bool:
	if not (payload is Dictionary) or (payload as Dictionary).is_empty():
		return false
	var rel := rhythm_dna_path_for_chart(chart_rel_path)
	if rel == "":
		return false
	DirectoryUtils.ensure_dir_for_file(rel)
	var file := DirectoryUtils.open_file(rel, FileAccess.WRITE)
	if file == null:
		push_warning("NotesUtils: failed to save Rhythm DNA: %s" % DirectoryUtils.to_absolute(rel))
		return false
	file.store_string(RfdPassportCodec.serialize(payload as Dictionary))
	var legacy_lane := _legacy_lane_rhythm_dna_path(chart_rel_path)
	var legacy_lane_abs := DirectoryUtils.to_absolute(legacy_lane)
	if legacy_lane_abs != "" and legacy_lane_abs != DirectoryUtils.to_absolute(rel) and FileAccess.file_exists(legacy_lane_abs):
		DirAccess.remove_absolute(legacy_lane_abs)
	var legacy := legacy_rhythm_dna_path_for_chart(chart_rel_path)
	var legacy_abs := DirectoryUtils.to_absolute(legacy)
	if legacy_abs != "" and FileAccess.file_exists(legacy_abs):
		DirAccess.remove_absolute(legacy_abs)
	return true


static func save_rhythm_dna(
	song_path: String,
	instrument: String,
	mode: String,
	lanes: int,
	payload: Variant,
	chart_tag: String = ""
) -> bool:
	var chart_path := resolve_existing_path(song_path, instrument, mode, lanes, chart_tag)
	if chart_path == "":
		chart_path = preferred_chart_path(song_path, instrument, mode, lanes, chart_tag)
	return save_rhythm_dna_at_chart(chart_path, payload)


static func _parse_bpm_from_metadata(meta: Dictionary) -> float:
	var raw: Variant = meta.get("bpm", 0)
	if raw is int or raw is float:
		return float(raw)
	var s := String(raw).strip_edges().replace(",", ".")
	return float(s) if s.is_valid_float() else 0.0


static func is_minimal_rhythm_dna(dna: Dictionary) -> bool:
	if dna.is_empty():
		return true
	var meta: Dictionary = dna.get("meta", {}) if dna.get("meta", {}) is Dictionary else {}
	if bool(meta.get("incomplete", false)):
		return true
	var pipeline: Dictionary = dna.get("pipeline", {}) if dna.get("pipeline", {}) is Dictionary else {}
	var source := int(pipeline.get("source", 0))
	var pre_section := int(pipeline.get("pre_section", 0))
	if source > 0 or pre_section > 0:
		return false
	var decisions: Array = dna.get("decisions", []) if dna.get("decisions") is Array else []
	for item in decisions:
		if item is Dictionary and String(item.get("key", "")) != "DNA_DEC_MINIMAL":
			return false
	return int(pipeline.get("final_notes", 0)) > 0 or decisions.size() > 0


static func _file_mtime_unix(rel_path: String) -> int:
	if rel_path.strip_edges() == "":
		return 0
	var abs := DirectoryUtils.to_absolute(rel_path)
	if abs == "":
		return 0
	for candidate in [abs, abs.replace("/", "\\")]:
		if FileAccess.file_exists(candidate):
			return int(FileAccess.get_modified_time(candidate))
	return 0


static func _chart_newer_than_rhythm_dna(chart_rel_path: String) -> bool:
	var chart_mtime := _file_mtime_unix(chart_rel_path)
	if chart_mtime <= 0:
		return false
	var rfd_mtime := _file_mtime_unix(rhythm_dna_path_for_chart(chart_rel_path))
	if rfd_mtime <= 0:
		rfd_mtime = _file_mtime_unix(legacy_rhythm_dna_path_for_chart(chart_rel_path))
	if rfd_mtime <= 0:
		return true
	return chart_mtime > rfd_mtime


static func _delete_rhythm_dna_sidecar(chart_rel_path: String) -> void:
	for rel in [
		rhythm_dna_path_for_chart(chart_rel_path),
		_legacy_lane_rhythm_dna_path(chart_rel_path),
		legacy_rhythm_dna_path_for_chart(chart_rel_path),
	]:
		if rel == "":
			continue
		var abs := DirectoryUtils.to_absolute(rel)
		if abs != "" and FileAccess.file_exists(abs):
			DirAccess.remove_absolute(abs)


static func build_fallback_rhythm_dna(
	song_path: String,
	instrument: String,
	mode: String,
	lanes: int,
	note_count: int,
	bpm: float = 0.0,
	from_server: bool = false
) -> Dictionary:
	if note_count <= 0:
		return {}
	var labels := resolve_track_labels(song_path)
	var meta: Dictionary = SongLibrary.get_metadata_for_song(song_path) if SongLibrary else {}
	if bpm <= 0.0:
		bpm = _parse_bpm_from_metadata(meta)
	var genre := String(meta.get("primary_genre", "")).strip_edges()
	var found: Array = []
	if bpm > 0.0:
		found.append({"key": "DNA_FOUND_BPM", "args": {"bpm": int(round(bpm))}})
	var incomplete_reason := "server_empty" if from_server else "legacy_chart"
	return {
		"version": "0.1",
		"meta": {
			"incomplete": true,
			"reason": incomplete_reason,
		},
		"track": {
			"artist": String(labels.get("artist", "")),
			"title": String(labels.get("title", "")),
			"genre": genre,
			"bpm": bpm,
			"mode": mode,
			"preset_id": "%s_%s" % [instrument.to_lower(), mode.to_lower()],
			"instrument": instrument,
			"lanes": lanes,
		},
		"pipeline": {
			"final_notes": note_count,
			"final_events": note_count,
		},
		"found": found,
		"warnings": [],
		"decisions": [{"key": "DNA_DEC_MINIMAL"}],
		"genes": {
			"confidence": {
				"overall": 45,
				"drum_detection": 50,
				"beat_tracking": 85 if bpm > 0.0 else 45,
				"genre": 45,
				"pattern": 55,
			},
		},
	}


static func ensure_rhythm_dna_for_chart(
	song_path: String,
	instrument: String,
	mode: String,
	lanes: int,
	chart_tag: String = ""
) -> Dictionary:
	var existing := load_rhythm_dna(song_path, instrument, mode, lanes, chart_tag)
	if existing.is_empty():
		return {}
	if not is_minimal_rhythm_dna(existing):
		return existing
	var chart_path := resolve_existing_path(song_path, instrument, mode, lanes, chart_tag)
	if chart_path != "":
		_delete_rhythm_dna_sidecar(chart_path)
	return {}


static func preferred_mode_chart_path(song_path: String, instrument: String, mode: String, chart_tag: String = "") -> String:
	var chart_id := chart_id_from_song_path(song_path)
	return "%s/%s.rf" % [chart_dir(chart_id), chart_mode_stem(instrument, mode, chart_tag)]


static func absolute_mode_chart_path(
	song_path: String,
	instrument: String,
	mode: String,
	chart_tag: String = "",
) -> String:
	return DirectoryUtils.to_absolute(preferred_mode_chart_path(song_path, instrument, mode, chart_tag))


## Existing chart on disk, or where the next save would go (active notes folder only).
static func display_chart_path(
	song_path: String,
	instrument: String,
	mode: String,
	lanes: int = CANONICAL_MAX_LANES,
	chart_tag: String = "",
) -> String:
	if String(song_path).strip_edges() == "":
		return ""
	var rel := resolve_existing_path(song_path, instrument, mode, lanes, chart_tag)
	if rel != "":
		return DirectoryUtils.to_absolute(rel)
	return absolute_mode_chart_path(song_path, instrument, mode, chart_tag)


static func save_mode_chart_array(
	song_path: String,
	instrument: String,
	mode: String,
	chart_lanes: int,
	notes: Array,
	chart_tag: String = ""
) -> bool:
	var dst := preferred_mode_chart_path(song_path, instrument, mode, chart_tag)
	DirectoryUtils.ensure_dir_for_file(dst)
	var labels := resolve_track_labels(song_path)
	var lanes_header := clampi(chart_lanes, 3, CANONICAL_MAX_LANES)
	if not _RfcChartCodec.write_file(
		dst,
		notes,
		instrument,
		mode,
		lanes_header,
		String(labels.get("artist", "")),
		String(labels.get("title", ""))
	):
		push_warning("NotesUtils: failed to save unified chart: %s" % DirectoryUtils.to_absolute(dst))
		return false
	invalidate_notes_cache()
	if normalize_chart_tag(chart_tag) == "":
		_remove_legacy_lane_variants_for_mode(song_path, instrument, mode)
	return true


static func _remove_legacy_lane_variants_for_mode(song_path: String, instrument: String, mode: String) -> void:
	for ln in LANE_COUNTS:
		_remove_legacy_files_for_variant(song_path, instrument, mode, ln)


static func save_notes_array(song_path: String, instrument: String, mode: String, lanes: int, notes: Array, chart_tag: String = "") -> bool:
	var chart_id := chart_id_from_song_path(song_path)
	var dst := preferred_chart_path(song_path, instrument, mode, lanes, chart_tag)
	DirectoryUtils.ensure_dir_for_file(dst)
	var labels := resolve_track_labels(song_path)
	if not _RfcChartCodec.write_file(
		dst,
		notes,
		instrument,
		mode,
		lanes,
		String(labels.get("artist", "")),
		String(labels.get("title", ""))
	):
		push_warning("NotesUtils: failed to save chart: %s" % DirectoryUtils.to_absolute(dst))
		return false
	invalidate_notes_cache()
	if normalize_chart_tag(chart_tag) == "":
		_remove_legacy_files_for_variant(song_path, instrument, mode, lanes)
	return true


static func delete_notes_for_song(song_path: String) -> void:
	var chart_id := chart_id_from_song_path(song_path)
	for root in [get_notes_root(), DEFAULT_NOTES_ROOT]:
		var nested_dir := chart_dir_for_root(root, chart_id)
		if nested_dir != root and DirectoryUtils.exists(nested_dir):
			DirectoryUtils.delete_dir_recursive(nested_dir)
		_delete_files_with_prefix(chart_id + "_", root)
		var base_name := base_name_from_song_path(song_path)
		var legacy_dir := legacy_notes_dir(base_name, root)
		if legacy_dir != root and DirectoryUtils.exists(legacy_dir):
			DirectoryUtils.delete_dir_recursive(legacy_dir)
	invalidate_notes_cache()


static func _remove_legacy_files_for_variant(song_path: String, instrument: String, mode: String, lanes: int) -> void:
	var chart_id := chart_id_from_song_path(song_path)
	# Compute the canonical save target so we never delete it during legacy cleanup.
	var saved_abs := DirectoryUtils.to_absolute(preferred_chart_path(song_path, instrument, mode, lanes))
	for root in [get_notes_root(), DEFAULT_NOTES_ROOT]:
		var flat_base := _flat_chart_basename(chart_id, instrument, mode, lanes)
		for suffix in [".rfc.gz", ".rfc", ".rf.gz", ".rf"]:
			var p_flat := "%s/%s%s" % [root, flat_base, suffix]
			var abs_flat := DirectoryUtils.to_absolute(p_flat)
			if abs_flat != "" and abs_flat != saved_abs and FileAccess.file_exists(abs_flat):
				DirAccess.remove_absolute(abs_flat)
		var nested_stem := chart_variant_stem(instrument, mode, lanes)
		for suffix in [".rfc.gz", ".rfc", ".rf.gz", ".rf"]:
			var p_nested := "%s/%s/%s%s" % [root, chart_id, nested_stem, suffix]
			var abs_nested := DirectoryUtils.to_absolute(p_nested)
			if abs_nested != "" and abs_nested != saved_abs and FileAccess.file_exists(abs_nested):
				DirAccess.remove_absolute(abs_nested)
		for path in [
			legacy_notes_path(song_path, instrument, mode, lanes, true, root),
			legacy_notes_path(song_path, instrument, mode, lanes, false, root),
		]:
			var abs_legacy := DirectoryUtils.to_absolute(path)
			if abs_legacy != "" and abs_legacy != saved_abs and FileAccess.file_exists(abs_legacy):
				DirAccess.remove_absolute(abs_legacy)
		var legacy_dir := legacy_notes_dir(base_name_from_song_path(song_path), root)
		if legacy_dir != root and DirectoryUtils.exists(legacy_dir) and DirectoryUtils.is_empty(legacy_dir):
			DirectoryUtils.delete_dir_recursive(legacy_dir)


static func _delete_files_with_prefix(prefix: String, root: String) -> void:
	var abs_root := DirectoryUtils.to_absolute(root)
	if abs_root.is_empty():
		return
	var d := DirAccess.open(abs_root)
	if d == null:
		return
	d.list_dir_begin()
	var name := d.get_next()
	while name != "":
		if name != "." and name != ".." and not d.current_is_dir() and name.begins_with(prefix):
			DirAccess.remove_absolute("%s/%s" % [abs_root, name])
		name = d.get_next()
	d.list_dir_end()


static func notes_ready_for_scope(song_path: String, instrument: String, mode: String, lanes: int) -> bool:
	if song_path == "":
		return false
	_sync_cache_epoch()
	var play_tag := resolve_play_chart_tag(song_path, instrument, mode, lanes)
	var cache_key := "%s|%s|%s|%d|%s" % [song_path, instrument, mode, lanes, play_tag]
	if _ready_scope_cache.has(cache_key):
		return bool(_ready_scope_cache[cache_key])
	var ready := _notes_ready_for_scope_impl(song_path, instrument, mode, lanes, play_tag)
	_ready_scope_cache[cache_key] = ready
	return ready


static func _notes_ready_for_scope_impl(
	song_path: String,
	instrument: String,
	mode: String,
	lanes: int,
	chart_tag: String = "",
) -> bool:
	if chart_tag != "" and notes_exist(song_path, instrument, mode, lanes, chart_tag):
		return true
	if chart_tag == "" and unified_mode_chart_exists(song_path, instrument, mode):
		return true
	var axes := _GoalDiff.resolve_ready_axes({}, "", "", instrument)
	var stems := _GoalDiff.stems_for_ready_axes(axes.get("goals", []), axes.get("diffs", []))
	var instruments: Array = axes.get("instruments", [instrument])
	for inst_raw in instruments:
		var inst := str(inst_raw)
		for stem_id in stems:
			if not notes_exist(song_path, inst, stem_id, lanes):
				return false
	return true
