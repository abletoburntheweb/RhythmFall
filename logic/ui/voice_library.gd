# logic/ui/voice_library.gd
extends RefCounted
class_name VoiceLibrary

## Stable microcopy variants for Museum + Song Select captions only.
## Same fact, other wording. Impersonal tone.
## Salt (usually song path) keeps the label stable for a track.


static func pick(salt: String, keys: Array, arg: Variant = null) -> String:
	if keys.is_empty():
		return ""
	var seed := absi(hash(str(salt)))
	var key := str(keys[seed % keys.size()])
	var text := TranslationServer.translate(key)
	if arg == null:
		return text
	if "%d" in text or "%s" in text or "%f" in text:
		return text % arg
	return text


static func best_rr_value(rr: int, salt: String) -> String:
	return pick("%s|best_rr" % salt, [
		"VOICE_BEST_RR_FMT_01",
		"VOICE_BEST_RR_FMT_02",
		"VOICE_BEST_RR_FMT_03",
	], rr)


static func best_rr_caption(salt: String) -> String:
	return pick("%s|best_rr_cap" % salt, [
		"VOICE_BEST_RR_CAP_01",
		"VOICE_BEST_RR_CAP_02",
		"VOICE_BEST_RR_CAP_03",
	])


static func chart_ready(salt: String) -> String:
	return pick("%s|chart_ready" % salt, [
		"VOICE_CHART_READY_01",
		"VOICE_CHART_READY_02",
		"VOICE_CHART_READY_03",
	])


static func notes_ready(salt: String) -> String:
	return pick("%s|notes_ready" % salt, [
		"VOICE_NOTES_READY_01",
		"VOICE_NOTES_READY_02",
		"VOICE_NOTES_READY_03",
	])


static func museum_first_caption(salt: String) -> String:
	return pick("%s|museum_first" % salt, [
		"VOICE_MUSEUM_FIRST_01",
		"VOICE_MUSEUM_FIRST_02",
		"VOICE_MUSEUM_FIRST_03",
	])
