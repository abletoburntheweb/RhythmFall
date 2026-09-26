# logic/data/rhythm_dna_view.gd
extends RefCounted
class_name RhythmDnaView

static func _tr(key: String) -> String:
	return TranslationServer.translate(key)


static func format_item(item: Variant) -> String:
	if not item is Dictionary:
		return ""
	var key := String(item.get("key", "")).strip_edges()
	if key == "":
		return ""
	var args: Variant = item.get("args", {})
	if args is Dictionary and not args.is_empty():
		return _format_with_args(key, args as Dictionary)
	return _tr(key)


static func _format_with_args(key: String, args: Dictionary) -> String:
	var template := _tr(key)
	if template == key:
		return key
	var ordered: Array = []
	for arg_key in ["bpm", "final", "count", "removed", "total", "core", "halo"]:
		if args.has(arg_key):
			ordered.append(args[arg_key])
	if ordered.is_empty():
		for v in args.values():
			ordered.append(v)
	if ordered.is_empty():
		return template
	return template % ordered


static func format_level(level: String) -> String:
	match String(level).strip_edges().to_lower():
		"high":
			return _tr("DNA_LEVEL_HIGH")
		"low":
			return _tr("DNA_LEVEL_LOW")
		_:
			return _tr("DNA_LEVEL_MEDIUM")


static func format_chart_preset(track: Dictionary) -> String:
	var preset := String(track.get("preset_id", "")).strip_edges().to_lower()
	var mode := String(track.get("mode", "")).strip_edges().to_lower()
	var instrument := String(track.get("instrument", "drums")).strip_edges().to_lower()
	var core := preset if preset != "" else mode
	if core == "":
		return ""
	if "_" in core:
		return core
	return "%s_%s" % [instrument, core]


