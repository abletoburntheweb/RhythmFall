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
