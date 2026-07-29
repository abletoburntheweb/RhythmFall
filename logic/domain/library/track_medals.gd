# logic/utils/track_medals.gd
class_name TrackMedals
extends RefCounted

const _RunModifiers = preload("res://logic/domain/modifiers/run_modifiers.gd")

const ID_FIRST_CLEAR := "first_clear"
const ID_GRADE_SS := "grade_ss"
const ID_HIDDEN_CLEAR := "hidden_clear"
const ID_MODIFIER_DUO := "modifier_duo"
const ID_SUDDEN_DEATH_CLEAR := "sudden_death_clear"
const ID_HARD_MODE_CLEAR := "hard_mode_clear"
const ID_GRINDER := "grinder"
const ID_SPEED_RUN := "speed_run"

const ALL_IDS: Array[String] = [
	ID_FIRST_CLEAR,
	ID_GRADE_SS,
	ID_HIDDEN_CLEAR,
	ID_MODIFIER_DUO,
	ID_SUDDEN_DEATH_CLEAR,
	ID_HARD_MODE_CLEAR,
	ID_GRINDER,
	ID_SPEED_RUN,
]

const COUNT := 8
const GRINDER_CLEAR_COUNT := 3
const MEDAL_ICON_SIZE := 16
const MEDAL_ICON_GAP := 2

static var _medal_row_icon_cache: Dictionary = {}

# i18n: TRACK_MEDAL_<id>_TITLE / _DESC / _ABBR


static func title_i18n_key(medal_id: String) -> String:
	return "TRACK_MEDAL_%s_TITLE" % medal_id


static func desc_i18n_key(medal_id: String) -> String:
	return "TRACK_MEDAL_%s_DESC" % medal_id


static func abbr_i18n_key(medal_id: String) -> String:
	return "TRACK_MEDAL_%s_ABBR" % medal_id


static func icon_path(medal_id: String) -> String:
	match medal_id:
		ID_FIRST_CLEAR:
			return "res://assets/icons/flag.svg"
		ID_GRADE_SS:
			return "res://assets/icons/crown.svg"
		ID_HIDDEN_CLEAR:
			return "res://assets/icons/eye-off.svg"
		ID_MODIFIER_DUO:
			return "res://assets/icons/layers-2.svg"
		ID_SUDDEN_DEATH_CLEAR:
			return "res://assets/icons/skull.svg"
		ID_HARD_MODE_CLEAR:
			return "res://assets/icons/flame.svg"
		ID_GRINDER:
			return "res://assets/icons/repeat.svg"
		ID_SPEED_RUN:
			return "res://assets/icons/fast-forward.svg"
		_:
			return ""


static func sanitize_unlocked(raw: Variant) -> Array[String]:
	var out: Array[String] = []
	if raw is Array:
		for item in raw:
			var sid := str(item).strip_edges()
			if ALL_IDS.has(sid) and not out.has(sid):
				out.append(sid)
	return out


static func compute_unlocked(results: Array) -> Array[String]:
	var earned: Array[String] = []
	if results.size() >= 1:
		earned.append(ID_FIRST_CLEAR)
	if results.size() >= GRINDER_CLEAR_COUNT:
		earned.append(ID_GRINDER)
	for result in results:
		if not result is Dictionary:
			continue
		if str(result.get("grade", "")) == "SS":
			earned.append(ID_GRADE_SS)
		var mods: Array = result.get("modifiers", [])
		if not mods is Array:
			mods = []
		for medal_id in _modifier_medals_from_run(mods):
			if not earned.has(medal_id):
				earned.append(medal_id)
	return sanitize_unlocked(earned)


static func evaluate_run_medals(
	grade: String,
	_accuracy: float,
	_missed_notes: int,
	_total_notes: int,
	modifiers: Array
) -> Array[String]:
	var earned: Array[String] = [ID_FIRST_CLEAR]
	if grade == "SS":
		earned.append(ID_GRADE_SS)
	for medal_id in _modifier_medals_from_run(modifiers):
		if not earned.has(medal_id):
			earned.append(medal_id)
	return sanitize_unlocked(earned)


