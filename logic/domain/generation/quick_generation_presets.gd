# logic/domain/generation/quick_generation_presets.gd
# Fixed "quick generation" presets (section 9). 3 slots, auto-named from content,
# applied by hotkeys / preset buttons. Reuses the ready-axes (mass) model.
extends RefCounted
class_name QuickGenerationPresets

const _GoalDiff = preload("res://logic/domain/generation/generation_goal_difficulty.gd")
const _Intents = preload("res://logic/domain/generation/generation_intents.gd")
const _PresetUi = preload("res://logic/ui/generation_preset_ui.gd")
const _UserPresets = preload("res://logic/domain/modifiers/user_presets.gd")

const COUNT := 3

const PARAM_KEYS := [
	"fill", "groove", "density", "grid_snap_strength",
	"accent_strong_beats", "genre_template_strength",
	"enable_genre_detection", "use_stems_in_generation",
	"include_hi_hats", "critic_strength", "groove_completion", "raw_adtof",
]

const _SETTING_KEY := "quick_generation_presets"
const _ACTIVE_SETTING_KEY := "quick_generation_active"

const SETTING_HOTKEY_PREFIX := "controls_quick_gen_"
const SETTING_HOTKEY_OPEN := "controls_quick_gen_open_key"


static func _default_ready_axes() -> Dictionary:
	return {
		"instruments": _GoalDiff.sanitize_ready_string_list(
			[], _GoalDiff.READY_INSTRUMENTS, str(_GoalDiff.DEFAULT_READY_INSTRUMENT)
		),
		"goals": _GoalDiff.sanitize_ready_string_list(
			[], _GoalDiff.GOALS, str(_GoalDiff.DEFAULT_GOAL)
		),
		"diffs": _GoalDiff.sanitize_ready_string_list(
			[], _GoalDiff.DIFFICULTIES, str(_GoalDiff.DEFAULT_DIFFICULTY)
		),
	}


static func sanitize_body(raw: Variant) -> Dictionary:
	var source: Dictionary = raw if raw is Dictionary else {}
	var axes := _default_ready_axes()
	var instruments: Array = axes["instruments"]
	if source.has("ready_instruments"):
		instruments = _GoalDiff.sanitize_ready_string_list(
			source.get("ready_instruments", []), _GoalDiff.READY_INSTRUMENTS,
			str(_GoalDiff.DEFAULT_READY_INSTRUMENT)
		)
	var goals: Array = axes["goals"]
	if source.has("ready_goals"):
		goals = _GoalDiff.sanitize_ready_string_list(
			source.get("ready_goals", []), _GoalDiff.GOALS, str(_GoalDiff.DEFAULT_GOAL)
		)
	var diffs: Array = axes["diffs"]
	if source.has("ready_diffs"):
		diffs = _GoalDiff.sanitize_ready_string_list(
			source.get("ready_diffs", []), _GoalDiff.DIFFICULTIES,
			str(_GoalDiff.DEFAULT_DIFFICULTY)
		)
	var intent := str(source.get("intent", "")).strip_edges().to_lower()
	if intent == "" or intent not in _Intents.INTENTS:
		intent = _GoalDiff.intent_for(str(goals[0]), str(diffs[0]))
	var out := {
		"ready_instruments": instruments,
		"ready_goals": goals,
		"ready_diffs": diffs,
		"lanes": clampi(int(source.get("lanes", 4)), 3, 5),
		"intent": intent,
		"ready_preset_slots": source.get("ready_preset_slots", []),
	}
	for key in PARAM_KEYS:
		if key.ends_with("_strength") or key in ["fill", "groove", "density", "grid_snap_strength", "genre_template_strength", "critic_strength"]:
			out[key] = clampi(int(source.get(key, 50)), 0, 100)
		else:
			out[key] = bool(source.get(key, true))
	return out


static func default_presets() -> Dictionary:
	return {
		1: _default_preset(
			{"ready_instruments": ["drums"], "ready_goals": ["arcade"],
			"ready_diffs": ["easy", "medium", "hard"], "lanes": 4, "intent": "groove"}
		),
		2: _default_preset(
			{"ready_instruments": ["drums", "bass"], "ready_goals": ["original"],
			"ready_diffs": ["medium"], "lanes": 4, "intent": "original"}
		),
		3: _default_preset(
			{"ready_instruments": ["bass"], "ready_goals": ["arcade"],
			"ready_diffs": ["medium"], "lanes": 4, "intent": "groove"}
		),
	}


