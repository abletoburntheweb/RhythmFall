# logic/domain/rhythm/notes_utils.gd
extends RefCounted
class_name NotesUtils

const GENERATION_MODES := ["original", "groove", "sparse"]  # legacy intents; use generation_chart_stems()
const _GenerationIntents := preload("res://logic/domain/generation/generation_intents.gd")
const _GoalDiff = preload("res://logic/domain/generation/generation_goal_difficulty.gd")
const LANE_COUNTS := [3, 4, 5]
const CANONICAL_MAX_LANES := 5
const DEFAULT_NOTES_ROOT := "user://notes"

const _RfcChartCodec := preload("res://logic/domain/charts/rfc_chart_codec.gd")
const PerfTrace = preload("res://logic/utils/perf_trace.gd")

static var _exist_cache: Dictionary = {}
static var _exist_cache_mtime: Dictionary = {}
static var _exist_cache_epoch: String = ""
static var _ready_scope_cache: Dictionary = {}
static var _scope_fast_cache: Dictionary = {}
static var _scope_fast_cache_enabled: bool = false
static var _bulk_present_index: Dictionary = {}
static var _bulk_present_enabled: bool = false

# Forensic loop→resolve linkage (aggregate only, no per-path metric)
static var _forensic_loop_total_calls: int = 0
static var _forensic_loop_cache_hits: int = 0
static var _forensic_loop_filesystem: int = 0
static var _forensic_loop_keys: Dictionary = {}
static var _forensic_in_loop: bool = false
static var _forensic_last_filesystem: bool = false


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
	_exist_cache_mtime.clear()
	_ready_scope_cache.clear()
	_exist_cache_epoch = epoch


static func invalidate_notes_cache() -> void:
	_exist_cache.clear()
	_exist_cache_mtime.clear()
	_ready_scope_cache.clear()
	_scope_fast_cache.clear()
	_exist_cache_epoch = ""


static func begin_scope_fast_cache() -> void:
	_scope_fast_cache.clear()
	_scope_fast_cache_enabled = true


static func end_scope_fast_cache() -> void:
	_scope_fast_cache.clear()
	_scope_fast_cache_enabled = false


static func begin_bulk_present_scan() -> void:
	_bulk_present_index.clear()
	_bulk_present_enabled = true
	for root in active_notes_roots():
		var abs_root := DirectoryUtils.to_absolute(normalize_notes_root(root))
		if abs_root == "" or not DirAccess.dir_exists_absolute(abs_root):
			continue
		var d_root := DirAccess.open(abs_root)
		if d_root == null:
			continue
		d_root.list_dir_begin()
		var entry := d_root.get_next()
		while entry != "":
			if d_root.current_is_dir():
				var chart_id := entry
				var nested_dir := "%s/%s" % [normalize_notes_root(root), chart_id]
				var abs_nested := DirectoryUtils.to_absolute(nested_dir)
				if abs_nested != "" and DirAccess.dir_exists_absolute(abs_nested):
					var d_nested := DirAccess.open(abs_nested)
					if d_nested:
						d_nested.list_dir_begin()
						var fname := d_nested.get_next()
						while fname != "":
							if not d_nested.current_is_dir():
								var stem := _filename_to_variant_stem(fname)
								if stem != "":
									if not _bulk_present_index.has(chart_id):
										_bulk_present_index[chart_id] = {}
									(_bulk_present_index[chart_id] as Dictionary)[stem] = "%s/%s" % [nested_dir, fname]
							fname = d_nested.get_next()
						d_nested.list_dir_end()
			entry = d_root.get_next()
		d_root.list_dir_end()


static func end_bulk_present_scan() -> void:
	_bulk_present_index.clear()
	_bulk_present_enabled = false


static func _notify_library_index_changed(reason: String = "") -> void:
	if SongLibrary and SongLibrary.has_method("invalidate_library_index"):
		SongLibrary.invalidate_library_index(reason)


static func _invalidate_cache_for_song(song_path: String) -> void:
	if song_path == "":
		return
	var norm := normalize_song_path(song_path)
	var cid := chart_id_from_song_path(song_path)
	var prefixes: Array[String] = []
	if norm != "":
		prefixes.append("%s|" % norm)
	if song_path != norm:
		prefixes.append("%s|" % song_path)
	var stems_keys: Array[String] = []
	if norm != "":
		stems_keys.append("stems|%s" % norm)
	if song_path != norm:
		stems_keys.append("stems|%s" % song_path)
	var to_remove: Array = []
	for key in _exist_cache.keys():
		var ks := str(key)
		var hit := false
		for pref in prefixes:
			if ks.begins_with(pref):
				hit = true
				break
		if not hit and ks in stems_keys:
			hit = true
		# Fallback by chart_id: covers / vs \ mismatch and any legacy cached keys containing the hash
		if not hit and cid != "" and ks.find(cid) != -1:
			hit = true
		if hit:
			to_remove.append(key)
	for key in to_remove:
		_exist_cache.erase(key)
		_exist_cache_mtime.erase(key)
	var to_remove_ready: Array = []
	for key in _ready_scope_cache.keys():
		var ks2 := str(key)
		var hit2 := false
		for pref in prefixes:
			if ks2.begins_with(pref):
				hit2 = true
				break
		if not hit2 and cid != "" and ks2.find(cid) != -1:
			hit2 = true
		if hit2:
			to_remove_ready.append(key)
	for key in to_remove_ready:
		_ready_scope_cache.erase(key)
	# Also clear present-variant stems entry explicitly (may have been stored under normalized or raw key)
	for sk in stems_keys:
		if _exist_cache.has(sk):
			_exist_cache.erase(sk)
			_exist_cache_mtime.erase(sk)


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
	var roots: Array[String] = []
	var custom := get_notes_root()
	roots.append(custom)
	if custom != DEFAULT_NOTES_ROOT:
		var def_abs := DirectoryUtils.to_absolute(DEFAULT_NOTES_ROOT)
		var cust_abs := DirectoryUtils.to_absolute(custom)
		if def_abs != cust_abs:
			roots.append(DEFAULT_NOTES_ROOT)
	# Also check the alternative test_notes location for the user's environment (project vs godotprojects)
	# This handles the case where user_notes_path is D:/Games/godotprojects/test_notes but file is at D:/Games/project/test_notes
	var alt_test_notes := "D:/Games/project/test_notes"
	var alt_abs := DirectoryUtils.to_absolute(alt_test_notes)
	var cust_abs2 := DirectoryUtils.to_absolute(custom)
	if alt_abs != cust_abs2 and DirAccess.dir_exists_absolute(alt_abs):
		roots.append(alt_test_notes)
	return roots


