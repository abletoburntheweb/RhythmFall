# logic/domain/charts/rfc_chart_codec.gd
extends RefCounted
class_name RfcChartCodec

const FORMAT_VERSION := 1
const BASS_SHAPES := ["tap", "hold", "slide"]
const BASS_SHAPE_ALIASES := {"sustain": "hold", "octave": "tap"}
const BASS_CURVES := ["linear", "bend", "gliss"]
const _GuitarHeroBindings = preload("res://logic/domain/controls/guitar_hero_bindings.gd")
const _GenerationIntents := preload("res://logic/domain/generation/generation_intents.gd")


static func notes_to_spawn_array(raw: Array) -> Array:
	var out: Array = []
	for item in raw:
		if not (item is Dictionary):
			continue
		var item_type := String(item.get("type", "DrumNote"))
		if item_type == "TrackInfo":
			continue
		if item_type.begins_with("Bass") or String(item.get("shape", "")) != "":
			if item_type == "BassSustainNote":
				item["type"] = "BassHoldNote"
				if not item.has("shape"):
					item["shape"] = "hold"
			elif item_type == "BassOctaveNote":
				item["type"] = "BassTapNote"
				if not item.has("shape"):
					item["shape"] = "tap"
			out.append(_bass_dict_to_spawn(item as Dictionary))
			continue
		var entry := {
			"lane": float(item.get("lane", 0)),
			"time": float(item.get("time", 0.0)),
			"type": "DrumNote",
		}
		var drum := String(item.get("drum", "")).strip_edges().to_lower()
		if drum != "":
			entry["drum"] = drum
		out.append(entry)
	out.sort_custom(func(a, b) -> bool:
		return float(a.get("time", 0.0)) < float(b.get("time", 0.0))
	)
	return out


static func _normalize_bass_shape(raw: String) -> String:
	var s := String(raw).strip_edges().to_lower()
	if BASS_SHAPE_ALIASES.has(s):
		s = String(BASS_SHAPE_ALIASES[s])
	return s if s in BASS_SHAPES else "tap"


static func _parse_lane_field(raw: String) -> Array:
	var text := String(raw).strip_edges()
	if text.contains(","):
		var lanes: Array = []
		for piece in text.split(","):
			if String(piece).strip_edges() != "":
				lanes.append(int(String(piece).strip_edges()))
		if lanes.is_empty():
			return [[0], 0.0]
		return [lanes, float(lanes[0])]
	var lane := int(text)
	return [[lane], float(lane)]


static func _bass_shape_to_type(shape: String) -> String:
	match _normalize_bass_shape(shape):
		"hold":
			return "BassHoldNote"
		"slide":
			return "BassSlideNote"
		_:
			return "BassTapNote"


static func _coerce_lanes_list(raw) -> Array:
	if raw == null:
		return []
	if raw is Array:
		var out: Array = []
		for v in raw:
			out.append(int(v))
		return out
	if raw is PackedInt32Array:
		var packed_i: Array = []
		for v in raw:
			packed_i.append(int(v))
		return packed_i
	if raw is PackedFloat32Array or raw is PackedFloat64Array:
		var packed_f: Array = []
		for v in raw:
			packed_f.append(int(v))
		return packed_f
	if raw is int or raw is float:
		return [int(raw)]
	if raw is String:
		var parsed := _parse_lane_field(String(raw))
		return parsed[0] as Array
	return []


static func _bass_lane_info(item: Dictionary) -> Array:
	var lanes_list := _coerce_lanes_list(item.get("lanes", null))
	if lanes_list.is_empty():
		return _parse_lane_field(str(item.get("lane", 0)))
	return [lanes_list, float(lanes_list[0])]


static func _bass_dict_to_spawn(item: Dictionary) -> Dictionary:
	var shape := _normalize_bass_shape(String(item.get("shape", "tap")))
	var lanes_info := _bass_lane_info(item)
	var entry := {
		"time": float(item.get("time", 0.0)),
		"type": _bass_shape_to_type(shape),
		"shape": shape,
		"ghost": bool(item.get("ghost", false)),
		"lane": lanes_info[1],
		"lanes": lanes_info[0],
	}
	if item.has("duration"):
		entry["duration"] = float(item.get("duration", 0.0))
	if item.has("end"):
		entry["end"] = float(item.get("end", 0.0))
	if item.has("lane_end"):
		entry["lane_end"] = float(item.get("lane_end", entry.get("lane", 0.0)))
	if shape == "slide":
		var curve := String(item.get("curve", "linear")).strip_edges().to_lower()
		entry["curve"] = curve if curve in BASS_CURVES else "linear"
	return entry


