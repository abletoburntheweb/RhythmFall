# logic/domain/library/song_select_strings.gd
extends RefCounted
class_name SongSelectStrings

const _GoalDiff = preload("res://logic/domain/generation/generation_goal_difficulty.gd")


static func is_missing_metadata_value(value: Variant) -> bool:
	var s := str(value).strip_edges()
	return s == "" or s == "Н/Д" or s == "N/A" or s == "-1" or s == "0" or s == "unknown"


static func display_metadata_value(value: Variant) -> String:
	if is_missing_metadata_value(value):
		return _translate("VALUE_NA")
	return str(value).strip_edges()


static func is_default_title(value: Variant, stem: String = "") -> bool:
	var t := str(value).strip_edges()
	return t == "" or t == stem or t == "Без названия" or t == _translate("VALUE_NO_TITLE")


static func is_default_artist(value: Variant) -> bool:
	var a := str(value).strip_edges()
	return a == "" or a == "Неизвестен" or a == "Unknown" or a == _translate("VALUE_UNKNOWN_ARTIST")


static func display_track_title(value: Variant, stem: String = "") -> String:
	if is_default_title(value, stem):
		return _translate("VALUE_NO_TITLE")
	return str(value).strip_edges()


static func display_track_artist(value: Variant) -> String:
	if is_default_artist(value):
		return _translate("VALUE_UNKNOWN_ARTIST")
	return str(value).strip_edges()


static func is_cancel_message(msg: String) -> bool:
	var lower := String(msg).to_lower()
	return lower.find("cancel") != -1 or lower.find("отмен") != -1


static func is_generating_status(status: String) -> bool:
	var s := status.to_lower()
	return s.find("generat") != -1 or s.find("генерац") != -1


static func format_gen_settings_label(
	instrument: String,
	_lanes: int,
	goal: String,
	difficulty: String,
) -> String:
	# Lanes omitted: client remaps chart lanes; status/queue don't need "Б О 4" / "4 линии".
	if _GoalDiff.sanitize_goal(goal) == "original":
		return _translate("SONG_GEN_SETTINGS_FMT_ORIGINAL") % [
			_instrument_abbrev(instrument),
			_goal_abbrev(goal),
		]
	return _translate("SONG_GEN_SETTINGS_FMT4") % [
		_instrument_abbrev(instrument),
		_goal_abbrev(goal),
		_difficulty_abbrev(goal, difficulty),
	]


static func format_gen_style_button_label(
	instrument: String,
	lanes: int,
	goal: String,
	difficulty: String,
) -> String:
	# Original has no difficulty tier — "Б О 4", not "Б О Ч 4".
	if _GoalDiff.sanitize_goal(goal) == "original":
		return _translate("SONG_GEN_STYLE_BTN_ORIGINAL_FMT") % [
			_instrument_abbrev(instrument),
			_goal_abbrev(goal),
			str(lanes),
		]
	return _translate("SONG_GEN_STYLE_BTN_FMT") % [
		_instrument_abbrev(instrument),
		_goal_abbrev(goal),
		_difficulty_abbrev(goal, difficulty),
		str(lanes),
	]


static func format_gen_settings_toast(
	instrument: String,
	_lanes: int,
	goal: String,
	difficulty: String,
) -> String:
	var inst_key := "GEN_INST_%s" % instrument.to_upper()
	var inst := _translate(inst_key)
	if inst == inst_key:
		inst = _instrument_abbrev(instrument)
	var mode_label := format_goal_difficulty_label(goal, difficulty)
	return "%s · %s" % [inst, mode_label]


## Human label for a chart stem / intent / legacy mode: «Аркада · Средняя», «Оригинал».
static func format_instrument_label(instrument: String) -> String:
	var inst_key := "GEN_INST_%s" % instrument.strip_edges().to_upper()
	var label := _translate(inst_key)
	if label == inst_key:
		return _instrument_abbrev(instrument)
	return label


static func format_chart_mode_label(mode_raw: String) -> String:
	var mode := mode_raw.strip_edges().to_lower()
	if mode == "":
		return ""
	if _GoalDiff.is_chart_stem(mode):
		return format_goal_difficulty_label_from_pair(_GoalDiff.pair_from_stem(mode))
	if mode in ["original", "groove", "sparse", "arcade"]:
		return format_goal_difficulty_label_from_pair(_GoalDiff.from_intent(mode))
	var mode_key := "GEN_MODE_%s" % mode.to_upper()
	var label := _translate(mode_key)
	if label == mode_key:
		return mode_raw
	return label