static func _default_preset(overrides: Dictionary) -> Dictionary:
	var out := sanitize_body({
		"lanes": 4,
		"intent": "groove",
	})
	for key in overrides:
		out[key] = overrides[key]
	var intent := str(out.get("intent", "groove"))
	var params := _Intents.preset_for(intent)
	for key in params:
		out[key] = params[key]
	return sanitize_body(out)


static func load_presets() -> Dictionary:
	if SettingsManager == null:
		return default_presets()
	var stored: Variant = SettingsManager.get_setting(_SETTING_KEY, {})
	if stored is Dictionary and not stored.is_empty():
		var out := {}
		for slot in range(1, COUNT + 1):
			out[slot] = sanitize_body(stored.get(str(slot), {}))
		return out
	return default_presets()


static func save_presets(presets: Dictionary) -> void:
	if SettingsManager == null:
		return
	var out := {}
	for slot in range(1, COUNT + 1):
		out[str(slot)] = sanitize_body(presets.get(slot, {}))
	SettingsManager.set_setting(_SETTING_KEY, out)
	SettingsManager.save_settings()


static func get_preset(slot: int) -> Dictionary:
	var presets := load_presets()
	var body: Variant = presets.get(slot, {})
	return sanitize_body(body)


static func get_ready_preset_slots(slot: int) -> Array:
	var presets := load_presets()
	var body: Dictionary = presets.get(slot, {})
	return body.get("ready_preset_slots", [])


static func ready_user_preset_count(slot: int) -> int:
	var raw_slots: Array
	if slot >= 1:
		raw_slots = get_ready_preset_slots(slot)
	else:
		raw_slots = SettingsManager.get_setting("generation_ready_preset_slots", [])
	var presets := SettingsManager.get_generation_presets()
	var counted := {}
	var n := 0
	for item in raw_slots:
		var ps := int(item)
		if ps <= 0 or counted.has(ps):
			continue
		counted[ps] = true
		if _UserPresets.is_generation_slot_filled(presets, ps):
			n += 1
	return n


static func set_ready_preset_slots(slot: int, slots: Array) -> void:
	if slot < 1:
		return
	var presets := load_presets()
	var body: Dictionary = presets.get(slot, {})
	body["ready_preset_slots"] = slots
	presets[slot] = body
	save_presets(presets)


static func active_index() -> int:
	if SettingsManager == null:
		return 0
	return clampi(int(SettingsManager.get_setting(_ACTIVE_SETTING_KEY, 0)), 0, COUNT)


static func set_active(index: int) -> void:
	if SettingsManager == null:
		return
	SettingsManager.set_setting(_ACTIVE_SETTING_KEY, clampi(int(index), 0, COUNT))


## Factory-default generation body (slot 0 / "Default").
static func default_body() -> Dictionary:
	return sanitize_body({
		"ready_instruments": [_GoalDiff.DEFAULT_READY_INSTRUMENT],
		"ready_goals": [_GoalDiff.DEFAULT_GOAL],
		"ready_diffs": [_GoalDiff.DEFAULT_DIFFICULTY],
		"lanes": 4,
		"intent": "original",
	})


## Resets live generation settings back to the factory defaults and clears the
## active quick preset (slot 0). Unlike apply_to_settings(), this writes the
## base "basic" mode rather than "custom".
static func apply_default() -> void:
	if SettingsManager == null:
		return
	var b := default_body()
	var instruments: Array = b.get("ready_instruments", ["drums"])
	SettingsManager.set_setting("last_generation_instrument", str(instruments[0]) if not instruments.is_empty() else "drums")
	SettingsManager.set_setting("last_generation_mode", "basic")
	SettingsManager.set_setting("generation_goal", str(b.get("ready_goals", ["original"])[0]))
	SettingsManager.set_setting("generation_difficulty", str(b.get("ready_diffs", ["medium"])[0]))
	SettingsManager.set_setting("last_generation_intent", str(b.get("intent", "original")))
	SettingsManager.set_setting("last_generation_lanes", int(b.get("lanes", 4)))
	_settings_write_params(b)
	SettingsManager.set_setting("generation_ready_instruments", b.get("ready_instruments"))
	SettingsManager.set_setting("generation_ready_goals", b.get("ready_goals"))
	SettingsManager.set_setting("generation_ready_diffs", b.get("ready_diffs"))
	set_active(0)


