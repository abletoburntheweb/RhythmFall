# logic/domain/modifiers/user_presets.gd
extends RefCounted
class_name UserPresets

const _RunModifiers = preload("res://logic/domain/modifiers/run_modifiers.gd")

const MAX_SLOTS := 10
const MAX_NAME_LEN := 32
const DOMAIN_MODIFIER := "modifier"
const DOMAIN_GENERATION := "generation"
const MODIFIER_PRESETS_PATH := "user://run_modifier_presets.json"
const GENERATION_PRESETS_PATH := "user://generation_presets.json"

const _Intents = preload("res://logic/domain/generation/generation_intents.gd")

const VALID_GENERATION_MODES := ["minimal", "basic", "enhanced", "natural", "custom"]
const VALID_GENERATION_INSTRUMENTS := ["drums", "fullmix", "bass", "guitar", "keys", "vocals"]

const _DEFAULT_MODIFIER_PRESETS := {
	"active_slot": 0,
	"slots": {},
}

const _DEFAULT_GENERATION_PRESETS := {
	"active_slot": 0,
	"slots": {},
}


static func default_modifier_presets() -> Dictionary:
	return _DEFAULT_MODIFIER_PRESETS.duplicate(true)


static func load_modifier_presets() -> Dictionary:
	var raw := JsonUtils.read_json_dict(MODIFIER_PRESETS_PATH)
	if raw.is_empty():
		return default_modifier_presets()
	return sanitize_modifier_presets(raw)


static func save_modifier_presets(presets: Dictionary) -> bool:
	var sanitized := sanitize_modifier_presets(presets)
	return JsonUtils.write_json(MODIFIER_PRESETS_PATH, sanitized, true, true)


static func migrate_modifier_presets_from_settings(legacy: Variant) -> void:
	if FileAccess.file_exists(MODIFIER_PRESETS_PATH):
		return
	if legacy is not Dictionary:
		return
	var migrated := sanitize_modifier_presets(legacy)
	if migrated.get("slots", {}).is_empty() and int(migrated.get("active_slot", 0)) == 0:
		return
	save_modifier_presets(migrated)


static func sanitize_modifier_presets(raw: Variant) -> Dictionary:
	var out := default_modifier_presets()
	if raw is Dictionary:
		out["active_slot"] = clampi(int(raw.get("active_slot", 0)), 0, MAX_SLOTS)
		var slots_in: Variant = raw.get("slots", {})
		if slots_in is Dictionary:
			for key in slots_in.keys():
				var slot_idx := int(str(key))
				if slot_idx < 1 or slot_idx > MAX_SLOTS:
					continue
				var entry: Variant = slots_in[key]
				if entry is Dictionary:
					out["slots"][str(slot_idx)] = sanitize_modifier_slot(entry)
	return out


static func sanitize_modifier_slot(raw: Variant) -> Dictionary:
	if raw is not Dictionary:
		return {}
	var mods := _RunModifiers.sanitize(raw.get("modifiers", []))
	var params := _RunModifiers.sanitize_params(raw.get("params", {}))
	var name := _sanitize_name(raw.get("name", ""))
	return {
		"name": name,
		"modifiers": mods,
		"params": params,
		"favorite": bool(raw.get("favorite", false)),
		"updated_at": int(raw.get("updated_at", 0)),
		"use_count": maxi(0, int(raw.get("use_count", 0))),
	}


static func _sanitize_name(raw: Variant) -> String:
	var name := str(raw).strip_edges().replace("\n", " ").replace("\r", "")
	if name.length() > MAX_NAME_LEN:
		name = name.substr(0, MAX_NAME_LEN)
	return name


static func sanitize_name(raw: Variant) -> String:
	return _sanitize_name(raw)


static func slot_key(slot: int) -> String:
	return str(clampi(slot, 1, MAX_SLOTS))


static func is_slot_filled(presets: Dictionary, slot: int) -> bool:
	var entry: Variant = presets.get("slots", {}).get(slot_key(slot), null)
	return entry is Dictionary and not str(entry.get("name", "")).strip_edges().is_empty()


static func get_slot(presets: Dictionary, slot: int) -> Dictionary:
	var entry: Variant = presets.get("slots", {}).get(slot_key(slot), null)
	if entry is Dictionary:
		return sanitize_modifier_slot(entry)
	return {}