static func format_goal_difficulty_label(goal: String, difficulty: String) -> String:
	return format_goal_difficulty_label_from_pair({
		"goal": goal,
		"difficulty": difficulty,
	})


static func format_goal_difficulty_label_from_pair(pair: Dictionary) -> String:
	var goal := str(pair.get("goal", _GoalDiff.DEFAULT_GOAL))
	var difficulty := str(pair.get("difficulty", _GoalDiff.DEFAULT_DIFFICULTY))
	var goal_label := _translate("GEN_GOAL_%s" % goal.to_upper())
	if _GoalDiff.sanitize_goal(goal) == "original":
		return goal_label
	var diff_label := _translate(_GoalDiff.difficulty_label_key(goal, difficulty))
	return "%s · %s" % [goal_label, diff_label]


## Compact label for Generate confirm: jobs from Chart readiness, not the play-style button.
static func format_ready_jobs_label(jobs: Array) -> String:
	if jobs.is_empty():
		return "—"
	var parts: PackedStringArray = []
	var seen: Dictionary = {}
	for job in jobs:
		if not job is Dictionary:
			continue
		var d := job as Dictionary
		var inst := str(d.get("instrument", "drums"))
		var goal := str(d.get("goal", _GoalDiff.DEFAULT_GOAL))
		var difficulty := str(d.get("difficulty", _GoalDiff.DEFAULT_DIFFICULTY))
		var key := "%s|%s|%s" % [inst, goal, difficulty]
		if seen.has(key):
			continue
		seen[key] = true
		parts.append(format_gen_settings_label(inst, 0, goal, difficulty))
	if parts.is_empty():
		return "—"
	if parts.size() == 1:
		return parts[0]
	if parts.size() <= 3:
		return ", ".join(parts)
	return _translate("SONG_GEN_READY_JOBS_MANY_FMT") % [parts[0], parts.size() - 1]


static func format_lanes_button_label(lanes: int) -> String:
	var locale := TranslationServer.get_locale()
	if locale.begins_with("ru"):
		var n := lanes % 100
		var n1 := n % 10
		var word := "линий"
		if n1 == 1 and n != 11:
			word = "линия"
		elif n1 >= 2 and n1 <= 4 and (n < 12 or n > 14):
			word = "линии"
		return "%d %s" % [lanes, word]
	return _translate("GEN_LANES_BTN_FMT") % lanes


static func _instrument_abbrev(instrument: String) -> String:
	match instrument:
		"drums":
			return _translate("SONG_GEN_ABBR_DRUMS")
		"fullmix":
			return _translate("SONG_GEN_ABBR_FULLMIX")
		"bass":
			return _translate("SONG_GEN_ABBR_BASS")
		_:
			return instrument.substr(0, 1).to_upper()


static func _goal_abbrev(goal: String) -> String:
	var key := "SONG_GEN_ABBR_%s" % goal.strip_edges().to_upper()
	var abbrev := _translate(key)
	if abbrev != key:
		return abbrev
	return goal.substr(0, 1).to_upper()


static func _difficulty_abbrev(goal: String, difficulty: String) -> String:
	var g := goal.strip_edges().to_lower()
	var d := difficulty.strip_edges().to_lower()
	if g == "original":
		var orig_key := "SONG_GEN_ABBR_DIFF_ORIGINAL_%s" % d.to_upper()
		var orig_abbrev := _translate(orig_key)
		if orig_abbrev != orig_key:
			return orig_abbrev
		# Hard fallback if CSV not reimported yet (Читаемая → Ч, not Средняя → С).
		match d:
			"easy":
				return "К" if TranslationServer.get_locale().begins_with("ru") else "B"
			"hard":
				return "А" if TranslationServer.get_locale().begins_with("ru") else "A"
			_:
				return "Ч" if TranslationServer.get_locale().begins_with("ru") else "R"
	var key := "SONG_GEN_ABBR_DIFF_%s" % d.to_upper()
	var abbrev := _translate(key)
	if abbrev != key:
		return abbrev
	return difficulty.substr(0, 1).to_upper()


static func _mode_or_intent_abbrev(key: String) -> String:
	var normalized := key.strip_edges().to_lower()
	var intent_key := "SONG_GEN_ABBR_%s" % normalized.to_upper()
	var abbrev := _translate(intent_key)
	if abbrev != intent_key:
		return abbrev
	return _mode_abbrev(normalized)


