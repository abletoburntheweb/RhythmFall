# scenes/song_select/run_modifiers/run_modifier_sections.gd
extends RefCounted
class_name RunModifierSections

const _RunModifiers = preload("res://logic/domain/modifiers/run_modifiers.gd")

const CARD_OVERVIEW := Vector2(124, 124)
const CARD_CATEGORY := Vector2(140, 140)

const EASE_SPEED: Array = [
	[_RunModifiers.ID_SLOW_75, "MOD_ABBR_HT"],
]
const EASE_HELP: Array = [
	[_RunModifiers.ID_NO_FAIL, "MOD_ABBR_NF"],
	[_RunModifiers.ID_EASY_WINDOWS, "MOD_ABBR_EZ"],
]

const HARD_SPEED: Array = [
	[_RunModifiers.ID_FAST_150, "MOD_ABBR_DT"],
	[_RunModifiers.ID_HEAT, "MOD_ABBR_HE"],
	[_RunModifiers.ID_RUSH, "MOD_ABBR_RU"],
]
const HARD_TIMING: Array = [
	[_RunModifiers.ID_STRICT_TIMING, "MOD_ABBR_ST"],
	[_RunModifiers.ID_NO_MISS_FORGIVENESS, "MOD_ABBR_EH"],
	[_RunModifiers.ID_SUDDEN_DEATH, "MOD_ABBR_SD"],
	[_RunModifiers.ID_HALF_HP, "MOD_ABBR_HP"],
]
const HARD_VISIBILITY: Array = [
	[_RunModifiers.ID_HIDDEN, "MOD_ABBR_HD"],
	[_RunModifiers.ID_SUDDEN, "MOD_ABBR_SN"],
	[_RunModifiers.ID_MEMORY_MODE, "MOD_ABBR_MM"],
	[_RunModifiers.ID_SPOTLIGHT, "MOD_ABBR_SP"],
]
const HARD_LANES: Array = [
	[_RunModifiers.ID_MIRROR_MODE, "MOD_ABBR_MR"],
	[_RunModifiers.ID_SHUFFLE_MODE, "MOD_ABBR_SF"],
	[_RunModifiers.ID_RANDOM_MODE, "MOD_ABBR_RN"],
]
const HARD_AUDIO: Array = [
	[_RunModifiers.ID_SILENCE, "MOD_ABBR_SI"],
]

const SPECIAL_LANES: Array = [
	[_RunModifiers.ID_SINGLE_LANE, "MOD_ABBR_SL"],
]
const DNA_STRUCTURE: Array = [
	[_RunModifiers.ID_DYNAMIC_LANES, "MOD_ABBR_DL"],
]
const DNA_PULSE: Array = [
	[_RunModifiers.ID_ENERGY_PULSE, "MOD_ABBR_EP"],
	[_RunModifiers.ID_ENERGY_BALANCE, "MOD_ABBR_EB"],
]
const DNA_FOCUS: Array = [
	[_RunModifiers.ID_DENSITY_FOCUS, "MOD_ABBR_DF"],
]
const DNA_BEHAVIOR: Array = [
	[_RunModifiers.ID_PHRASE_SHIFT, "MOD_ABBR_PS"],
	[_RunModifiers.ID_GROOVE_LOCK, "MOD_ABBR_GL"],
	[_RunModifiers.ID_GROOVE_ADDICTION, "MOD_ABBR_GA"],
	[_RunModifiers.ID_ADAPTIVE, "MOD_ABBR_AD"],
]
const SPECIAL_SCROLL: Array = [
	[_RunModifiers.ID_TIME_WARP, "MOD_ABBR_TW"],
	[_RunModifiers.ID_REVERSE_SCROLL, "MOD_ABBR_RS"],
	[_RunModifiers.ID_FIXED_SPEED_20, "MOD_ABBR_FS"],
]
const SPECIAL_INPUT: Array = [
	[_RunModifiers.ID_PICK_MODE, "MOD_ABBR_PM"],
	[_RunModifiers.ID_AUTOPLAY, "MOD_ABBR_AP"],
]
const SPECIAL_CHAOS: Array = [
	[_RunModifiers.ID_COMBO_ESCALATION, "MOD_ABBR_CE"],
	[_RunModifiers.ID_LAST_CHANCE, "MOD_ABBR_LC"],
]
const SPECIAL_AUDIO: Array = [
	[_RunModifiers.ID_METRONOME_ONLY, "MOD_ABBR_MO"],
]

