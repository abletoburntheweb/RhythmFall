# logic/domain/library/song_library_index.gd
# Library-side index for fast song eligibility queries.
# Built once / lazily, queried without filesystem scans.
# Invalidated on SongLibrary changes (songs_list_changed, metadata_updated, chart saves/deletes).
class_name SongLibraryIndex
extends RefCounted

const _ChartDifficultyAnalyzer = preload("res://logic/domain/charts/chart_difficulty_analyzer.gd")
const _GoalDiff = preload("res://logic/domain/generation/generation_goal_difficulty.gd")
const _ProfileGenrePortrait = preload("res://logic/domain/profile/profile_genre_portrait.gd")
const _EndlessSessionConfig = preload("res://logic/domain/session/endless_session_config.gd")
const _NotesUtils = preload("res://logic/domain/rhythm/notes_utils.gd")
const _PlaylistCatalog = preload("res://logic/domain/library/playlist_catalog.gd")
const _DirectoryUtils = preload("res://logic/platform/directory_utils.gd")
const _GenerationIntents = preload("res://logic/domain/generation/generation_intents.gd")

var entries: Array[Dictionary] = []
var song_count: int = 0
var chart_entry_count: int = 0
var build_msec: float = 0.0
var built_at_msec: int = 0
var built_at_epoch_usec: int = 0

static func _local_filename_to_variant_stem(filename: String) -> String:
	for ext in [".rfc.gz", ".rf.gz", ".rfc", ".rf", ".json.gz", ".json"]:
		if filename.ends_with(ext):
			return filename.substr(0, filename.length() - ext.length())
	return ""


static func _bulk_has_stem(bulk_set: Dictionary, instrument: String, stem: String) -> bool:
	var inst := instrument.to_lower().strip_edges()
	var key := stem.strip_edges().to_lower()
	# Use same alias logic as NotesUtils
	var aliases: Array[String] = _GoalDiff.stem_read_aliases(key)
	for alias in aliases:
		var full := "%s_%s" % [inst, alias]
		if bulk_set.has(full):
			return true
		# Also check lanes variants: bulk may contain lanes suffix (e.g., drums_arcade_hard_lanes4)
		# Treat any lanes variant as matching the base stem
		for lanes in [3, 4, 5]:
			var with_lanes := "%s_lanes%d" % [full, lanes]
			if bulk_set.has(with_lanes):
				return true
	return false


static func _legacy_stem_from_file(fname: String, base: String) -> String:
	var full := _local_filename_to_variant_stem(fname)
	if full == "":
		return ""
	# Skip legacy json charts (old format not counted as .rf)
	if fname.ends_with(".json") or fname.ends_with(".json.gz"):
		return ""
	var prefix := base + "_"
	if full.begins_with(prefix):
		return full.substr(prefix.length())
	return full