static func _mode_abbrev(mode: String) -> String:
	var mode_key := "SONG_GEN_ABBR_%s" % mode.to_upper()
	var abbrev := _translate(mode_key)
	if abbrev == mode_key:
		return mode.substr(0, 1).to_upper()
	return abbrev


static func _translate(key: String) -> String:
	var value := TranslationServer.translate(key)
	if value != key:
		return value
	var locale := TranslationServer.get_locale()
	if locale.begins_with("en"):
		return _EN_FALLBACKS.get(key, key)
	return _RU_FALLBACKS.get(key, key)


const _RU_FALLBACKS := {
	"SONG_FILTER_PLAY_COUNT": "Чаще играли",
	"SONG_FILTER_DIFFICULTY": "Сложность",
	"SONG_FILTER_NOTES_READY": "Готовность нот",
	"SONG_FILTER_DURATION": "Длительность",
	"SONG_FILTER_BPM": "BPM",
	"SONG_GROUP_BPM_UNKNOWN": "BPM не указан",
	"SONG_GROUP_BPM_FMT": "%d BPM",
	"SONG_GROUP_DURATION_UNKNOWN": "Неизвестная длительность",
	"SONG_GROUP_DURATION_UNDER_1": "<1 мин",
	"SONG_GROUP_DURATION_1_MIN": "1 мин",
	"SONG_GROUP_DURATION_N_MIN": "%d мин",
	"SONG_GROUP_NOTES_HAVE_FMT": "Есть (%d)",
	"SONG_GROUP_NOTES_MISSING_FMT": "Нет (%d)",
	"SONG_DIFFICULTY_PREFIX": "Сложность:",
	"SONG_DENSITY_FMT": "Плотность: %.1f нот/с",
	"SONG_GROUP_HEADER_FMT": "%d %s",
	"SONG_GROUP_FAVORITES": "Избранное",
	"SONG_FAVORITE_ADD": "В избранное",
	"SONG_FAVORITE_REMOVE": "Убрать из избранного",
	"SONG_GEN_REGEN": "Перегенерировать ноты",
	"SONG_GEN_TOOLTIP_IN_PROGRESS": "Идёт генерация…",
	"SONG_GEN_TOOLTIP_QUEUED": "В очереди — дождитесь текущей задачи",
	"SONG_GEN_TOOLTIP_REGEN": "Ноты для этих настроек уже есть — нажмите для перегенерации",
	"SONG_CHART_ID_TOOLTIP": "Нажмите, чтобы скопировать ID папки чарта",
	"SONG_CHART_ID_COPIED": "ID чарта скопирован",
	"SONG_DUPLICATE_MSG": "Этот трек уже есть в библиотеке: «%s».\n\nИспользуйте существующую запись — не добавляйте дубликат.",
	"SONG_GEN_STYLE_BTN_FMT": "Стиль чарта: %s %s %s %s",
	"SONG_GEN_ABBR_DIFF_ORIGINAL_RELAXED": "К",
	"SONG_GEN_ABBR_DIFF_ORIGINAL_STANDARD": "Ч",
	"SONG_GEN_ABBR_DIFF_ORIGINAL_DENSE": "А",
	"SONG_MUSEUM_TITLE": "Музей трека",
	"SONG_MUSEUM_FIRST_CAPTION": "Первый забег",
	"SONG_MUSEUM_RUNS_CAPTION": "Забегов",
	"SONG_MUSEUM_AVG_ACC_CAPTION": "Средняя точность",
	"SONG_MUSEUM_BEST_RR_CAPTION": "Лучший RR",
	"SONG_MUSEUM_TIME_CAPTION": "В игре",
	"SONG_MUSEUM_FC_CAPTION": "Full Combo",
	"SONG_MUSEUM_SS_CAPTION": "Оценки SS",
	"SONG_MUSEUM_FAV_STYLE_CAPTION": "Любимый стиль",
	"SONG_MUSEUM_FAV_INST_CAPTION": "Любимый инструмент",
	"SONG_MUSEUM_LAST_CAPTION": "Последний забег",
	"SONG_MUSEUM_MEDALS_CAPTION": "Медали",
	"SONG_MUSEUM_MODS": "Частые моды",
	"SONG_MUSEUM_RR_FMT": "RR %s",
	"SONG_MUSEUM_COMBO_FMT": "Комбо %d",
	"SONG_MUSEUM_SHOWN_OF": "Показано %d из %d",
	"SONG_MUSEUM_SHOWN_ALL": "Показаны все %d попыток",
	"SONG_STAT_PLAYS_CAPTION": "Прохождений",
	"SONG_STAT_GRADE_CAPTION": "Лучший ранг",
	"SONG_STAT_RR_CAPTION": "Лучший RR",
}

