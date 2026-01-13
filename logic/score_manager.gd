# logic/score_manager.gd
extends RefCounted

var score: int = 0
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

func _init(screen):
	game_screen = screen

func add_perfect_hit() -> int:
	combo_multiplier = min(4.0, 1.0 + float(int(combo / 10))) 
	combo += 1
	max_combo = max(max_combo, combo)
	var final_points = int(base_perfect_points * combo_multiplier)
	score += final_points
	hit_notes += 1
	update_accuracy() 
	print("[ScoreManager] PERFECT hit! +%d -> %d (x%.1f) | Combo: %d | Total: %d" % [base_perfect_points, final_points, combo_multiplier, combo, score])
	return final_points

func add_good_hit() -> int:
	combo += 1
	max_combo = max(max_combo, combo)
	var final_points = int(base_good_points * combo_multiplier) 
	score += final_points
	hit_notes += 1
	update_accuracy() 
	print("[ScoreManager] GOOD hit! +%d -> %d (x%.1f) | Combo: %d | Total: %d" % [base_good_points, final_points, combo_multiplier, combo, score])
	return final_points

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

func get_combo() -> int:
	return combo

func get_max_combo() -> int:
	return max_combo

func set_total_notes(total: int):
	total_notes = total
	print("ScoreManager: Установлено total_notes: %d" % total_notes)
	update_accuracy()

func update_accuracy():
	print("[ScoreManager] update_accuracy вызван: missed_notes=%d (%s), total_notes=%d (%s)" % [missed_notes, typeof(missed_notes), total_notes, typeof(total_notes)])
	if total_notes == 0:
		accuracy = 100.0
	else:
		var intermediate_calc = (float(missed_notes) / total_notes) * 100
		print("[ScoreManager] Промежуточный расчёт (missed_notes / total_notes) * 100 = (%d / %d) * 100 = %.6f" % [missed_notes, total_notes, intermediate_calc])
		accuracy = max(0.0, 100.0 - intermediate_calc)
		print("[ScoreManager] Рассчитанная точность (до max): %.6f" % (100.0 - intermediate_calc))
	accuracy = clamp(accuracy, 0.0, 100.0)
	print("[ScoreManager] Установленная точность (accuracy): %.6f" % accuracy)
	print("[ScoreManager] Рассчитанная точность: %.2f%% (из %d промахов из %d)" % [accuracy, missed_notes, total_notes])

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
	score = 0
	combo = 0
	max_combo = 0
	combo_multiplier = 1.0
	missed_notes = 0
	hit_notes = 0
	total_notes = 0
	accuracy = 100.0