static func format_report(dna: Dictionary) -> PackedStringArray:
	var lines: PackedStringArray = []
	if dna.is_empty():
		lines.append(_tr("DNA_EMPTY"))
		return lines

	var track: Dictionary = dna.get("track", {}) if dna.get("track", {}) is Dictionary else {}
	var pipeline: Dictionary = dna.get("pipeline", {}) if dna.get("pipeline", {}) is Dictionary else {}
	var genes: Dictionary = dna.get("genes", {}) if dna.get("genes", {}) is Dictionary else {}
	var confidence: Dictionary = genes.get("confidence", {}) if genes.get("confidence", {}) is Dictionary else {}
	var rhythm_gene: Dictionary = genes.get("rhythm", {}) if genes.get("rhythm", {}) is Dictionary else {}

	var title := String(track.get("title", "")).strip_edges()
	var artist := String(track.get("artist", "")).strip_edges()
	if title != "" or artist != "":
		if artist != "" and title != "":
			lines.append(_tr("DNA_TRACK_FMT") % [artist, title])
		elif title != "":
			lines.append(title)
		else:
			lines.append(artist)

	var meta_bits: Array[String] = []
	var bpm := float(track.get("bpm", 0.0))
	if bpm > 0.0:
		meta_bits.append(_tr("DNA_META_BPM_FMT") % int(round(bpm)))
	var preset_label := format_chart_preset(track)
	if preset_label != "":
		meta_bits.append(preset_label)
	var genre := String(track.get("genre", "")).strip_edges()
	if genre != "":
		meta_bits.append(_tr("DNA_META_GENRE_FMT") % genre)
	if meta_bits.size() > 0:
		lines.append(" · ".join(meta_bits))

	lines.append("")

	var found: Array = dna.get("found", []) if dna.get("found", []) is Array else []
	if found.size() > 0:
		lines.append(_tr("DNA_SECTION_FOUND"))
		for item in found:
			var line := format_item(item)
			if line != "":
				lines.append("• " + line)
		lines.append("")

	if not pipeline.is_empty():
		lines.append(_tr("DNA_SECTION_PIPELINE"))
		var source := int(pipeline.get("source", 0))
		var pre_section := int(pipeline.get("pre_section", 0))
		var post_section := int(pipeline.get("post_section", 0))
		var final_events := int(pipeline.get("final_events", 0))
		var final_notes := int(pipeline.get("final_notes", 0))
		if source <= 0 and pre_section <= 0 and post_section <= 0 and final_notes > 0:
			lines.append(_tr("DNA_PIPELINE_SIMPLE_FMT") % final_notes)
		else:
			lines.append(_tr("DNA_PIPELINE_LINE_FMT") % source)
			lines.append(_tr("DNA_PIPELINE_LINE2_FMT") % [pre_section, post_section])
			lines.append(_tr("DNA_PIPELINE_LINE3_FMT") % [final_events, final_notes])
		var removed := int(pipeline.get("removed_total", 0))
		var added := int(pipeline.get("added_net", 0))
		if removed > 0 or added > 0:
			lines.append(_tr("DNA_PIPELINE_DELTA_FMT") % [removed, added])
		lines.append("")

	var decisions: Array = dna.get("decisions", []) if dna.get("decisions", []) is Array else []
	if decisions.size() > 0:
		lines.append(_tr("DNA_SECTION_DECISIONS"))
		for item in decisions:
			var line := format_item(item)
			if line != "":
				lines.append("• " + line)
		lines.append("")

	if not rhythm_gene.is_empty():
		lines.append(_tr("DNA_SECTION_RHYTHM"))
		if bool(rhythm_gene.get("kit_detected", false)):
			lines.append("• " + _tr("DNA_GENE_KIT_DETECTED"))
		lines.append(
			_tr("DNA_GENE_GROOVE_FMT") % format_level(String(rhythm_gene.get("groove_stability", "medium")))
		)
		lines.append(
			_tr("DNA_GENE_FILL_FMT") % format_level(String(rhythm_gene.get("fill_density", "medium")))
		)
		lines.append("")

	var warnings: Array = dna.get("warnings", []) if dna.get("warnings", []) is Array else []
	var meta: Dictionary = dna.get("meta", {}) if dna.get("meta", {}) is Dictionary else {}
	var warning_lines: PackedStringArray = []
	if NotesUtils.is_minimal_rhythm_dna(dna):
		var reason := String(meta.get("reason", ""))
		if reason == "":
			for item in warnings:
				if item is Dictionary and String(item.get("key", "")) == "DNA_WARN_CLIENT_FALLBACK":
					reason = "server_empty"
					break
			if reason == "":
				reason = "legacy_chart"
		var notice_key := "DNA_WARN_CLIENT_FALLBACK" if reason == "server_empty" else "DNA_WARN_LEGACY_CHART"
		warning_lines.append("⚠ " + _tr(notice_key))
	for item in warnings:
		if item is Dictionary:
			var warn_key := String(item.get("key", ""))
			if warn_key in ["DNA_WARN_CLIENT_FALLBACK", "DNA_WARN_LEGACY_CHART"]:
				continue
		var line := format_item(item)
		if line != "":
			warning_lines.append("⚠ " + line)
	if warning_lines.size() > 0:
		lines.append(_tr("DNA_SECTION_WARNINGS"))
		for warning_line in warning_lines:
			lines.append(warning_line)
		lines.append("")

	if not confidence.is_empty():
		lines.append(_tr("DNA_SECTION_CONFIDENCE"))
		lines.append(_tr("DNA_CONFIDENCE_OVERALL_FMT") % int(confidence.get("overall", 0)))
		lines.append(_tr("DNA_CONFIDENCE_DRUM_FMT") % int(confidence.get("drum_detection", 0)))
		lines.append(_tr("DNA_CONFIDENCE_BEAT_FMT") % int(confidence.get("beat_tracking", 0)))
		lines.append(_tr("DNA_CONFIDENCE_GENRE_FMT") % int(confidence.get("genre", 0)))
		lines.append(_tr("DNA_CONFIDENCE_PATTERN_FMT") % int(confidence.get("pattern", 0)))
		lines.append("")
		lines.append(_tr("DNA_FOOTER"))

	return lines


