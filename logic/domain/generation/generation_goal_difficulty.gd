# logic/domain/generation/generation_goal_difficulty.gd
extends RefCounted
class_name GenerationGoalDifficulty

const GOALS := ["original", "arcade"]
const DIFFICULTIES := ["easy", "medium", "hard"]
const READY_INSTRUMENTS := ["drums", "bass"]

const DEFAULT_GOAL := "original"
const DEFAULT_DIFFICULTY := "medium"
const DEFAULT_READY_INSTRUMENT := "drums"

# Legacy difficulty ids still present in settings / on-disk stems.
const _LEGACY_DIFFICULTY := {
	"relaxed": "easy",
	"standard": "medium",
	"dense": "hard",
}

# Legacy int scope (migrated to ready-axes on settings load). Kept for one-shot remap only.
const SCOPE_CURRENT := 0
const SCOPE_GOAL_ALL_DIFF := 1
const SCOPE_DIFF_ALL_GOAL := 2
const SCOPE_ALL := 3
const SCOPE_MAX := 3

const _INTENT_TO_PAIR := {
	"original": {"goal": "original", "difficulty": "medium"},
	"groove": {"goal": "arcade", "difficulty": "medium"},
	"sparse": {"goal": "original", "difficulty": "easy"},
	"arcade": {"goal": "arcade", "difficulty": "medium"},
}

const _PAIR_TO_INTENT := {
	"original|easy": "sparse",
	"original|medium": "original",
	"original|hard": "original",
	"arcade|easy": "sparse",
	"arcade|medium": "groove",
	"arcade|hard": "groove",
}

const _DIFFICULTY_OPTION_IDS := {
	"easy": 0,
	"medium": 1,
	"hard": 2,
}


static func pair_key(goal: String, difficulty: String) -> String:
	return "%s|%s" % [
		goal.strip_edges().to_lower(),
		sanitize_difficulty(difficulty),
	]


static func is_goal(value: String) -> bool:
	return value.strip_edges().to_lower() in GOALS


static func is_difficulty(value: String) -> bool:
	return sanitize_difficulty(value) in DIFFICULTIES


static func intent_for(goal: String, difficulty: String) -> String:
	return str(_PAIR_TO_INTENT.get(pair_key(goal, difficulty), "original"))


static func from_intent(intent_id: String) -> Dictionary:
	var key := intent_id.strip_edges().to_lower()
	if _INTENT_TO_PAIR.has(key):
		return _INTENT_TO_PAIR[key].duplicate()
	return {"goal": DEFAULT_GOAL, "difficulty": DEFAULT_DIFFICULTY}


static func difficulty_option_id(difficulty: String) -> int:
	return int(_DIFFICULTY_OPTION_IDS.get(sanitize_difficulty(difficulty), 1))


static func difficulty_from_option_id(option_id: int) -> String:
	for key in _DIFFICULTY_OPTION_IDS:
		if int(_DIFFICULTY_OPTION_IDS[key]) == option_id:
			return key
	return DEFAULT_DIFFICULTY


static func blurb_key(goal: String, difficulty: String) -> String:
	return "GEN_GOAL_DIFF_BLURB_%s_%s" % [
		goal.strip_edges().to_upper(),
		sanitize_difficulty(difficulty).to_upper(),
	]


# UI segment / preview labels depend on goal: Original uses documentary names,
# Arcade keeps gameplay-oriented Easy/Medium/Hard strings.
static func difficulty_label_key(goal: String, difficulty: String) -> String:
	var g := sanitize_goal(goal)
	var d := sanitize_difficulty(difficulty)
	if g == "original":
		return "GEN_DIFF_ORIGINAL_%s" % d.to_upper()
	return "GEN_DIFF_%s" % d.to_upper()


static func difficulty_label_key_for_stem(stem: String) -> String:
	var pair := pair_from_stem(stem)
	return difficulty_label_key(
		str(pair.get("goal", DEFAULT_GOAL)),
		str(pair.get("difficulty", DEFAULT_DIFFICULTY)),
	)