static func display_name(slot: int) -> String:
	var body := get_preset(slot)
	var parts: PackedStringArray = []
	var instruments: Array = body.get("ready_instruments", [])
	for inst in instruments:
		parts.append(_PresetUi.localized_instrument(str(inst)))
	var goals: Array = body.get("ready_goals", [])
	if not goals.is_empty():
		var goal := str(goals[0]).strip_edges().to_lower()
		parts.append(_PresetUi.localized_goal(goal))
		if goal == "arcade":
			parts.append(_difficulties_label(goal, body.get("ready_diffs", [])))
	if parts.is_empty():
		return str(slot)
	return " · ".join(parts)


static func _difficulties_label(goal: String, diffs: Array) -> String:
	var expected: Array = _GoalDiff.DIFFICULTIES
	var has_all := true
	for diff_id in expected:
		if not diffs.has(diff_id):
			has_all = false
			break
	if has_all:
		return TranslationServer.translate("GEN_QUICK_PRESET_ALL_DIFFS")
	var labels: PackedStringArray = []
	for diff_id in diffs:
		labels.append(TranslationServer.translate(_GoalDiff.difficulty_label_key(goal, str(diff_id))))
	return " · ".join(labels)


static func hotkey_label(slot: int) -> String:
	if SettingsManager == null:
		return ""
	var sc := SettingsManager.get_quick_gen_preset_scancode(slot)
	return KeyInputUtils.get_key_string_from_scancode(sc)


static func apply_to_settings(body: Dictionary) -> void:
	if SettingsManager == null:
		return
	var b := sanitize_body(body)
	var instruments: Array = b.get("ready_instruments", [])
	var goals: Array = b.get("ready_goals", [])
	var diffs: Array = b.get("ready_diffs", [])
	var primary_instrument := str(instruments[0]) if not instruments.is_empty() else "drums"
	var primary_goal := str(goals[0]) if not goals.is_empty() else _GoalDiff.DEFAULT_GOAL
	var primary_diff := str(diffs[0]) if not diffs.is_empty() else _GoalDiff.DEFAULT_DIFFICULTY
	SettingsManager.set_setting("last_generation_instrument", primary_instrument)
	SettingsManager.set_setting("last_generation_mode", "custom")
	SettingsManager.set_setting("generation_goal", primary_goal)
	SettingsManager.set_setting("generation_difficulty", primary_diff)
	SettingsManager.set_setting("last_generation_intent", str(b.get("intent", "groove")))
	SettingsManager.set_setting("last_generation_lanes", int(b.get("lanes", 4)))
	_settings_write_params(b)
	SettingsManager.set_setting("generation_ready_instruments", instruments)
	SettingsManager.set_setting("generation_ready_goals", goals)
	SettingsManager.set_setting("generation_ready_diffs", diffs)


static func _settings_write_params(b: Dictionary) -> void:
	if SettingsManager == null:
		return
	var slots := {
		"fill": "generation_fill",
		"groove": "generation_groove",
		"density": "generation_density",
		"grid_snap_strength": "generation_grid_snap_strength",
		"accent_strong_beats": "generation_accent_strong_beats",
		"genre_template_strength": "generation_genre_template_strength",
		"enable_genre_detection": "enable_genre_detection",
		"use_stems_in_generation": "use_stems_in_generation",
		"include_hi_hats": "generation_include_hi_hats",
		"critic_strength": "generation_critic_strength",
		"groove_completion": "generation_groove_completion",
		"raw_adtof": "generation_raw_adtof",
	}
	for key in slots:
		SettingsManager.set_setting(slots[key], b.get(key))


## Canonical list of SettingsManager keys that a preset can write (apply mirror).
static func _settings_write_keys() -> Array[String]:
	return [
		"last_generation_instrument",
		"last_generation_mode",
		"generation_goal",
		"generation_difficulty",
		"last_generation_intent",
		"last_generation_lanes",
		"generation_fill",
		"generation_groove",
		"generation_density",
		"generation_grid_snap_strength",
		"generation_accent_strong_beats",
		"generation_genre_template_strength",
		"enable_genre_detection",
		"use_stems_in_generation",
		"generation_include_hi_hats",
		"generation_critic_strength",
		"generation_groove_completion",
		"generation_raw_adtof",
		"generation_ready_instruments",
		"generation_ready_goals",
		"generation_ready_diffs",
	]


