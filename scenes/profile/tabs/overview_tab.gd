# scenes/profile/tabs/overview_tab.gd
extends VBoxContainer

const ACHIEVEMENT_CARD_SCENE := preload("res://scenes/achievements/achievement_card.tscn")
const TimeUtils = preload("res://logic/platform/time_utils.gd")
const ResultsHistoryService = preload("res://logic/data/results_history_service.gd")
const _ProfileGenrePortrait = preload("res://logic/domain/profile/profile_genre_portrait.gd")
const _GenreGroupIcons = preload("res://logic/domain/library/genre_group_icons.gd")
const _GenrePortraitRowsUi = preload("res://logic/domain/profile/genre_portrait_rows_ui.gd")
const _SongSelectStrings = preload("res://logic/domain/library/song_select_strings.gd")
const _ProfilePlayModesStats = preload("res://logic/domain/profile/profile_play_modes_stats.gd")
const _MarathonRouteBadges = preload("res://logic/domain/session/marathon_route_badges.gd")
const _UiIconHelper = preload("res://logic/ui/ui_icon_helper.gd")
const _ModifierIconStrip = preload("res://logic/ui/modifier_icon_strip.gd")

const _FAVORITE := "FavoriteTrackCard/MarginContainer/HBoxContainer"
const _HIGHLIGHTS := "HighlightsRow"
const _ACHIEVEMENTS := "RecentAchievementsCard"

const _OVERVIEW_ACHIEVEMENT_LIMIT := 3
const _OVERVIEW_GENRE_PORTRAIT_LIMIT := 5
const _OVERVIEW_PORTRAIT_ROW_GENRE_STRETCH := 0.52
const _OVERVIEW_PORTRAIT_ROW_ACHIEVEMENTS_STRETCH := 1.48

var screen: ProfileScreen = null

var _overview_extras_ready := false
var _genre_portrait_card: PanelContainer
var _genre_portrait_title: Label
var _genre_portrait_rows: GridContainer
var _genre_portrait_empty_label: Label
var _genre_portrait_spacer: Control
var _overview_portrait_row: HBoxContainer
var _overview_refresh_token := 0
var _heavy_refresh_running := false
var _play_modes_summary_row: VBoxContainer
var _play_modes_panel: PanelContainer
var _marathon_progress: ProgressBar
var _marathon_progress_hint: Label
var _marathon_caption: Label
var _marathon_medal_row: HBoxContainer
var _marathon_medal_icon: Control
var _marathon_medal_label: Label
var _marathon_details: Button
var _mod_progress: ProgressBar
var _mod_progress_hint: Label
var _mod_caption: Label
var _mod_top_icons: HBoxContainer
var _mod_details: Button
var _play_modes_marathon_cache: Dictionary = {}
var _play_modes_mod_cache: Dictionary = {}
var _cached_marathon_tier: String = ""

@onready var favorite_track_card_title: Label = get_node_or_null("%s/InfoVBox/CardTitle" % _FAVORITE) as Label
@onready var level_card_title: Label = get_node_or_null("%s/LevelXPCard/ContentVBox/CardTitle" % _HIGHLIGHTS) as Label
@onready var play_time_caption_label: Label = get_node_or_null("%s/PlayTimeHighlight/VBox/CaptionLabel" % _HIGHLIGHTS) as Label
@onready var accuracy_caption_label: Label = get_node_or_null("%s/AccuracyHighlight/VBox/CaptionLabel" % _HIGHLIGHTS) as Label
@onready var levels_caption_label: Label = get_node_or_null("%s/LevelsHighlight/VBox/CaptionLabel" % _HIGHLIGHTS) as Label
@onready var difficulty_caption_label: Label = get_node_or_null("%s/DifficultyHighlight/VBox/CaptionLabel" % _HIGHLIGHTS) as Label
@onready var recent_achievements_title: Label = get_node_or_null("%s/ContentVBox/CardTitle" % _ACHIEVEMENTS) as Label
@onready var profile_medals_card: PanelContainer = get_node_or_null("TrackMedalsCard") as PanelContainer
@onready var level_label: Label = get_node_or_null("%s/LevelXPCard/ContentVBox/LevelLabel" % _HIGHLIGHTS) as Label
@onready var xp_label: Label = get_node_or_null("%s/LevelXPCard/ContentVBox/XPLabel" % _HIGHLIGHTS) as Label
@onready var xp_progress_label: Label = get_node_or_null("%s/LevelXPCard/ContentVBox/XPProgressLabel" % _HIGHLIGHTS) as Label
@onready var xp_progress_bar: ProgressBar = get_node_or_null("%s/LevelXPCard/ContentVBox/XPProgressBar" % _HIGHLIGHTS) as ProgressBar
@onready var highlight_play_time_value: Label = get_node_or_null("%s/PlayTimeHighlight/VBox/ValueLabel" % _HIGHLIGHTS) as Label
@onready var highlight_accuracy_value: Label = get_node_or_null("%s/AccuracyHighlight/VBox/ValueLabel" % _HIGHLIGHTS) as Label
@onready var highlight_levels_value: Label = get_node_or_null("%s/LevelsHighlight/VBox/ValueLabel" % _HIGHLIGHTS) as Label
@onready var highlight_difficulty_value: Label = get_node_or_null("%s/DifficultyHighlight/VBox/ValueLabel" % _HIGHLIGHTS) as Label
@onready var highlights_row: HBoxContainer = get_node_or_null(_HIGHLIGHTS) as HBoxContainer
@onready var _login_streak_highlight_value: Label = get_node_or_null("%s/LoginStreakHighlight/VBox/ValueLabel" % _HIGHLIGHTS) as Label
@onready var _login_streak_highlight_caption: Label = get_node_or_null("%s/LoginStreakHighlight/VBox/CaptionLabel" % _HIGHLIGHTS) as Label
@onready var _rr_highlight_value: Label = get_node_or_null("%s/RhythmRatingHighlight/VBox/ValueLabel" % _HIGHLIGHTS) as Label
@onready var _rr_highlight_caption: Label = get_node_or_null("%s/RhythmRatingHighlight/VBox/CaptionLabel" % _HIGHLIGHTS) as Label
@onready var favorite_track_card: PanelContainer = get_node_or_null("FavoriteTrackCard")
@onready var favorite_cover_texture_rect: TextureRect = get_node_or_null("%s/FavoriteCoverTextureRect" % _FAVORITE)
@onready var favorite_title_label: Label = get_node_or_null("%s/InfoVBox/FavoriteTitleLabel" % _FAVORITE)
@onready var favorite_artist_label: Label = get_node_or_null("%s/InfoVBox/FavoriteArtistLabel" % _FAVORITE)
@onready var favorite_genre_label: Label = get_node_or_null("%s/InfoVBox/FavoriteGenreLabel" % _FAVORITE)
@onready var favorite_play_count_label: Label = get_node_or_null("%s/InfoVBox/FavoritePlayCountLabel" % _FAVORITE)
@onready var achievements_list_vbox: VBoxContainer = get_node_or_null("%s/ContentVBox/AchievementsListVBox" % _ACHIEVEMENTS)
@onready var achievements_empty_label: Label = get_node_or_null("%s/ContentVBox/AchievementsListVBox/EmptyLabel" % _ACHIEVEMENTS)
@onready var achievement_card_template: PanelContainer = get_node_or_null("%s/ContentVBox/TemplateAchievementCard/AchievementCard" % _ACHIEVEMENTS)