static func sanitize_goal(value: String) -> String:
	var key := value.strip_edges().to_lower()
	return key if key in GOALS else DEFAULT_GOAL


static func sanitize_difficulty(value: String) -> String:
	var key := value.strip_edges().to_lower()
	if _LEGACY_DIFFICULTY.has(key):
		key = str(_LEGACY_DIFFICULTY[key])
	return key if key in DIFFICULTIES else DEFAULT_DIFFICULTY


static func chart_stem(goal: String, difficulty: String) -> String:
	# Original is one documentary chart → filename stem "original" (not original_medium).
	if sanitize_goal(goal) == "original":
		return "original"
	return "%s_%s" % [sanitize_goal(goal), sanitize_difficulty(difficulty)]


static func all_stems() -> Array[String]:
	var out: Array[String] = ["original"]
	for d in DIFFICULTIES:
		out.append(chart_stem("arcade", d))
	return out


static func is_chart_stem(value: String) -> bool:
	var key := value.strip_edges().to_lower()
	if key in all_stems():
		return true
	# Legacy on-disk / metadata stems.
	if key.begins_with("original_"):
		var legacy_d := key.substr("original_".length())
		return sanitize_difficulty(legacy_d) in DIFFICULTIES
	if key.begins_with("arcade_"):
		var legacy_d2 := key.substr("arcade_".length())
		return sanitize_difficulty(legacy_d2) in DIFFICULTIES
	return false


## Filenames to try when looking up a chart on disk (canonical first, then legacy).
static func stem_read_aliases(stem: String) -> Array[String]:
	var key := stem.strip_edges().to_lower()
	var out: Array[String] = []
	if key == "original" or key.begins_with("original_"):
		for s in ["original", "original_standard", "original_medium", "original_relaxed", "original_easy", "original_dense", "original_hard"]:
			out.append(s)
		return out
	var pair := pair_from_stem(key)
	var goal := str(pair.get("goal", ""))
	var diff := sanitize_difficulty(str(pair.get("difficulty", DEFAULT_DIFFICULTY)))
	if goal == "arcade":
		var canonical := chart_stem("arcade", diff)
		out.append(canonical)
		# Legacy difficulty tokens in filenames.
		var legacy_token: String = ""
		match diff:
			"easy":
				legacy_token = "relaxed"
			"medium":
				legacy_token = "standard"
			"hard":
				legacy_token = "dense"
		if legacy_token != "":
			var legacy_stem := "arcade_%s" % legacy_token
			if not out.has(legacy_stem):
				out.append(legacy_stem)
		return out
	out.append(key)
	return out


static func clamp_scope(scope: int) -> int:
	return clampi(int(scope), 0, SCOPE_MAX)


static func sanitize_ready_instrument(value: String) -> String:
	var key := value.strip_edges().to_lower()
	return key if key in READY_INSTRUMENTS else DEFAULT_READY_INSTRUMENT


static func sanitize_ready_string_list(raw: Variant, allowed: Array, fallback: String) -> Array[String]:
	var out: Array[String] = []
	if raw is Array or raw is PackedStringArray:
		for item in raw:
			var key := str(item).strip_edges().to_lower()
			if allowed == DIFFICULTIES:
				key = sanitize_difficulty(key)
			if key == "" or not allowed.has(key):
				continue
			if out.has(key):
				continue
			out.append(key)
	if out.is_empty():
		out.append(fallback)
	return out