## Raw value snapshot of every settings key apply_to_settings() may touch.
## Used by the hold-hotkey flow: capture on press, restore verbatim on release,
## so a temporary preset never leaks into the user's generation settings.
static func capture_settings_override() -> Dictionary:
	var out := {}
	if SettingsManager == null:
		return out
	for key in _settings_write_keys():
		if SettingsManager.settings.has(key):
			out[key] = SettingsManager.settings[key]
	return out


static func restore_settings_override(snapshot: Dictionary) -> void:
	if SettingsManager == null:
		return
	for key in _settings_write_keys():
		if snapshot.has(key):
			SettingsManager.settings[key] = snapshot[key]
		else:
			SettingsManager.settings.erase(key)


## Captures the current generation body (settings → sanitized preset body).
## Used when saving a slot from the current live settings.
static func capture_current_body() -> Dictionary:
	if SettingsManager == null:
		return sanitize_body({})
	var intent := _GoalDiff.intent_for(
		str(SettingsManager.get_setting("generation_goal", _GoalDiff.DEFAULT_GOAL)),
		str(SettingsManager.get_setting("generation_difficulty", _GoalDiff.DEFAULT_DIFFICULTY)),
	)
	var instruments := _GoalDiff.sanitize_ready_string_list(
		SettingsManager.get_setting("generation_ready_instruments", []),
		_GoalDiff.READY_INSTRUMENTS,
		str(SettingsManager.get_setting("last_generation_instrument", "drums")),
	)
	var goals := _GoalDiff.sanitize_ready_string_list(
		SettingsManager.get_setting("generation_ready_goals", []),
		_GoalDiff.GOALS,
		str(SettingsManager.get_setting("generation_goal", _GoalDiff.DEFAULT_GOAL)),
	)
	var diffs := _GoalDiff.sanitize_ready_string_list(
		SettingsManager.get_setting("generation_ready_diffs", []),
		_GoalDiff.DIFFICULTIES,
		str(SettingsManager.get_setting("generation_difficulty", _GoalDiff.DEFAULT_DIFFICULTY)),
	)
	var raw := {
		"ready_instruments": instruments,
		"ready_goals": goals,
		"ready_diffs": diffs,
		"lanes": SettingsManager.get_setting("last_generation_lanes", 4),
		"intent": intent,
	}
	var params := {
		"fill": SettingsManager.get_setting("generation_fill", 50),
		"groove": SettingsManager.get_setting("generation_groove", 50),
		"density": SettingsManager.get_setting("generation_density", 50),
		"grid_snap_strength": SettingsManager.get_setting("generation_grid_snap_strength", 50),
		"accent_strong_beats": SettingsManager.get_setting("generation_accent_strong_beats", false),
		"genre_template_strength": SettingsManager.get_setting("generation_genre_template_strength", 50),
		"enable_genre_detection": SettingsManager.get_setting("enable_genre_detection", true),
		"use_stems_in_generation": SettingsManager.get_setting("use_stems_in_generation", true),
		"include_hi_hats": SettingsManager.get_setting("generation_include_hi_hats", true),
		"critic_strength": SettingsManager.get_setting("generation_critic_strength", 50),
		"groove_completion": SettingsManager.get_setting("generation_groove_completion", true),
		"raw_adtof": SettingsManager.get_setting("generation_raw_adtof", false),
	}
	for key in params:
		raw[key] = params[key]
	return sanitize_body(raw)


## Editable slots: writes a full sanitized body into one of the 3 slots,
## persisting it in the settings file. The display name is always derived
## from the stored content (no manual rename).
static func set_preset_content(slot: int, body: Dictionary) -> void:
	if SettingsManager == null:
		return
	if slot < 1 or slot > COUNT:
		return
	var safe := clampi(int(slot), 1, COUNT)
	var presets := load_presets()
	presets[safe] = sanitize_body(body)
	save_presets(presets)


static func reset_preset(slot: int) -> void:
	if slot < 1 or slot > COUNT:
		return
	var defaults := default_presets()
	set_preset_content(slot, defaults.get(clampi(int(slot), 1, COUNT), {}))


## Keeps the active preset slot in sync with the live generation settings.
## The active preset's content IS the current working state, so every edit of the
## parameter icons becomes part of the active preset until the settings save.
## Returns true when a slot was updated, false when no preset is active.
static func sync_active_from_settings() -> bool:
	var active := active_index()
	if active < 1:
		return true
	var body := capture_current_body()
	body["ready_preset_slots"] = get_ready_preset_slots(active)
	set_preset_content(active, body)
	return true