func bind(host: ProfileScreen) -> void:
	screen = host


func setup() -> void:
	_setup_favorite_cover_rect()
	_setup_overview_extras()


func apply_locale() -> void:
	if favorite_track_card_title:
		favorite_track_card_title.text = tr("PROFILE_FAVORITE_TRACK")
	if profile_medals_card and profile_medals_card.has_method("apply_locale"):
		profile_medals_card.apply_locale()
	if level_card_title:
		level_card_title.text = tr("PROFILE_LEVEL_TITLE")
	if play_time_caption_label:
		play_time_caption_label.text = tr("PROFILE_PLAY_TIME")
	if accuracy_caption_label:
		accuracy_caption_label.text = tr("PROFILE_ACCURACY")
	if levels_caption_label:
		levels_caption_label.text = tr("PROFILE_LEVELS_COMPLETED")
	if difficulty_caption_label:
		difficulty_caption_label.text = tr("PROFILE_AVG_DIFFICULTY")
	if recent_achievements_title:
		recent_achievements_title.text = tr("PROFILE_RECENT_ACHIEVEMENTS")
	if achievements_empty_label:
		achievements_empty_label.text = tr("PROFILE_NO_RECENT_ACHIEVEMENTS")
	if _login_streak_highlight_caption:
		_login_streak_highlight_caption.text = tr("PROFILE_LOGIN_STREAK_CAPTION") % PlayerDataManager.get_best_login_streak()
	if _rr_highlight_caption:
		_rr_highlight_caption.text = tr("PROFILE_STAT_TOTAL_RR")
	if _genre_portrait_title:
		_genre_portrait_title.text = tr("PROFILE_GENRE_PORTRAIT_TITLE")
	if _genre_portrait_empty_label:
		_genre_portrait_empty_label.text = tr("PROFILE_GENRE_PORTRAIT_EMPTY")


func migrate_legacy_layout() -> void:
	var medals_panel := screen.get_node_or_null("MainVBox/ProfileRoot/MedalsPanel") as VBoxContainer
	var medals_card := get_node_or_null("TrackMedalsCard") as Node
	if medals_card == null and medals_panel:
		medals_card = medals_panel.get_node_or_null("TrackMedalsCard")
	if medals_card and medals_card.get_parent() != self:
		var parent := medals_card.get_parent()
		parent.remove_child(medals_card)
		var insert_idx := get_child_count()
		var achievements := get_node_or_null("RecentAchievementsCard")
		if achievements:
			insert_idx = achievements.get_index()
		add_child(medals_card)
		move_child(medals_card, insert_idx)
	if medals_panel and medals_panel.get_child_count() == 0:
		medals_panel.queue_free()
	_remove_play_modes_summary_if_present()
	if _genre_portrait_card:
		_reorganize_overview_bottom_row()


func refresh_fast() -> void:
	var overall_accuracy := _compute_overall_accuracy()
	if level_label:
		level_label.text = tr("PROFILE_LEVEL") % PlayerDataManager.get_current_level()
	if xp_label:
		xp_label.text = "XP: %s" % PlayerDataManager.get_xp_progress_text()
	if xp_progress_label:
		var progress_percent = PlayerDataManager.get_xp_progress() * 100.0
		xp_progress_label.text = tr("PROFILE_XP_PROGRESS") % progress_percent
	if xp_progress_bar:
		xp_progress_bar.value = PlayerDataManager.get_xp_progress()
	_update_highlight_tiles(overall_accuracy)
	_update_login_streak_display()


func schedule_heavy_refresh() -> void:
	_overview_refresh_token += 1
	var token := _overview_refresh_token
	call_deferred("_refresh_heavy", token)


func refresh_content_async() -> void:
	_refresh_favorite_track()
	await get_tree().process_frame
	_update_profile_medals(_get_global_medal_stats())
	await get_tree().process_frame
	_update_genre_portrait()
	await get_tree().process_frame
	_update_recent_achievements()
	await get_tree().process_frame
	_sync_overview_portrait_row_layout()


func on_play_time_changed() -> void:
	_update_highlight_tiles()


func on_calendar_day_changed() -> void:
	_update_login_streak_display()


func _refresh_heavy(token: int) -> void:
	if token != _overview_refresh_token or _heavy_refresh_running:
		return
	if screen == null or screen.current_profile_category != "overview":
		return
	_heavy_refresh_running = true
	_refresh_content()
	_heavy_refresh_running = false


func _refresh_content() -> void:
	_refresh_favorite_track()
	_update_profile_medals(_get_global_medal_stats())
	_update_genre_portrait()
	_update_recent_achievements()
	call_deferred("_sync_overview_portrait_row_layout")


func _play_time_string_to_seconds(time_str: String) -> int:
	var parts = time_str.split(":")
	if parts.size() == 2:
		var hours = parts[0].to_int()
		var minutes = parts[1].to_int()
		return (hours * 3600) + (minutes * 60)
	return 0


func _format_play_time(time_str: String) -> String:
	var parts = time_str.split(":")
	var hours = 0
	var minutes = 0
	if parts.size() >= 2:
		hours = int(parts[0])
		minutes = int(parts[1])
	else:
		var seconds = _play_time_string_to_seconds(time_str)
		hours = int(seconds / 3600)
		minutes = int((seconds % 3600) / 60)
	return tr("PROFILE_PLAY_TIME_FMT") % [hours, minutes]


func _compute_overall_accuracy() -> float:
	var total_notes_hit = PlayerDataManager.get_total_notes_hit()
	var total_notes_missed = PlayerDataManager.get_total_notes_missed()
	var total_notes_played = total_notes_hit + total_notes_missed
	if total_notes_played > 0:
		return (float(total_notes_hit) / float(total_notes_played)) * 100.0
	if screen and screen.results_history_service:
		var hist = screen.results_history_service.get_history()
		if hist.size() > 0:
			var sum_acc = 0.0
			for item in hist:
				sum_acc += float(item.get("accuracy", 0.0))
			return sum_acc / float(hist.size())
	return 0.0


