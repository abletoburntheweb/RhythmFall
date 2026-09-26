# logic/domain/generation/generation_ready_presets.gd
extends RefCounted
class_name GenerationReadyPresets

const _UserPresets = preload("res://logic/domain/modifiers/user_presets.gd")


static func sanitize_slot_list(raw: Variant) -> Array[int]:
	var out: Array[int] = []
	if raw is Array or raw is PackedInt32Array or raw is PackedStringArray:
		for item in raw:
			var slot := int(item)
			if slot >= 1 and slot <= _UserPresets.MAX_SLOTS and not out.has(slot):
				out.append(slot)
	out.sort()
	return out


static func filled_slots(presets: Dictionary = {}) -> Array[int]:
	var src := presets
	if src.is_empty() and SettingsManager != null:
		src = SettingsManager.get_generation_presets()
	var out: Array[int] = []
	for slot in range(1, _UserPresets.MAX_SLOTS + 1):
		if _UserPresets.is_generation_slot_filled(src, slot):
			out.append(slot)
	return out


static func default_ready_slots(presets: Dictionary = {}) -> Array[int]:
	var active := int(presets.get("active_slot", 0))
	if active >= 1 and _UserPresets.is_generation_slot_filled(presets, active):
		return [active]
	return []


static func resolve_ready_slots(settings: Dictionary = {}) -> Array[int]:
	var src := settings
	if src.is_empty() and SettingsManager != null:
		src = {"generation_ready_preset_slots": SettingsManager.get_setting("generation_ready_preset_slots", [])}
	var selected := sanitize_slot_list(src.get("generation_ready_preset_slots", []))
	if selected.is_empty():
		return []
	return selected


static func is_mass(selected: Variant = null) -> bool:
	var slots := sanitize_slot_list(selected) if selected != null else resolve_ready_slots()
	return slots.size() > 1


static func slot_display_name(presets: Dictionary, slot: int) -> String:
	return _UserPresets.generation_display_name(presets, slot)


static func slot_tooltip(presets: Dictionary, slot: int) -> String:
	if not _UserPresets.is_generation_slot_filled(presets, slot):
		return ""
	var entry := _UserPresets.get_generation_slot(presets, slot)
	var name := slot_display_name(presets, slot)
	var inst := str(entry.get("instrument", "drums"))
	var intent := str(entry.get("intent", entry.get("mode", "custom"))).strip_edges()
	return "%s · %s · %s" % [name, inst, intent]