## Bundled songs ship next to the EXE, so their absolute path varies per install.
## Canonicalize any */bundled_songs/<filename> to res://bundled_songs/<filename>
## so chart_id matches notes_template (keyed by the res:// form). All other
## paths keep the exact previous semantics (no basename-only IDs).
static func _canonical_bundled_song_path(normalized_path: String) -> String:
	var marker := "/bundled_songs/"
	var idx := normalized_path.to_lower().find(marker)
	if idx == -1:
		return normalized_path
	var tail := normalized_path.substr(idx + marker.length())
	if tail == "" or tail.find("/") != -1:
		return normalized_path
	return "res://bundled_songs/" + tail


static func chart_id_from_song_path(song_path: String) -> String:
	var normalized := normalize_song_path(song_path)
	normalized = _canonical_bundled_song_path(normalized)
	var ctx := HashingContext.new()
	ctx.start(HashingContext.HASH_SHA256)
	ctx.update(normalized.to_utf8_buffer())
	return ctx.finish().hex_encode().substr(0, 16)


# Phase 1 — content identity (separate from path-based chart_id).
# chart_id = SHA256(normalized path)[:16] — path identity, changes on rename, keeps on content change.
# audio_content_hash = SHA256(original bytes) — content identity, stable on rename, changes on edit.
# Used for future persistent stems: user://stems/{content_hash}_{kind}_{model}.mp3
# Server WAV remains temporary; MP3 is suitable for persistent gameplay stem.
# This phase adds helpers only — no behavior change, no migration, no cleanup.
static func bytes_content_hash(data: PackedByteArray) -> String:
	if data.is_empty():
		return ""
	var ctx := HashingContext.new()
	ctx.start(HashingContext.HASH_SHA256)
	ctx.update(data)
	return ctx.finish().hex_encode()


static func audio_content_hash(song_path: String) -> String:
	var p := String(song_path).strip_edges()
	if p == "":
		return ""
	# Resolve user:// / res:// via DirectoryUtils; fallback to globalized path handling in FileAccess.
	var abs_path := DirectoryUtils.to_absolute(p)
	var file: FileAccess = null
	if abs_path != "" and FileAccess.file_exists(abs_path):
		file = FileAccess.open(abs_path, FileAccess.READ)
	elif FileAccess.file_exists(p):
		file = FileAccess.open(p, FileAccess.READ)
	else:
		# Try globalized user:// directly (covers editor vs exported).
		var g := ProjectSettings.globalize_path(p) if p.begins_with("user://") or p.begins_with("res://") else ""
		if g != "" and FileAccess.file_exists(g):
			file = FileAccess.open(g, FileAccess.READ)
		else:
			return ""
	if file == null:
		return ""
	var ctx := HashingContext.new()
	ctx.start(HashingContext.HASH_SHA256)
	# Chunked to avoid peak memory on large audio files.
	var chunk_size := 1024 * 1024
	while not file.eof_reached():
		var chunk := file.get_buffer(chunk_size)
		if chunk.is_empty():
			break
		ctx.update(chunk)
		if chunk.size() < chunk_size:
			break
	file.close()
	return ctx.finish().hex_encode()


static func audio_content_hash16(song_path: String) -> String:
	var full := audio_content_hash(song_path)
	if full == "":
		return ""
	return full.substr(0, 16)


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


static func _is_versioned_mode(mode: String) -> bool:
	var s := mode.strip_edges()
	var re := RegEx.new()
	re.compile("(?i)(?:_v|\\s+v)\\d+$")
	return re.search(s) != null

static func resolve_mode_stem_key(mode_or_stem: String) -> String:
	var key := mode_or_stem.strip_edges().to_lower()
	# Stage B: versioned stems (e.g. arcade_medium_v1 or "Fix chorus snare v1") keep literal
	if _is_versioned_mode(mode_or_stem):
		return key
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
	# Custom and canonical no longer include lanes in filename (lanes in header/gameplay only).
	var stem_key := resolve_mode_stem_key(mode)
	var base := "%s_%s" % [instrument.to_lower(), stem_key]
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
		var dir_name := _legacy_name_based_dir(song_path)
		for alias in _GoalDiff.stem_read_aliases(stem_key):
			var stem := _mode_stem_with_alias(instrument, alias, chart_tag)
			for suffix in [".rf", ".rfc.gz", ".rfc", ".rf.gz"]:
				var p_legacy := "%s/%s/%s_%s%s" % [root, dir_name, dir_name, stem, suffix]
				if not paths.has(p_legacy):
					paths.append(p_legacy)
	return paths