func build() -> void:
	var t0 := Time.get_ticks_usec()
	entries.clear()
	chart_entry_count = 0
	song_count = 0
	if SongLibrary == null:
		printerr("[LibraryIndex] build skipped: SongLibrary null")
		return
	var songs: Array[Dictionary] = []
	if SongLibrary.has_method("get_songs_list"):
		songs = SongLibrary.get_songs_list()
	else:
		# Fallback: direct variable
		if "songs" in SongLibrary:
			songs = SongLibrary.songs
	if songs.is_empty():
		song_count = 0
		built_at_msec = Time.get_ticks_msec()
		built_at_epoch_usec = Time.get_ticks_usec()
		build_msec = (Time.get_ticks_usec() - t0) / 1000.0
		print("[LibraryIndex] built empty in %.2fms songs=0 chart_entries=0" % build_msec)
		return
	# Bulk scan notes directories once to avoid per-song DirAccess storms (21s -> <100ms)
	var t_bulk0 := Time.get_ticks_usec()
	var bulk_by_cid: Dictionary = {}
	var legacy_by_base: Dictionary = {}
	var roots: Array[String] = _NotesUtils.active_notes_roots()
	for root in roots:
		var abs_root := _DirectoryUtils.to_absolute(root)
		if abs_root == "":
			continue
		var d := DirAccess.open(abs_root)
		if d:
			d.list_dir_begin()
			var fname := d.get_next()
			while fname != "":
				if not d.current_is_dir():
					var sep := fname.find("_")
					# flat: chart_id (16 hex) + "_" + stem.ext
					if sep == 16:
						var cid := fname.substr(0, 16)
						var rest := fname.substr(17)
						var stem := _local_filename_to_variant_stem(rest)
						if stem != "":
							if not bulk_by_cid.has(cid):
								bulk_by_cid[cid] = {}
							(bulk_by_cid[cid] as Dictionary)[stem] = true
				fname = d.get_next()
			d.list_dir_end()
		var d2 := DirAccess.open(abs_root)
		if d2:
			d2.list_dir_begin()
			var sub := d2.get_next()
			while sub != "":
				if d2.current_is_dir():
					if sub.length() == 16:
						var nested := "%s/%s" % [root, sub]
						var abs_nested := _DirectoryUtils.to_absolute(nested)
						var nd := DirAccess.open(abs_nested)
						if nd:
							nd.list_dir_begin()
							var nf := nd.get_next()
							while nf != "":
								if not nd.current_is_dir():
									var stem2 := _local_filename_to_variant_stem(nf)
									if stem2 != "":
										if not bulk_by_cid.has(sub):
											bulk_by_cid[sub] = {}
										(bulk_by_cid[sub] as Dictionary)[stem2] = true
								nf = nd.get_next()
							nd.list_dir_end()
					else:
						# Legacy name-based dir: root/base_name -> files base_variant.rf
						var legacy_dir := "%s/%s" % [root, sub]
						var abs_legacy := _DirectoryUtils.to_absolute(legacy_dir)
						var ld := DirAccess.open(abs_legacy)
						if ld:
							ld.list_dir_begin()
							var lf := ld.get_next()
							while lf != "":
								if not ld.current_is_dir():
									# Skip json legacy (not counted)
									if lf.ends_with(".json") or lf.ends_with(".json.gz"):
										lf = ld.get_next()
										continue
									var l_stem := _legacy_stem_from_file(lf, sub)
									if l_stem != "":
										if not legacy_by_base.has(sub):
											legacy_by_base[sub] = {}
										(legacy_by_base[sub] as Dictionary)[l_stem] = true
								lf = ld.get_next()
							ld.list_dir_end()
				sub = d2.get_next()
			d2.list_dir_end()
	var t_bulk_ms := (Time.get_ticks_usec() - t_bulk0) / 1000.0
	print("[LibraryIndex] bulk scan %.2fms roots=%d cids=%d legacy_bases=%d" % [t_bulk_ms, roots.size(), bulk_by_cid.size(), legacy_by_base.size()])
	for song in songs:
		if song is not Dictionary:
			continue
		var path := str(song.get("path", "")).strip_edges()
		if path == "":
			continue
		# Prefer persisted metadata (includes chart_difficulty, primary_genre, etc)
		var meta: Dictionary = {}
		if SongLibrary.has_method("get_metadata_for_song"):
			meta = SongLibrary.get_metadata_for_song(path)
		if meta.is_empty():
			meta = song
		var duration_sec := _ChartDifficultyAnalyzer.parse_duration_seconds(meta.get("duration", "00:00"))
		# Genre groups
		var groups: Array[String] = []
		var primary := str(meta.get("primary_genre", "")).strip_edges()
		if primary != "":
			var g := _ProfileGenrePortrait.map_genre_to_group(primary)
			if g == "":
				g = "_other"
			if not groups.has(g):
				groups.append(g)
		var genres_raw: Variant = meta.get("genres", [])
		# Parity with SessionScopeResolver._matches_genre_scope: only Array is considered.
		# String (", ".join) and PackedStringArray are ignored — Index must not count a song
		# for a group if old resolver wouldn't (see Batch 1 task).
		if genres_raw is Array:
			for item in genres_raw as Array:
				var token2 := str(item).strip_edges()
				if token2 == "":
					continue
				var gg2 := _ProfileGenrePortrait.map_genre_to_group(token2)
				if gg2 == "":
					gg2 = "_other"
				if not groups.has(gg2):
					groups.append(gg2)
		# String/PackedStringArray intentionally ignored for parity (old resolver only checks Array)
		if groups.is_empty():
			groups.append("_other")
		# Charts per instrument/stem — bulk scan avoids per-song DirAccess storms
		var cid := _NotesUtils.chart_id_from_song_path(path)
		var bulk_set: Dictionary = bulk_by_cid.get(cid, {}) as Dictionary if bulk_by_cid.has(cid) else {}
		var base_name := _NotesUtils.base_name_from_song_path(path)
		var legacy_set: Dictionary = legacy_by_base.get(base_name, {}) as Dictionary if legacy_by_base.has(base_name) else {}
		var chart_map: Dictionary = {} # instrument -> { stem -> rating }
		var instruments := ["drums", "bass"]
		for inst in instruments:
			var per_inst: Dictionary = {}
			# Fast path: bulk sets (single enumeration). Fallback to per-song scan only if both bulk and legacy empty.
			var fallback_map: Dictionary = {}
			var need_fallback := bulk_set.is_empty() and legacy_set.is_empty()
			if need_fallback:
				fallback_map = _NotesUtils.chart_stems_exist(path, inst)
			for stem in _GoalDiff.all_stems():
				var has := false
				if not bulk_set.is_empty():
					has = _bulk_has_stem(bulk_set, inst, stem)
				if not has and not legacy_set.is_empty():
					has = _bulk_has_stem(legacy_set, inst, stem)
				if not has and need_fallback:
					has = bool(fallback_map.get(stem, false))
				if not has:
					continue
				var stats: Dictionary = {}
				if SongLibrary.has_method("get_chart_difficulty_variant"):
					stats = SongLibrary.get_chart_difficulty_variant(path, inst, stem)
				if stats.is_empty():
					continue
				var rating := _ChartDifficultyAnalyzer.decimal_rating_from_stats(stats)
				if rating <= 0.0:
					continue
				# Lanes: canonical for exact parity with SessionScopeResolver._entries_for_song (unified -> 4)
				var lanes: int = _ChartDifficultyAnalyzer.canonical_lanes_for_notes(path, inst, stem)
				per_inst[stem] = {"rating": rating, "lanes": lanes}
				chart_entry_count += 1
			if not per_inst.is_empty():
				chart_map[inst] = per_inst
		entries.append({
			"path": path,
			"duration_sec": duration_sec,
			"genre_groups": groups,
			"charts": chart_map,
		})
	song_count = entries.size()
	built_at_msec = Time.get_ticks_msec()
	built_at_epoch_usec = Time.get_ticks_usec()
	build_msec = (Time.get_ticks_usec() - t0) / 1000.0
	print("[LibraryIndex] built in %.2fms songs=%d chart_entries=%d entries=%d" % [build_msec, song_count, chart_entry_count, entries.size()])