func _setup_favorite_cover_rect() -> void:
	if favorite_cover_texture_rect == null:
		return
	favorite_cover_texture_rect.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	favorite_cover_texture_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED


func _apply_favorite_cover_texture(tex: Texture2D) -> void:
	if favorite_cover_texture_rect == null:
		return
	if tex == null:
		favorite_cover_texture_rect.texture = null
		return
	if tex is ImageTexture:
		var img := (tex as ImageTexture).get_image()
		if img and not img.has_mipmaps():
			img.generate_mipmaps()
			tex = ImageTexture.create_from_image(img)
	favorite_cover_texture_rect.texture = tex


func _refresh_favorite_track() -> void:
	var favorite_track_path: String = str(PlayerDataManager.data.get("favorite_track", ""))
	var favorite_track_count = PlayerDataManager.data.get("favorite_track_play_count", 0)
	if favorite_track_path == "" or favorite_track_count == 0:
		favorite_track_path = str(TrackStatsManager.get_favorite_track())
		favorite_track_count = TrackStatsManager.get_favorite_track_count()

	if favorite_track_card == null:
		return

	var title_text = tr("VALUE_NA")
	var artist_text = tr("VALUE_NA")
	var cover_texture = null
	var user_md: Dictionary = {}
	if favorite_track_path != "":
		favorite_track_path = favorite_track_path.replace("\\", "/").trim_suffix("/")
		var basic_md = _read_basic_metadata(favorite_track_path)
		title_text = str(basic_md.get("title", title_text))
		artist_text = str(basic_md.get("artist", artist_text))
		cover_texture = basic_md.get("cover", null)
		user_md = SongLibrary.get_metadata_for_song(favorite_track_path)
		if user_md and typeof(user_md) == TYPE_DICTIONARY:
			title_text = str(user_md.get("title", title_text))
			artist_text = str(user_md.get("artist", artist_text))
	var stem: String = favorite_track_path.get_file().get_basename() if favorite_track_path != "" else ""
	title_text = _SongSelectStrings.display_track_title(title_text, stem)
	artist_text = _SongSelectStrings.display_track_artist(artist_text)
	if favorite_cover_texture_rect:
		if cover_texture and cover_texture is ImageTexture:
			_apply_favorite_cover_texture(cover_texture)
		else:
			var file_cover = _get_cover_from_file(favorite_track_path)
			if file_cover:
				_apply_favorite_cover_texture(file_cover)
			else:
				var fallback_texture = _get_fallback_cover_texture()
				if fallback_texture:
					_apply_favorite_cover_texture(fallback_texture)
	if favorite_title_label:
		favorite_title_label.text = title_text
	if favorite_artist_label:
		favorite_artist_label.text = artist_text
	if favorite_genre_label:
		favorite_genre_label.text = tr("SONG_FIELD_GENRE") % _format_favorite_track_genre(favorite_track_path, user_md)
	if favorite_play_count_label:
		if favorite_track_path != "":
			favorite_play_count_label.text = tr("PROFILE_FAVORITE_PLAY_COUNT") % favorite_track_count
		else:
			favorite_play_count_label.text = tr("PROFILE_FAVORITE_PLAY_COUNT") % 0


func _update_highlight_tiles(overall_accuracy: float = -1.0) -> void:
	if overall_accuracy < 0.0:
		overall_accuracy = _compute_overall_accuracy()

	if highlight_play_time_value:
		highlight_play_time_value.text = _format_play_time(PlayerDataManager.get_total_play_time_formatted())
	if highlight_accuracy_value:
		highlight_accuracy_value.text = "%.1f%%" % overall_accuracy
	if highlight_levels_value:
		highlight_levels_value.text = str(PlayerDataManager.get_levels_completed())
	if highlight_difficulty_value:
		if PlayerDataManager.has_method("_maybe_rebuild_chart_difficulty_stats_from_results"):
			PlayerDataManager._maybe_rebuild_chart_difficulty_stats_from_results()
		var avg_difficulty := PlayerDataManager.get_average_chart_difficulty_cleared()
		highlight_difficulty_value.text = ChartDifficultyAnalyzer.format_average_rating(avg_difficulty)
		if avg_difficulty > 0.0:
			var tier_rating := clampi(int(round(avg_difficulty)), 1, ChartDifficultyAnalyzer.MAX_RATING)
			highlight_difficulty_value.add_theme_color_override(
				"font_color",
				ChartDifficultyAnalyzer.rating_color(tier_rating)
			)
		else:
			highlight_difficulty_value.add_theme_color_override(
				"font_color",
				Color(0.784314, 0.823529, 0.901961, 1)
			)
	if _login_streak_highlight_value:
		_login_streak_highlight_value.text = str(PlayerDataManager.get_login_streak())
		_login_streak_highlight_value.add_theme_color_override(
			"font_color",
			Color(0.9490196, 0.7019608, 0.3529412)
		)
	if _login_streak_highlight_caption:
		_login_streak_highlight_caption.text = tr("PROFILE_LOGIN_STREAK_CAPTION") % PlayerDataManager.get_best_login_streak()


func _format_favorite_track_genre(song_path: String, user_md: Dictionary) -> String:
	if song_path == "":
		return tr("VALUE_NA")
	if user_md is Dictionary:
		var genre := str(user_md.get("primary_genre", "")).strip_edges()
		if genre != "" and genre.to_lower() != "unknown":
			return genre
		var genres: Variant = user_md.get("genres", [])
		if genres is Array and genres.size() > 0:
			var first := str(genres[0]).strip_edges()
			if first != "" and first.to_lower() != "unknown":
				return first
	return tr("VALUE_NA")


func _get_global_medal_stats() -> Dictionary:
	if screen and screen.results_history_service and screen.results_history_service.has_method("get_global_medal_stats"):
		return screen.results_history_service.get_global_medal_stats()
	return ResultsHistoryService.new().get_global_medal_stats()


func _update_profile_medals(medal_stats: Dictionary = {}) -> void:
	if profile_medals_card == null or not profile_medals_card.has_method("set_counts"):
		return
	var stats := medal_stats if not medal_stats.is_empty() else _get_global_medal_stats()
	var counts: Variant = stats.get("counts_by_id", {})
	if counts is Dictionary:
		profile_medals_card.set_counts(counts)
	else:
		profile_medals_card.set_counts({})


