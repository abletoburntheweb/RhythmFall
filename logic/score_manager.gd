# logic/score_manager.gd
extends RefCounted

var score: int = 0
var combo: int = 0
var max_combo: int = 0
var combo_multiplier: float = 1.0
var base_hit_points: int = 100
var total_notes: int = 0
var missed_notes: int = 0
var accuracy: float = 100.0
var game_screen

func _init(screen):
	game_screen = screen

func add_score(hit_type: String = "perfect") -> int:
	combo_multiplier = min(4, 1 + (int(combo / 10)))
	combo += 1
	max_combo = max(max_combo, combo)
	var final_points = int(base_hit_points * combo_multiplier)
	score += final_points
	print("[ScoreManager] %s hit! +%d -> %d (x%.1f) | Combo: %d | Total: %d" % [hit_type, base_hit_points, final_points, combo_multiplier, combo, score])
	return final_points

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
	update_accuracy()

func update_accuracy():
	if total_notes == 0:
		accuracy = 100.0
	else:
		accuracy = max(0, 100 - (missed_notes / total_notes) * 100)

func add_perfect_hit() -> int:
	return add_score("perfect")

func add_good_hit() -> int:
	return add_score("good")

func add_miss_hit() -> int:
	missed_notes += 1
	reset_combo()
	update_accuracy()
	print("[ScoreManager] Miss! Combo reset, accuracy: %.2f%%" % accuracy)
	return 0

func get_accuracy() -> float:
	return accuracy
	
func get_missed_notes_count() -> int:
	return missed_notes
	
func set_accuracy(new_accuracy: float):
	accuracy = clampf(new_accuracy, 0.0, 100.0)
	print("ScoreManager: Точность установлена вручную: %.1f%%" % accuracy)
