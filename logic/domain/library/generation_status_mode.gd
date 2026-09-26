# logic/domain/library/generation_status_mode.gd
extends RefCounted
class_name GenerationStatusMode

const OFF := "off"
const COMPACT := "compact"
const FULL := "full"

const SETTING_KEY := "generation_status_mode"
const LEGACY_BOOL_KEY := "show_generation_notifications"


static func from_settings() -> String:
	var raw: Variant = SettingsManager.get_setting(SETTING_KEY, "")
	var mode := String(raw).strip_edges().to_lower()
	if mode == OFF or mode == COMPACT or mode == FULL:
		return mode
	if SettingsManager.get_setting(LEGACY_BOOL_KEY, true):
		return FULL
	return OFF


static func is_enabled() -> bool:
	return from_settings() != OFF


static func is_full() -> bool:
	return from_settings() == FULL


static func is_compact() -> bool:
	return from_settings() == COMPACT
