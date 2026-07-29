# logic/domain/session/play_mode_ids.gd
class_name PlayModeIds
extends RefCounted

const LIBRARY := "library"
const ENDLESS := "endless"
const MARATHON := "marathon"

const UNLOCK_REQUIREMENTS: Dictionary = {
	LIBRARY: {},
	ENDLESS: {
		"min_level": 15,
		"diamond_cost": 5000,
		"min_medals": 35,
	},
	MARATHON: {
		"min_level": 22,
		"diamond_cost": 7500,
		"min_medals": 55,
	},
}

const ILLUSTRATION_TINTS: Dictionary = {
	LIBRARY: Color(0.28, 0.72, 0.62, 0.42),
	ENDLESS: Color(0.48, 0.32, 0.82, 0.48),
	MARATHON: Color(0.55, 0.38, 0.24, 0.44),
}

const ACCENT_COLORS: Dictionary = {
	LIBRARY: Color(0.35, 0.86, 0.76, 1.0),
	ENDLESS: Color(0.62, 0.48, 0.95, 1.0),
	MARATHON: Color(0.79, 0.57, 0.35, 1.0),  # #C9925A copper
}

const ICON_FILES: Dictionary = {
	LIBRARY: "music.svg",
	ENDLESS: "refresh-cw.svg",
	MARATHON: "flag.svg",
}

const HERO_ORBS: Dictionary = {
	LIBRARY: [
		Vector3(0.18, 0.28, 0.42),
		Vector3(0.72, 0.22, 0.34),
		Vector3(0.48, 0.62, 0.26),
	],
	ENDLESS: [
		Vector3(0.5, 0.34, 0.48),
		Vector3(0.22, 0.58, 0.3),
		Vector3(0.82, 0.48, 0.36),
		Vector3(0.64, 0.78, 0.22),
	],
	MARATHON: [
		Vector3(0.48, 0.34, 0.22),
		Vector3(0.62, 0.44, 0.28),
		Vector3(0.76, 0.54, 0.34),
	],
}


static func requirement(mode_id: String, key: String, fallback: int = 0) -> int:
	var req: Dictionary = unlock_requirements_for(mode_id)
	return int(req.get(key, fallback))


static func unlock_requirements_for(mode_id: String) -> Dictionary:
	var raw: Variant = UNLOCK_REQUIREMENTS.get(mode_id)
	if raw is Dictionary:
		return raw
	return {}


static func accent_for(mode_id: String) -> Color:
	var raw: Variant = ACCENT_COLORS.get(mode_id)
	if raw is Color:
		return raw
	return Color(0.35, 0.86, 0.76, 1.0)


static func illustration_tint_for(mode_id: String) -> Color:
	var raw: Variant = ILLUSTRATION_TINTS.get(mode_id)
	if raw is Color:
		return raw
	return accent_for(mode_id)


static func icon_for(mode_id: String) -> String:
	var raw: Variant = ICON_FILES.get(mode_id)
	if raw is String:
		return raw
	return "music.svg"


static func hero_orbs_for(mode_id: String) -> Array:
	var raw: Variant = HERO_ORBS.get(mode_id)
	if raw is Array:
		return raw
	return HERO_ORBS[LIBRARY]
