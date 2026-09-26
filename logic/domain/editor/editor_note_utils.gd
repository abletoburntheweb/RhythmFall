# logic/domain/editor/editor_note_utils.gd
extends RefCounted
class_name EditorNoteUtils

# Canonical drum palette — single source for color + validation.
const DRUM_TYPES: Array[String] = ["kick", "snare", "hat", "tom", "cymbal", "perc"]
const DRUM_COLORS := {
	"kick": Color(0.35, 0.55, 1.0, 1.0),
	"snare": Color(0.35, 0.85, 0.45, 1.0),
	"hat": Color(0.95, 0.85, 0.25, 1.0),
	"tom": Color(0.95, 0.55, 0.20, 1.0),
	"cymbal": Color(0.85, 0.45, 0.95, 1.0),
	"perc": Color(0.65, 0.68, 0.75, 1.0),
}

const NOTE_TYPE := "DrumNote"
const TIME_EPSILON := 1e-5
const TIME_PRECISION := 4 # RFC %.4f

# Mirrors RfcChartCodec notes_to_spawn_array validation.
static func make_note(time: float, lane: int, drum: String, lanes: int = 5) -> Dictionary:
	var d := drum.strip_edges().to_lower()
	if d not in DRUM_TYPES:
		d = "kick"
	var clamped_lane := clampi(lane, 0, maxi(1, lanes) - 1)
	return {
		"type": NOTE_TYPE,
		"lane": float(clamped_lane),
		"time": snappedf(time, 0.0001) if time >= 0.0 else 0.0,
		"drum": d,
	}

static func clone_note(n: Dictionary) -> Dictionary:
	return n.duplicate(true)

static func clone_notes(arr: Array) -> Array:
	var out: Array = []
	for item in arr:
		if item is Dictionary:
			out.append((item as Dictionary).duplicate(true))
	return out

static func sort_by_time(arr: Array) -> Array:
	var copy := arr.duplicate()
	copy.sort_custom(func(a, b) -> bool:
		return float(a.get("time", 0.0)) < float(b.get("time", 0.0))
	)
	return copy

static func note_key(n: Dictionary) -> String:
	# For diff/selection — matches note_manager._live_note_key precision.
	return "%0.5f|%d|%s" % [float(n.get("time", 0.0)), int(n.get("lane", 0)), String(n.get("drum", "kick")).to_lower()]

static func stable_id(n: Dictionary, index: int) -> String:
	# Stable id for duplicate time+lane+drum collisions (includes original index).
	return "%s#%d" % [note_key(n), index]

static func sanitize_time(t: float) -> float:
	if t < 0.0:
		return 0.0
	return snappedf(t, 0.0001)

static func sanitize_lane(lane: int, lanes: int) -> int:
	return clampi(lane, 0, maxi(1, lanes) - 1)

static func sanitize_drum(drum: String) -> String:
	var d := drum.strip_edges().to_lower()
	return d if d in DRUM_TYPES else "kick"

static func color_for_drum(drum: String) -> Color:
	var d := drum.strip_edges().to_lower()
	return DRUM_COLORS.get(d, DRUM_COLORS["perc"])

static func validate_notes(arr: Array, lanes: int, duration: float) -> Array[String]:
	var errs: Array[String] = []
	for i in range(arr.size()):
		var n: Dictionary = arr[i] if arr[i] is Dictionary else {}
		var t := float(n.get("time", -1.0))
		var lane := int(n.get("lane", -1))
		var drum := String(n.get("drum", "")).to_lower()
		if t < -TIME_EPSILON or (duration > 0.0 and t > duration + TIME_EPSILON):
			errs.append("note %d time %.4f out of range" % [i, t])
		if lane < 0 or lane >= lanes:
			errs.append("note %d lane %d out of 0..%d" % [i, lane, lanes - 1])
		if drum not in DRUM_TYPES:
			errs.append("note %d drum '%s' invalid" % [i, drum])
	return errs

static func dedupe_same_lane_time(arr: Array, eps: float = TIME_EPSILON) -> Array:
	if arr.is_empty():
		return arr
	var sorted := sort_by_time(arr)
	var out: Array = []
	var last_by_lane: Dictionary = {}
	for n in sorted:
		var lane := int(n.get("lane", 0))
		var t := float(n.get("time", 0.0))
		var prev = last_by_lane.get(lane, null)
		if prev != null and absf(t - float(prev)) <= eps:
			continue
		last_by_lane[lane] = t
		out.append(n)
	return out