func is_empty() -> bool:
	return entries.is_empty()

## Core query: count unique songs with at least one matching chart, up to max_count.
func count_matching_songs_up_to(scope_config: Dictionary, max_count: int, instrument_override: String = "") -> int:
	var t0 := Time.get_ticks_usec()
	if entries.is_empty() or max_count <= 0:
		var dt0 := (Time.get_ticks_usec() - t0) / 1000.0
		return 0
	var cfg := _EndlessSessionConfig.sanitize(scope_config)
	var instruments: Array = _EndlessSessionConfig.instruments_from_config(cfg, instrument_override)
	var allowed_stems: Array[String] = _allowed_chart_stems(cfg)
	var genre_policy := str(cfg.get("genre_policy", _EndlessSessionConfig.GENRE_POLICY_ALL))
	var allowed_groups: Array = []
	if genre_policy == _EndlessSessionConfig.GENRE_POLICY_GROUPS:
		var raw_allowed: Variant = cfg.get("genre_group_ids", [])
		if raw_allowed is Array:
			for gid in raw_allowed as Array:
				var s := str(gid).strip_edges()
				if s != "" and not allowed_groups.has(s):
					allowed_groups.append(s)
	var dmin := float(cfg.get("difficulty_min", _EndlessSessionConfig.DEFAULT_DIFFICULTY_MIN))
	var dmax := float(cfg.get("difficulty_max", _EndlessSessionConfig.DEFAULT_DIFFICULTY_MAX))
	var max_over_cap := bool(cfg.get("difficulty_max_over_cap", false))
	var diff_policy := str(cfg.get("chart_difficulty_policy", _EndlessSessionConfig.CHART_DIFFICULTY_POLICY_ALL))
	var tiers_allowed: Array = cfg.get("chart_difficulty_tiers_allowed", [])
	var duration_min := int(cfg.get("duration_min_sec", _EndlessSessionConfig.DEFAULT_DURATION_MIN_SEC))
	var duration_max := int(cfg.get("duration_max_sec", _EndlessSessionConfig.DEFAULT_DURATION_MAX_SEC))
	var duration_max_open := bool(cfg.get("duration_max_open", false))
	var favorites_only := bool(cfg.get("random_favorites_only", false))
	var track_source := str(cfg.get("track_source", _EndlessSessionConfig.TRACK_SOURCE_RANDOM))
	var selected_paths: Array[String] = []
	var playlist_paths: Dictionary = {}
	var use_playlist_filter := false
	var use_selected_filter := false
	if track_source == _EndlessSessionConfig.TRACK_SOURCE_SELECTED:
		var raw_sel: Variant = cfg.get("selected_song_paths", [])
		if raw_sel is Array:
			for p in raw_sel as Array:
				var pp := str(p).strip_edges()
				if pp != "" and not selected_paths.has(pp):
					selected_paths.append(pp)
		use_selected_filter = true
		if selected_paths.is_empty():
			var dt1 := (Time.get_ticks_usec() - t0) / 1000.0
			return 0
	elif track_source == _EndlessSessionConfig.TRACK_SOURCE_PLAYLIST:
		var pid := str(cfg.get("playlist_id", "")).strip_edges()
		if pid != "":
			var pl_paths: Array = _PlaylistCatalog.song_paths_for(pid)
			for p in pl_paths:
				var pp2 := str(p).strip_edges()
				if pp2 != "":
					playlist_paths[pp2] = true
			use_playlist_filter = true
			if playlist_paths.is_empty():
				var dt2 := (Time.get_ticks_usec() - t0) / 1000.0
				return 0

	var count := 0
	for entry in entries:
		var path := str(entry.get("path", "")).strip_edges()
		if path == "":
			continue
		if use_selected_filter and not selected_paths.has(path):
			continue
		if use_playlist_filter and not playlist_paths.has(path):
			continue
		if favorites_only:
			if PlayerDataManager == null or not PlayerDataManager.has_method("is_song_favorite"):
				continue
			if not PlayerDataManager.is_song_favorite(path):
				continue
		# Genre
		if genre_policy == _EndlessSessionConfig.GENRE_POLICY_GROUPS:
			if allowed_groups.is_empty():
				continue
			var groups: Array = entry.get("genre_groups", [])
			var ok_genre := false
			for g in groups:
				if allowed_groups.has(str(g)):
					ok_genre = true
					break
			if not ok_genre:
				continue
		# Duration
		var dur: float = float(entry.get("duration_sec", 0.0))
		if not _matches_duration(dur, duration_min, duration_max, duration_max_open):
			continue
		# Charts / difficulty
		var charts: Dictionary = entry.get("charts", {})
		if charts.is_empty():
			continue
		var found := false
		for inst in instruments:
			var inst_key := str(inst).strip_edges().to_lower()
			var per_inst: Variant = charts.get(inst_key, null)
			if per_inst == null or not per_inst is Dictionary:
				continue
			var per_dict: Dictionary = per_inst as Dictionary
			if per_dict.is_empty():
				continue
			for stem in allowed_stems:
				if not per_dict.has(stem):
					continue
				var raw: Variant = per_dict[stem]
				var rating: float = 0.0
				if raw is Dictionary:
					rating = float((raw as Dictionary).get("rating", 0.0))
				else:
					rating = float(raw)
				if not _matches_difficulty(rating, dmin, dmax, max_over_cap, diff_policy, tiers_allowed):
					continue
				found = true
				break
			if found:
				break
		if found:
			count += 1
			if count >= max_count:
				var dt := (Time.get_ticks_usec() - t0) / 1000.0
				return count
	var dt_final := (Time.get_ticks_usec() - t0) / 1000.0
	return count