## Resolved ready/mass-gen axes from settings (or a settings-like dict).
## Always uses the selected checkbox/icon sets (at least one value per axis).
static func resolve_ready_axes(
	settings: Dictionary = {},
	cur_goal: String = "",
	cur_diff: String = "",
	cur_instrument: String = "",
) -> Dictionary:
	var src := settings
	if src.is_empty() and typeof(SettingsManager) != TYPE_NIL and SettingsManager != null:
		src = {
			"generation_ready_goals": SettingsManager.get_setting("generation_ready_goals", []),
			"generation_ready_diffs": SettingsManager.get_setting("generation_ready_diffs", []),
			"generation_ready_instruments": SettingsManager.get_setting("generation_ready_instruments", []),
			"generation_goal": SettingsManager.get_setting("generation_goal", DEFAULT_GOAL),
			"generation_difficulty": SettingsManager.get_setting("generation_difficulty", DEFAULT_DIFFICULTY),
			"last_generation_instrument": SettingsManager.get_setting("last_generation_instrument", DEFAULT_READY_INSTRUMENT),
		}
	var goal := sanitize_goal(cur_goal if cur_goal != "" else str(src.get("generation_goal", DEFAULT_GOAL)))
	var diff := sanitize_difficulty(cur_diff if cur_diff != "" else str(src.get("generation_difficulty", DEFAULT_DIFFICULTY)))
	var instrument := sanitize_ready_instrument(
		cur_instrument if cur_instrument != "" else str(src.get("last_generation_instrument", DEFAULT_READY_INSTRUMENT))
	)
	var instruments := sanitize_ready_string_list(
		src.get("generation_ready_instruments", []), READY_INSTRUMENTS, instrument
	)
	# Style chip instrument must always be in the ready set — otherwise Play looks for
	# bass while Generate/ready checks only drums (default ready list).
	if not instruments.has(instrument):
		instruments.append(instrument)
	return {
		"goals": sanitize_ready_string_list(src.get("generation_ready_goals", []), GOALS, goal),
		"diffs": sanitize_ready_string_list(src.get("generation_ready_diffs", []), DIFFICULTIES, diff),
		"instruments": instruments,
	}


static func stems_for_ready_axes(goals: Array, diffs: Array) -> Array[String]:
	var out: Array[String] = []
	for g_raw in goals:
		var g := sanitize_goal(str(g_raw))
		# Original is documentary — one chart ("as detected"), not Easy/Med/Hard tiers.
		if g == "original":
			var stem_o := chart_stem("original", DEFAULT_DIFFICULTY)
			if not out.has(stem_o):
				out.append(stem_o)
			continue
		for d_raw in diffs:
			var stem := chart_stem(g, str(d_raw))
			if not out.has(stem):
				out.append(stem)
	if out.is_empty():
		out.append(chart_stem(DEFAULT_GOAL, DEFAULT_DIFFICULTY))
	return out


static func ready_axes_fingerprint(axes: Dictionary) -> String:
	var goals: Array = axes.get("goals", [])
	var diffs: Array = axes.get("diffs", [])
	var instruments: Array = axes.get("instruments", [])
	return "%s|%s|%s" % [
		",".join(PackedStringArray(goals)),
		",".join(PackedStringArray(diffs)),
		",".join(PackedStringArray(instruments)),
	]


static func ready_axes_is_mass(axes: Dictionary) -> bool:
	var goals: Array = axes.get("goals", [])
	var diffs: Array = axes.get("diffs", [])
	var instruments: Array = axes.get("instruments", [])
	return goals.size() > 1 or diffs.size() > 1 or instruments.size() > 1


## One-shot map from legacy int scope (0–3) into ready-axes settings keys.
static func ready_axes_from_legacy_scope(scope: int) -> Dictionary:
	match clamp_scope(scope):
		SCOPE_GOAL_ALL_DIFF:
			return {
				"generation_ready_goals": [DEFAULT_GOAL],
				"generation_ready_diffs": DIFFICULTIES.duplicate(),
				"generation_ready_instruments": [DEFAULT_READY_INSTRUMENT],
			}
		SCOPE_DIFF_ALL_GOAL:
			return {
				"generation_ready_goals": GOALS.duplicate(),
				"generation_ready_diffs": [DEFAULT_DIFFICULTY],
				"generation_ready_instruments": [DEFAULT_READY_INSTRUMENT],
			}
		SCOPE_ALL:
			return {
				"generation_ready_goals": GOALS.duplicate(),
				"generation_ready_diffs": DIFFICULTIES.duplicate(),
				"generation_ready_instruments": [DEFAULT_READY_INSTRUMENT],
			}
		_:
			return {
				"generation_ready_goals": [DEFAULT_GOAL],
				"generation_ready_diffs": [DEFAULT_DIFFICULTY],
				"generation_ready_instruments": [DEFAULT_READY_INSTRUMENT],
			}


