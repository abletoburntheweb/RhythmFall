class_name ProfileInstrumentStats
extends RefCounted

const STAT_SPECS: Array = [
	["levels", "PROFILE_STAT_INSTR_LEVELS"],
	["score", "PROFILE_STAT_INSTR_SCORE"],
	["avg_acc", "PROFILE_STAT_INSTR_AVG_ACC"],
	["sessions", "PROFILE_STAT_INSTR_SESSIONS"],
	["perfect", "PROFILE_STAT_INSTR_PERFECT"],
	["combo", "PROFILE_STAT_INSTR_COMBO"],
	["hits", "PROFILE_STAT_INSTR_HITS"],
	["misses", "PROFILE_STAT_INSTR_MISSES"],
]

const INSTRUMENT_SPECS := {
	"drums": {
		"title_key": "GEN_INST_DRUMS",
		"subtitle_key": "PROFILE_STAT_INSTR_DRUMS_SUB",
		"icon": "drum.svg",
		"accent": Color(0.38039216, 0.78039217, 0.7411765, 1.0),
		"accent_light": Color(0.42039216, 0.84039217, 0.8011765, 1.0),
	},
	"bass": {
		"title_key": "GEN_INST_BASS",
		"subtitle_key": "PROFILE_STAT_INSTR_BASS_SUB",
		"icon": "guitar.svg",
		"accent": Color(0.4509804, 0.61960787, 0.92156863, 1.0),
		"accent_light": Color(0.4909804, 0.67960787, 0.98156863, 1.0),
	},
}

const COMBO_COLOR := Color(0.9490196, 0.7019608, 0.3529412, 1.0)
const MISS_COLOR := Color(0.8980392, 0.4509804, 0.4509804, 1.0)
const ACC_COLOR := Color(0.62, 0.86, 0.72, 1.0)


static func drums_summary(history: Array = []) -> Dictionary:
	if PlayerDataManager == null:
		return _empty_summary()
	var data: Dictionary = PlayerDataManager.data
	var derived := _history_derived("drums", history)
	return {
		"levels": int(data.get("drum_levels_completed", 0)),
		"perfect": int(data.get("total_drum_perfect_hits", 0)),
		"combo": int(data.get("max_drum_combo_ever", 0)),
		"score": int(data.get("total_drum_score_ever", 0)),
		"hits": int(data.get("total_drum_hits", 0)),
		"misses": int(data.get("total_drum_misses", 0)),
		"sessions": int(derived.get("sessions", 0)),
		"avg_acc": float(derived.get("avg_acc", 0.0)),
	}


static func bass_summary(history: Array) -> Dictionary:
	if PlayerDataManager == null:
		return _empty_summary()
	var data: Dictionary = PlayerDataManager.data
	var derived := _history_derived("bass", history)
	var score_total := int(derived.get("score", 0))
	if score_total <= 0:
		for session in history:
			if not (session is Dictionary):
				continue
			if not _is_bass_session(session as Dictionary):
				continue
			score_total += int((session as Dictionary).get("score", 0))
	return {
		"levels": int(data.get("bass_levels_completed", 0)),
		"perfect": int(data.get("total_bass_perfect_hits", 0)),
		"combo": int(data.get("max_bass_combo_ever", 0)),
		"score": score_total,
		"hits": int(derived.get("hits", 0)),
		"misses": int(derived.get("misses", 0)),
		"sessions": int(derived.get("sessions", 0)),
		"avg_acc": float(derived.get("avg_acc", 0.0)),
	}


static func instrument_ids() -> Array[String]:
	return ["drums", "bass"]


static func instrument_spec(instrument_id: String) -> Dictionary:
	return INSTRUMENT_SPECS.get(instrument_id, {}) as Dictionary


static func stat_rows(instrument_id: String, summary: Dictionary) -> Array[Dictionary]:
	var spec: Dictionary = instrument_spec(instrument_id)
	var accent: Color = spec.get("accent", Color.WHITE)
	var accent_light: Color = spec.get("accent_light", accent.lightened(0.08))
	var rows: Array[Dictionary] = []
	for entry in STAT_SPECS:
		var key := str(entry[0])
		var locale_key := str(entry[1])
		var value_color := accent
		var value := ""
		match key:
			"perfect":
				value_color = accent_light
				value = str(int(summary.get(key, 0)))
			"combo":
				value_color = COMBO_COLOR
				value = str(int(summary.get(key, 0)))
			"score", "levels":
				value_color = accent_light if key == "levels" else accent
				value = str(int(summary.get(key, 0)))
			"misses":
				value_color = MISS_COLOR
				value = str(int(summary.get(key, 0)))
			"hits", "sessions":
				value = str(int(summary.get(key, 0)))
			"avg_acc":
				value_color = ACC_COLOR
				value = "%.1f" % float(summary.get(key, 0.0))
			_:
				value = str(int(summary.get(key, 0)))
		rows.append({
			"key": key,
			"label_key": locale_key,
			"value": value,
			"value_color": value_color,
		})
	return rows


static func _empty_summary() -> Dictionary:
	return {
		"levels": 0,
		"perfect": 0,
		"combo": 0,
		"score": 0,
		"hits": 0,
		"misses": 0,
		"sessions": 0,
		"avg_acc": 0.0,
	}


static func _history_derived(instrument_id: String, history: Array) -> Dictionary:
	var sessions := 0
	var acc_sum := 0.0
	var acc_n := 0
	var score := 0
	var hits := 0
	var misses := 0
	for session in history:
		if not (session is Dictionary):
			continue
		var s := session as Dictionary
		if not _matches_instrument(s, instrument_id):
			continue
		sessions += 1
		score += int(s.get("score", 0))
		hits += int(s.get("notes_hit", s.get("hits", 0)))
		misses += int(s.get("notes_missed", s.get("misses", 0)))
		if s.has("accuracy"):
			acc_sum += float(s.get("accuracy", 0.0))
			acc_n += 1
	var avg_acc := 0.0
	if acc_n > 0:
		avg_acc = acc_sum / float(acc_n)
	elif hits + misses > 0:
		avg_acc = 100.0 * float(hits) / float(hits + misses)
	return {
		"sessions": sessions,
		"avg_acc": avg_acc,
		"score": score,
		"hits": hits,
		"misses": misses,
	}


static func _matches_instrument(session: Dictionary, instrument_id: String) -> bool:
	if instrument_id == "bass":
		return _is_bass_session(session)
	# drums / percussion / empty / legacy labels
	var instrument := str(session.get("instrument", "")).strip_edges().to_lower()
	if instrument == "":
		return true
	return instrument in ["drums", "drum", "percussion", "перкуссия", "standard"]


static func _is_bass_session(session: Dictionary) -> bool:
	var instrument := str(session.get("instrument", "")).strip_edges().to_lower()
	return instrument in ["bass", "бас"]