static func section_letter(seg: Dictionary) -> String:
	return String(seg.get("section", seg.get("block", ""))).strip_edges().to_upper()

static func section_role(seg: Dictionary) -> String:
	return String(seg.get("role", "")).strip_edges().to_lower()

static func _normalize_role(role: String) -> String:
	var r := String(role).strip_edges().to_lower().replace("_", "-")
	match r:
		"inst": return "instrumental"
		"prechorus": return "pre-chorus"
		"postchorus": return "post-chorus"
		_: return r

static func _is_transition_role(role_norm: String) -> bool:
	match role_norm:
		"pre-chorus", "post-chorus", "break", "interlude":
			return true
		_: return false

static func _is_numbered_role(role_norm: String) -> bool:
	# Only Verse is numbered. Chorus and all other roles are not.
	match role_norm:
		"verse":
			return true
		_: return false

static func short_letter_for_role(role: String) -> String:
	var r := String(role).strip_edges().to_lower().replace("_", "-")
	match r:
		"intro": return "I"
		"verse": return "V"
		"chorus": return "C"
		"bridge": return "B"
		"breakdown": return "BD"
		"outro": return "O"
		"solo": return "S"
		"body": return "Y"
		"peak": return "K"
		"pre-chorus", "pre_chorus", "prechorus": return "PR"
		"post-chorus", "post_chorus", "postchorus": return "PO"
		"instrumental", "inst": return "IN"
		"interlude": return "INT"
		"refrain": return "R"
		_: return r.substr(0, 1).to_upper() if r != "" else ""

static func _full_name_for_role(role: String) -> String:
	var key := "DNA_ROLE_%s" % String(role).strip_edges().to_upper().replace("-", "_")
	var tr_val := _tr(key)
	if tr_val != key:
		return tr_val
	# Fallback: capitalize role
	return String(role).capitalize()

static func _duration_of(seg: Dictionary) -> float:
	return maxf(0.0, float(seg.get("end_s", seg.get("start_s", 0.0))) - float(seg.get("start_s", 0.0)))

static func _merge_two_segments(a: Dictionary, b: Dictionary) -> Dictionary:
	# Merge b into a (a is kept, extended to cover b). a and b are assumed adjacent (a.start < b.start).
	var merged: Dictionary = a.duplicate(true)
	var start_a := float(a.get("start_s", 0.0))
	var end_a := float(a.get("end_s", 0.0))
	var start_b := float(b.get("start_s", 0.0))
	var end_b := float(b.get("end_s", 0.0))
	merged["start_s"] = minf(start_a, start_b)
	merged["end_s"] = maxf(end_a, end_b)
	# measures / notes
	if a.has("measures") and b.has("measures"):
		merged["measures"] = int(a.get("measures", 0)) + int(b.get("measures", 0))
	elif b.has("measures"):
		merged["measures"] = int(merged.get("measures", 0)) + int(b.get("measures", 0))
	if a.has("notes") and b.has("notes"):
		merged["notes"] = int(a.get("notes", 0)) + int(b.get("notes", 0))
	elif b.has("notes"):
		merged["notes"] = int(merged.get("notes", 0)) + int(b.get("notes", 0))
	# block: keep first non-empty
	if String(merged.get("block", "")).strip_edges() == "" and String(b.get("block", "")).strip_edges() != "":
		merged["block"] = String(b.get("block", ""))
	if String(merged.get("section", "")).strip_edges() == "" and String(b.get("section", "")).strip_edges() != "":
		merged["section"] = String(b.get("section", ""))
	# intensity/density average if both present
	if a.has("intensity") and b.has("intensity"):
		merged["intensity"] = (float(a.get("intensity", 0.0)) + float(b.get("intensity", 0.0))) * 0.5
	elif b.has("intensity") and not merged.has("intensity"):
		merged["intensity"] = float(b.get("intensity", 0.0))
	if a.has("density") and b.has("density"):
		merged["density"] = (float(a.get("density", 0.0)) + float(b.get("density", 0.0))) * 0.5
	elif b.has("density") and not merged.has("density"):
		merged["density"] = float(b.get("density", 0.0))
	# confidence: keep max
	if a.has("confidence") and b.has("confidence"):
		merged["confidence"] = maxf(float(a.get("confidence", 0.0)), float(b.get("confidence", 0.0)))
	elif b.has("confidence") and not merged.has("confidence"):
		merged["confidence"] = float(b.get("confidence", 0.0))
	# boundary_source: if either is both, keep both
	if String(b.get("boundary_source", "")) == "both":
		merged["boundary_source"] = "both"
	# keep role from a (they are same role when merging same-role); if a role empty and b has, keep b
	if String(merged.get("role", "")).strip_edges() == "" and String(b.get("role", "")).strip_edges() != "":
		merged["role"] = String(b.get("role", ""))
	return merged