static func default_slot_name(slot: int) -> String:
	return TranslationServer.translate("MOD_PRESET_SLOT_DEFAULT") % slot


static func display_name(presets: Dictionary, slot: int) -> String:
	if not is_slot_filled(presets, slot):
		return TranslationServer.translate("MOD_PRESET_SLOT_EMPTY")
	var entry := get_slot(presets, slot)
	var name := str(entry.get("name", "")).strip_edges()
	if name == "":
		return default_slot_name(slot)
	return name


static func make_modifier_slot(
	name: String,
	modifiers: Array,
	params: Dictionary,
	favorite: bool = false,
	use_count: int = 0,
	updated_at: int = 0
) -> Dictionary:
	return {
		"name": _sanitize_name(name),
		"modifiers": _RunModifiers.sanitize(modifiers),
		"params": _RunModifiers.sanitize_params(params),
		"favorite": favorite,
		"updated_at": updated_at if updated_at > 0 else int(Time.get_unix_time_from_system()),
		"use_count": maxi(0, use_count),
	}


static func update_modifier_slot_name(presets: Dictionary, slot: int, name: String) -> Dictionary:
	if not is_slot_filled(presets, slot):
		return sanitize_modifier_presets(presets)
	var out := sanitize_modifier_presets(presets)
	var key := slot_key(slot)
	var entry := get_slot(out, slot)
	var slot_name := _sanitize_name(name)
	if slot_name == "":
		slot_name = default_slot_name(slot)
	entry["name"] = slot_name
	entry["updated_at"] = int(Time.get_unix_time_from_system())
	out["slots"][key] = entry
	return out


static func save_modifier_slot(
	presets: Dictionary,
	slot: int,
	name: String,
	modifiers: Array,
	params: Dictionary,
	keep_meta: Dictionary = {}
) -> Dictionary:
	var out := sanitize_modifier_presets(presets)
	var key := slot_key(slot)
	var prev := get_slot(out, slot)
	var slot_name := _sanitize_name(name)
	if slot_name == "":
		slot_name = default_slot_name(slot)
	# «Пройдено N раз» привязано к КОНКРЕТНОМУ набору модификаторов. Если при
	# перезаписи слота изменились сами моды или их параметры — это новый вызов,
	# и счётчик прохождений сбрасывается. Иначе можно накрутить клиры на лёгких
	# модах, а потом подменить их сложными, сохранив число прохождений.
	var prev_filled := not str(prev.get("name", "")).strip_edges().is_empty()
	var same_config := prev_filled and modifier_states_equal(
		prev,
		{"modifiers": modifiers, "params": params}
	)
	var use_count := 0
	if same_config:
		use_count = int(keep_meta.get("use_count", prev.get("use_count", 0)))
	out["slots"][key] = make_modifier_slot(
		slot_name,
		modifiers,
		params,
		bool(keep_meta.get("favorite", prev.get("favorite", false))),
		use_count,
		int(Time.get_unix_time_from_system())
	)
	out["active_slot"] = slot
	return out


static func delete_modifier_slot(presets: Dictionary, slot: int) -> Dictionary:
	var out := sanitize_modifier_presets(presets)
	out["slots"].erase(slot_key(slot))
	if int(out.get("active_slot", 0)) == slot:
		out["active_slot"] = 0
	return out


static func set_modifier_slot_favorite(presets: Dictionary, slot: int, favorite: bool) -> Dictionary:
	if not is_slot_filled(presets, slot):
		return sanitize_modifier_presets(presets)
	var out := sanitize_modifier_presets(presets)
	var key := slot_key(slot)
	var entry := get_slot(out, slot)
	entry["favorite"] = favorite
	out["slots"][key] = entry
	return out


static func set_active_modifier_slot(presets: Dictionary, slot: int) -> Dictionary:
	var out := sanitize_modifier_presets(presets)
	if slot >= 1 and slot <= MAX_SLOTS:
		out["active_slot"] = slot
	return out


static func clear_active_modifier_slot(presets: Dictionary) -> Dictionary:
	var out := sanitize_modifier_presets(presets)
	out["active_slot"] = 0
	return out


