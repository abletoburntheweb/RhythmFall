# logic/score_manager.gd
extends RefCounted

var score: int = 0
var raw_score: int = 0
var combo: int = 0
var max_combo: int = 0
var combo_multiplier: float = 1.0
var base_perfect_points: int = 100
var base_good_points: int = 50
var total_notes: int = 0
var missed_notes: int = 0
var hit_notes: int = 0
var accuracy: float = 100.0
var game_screen
var score_reward_multiplier: float = 1.0

func _init(screen):
	game_screen = screen

func set_score_reward_multiplier(mult: float) -> void:
	score_reward_multiplier = maxf(0.0, mult)
	_sync_score_from_raw()

func _scaled_total() -> int:
	if score_reward_multiplier <= 0.0:
		return 0
	return max(0, int(round(float(raw_score) * score_reward_multiplier)))

func _sync_score_from_raw() -> void:
	score = _scaled_total()

func _base_points(base_points: int) -> int:
	return int(float(base_points) * combo_multiplier)

func add_perfect_hit() -> int:
	combo_multiplier = min(4.0, 1.0 + float(int(combo / 10)))
	combo += 1
	max_combo = max(max_combo, combo)
	var base_final := _base_points(base_perfect_points)
	raw_score += base_final
	_sync_score_from_raw()
	hit_notes += 1
	update_accuracy()
	print("[ScoreManager] PERFECT hit! +%d raw | total %d (mod x%.2f) | Combo: %d" % [base_final, score, score_reward_multiplier, combo])
	return base_final

func add_good_hit() -> int:
	combo += 1
	max_combo = max(max_combo, combo)
	var base_final := _base_points(base_good_points)
	raw_score += base_final
	_sync_score_from_raw()
	hit_notes += 1
	update_accuracy()
	print("[ScoreManager] GOOD hit! +%d -> scaled total %d | Combo: %d" % [base_final, score, combo])
	return base_final

func add_hold_sustain_points(amount: int = 8) -> int:
	var pts := maxi(0, amount)
	if pts <= 0:
		return 0
	raw_score += pts
	_sync_score_from_raw()
	return pts

func add_bonus_points(amount: int) -> int:
	var bonus := maxi(0, amount)
	if bonus <= 0:
		return 0
	raw_score += bonus
	_sync_score_from_raw()
	return bonus

func add_miss_hit() -> int:
	missed_notes += 1
	reset_combo()
	update_accuracy()
	print("[ScoreManager] Miss! Combo reset, accuracy: %.2f%%" % accuracy)
	return 0

func reset_combo():
	if combo > 0:
		print("[ScoreManager] Combo reset! Was: %d" % combo)
	combo = 0
	combo_multiplier = 1.0

func get_combo_multiplier() -> float:
	return combo_multiplier

func get_score() -> int:
	return score

func set_raw_score(value: int) -> void:
	raw_score = maxi(0, value)
	_sync_score_from_raw()

func get_score_reward_multiplier() -> float:
	return score_reward_multiplier

func get_raw_score() -> int:
	return raw_score

func get_combo() -> int:
	return combo

func get_max_combo() -> int:
	return max_combo

func set_total_notes(total: int):
	total_notes = total
	print("ScoreManager: Установлено total_notes: %d" % total_notes)
	update_accuracy()

func update_accuracy():
	var played_notes = hit_notes + missed_notes
	if played_notes <= 0:
		accuracy = 100.0
	else:
		accuracy = (float(hit_notes) / float(played_notes)) * 100.0
	accuracy = clamp(accuracy, 0.0, 100.0)

func get_accuracy() -> float:
	return accuracy

func get_missed_notes_count() -> int:
	return missed_notes

func get_hit_notes_count() -> int:
	return hit_notes

func set_accuracy(new_accuracy: float):
	accuracy = clampf(new_accuracy, 0.0, 100.0)
	print("ScoreManager: Точность установлена вручную: %.1f%%" % accuracy)

func reset():
	raw_score = 0
	score = 0
	combo = 0
	max_combo = 0
	combo_multiplier = 1.0
	missed_notes = 0
	hit_notes = 0
	total_notes = 0
	accuracy = 100.0


func capture_rewind_snapshot() -> Dictionary:
	return {
		"raw_score": raw_score,
		"combo": combo,
		"max_combo": max_combo,
		"combo_multiplier": combo_multiplier,
		"hit_notes": hit_notes,
		"missed_notes": missed_notes,
		"accuracy": accuracy,
	}


func restore_rewind_snapshot(snap: Dictionary) -> void:
	if snap.is_empty():
		return
	raw_score = maxi(0, int(snap.get("raw_score", 0)))
	_sync_score_from_raw()
	combo = maxi(0, int(snap.get("combo", 0)))
	max_combo = maxi(0, int(snap.get("max_combo", 0)))
	combo_multiplier = maxf(1.0, float(snap.get("combo_multiplier", 1.0)))
	hit_notes = maxi(0, int(snap.get("hit_notes", 0)))
	missed_notes = maxi(0, int(snap.get("missed_notes", 0)))
	accuracy = clampf(float(snap.get("accuracy", 100.0)), 0.0, 100.0)


## After chart rewind: keep hits/combo earned before pause; allow retrying misses after rewind point.
func apply_rewind_score_floor(floor: Dictionary) -> void:
	if floor.is_empty():
		return
	combo = maxi(0, int(floor.get("combo", combo)))
	combo_multiplier = minf(4.0, 1.0 + float(int(combo / 10)))
	hit_notes = maxi(hit_notes, int(floor.get("hit_notes", 0)))
	raw_score = maxi(raw_score, int(floor.get("raw_score", 0)))
	_sync_score_from_raw()
	max_combo = maxi(max_combo, int(floor.get("max_combo", 0)))
	update_accuracy()