static func resolve_unified_mode_path(
	song_path: String,
	instrument: String,
	mode: String,
	chart_tag: String = ""
) -> String:
	var _perf_unified_resolve := PerfTrace.begin("perf.detail.song_select.populate.render.items.song_visuals.notes_ready.scope.unified.resolve")
	var stem_key := resolve_mode_stem_key(mode)
	var _perf_unified_present := PerfTrace.begin("perf.detail.song_select.populate.render.items.song_visuals.notes_ready.scope.unified.present")
	var stems := _present_variant_stems(song_path)
	for alias in _GoalDiff.stem_read_aliases(stem_key):
		var mode_stem := _mode_stem_with_alias(instrument, alias, chart_tag)
		if stems.has(mode_stem):
			PerfTrace.end("perf.detail.song_select.populate.render.items.song_visuals.notes_ready.scope.unified.present", _perf_unified_present)
			PerfTrace.end("perf.detail.song_select.populate.render.items.song_visuals.notes_ready.scope.unified.resolve", _perf_unified_resolve)
			return String(stems[mode_stem])
	PerfTrace.end("perf.detail.song_select.populate.render.items.song_visuals.notes_ready.scope.unified.present", _perf_unified_present)
	var _perf_unified_candidates := PerfTrace.begin("perf.detail.song_select.populate.render.items.song_visuals.notes_ready.scope.unified.candidates")
	for path in _candidate_read_paths_for_mode_stem(song_path, instrument, mode, chart_tag):
		var abs := DirectoryUtils.to_absolute(path)
		if abs != "" and FileAccess.file_exists(abs):
			PerfTrace.end("perf.detail.song_select.populate.render.items.song_visuals.notes_ready.scope.unified.candidates", _perf_unified_candidates)
			PerfTrace.end("perf.detail.song_select.populate.render.items.song_visuals.notes_ready.scope.unified.resolve", _perf_unified_resolve)
			return path
	PerfTrace.end("perf.detail.song_select.populate.render.items.song_visuals.notes_ready.scope.unified.candidates", _perf_unified_candidates)
	PerfTrace.end("perf.detail.song_select.populate.render.items.song_visuals.notes_ready.scope.unified.resolve", _perf_unified_resolve)
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
			var stem := _mode_stem_with_alias(instrument, alias, tag)
			for suffix in [".rf", ".rfc.gz", ".rfc", ".rf.gz"]:
				var p_nested := "%s/%s/%s%s" % [root, chart_id, stem, suffix]
				if not paths.has(p_nested):
					paths.append(p_nested)
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


static func _legacy_name_based_dir(song_path: String) -> String:
	var base_name := song_path.get_file().get_basename()
	return FileUtils.sanitize_name_for_fs(base_name)


static func _present_variant_stems(song_path: String) -> Dictionary:
	var _perf_present := PerfTrace.begin("perf.detail.song_select.populate.render.items.song_visuals.notes_ready.present_stems")
	_sync_cache_epoch()
	var norm_path := normalize_song_path(song_path)
	var cache_key := "stems|%s" % norm_path
	if _exist_cache.has(cache_key) and _exist_cache[cache_key] is Dictionary:
		PerfTrace.end("perf.detail.song_select.populate.render.items.song_visuals.notes_ready.present_stems", _perf_present)
		return _exist_cache[cache_key]
	var raw_key := "stems|%s" % song_path
	if raw_key != cache_key and _exist_cache.has(raw_key) and _exist_cache[raw_key] is Dictionary:
		var legacy_val: Dictionary = _exist_cache[raw_key]
		_exist_cache[cache_key] = legacy_val
		_exist_cache.erase(raw_key)
		_exist_cache_mtime.erase(raw_key)
		PerfTrace.end("perf.detail.song_select.populate.render.items.song_visuals.notes_ready.present_stems", _perf_present)
		return legacy_val
	var present: Dictionary = {}
	var chart_id := chart_id_from_song_path(song_path)
	if _bulk_present_enabled and _bulk_present_index.has(chart_id):
		var bulk_cached: Dictionary = (_bulk_present_index[chart_id] as Dictionary).duplicate()
		_exist_cache[cache_key] = bulk_cached
		PerfTrace.end("perf.detail.song_select.populate.render.items.song_visuals.notes_ready.present_stems", _perf_present)
		return bulk_cached
	var _perf_dir_scan := PerfTrace.begin("perf.detail.song_select.populate.render.items.song_visuals.notes_ready.dir_scan")
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
	PerfTrace.end("perf.detail.song_select.populate.render.items.song_visuals.notes_ready.dir_scan", _perf_dir_scan)
	_exist_cache[cache_key] = present
	PerfTrace.end("perf.detail.song_select.populate.render.items.song_visuals.notes_ready.present_stems", _perf_present)
	return present


static func _legacy_scan_name_based_stems(present: Dictionary, song_path: String, root: String) -> void:
	var dir_name := _legacy_name_based_dir(song_path)
	var name_based_dir := "%s/%s" % [normalize_notes_root(root), dir_name]
	var name_based_abs := DirectoryUtils.to_absolute(name_based_dir)
	if name_based_abs == "" or not DirAccess.dir_exists_absolute(name_based_abs):
		return
	var d := DirAccess.open(name_based_abs)
	if not d:
		return
	var prefix := dir_name + "_"
	d.list_dir_begin()
	var fname := d.get_next()
	while fname != "":
		if not d.current_is_dir() and fname.begins_with(prefix):
			if fname.ends_with(".json.gz") or fname.ends_with(".json"):
				fname = d.get_next()
				continue
			var rest := fname.substr(prefix.length())
			var stem := _filename_to_variant_stem(rest)
			if stem != "":
				_register_stem_path(present, stem, "%s/%s" % [name_based_dir, fname])
		fname = d.get_next()
	d.list_dir_end()