const SPECIAL_RULES: Array = SPECIAL_LANES + SPECIAL_SCROLL + SPECIAL_INPUT + SPECIAL_CHAOS + SPECIAL_AUDIO

static func ease_subsections() -> Array:
	return [
		{"key": "MOD_SUBCAT_EASE_SPEED", "specs": EASE_SPEED},
		{"key": "MOD_SUBCAT_EASE_HELP", "specs": EASE_HELP},
	]


static func hard_subsections() -> Array:
	return [
		{"key": "MOD_SUBCAT_HARD_SPEED", "specs": HARD_SPEED},
		{"key": "MOD_SUBCAT_HARD_TIMING", "specs": HARD_TIMING},
		{"key": "MOD_SUBCAT_HARD_VISIBILITY", "specs": HARD_VISIBILITY},
		{"key": "MOD_SUBCAT_HARD_LANES", "specs": HARD_LANES},
		{"key": "MOD_SUBCAT_HARD_AUDIO", "specs": HARD_AUDIO},
	]


static func special_subsections() -> Array:
	return [
		{"key": "MOD_SUBCAT_SPECIAL_LANES", "specs": SPECIAL_LANES},
		{"key": "MOD_SUBCAT_SPECIAL_SCROLL", "specs": SPECIAL_SCROLL},
		{"key": "MOD_SUBCAT_SPECIAL_INPUT", "specs": SPECIAL_INPUT},
		{"key": "MOD_SUBCAT_SPECIAL_CHAOS", "specs": SPECIAL_CHAOS},
		{"key": "MOD_SUBCAT_SPECIAL_AUDIO", "specs": SPECIAL_AUDIO},
	]


static func dna_subsections() -> Array:
	return [
		{"key": "MOD_SUBCAT_DNA_STRUCTURE", "specs": DNA_STRUCTURE},
		{"key": "MOD_SUBCAT_DNA_PULSE", "specs": DNA_PULSE},
		{"key": "MOD_SUBCAT_DNA_FOCUS", "specs": DNA_FOCUS},
		{"key": "MOD_SUBCAT_DNA_BEHAVIOR", "specs": DNA_BEHAVIOR},
	]


static func overview_groups() -> Array:
	return [
		{
			"header_key": "MOD_CAT_EASING",
			"header_color": Color(0.55, 0.92, 0.62, 1.0),
			"subsections": ease_subsections(),
		},
		{
			"header_key": "MOD_CAT_HARDENING",
			"header_color": Color(0.95, 0.55, 0.45, 1.0),
			"subsections": hard_subsections(),
		},
		{
			"header_key": "MOD_CAT_SPECIAL",
			"header_color": Color(0.72, 0.78, 0.98, 1.0),
			"subsections": special_subsections(),
		},
		{
			"header_key": "MOD_CAT_DNA",
			"header_color": Color(0.98, 0.72, 0.32, 1.0),
			"subsections": dna_subsections(),
		},
	]


static func all_ease_specs() -> Array:
	return EASE_SPEED + EASE_HELP


static func all_hard_specs() -> Array:
	return HARD_SPEED + HARD_TIMING + HARD_VISIBILITY + HARD_LANES + HARD_AUDIO


static func all_special_specs() -> Array:
	return SPECIAL_RULES


static func all_dna_specs() -> Array:
	return DNA_STRUCTURE + DNA_PULSE + DNA_FOCUS + DNA_BEHAVIOR