const _EN_FALLBACKS := {
	"SONG_FILTER_PLAY_COUNT": "Most played",
	"SONG_FILTER_DIFFICULTY": "Difficulty",
	"SONG_FILTER_NOTES_READY": "Notes ready",
	"SONG_FILTER_DURATION": "Duration",
	"SONG_FILTER_BPM": "BPM",
	"SONG_GROUP_BPM_UNKNOWN": "Unknown BPM",
	"SONG_GROUP_BPM_FMT": "%d BPM",
	"SONG_GROUP_DURATION_UNKNOWN": "Unknown duration",
	"SONG_GROUP_DURATION_UNDER_1": "<1 min",
	"SONG_GROUP_DURATION_1_MIN": "1 min",
	"SONG_GROUP_DURATION_N_MIN": "%d min",
	"SONG_GROUP_NOTES_HAVE_FMT": "Has notes (%d)",
	"SONG_GROUP_NOTES_MISSING_FMT": "No notes (%d)",
	"SONG_DIFFICULTY_PREFIX": "Difficulty:",
	"SONG_DENSITY_FMT": "Density: %.1f notes/s",
	"SONG_GROUP_HEADER_FMT": "%d %s",
	"SONG_GROUP_FAVORITES": "Favorites",
	"SONG_FAVORITE_ADD": "Add to favorites",
	"SONG_FAVORITE_REMOVE": "Remove from favorites",
	"SONG_GEN_REGEN": "Regenerate notes",
	"SONG_GEN_TOOLTIP_IN_PROGRESS": "Generation in progress…",
	"SONG_GEN_TOOLTIP_QUEUED": "Queued — wait for the current task",
	"SONG_GEN_TOOLTIP_REGEN": "Notes exist for these settings — click to regenerate",
	"SONG_CHART_ID_TOOLTIP": "Click to copy chart folder ID",
	"SONG_CHART_ID_COPIED": "Chart ID copied",
	"SONG_DUPLICATE_MSG": "This track is already in the library: «%s».\n\nUse the existing entry — do not add a duplicate.",
	"SONG_GEN_STYLE_BTN_FMT": "Chart style: %s %s %s %s",
	"SONG_GEN_ABBR_DIFF_ORIGINAL_RELAXED": "B",
	"SONG_GEN_ABBR_DIFF_ORIGINAL_STANDARD": "R",
	"SONG_GEN_ABBR_DIFF_ORIGINAL_DENSE": "A",
	"SONG_MUSEUM_TITLE": "Track museum",
	"SONG_MUSEUM_FIRST_CAPTION": "First play",
	"SONG_MUSEUM_RUNS_CAPTION": "Runs",
	"SONG_MUSEUM_AVG_ACC_CAPTION": "Avg accuracy",
	"SONG_MUSEUM_BEST_RR_CAPTION": "Best RR",
	"SONG_MUSEUM_TIME_CAPTION": "Time played",
	"SONG_MUSEUM_FC_CAPTION": "Full combos",
	"SONG_MUSEUM_SS_CAPTION": "SS ranks",
	"SONG_MUSEUM_FAV_STYLE_CAPTION": "Favorite style",
	"SONG_MUSEUM_FAV_INST_CAPTION": "Favorite instrument",
	"SONG_MUSEUM_LAST_CAPTION": "Last play",
	"SONG_MUSEUM_MEDALS_CAPTION": "Medals",
	"SONG_MUSEUM_MODS": "Common mods",
	"SONG_MUSEUM_RR_FMT": "RR %s",
	"SONG_MUSEUM_COMBO_FMT": "Combo %d",
	"SONG_MUSEUM_SHOWN_OF": "Showing %d of %d",
	"SONG_MUSEUM_SHOWN_ALL": "All %d attempts shown",
	"SONG_STAT_PLAYS_CAPTION": "Clears",
	"SONG_STAT_GRADE_CAPTION": "Best rank",
	"SONG_STAT_RR_CAPTION": "Best RR",
}
