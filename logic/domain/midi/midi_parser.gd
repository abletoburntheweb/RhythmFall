# logic/domain/midi/midi_parser.gd
extends RefCounted
class_name MidiParser

# Minimal SMF parser for drum patterns MVP.
# Supports Format 0/1, PPQ division, single initial tempo, note_on/off, timeSig.
# Preserves leading offset, velocity and duration when present. No artificial defaults.

const DEFAULT_BPM := 120.0
const DEFAULT_PPQ := 480

static func parse_file(path: String) -> Dictionary:
	var abs_path := DirectoryUtils.to_absolute(path)
	if abs_path == "" or not FileAccess.file_exists(abs_path):
		return {"error": "file not found: %s" % path}
	var fa := FileAccess.open(abs_path, FileAccess.READ)
	if fa == null:
		return {"error": "cannot open: %s" % path}
	var data := fa.get_buffer(fa.get_length())
	fa.close()
	return parse_bytes(data)

static func parse_bytes(data: PackedByteArray) -> Dictionary:
	if data.size() < 14:
		return {"error": "too small for MThd"}
	if data[0] != 0x4D or data[1] != 0x54 or data[2] != 0x68 or data[3] != 0x64:
		return {"error": "missing MThd"}
	var header_len := _read_u32_be(data, 4)
	if header_len != 6:
		return {"error": "bad MThd len %d" % header_len}
	var fmt := _read_u16_be(data, 8)
	var n_tracks := _read_u16_be(data, 10)
	var division := _read_u16_be(data, 12)
	if division & 0x8000:
		return {"error": "SMPTE division not supported"}
	var ppq := int(division & 0x7FFF)
	if ppq == 0:
		ppq = DEFAULT_PPQ
	var bpm := DEFAULT_BPM
	var time_sig := "4/4"
	var tempo_us := 0
	var tracks_notes: Array = []
	var tracks_meta: Array = []
	var offset := 14
	var parsed_tracks := 0
	for ti in range(n_tracks):
		if offset + 8 > data.size():
			break
		if data[offset] != 0x4D or data[offset+1] != 0x54 or data[offset+2] != 0x72 or data[offset+3] != 0x6B:
			return {"error": "missing MTrk at %d" % offset}
		var trk_len := _read_u32_be(data, offset + 4)
		offset += 8
		if offset + trk_len > data.size():
			return {"error": "MTrk len exceeds file"}
		var trk_data := data.slice(offset, offset + trk_len)
		var res := _parse_track(trk_data, ti, ppq)
		if res.has("error"):
			return res
		tracks_meta.append({"name": res.get("name", ""), "channel_set": res.get("channel_set", {})})
		for n in res.get("notes", []):
			tracks_notes.append(n)
		if res.has("tempo_us") and tempo_us == 0 and int(res["tempo_us"]) > 0:
			tempo_us = int(res["tempo_us"])
			bpm = 60000000.0 / float(tempo_us)
		if res.has("time_sig") and time_sig == "4/4" and String(res["time_sig"]) != "":
			time_sig = String(res["time_sig"])
		offset += trk_len
		parsed_tracks += 1
	if parsed_tracks == 0 and n_tracks == 0:
		return {"error": "no tracks"}
	# Convert ticks to seconds using first tempo only (MVP)
	if tempo_us == 0:
		tempo_us = int(60000000.0 / bpm)
	var sec_per_tick := (float(tempo_us) / 1000000.0) / float(ppq)
	for n in tracks_notes:
		var tick := int(n.get("start_tick", 0))
		n["start_sec"] = float(tick) * sec_per_tick
		n["relTime"] = float(tick) * sec_per_tick
		var dur_tick := int(n.get("dur_ticks", 0))
		n["duration"] = float(dur_tick) * sec_per_tick
		n["relDuration"] = float(dur_tick) * sec_per_tick
	tracks_notes.sort_custom(func(a, b): return float(a.get("relTime", 0.0)) < float(b.get("relTime", 0.0)))
	var duration_sec := 0.0
	if not tracks_notes.is_empty():
		var last := tracks_notes[tracks_notes.size() - 1] as Dictionary
		duration_sec = float(last.get("relTime", 0.0)) + float(last.get("duration", 0.0))
	var leading_offset := 0.0
	if not tracks_notes.is_empty():
		leading_offset = float(tracks_notes[0].get("relTime", 0.0))
	return {
		"ppq": ppq,
		"format": fmt,
		"nTracks": n_tracks,
		"bpm": bpm,
		"tempo_us": tempo_us,
		"timeSig": time_sig,
		"notes": tracks_notes,
		"durationSec": duration_sec,
		"leadingOffset": leading_offset,
		"tracksMeta": tracks_meta,
		"error": "",
	}