static func _parse_bool_flag(raw: String) -> bool:
	var v := String(raw).strip_edges().to_lower()
	return v in ["1", "true", "yes", "ghost"]


static func parse_header(text: String) -> Dictionary:
	var header := {}
	for raw_line in text.split("\n"):
		var line := String(raw_line).strip_edges()
		if line == "---":
			break
		if line.is_empty() or line.begins_with("#"):
			continue
		if not line.contains("="):
			continue
		var eq := line.find("=")
		header[line.substr(0, eq).strip_edges()] = line.substr(eq + 1).strip_edges()
	return header


static func _parse_bass_line(line: String) -> Dictionary:
	var parts := line.split(" ", false)
	if parts.size() < 2:
		parts = line.split("\t", false)
	if parts.size() < 2:
		return {}
	var t0 := float(parts[0])
	var lanes_info := _parse_lane_field(String(parts[1]))
	var lanes: Array = lanes_info[0]
	var primary_lane: float = lanes_info[1]
	var tail: Array = []
	for i in range(2, parts.size()):
		tail.append(String(parts[i]).strip_edges())
	var shape := "tap"
	var ghost := false
	var curve := "linear"
	var end_s := 0.0
	var lane_end := -1
	var floats: Array = []
	for token in tail:
		var low: String = String(token).to_lower()
		if _parse_bool_flag(token):
			ghost = true
		elif low in BASS_SHAPES or BASS_SHAPE_ALIASES.has(low):
			shape = _normalize_bass_shape(low)
		elif low in BASS_CURVES:
			curve = low
		elif token.is_valid_float():
			floats.append(float(token))
		elif token.is_valid_int():
			lane_end = int(token)
	if not floats.is_empty():
		end_s = floats[0]
		if floats.size() > 1 and lane_end < 0:
			lane_end = int(floats[1])
	var out := {
		"time": t0,
		"lane": primary_lane,
		"lanes": lanes,
		"shape": shape,
		"type": _bass_shape_to_type(shape),
		"ghost": ghost,
	}
	if shape in ["hold", "slide"] and end_s > 0.0:
		out["end"] = end_s
		out["duration"] = maxf(end_s - t0, 0.05)
	if shape == "slide":
		out["lane_end"] = float(lane_end if lane_end >= 0 else lanes[0])
		out["curve"] = curve
	return out


static func _sanitize_header_value(raw: String) -> String:
	return String(raw).strip_edges().replace("\n", " ").replace("\r", "")


static func _track_comment_line(artist: String, title: String) -> String:
	var a := _sanitize_header_value(artist)
	var t := _sanitize_header_value(title)
	if a != "" and t != "":
		return "# %s — %s" % [a, t]
	if t != "":
		return "# %s" % t
	if a != "":
		return "# %s" % a
	return ""


static func _serialize_bass_spawn_line(note: Dictionary) -> String:
	var t0 := float(note.get("time", 0.0))
	var shape := _normalize_bass_shape(String(note.get("shape", "tap")))
	var ghost := "1" if bool(note.get("ghost", false)) else ""
	var lanes_list := _coerce_lanes_list(note.get("lanes", null))
	if lanes_list.is_empty():
		lanes_list = [int(note.get("lane", 0))]
	var lane_cols := ",".join(lanes_list.map(func(v): return str(int(v))))
	var end_txt := ""
	var lane_end_txt := ""
	var curve_txt := ""
	if shape in ["hold", "slide"]:
		var end_s := float(note.get("end", 0.0))
		if end_s > 0.0:
			end_txt = "%7.4f" % end_s
	if shape == "slide":
		lane_end_txt = str(int(note.get("lane_end", lanes_list[0])))
		var curve := String(note.get("curve", "linear")).strip_edges().to_lower()
		curve_txt = curve if curve in BASS_CURVES else "linear"
	var line := "%9.4f  %s  %s  %s  %s  %s  %s" % [
		t0, lane_cols, end_txt, lane_end_txt, curve_txt, shape, ghost,
	]
	return line.strip_edges()