func _read_basic_metadata(filepath: String) -> Dictionary:
	var result = {
		"title": filepath.get_file().get_basename(),
		"artist": tr("VALUE_UNKNOWN_ARTIST"),
		"cover": null
	}
	var ext = filepath.get_extension().to_lower()
	var global_path = ProjectSettings.globalize_path(filepath)
	if FileAccess.file_exists(global_path):
		var f = FileAccess.open(global_path, FileAccess.READ)
		if f:
			var data = f.get_buffer(f.get_length())
			f.close()
			var md = MusicMetadata.new()
			md.set_from_data(data)
			if md.title != "":
				result["title"] = md.title
			if md.artist != "":
				result["artist"] = md.artist
			result["cover"] = md.cover
	if ext == "wav":
		if result["title"] == filepath.get_file().get_basename():
			var stem = filepath.get_file().get_basename()
			if " - " in stem:
				var parts = stem.split(" - ", false, 1)
				if parts.size() == 2:
					result["artist"] = parts[0].strip_edges()
					result["title"] = parts[1].strip_edges()
	return result


func _get_cover_from_file(filepath: String):
	if filepath == "":
		return null
	var ext = filepath.get_extension().to_lower()
	if ext != "mp3" and ext != "wav":
		return null
	var global_path = ProjectSettings.globalize_path(filepath)
	if not FileAccess.file_exists(global_path):
		return null
	var file_access = FileAccess.open(global_path, FileAccess.READ)
	if not file_access:
		return null
	var file_data = file_access.get_buffer(file_access.get_length())
	file_access.close()
	var md = MusicMetadata.new()
	md.set_from_data(file_data)
	return md.cover


func _get_fallback_cover_path() -> String:
	return TrackPlaceholderCover.path_random()


func _get_fallback_cover_texture() -> Texture2D:
	var fallback_cover_path := _get_fallback_cover_path()
	if fallback_cover_path == "":
		return null
	var loader := ThreadedTextureLoader.get_instance()
	if loader:
		var cached := loader.get_cached(fallback_cover_path)
		if cached:
			return cached
	var tex := load(fallback_cover_path) as Texture2D
	return tex


func _update_recent_achievements() -> void:
	if achievements_list_vbox == null:
		return
	for child in achievements_list_vbox.get_children():
		achievements_list_vbox.remove_child(child)
		child.queue_free()

	var achievements_source: Array = []
	if screen and screen.achievement_manager and screen.achievement_manager.achievements.size() > 0:
		achievements_source = screen.achievement_manager.achievements
	else:
		var user_path = "user://achievements_data.json"
		if not FileAccess.file_exists(user_path):
			if achievements_empty_label:
				achievements_empty_label.visible = true
			return
		var file := FileAccess.open(user_path, FileAccess.READ)
		if not file:
			if achievements_empty_label:
				achievements_empty_label.visible = true
			return
		var parsed = JSON.parse_string(file.get_as_text())
		file.close()
		if not parsed or not parsed.has("achievements") or not (parsed.achievements is Array):
			if achievements_empty_label:
				achievements_empty_label.visible = true
			return
		achievements_source = parsed.achievements

	var unlocked_list: Array[Dictionary] = []
	for item in achievements_source:
		if item is Dictionary and item.get("unlocked", false) and item.get("unlock_date", null) != null:
			unlocked_list.append(item)
	unlocked_list.sort_custom(Callable(self, "_sort_by_unlock_date_desc"))
	var to_display = unlocked_list.slice(0, min(_OVERVIEW_ACHIEVEMENT_LIMIT, unlocked_list.size()))
	if achievements_empty_label:
		achievements_empty_label.visible = to_display.size() == 0
	for ach in to_display:
		var card: PanelContainer = null
		if achievement_card_template:
			card = achievement_card_template.duplicate(
				Node.DUPLICATE_SCRIPTS | Node.DUPLICATE_GROUPS | Node.DUPLICATE_SIGNALS
			)
			card.visible = true
		else:
			card = ACHIEVEMENT_CARD_SCENE.instantiate()
		achievements_list_vbox.add_child(card)
		_configure_profile_achievement_card(card)
		card.apply_achievement(ach, screen.achievement_manager if screen else null)
	call_deferred("_sync_overview_portrait_row_layout")


func _configure_profile_achievement_card(card: PanelContainer) -> void:
	var progress_label := card.get_node_or_null(
		"MarginContainer/ContentContainer/TopRowContainer/ProgressLabel"
	) as Label
	if progress_label:
		progress_label.visible = false
		progress_label.custom_minimum_size = Vector2.ZERO
	var info_vbox := card.get_node_or_null(
		"MarginContainer/ContentContainer/TopRowContainer/InfoVBox"
	) as VBoxContainer
	if info_vbox:
		info_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var title_label := card.get_node_or_null(
		"MarginContainer/ContentContainer/TopRowContainer/InfoVBox/TitleLabel"
	) as Label
	if title_label:
		title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		title_label.text_overrun_behavior = TextServer.OVERRUN_NO_TRIMMING
		title_label.clip_text = false


func _sort_by_unlock_date_desc(a: Dictionary, b: Dictionary) -> bool:
	var ka = TimeUtils.unlock_date_key(str(a.get("unlock_date", "")))
	var kb = TimeUtils.unlock_date_key(str(b.get("unlock_date", "")))
	if ka[0] != kb[0]:
		return ka[0] > kb[0]
	if ka[1] != kb[1]:
		return ka[1] > kb[1]
	if ka[2] != kb[2]:
		return ka[2] > kb[2]
	if ka[3] != kb[3]:
		return ka[3] > kb[3]
	return ka[4] > kb[4]


func _remove_play_modes_summary_if_present() -> void:
	var legacy := get_node_or_null("PlayModesSummaryCard") as Node
	if legacy:
		legacy.queue_free()
	_play_modes_panel = null
	_play_modes_summary_row = null
	_marathon_progress = null
	_marathon_progress_hint = null
	_marathon_caption = null
	_marathon_medal_row = null
	_marathon_medal_icon = null
	_marathon_medal_label = null
	_marathon_details = null
	_mod_progress = null
	_mod_progress_hint = null
	_mod_caption = null
	_mod_top_icons = null
	_mod_details = null
	_play_modes_marathon_cache.clear()
	_play_modes_mod_cache.clear()
	_cached_marathon_tier = ""


func _setup_play_modes_summary() -> void:
	_remove_play_modes_summary_if_present()