# Legacy: stems for old int scope. Prefer stems_for_ready_axes.
static func stems_for_scope(scope: int, goal: String, difficulty: String) -> Array[String]:
	var g := sanitize_goal(goal)
	var d := sanitize_difficulty(difficulty)
	var out: Array[String] = []
	match clamp_scope(scope):
		SCOPE_GOAL_ALL_DIFF:
			if g == "original":
				out.append(chart_stem(g, d))
			else:
				for dd in DIFFICULTIES:
					out.append(chart_stem(g, dd))
		SCOPE_DIFF_ALL_GOAL:
			for gg in GOALS:
				out.append(chart_stem(gg, d))
		SCOPE_ALL:
			out = all_stems()
		_:
			out.append(chart_stem(g, d))
	return out


static func stem_from_intent_legacy(intent_id: String) -> String:
	var pair := from_intent(intent_id)
	return chart_stem(str(pair.get("goal", DEFAULT_GOAL)), str(pair.get("difficulty", DEFAULT_DIFFICULTY)))


static func pair_from_stem(stem: String) -> Dictionary:
	var key := stem.strip_edges().to_lower()
	if key == "original" or key.begins_with("original_"):
		if key.begins_with("original_"):
			var legacy_d := key.substr("original_".length())
			return {"goal": "original", "difficulty": sanitize_difficulty(legacy_d)}
		return {"goal": "original", "difficulty": DEFAULT_DIFFICULTY}
	if key.begins_with("arcade_"):
		var d_token := key.substr("arcade_".length())
		# Tag / lanes suffixes: arcade_hard_p03, arcade_dense_lanes4
		var base := d_token.split("_")[0]
		return {"goal": "arcade", "difficulty": sanitize_difficulty(base)}
	for d in DIFFICULTIES:
		if chart_stem("arcade", d) == key:
			return {"goal": "arcade", "difficulty": d}
	return {"goal": DEFAULT_GOAL, "difficulty": DEFAULT_DIFFICULTY}


static func label_key_for_stem(stem: String) -> String:
	var pair := pair_from_stem(stem)
	return blurb_key(str(pair.get("goal", DEFAULT_GOAL)), str(pair.get("difficulty", DEFAULT_DIFFICULTY)))


static func abbrev_for_stem(stem: String) -> String:
	var pair := pair_from_stem(stem)
	var goal := str(pair.get("goal", DEFAULT_GOAL))
	var difficulty := str(pair.get("difficulty", DEFAULT_DIFFICULTY))
	if sanitize_goal(goal) == "original":
		return _goal_abbrev(goal)
	return "%s%s" % [_goal_abbrev(goal), _difficulty_abbrev(goal, difficulty)]


static func _goal_abbrev(goal: String) -> String:
	var key := "SONG_GEN_ABBR_%s" % sanitize_goal(goal).to_upper()
	var abbrev := TranslationServer.translate(key)
	if abbrev != key:
		return abbrev
	match sanitize_goal(goal):
		"arcade":
			return "A"
		_:
			return "O"


static func _difficulty_abbrev(goal: String, difficulty: String) -> String:
	var g := sanitize_goal(goal)
	var d := sanitize_difficulty(difficulty)
	if g == "original":
		var orig_key := "SONG_GEN_ABBR_DIFF_ORIGINAL_%s" % d.to_upper()
		var orig_abbrev := TranslationServer.translate(orig_key)
		if orig_abbrev != orig_key:
			return orig_abbrev
		var ru := TranslationServer.get_locale().begins_with("ru")
		match d:
			"easy":
				return "К" if ru else "B"
			"hard":
				return "А" if ru else "A"
			_:
				return "Ч" if ru else "R"
	var key := "SONG_GEN_ABBR_DIFF_%s" % d.to_upper()
	var abbrev := TranslationServer.translate(key)
	if abbrev != key:
		return abbrev
	match d:
		"easy":
			return "E"
		"hard":
			return "H"
		_:
			return "M"
