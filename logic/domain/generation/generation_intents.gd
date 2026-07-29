# logic/domain/generation/generation_intents.gd
extends RefCounted
class_name GenerationIntents

const INTENTS := ["original", "groove", "arcade", "sparse"]
const _GoalDiff = preload("res://logic/domain/generation/generation_goal_difficulty.gd")

const LOCKED_INTENTS := {}

# Display presets for song-select UI. Server intent bundles — phase C (see docs/generation_intents.md).
const INTENT_PRESETS := {
	"original": {
		"fill": 0,
		"groove": 50,
		"density": 50,
		"grid_snap_strength": 40,
		"accent_strong_beats": false,
		"genre_template_strength": 55,
		"enable_genre_detection": true,
		"use_stems_in_generation": true,
		"include_hi_hats": true,
		"critic_strength": 45,
		"groove_completion": false,
		"raw_adtof": false,
	},
	"groove": {
		"fill": 0,
		"groove": 50,
		"density": 50,
		"grid_snap_strength": 40,
		"accent_strong_beats": false,
		"genre_template_strength": 55,
		"enable_genre_detection": true,
		"use_stems_in_generation": true,
		"include_hi_hats": true,
		"critic_strength": 50,
		"groove_completion": true,
		"raw_adtof": false,
	},
	"sparse": {
		"fill": 0,
		"groove": 20,
		"density": 30,
		"grid_snap_strength": 85,
		"accent_strong_beats": true,
		"genre_template_strength": 45,
		"enable_genre_detection": true,
		"use_stems_in_generation": true,
		"include_hi_hats": false,
		"critic_strength": 30,
		"groove_completion": false,
		"raw_adtof": false,
	},
}

const _LEGACY_MODE_TO_INTENT := {
	"minimal": "sparse",
	"basic": "groove",
	"enhanced": "groove",
	"natural": "original",
	"custom": "groove",
}

const _INTENT_TO_LEGACY_MODE := {
	"original": "basic",
	"groove": "basic",
	"sparse": "minimal",
	"arcade": "basic",
}


static func is_locked(intent_id: String) -> bool:
	return bool(LOCKED_INTENTS.get(intent_id.strip_edges().to_lower(), false))


static func migrate_legacy_mode(mode: String) -> String:
	var key := mode.strip_edges().to_lower()
	if key in INTENTS:
		return key
	return str(_LEGACY_MODE_TO_INTENT.get(key, "original"))


static func intent_to_legacy_mode(intent_id: String) -> String:
	var key := intent_id.strip_edges().to_lower()
	return str(_INTENT_TO_LEGACY_MODE.get(key, "basic"))


static func is_chart_intent(value: String) -> bool:
	return value.strip_edges().to_lower() in INTENTS


static func resolve_chart_stem(mode_or_intent: String) -> String:
	var key := mode_or_intent.strip_edges().to_lower()
	if _GoalDiff.is_chart_stem(key):
		var pair := _GoalDiff.pair_from_stem(key)
		return _GoalDiff.chart_stem(
			str(pair.get("goal", _GoalDiff.DEFAULT_GOAL)),
			str(pair.get("difficulty", _GoalDiff.DEFAULT_DIFFICULTY)),
		)
	if key in INTENTS:
		return _GoalDiff.stem_from_intent_legacy(key)
	if key == "custom":
		if SettingsManager:
			var g := str(SettingsManager.get_setting("generation_goal", _GoalDiff.DEFAULT_GOAL)).strip_edges().to_lower()
			var d := str(SettingsManager.get_setting("generation_difficulty", _GoalDiff.DEFAULT_DIFFICULTY)).strip_edges().to_lower()
			if _GoalDiff.is_goal(g) and _GoalDiff.is_difficulty(d):
				return _GoalDiff.chart_stem(g, d)
			var saved := str(SettingsManager.get_setting("last_generation_intent", "")).strip_edges().to_lower()
			if saved in INTENTS:
				return _GoalDiff.stem_from_intent_legacy(saved)
		return _GoalDiff.chart_stem(_GoalDiff.DEFAULT_GOAL, _GoalDiff.DEFAULT_DIFFICULTY)
	return _GoalDiff.stem_from_intent_legacy(migrate_legacy_mode(key))


## Chart file stem for play / notes_exist / notifications (goal×difficulty aware).
static func chart_lookup_key(mode: String, intent: String = "") -> String:
	if SettingsManager:
		var g := str(SettingsManager.get_setting("generation_goal", "")).strip_edges().to_lower()
		var d := str(SettingsManager.get_setting("generation_difficulty", "")).strip_edges().to_lower()
		if g != "" and d != "":
			return _GoalDiff.chart_stem(g, d)
	var intent_lc := intent.strip_edges().to_lower()
	if intent_lc in INTENTS:
		return _GoalDiff.stem_from_intent_legacy(intent_lc)
	var mode_lc := mode.strip_edges().to_lower()
	if mode_lc in INTENTS:
		return _GoalDiff.stem_from_intent_legacy(mode_lc)
	if SettingsManager:
		var saved := str(SettingsManager.get_setting("last_generation_intent", "")).strip_edges().to_lower()
		if saved in INTENTS:
			return _GoalDiff.stem_from_intent_legacy(saved)
	return _GoalDiff.chart_stem(_GoalDiff.DEFAULT_GOAL, _GoalDiff.DEFAULT_DIFFICULTY)


static func chart_lookup_key_from_job(job: Dictionary) -> String:
	var g := str(job.get("goal", "")).strip_edges().to_lower()
	var d := str(job.get("difficulty", "")).strip_edges().to_lower()
	if g != "" and d != "":
		return _GoalDiff.chart_stem(g, d)
	var stem := str(job.get("chart_stem", "")).strip_edges().to_lower()
	if stem != "":
		if _GoalDiff.is_chart_stem(stem):
			var pair := _GoalDiff.pair_from_stem(stem)
			return _GoalDiff.chart_stem(
				str(pair.get("goal", _GoalDiff.DEFAULT_GOAL)),
				str(pair.get("difficulty", _GoalDiff.DEFAULT_DIFFICULTY)),
			)
		return stem
	return chart_lookup_key(str(job.get("mode", "")), str(job.get("chart_intent", "")))


static func preset_for(intent_id: String) -> Dictionary:
	var key := intent_id.strip_edges().to_lower()
	if key in INTENT_PRESETS:
		return (INTENT_PRESETS[key] as Dictionary).duplicate(true)
	return (INTENT_PRESETS["original"] as Dictionary).duplicate(true)


static func params_match_intent(params: Dictionary, intent_id: String) -> bool:
	var preset := preset_for(intent_id)
	for key in preset:
		if params.get(key) != preset[key]:
			return false
	return true


static func closest_intent_for_params(params: Dictionary) -> String:
	for intent_id in INTENTS:
		if is_locked(intent_id):
			continue
		if params_match_intent(params, intent_id):
			return intent_id
	return ""


static func can_toggle_groove_completion(intent_id: String) -> bool:
	return intent_id.strip_edges().to_lower() == "groove"


static func can_toggle_raw_adtof(intent_id: String) -> bool:
	return intent_id.strip_edges().to_lower() == "groove"


static func clamp_advanced_flags(intent_id: String, groove_completion: bool, raw_adtof: bool) -> Dictionary:
	var intent := intent_id.strip_edges().to_lower()
	var gc := groove_completion
	var raw := raw_adtof
	if not can_toggle_groove_completion(intent):
		gc = false
	if not can_toggle_raw_adtof(intent):
		raw = false
	return {"groove_completion": gc, "raw_adtof": raw}
