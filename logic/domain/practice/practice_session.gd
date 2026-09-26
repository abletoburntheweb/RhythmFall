# logic/domain/practice/practice_session.gd
class_name PracticeSession
extends RefCounted

# A PracticeSession owns the loop state for one active practice run: the
# selected continuous section range, the live current-attempt counters and the
# accumulated bests. It does NOT own persistence (see PracticeBestsStore).

var active := false

var sections: Array = []
var section_start := -1
var section_end := -1
var start_s := 0.0
var end_s := 0.0

# Current attempt live counters.
var attempt_hits := 0
var attempt_misses := 0
var attempt_combo := 0
var attempt_max_combo := 0

# Completed full cycles + bests achieved inside this session.
var attempts := 0
var best_accuracy := 0.0
var best_combo := 0

# Session-wide cumulative counters (across every completed cycle + the live
# in-progress cycle). These are what the Practice HUD shows; they are NOT reset
# between cycles and DO reset when a new Practice Session starts.
var session_hits := 0
var session_misses := 0
var session_max_combo := 0


func configure(segments: Array, start_idx: int, end_idx: int) -> void:
	sections = segments.duplicate(true) if segments is Array else []
	if sections.is_empty():
		active = false
		return
	var a := clampi(start_idx, 0, sections.size() - 1)
	var b := clampi(end_idx, 0, sections.size() - 1)
	if b < a:
		var t := a
		a = b
		b = t
	section_start = a
	section_end = b
	var first: Dictionary = sections[a] if sections[a] is Dictionary else {}
	var last: Dictionary = sections[b] if sections[b] is Dictionary else {}
	start_s = maxf(0.0, float(first.get("start_s", 0.0)))
	end_s = maxf(start_s, float(last.get("end_s", first.get("end_s", start_s))))
	active = true
	attempts = 0
	best_accuracy = 0.0
	best_combo = 0
	session_hits = 0
	session_misses = 0
	session_max_combo = 0
	start_attempt()


func start_attempt() -> void:
	attempt_hits = 0
	attempt_misses = 0
	attempt_combo = 0
	attempt_max_combo = 0


func record_hit() -> void:
	attempt_hits += 1
	attempt_combo += 1
	attempt_max_combo = maxi(attempt_max_combo, attempt_combo)


func record_miss() -> void:
	attempt_misses += 1
	attempt_combo = 0


func attempt_accuracy() -> float:
	var played := attempt_hits + attempt_misses
	if played <= 0:
		return 100.0
	return clampf(float(attempt_hits) / float(played) * 100.0, 0.0, 100.0)


func session_total_hits() -> int:
	return session_hits + attempt_hits


func session_total_misses() -> int:
	return session_misses + attempt_misses


func session_max_combo_display() -> int:
	return maxi(session_max_combo, attempt_max_combo)


func session_accuracy() -> float:
	var played := session_total_hits() + session_total_misses()
	if played <= 0:
		return 100.0
	return clampf(float(session_total_hits()) / float(played) * 100.0, 0.0, 100.0)


## Finishes the current cycle. Rolls the attempt into the session-wide counters,
## updates the in-session bests and returns a Dictionary describing the completed
## attempt (accuracy, max_combo, misses) or an empty Dictionary if no notes were
## judged at all (the attempt is not counted then either). The session counters
## are intentionally left intact so the HUD keeps cumulative values.
func complete_attempt() -> Dictionary:
	var played := attempt_hits + attempt_misses
	var acc := attempt_accuracy()
	var max_combo := attempt_max_combo
	attempts += 1
	if acc > best_accuracy or (is_equal_approx(acc, best_accuracy) and max_combo > best_combo):
		best_accuracy = acc
		best_combo = max_combo
	session_hits += attempt_hits
	session_misses += attempt_misses
	session_max_combo = maxi(session_max_combo, attempt_max_combo)
	var result := {
		"accuracy": acc,
		"max_combo": max_combo,
		"misses": attempt_misses,
		"hits": attempt_hits,
		"played": played,
	}
	start_attempt()
	return result


func section_label(index: int) -> String:
	if index < 0 or index >= sections.size():
		return ""
	var seg: Dictionary = sections[index] if sections[index] is Dictionary else {}
	var result := RhythmDnaView.format_section_headline(seg)
	if ProjectSettings.get_setting("debug/verbose_rhythm_dna", false):
		push_warning("RNA: practice_section_label index=%s block=%s role=%s label_key=%s result=%s" % [
		index,
		seg.get("block", "none"),
		seg.get("role", "none"),
		seg.get("label_key", "none"),
		result
		])
	return result


func section_at_time(t: float) -> int:
	for i in range(sections.size()):
		var seg: Dictionary = sections[i] if sections[i] is Dictionary else {}
		var start := float(seg.get("start_s", 0.0))
		var end := float(seg.get("end_s", start))
		if t >= start and t < end:
			return i
	return -1