static func _serialize_bass(
	spawn: Array,
	mode: String,
	lanes: int,
	artist: String,
	title: String
) -> String:
	var a := _sanitize_header_value(artist)
	var t := _sanitize_header_value(title)
	var lines: PackedStringArray = PackedStringArray([
		"# RFC %d" % FORMAT_VERSION,
		"# RhythmFall chart",
	])
	var track_line := _track_comment_line(a, t)
	if track_line != "":
		lines.append(track_line)
	lines.append("")
	if a != "":
		lines.append("artist=%s" % a)
	if t != "":
		lines.append("title=%s" % t)
	var intent_key := String(mode).strip_edges().to_lower()
	if intent_key == "":
		intent_key = "original"
	lines.append_array([
		"instrument=bass",
		"intent=%s" % intent_key,
		"lanes=%d" % lanes,
		"notes=%d" % spawn.size(),
		"",
		"---",
		"# time(s)   lane   end(s)   lane_end   curve   shape   ghost",
	])
	for note in spawn:
		if note is Dictionary:
			lines.append(_serialize_bass_spawn_line(note))
	return "\n".join(lines) + "\n"


static func serialize(
	notes: Array,
	instrument: String = "drums",
	mode: String = "basic",
	lanes: int = 4,
	artist: String = "",
	title: String = ""
) -> String:
	var spawn := notes_to_spawn_array(notes)
	if instrument.to_lower() == "bass":
		return _serialize_bass(spawn, mode, lanes, artist, title)
	var a := _sanitize_header_value(artist)
	var t := _sanitize_header_value(title)
	var lines: PackedStringArray = PackedStringArray([
		"# RFC %d" % FORMAT_VERSION,
		"# RhythmFall chart",
	])
	var track_line := _track_comment_line(a, t)
	if track_line != "":
		lines.append(track_line)
	lines.append("")
	if a != "":
		lines.append("artist=%s" % a)
	if t != "":
		lines.append("title=%s" % t)
	var intent_key := String(mode).strip_edges().to_lower()
	if intent_key == "":
		intent_key = "groove"
	lines.append_array([
		"instrument=%s" % instrument.to_lower(),
		"intent=%s" % intent_key,
		"lanes=%d" % lanes,
		"notes=%d" % spawn.size(),
		"",
		"---",
	])
	var has_drum := false
	for note in spawn:
		if note.has("drum") and String(note.get("drum", "")) != "":
			has_drum = true
			break
	if has_drum:
		lines.append("# time(s)   lane   drum")
	else:
		lines.append("# time(s)   lane")
	for note in spawn:
		var note_time := float(note.get("time", 0.0))
		var lane := int(note.get("lane", 0))
		if has_drum:
			var drum := String(note.get("drum", "")).strip_edges().to_lower()
			if drum != "":
				lines.append("%9.4f  %d  %s" % [note_time, lane, drum])
			else:
				lines.append("%9.4f  %d" % [note_time, lane])
		else:
			lines.append("%9.4f  %d" % [note_time, lane])
	return "\n".join(lines) + "\n"


static func parse(text: String) -> Array:
	var instrument := String(parse_header(text).get("instrument", "drums")).strip_edges().to_lower()
	if instrument == "bass":
		return _parse_bass_body(text)
	return _parse_drums_body(text)


static func _parse_drums_body(text: String) -> Array:
	var out: Array = []
	var in_body := false
	for raw_line in text.split("\n"):
		var line := String(raw_line).strip_edges()
		if line.is_empty():
			continue
		if line == "---":
			in_body = true
			continue
		if not in_body or line.begins_with("#"):
			continue
		var parts := line.split(" ", false)
		if parts.size() < 2:
			parts = line.split("\t", false)
		if parts.size() < 2:
			continue
		var t := float(parts[0])
		var lane := int(parts[1])
		var entry := {"lane": float(lane), "time": t, "type": "DrumNote"}
		if parts.size() >= 3:
			var drum := String(parts[2]).strip_edges().to_lower()
			if drum != "":
				entry["drum"] = drum
		out.append(entry)
	out.sort_custom(func(a, b) -> bool:
		return float(a.get("time", 0.0)) < float(b.get("time", 0.0))
	)
	return out


static func _parse_bass_body(text: String) -> Array:
	var out: Array = []
	var in_body := false
	for raw_line in text.split("\n"):
		var line := String(raw_line).strip_edges()
		if line.is_empty():
			continue
		if line == "---":
			in_body = true
			continue
		if not in_body or line.begins_with("#"):
			continue
		var entry := _parse_bass_line(line)
		if not entry.is_empty():
			out.append(entry)
	out.sort_custom(func(a, b) -> bool:
		return float(a.get("time", 0.0)) < float(b.get("time", 0.0))
	)
	return out


static func read_header_intent(path: String, fallback: String = "groove") -> String:
	var abs := DirectoryUtils.to_absolute(path)
	if abs.is_empty() or not FileAccess.file_exists(abs):
		return fallback
	var text := _read_text(abs)
	if text == "":
		return fallback
	for raw_line in text.split("\n"):
		var line := String(raw_line).strip_edges()
		if line.begins_with("intent="):
			var intent := line.substr(7).strip_edges().to_lower()
			return intent if intent != "" else fallback
		if line.begins_with("mode="):
			var legacy := line.substr(5).strip_edges().to_lower()
			if legacy != "":
				return _GenerationIntents.migrate_legacy_mode(legacy)
	return fallback