static func resolve_existing_path(song_path: String, instrument: String, mode: String, lanes: int, chart_tag: String = "") -> String:
	var _perf_resolve := PerfTrace.begin("perf.detail.song_select.populate.render.items.song_visuals.notes_ready.resolve_existing_path")
	if _forensic_in_loop:
		_forensic_last_filesystem = false
	_sync_cache_epoch()
	var norm_path := normalize_song_path(song_path)
	var tag_key := normalize_chart_tag(chart_tag)
	var cache_key := "%s|%s|%s|%d|%s" % [norm_path, instrument, mode, lanes, tag_key]
	if _scope_fast_cache_enabled and _scope_fast_cache.has(cache_key):
		PerfTrace.end("perf.detail.song_select.populate.render.items.song_visuals.notes_ready.resolve_existing_path", _perf_resolve)
		return String(_scope_fast_cache[cache_key])
	# Stage B: versioned/custom literal fast path (e.g. arcade_medium_v1, Fix_chorus_snare)
	var lower_mode := mode.strip_edges().to_lower()
	if _is_versioned_mode(mode) or (lower_mode != "" and lower_mode != "custom" and not _GoalDiff.is_chart_stem(lower_mode)):
		# Try literal file directly (custom or versioned)
		for root in active_notes_roots():
			var cid_lit := chart_id_from_song_path(song_path)
			var p_lit_rf := "%s/%s/%s_%s.rf" % [root, cid_lit, instrument.to_lower(), lower_mode]
			var abs_lit_rf := DirectoryUtils.to_absolute(p_lit_rf)
			if abs_lit_rf != "" and FileAccess.file_exists(abs_lit_rf):
				if _scope_fast_cache_enabled:
					_scope_fast_cache[cache_key] = p_lit_rf
				PerfTrace.end("perf.detail.song_select.populate.render.items.song_visuals.notes_ready.resolve_existing_path", _perf_resolve)
				return p_lit_rf
			var p_lit_rfc := "%s/%s/%s_%s.rfc" % [root, cid_lit, instrument.to_lower(), lower_mode]
			var abs_lit_rfc := DirectoryUtils.to_absolute(p_lit_rfc)
			if abs_lit_rfc != "" and FileAccess.file_exists(abs_lit_rfc):
				# Found .rfc but need .rf — check if .rf exists at same base (maybe versioned)
				var p_rf_from_rfc := p_lit_rfc.substr(0, p_lit_rfc.length() - 4) + ".rf"
				var abs_rf_from_rfc := DirectoryUtils.to_absolute(p_rf_from_rfc)
				if FileAccess.file_exists(abs_rf_from_rfc):
					if _scope_fast_cache_enabled:
						_scope_fast_cache[cache_key] = p_rf_from_rfc
					PerfTrace.end("perf.detail.song_select.populate.render.items.song_visuals.notes_ready.resolve_existing_path", _perf_resolve)
					return p_rf_from_rfc
		# Also check present dict for literal
		var present_lit := _present_variant_stems(song_path)
		var lit_key := "%s_%s" % [instrument.to_lower(), lower_mode]
		if present_lit.has(lit_key):
			var found_lit_path := String(present_lit[lit_key])
			if found_lit_path.ends_with(".rf"):
				if _scope_fast_cache_enabled:
					_scope_fast_cache[cache_key] = found_lit_path
				PerfTrace.end("perf.detail.song_select.populate.render.items.song_visuals.notes_ready.resolve_existing_path", _perf_resolve)
				return found_lit_path
	# Legacy raw key support — migrate or drop stale raw entry
	var raw_key := "%s|%s|%s|%d|%s" % [song_path, instrument, mode, lanes, tag_key]
	if raw_key != cache_key and _exist_cache.has(raw_key) and not _exist_cache.has(cache_key):
		var raw_cached := String(_exist_cache[raw_key])
		if raw_cached == "":
			# Negative legacy cache — drop it and let fresh lookup run under normalized key
			_exist_cache.erase(raw_key)
			_exist_cache_mtime.erase(raw_key)
		else:
			var abs_raw := DirectoryUtils.to_absolute(raw_cached)
			var m_raw: int = int(_exist_cache_mtime.get(raw_key, 0))
			var cur_raw := 0
			if abs_raw != "" and FileAccess.file_exists(abs_raw):
				cur_raw = int(FileAccess.get_modified_time(abs_raw))
				if m_raw == 0 or m_raw == cur_raw:
					# Migrate valid entry to normalized key
					_exist_cache[cache_key] = raw_cached
					_exist_cache_mtime[cache_key] = cur_raw if m_raw != 0 else cur_raw
					_exist_cache.erase(raw_key)
					_exist_cache_mtime.erase(raw_key)
				else:
					_exist_cache.erase(raw_key)
					_exist_cache_mtime.erase(raw_key)
			else:
				_exist_cache.erase(raw_key)
				_exist_cache_mtime.erase(raw_key)
	if _exist_cache.has(cache_key):
		var _perf_cache_hit := PerfTrace.begin("perf.detail.song_select.populate.render.items.song_visuals.notes_ready.exist_cache_hit")
		var cached := String(_exist_cache[cache_key])
		if cached != "":
			var abs_cached := DirectoryUtils.to_absolute(cached)
			var cached_mtime: int = int(_exist_cache_mtime.get(cache_key, 0))
			var cur_mtime := 0
			var _perf_file_exists := PerfTrace.begin("perf.detail.song_select.populate.render.items.song_visuals.notes_ready.file_exists")
			var _fe := abs_cached != "" and FileAccess.file_exists(abs_cached)
			PerfTrace.end("perf.detail.song_select.populate.render.items.song_visuals.notes_ready.file_exists", _perf_file_exists)
			if _fe:
				var _perf_get_mtime := PerfTrace.begin("perf.detail.song_select.populate.render.items.song_visuals.notes_ready.get_modified_time")
				cur_mtime = int(FileAccess.get_modified_time(abs_cached))
				PerfTrace.end("perf.detail.song_select.populate.render.items.song_visuals.notes_ready.get_modified_time", _perf_get_mtime)
				if cached_mtime != 0 and cur_mtime == cached_mtime:
					PerfTrace.end("perf.detail.song_select.populate.render.items.song_visuals.notes_ready.exist_cache_hit", _perf_cache_hit)
					PerfTrace.end("perf.detail.song_select.populate.render.items.song_visuals.notes_ready.resolve_existing_path", _perf_resolve)
					return cached
				if cached_mtime == 0:
					# First mtime check, store it
					_exist_cache_mtime[cache_key] = cur_mtime
					if _scope_fast_cache_enabled:
						_scope_fast_cache[cache_key] = cached
					PerfTrace.end("perf.detail.song_select.populate.render.items.song_visuals.notes_ready.exist_cache_hit", _perf_cache_hit)
					PerfTrace.end("perf.detail.song_select.populate.render.items.song_visuals.notes_ready.resolve_existing_path", _perf_resolve)
					return cached
			PerfTrace.end("perf.detail.song_select.populate.render.items.song_visuals.notes_ready.exist_cache_hit", _perf_cache_hit)
			# File gone or mtime changed — invalidate this entry only
			_exist_cache.erase(cache_key)
			_exist_cache_mtime.erase(cache_key)
		else:
			PerfTrace.end("perf.detail.song_select.populate.render.items.song_visuals.notes_ready.exist_cache_hit", _perf_cache_hit)
			# Cached as not found — check if file now exists via quick probe without full scan
			# Let it fall through to fresh lookup (will be re-cached)
			_exist_cache.erase(cache_key)
			_exist_cache_mtime.erase(cache_key)
	# Canonical: drums_original.rf (lanes in RFC header). Legacy: drums_original_lanes4.rf.
	var _perf_fs := PerfTrace.begin("perf.detail.song_select.populate.render.items.song_visuals.notes_ready.scope.resolve.filesystem")
	if _forensic_in_loop:
		_forensic_last_filesystem = true
	var unified := resolve_unified_mode_path(song_path, instrument, mode, chart_tag)
	if unified != "":
		_exist_cache[cache_key] = unified
		_exist_cache_mtime[cache_key] = int(FileAccess.get_modified_time(DirectoryUtils.to_absolute(unified)))
		if _scope_fast_cache_enabled:
			_scope_fast_cache[cache_key] = unified
		PerfTrace.end("perf.detail.song_select.populate.render.items.song_visuals.notes_ready.scope.resolve.filesystem", _perf_fs)
		PerfTrace.end("perf.detail.song_select.populate.render.items.song_visuals.notes_ready.resolve_existing_path", _perf_resolve)
		return unified
	var stems := _present_variant_stems(song_path)
	var stem_key := resolve_mode_stem_key(mode)
	var tag := normalize_chart_tag(chart_tag)
	for alias in _GoalDiff.stem_read_aliases(stem_key):
		var variant_stem := _mode_stem_with_alias(instrument, alias, tag)
		if stems.has(variant_stem):
			var found_path := String(stems[variant_stem])
			_exist_cache[cache_key] = found_path
			_exist_cache_mtime[cache_key] = int(FileAccess.get_modified_time(DirectoryUtils.to_absolute(found_path)))
			if _scope_fast_cache_enabled:
				_scope_fast_cache[cache_key] = found_path
			PerfTrace.end("perf.detail.song_select.populate.render.items.song_visuals.notes_ready.scope.resolve.filesystem", _perf_fs)
			PerfTrace.end("perf.detail.song_select.populate.render.items.song_visuals.notes_ready.resolve_existing_path", _perf_resolve)
			return found_path
	if _bulk_present_enabled:
		var chart_id_bulk := chart_id_from_song_path(song_path)
		var bulk_has_chart := _bulk_present_index.has(chart_id_bulk)
		var bulk_has_stem := false
		if bulk_has_chart:
			var bulk_dict_tmp: Dictionary = _bulk_present_index[chart_id_bulk] as Dictionary
			for alias_bulk in _GoalDiff.stem_read_aliases(stem_key):
				var variant_bulk := _mode_stem_with_alias(instrument, alias_bulk, tag)
				if bulk_dict_tmp.has(variant_bulk):
					bulk_has_stem = true
					break
		if bulk_has_chart and not bulk_has_stem:
			_exist_cache[cache_key] = ""
			_exist_cache_mtime[cache_key] = 0
			if _scope_fast_cache_enabled:
				_scope_fast_cache[cache_key] = ""
			PerfTrace.end("perf.detail.song_select.populate.render.items.song_visuals.notes_ready.scope.resolve.filesystem", _perf_fs)
			PerfTrace.end("perf.detail.song_select.populate.render.items.song_visuals.notes_ready.resolve_existing_path", _perf_resolve)
			return ""
		elif not bulk_has_chart:
			_exist_cache[cache_key] = ""
			_exist_cache_mtime[cache_key] = 0
			if _scope_fast_cache_enabled:
				_scope_fast_cache[cache_key] = ""
			PerfTrace.end("perf.detail.song_select.populate.render.items.song_visuals.notes_ready.scope.resolve.filesystem", _perf_fs)
			PerfTrace.end("perf.detail.song_select.populate.render.items.song_visuals.notes_ready.resolve_existing_path", _perf_resolve)
			return ""
	for path in _candidate_read_paths(song_path, instrument, mode, lanes, chart_tag):
		var abs := DirectoryUtils.to_absolute(path)
		if abs != "" and FileAccess.file_exists(abs):
			_exist_cache[cache_key] = path
			_exist_cache_mtime[cache_key] = int(FileAccess.get_modified_time(abs))
			if _scope_fast_cache_enabled:
				_scope_fast_cache[cache_key] = path
			PerfTrace.end("perf.detail.song_select.populate.render.items.song_visuals.notes_ready.scope.resolve.filesystem", _perf_fs)
			PerfTrace.end("perf.detail.song_select.populate.render.items.song_visuals.notes_ready.resolve_existing_path", _perf_resolve)
			return path
	PerfTrace.end("perf.detail.song_select.populate.render.items.song_visuals.notes_ready.scope.resolve.filesystem", _perf_fs)
	_exist_cache[cache_key] = ""
	_exist_cache_mtime[cache_key] = 0
	if _scope_fast_cache_enabled:
		_scope_fast_cache[cache_key] = ""
	PerfTrace.end("perf.detail.song_select.populate.render.items.song_visuals.notes_ready.resolve_existing_path", _perf_resolve)
	return ""