func _create_play_modes_block(kind: String) -> VBoxContainer:
	var block := VBoxContainer.new()
	block.add_theme_constant_override("separation", 6)
	block.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 8)
	block.add_child(header)

	var title := Label.new()
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.add_theme_color_override("font_color", Color(0.41960785, 0.5686275, 0.8235294, 1))
	title.add_theme_font_size_override("font_size", 15)
	title.text = tr("PROFILE_OVERVIEW_MARATHON_TITLE") if kind == "marathon" else tr("PROFILE_OVERVIEW_MODS_TITLE")
	header.add_child(title)

	var details := Button.new()
	details.flat = true
	details.add_theme_font_size_override("font_size", 12)
	details.text = tr("PROFILE_OVERVIEW_DETAILS_LINK")
	header.add_child(details)

	var progress := ProgressBar.new()
	progress.custom_minimum_size = Vector2(0, 10)
	progress.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	progress.show_percentage = false
	progress.max_value = 100.0
	block.add_child(progress)

	var progress_hint := Label.new()
	progress_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	progress_hint.add_theme_font_size_override("font_size", 11)
	progress_hint.add_theme_color_override("font_color", Color(0.55, 0.6, 0.7, 0.88))

	var caption_row := HBoxContainer.new()
	caption_row.add_theme_constant_override("separation", 8)
	caption_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	block.add_child(caption_row)

	var caption := Label.new()
	caption.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	caption.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	caption.add_theme_font_size_override("font_size", 13)
	caption.add_theme_color_override("font_color", Color(0.72, 0.78, 0.9, 0.92))

	if kind == "marathon":
		_marathon_progress = progress
		_marathon_progress_hint = progress_hint
		progress_hint.text = tr("PROFILE_OVERVIEW_MARATHON_PROGRESS_HINT")
		var marathon_fill := StyleBoxFlat.new()
		marathon_fill.bg_color = Color(0.35, 0.55, 0.92, 1.0)
		marathon_fill.set_corner_radius_all(4)
		progress.add_theme_stylebox_override("fill", marathon_fill)
		block.add_child(progress_hint)
		_marathon_caption = caption
		caption_row.add_child(caption)
		_marathon_medal_row = HBoxContainer.new()
		_marathon_medal_row.name = "MarathonMedalRow"
		_marathon_medal_row.add_theme_constant_override("separation", 6)
		_marathon_medal_row.visible = false
		block.add_child(_marathon_medal_row)
		_marathon_medal_icon = Control.new()
		_marathon_medal_icon.name = "MarathonMedalIcon"
		_marathon_medal_row.add_child(_marathon_medal_icon)
		_marathon_medal_label = Label.new()
		_marathon_medal_label.add_theme_font_size_override("font_size", 13)
		_marathon_medal_label.add_theme_color_override("font_color", Color(0.72, 0.78, 0.9, 0.92))
		_marathon_medal_row.add_child(_marathon_medal_label)
		_marathon_details = details
		if not details.pressed.is_connected(_on_marathon_details_pressed):
			details.pressed.connect(_on_marathon_details_pressed)
	else:
		_mod_progress = progress
		_mod_progress_hint = progress_hint
		progress_hint.text = tr("PROFILE_OVERVIEW_MODS_PROGRESS_HINT")
		var mod_fill := StyleBoxFlat.new()
		mod_fill.bg_color = Color(0.75, 0.52, 0.98, 1.0)
		mod_fill.set_corner_radius_all(4)
		progress.add_theme_stylebox_override("fill", mod_fill)
		block.add_child(progress_hint)
		_mod_caption = caption
		_mod_details = details
		_mod_top_icons = HBoxContainer.new()
		_mod_top_icons.name = "ModTopIcons"
		_mod_top_icons.add_theme_constant_override("separation", 4)
		caption_row.add_child(_mod_top_icons)
		caption_row.add_child(caption)
		if not details.pressed.is_connected(_on_mod_details_pressed):
			details.pressed.connect(_on_mod_details_pressed)
	return block


func _on_marathon_details_pressed() -> void:
	if screen and screen.has_method("open_records_section"):
		screen.open_records_section("marathon")


func _on_mod_details_pressed() -> void:
	if screen and screen.has_method("open_records_section"):
		screen.open_records_section("mod_clears")


func _retranslate_play_modes_summary_cached() -> void:
	if _marathon_caption == null or _mod_caption == null:
		return
	if _play_modes_marathon_cache.is_empty() and _play_modes_mod_cache.is_empty():
		return
	var marathon := _play_modes_marathon_cache
	var mod := _play_modes_mod_cache
	var mod_total := _ProfilePlayModesStats.MOD_STAT_SPECS.size()
	var mod_mastered := _ProfilePlayModesStats.mods_mastered_count()
	var routes_attempted := int(marathon.get("routes_attempted", 0))
	var routes_completed := int(marathon.get("routes_completed", 0))
	if routes_attempted <= 0:
		_marathon_caption.text = tr("PROFILE_OVERVIEW_MARATHON_EMPTY")
	else:
		_marathon_caption.text = tr("PROFILE_OVERVIEW_MARATHON_ROUTES_FMT") % [routes_completed, routes_attempted]
	if _marathon_progress_hint:
		_marathon_progress_hint.text = tr("PROFILE_OVERVIEW_MARATHON_PROGRESS_HINT")
	if _cached_marathon_tier.strip_edges() != "" and _marathon_medal_label:
		var tier_label := _ProfilePlayModesStats.badge_tier_label(_cached_marathon_tier)
		_marathon_medal_label.text = tr("PROFILE_OVERVIEW_MARATHON_BEST_MEDAL_FMT") % tier_label
	if int(mod.get("clears_any", 0)) <= 0:
		_mod_caption.text = tr("PROFILE_OVERVIEW_MODS_EMPTY")
	else:
		var top_mod := str(mod.get("top_mod_id", ""))
		var top_count := int(mod.get("top_mod_count", 0))
		if top_mod != "" and top_count > 0:
			_mod_caption.text = tr("PROFILE_OVERVIEW_MODS_TOP_COUNT_FMT") % top_count
			_mod_caption.text += " · " + (tr("PROFILE_OVERVIEW_MODS_MASTERED_FMT") % [mod_mastered, mod_total])
		else:
			_mod_caption.text = tr("PROFILE_OVERVIEW_MODS_MASTERED_FMT") % [mod_mastered, mod_total]
	if _mod_progress_hint:
		_mod_progress_hint.text = tr("PROFILE_OVERVIEW_MODS_PROGRESS_HINT")