static func coalesce_to_semantic_sections(sections: Array) -> Array:
	# Technical fragments → semantic sections.
	# Input: sorted technical segments (from SongFormer/existing). Output: merged semantic sections.
	if sections.is_empty():
		return []
	# Duplicate and ensure sorted by start_s
	var working: Array = []
	for raw in sections:
		if not raw is Dictionary:
			continue
		var seg: Dictionary = (raw as Dictionary).duplicate(true)
		# Normalize start/end
		seg["start_s"] = float(seg.get("start_s", 0.0))
		seg["end_s"] = float(seg.get("end_s", seg.get("start_s", 0.0)))
		if seg["end_s"] < seg["start_s"]:
			seg["end_s"] = seg["start_s"]
		seg["role"] = _normalize_role(String(seg.get("role", "")))
		working.append(seg)
	working.sort_custom(func(a, b): return float(a.get("start_s", 0.0)) < float(b.get("start_s", 0.0)))

	# Pass 1: absorb short transition segments (pre/post/break/interlude <10s)
	var i := 0
	while i < working.size():
		var seg: Dictionary = working[i]
		var role_n := _normalize_role(String(seg.get("role", "")))
		var dur := _duration_of(seg)
		var meas := int(seg.get("measures", 0))
		var is_trans := _is_transition_role(role_n)
		var is_short := dur < 10.0 or (meas > 0 and meas < 4)
		if is_trans and is_short:
			var prev: Variant = working[i - 1] if i > 0 else null
			var next: Variant = working[i + 1] if i + 1 < working.size() else null
			var target_idx := -1
			if prev != null and next != null:
				# Choose neighbor with closer intensity or larger duration
				var has_intensity := seg.has("intensity") and (prev as Dictionary).has("intensity") and (next as Dictionary).has("intensity")
				if has_intensity:
					var d_prev := absf(float((prev as Dictionary).get("intensity", 0.0)) - float(seg.get("intensity", 0.0)))
					var d_next := absf(float((next as Dictionary).get("intensity", 0.0)) - float(seg.get("intensity", 0.0)))
					target_idx = i + 1 if d_next < d_prev else i - 1
				else:
					var dur_prev := _duration_of(prev as Dictionary)
					var dur_next := _duration_of(next as Dictionary)
					target_idx = i + 1 if dur_next > dur_prev else i - 1
			elif prev != null:
				target_idx = i - 1
			elif next != null:
				target_idx = i + 1
			if target_idx != -1:
				var target: Dictionary = working[target_idx]
				var merged: Dictionary = _merge_two_segments(target, seg) if target_idx < i else _merge_two_segments(seg, target)
				# Keep target's semantic role (the larger neighbor), not the short transition's role
				if target_idx > i:
					merged["role"] = String(target.get("role", ""))
				# For target < i (prev), merged is prev+seg; for target > i (next), merged is seg+next
				# Replace target with merged, remove current
				if target_idx < i:
					# merged into prev
					working[target_idx] = merged
					working.remove_at(i)
					# stay at same i (now points to next)
					continue
				else:
					# merged into next
					working[target_idx] = merged
					working.remove_at(i)
					continue
		i += 1

	# Pass 1b: short non-transition fragments (e.g., 5-6s Verse between Bridge and Chorus)
	# Should not become its own Practice section without strong musical evidence.
	var k := 0
	while k < working.size():
		var seg2: Dictionary = working[k]
		var role2 := _normalize_role(String(seg2.get("role", "")))
		if role2 in ["verse", "chorus", "bridge", "instrumental", "solo", "breakdown", "interlude"]:
			var dur2 := _duration_of(seg2)
			var meas2 := int(seg2.get("measures", 0))
			var is_short2 := dur2 < 8.0 or (meas2 > 0 and meas2 < 3)
			if is_short2:
				var has_strong := false
				if seg2.has("confidence") and float(seg2.get("confidence", 0.0)) >= 0.75 and String(seg2.get("boundary_source", "")) == "both":
					var block2 := String(seg2.get("block", "")).strip_edges()
					var prev2: Variant = working[k - 1] if k > 0 else null
					var next2: Variant = working[k + 1] if k + 1 < working.size() else null
					var block_prev2 := String((prev2 as Dictionary).get("block", "")) if prev2 != null else ""
					var block_next2 := String((next2 as Dictionary).get("block", "")) if next2 != null else ""
					if block2 != "" and block2 != block_prev2 and block2 != block_next2:
						has_strong = true
				if not has_strong:
					var prev2a: Variant = working[k - 1] if k > 0 else null
					var next2a: Variant = working[k + 1] if k + 1 < working.size() else null
					var target_idx2 := -1
					if prev2a != null and next2a != null:
						var has_int2 := seg2.has("intensity") and (prev2a as Dictionary).has("intensity") and (next2a as Dictionary).has("intensity")
						if has_int2:
							var d_prev2 := absf(float((prev2a as Dictionary).get("intensity", 0.0)) - float(seg2.get("intensity", 0.0)))
							var d_next2 := absf(float((next2a as Dictionary).get("intensity", 0.0)) - float(seg2.get("intensity", 0.0)))
							target_idx2 = k + 1 if d_next2 < d_prev2 else k - 1
						else:
							var dur_prev2 := _duration_of(prev2a as Dictionary)
							var dur_next2 := _duration_of(next2a as Dictionary)
							target_idx2 = k + 1 if dur_next2 > dur_prev2 else k - 1
					elif prev2a != null:
						target_idx2 = k - 1
					elif next2a != null:
						target_idx2 = k + 1
					if target_idx2 != -1:
						var target2: Dictionary = working[target_idx2]
						var merged2: Dictionary = _merge_two_segments(target2, seg2) if target_idx2 < k else _merge_two_segments(seg2, target2)
						if target_idx2 > k:
							merged2["role"] = String(target2.get("role", ""))
						if target_idx2 < k:
							working[target_idx2] = merged2
							working.remove_at(k)
							continue
						else:
							working[target_idx2] = merged2
							working.remove_at(k)
							continue
		k += 1

	# Pass 2: merge adjacent same-role fragments into one semantic section
	# This is the core fix for Verse 40 / Bridge 17. Duration cap is heuristic, not absolute.
	var j := 0
	while j < working.size() - 1:
		var a: Dictionary = working[j]
		var b: Dictionary = working[j + 1]
		var role_a := _normalize_role(String(a.get("role", "")))
		var role_b := _normalize_role(String(b.get("role", "")))
		var should_merge := false
		if role_a != "" and role_a == role_b:
			var merged_dur := float(b.get("end_s", 0.0)) - float(a.get("start_s", 0.0))
			var limit := 48.0 if role_a in ["intro", "outro"] else 96.0
			if merged_dur <= limit:
				should_merge = true
			else:
				var block_a := String(a.get("block", "")).strip_edges()
				var block_b := String(b.get("block", "")).strip_edges()
				var boundary_strong2 := String(b.get("boundary_source", "")) == "both"
				if block_a != "" and block_a == block_b:
					should_merge = true
				elif a.has("intensity") and b.has("intensity") and a.has("density") and b.has("density"):
					var d_int := absf(float(a.get("intensity", 0.0)) - float(b.get("intensity", 0.0)))
					var d_den := absf(float(a.get("density", 0.0)) - float(b.get("density", 0.0)))
					if d_int < 0.12 and d_den < 0.20 and not boundary_strong2:
						should_merge = true
					elif (block_a == "" or block_b == "") and d_int < 0.15 and d_den < 0.25 and not boundary_strong2:
						should_merge = true
				# Short tail of large structural block (Bridge/Inst/Solo etc) — don't split just due to Δdensity
				if not should_merge and role_a in ["bridge", "instrumental", "solo", "breakdown", "intro", "outro"] and _duration_of(b) < 20.0 and not boundary_strong2:
					should_merge = true
		elif role_a == "" and role_b == "":
			var la := section_letter(a)
			var lb := section_letter(b)
			if la != "" and la == lb:
				var merged_dur2 := float(b.get("end_s", 0.0)) - float(a.get("start_s", 0.0))
				if merged_dur2 <= 96.0:
					should_merge = true
				elif la != "" and la == lb:
					# Same letter but long — still one block if intensity similar
					if a.has("intensity") and b.has("intensity"):
						var d_int2 := absf(float(a.get("intensity", 0.0)) - float(b.get("intensity", 0.0)))
						if d_int2 < 0.12:
							should_merge = true
		if should_merge:
			var merged := _merge_two_segments(a, b)
			working[j] = merged
			working.remove_at(j + 1)
			continue
		j += 1

	return working