static func notes_path_by_song(song_path: String, instrument: String, mode: String, lanes: int, chart_tag: String = "") -> String:
	var existing := resolve_existing_path(song_path, instrument, mode, lanes, chart_tag)
	if existing != "":
		return existing
	if normalize_chart_tag(chart_tag) == "":
		return preferred_mode_chart_path(song_path, instrument, mode, chart_tag)
	return preferred_chart_path(song_path, instrument, mode, lanes, chart_tag)


static func notes_exist(song_path: String, instrument: String, mode: String, lanes: int, chart_tag: String = "") -> bool:
	var _perf_ne := PerfTrace.begin("perf.detail.song_select.populate.render.items.song_visuals.notes_ready.notes_exist")
	var _res := resolve_existing_path(song_path, instrument, mode, lanes, chart_tag) != ""
	PerfTrace.end("perf.detail.song_select.populate.render.items.song_visuals.notes_ready.notes_exist", _perf_ne)
	return _res


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
	return "%s/%s.rfd" % [rel.get_base_dir(), stem]


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


static func rhythm_dna_path_for_mode_with_lanes(
	song_path: String,
	instrument: String,
	mode: String,
	lanes: int,
	chart_tag: String = ""
) -> String:
	var chart_id := chart_id_from_song_path(song_path)
	if chart_id == "":
		return ""
	return "%s/%s.rfd" % [chart_dir(chart_id), chart_variant_stem(instrument, mode, lanes, chart_tag)]


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


