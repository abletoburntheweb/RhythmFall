# scenes/marathon/marathon_summary_rewards_panel.gd
extends VBoxContainer
class_name MarathonSummaryRewardsPanel

const _MarathonSessionConfig = preload("res://logic/domain/session/marathon_session_config.gd")
const _EndlessSessionConfig = preload("res://logic/domain/session/endless_session_config.gd")
const _RunRewards = preload("res://logic/domain/rewards/run_rewards.gd")
const _SongSelectUiStyles = preload("res://scenes/song_select/lib/song_select_ui_styles.gd")
const _UiIconHelper = preload("res://logic/ui/ui_icon_helper.gd")

var _accent := Color(0.79, 0.57, 0.35, 1.0)
var _title_label: Label = null
var _xp_value_label: Label = null
var _currency_value_label: Label = null
var _bonus_label: Label = null
var _last_cfg: Dictionary = {}


func _ready() -> void:
	add_theme_constant_override("separation", 6)
	if _title_label == null:
		_build_ui()


func setup(accent: Color) -> void:
	_accent = accent
	if _title_label == null:
		_build_ui()
	if _title_label:
		_title_label.add_theme_color_override("font_color", _accent.lerp(Color.WHITE, 0.12))


func apply_locale() -> void:
	if _title_label:
		_title_label.text = tr("MARATHON_CATALOG_REWARDS_TITLE")
	_refresh_bonus_text(_last_cfg)


func refresh(
	template: Dictionary,
	effective_config: Dictionary,
	track_count: int,
	playable: bool,
) -> void:
	if _title_label == null:
		_build_ui()
	visible = playable and not template.is_empty()
	if not visible:
		return
	var cfg := _MarathonSessionConfig.resolve_effective_mod_config(effective_config, template)
	_last_cfg = cfg
	var tracks := maxi(1, track_count if track_count > 0 else int(template.get("track_count", 5)))
	var completion := _RunRewards.compute_marathon_completion_rewards(template, cfg, tracks)
	if _xp_value_label:
		_xp_value_label.text = "+%d" % int(completion.get("xp", 0))
	if _currency_value_label:
		_currency_value_label.text = "+%d" % int(completion.get("currency", 0))
	_refresh_bonus_text(cfg)


func _refresh_bonus_text(cfg: Dictionary = {}) -> void:
	if _bonus_label == null:
		return
	var policy := str(cfg.get("mod_policy", _EndlessSessionConfig.MOD_POLICY_NONE))
	if policy == _EndlessSessionConfig.MOD_POLICY_RANDOM_POOL:
		var mod_count := int(cfg.get("mod_random_count", _EndlessSessionConfig.DEFAULT_MOD_RANDOM_COUNT))
		var mult_pct := int(round((_MarathonSessionConfig.mod_reward_multiplier(cfg) - 1.0) * 100.0))
		_bonus_label.text = tr("MARATHON_CATALOG_REWARDS_MOD_BONUS_FMT") % [mult_pct, mod_count]
		_bonus_label.visible = true
	elif policy == _EndlessSessionConfig.MOD_POLICY_FIXED:
		_bonus_label.text = tr("MARATHON_CATALOG_REWARDS_FIXED_MODS_HINT")
		_bonus_label.visible = true
	else:
		_bonus_label.visible = false


func _build_ui() -> void:
	for child in get_children():
		child.queue_free()
	_title_label = Label.new()
	_title_label.text = tr("MARATHON_CATALOG_REWARDS_TITLE")
	_title_label.add_theme_font_size_override("font_size", 13)
	add_child(_title_label)

	var panel := PanelContainer.new()
	var box := _SongSelectUiStyles.card_panel_style().duplicate() as StyleBoxFlat
	box.bg_color = Color(0.07, 0.09, 0.13, 0.94)
	box.border_color = Color(_accent.r, _accent.g, _accent.b, 0.28)
	box.content_margin_left = 12.0
	box.content_margin_right = 12.0
	box.content_margin_top = 10.0
	box.content_margin_bottom = 10.0
	panel.add_theme_stylebox_override("panel", box)
	add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	panel.add_child(vbox)

	var rewards_row := HBoxContainer.new()
	rewards_row.add_theme_constant_override("separation", 16)
	rewards_row.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(rewards_row)

	rewards_row.add_child(_make_reward_col("gauge.svg", Color(0.35, 0.82, 0.72, 1.0), tr("VICTORY_REWARD_XP")))
	rewards_row.add_child(_make_reward_col("diamond.svg", Color(0.95, 0.78, 0.42, 1.0), tr("VICTORY_REWARD_CURRENCY")))

	_bonus_label = Label.new()
	_bonus_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_bonus_label.add_theme_font_size_override("font_size", 12)
	_bonus_label.add_theme_color_override("font_color", Color(0.62, 0.72, 0.86, 0.92))
	_bonus_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_bonus_label.visible = false
	vbox.add_child(_bonus_label)


func _make_reward_col(icon_file: String, tint: Color, caption: String) -> VBoxContainer:
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override("separation", 4)
	col.alignment = BoxContainer.ALIGNMENT_CENTER

	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 8)
	top.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_child(top)
	top.add_child(_UiIconHelper.make_icon_frame(icon_file, 28, 15, tint))

	var value := Label.new()
	value.add_theme_font_size_override("font_size", 22)
	value.add_theme_color_override("font_color", tint)
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	top.add_child(value)

	var cap := Label.new()
	cap.text = caption
	cap.add_theme_font_size_override("font_size", 11)
	cap.add_theme_color_override("font_color", Color(0.55, 0.62, 0.74, 0.9))
	cap.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(cap)

	if icon_file == "gauge.svg":
		_xp_value_label = value
	else:
		_currency_value_label = value
	return col
