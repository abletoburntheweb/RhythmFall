# logic/platform/locale_detect.gd
extends RefCounted
class_name LocaleDetect

## First-run language: Russian keyboard or OS locale → ru, otherwise en.


static func detect_initial_language() -> String:
	if _locale_indicates_russian(_keyboard_locale_hint()):
		return "ru"
	if _locale_indicates_russian(_os_locale_hint()):
		return "ru"
	return "en"


static func _keyboard_locale_hint() -> String:
	var layout_idx := DisplayServer.keyboard_get_current_layout()
	return String(DisplayServer.keyboard_get_layout_name(layout_idx)).strip_edges()


static func _os_locale_hint() -> String:
	var lang := String(OS.get_locale_language()).strip_edges()
	if lang != "":
		return lang
	return String(OS.get_locale()).strip_edges()


static func _locale_indicates_russian(raw: String) -> bool:
	var s := raw.strip_edges().to_lower().replace("-", "_")
	if s == "":
		return false
	if s == "ru" or s.begins_with("ru_"):
		return true
	if s.contains("russian") or s.contains("рус"):
		return true
	return false