static func slot_matches_run(
	presets: Dictionary,
	slot: int,
	modifiers: Array,
	params: Dictionary
) -> bool:
	if not is_slot_filled(presets, slot):
		return false
	var entry := get_slot(presets, slot)
	var slot_mods := _RunModifiers.sanitize(entry.get("modifiers", []))
	var run_mods := _RunModifiers.sanitize(modifiers)
	if slot_mods.size() != run_mods.size():
		return false
	for mod_id in slot_mods:
		if not run_mods.has(mod_id):
			return false
	var slot_params := _RunModifiers.sanitize_params(entry.get("params", {}))
	var run_params := _RunModifiers.sanitize_params(params)
	return slot_params == run_params


static func sync_active_slot_for_run(presets: Dictionary, modifiers: Array, params: Dictionary) -> Dictionary:
	var out := sanitize_modifier_presets(presets)
	var slot := int(out.get("active_slot", 0))
	if slot <= 0:
		return out
	if is_slot_filled(out, slot) and slot_matches_run(out, slot, modifiers, params):
		return out
	if not is_slot_filled(out, slot):
		return out
	out["active_slot"] = 0
	return out


static func record_modifier_slot_clear(presets: Dictionary, modifiers: Array, params: Dictionary) -> Dictionary:
	var out := sanitize_modifier_presets(presets)
	var slot := int(out.get("active_slot", 0))
	if slot <= 0 or not slot_matches_run(out, slot, modifiers, params):
		return out
	var key := slot_key(slot)
	var entry := get_slot(out, slot)
	entry["use_count"] = int(entry.get("use_count", 0)) + 1
	out["slots"][key] = entry
	return out


static func slots_for_tab(presets: Dictionary, favorites_only: bool) -> Array[int]:
	var out: Array[int] = []
	for slot in range(1, MAX_SLOTS + 1):
		if favorites_only:
			if is_slot_filled(presets, slot) and bool(get_slot(presets, slot).get("favorite", false)):
				out.append(slot)
		else:
			out.append(slot)
	return out


static func format_slot_date(unix_ts: int) -> String:
	if unix_ts <= 0:
		return "—"
	var dt := Time.get_datetime_dict_from_unix_time(unix_ts)
	return "%02d.%02d.%04d" % [int(dt.get("day", 0)), int(dt.get("month", 0)), int(dt.get("year", 0))]


# --- Generation presets ---


static func default_generation_presets() -> Dictionary:
	return _DEFAULT_GENERATION_PRESETS.duplicate(true)


static func load_generation_presets() -> Dictionary:
	var raw := JsonUtils.read_json_dict(GENERATION_PRESETS_PATH)
	if raw.is_empty():
		return default_generation_presets()
	return sanitize_generation_presets(raw)


static func save_generation_presets(presets: Dictionary) -> bool:
	var sanitized := sanitize_generation_presets(presets)
	return JsonUtils.write_json(GENERATION_PRESETS_PATH, sanitized, true, true)


static func sanitize_generation_presets(raw: Variant) -> Dictionary:
	var out := default_generation_presets()
	if raw is Dictionary:
		out["active_slot"] = clampi(int(raw.get("active_slot", 0)), 0, MAX_SLOTS)
		var slots_in: Variant = raw.get("slots", {})
		if slots_in is Dictionary:
			for key in slots_in.keys():
				var slot_idx := int(str(key))
				if slot_idx < 1 or slot_idx > MAX_SLOTS:
					continue
				var entry: Variant = slots_in[key]
				if entry is Dictionary:
					out["slots"][str(slot_idx)] = sanitize_generation_slot(entry)
	return out


