# scenes/profile/share/cards/profile_share_card_music.gd
extends ProfileShareCardBase

const _GenreGroupIcons = preload("res://logic/domain/library/genre_group_icons.gd")

@onready var _section_genres: Label      = %SectionHeaderGenres
@onready var _section_mastery: Label     = %SectionHeaderMastery
@onready var _section_leaders: Label     = %SectionHeaderLeaders
@onready var _section_fact: Label        = %SectionHeaderFact
@onready var _best_level_value: Label    = %BestLevelValue
@onready var _mastery_count: Label       = %MasteryCountLabel
@onready var _mastery_caption: Label     = %MasteryCaption
@onready var _fact_label: Label          = %FactLabel
@onready var _genre_rows: Array[HBoxContainer] = [
	%GenreRow0, %GenreRow1, %GenreRow2, %GenreRow3, %GenreRow4, %GenreRow5,
]
@onready var _leader_rows: Array[HBoxContainer] = [
	%LeaderRow0, %LeaderRow1, %LeaderRow2, %LeaderRow3, %LeaderRow4,
]


func _ready() -> void:
	card_id = "music"
	super._ready()


func _apply_card_content(data: Dictionary) -> void:
	var accent := _accent()

	_set_section_header(_section_genres, tr("PROFILE_SHARE_SEC_TOP_GENRES"))
	_set_section_header(_section_mastery, tr("PROFILE_SHARE_SEC_MASTERY"))
	_set_section_header(_section_leaders, tr("PROFILE_SHARE_SEC_LEADERS"))
	_set_section_header(_section_fact, tr("PROFILE_SHARE_SEC_FACT"))

	# --- Genre bars ---
	var genres: Array = data.get("top_genres", [])
	for i in range(_genre_rows.size()):
		var row := _genre_rows[i]
		if row == null:
			continue
		if i >= genres.size() or not genres[i] is Dictionary:
			row.visible = false
			continue
		row.visible = true
		_fill_genre_row(row, str(genres[i].get("group_id", "")), float(genres[i].get("percent", 0.0)))

	# --- Mastery panel ---
	var best_level := int(data.get("best_mastery_level", 0))
	var unlocked   := int(data.get("groups_unlocked", 0))
	var total      := int(data.get("groups_total", 0))
	_apply_glass_panel(get_node_or_null("%MasteryPanel") as PanelContainer, true)
	if _best_level_value:
		_set_label(_best_level_value, str(best_level) if best_level > 0 else "—", 72, accent)
		_best_level_value.custom_minimum_size = Vector2(_fs(80), 0)
	if _mastery_count:
		_set_label(_mastery_count, tr("PROFILE_SHARE_MASTERY_OF") % [unlocked, total], 26, _TEXT)
	if _mastery_caption:
		_set_label(_mastery_caption, tr("PROFILE_SHARE_SEC_MASTERY"), 20, _MUTED)

	# --- Mastery leaders ---
	var leaders: Array = data.get("mastery_leaders", [])
	for i in range(_leader_rows.size()):
		var row := _leader_rows[i]
		if row == null:
			continue
		if i >= leaders.size() or not leaders[i] is Dictionary:
			row.visible = false
			continue
		row.visible = true
		_fill_leader_row(row, i + 1,
			str(leaders[i].get("group_id", "")),
			int(leaders[i].get("level", 0)))

	# --- Interesting fact ---
	_apply_glass_panel(get_node_or_null("%FactPanel") as PanelContainer, true)
	if _fact_label:
		_set_label(_fact_label, _build_fact(genres, unlocked, total), 26, accent)
		_fact_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART


func _fill_genre_row(row: HBoxContainer, group_id: String, percent: float) -> void:
	var name_lbl := row.get_node_or_null("NameLabel") as Label
	var bar      := row.get_node_or_null("Bar") as ProgressBar
	var pct_lbl  := row.get_node_or_null("PctLabel") as Label
	var bar_color := _GenreGroupIcons.tint_for_group(group_id)
	if name_lbl:
		name_lbl.custom_minimum_size.x = _fs(200)
		_set_label(name_lbl, _group_label(group_id), 24, _TEXT)
	if bar:
		bar.custom_minimum_size = Vector2(_fs(380), _fs(16))
		_style_progress(bar, bar_color)
		bar.max_value = 100.0
		bar.value     = clampf(percent, 0.0, 100.0)
	if pct_lbl:
		pct_lbl.custom_minimum_size.x = _fs(72)
		_set_label(pct_lbl, "%.0f%%" % percent, 24, bar_color)


func _fill_leader_row(row: HBoxContainer, rank: int, group_id: String, level: int) -> void:
	var rank_lbl := row.get_node_or_null("RankLabel") as Label
	var name_lbl := row.get_node_or_null("NameLabel") as Label
	var lv_lbl   := row.get_node_or_null("LvLabel")   as Label
	var accent   := _accent()
	if rank_lbl:
		rank_lbl.custom_minimum_size.x = _fs(36)
		_set_label(rank_lbl, "%02d." % rank, 22, _MUTED)
	if name_lbl:
		_set_label(name_lbl, _group_label(group_id), 24, accent)
	if lv_lbl:
		_set_label(lv_lbl, "Lv.%d" % level, 24, _TEXT)


func _build_fact(genres: Array, unlocked: int, total: int) -> String:
	if not genres.is_empty() and genres[0] is Dictionary:
		var top_id  := str(genres[0].get("group_id", ""))
		var top_pct := float(genres[0].get("percent", 0.0))
		if top_pct > 0.0:
			return tr("PROFILE_SHARE_MUSIC_FACT") % [_group_label(top_id), top_pct]
	if unlocked > 0 and total > 0:
		return tr("PROFILE_SHARE_MASTERY_SUMMARY") % [unlocked, total]
	return tr("PROFILE_SHARE_WRAPPED_TAGLINE")