func _update_play_modes_summary() -> void:
	if _marathon_caption == null or _mod_caption == null:
		return
	var marathon := _ProfilePlayModesStats.marathon_summary()
	var mod := _ProfilePlayModesStats.mod_summary()
	var prev_top_mod := str(_play_modes_mod_cache.get("top_mod_id", ""))
	_play_modes_marathon_cache = marathon.duplicate(true)
	_play_modes_marathon_cache["mod_mastered"] = _ProfilePlayModesStats.mods_mastered_count()
	_play_modes_mod_cache = mod.duplicate(true)
	var mod_total := _ProfilePlayModesStats.MOD_STAT_SPECS.size()
	var mod_mastered := _ProfilePlayModesStats.mods_mastered_count()

	var routes_attempted := int(marathon.get("routes_attempted", 0))
	var routes_completed := int(marathon.get("routes_completed", 0))
	if _marathon_progress:
		if routes_attempted <= 0:
			_marathon_progress.value = 0.0
		else:
			_marathon_progress.value = float(routes_completed) / float(routes_attempted) * 100.0
	if routes_attempted <= 0:
		_marathon_caption.text = tr("PROFILE_OVERVIEW_MARATHON_EMPTY")
		if _marathon_progress_hint:
			_marathon_progress_hint.text = tr("PROFILE_OVERVIEW_MARATHON_PROGRESS_HINT")
		_update_marathon_medal_icon("")
	else:
		_marathon_caption.text = tr("PROFILE_OVERVIEW_MARATHON_ROUTES_FMT") % [routes_completed, routes_attempted]
		if _marathon_progress_hint:
			_marathon_progress_hint.text = tr("PROFILE_OVERVIEW_MARATHON_PROGRESS_HINT")
		var tier := str(marathon.get("best_badge_tier", ""))
		var tier_label := _ProfilePlayModesStats.badge_tier_label(tier) if tier != "" else ""
		if tier != _cached_marathon_tier:
			_update_marathon_medal_icon(tier, tier_label)
		elif _marathon_medal_label and tier_label != "":
			_marathon_medal_label.text = tr("PROFILE_OVERVIEW_MARATHON_BEST_MEDAL_FMT") % tier_label

	if _mod_progress:
		_mod_progress.value = float(mod_mastered) / float(maxi(mod_total, 1)) * 100.0
	if int(mod.get("clears_any", 0)) <= 0:
		_mod_caption.text = tr("PROFILE_OVERVIEW_MODS_EMPTY")
		if _mod_progress_hint:
			_mod_progress_hint.text = tr("PROFILE_OVERVIEW_MODS_PROGRESS_HINT")
		if _mod_top_icons and _mod_top_icons.get_child_count() > 0:
			for child in _mod_top_icons.get_children():
				child.queue_free()
	else:
		var top_mod := str(mod.get("top_mod_id", ""))
		var top_count := int(mod.get("top_mod_count", 0))
		if _mod_top_icons and (top_mod != prev_top_mod or _mod_top_icons.get_child_count() == 0):
			for child in _mod_top_icons.get_children():
				child.queue_free()
			if top_mod != "" and top_count > 0:
				_ModifierIconStrip.fill_slot_chips(_mod_top_icons, [top_mod], {}, 1, true)
		if top_mod != "" and top_count > 0:
			_mod_caption.text = tr("PROFILE_OVERVIEW_MODS_TOP_COUNT_FMT") % top_count
			_mod_caption.text += " · " + (tr("PROFILE_OVERVIEW_MODS_MASTERED_FMT") % [mod_mastered, mod_total])
			if _mod_progress_hint:
				_mod_progress_hint.text = tr("PROFILE_OVERVIEW_MODS_PROGRESS_HINT")
		else:
			_mod_caption.text = tr("PROFILE_OVERVIEW_MODS_MASTERED_FMT") % [mod_mastered, mod_total]
			if _mod_progress_hint:
				_mod_progress_hint.text = tr("PROFILE_OVERVIEW_MODS_PROGRESS_HINT")


func _update_marathon_medal_icon(tier: String, tier_label: String = "") -> void:
	if _marathon_medal_row == null or _marathon_medal_icon == null or _marathon_medal_label == null:
		return
	_cached_marathon_tier = tier
	for child in _marathon_medal_icon.get_children():
		child.queue_free()
	if tier.strip_edges() == "" or tier_label.strip_edges() == "":
		_cached_marathon_tier = ""
		_marathon_medal_row.visible = false
		return
	var tint := _MarathonRouteBadges.tier_accent(tier)
	_marathon_medal_icon.custom_minimum_size = Vector2(22, 22)
	_marathon_medal_icon.add_child(
		_UiIconHelper.make_icon_frame(_MarathonRouteBadges.tier_icon_file(tier), 22, 12, tint)
	)
	_marathon_medal_label.text = tr("PROFILE_OVERVIEW_MARATHON_BEST_MEDAL_FMT") % tier_label
	_marathon_medal_row.visible = true


func _overview_card_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.094118, 0.094118, 0.121569, 1)
	style.border_color = Color(1, 1, 1, 0.08)
	style.set_border_width_all(1)
	style.set_corner_radius_all(8)
	style.content_margin_left = 12.0
	style.content_margin_top = 10.0
	style.content_margin_right = 12.0
	style.content_margin_bottom = 10.0
	return style


func _setup_overview_extras() -> void:
	if _overview_extras_ready:
		return
	_overview_extras_ready = true

	_remove_legacy_login_streak_card()
	if _login_streak_highlight_value == null:
		_setup_login_streak_highlight()
	if _rr_highlight_value == null:
		_setup_rr_highlight()
	_bind_genre_portrait_card()
	_remove_play_modes_summary_if_present()

	_reorganize_overview_bottom_row()

	if _genre_portrait_title:
		_genre_portrait_title.text = tr("PROFILE_GENRE_PORTRAIT_TITLE")
	if _genre_portrait_empty_label:
		_genre_portrait_empty_label.text = tr("PROFILE_GENRE_PORTRAIT_EMPTY")


func _bind_genre_portrait_card() -> void:
	if _genre_portrait_card == null:
		_genre_portrait_card = get_node_or_null("GenrePortraitCard") as PanelContainer
	if _genre_portrait_card:
		_genre_portrait_title = _genre_portrait_card.get_node_or_null("ContentVBox/TitleLabel") as Label
		_genre_portrait_empty_label = _genre_portrait_card.get_node_or_null("ContentVBox/EmptyLabel") as Label
		var genre_vbox := _genre_portrait_card.get_node_or_null("ContentVBox") as VBoxContainer
		if genre_vbox:
			genre_vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
		_ensure_genre_portrait_grid(genre_vbox)
		_ensure_genre_portrait_spacer(genre_vbox)
		return

	_genre_portrait_card = PanelContainer.new()
	_genre_portrait_card.name = "GenrePortraitCard"
	_genre_portrait_card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_genre_portrait_card.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_genre_portrait_card.add_theme_stylebox_override("panel", _overview_card_style())

	var genre_vbox := VBoxContainer.new()
	genre_vbox.name = "ContentVBox"
	genre_vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	genre_vbox.add_theme_constant_override("separation", 6)
	_genre_portrait_card.add_child(genre_vbox)

	_genre_portrait_title = Label.new()
	_genre_portrait_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_genre_portrait_title.add_theme_color_override("font_color", Color(0.41960785, 0.5686275, 0.8235294, 1))
	genre_vbox.add_child(_genre_portrait_title)

	_ensure_genre_portrait_grid(genre_vbox)
	_ensure_genre_portrait_spacer(genre_vbox)

	_genre_portrait_empty_label = Label.new()
	_genre_portrait_empty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_genre_portrait_empty_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_genre_portrait_empty_label.add_theme_color_override("font_color", Color(0.654902, 0.654902, 0.678431, 1))
	_genre_portrait_empty_label.visible = false
	genre_vbox.add_child(_genre_portrait_empty_label)