static func sanitize_generation_slot(raw: Variant) -> Dictionary:
	if raw is not Dictionary:
		return {}
	var instrument := str(raw.get("instrument", "drums")).strip_edges().to_lower()
	if instrument not in VALID_GENERATION_INSTRUMENTS:
		instrument = "drums"
	var mode := str(raw.get("mode", "basic")).strip_edges().to_lower()
	if mode not in VALID_GENERATION_MODES:
		mode = "basic"
	var lanes := clampi(int(raw.get("lanes", 4)), 3, 5)
	var saved_intent := str(raw.get("intent", "")).strip_edges().to_lower()
	if saved_intent == "" or saved_intent not in _Intents.INTENTS:
		saved_intent = _Intents.migrate_legacy_mode(mode)
	return {
		"name": _sanitize_name(raw.get("name", "")),
		"instrument": instrument,
		"intent": saved_intent,
		"mode": "custom",
		"lanes": lanes,
		"fill": clampi(int(raw.get("fill", 50)), 0, 100),
		"groove": clampi(int(raw.get("groove", 50)), 0, 100),
		"density": clampi(int(raw.get("density", 50)), 0, 100),
		"grid_snap_strength": clampi(int(raw.get("grid_snap_strength", 50)), 0, 100),
		"accent_strong_beats": bool(raw.get("accent_strong_beats", false)),
		"genre_template_strength": clampi(int(raw.get("genre_template_strength", 50)), 0, 100),
		"enable_genre_detection": bool(raw.get("enable_genre_detection", true)),
		"use_stems_in_generation": bool(raw.get("use_stems_in_generation", true)),
		"include_hi_hats": bool(raw.get("include_hi_hats", true)),
		"critic_strength": clampi(int(raw.get("critic_strength", 50)), 0, 100),
		"groove_completion": bool(raw.get("groove_completion", true)),
		"raw_adtof": bool(raw.get("raw_adtof", false)),
		"favorite": bool(raw.get("favorite", false)),
		"updated_at": int(raw.get("updated_at", 0)),
		"use_count": maxi(0, int(raw.get("use_count", 0))),
	}


static func is_generation_slot_filled(presets: Dictionary, slot: int) -> bool:
	var entry: Variant = presets.get("slots", {}).get(slot_key(slot), null)
	return entry is Dictionary and not str(entry.get("name", "")).strip_edges().is_empty()


static func get_generation_slot(presets: Dictionary, slot: int) -> Dictionary:
	var entry: Variant = presets.get("slots", {}).get(slot_key(slot), null)
	if entry is Dictionary:
		return sanitize_generation_slot(entry)
	return {}


static func default_generation_slot_name(slot: int) -> String:
	return TranslationServer.translate("GEN_PRESET_SLOT_DEFAULT") % slot


static func generation_display_name(presets: Dictionary, slot: int) -> String:
	if not is_generation_slot_filled(presets, slot):
		return TranslationServer.translate("MOD_PRESET_SLOT_EMPTY")
	var entry := get_generation_slot(presets, slot)
	var name := str(entry.get("name", "")).strip_edges()
	if name == "":
		return default_generation_slot_name(slot)
	return name


static func make_generation_slot(snapshot: Dictionary, favorite: bool = false, use_count: int = 0, updated_at: int = 0) -> Dictionary:
	var sanitized := sanitize_generation_slot(snapshot)
	sanitized["favorite"] = favorite
	sanitized["updated_at"] = updated_at if updated_at > 0 else int(Time.get_unix_time_from_system())
	sanitized["use_count"] = maxi(0, use_count)
	return sanitized


static func update_generation_slot_name(presets: Dictionary, slot: int, name: String) -> Dictionary:
	if not is_generation_slot_filled(presets, slot):
		return sanitize_generation_presets(presets)
	var out := sanitize_generation_presets(presets)
	var key := slot_key(slot)
	var entry := get_generation_slot(out, slot)
	var slot_name := _sanitize_name(name)
	if slot_name == "":
		slot_name = default_generation_slot_name(slot)
	entry["name"] = slot_name
	entry["updated_at"] = int(Time.get_unix_time_from_system())
	out["slots"][key] = entry
	return out


static func save_generation_slot(
	presets: Dictionary,
	slot: int,
	name: String,
	snapshot: Dictionary,
	keep_meta: Dictionary = {}
) -> Dictionary:
	var out := sanitize_generation_presets(presets)
	var key := slot_key(slot)
	var prev := get_generation_slot(out, slot)
	var slot_name := _sanitize_name(name)
	if slot_name == "":
		slot_name = default_generation_slot_name(slot)
	var body := sanitize_generation_slot(snapshot)
	body["name"] = slot_name
	body["favorite"] = bool(keep_meta.get("favorite", prev.get("favorite", false)))
	body["use_count"] = int(keep_meta.get("use_count", prev.get("use_count", 0)))
	body["updated_at"] = int(Time.get_unix_time_from_system())
	out["slots"][key] = body
	out["active_slot"] = slot
	return out


