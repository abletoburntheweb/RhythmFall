# logic/domain/rewards/run_rewards.gd
class_name RunRewards
extends RefCounted

const _RunModifiers = preload("res://logic/domain/modifiers/run_modifiers.gd")
const _MarathonSessionConfig = preload("res://logic/domain/session/marathon_session_config.gd")

const ENDLESS_TRACK_REWARD_SCALE := 0.22
const ENDLESS_RUN_XP_CAP := 380
const ENDLESS_RUN_CURRENCY_CAP := 240

const MARATHON_XP_PER_TRACK := 12
const MARATHON_CURRENCY_PER_TRACK := 8
const MARATHON_XP_PER_DIFFICULTY := 18.0
const MARATHON_CURRENCY_PER_DIFFICULTY := 12.0


static func compute_grade(accuracy: float) -> String:
	if accuracy >= 100.0:
		return "SS"
	if accuracy >= 95.0:
		return "S"
	if accuracy >= 90.0:
		return "A"
	if accuracy >= 80.0:
		return "B"
	if accuracy >= 70.0:
		return "C"
	if accuracy >= 60.0:
		return "D"
	return "F"


static func compute_combo_multiplier(max_combo: int) -> float:
	return minf(4.0, 1.0 + floor(float(max_combo) / 10.0))


static func compute_track_rewards(stats: Dictionary) -> Dictionary:
	var modifiers: Array = stats.get("modifiers", [])
	if _RunModifiers.blocks_track_result_save(modifiers):
		return {"xp": 0, "currency": 0}

	var score := int(stats.get("score", 0))
	var accuracy := float(stats.get("accuracy", 0.0))
	var max_combo := int(stats.get("max_combo", 0))
	var missed_notes := int(stats.get("missed_notes", 0))
	var hit_notes := int(stats.get("hit_notes", 0))
	var total_notes := int(stats.get("total_notes", hit_notes + missed_notes))
	var combo_multiplier := float(stats.get("combo_multiplier", compute_combo_multiplier(max_combo)))

	var xp := _compute_xp(score, accuracy, max_combo, missed_notes, total_notes)
	var currency := _compute_currency(score, accuracy, max_combo, missed_notes, total_notes, combo_multiplier)
	return {"xp": xp, "currency": currency}


static func _compute_xp(
	score: int,
	accuracy: float,
	max_combo: int,
	missed_notes: int,
	total_notes: int
) -> int:
	var base_xp := sqrt(float(score)) * 1.2

	var accuracy_bonus := 0.0
	if accuracy >= 100.0:
		accuracy_bonus = 20.0
	elif accuracy >= 98.0:
		accuracy_bonus = 12.0
	elif accuracy >= 95.0:
		accuracy_bonus = 7.0
	elif accuracy >= 90.0:
		accuracy_bonus = 2.0

	var combo_bonus := 0.0
	if max_combo > 0:
		combo_bonus = log(float(max_combo) + 1.0) * 6.0

	var grade_bonus := 0.0
	match compute_grade(accuracy):
		"SS":
			grade_bonus = 50.0
		"S":
			grade_bonus = 25.0
		"A":
			grade_bonus = 10.0
		"B":
			grade_bonus = 3.0

	var full_combo_bonus := 0.0
	if missed_notes == 0 and total_notes > 0:
		full_combo_bonus = 15.0

	return maxi(1, int(base_xp + accuracy_bonus + combo_bonus + grade_bonus + full_combo_bonus))


static func _compute_currency(
	score: int,
	accuracy: float,
	max_combo: int,
	missed_notes: int,
	total_notes: int,
	combo_multiplier: float
) -> int:
	var base_currency := sqrt(float(score)) * 0.9

	var combo_bonus := 0.0
	if max_combo > 0:
		combo_bonus = log(float(max_combo) + 1.0) * 3.0

	var accuracy_bonus := 0.0
	if accuracy >= 100.0:
		accuracy_bonus = 20.0
	elif accuracy >= 95.0:
		accuracy_bonus = (accuracy - 90.0) * 0.5

	var full_combo_bonus := 0.0
	if missed_notes == 0 and total_notes > 0:
		full_combo_bonus = 10.0

	var multiplier_bonus := (combo_multiplier - 1.0) * 2.0
	var total_currency := base_currency + combo_bonus + accuracy_bonus + full_combo_bonus + multiplier_bonus
	return maxi(1, int(round(total_currency)))


static func compute_endless_track_rewards(stats: Dictionary) -> Dictionary:
	var base := compute_track_rewards(stats)
	return {
		"xp": maxi(0, int(round(float(base.get("xp", 0)) * ENDLESS_TRACK_REWARD_SCALE))),
		"currency": maxi(0, int(round(float(base.get("currency", 0)) * ENDLESS_TRACK_REWARD_SCALE))),
	}


static func finalize_endless_run_rewards(xp: int, currency: int, tracks_cleared: int) -> Dictionary:
	if tracks_cleared <= 0:
		return {"xp": 0, "currency": 0}
	var bonus_xp := mini(36, tracks_cleared * 2)
	var bonus_currency := mini(24, tracks_cleared)
	return {
		"xp": mini(ENDLESS_RUN_XP_CAP, maxi(0, xp) + bonus_xp),
		"currency": mini(ENDLESS_RUN_CURRENCY_CAP, maxi(0, currency) + bonus_currency),
	}


static func compute_marathon_completion_rewards(
	template: Dictionary,
	run_config: Dictionary,
	total_tracks: int,
) -> Dictionary:
	var tracks := maxi(1, total_tracks)
	var diff_min := float(template.get("difficulty_min", 2.0))
	var diff_max := float(template.get("difficulty_max", 7.0))
	var avg_diff := (diff_min + diff_max) * 0.5
	var length_mult := _marathon_length_reward_multiplier(str(template.get("length_class", "standard")))
	var base_xp := float(tracks * MARATHON_XP_PER_TRACK) + avg_diff * MARATHON_XP_PER_DIFFICULTY
	var base_currency := float(tracks * MARATHON_CURRENCY_PER_TRACK) + avg_diff * MARATHON_CURRENCY_PER_DIFFICULTY
	var mod_mult := _MarathonSessionConfig.mod_reward_multiplier(run_config)
	return {
		"xp": maxi(15, int(round(base_xp * length_mult * mod_mult))),
		"currency": maxi(10, int(round(base_currency * length_mult * mod_mult))),
	}


static func _marathon_length_reward_multiplier(length_class: String) -> float:
	match length_class.strip_edges().to_lower():
		"sprint":
			return 0.85
		"short":
			return 0.9
		"standard":
			return 1.0
		"long", "epic":
			return 1.2
		_:
			return 1.0