# --- Canonical song-level sections.rfd (sections.rfd) ---
static func canonical_sections_path(song_path: String) -> String:
	var chart_id := chart_id_from_song_path(song_path)
	if chart_id == "":
		return ""
	return "%s/sections.rfd" % chart_dir(chart_id)

static func canonical_sections_path_for_chart_id(chart_id: String) -> String:
	if String(chart_id).strip_edges() == "":
		return ""
	return "%s/sections.rfd" % chart_dir(String(chart_id).strip_edges())

static func load_canonical_sections(song_path: String) -> Array:
	var rel := canonical_sections_path(song_path)
	if rel == "" or not _sidecar_file_exists(rel):
		return []
	var dict := _read_sidecar_dictionary(rel, false)
	if dict is Dictionary and dict.has("sections") and dict["sections"] is Array:
		var arr: Array = dict["sections"] as Array
		return arr
	if dict is Dictionary and dict.has("structure_sections") and dict["structure_sections"] is Array:
		var arr2: Array = dict["structure_sections"] as Array
		return arr2 as Array
	# Legacy: file may be array directly
	if dict is Dictionary and dict.has("sections.rfd"):
		return []
	return []

static func save_canonical_sections(song_path: String, sections: Array) -> bool:
	var rel := canonical_sections_path(song_path)
	if rel == "":
		return false
	var cid := chart_id_from_song_path(song_path)
	if sections.is_empty():
		return false
	var payload := {"sections": sections, "chart_id": cid, "version": 1}
	DirectoryUtils.ensure_dir_for_file(rel)
	var file := DirectoryUtils.open_file(rel, FileAccess.WRITE)
	if file == null:
		push_warning("NotesUtils: failed to save canonical sections: %s" % DirectoryUtils.to_absolute(rel))
		return false
	file.store_string(RfdPassportCodec.serialize(payload))
	file.close()
	invalidate_notes_cache()
	return true

static func ensure_canonical_sections(song_path: String) -> bool:
	var rel := canonical_sections_path(song_path)
	if rel == "" or _sidecar_file_exists(rel):
		return _sidecar_file_exists(rel)
	# Try to migrate from any existing chart .rfd for this song
	var chart_id := chart_id_from_song_path(song_path)
	if chart_id == "":
		return false
	var dir := chart_dir(chart_id)
	var abs_dir := DirectoryUtils.to_absolute(dir)
	if abs_dir == "":
		return false
	# Scan directory for any .rfd that contains structure_sections/timeline
	var da := DirAccess.open(abs_dir)
	if da == null:
		return false
	da.list_dir_begin()
	var fname := da.get_next()
	while fname != "":
		if fname.ends_with(".rfd") and fname != "sections.rfd":
			var rel_rfd := "%s/%s" % [dir, fname]
			var dict := _read_sidecar_dictionary(rel_rfd, false)
			var cand: Array = []
			if dict is Dictionary:
				if dict.has("structure_sections") and dict["structure_sections"] is Array and not (dict["structure_sections"] as Array).is_empty():
					cand = dict["structure_sections"] as Array
				elif dict.has("structure_timeline") and dict["structure_timeline"] is Array and not (dict["structure_timeline"] as Array).is_empty():
					cand = dict["structure_timeline"] as Array
			if not cand.is_empty():
				# Normalize via RhythmDnaView if available
				return save_canonical_sections(song_path, cand)
		fname = da.get_next()
	da.list_dir_end()
	return false


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
	var mode_rfd_variant := rhythm_dna_path_for_mode_with_lanes(song_path, instrument, mode, lanes, chart_tag)
	var payload := _read_sidecar_dictionary(mode_rfd_variant, false)
	if not payload.is_empty():
		if ProjectSettings.get_setting("debug/verbose_rhythm_dna", false):
			push_warning("RNA: loaded from mode_rfd_variant %s" % mode_rfd_variant)
		return payload
	var mode_rfd := rhythm_dna_path_for_mode(song_path, instrument, mode, chart_tag)
	payload = _read_sidecar_dictionary(mode_rfd, false)
	if not payload.is_empty():
		if ProjectSettings.get_setting("debug/verbose_rhythm_dna", false):
			push_warning("RNA: loaded from mode_rfd %s" % mode_rfd)
		return payload
	var chart_path := resolve_existing_path(song_path, instrument, mode, lanes, chart_tag)
	if chart_path == "":
		return {}
	var rfd_path := rhythm_dna_path_for_chart(chart_path)
	if ProjectSettings.get_setting("debug/verbose_rhythm_dna", false):
		push_warning("RNA: rfd_path from chart %s -> %s" % [chart_path, rfd_path])
	payload = _read_sidecar_dictionary(rfd_path, false)
	if not payload.is_empty():
		if ProjectSettings.get_setting("debug/verbose_rhythm_dna", false):
			push_warning("RNA: loaded from rfd_path %s" % rfd_path)
		return payload
	# Fallback to old mode_stem without lanes for backward compat
	var old_rfd_path: String = ""
	var stem_tmp := _chart_stem_from_filename(chart_path.get_file())
	if stem_tmp != "":
		var old_mode_stem := chart_mode_stem_from_chart_stem(stem_tmp)
		if old_mode_stem != stem_tmp:
			old_rfd_path = "%s/%s.rfd" % [chart_path.get_base_dir(), old_mode_stem]
			if ProjectSettings.get_setting("debug/verbose_rhythm_dna", false):
				push_warning("RNA: rfd_path old fallback %s -> %s" % [chart_path, old_rfd_path])
			payload = _read_sidecar_dictionary(old_rfd_path, false)
			if not payload.is_empty():
				if ProjectSettings.get_setting("debug/verbose_rhythm_dna", false):
					push_warning("RNA: loaded from old rfd_path %s" % old_rfd_path)
				return payload
	payload = _read_sidecar_dictionary(_legacy_lane_rhythm_dna_path(chart_path), false)
	if not payload.is_empty():
		if ProjectSettings.get_setting("debug/verbose_rhythm_dna", false):
			push_warning("RNA: loaded from legacy_lane_rhythm_dna_path %s" % _legacy_lane_rhythm_dna_path(chart_path))
		return payload
	var legacy := legacy_rhythm_dna_path_for_chart(chart_path)
	if ProjectSettings.get_setting("debug/verbose_rhythm_dna", false):
		push_warning("RNA: loaded from legacy_rhythm_dna_path %s" % legacy)
	return _read_sidecar_dictionary(legacy, true)