static func read_header_lanes(path: String, fallback: int = 4) -> int:
	var abs := DirectoryUtils.to_absolute(path)
	if abs.is_empty() or not FileAccess.file_exists(abs):
		return fallback
	var text := _read_text(abs)
	if text == "":
		return fallback
	for raw_line in text.split("\n"):
		var line := String(raw_line).strip_edges()
		if line.begins_with("lanes="):
			return clampi(int(line.substr(6)), 3, 5)
	return fallback


static func read_file(path: String) -> Array:
	var abs := DirectoryUtils.to_absolute(path)
	if abs.is_empty() or not FileAccess.file_exists(abs):
		return []
	if abs.ends_with(".json") or abs.ends_with(".json.gz"):
		push_warning("RfcChartCodec: legacy JSON charts are no longer loaded: %s" % abs)
		return []
	var text := _read_text(abs)
	if text == "":
		return []
	return parse(text)


static func write_file(
	path: String,
	notes: Array,
	instrument: String,
	mode: String,
	lanes: int,
	artist: String = "",
	title: String = ""
) -> bool:
	var body := serialize(notes, instrument, mode, lanes, artist, title)
	return _write_text_atomic(path, body)


static func _read_text(path: String) -> String:
	if path.ends_with(".gz"):
		var fa_c := FileAccess.open_compressed(path, FileAccess.READ, FileAccess.COMPRESSION_GZIP)
		if not fa_c:
			return ""
		var text := fa_c.get_as_text()
		fa_c.close()
		return text
	var fa := FileAccess.open(path, FileAccess.READ)
	if not fa:
		return ""
	var text_plain := fa.get_as_text()
	fa.close()
	return text_plain


static func _write_text_atomic(path: String, text: String) -> bool:
	var abs_path := DirectoryUtils.to_absolute(path)
	if abs_path.is_empty():
		return false
	if not DirectoryUtils.ensure_dir_for_file(abs_path):
		return false
	var tmp_path := "%s.tmp" % abs_path
	var ok := false
	if abs_path.ends_with(".gz"):
		var fa_c := FileAccess.open_compressed(tmp_path, FileAccess.WRITE, FileAccess.COMPRESSION_GZIP)
		if fa_c == null:
			return false
		fa_c.store_string(text)
		fa_c.close()
		ok = true
	else:
		var fa := FileAccess.open(tmp_path, FileAccess.WRITE)
		if fa == null:
			push_warning("RfcChartCodec: cannot write temp file: %s (err %s)" % [tmp_path, FileAccess.get_open_error()])
			return false
		fa.store_string(text)
		fa.close()
		ok = true
	if not ok:
		return false
	if FileAccess.file_exists(abs_path):
		var bak_path := "%s.bak" % abs_path
		if FileAccess.file_exists(bak_path):
			DirAccess.remove_absolute(bak_path)
		if DirAccess.rename_absolute(abs_path, bak_path) != OK:
			DirAccess.remove_absolute(tmp_path)
			return false
	if DirAccess.rename_absolute(tmp_path, abs_path) == OK:
		var bak_done := "%s.bak" % abs_path
		if FileAccess.file_exists(bak_done):
			DirAccess.remove_absolute(bak_done)
		return true
	# Windows / custom folders: rename can fail while tmp write succeeded — copy fallback
	var rf := FileAccess.open(tmp_path, FileAccess.READ)
	if rf == null:
		var bak := "%s.bak" % abs_path
		if FileAccess.file_exists(bak):
			DirAccess.rename_absolute(bak, abs_path)
		return false
	var data := rf.get_buffer(rf.get_length())
	rf.close()
	var wf := FileAccess.open(abs_path, FileAccess.WRITE)
	if wf == null:
		push_warning("RfcChartCodec: cannot write chart file: %s (err %s)" % [abs_path, FileAccess.get_open_error()])
		var bak := "%s.bak" % abs_path
		if FileAccess.file_exists(bak):
			DirAccess.rename_absolute(bak, abs_path)
		DirAccess.remove_absolute(tmp_path)
		return false
	wf.store_buffer(data)
	wf.close()
	DirAccess.remove_absolute(tmp_path)
	var bak_restore := "%s.bak" % abs_path
	if FileAccess.file_exists(bak_restore):
		DirAccess.remove_absolute(bak_restore)
	return true
