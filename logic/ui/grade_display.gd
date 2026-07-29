# logic/utils/grade_display.gd
class_name GradeDisplay
extends RefCounted

const COLOR_SS_FIRST := Color("#F2B35A")
const COLOR_SS_REPEAT := Color("#2EE59D")
const COLOR_S := Color("#C8D2E6")
const COLOR_A := Color("#6B91D2")
const COLOR_B := Color("#59D1BE")
const COLOR_C := Color("#A58EDB")
const COLOR_D := Color("#D56B87")
const COLOR_F := Color("#8A2F39")


static func normalize_track_path(song_path: String) -> String:
	return song_path.replace("\\", "/").trim_suffix("/")


static func is_repeat_ss_on_track(song_path: String) -> bool:
	if song_path.is_empty() or TrackStatsManager == null:
		return false
	return TrackStatsManager.get_ss_count(normalize_track_path(song_path)) > 0


static func ss_display_color(is_repeat: bool) -> Color:
	return COLOR_SS_REPEAT if is_repeat else COLOR_SS_FIRST


static func grade_color(grade: String, is_repeat_ss: bool = false) -> Color:
	if grade == "SS":
		return ss_display_color(is_repeat_ss)
	match grade:
		"S": return COLOR_S
		"A": return COLOR_A
		"B": return COLOR_B
		"C": return COLOR_C
		"D": return COLOR_D
		"F": return COLOR_F
		_: return Color.WHITE


static func best_grade_for_track(song_path: String) -> String:
	if song_path.is_empty():
		return ""
	var normalized := normalize_track_path(song_path)
	if TrackStatsManager:
		var from_stats := str(TrackStatsManager.best_grades_per_track.get(normalized, ""))
		if from_stats != "":
			return from_stats
	if PlayerDataManager:
		var from_player := str(PlayerDataManager.data.get("best_grades_per_track", {}).get(song_path, ""))
		if from_player != "":
			return from_player
		return str(PlayerDataManager.data.get("best_grades_per_track", {}).get(normalized, ""))
	return ""


static func color_for_track_best(song_path: String) -> Color:
	var best := best_grade_for_track(song_path)
	if best == "":
		return Color.WHITE
	if best == "SS":
		var count := 0
		if TrackStatsManager:
			count = TrackStatsManager.get_ss_count(normalize_track_path(song_path))
		return ss_display_color(count > 1)
	return grade_color(best)


static func color_from_saved_result(result: Dictionary) -> Color:
	var grade := str(result.get("grade", "N/A"))
	if grade == "SS":
		if bool(result.get("ss_repeat", false)):
			return COLOR_SS_REPEAT
		if result.has("ss_repeat") and not bool(result.get("ss_repeat", false)):
			return COLOR_SS_FIRST
		var saved: Variant = _read_saved_color(result.get("grade_color", null))
		if saved is Color:
			return saved
		return COLOR_SS_FIRST
	var saved_other: Variant = _read_saved_color(result.get("grade_color", null))
	if saved_other is Color:
		return saved_other
	return grade_color(grade)


static func _read_saved_color(saved: Variant) -> Variant:
	if saved is Dictionary and saved.has("r"):
		return Color(
			float(saved.get("r", 1.0)),
			float(saved.get("g", 1.0)),
			float(saved.get("b", 1.0)),
			float(saved.get("a", 1.0))
		)
	return null