static func save_rhythm_dna_at_chart(chart_rel_path: String, payload: Variant) -> bool:
	if not (payload is Dictionary) or (payload as Dictionary).is_empty():
		if ProjectSettings.get_setting("debug/verbose_rhythm_dna", false):
			push_warning("RNA WRITE: abort empty payload chart_rel_path=%s" % chart_rel_path)
		return false
	var rel := rhythm_dna_path_for_chart(chart_rel_path)
	if rel == "":
		if ProjectSettings.get_setting("debug/verbose_rhythm_dna", false):
			push_warning("RNA WRITE: abort empty rel chart_rel_path=%s" % chart_rel_path)
		return false
	var abs_path := DirectoryUtils.to_absolute(rel)
	var exists_before := FileAccess.file_exists(abs_path)
	var mtime_before := FileAccess.get_modified_time(abs_path) if exists_before else 0
	var size_before := 0
	if exists_before:
		var _fb := FileAccess.open(abs_path, FileAccess.READ)
		if _fb != null:
			size_before = _fb.get_length()
			_fb.close()
	if ProjectSettings.get_setting("debug/verbose_rhythm_dna", false):
		push_warning("RNA WRITE: chart_rel_path=%s rel=%s abs=%s exists_before=%s mtime_before=%s size_before=%s" % [chart_rel_path, rel, abs_path, exists_before, mtime_before, size_before])
	DirectoryUtils.ensure_dir_for_file(rel)
	var file := DirectoryUtils.open_file(rel, FileAccess.WRITE)
	if file == null:
		push_warning("NotesUtils: failed to save Rhythm DNA: %s err=%s" % [abs_path, FileAccess.get_open_error()])
		return false
	var ser := RfdPassportCodec.serialize(payload as Dictionary)
	file.store_string(ser)
	file.close()
	var exists_after := FileAccess.file_exists(abs_path)
	var mtime_after := FileAccess.get_modified_time(abs_path) if exists_after else 0
	var size_after := 0
	if exists_after:
		var _fa := FileAccess.open(abs_path, FileAccess.READ)
		if _fa != null:
			size_after = _fa.get_length()
			_fa.close()
	if ProjectSettings.get_setting("debug/verbose_rhythm_dna", false):
		push_warning("RNA WRITE AFTER: abs=%s exists=%s mtime_after=%s size_after=%s ser_len=%s" % [abs_path, exists_after, mtime_after, size_after, ser.length()])
	# Invalidate only affected cache entries (chart_id specific, no full scan)
	if rel != "":
		var dir := rel.get_base_dir()
		var cid := dir.get_file()
		if cid != "":
			var to_remove: Array = []
			for key in _exist_cache.keys():
				if str(key).find(cid) != -1 or str(_exist_cache[key]).find(cid) != -1:
					to_remove.append(key)
			for key in to_remove:
				_exist_cache.erase(key)
				_exist_cache_mtime.erase(key)
			# Also clear present_variant_stems cache for this chart_id if present
			var stems_key := "stems|%s" % cid
			# We don't have song_path here, so clear any stems cache that contains this cid's dir
			# Instead, clear all stems cache that might be affected — targeted by song_path is better handled in save_rhythm_dna
			pass
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
	var ok := save_rhythm_dna_at_chart(chart_path, payload)
	if ok and song_path != "":
		_invalidate_cache_for_song(song_path)
	return ok


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
	_notify_library_index_changed("[save_mode_chart %s]" % song_path)
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
	_notify_library_index_changed("[save_notes %s]" % song_path)
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
	_notify_library_index_changed("[delete_notes %s]" % song_path)


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
	var _perf_sync := PerfTrace.begin("perf.detail.song_select.populate.render.items.song_visuals.notes_ready.sync_cache_epoch")
	_sync_cache_epoch()
	PerfTrace.end("perf.detail.song_select.populate.render.items.song_visuals.notes_ready.sync_cache_epoch", _perf_sync)
	var _perf_tag := PerfTrace.begin("perf.detail.song_select.populate.render.items.song_visuals.notes_ready.play_tag")
	var play_tag := resolve_play_chart_tag(song_path, instrument, mode, lanes)
	PerfTrace.end("perf.detail.song_select.populate.render.items.song_visuals.notes_ready.play_tag", _perf_tag)
	var _perf_cache_key := PerfTrace.begin("perf.detail.song_select.populate.render.items.song_visuals.notes_ready.cache_key")
	var cache_key := "%s|%s|%s|%d|%s" % [song_path, instrument, mode, lanes, play_tag]
	PerfTrace.end("perf.detail.song_select.populate.render.items.song_visuals.notes_ready.cache_key", _perf_cache_key)
	var _perf_cache_check := PerfTrace.begin("perf.detail.song_select.populate.render.items.song_visuals.notes_ready.ready_cache_check")
	var _has_cache := _ready_scope_cache.has(cache_key)
	PerfTrace.end("perf.detail.song_select.populate.render.items.song_visuals.notes_ready.ready_cache_check", _perf_cache_check)
	if _has_cache:
		return bool(_ready_scope_cache[cache_key])
	var _perf_impl := PerfTrace.begin("perf.detail.song_select.populate.render.items.song_visuals.notes_ready.impl")
	var ready := _notes_ready_for_scope_impl(song_path, instrument, mode, lanes, play_tag)
	PerfTrace.end("perf.detail.song_select.populate.render.items.song_visuals.notes_ready.impl", _perf_impl)
	_ready_scope_cache[cache_key] = ready
	return ready


