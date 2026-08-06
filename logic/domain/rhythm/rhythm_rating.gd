# logic/domain/rhythm/rhythm_rating.gd
class_name RhythmRating
extends RefCounted

const _RunModifiers = preload("res://logic/domain/modifiers/run_modifiers.gd")
const _ChartDifficulty = preload("res://logic/domain/charts/chart_difficulty_analyzer.gd")
const _GenerationIntents = preload("res://logic/domain/generation/generation_intents.gd")

const ACCURACY_WEIGHT := 8.0
const CHART_RATING_WEIGHT := 92.0
const FULL_COMBO_BONUS := 150.0
const GLOBAL_OUTPUT_SCALE := 0.92

const GRADE_BONUS := {
	"SS": 115.0,
	"S": 62.0,
	"A": 24.0,
	"B": 8.0,
}


static func normalize_instrument(instrument: String) -> String:
	var key := instrument.strip_edges().to_lower()
	match key:
		"drums", "перкуссия", "ударные", "ударные инструменты":
			return "drums"
		"bass", "бас", "бас-гитара", "бас гитара":
			return "bass"
		"fullmix", "микс", "full mix":
			return "fullmix"
		"standard", "стандарт":
			return "standard"
		_:
			return key if key != "" else "standard"


static func normalize_mode(mode: String) -> String:
	var key := mode.strip_edges().to_lower()
	if key == "":
		key = "basic"
	# Canonical chart stem (arcade_dense, original, …) so legacy aliases share one RR bucket.
	return _GenerationIntents.resolve_chart_stem(key)


static func chart_key(
	song_path: String,
	instrument: String,
	mode: String,
	lanes: int,
	modifiers: Array
) -> String:
	var path := song_path.replace("\\", "/").trim_suffix("/")
	var mods := _RunModifiers.sanitize(modifiers)
	mods.sort()
	var mod_part := ",".join(mods)
	return "%s|%s|%s|%d|%s" % [
		path,
		normalize_instrument(instrument),
		normalize_mode(mode),
		maxi(lanes, 1),
		mod_part,
	]


static func grade_bonus(grade: String) -> float:
	return float(GRADE_BONUS.get(str(grade).strip_edges().to_upper(), 0.0))


static func mod_combo_hardness(modifiers: Array) -> float:
	var total := 0.0
	for id in _RunModifiers.sanitize(modifiers):
		if id == _RunModifiers.ID_AUTOPLAY:
			continue
		var delta := float(_RunModifiers.REWARD_DELTA.get(id, 0.0))
		if delta > 0.0:
			total += delta
	return total


static func countable_mod_count(modifiers: Array) -> int:
	var mods := _RunModifiers.sanitize(modifiers)
	if mods.has(_RunModifiers.ID_AUTOPLAY):
		return 0
	return mods.size()


static func compute(
	accuracy: float,
	chart_rating: int,
	grade: String,
	full_combo: bool,
	modifiers: Array,
	params: Dictionary = {}
) -> int:
	if _RunModifiers.blocks_track_result_save(modifiers):
		return 0
	var base := accuracy * ACCURACY_WEIGHT
	base += float(maxi(chart_rating, 0)) * CHART_RATING_WEIGHT
	base += grade_bonus(grade)
	if full_combo:
		base += FULL_COMBO_BONUS
	var mult := _RunModifiers.score_multiplier(modifiers, params)
	return int(round(base * mult * GLOBAL_OUTPUT_SCALE))


static func is_improvement(run_rr: int, previous_best_rr: int) -> bool:
	return run_rr > previous_best_rr


static func resolve_chart_rating(song_path: String, instrument: String, mode: String, lanes: int) -> int:
	if song_path == "":
		return 0
	var inst := normalize_instrument(instrument)
	var m := normalize_mode(mode)
	var l := maxi(lanes, 1)
	var rating := _ChartDifficulty.get_run_rating(song_path, inst, m, l)
	if rating > 0:
		return rating
	rating = _ChartDifficulty.get_cached_rating(song_path, inst, m, l)
	if rating > 0:
		return rating
	for try_inst in ["drums", "standard", "fullmix"]:
		for try_mode in ["basic", "advanced", "expert"]:
			for try_lanes in [4, 5, 6, 7, 8]:
				rating = _ChartDifficulty.get_cached_rating(song_path, try_inst, try_mode, try_lanes)
				if rating > 0:
					return rating
	return 0