static func annotate_sections_with_names(sections: Array) -> Array:
	# New semantic pipeline: technical fragments → semantic sections → numbering
	# Numbering is per semantic role, not per technical fragment.
	# Chorus is never numbered; Verse is numbered only if there is more than one Verse.
	var semantic: Array = coalesce_to_semantic_sections(sections)
	var total_verses := 0
	for s in semantic:
		if s is Dictionary and _normalize_role(String(s.get("role", ""))) == "verse":
			total_verses += 1
	var role_counts: Dictionary = {}
	var out: Array = []
	for raw in semantic:
		if not raw is Dictionary:
			continue
		var seg: Dictionary = (raw as Dictionary).duplicate(true)
		var role_n := _normalize_role(String(seg.get("role", "")))
		var full := ""
		var short := ""
		if role_n != "":
			if _is_numbered_role(role_n):
				if total_verses == 1:
					# Single Verse in song — display without number
					full = _full_name_for_role(role_n)
					short = short_letter_for_role(role_n)
				else:
					var cnt := int(role_counts.get(role_n, 0)) + 1
					role_counts[role_n] = cnt
					var base_name := _full_name_for_role(role_n)
					full = "%s %d" % [base_name, cnt]
					var letter := short_letter_for_role(role_n)
					short = "%s%d" % [letter, cnt]
			else:
				# Non-numbered: Bridge/Intro/Outro/Instrumental etc — always without number
				full = _full_name_for_role(role_n)
				short = short_letter_for_role(role_n)
				if short == "":
					short = role_n.substr(0, 1).to_upper()
				if full == "":
					full = role_n.capitalize()
		else:
			var letter := section_letter(seg)
			if letter != "":
				full = _tr("DNA_UI_SECTION_FMT") % letter
				short = letter
			else:
				var lk := String(seg.get("label_key", "DNA_SEG_STEADY"))
				full = _tr(lk)
				short = full.substr(0, 1).to_upper() if full != "" else "?"
		seg["display_full"] = full
		seg["display_short"] = short
		seg["role"] = role_n
		seg["section_letter"] = section_letter(seg)
		out.append(seg)
	return out