func has_minimum_matching_songs(scope_config: Dictionary, min_required: int, instrument_override: String = "") -> bool:
	var t0 := Time.get_ticks_usec()
	var cnt := count_matching_songs_up_to(scope_config, min_required, instrument_override)
	var res := cnt >= min_required
	var dt := (Time.get_ticks_usec() - t0) / 1000.0
	return res


## Returns playable entries mirroring SessionScopeResolver.resolve_scope() for RANDOM source.
## Used by Marathon preview to avoid filesystem scan. Falls back to empty if not RANDOM.
func get_matching_entries(scope_config: Dictionary, instrument_override: String = "") -> Array[Dictionary]:
	var t0 := Time.get_ticks_usec()
	var cfg := _EndlessSessionConfig.sanitize(scope_config)
	var track_source := str(cfg.get("track_source", _EndlessSessionConfig.TRACK_SOURCE_RANDOM))
	if track_source != _EndlessSessionConfig.TRACK_SOURCE_RANDOM:
		# Selected/Playlist need different ordering — let caller fallback to resolve_scope
		return []
	var instruments: Array = _EndlessSessionConfig.instruments_from_config(cfg, instrument_override)
	var allowed_stems: Array[String] = _allowed_chart_stems(cfg)
	var genre_policy := str(cfg.get("genre_policy", _EndlessSessionConfig.GENRE_POLICY_ALL))
	var allowed_groups: Array = []
	if genre_policy == _EndlessSessionConfig.GENRE_POLICY_GROUPS:
		var raw_allowed: Variant = cfg.get("genre_group_ids", [])
		if raw_allowed is Array:
			for gid in raw_allowed as Array:
				var s := str(gid).strip_edges()
				if s != "" and not allowed_groups.has(s):
					allowed_groups.append(s)
	var dmin := float(cfg.get("difficulty_min", _EndlessSessionConfig.DEFAULT_DIFFICULTY_MIN))
	var dmax := float(cfg.get("difficulty_max", _EndlessSessionConfig.DEFAULT_DIFFICULTY_MAX))
	var max_over_cap := bool(cfg.get("difficulty_max_over_cap", false))
	var diff_policy := str(cfg.get("chart_difficulty_policy", _EndlessSessionConfig.CHART_DIFFICULTY_POLICY_ALL))
	var tiers_allowed: Array = cfg.get("chart_difficulty_tiers_allowed", [])
	var duration_min := int(cfg.get("duration_min_sec", _EndlessSessionConfig.DEFAULT_DURATION_MIN_SEC))
	var duration_max := int(cfg.get("duration_max_sec", _EndlessSessionConfig.DEFAULT_DURATION_MAX_SEC))
	var duration_max_open := bool(cfg.get("duration_max_open", false))
	var favorites_only := bool(cfg.get("random_favorites_only", false))
	var out: Array[Dictionary] = []
	for entry in entries:
		var path := str(entry.get("path", "")).strip_edges()
		if path == "":
			continue
		if favorites_only:
			if PlayerDataManager == null or not PlayerDataManager.has_method("is_song_favorite"):
				continue
			if not PlayerDataManager.is_song_favorite(path):
				continue
		if genre_policy == _EndlessSessionConfig.GENRE_POLICY_GROUPS:
			if allowed_groups.is_empty():
				continue
			var groups: Array = entry.get("genre_groups", [])
			var ok_genre := false
			for g in groups:
				if allowed_groups.has(str(g)):
					ok_genre = true
					break
			if not ok_genre:
				continue
		var dur: float = float(entry.get("duration_sec", 0.0))
		if not _matches_duration(dur, duration_min, duration_max, duration_max_open):
			continue
		var charts: Dictionary = entry.get("charts", {})
		if charts.is_empty():
			continue
		# Dedup per chart_key stem|lanes (one entry per stem, lanes from stored)
		var seen_keys: Dictionary = {}
		for inst in instruments:
			var inst_key := str(inst).strip_edges().to_lower()
			var per_inst: Variant = charts.get(inst_key, null)
			if per_inst == null or not per_inst is Dictionary:
				continue
			var per_dict: Dictionary = per_inst as Dictionary
			for stem in allowed_stems:
				if not per_dict.has(stem):
					continue
				var raw: Variant = per_dict[stem]
				var rating: float = 0.0
				var lanes: int = 4
				if raw is Dictionary:
					rating = float((raw as Dictionary).get("rating", 0.0))
					lanes = int((raw as Dictionary).get("lanes", 4))
				else:
					rating = float(raw)
				if not _matches_difficulty(rating, dmin, dmax, max_over_cap, diff_policy, tiers_allowed):
					continue
				var chart_key := "%s|%d" % [stem, lanes]
				if seen_keys.has(chart_key):
					continue
				seen_keys[chart_key] = true
				var pair := _GoalDiff.pair_from_stem(stem)
				var goal := str(pair.get("goal", _GoalDiff.DEFAULT_GOAL))
				var diff := str(pair.get("difficulty", _GoalDiff.DEFAULT_DIFFICULTY))
				var intent := _GoalDiff.intent_for(goal, diff)
				var mode := _GenerationIntents.intent_to_legacy_mode(intent)
				out.append({
					"song_path": path,
					"instrument": inst_key,
					"mode": mode,
					"intent": intent,
					"chart_stem": stem,
					"lanes": lanes,
					"decimal_rating": rating,
					"duration_sec": dur,
				})
	var dt := (Time.get_ticks_usec() - t0) / 1000.0
	return out