func _ensure_genre_portrait_grid(parent: VBoxContainer) -> void:
	if parent == null:
		return
	var existing_grid := parent.get_node_or_null("RowsGrid") as GridContainer
	if existing_grid:
		_genre_portrait_rows = existing_grid
		_configure_genre_portrait_grid(_genre_portrait_rows)
		return
	var legacy_rows := parent.get_node_or_null("RowsVBox")
	if legacy_rows:
		var insert_idx := legacy_rows.get_index()
		parent.remove_child(legacy_rows)
		legacy_rows.queue_free()
		_genre_portrait_rows = _create_genre_portrait_grid()
		parent.add_child(_genre_portrait_rows)
		parent.move_child(_genre_portrait_rows, insert_idx)
		return
	if _genre_portrait_rows == null or not is_instance_valid(_genre_portrait_rows):
		_genre_portrait_rows = _create_genre_portrait_grid()
		var title_idx := _genre_portrait_title.get_index() if _genre_portrait_title else 0
		parent.add_child(_genre_portrait_rows)
		parent.move_child(_genre_portrait_rows, title_idx + 1)


func _create_genre_portrait_grid() -> GridContainer:
	var grid := GridContainer.new()
	grid.name = "RowsGrid"
	_configure_genre_portrait_grid(grid)
	return grid


func _configure_genre_portrait_grid(grid: GridContainer) -> void:
	_GenrePortraitRowsUi.configure_grid(grid)


func _ensure_genre_portrait_spacer(parent: VBoxContainer) -> void:
	if parent == null:
		return
	_genre_portrait_spacer = parent.get_node_or_null("PortraitBottomSpacer") as Control
	if _genre_portrait_spacer:
		return
	_genre_portrait_spacer = Control.new()
	_genre_portrait_spacer.name = "PortraitBottomSpacer"
	_genre_portrait_spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_genre_portrait_spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var insert_idx := parent.get_child_count()
	if _genre_portrait_empty_label and _genre_portrait_empty_label.get_parent() == parent:
		insert_idx = _genre_portrait_empty_label.get_index()
	parent.add_child(_genre_portrait_spacer)
	parent.move_child(_genre_portrait_spacer, insert_idx)


func _reorganize_overview_bottom_row() -> void:
	if _genre_portrait_card == null:
		return
	var achievements_card := get_node_or_null("RecentAchievementsCard") as PanelContainer
	if achievements_card == null:
		return

	if _overview_portrait_row == null:
		_overview_portrait_row = get_node_or_null("PortraitAchievementsRow") as HBoxContainer
	if _overview_portrait_row == null:
		_overview_portrait_row = HBoxContainer.new()
		_overview_portrait_row.name = "PortraitAchievementsRow"
		_overview_portrait_row.add_theme_constant_override("separation", 6)
		_overview_portrait_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_overview_portrait_row.size_flags_vertical = Control.SIZE_SHRINK_BEGIN

		var row_idx := get_child_count()
		if profile_medals_card:
			row_idx = profile_medals_card.get_index() + 1
		elif achievements_card.get_parent() == self:
			row_idx = achievements_card.get_index()

		add_child(_overview_portrait_row)
		move_child(_overview_portrait_row, row_idx)

	if _genre_portrait_card.get_parent() != _overview_portrait_row:
		var genre_parent := _genre_portrait_card.get_parent()
		if genre_parent:
			genre_parent.remove_child(_genre_portrait_card)
		_genre_portrait_card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_genre_portrait_card.size_flags_vertical = Control.SIZE_EXPAND_FILL
		_genre_portrait_card.size_flags_stretch_ratio = _OVERVIEW_PORTRAIT_ROW_GENRE_STRETCH
		_overview_portrait_row.add_child(_genre_portrait_card)
		_overview_portrait_row.move_child(_genre_portrait_card, 0)

	if achievements_card.get_parent() != _overview_portrait_row:
		var achievements_parent := achievements_card.get_parent()
		if achievements_parent:
			achievements_parent.remove_child(achievements_card)
		achievements_card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		achievements_card.size_flags_vertical = Control.SIZE_EXPAND_FILL
		achievements_card.size_flags_stretch_ratio = _OVERVIEW_PORTRAIT_ROW_ACHIEVEMENTS_STRETCH
		_overview_portrait_row.add_child(achievements_card)

	var achievements_vbox := achievements_card.get_node_or_null("ContentVBox") as VBoxContainer
	if achievements_vbox:
		achievements_vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	if _genre_portrait_card:
		_genre_portrait_card.size_flags_vertical = Control.SIZE_EXPAND_FILL
		_genre_portrait_card.size_flags_stretch_ratio = _OVERVIEW_PORTRAIT_ROW_GENRE_STRETCH
		var genre_vbox := _genre_portrait_card.get_node_or_null("ContentVBox") as VBoxContainer
		if genre_vbox:
			genre_vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
			_ensure_genre_portrait_grid(genre_vbox)
			_ensure_genre_portrait_spacer(genre_vbox)
	if achievements_card:
		achievements_card.size_flags_stretch_ratio = _OVERVIEW_PORTRAIT_ROW_ACHIEVEMENTS_STRETCH


func _sync_overview_portrait_row_layout() -> void:
	if _overview_portrait_row == null or _genre_portrait_card == null:
		return
	var achievements_card := _overview_portrait_row.get_node_or_null("RecentAchievementsCard") as PanelContainer
	if achievements_card == null:
		return
	_genre_portrait_card.size_flags_vertical = Control.SIZE_EXPAND_FILL
	achievements_card.size_flags_vertical = Control.SIZE_EXPAND_FILL
	if _genre_portrait_spacer:
		_genre_portrait_spacer.visible = _genre_portrait_rows != null and _genre_portrait_rows.get_child_count() > 0