static func medals_for_result(result: Dictionary) -> Array[String]:
	if result.get("medals_new") is Array:
		var stored := sanitize_unlocked(result["medals_new"])
		if not stored.is_empty():
			return stored
	var grade := str(result.get("grade", ""))
	var modifiers: Variant = result.get("modifiers", [])
	if not modifiers is Array:
		modifiers = []
	return evaluate_run_medals(grade, 0.0, 0, 0, modifiers)


static func tooltip_for_medals(medal_ids: Array[String]) -> String:
	var lines: PackedStringArray = []
	for medal_id in medal_ids:
		if not ALL_IDS.has(medal_id):
			continue
		lines.append("%s — %s" % [
			TranslationServer.translate(title_i18n_key(medal_id)),
			TranslationServer.translate(desc_i18n_key(medal_id)),
		])
	return "\n".join(lines)


static func build_medals_row_icon(medal_ids: Array[String]) -> Texture2D:
	var ordered := sanitize_unlocked(medal_ids)
	if ordered.is_empty():
		return null
	var cache_key := ",".join(ordered)
	if _medal_row_icon_cache.has(cache_key):
		return _medal_row_icon_cache[cache_key]
	var icon_px := MEDAL_ICON_SIZE
	var gap := MEDAL_ICON_GAP
	var width := ordered.size() * icon_px + maxi(ordered.size() - 1, 0) * gap
	var height := icon_px
	var image := Image.create(width, height, false, Image.FORMAT_RGBA8)
	image.fill(Color(0, 0, 0, 0))
	var x := 0
	for medal_id in ordered:
		var path := icon_path(medal_id)
		if path == "":
			continue
		var tex := load(path) as Texture2D
		if tex == null:
			continue
		var src := tex.get_image()
		if src == null or src.is_empty():
			continue
		if src.get_width() != icon_px or src.get_height() != icon_px:
			src = src.duplicate()
			src.resize(icon_px, icon_px, Image.INTERPOLATE_LANCZOS)
		image.blit_rect(src, Rect2i(0, 0, icon_px, icon_px), Vector2i(x, 0))
		x += icon_px + gap
	if x <= 0:
		return null
	var out := ImageTexture.create_from_image(image)
	_medal_row_icon_cache[cache_key] = out
	return out


static func _modifier_medals_from_run(modifiers: Array) -> Array[String]:
	var earned: Array[String] = []
	var mods := _RunModifiers.sanitize(modifiers)
	if _RunModifiers.has_modifier(mods, _RunModifiers.ID_HIDDEN):
		earned.append(ID_HIDDEN_CLEAR)
	if _RunModifiers.has_modifier(mods, _RunModifiers.ID_SUDDEN_DEATH):
		earned.append(ID_SUDDEN_DEATH_CLEAR)
	if _challenge_mod_count(mods) >= 2:
		earned.append(ID_MODIFIER_DUO)
	if _has_hardening_mod(mods):
		earned.append(ID_HARD_MODE_CLEAR)
	if _is_speed_run_mod(mods):
		earned.append(ID_SPEED_RUN)
	return earned


static func _challenge_mod_count(mods: Array[String]) -> int:
	var count := 0
	for mod_id in mods:
		if mod_id != _RunModifiers.ID_AUTOPLAY:
			count += 1
	return count


static func _has_hardening_mod(mods: Array[String]) -> bool:
	for mod_id in mods:
		if _RunModifiers.HARDENING_IDS.has(mod_id):
			return true
	return false


static func _is_speed_run_mod(mods: Array[String]) -> bool:
	return (
		_RunModifiers.has_modifier(mods, _RunModifiers.ID_FAST_150)
		or _RunModifiers.has_modifier(mods, _RunModifiers.ID_SUDDEN)
	)