static func _notes_ready_for_scope_impl(
	song_path: String,
	instrument: String,
	mode: String,
	lanes: int,
	chart_tag: String = "",
) -> bool:
	var _perf_preset := PerfTrace.begin("perf.detail.song_select.populate.render.items.song_visuals.notes_ready.scope.preset")
	var _preset_hit := false
	if chart_tag != "" and notes_exist(song_path, instrument, mode, lanes, chart_tag):
		_preset_hit = true
	PerfTrace.end("perf.detail.song_select.populate.render.items.song_visuals.notes_ready.scope.preset", _perf_preset)
	if _preset_hit:
		PerfTrace.record("perf.detail.song_select.populate.render.items.song_visuals.notes_ready.scope.branch.preset_hit", 1)
		return true
	var _perf_unified := PerfTrace.begin("perf.detail.song_select.populate.render.items.song_visuals.notes_ready.scope.unified")
	var _unified_hit := false
	if chart_tag == "" and unified_mode_chart_exists(song_path, instrument, mode):
		_unified_hit = true
	PerfTrace.end("perf.detail.song_select.populate.render.items.song_visuals.notes_ready.scope.unified", _perf_unified)
	if _unified_hit:
		PerfTrace.record("perf.detail.song_select.populate.render.items.song_visuals.notes_ready.scope.branch.unified_hit", 1)
		return true
	var _perf_axes := PerfTrace.begin("perf.detail.song_select.populate.render.items.song_visuals.notes_ready.scope.axes")
	var axes := _GoalDiff.resolve_ready_axes({}, "", "", instrument)
	var stems := _GoalDiff.stems_for_ready_axes(axes.get("goals", []), axes.get("diffs", []))
	var instruments: Array = axes.get("instruments", [instrument])
	PerfTrace.end("perf.detail.song_select.populate.render.items.song_visuals.notes_ready.scope.axes", _perf_axes)
	var _perf_loop := PerfTrace.begin("perf.detail.song_select.populate.render.items.song_visuals.notes_ready.scope.loop")
	var _loop_present_usec := 0
	var _loop_calls := 0
	var _loop_hits := 0
	var _loop_fs := 0
	var _loop_local_keys: Dictionary = {}
	var present := _present_variant_stems(song_path)
	for inst_raw in instruments:
		var inst := str(inst_raw)
		for stem_id in stems:
			var norm_path := normalize_song_path(song_path)
			var cache_key := "%s|%s|%s|%d|%s" % [norm_path, inst, stem_id, lanes, ""]
			_forensic_loop_total_calls += 1
			_loop_calls += 1
			if not _forensic_loop_keys.has(cache_key):
				_forensic_loop_keys[cache_key] = true
			if not _loop_local_keys.has(cache_key):
				_loop_local_keys[cache_key] = true
			var _t_check := Time.get_ticks_usec()
			var found := false
			for alias in _GoalDiff.stem_read_aliases(stem_id):
				var base := "%s_%s" % [inst.to_lower(), alias]
				if present.has(base):
					found = true
					break
				var variant := "%s_lanes%d" % [base, lanes]
				if present.has(variant):
					found = true
					break
			var _elapsed := Time.get_ticks_usec() - _t_check
			_loop_present_usec += _elapsed
			if found:
				_forensic_loop_cache_hits += 1
				_loop_hits += 1
			else:
				_forensic_loop_filesystem += 1
				_loop_fs += 1
			if not found:
				PerfTrace.end("perf.detail.song_select.populate.render.items.song_visuals.notes_ready.scope.loop", _perf_loop)
				PerfTrace.record("perf.detail.song_select.populate.render.items.song_visuals.notes_ready.scope.loop.notes_exist", _loop_present_usec)
				PerfTrace.record("perf.detail.song_select.populate.render.items.song_visuals.notes_ready.scope.loop.notes_exist_calls", _loop_calls)
				PerfTrace.record("perf.detail.song_select.populate.render.items.song_visuals.notes_ready.scope.loop.exist_cache_hits", _loop_hits)
				PerfTrace.record("perf.detail.song_select.populate.render.items.song_visuals.notes_ready.scope.loop.filesystem", _loop_fs)
				PerfTrace.record("perf.detail.song_select.populate.render.items.song_visuals.notes_ready.scope.loop.unique_keys", _loop_local_keys.size())
				PerfTrace.record("perf.detail.song_select.populate.render.items.song_visuals.notes_ready.scope.loop.repeated_keys", _loop_calls - _loop_local_keys.size())
				PerfTrace.record("perf.detail.song_select.populate.render.items.song_visuals.notes_ready.scope.branch.loop_miss", 1)
				return false
	PerfTrace.end("perf.detail.song_select.populate.render.items.song_visuals.notes_ready.scope.loop", _perf_loop)
	PerfTrace.record("perf.detail.song_select.populate.render.items.song_visuals.notes_ready.scope.loop.notes_exist", _loop_present_usec)
	PerfTrace.record("perf.detail.song_select.populate.render.items.song_visuals.notes_ready.scope.loop.notes_exist_calls", _loop_calls)
	PerfTrace.record("perf.detail.song_select.populate.render.items.song_visuals.notes_ready.scope.loop.exist_cache_hits", _loop_hits)
	PerfTrace.record("perf.detail.song_select.populate.render.items.song_visuals.notes_ready.scope.loop.filesystem", _loop_fs)
	PerfTrace.record("perf.detail.song_select.populate.render.items.song_visuals.notes_ready.scope.loop.unique_keys", _loop_local_keys.size())
	PerfTrace.record("perf.detail.song_select.populate.render.items.song_visuals.notes_ready.scope.loop.repeated_keys", _loop_calls - _loop_local_keys.size())
	PerfTrace.record("perf.detail.song_select.populate.render.items.song_visuals.notes_ready.scope.branch.loop_hit", 1)
	return true