static func format_section_headline(seg: Dictionary) -> String:
	# Prefer semantic role; fallback to technical letter only if role missing.
	# If seg already annotated, use its display_full.
	if seg.has("display_full"):
		return String(seg.get("display_full", ""))
	var role := _normalize_role(section_role(seg))
	if role != "":
		if _is_numbered_role(role):
			# Without annotation we cannot know number, so return base name
			return _full_name_for_role(role)
		return _full_name_for_role(role)
	var letter := section_letter(seg)
	if letter != "":
		return _tr("DNA_UI_SECTION_FMT") % letter
	return _tr(String(seg.get("label_key", "DNA_SEG_STEADY")))

static func format_section_short(seg: Dictionary) -> String:
	if seg.has("display_short"):
		return String(seg.get("display_short", ""))
	var role := _normalize_role(section_role(seg))
	if role != "":
		return short_letter_for_role(role)
	var letter := section_letter(seg)
	if letter != "":
		return letter
	return "?"

static func resolve_structure_timeline_for_ui(dna: Dictionary) -> Array:
	var sections: Variant = dna.get("structure_sections", [])
	if sections is Array and not (sections as Array).is_empty():
		return _normalize_structure_sections(sections as Array)
	var timeline: Variant = dna.get("structure_timeline", [])
	if not timeline is Array or (timeline as Array).is_empty():
		return []
	return _coalesce_structure_timeline(timeline as Array)

