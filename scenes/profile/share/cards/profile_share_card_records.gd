# scenes/profile/share/cards/profile_share_card_records.gd
extends ProfileShareCardBase

const EXTREME_SPECS: Array = [
	["highest_accuracy",           "PROFILE_RECORD_EXTREME_ACCURACY",  "percent"],
	["hardest_chart_cleared",      "PROFILE_RECORD_EXTREME_CHART",     "rating"],
	["longest_fc",                 "PROFILE_RECORD_EXTREME_FC",        "int"],
	["highest_bpm_cleared",        "PROFILE_RECORD_EXTREME_BPM",       "bpm"],
	["longest_track_duration_sec", "PROFILE_RECORD_EXTREME_DURATION",  "duration"],
]

const MILESTONE_SPECS: Array = [
	["first_ss",          "PROFILE_RECORD_MILESTONE_FIRST_SS"],
	["first_fc",          "PROFILE_RECORD_MILESTONE_FIRST_FC"],
	["unique_100_tracks", "PROFILE_RECORD_MILESTONE_UNIQUE_100"],
	["first_s",           "PROFILE_RECORD_MILESTONE_FIRST_S"],
]

@onready var _section_milestones: Label = %SectionHeaderMilestones
@onready var _section_records: Label    = %SectionHeaderRecords
@onready var _section_streaks: Label    = %SectionHeaderStreaks
@onready var _records: Array[PanelContainer] = [
	%Record0, %Record1, %Record2, %Record3, %Record4,
]
@onready var _milestones: Array[PanelContainer] = [
	%Milestone0, %Milestone1, %Milestone2, %Milestone3,
]
@onready var _streak_panels: Array[PanelContainer] = [
	%StreakPanel0, %StreakPanel1, %StreakPanel2, %StreakPanel3,
]
@onready var _tagline: Label = %TaglineLabel


func _ready() -> void:
	card_id = "records"
	super._ready()


func _apply_card_content(data: Dictionary) -> void:
	var accent := _accent()

	_set_section_header(_section_milestones, tr("PROFILE_SHARE_SEC_MILESTONES"))
	_set_section_header(_section_records,    tr("PROFILE_SHARE_SEC_RECORDS"))
	_set_section_header(_section_streaks,    tr("PROFILE_SHARE_SEC_STREAKS"))

	# --- Milestones ---
	var milestones: Dictionary = data.get("milestones", {}) if data.get("milestones") is Dictionary else {}
	for i in range(mini(_milestones.size(), MILESTONE_SPECS.size())):
		var spec: Array = MILESTONE_SPECS[i]
		_apply_milestone_chip(_milestones[i], tr(str(spec[1])), milestones.has(str(spec[0])))

	# --- Records ---
	var extremes: Dictionary = data.get("extremes", {}) if data.get("extremes") is Dictionary else {}
	for i in range(mini(_records.size(), EXTREME_SPECS.size())):
		var spec: Array = EXTREME_SPECS[i]
		var value := tr("VALUE_NA")
		if extremes.has(str(spec[0])) and extremes[str(spec[0])] is Dictionary:
			value = _format_extreme(extremes[str(spec[0])], str(spec[2]))
			if value == "":
				value = tr("VALUE_NA")
		_apply_record_row(_records[i], tr(str(spec[1])), value, accent if i == 0 else _TEXT)

	# --- 4-row streaks ---
	var streaks: Dictionary = data.get("streaks", {}) if data.get("streaks") is Dictionary else {}
	var best_clear    := int(streaks.get("best_clear_streak_days", 0))
	var cur_clear     := int(streaks.get("current_clear_streak_days", 0))
	var best_login    := int(data.get("login_streak_best", 0))
	var cur_login     := int(data.get("login_streak_current", 0))
	var streak_data: Array = [
		[tr("PROFILE_SHARE_STREAK_BEST_CLEAR"),   _days_str(best_clear),  accent],
		[tr("PROFILE_SHARE_STREAK_CUR_CLEAR"),    _days_str(cur_clear),   _TEXT],
		[tr("PROFILE_SHARE_STREAK_BEST_LOGIN"),   _days_str(best_login),  Color(0.38, 0.78, 0.74)],
		[tr("PROFILE_SHARE_STREAK_CUR_LOGIN"),    _days_str(cur_login),   _TEXT],
	]
	for i in range(mini(_streak_panels.size(), streak_data.size())):
		var sd: Array = streak_data[i]
		_apply_record_row(_streak_panels[i], str(sd[0]), str(sd[1]), sd[2] as Color)

	if _tagline:
		_set_label(_tagline, tr("PROFILE_SHARE_WRAPPED_TAGLINE"), 22, accent)


func _days_str(days: int) -> String:
	if days <= 0:
		return tr("VALUE_NA")
	return "%d дн." % days if tr("LOCALE") != "en" else "%d days" % days
