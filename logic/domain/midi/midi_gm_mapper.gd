# logic/domain/midi/midi_gm_mapper.gd
extends RefCounted
class_name MidiGmMapper

# GM drum mapping for present pitches only. No artificial 128 table.

const DEFAULT_GM: Dictionary = {
	35: "kick",
	36: "kick",
	37: "snare",
	38: "snare",
	40: "snare",
	39: "snare",
	42: "hat",
	44: "hat",
	46: "hat",
	41: "tom",
	43: "tom",
	45: "tom",
	47: "tom",
	48: "tom",
	50: "tom",
	49: "cymbal",
	51: "cymbal",
	52: "cymbal",
	53: "cymbal",
	55: "cymbal",
	57: "cymbal",
	59: "cymbal",
	56: "perc",
	58: "perc",
}

const DRUM_TO_LANE: Dictionary = {
	"kick": 0,
	"snare": 1,
	"hat": 2,
	"tom": 3,
	"cymbal": 4,
	"perc": 4,
}

static func is_pitch_drum(pitch: int) -> bool:
	return DEFAULT_GM.has(int(pitch))

static func drum_for_pitch(pitch: int, custom_map: Dictionary = {}) -> String:
	var p := int(pitch)
	if custom_map.has(p):
		var c := String(custom_map[p]).strip_edges().to_lower()
		if c in ["kick", "snare", "hat", "tom", "cymbal", "perc"]:
			return c
	if DEFAULT_GM.has(p):
		return String(DEFAULT_GM[p])
	return ""

static func lane_for_drum(drum: String, lanes: int = 5) -> int:
	var d := drum.strip_edges().to_lower()
	if DRUM_TO_LANE.has(d):
		var l := int(DRUM_TO_LANE[d])
		return clampi(l, 0, maxi(0, lanes - 1))
	return 0

static func lane_for_pitch(pitch: int, lanes: int = 5, custom_map: Dictionary = {}) -> int:
	var drum := drum_for_pitch(pitch, custom_map)
	if drum == "":
		return -1
	return lane_for_drum(drum, lanes)

static func pitches_in_notes(notes: Array) -> Array[int]:
	var seen: Dictionary = {}
	for n in notes:
		if n is Dictionary and n.has("pitch"):
			seen[int(n.get("pitch"))] = true
	var out: Array[int] = []
	for k in seen.keys():
		out.append(int(k))
	out.sort()
	return out

static func default_map_for_pitches(pitches: Array) -> Dictionary:
	var out: Dictionary = {}
	for p in pitches:
		var pi := int(p)
		if DEFAULT_GM.has(pi):
			out[pi] = String(DEFAULT_GM[pi])
	return out

static func present_pitches_map(notes: Array, custom_map: Dictionary = {}) -> Dictionary:
	var pitches := pitches_in_notes(notes)
	var out: Dictionary = {}
	for pi in pitches:
		var drum := drum_for_pitch(pi, custom_map)
		if drum != "":
			out[pi] = drum
	return out

static func build_mapping_for_notes(notes: Array) -> Dictionary:
	return present_pitches_map(notes, {})

static func validate_custom_map_for_present(custom_map: Dictionary, present_pitches: Array) -> Dictionary:
	var out: Dictionary = {}
	var present_set: Dictionary = {}
	for p in present_pitches:
		present_set[int(p)] = true
	for k in custom_map.keys():
		var pi := int(k)
		if not present_set.has(pi):
			continue
		var drum := String(custom_map[k]).strip_edges().to_lower()
		if drum in ["kick", "snare", "hat", "tom", "cymbal", "perc"]:
			out[pi] = drum
	return out