func _remove_legacy_login_streak_card() -> void:
	var legacy_card := get_node_or_null("LoginStreakCard")
	if legacy_card:
		legacy_card.queue_free()


func _setup_login_streak_highlight() -> void:
	if highlights_row == null:
		return
	var existing := highlights_row.get_node_or_null("LoginStreakHighlight") as PanelContainer
	if existing:
		_login_streak_highlight_value = existing.get_node_or_null("VBox/ValueLabel") as Label
		_login_streak_highlight_caption = existing.get_node_or_null("VBox/CaptionLabel") as Label
		return

	var ref_tile := highlights_row.get_node_or_null("PlayTimeHighlight") as PanelContainer
	var tile := PanelContainer.new()
	tile.name = "LoginStreakHighlight"
	tile.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if ref_tile:
		var panel_style := ref_tile.get_theme_stylebox("panel")
		if panel_style:
			tile.add_theme_stylebox_override("panel", panel_style.duplicate())

	var vbox := VBoxContainer.new()
	vbox.name = "VBox"
	vbox.add_theme_constant_override("separation", 1)
	tile.add_child(vbox)

	_login_streak_highlight_value = Label.new()
	_login_streak_highlight_value.name = "ValueLabel"
	_login_streak_highlight_value.text = "0"
	_login_streak_highlight_value.add_theme_font_size_override("font_size", 28)
	_login_streak_highlight_value.add_theme_color_override("font_color", Color(0.9490196, 0.7019608, 0.3529412))
	vbox.add_child(_login_streak_highlight_value)

	_login_streak_highlight_caption = Label.new()
	_login_streak_highlight_caption.name = "CaptionLabel"
	_login_streak_highlight_caption.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_login_streak_highlight_caption.add_theme_font_size_override("font_size", 13)
	_login_streak_highlight_caption.add_theme_color_override("font_color", Color(0.654902, 0.654902, 0.678431, 1))
	vbox.add_child(_login_streak_highlight_caption)

	highlights_row.add_child(tile)
	var difficulty_tile := highlights_row.get_node_or_null("DifficultyHighlight")
	if difficulty_tile:
		highlights_row.move_child(tile, difficulty_tile.get_index() + 1)


func _setup_rr_highlight() -> void:
	if highlights_row == null:
		return
	var existing := highlights_row.get_node_or_null("RhythmRatingHighlight") as PanelContainer
	if existing:
		_rr_highlight_value = existing.get_node_or_null("VBox/ValueLabel") as Label
		_rr_highlight_caption = existing.get_node_or_null("VBox/CaptionLabel") as Label
		return

	var ref_tile := highlights_row.get_node_or_null("LevelsHighlight") as PanelContainer
	var tile := PanelContainer.new()
	tile.name = "RhythmRatingHighlight"
	tile.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if ref_tile:
		var panel_style := ref_tile.get_theme_stylebox("panel")
		if panel_style:
			tile.add_theme_stylebox_override("panel", panel_style.duplicate())

	var vbox := VBoxContainer.new()
	vbox.name = "VBox"
	vbox.add_theme_constant_override("separation", 1)
	tile.add_child(vbox)

	_rr_highlight_value = Label.new()
	_rr_highlight_value.name = "ValueLabel"
	_rr_highlight_value.text = "0"
	_rr_highlight_value.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_rr_highlight_value.add_theme_font_size_override("font_size", 28)
	_rr_highlight_value.add_theme_color_override("font_color", Color(0.9490196, 0.7019608, 0.3529412))
	vbox.add_child(_rr_highlight_value)

	_rr_highlight_caption = Label.new()
	_rr_highlight_caption.name = "CaptionLabel"
	_rr_highlight_caption.text = tr("PROFILE_STAT_TOTAL_RR")
	_rr_highlight_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_rr_highlight_caption.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_rr_highlight_caption.add_theme_font_size_override("font_size", 13)
	_rr_highlight_caption.add_theme_color_override("font_color", Color(0.654902, 0.654902, 0.678431, 1))
	vbox.add_child(_rr_highlight_caption)

	highlights_row.add_child(tile)
	var streak_tile := highlights_row.get_node_or_null("LoginStreakHighlight")
	if streak_tile:
		highlights_row.move_child(tile, streak_tile.get_index() + 1)


func _update_login_streak_display() -> void:
	if _login_streak_highlight_value:
		_login_streak_highlight_value.text = str(PlayerDataManager.get_login_streak())
	if _login_streak_highlight_caption:
		_login_streak_highlight_caption.text = tr("PROFILE_LOGIN_STREAK_CAPTION") % PlayerDataManager.get_best_login_streak()
	if _rr_highlight_caption:
		_rr_highlight_caption.text = tr("PROFILE_STAT_TOTAL_RR")
	if _rr_highlight_value:
		_rr_highlight_value.text = str(screen.get_total_rr_earned() if screen else 0)
		_rr_highlight_value.add_theme_color_override("font_color", Color(0.9490196, 0.7019608, 0.3529412))


func _genre_group_label(group_id: String) -> String:
	var key := _ProfileGenrePortrait.group_locale_key(group_id)
	var label := tr(key)
	if label == key:
		return group_id.replace("_", " ").capitalize()
	return label


func _update_genre_portrait() -> void:
	if _genre_portrait_card:
		var genre_vbox := _genre_portrait_card.get_node_or_null("ContentVBox") as VBoxContainer
		_ensure_genre_portrait_grid(genre_vbox)
	if _genre_portrait_rows == null:
		return
	for child in _genre_portrait_rows.get_children():
		child.queue_free()

	var top_groups: Array = _ProfileGenrePortrait.top_groups(
		TrackStatsManager.genre_play_counts, _OVERVIEW_GENRE_PORTRAIT_LIMIT
	)
	if top_groups.is_empty():
		if _genre_portrait_empty_label:
			_genre_portrait_empty_label.visible = true
		return
	if _genre_portrait_empty_label:
		_genre_portrait_empty_label.visible = false

	var max_count := 1
	for row in top_groups:
		max_count = maxi(max_count, int(row.get("count", 0)))

	for row in top_groups:
		var group_id := str(row.get("group", ""))
		var count := int(row.get("count", 0))
		var group_tint := _GenreGroupIcons.tint_for_group(group_id)
		_GenrePortraitRowsUi.add_grid_row(
			_genre_portrait_rows,
			_GenrePortraitRowsUi.icon_cell_for_group(group_id, group_tint),
			_genre_group_label(group_id),
			float(count),
			float(max_count),
			str(count),
			group_tint
		)