static func resolve_structure_for_song(song_path: String, dna: Dictionary) -> Array:
	# Canonical song-level sections.rfd takes precedence
	if song_path != "" and String(song_path).strip_edges() != "":
		var canon := NotesUtils.load_canonical_sections(song_path)
		if not canon.is_empty():
			return _normalize_structure_sections(canon)
		# Try migration if canonical missing but embedded exists
		if NotesUtils.ensure_canonical_sections(song_path):
			var migrated := NotesUtils.load_canonical_sections(song_path)
			if not migrated.is_empty():
				return _normalize_structure_sections(migrated)
	return resolve_structure_timeline_for_ui(dna)


static func _normalize_structure_sections(sections: Array) -> Array:
	var out: Array = []
	for raw in sections:
		if not raw is Dictionary:
			continue
		var seg: Dictionary = (raw as Dictionary).duplicate(true)
		var letter := section_letter(seg)
		# Preserve enriched fields if present (role, intensity, etc) for semantic merging
		seg["start_s"] = float(seg.get("start_s", 0.0))
		seg["end_s"] = float(seg.get("end_s", seg.get("start_s", 0.0)))
		seg["section"] = letter
		seg["block"] = letter
		if not seg.has("kind"):
			seg["kind"] = String(seg.get("kind", "steady"))
		if not seg.has("label_key"):
			seg["label_key"] = String(seg.get("label_key", "DNA_SEG_STEADY"))
		if not seg.has("role"):
			seg["role"] = String(seg.get("role", ""))
		else:
			seg["role"] = _normalize_role(String(seg.get("role", "")))
		if not seg.has("notes"):
			seg["notes"] = int(seg.get("notes", 0))
		out.append(seg)
	return out


static func _coalesce_structure_timeline(timeline: Array) -> Array:
	var out: Array = []
	for raw in timeline:
		if not raw is Dictionary:
			continue
		var seg: Dictionary = (raw as Dictionary).duplicate(true)
		seg["role"] = _normalize_role(String(seg.get("role", "")))
		if out.is_empty():
			out.append(seg)
			continue
		var last: Dictionary = out[-1]
		var letter := section_letter(seg)
		var last_letter := section_letter(last)
		if letter != "" and letter == last_letter:
			last["end_s"] = maxf(float(last.get("end_s", 0.0)), float(seg.get("end_s", 0.0)))
			last["notes"] = int(last.get("notes", 0)) + int(seg.get("notes", 0))
			if String(last.get("role", "")).strip_edges() == "":
				last["role"] = String(seg.get("role", ""))
			# Merge auxiliary fields
			if seg.has("measures") and last.has("measures"):
				last["measures"] = int(last.get("measures", 0)) + int(seg.get("measures", 0))
			if seg.has("confidence") and last.has("confidence"):
				last["confidence"] = maxf(float(last.get("confidence", 0.0)), float(seg.get("confidence", 0.0)))
		else:
			out.append(seg)
	return out