func get_stats() -> Dictionary:
	return {
		"songs": song_count,
		"chart_entries": chart_entry_count,
		"build_msec": build_msec,
		"built_at_msec": built_at_msec,
		"entries": entries.size(),
	}


# ---- helpers mirroring SessionScopeResolver ----

static func _matches_duration(duration_sec: float, dmin: int, dmax: int, max_open: bool) -> bool:
	if duration_sec <= 0.0:
		return true
	var vi := int(duration_sec)
	if vi < dmin:
		return false
	if max_open:
		return true
	return vi <= dmax


static func _matches_difficulty(decimal_rating: float, dmin: float, dmax: float, max_over_cap: bool, diff_policy: String, tiers_allowed: Array) -> bool:
	if decimal_rating <= 0.0:
		return false
	if decimal_rating + 0.001 < dmin:
		return false
	if not max_over_cap and decimal_rating > dmax + 0.001:
		return false
	if diff_policy != _EndlessSessionConfig.CHART_DIFFICULTY_POLICY_SELECTED:
		return true
	if tiers_allowed.is_empty():
		return true
	for tier_id in tiers_allowed:
		var tier_range := _EndlessSessionConfig.difficulty_range_for_tier(str(tier_id))
		var tier_min := float(tier_range.get("min", _EndlessSessionConfig.DIFFICULTY_BASE_MIN))
		var tier_max := float(tier_range.get("max", _EndlessSessionConfig.DIFFICULTY_BASE_MAX))
		if decimal_rating + 0.001 >= tier_min and decimal_rating <= tier_max + 0.001:
			return true
	return false


static func _allowed_chart_stems(cfg: Dictionary) -> Array[String]:
	var policy := str(cfg.get("generation_mode_policy", _EndlessSessionConfig.GEN_MODE_POLICY_ALL))
	if policy == _EndlessSessionConfig.GEN_MODE_POLICY_ALL:
		return _GoalDiff.all_stems()
	var goals := _EndlessSessionConfig.sanitize_generation_goals(cfg.get("generation_modes_allowed", []))
	if goals.is_empty():
		goals = _EndlessSessionConfig.UI_CHART_STYLE_GOALS.duplicate()
	var out: Array[String] = []
	for goal in goals:
		for difficulty in _GoalDiff.DIFFICULTIES:
			var stem := _GoalDiff.chart_stem(str(goal), str(difficulty))
			if not out.has(stem):
				out.append(stem)
	return out