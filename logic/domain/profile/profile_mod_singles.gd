# logic/domain/profile/profile_mod_singles.gd
## Per-mod singles for History «Прохождения по модам» highlight row.
## Each slot shows one mod + one metric; slots never share a mod.
class_name ProfileModSingles
extends RefCounted

const _RunModifiers = preload("res://logic/domain/modifiers/run_modifiers.gd")
const _RhythmRating = preload("res://logic/domain/rhythm/rhythm_rating.gd")

const PER_MOD_KEY := "per_mod"
const SS_RATE_MIN_CLEARS := 3

## Slot order = priority for unique-mod conflict resolution.
const HIGHLIGHT_SPECS: Array = [
	["score", "PROFILE_MOD_SINGLE_SCORE"],
	["rr", "PROFILE_MOD_SINGLE_RR"],
	["accuracy", "PROFILE_MOD_SINGLE_ACCURACY"],
	["hardest_chart", "PROFILE_MOD_SINGLE_HARDEST_CHART"],
	["ss_rate", "PROFILE_MOD_SINGLE_SS_RATE"],
]


static func update_from_run(mod_records: Dictionary, run: Dictionary, modifiers: Array, run_rr: int = -1) -> void:
	if _RunModifiers.has_modifier(modifiers, _RunModifiers.ID_AUTOPLAY):
		return
	var mods := _RunModifiers.sanitize(modifiers)
	var countable: Array[String] = []
	for mod_id in mods:
		var mid := str(mod_id)
		if mid == "" or mid == _RunModifiers.ID_AUTOPLAY:
			continue
		if not countable.has(mid):
			countable.append(mid)
	if countable.is_empty():
		return

	var score := int(run.get("score", 0))
	var accuracy := float(run.get("accuracy", 0.0))
	var grade := str(run.get("grade", "")).strip_edges().to_upper()
	var is_ss := grade == "SS"
	var chart_rating := float(run.get("chart_rating", 0.0))
	if chart_rating <= 0.0:
		chart_rating = float(_RhythmRating.resolve_chart_rating(
			str(run.get("song_path", "")),
			str(run.get("instrument", "standard")),
			str(run.get("mode", "basic")),
			int(run.get("lanes", 4))
		))
	var rr := run_rr
	if rr < 0:
		rr = _RhythmRating.compute(
			accuracy,
			int(round(chart_rating)),
			grade,
			bool(run.get("full_combo", false)),
			modifiers
		)

	var per_mod: Dictionary = mod_records.get(PER_MOD_KEY, {}) if mod_records.get(PER_MOD_KEY) is Dictionary else {}
	for mid in countable:
		var entry: Dictionary = per_mod.get(mid, {}) if per_mod.get(mid) is Dictionary else {}
		entry["clears"] = int(entry.get("clears", 0)) + 1
		if is_ss:
			entry["ss_clears"] = int(entry.get("ss_clears", 0)) + 1
		if score > int(entry.get("best_score", 0)):
			entry["best_score"] = score
		if rr > int(entry.get("best_rr", 0)):
			entry["best_rr"] = rr
		if accuracy > float(entry.get("best_accuracy", 0.0)):
			entry["best_accuracy"] = accuracy
		if chart_rating > float(entry.get("hardest_chart_rating", 0.0)):
			entry["hardest_chart_rating"] = chart_rating
		per_mod[mid] = entry
	mod_records[PER_MOD_KEY] = per_mod


static func per_mod_map(mod_records: Variant) -> Dictionary:
	if not mod_records is Dictionary:
		return {}
	var raw: Variant = (mod_records as Dictionary).get(PER_MOD_KEY, {})
	return raw if raw is Dictionary else {}


static func ss_rate(entry: Dictionary) -> float:
	var clears := int(entry.get("clears", 0))
	if clears <= 0:
		return 0.0
	return float(int(entry.get("ss_clears", 0))) * 100.0 / float(clears)


static func highlight_slots(mod_records: Variant, limit: int = 5) -> Array[Dictionary]:
	var per_mod := per_mod_map(mod_records)
	if per_mod.is_empty():
		return []
	var used: Dictionary = {}
	var out: Array[Dictionary] = []
	for spec in HIGHLIGHT_SPECS:
		if out.size() >= limit:
			break
		var metric := str(spec[0])
		var caption_key := str(spec[1])
		var pick := _best_unused(per_mod, used, metric)
		if pick.is_empty():
			continue
		var mod_id := str(pick.get("mod_id", ""))
		if mod_id == "":
			continue
		used[mod_id] = true
		out.append({
			"metric": metric,
			"caption_key": caption_key,
			"mod_id": mod_id,
			"value": pick.get("value"),
			"value_text": str(pick.get("value_text", "")),
			"clears": int(pick.get("clears", 0)),
		})
	return out


static func _best_unused(per_mod: Dictionary, used: Dictionary, metric: String) -> Dictionary:
	var best_id := ""
	var best_primary := -INF
	var best_tie := -INF
	var best_entry: Dictionary = {}
	for mod_id_raw in per_mod.keys():
		var mod_id := str(mod_id_raw)
		if mod_id == "" or used.has(mod_id):
			continue
		var entry: Dictionary = per_mod[mod_id_raw] if per_mod[mod_id_raw] is Dictionary else {}
		var clears := int(entry.get("clears", 0))
		if clears <= 0:
			continue
		var primary := 0.0
		var tie := float(clears)
		var value_text := ""
		var value: Variant = null
		match metric:
			"score":
				primary = float(int(entry.get("best_score", 0)))
				if primary <= 0.0:
					continue
				value = int(primary)
				value_text = str(int(primary))
			"rr":
				primary = float(int(entry.get("best_rr", 0)))
				if primary <= 0.0:
					continue
				value = int(primary)
				value_text = "%d RR" % int(primary)
			"accuracy":
				primary = float(entry.get("best_accuracy", 0.0))
				if primary <= 0.0:
					continue
				value = primary
				value_text = "%.1f%%" % primary
			"hardest_chart":
				primary = float(entry.get("hardest_chart_rating", 0.0))
				if primary <= 0.0:
					continue
				value = primary
				value_text = "%.1f" % primary
			"ss_rate":
				if clears < SS_RATE_MIN_CLEARS:
					continue
				primary = ss_rate(entry)
				# Need at least one SS so the slot isn't "0% leader".
				if primary <= 0.0:
					continue
				value = primary
				value_text = "%.0f%%" % primary
				tie = primary * 1000.0 + float(clears)
			_:
				continue
		if primary > best_primary + 0.0001 or (is_equal_approx(primary, best_primary) and tie > best_tie):
			best_primary = primary
			best_tie = tie
			best_id = mod_id
			best_entry = {
				"mod_id": mod_id,
				"value": value,
				"value_text": value_text,
				"clears": clears,
			}
	return best_entry