static func delete_generation_slot(presets: Dictionary, slot: int) -> Dictionary:
	var out := sanitize_generation_presets(presets)
	out["slots"].erase(slot_key(slot))
	if int(out.get("active_slot", 0)) == slot:
		out["active_slot"] = 0
	return out


static func set_generation_slot_favorite(presets: Dictionary, slot: int, favorite: bool) -> Dictionary:
	if not is_generation_slot_filled(presets, slot):
		return sanitize_generation_presets(presets)
	var out := sanitize_generation_presets(presets)
	var key := slot_key(slot)
	var entry := get_generation_slot(out, slot)
	entry["favorite"] = favorite
	out["slots"][key] = entry
	return out


static func set_active_generation_slot(presets: Dictionary, slot: int) -> Dictionary:
	var out := sanitize_generation_presets(presets)
	if slot >= 1 and slot <= MAX_SLOTS:
		out["active_slot"] = slot
	return out


static func clear_active_generation_slot(presets: Dictionary) -> Dictionary:
	var out := sanitize_generation_presets(presets)
	out["active_slot"] = 0
	return out


static func generation_slots_for_tab(presets: Dictionary, favorites_only: bool) -> Array[int]:
	var out: Array[int] = []
	for slot in range(1, MAX_SLOTS + 1):
		if favorites_only:
			if is_generation_slot_filled(presets, slot) and bool(get_generation_slot(presets, slot).get("favorite", false)):
				out.append(slot)
		else:
			out.append(slot)
	return out


static func generation_body_from_slot(entry: Dictionary) -> Dictionary:
	var body := sanitize_generation_slot(entry)
	for meta_key in ["name", "favorite", "updated_at", "use_count"]:
		body.erase(meta_key)
	return body


static func generation_bodies_equal(a: Dictionary, b: Dictionary) -> bool:
	return generation_body_from_slot(a) == generation_body_from_slot(b)


static func current_generation_body_from_settings() -> Dictionary:
	if SettingsManager == null:
		return sanitize_generation_slot({})
	return sanitize_generation_slot({
		"instrument": SettingsManager.get_setting("last_generation_instrument", "drums"),
		"intent": SettingsManager.get_setting("last_generation_intent", "original"),
		"mode": "custom",
		"lanes": SettingsManager.get_setting("last_generation_lanes", 4),
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
	})


static func is_active_generation_preset_dirty() -> bool:
	if SettingsManager == null:
		return false
	var slot := int(SettingsManager.get_generation_presets().get("active_slot", 0))
	if slot <= 0:
		return false
	if str(SettingsManager.get_setting("last_generation_mode", "basic")).strip_edges().to_lower() != "custom":
		return false
	var presets := SettingsManager.get_generation_presets()
	if not is_generation_slot_filled(presets, slot):
		return false
	var saved := generation_body_from_slot(get_generation_slot(presets, slot))
	var current := generation_body_from_slot(current_generation_body_from_settings())
	return saved != current


static func save_active_generation_preset_body() -> void:
	if SettingsManager == null:
		return
	var slot := int(SettingsManager.get_generation_presets().get("active_slot", 0))
	if slot <= 0:
		return
	var presets := SettingsManager.get_generation_presets()
	if not is_generation_slot_filled(presets, slot):
		return
	var entry := get_generation_slot(presets, slot)
	var name := str(entry.get("name", "")).strip_edges()
	if name == "":
		name = default_generation_slot_name(slot)
	presets = save_generation_slot(presets, slot, name, current_generation_body_from_settings(), {
		"favorite": entry.get("favorite", false),
		"use_count": entry.get("use_count", 0),
	})
	SettingsManager.set_generation_presets(presets)


static func modifier_state_from_snapshot(snapshot: Dictionary) -> Dictionary:
	return {
		"modifiers": _RunModifiers.sanitize(snapshot.get("modifiers", [])),
		"params": _RunModifiers.sanitize_params(snapshot.get("params", {})),
	}


static func modifier_states_equal(a: Dictionary, b: Dictionary) -> bool:
	var left := modifier_state_from_snapshot(a)
	var right := modifier_state_from_snapshot(b)
	var left_mods: Array = left["modifiers"].duplicate()
	var right_mods: Array = right["modifiers"].duplicate()
	left_mods.sort()
	right_mods.sort()
	if left_mods != right_mods:
		return false
	return _RunModifiers.params_equal(left["params"], right["params"])