static func _parse_track(data: PackedByteArray, track_idx: int, ppq: int) -> Dictionary:
	var pos := 0
	var abs_tick := 0
	var running_status := -1
	var notes: Array = []
	var tempo_us := 0
	var time_sig := ""
	var track_name := ""
	var channel_set := {}
	var pending_on: Dictionary = {}
	while pos < data.size():
		var delta_res := _read_vlq(data, pos)
		if delta_res.has("error"):
			return delta_res
		var delta: int = delta_res["value"]
		pos = int(delta_res["next_pos"])
		abs_tick += delta
		if pos >= data.size():
			break
		var status := int(data[pos])
		if status < 0x80:
			if running_status < 0:
				return {"error": "running status without previous at %d" % pos}
			status = running_status
		else:
			pos += 1
			if status != 0xFF and status != 0xF0 and status != 0xF7:
				running_status = status
			elif status == 0xFF:
				running_status = -1
		if status == 0xFF:
			if pos >= data.size():
				break
			var meta_type := int(data[pos])
			pos += 1
			var len_res := _read_vlq(data, pos)
			if len_res.has("error"):
				return len_res
			var mlen: int = len_res["value"]
			pos = int(len_res["next_pos"])
			if pos + mlen > data.size():
				return {"error": "meta len exceeds"}
			var mdata := data.slice(pos, pos + mlen)
			if meta_type == 0x51 and mlen == 3 and tempo_us == 0:
				tempo_us = (int(mdata[0]) << 16) | (int(mdata[1]) << 8) | int(mdata[2])
			elif meta_type == 0x58 and mlen >= 4 and time_sig == "":
				var nn := int(mdata[0])
				var dd_pow := int(mdata[1])
				var dd := 1 << dd_pow
				time_sig = "%d/%d" % [nn, dd]
			elif meta_type == 0x03:
				track_name = mdata.get_string_from_utf8()
			elif meta_type == 0x2F:
				pos += mlen
				break
			pos += mlen
		elif status == 0xF0 or status == 0xF7:
			var len_res2 := _read_vlq(data, pos)
			if len_res2.has("error"):
				return len_res2
			var slen: int = len_res2["value"]
			pos = int(len_res2["next_pos"]) + slen
		elif (status & 0xF0) == 0x90 or (status & 0xF0) == 0x80:
			if pos + 1 >= data.size():
				return {"error": "note data truncated"}
			var pitch := int(data[pos])
			var vel := int(data[pos + 1])
			pos += 2
			var ch := status & 0x0F
			channel_set[ch] = true
			var is_on := (status & 0xF0) == 0x90 and vel > 0
			var key := "%d:%d" % [ch, pitch]
			if is_on:
				if not pending_on.has(key):
					pending_on[key] = []
				var stack: Array = pending_on[key]
				stack.append({"pitch": pitch, "vel": vel, "start_tick": abs_tick, "channel": ch, "track": track_idx, "track_name": track_name})
			else:
				if pending_on.has(key):
					var stack2: Array = pending_on[key]
					if not stack2.is_empty():
						var on := stack2.pop_back() as Dictionary
						var dur := abs_tick - int(on.get("start_tick", 0))
						if dur < 0:
							dur = 0
						notes.append({
							"pitch": int(on.get("pitch", pitch)),
							"vel": int(on.get("vel", 0)),
							"start_tick": int(on.get("start_tick", 0)),
							"dur_ticks": dur,
							"channel": ch,
							"track": track_idx,
							"track_name": String(on.get("track_name", track_name)),
						})
						if stack2.is_empty():
							pending_on.erase(key)
		elif (status & 0xF0) == 0xC0 or (status & 0xF0) == 0xD0:
			if pos >= data.size():
				return {"error": "program/pressure truncated"}
			var ch2 := status & 0x0F
			channel_set[ch2] = true
			pos += 1
		elif (status & 0xF0) == 0xA0 or (status & 0xF0) == 0xB0 or (status & 0xF0) == 0xE0:
			if pos + 1 >= data.size():
				return {"error": "cc truncated"}
			var ch3 := status & 0x0F
			channel_set[ch3] = true
			pos += 2
		else:
			return {"error": "unknown status %02X at %d" % [status, pos]}
	return {"notes": notes, "tempo_us": tempo_us, "time_sig": time_sig, "name": track_name, "channel_set": channel_set}

static func _read_u16_be(data: PackedByteArray, off: int) -> int:
	return (int(data[off]) << 8) | int(data[off + 1])

static func _read_u32_be(data: PackedByteArray, off: int) -> int:
	return (int(data[off]) << 24) | (int(data[off + 1]) << 16) | (int(data[off + 2]) << 8) | int(data[off + 3])

static func _read_vlq(data: PackedByteArray, pos: int) -> Dictionary:
	var val := 0
	var p := pos
	var bytes_read := 0
	while p < data.size():
		var b := int(data[p])
		p += 1
		bytes_read += 1
		if bytes_read > 4:
			return {"error": "VLQ too long"}
		val = (val << 7) | (b & 0x7F)
		if (b & 0x80) == 0:
			return {"value": val, "next_pos": p}
	return {"error": "VLQ truncated"}
