# scenes/profile/profile_screen.gd
class_name ProfileScreen
extends BaseScreen

const ACHIEVEMENT_CARD_SCENE := preload("res://scenes/achievements/achievement_card.tscn")
const ACHIEVEMENTS_JSON_PATH := "res://data/achievements_data.json"

@onready var back_button: Button = $MainContent/MainVBox/BackButton
@onready var levels_completed_label: Label = $MainContent/MainVBox/TopSection/LeftColumn/GeneralStatsCard/ContentVBox/LevelsCompletedLabel
@onready var drum_levels_completed_label: Label = $MainContent/MainVBox/TopSection/RightColumn/PercussionCard/ContentVBox/DrumLevelsCompletedLabel
@onready var unique_levels_completed_label: Label = $MainContent/MainVBox/TopSection/LeftColumn/GeneralStatsCard/ContentVBox/UniqueLevelsCompletedLabel
@onready var overall_accuracy_label: Label = $MainContent/MainVBox/TopSection/LeftColumn/GeneralStatsCard/ContentVBox/OverallAccuracyLabel
@onready var drum_overall_accuracy_label: Label = $MainContent/MainVBox/TopSection/RightColumn/PercussionCard/ContentVBox/DrumOverallAccuracyLabel
@onready var play_time_label: Label = $MainContent/MainVBox/TopSection/LeftColumn/GeneralStatsCard/ContentVBox/PlayTimeLabel
@onready var start_date_label: Label = get_node_or_null("MainContent/MainVBox/TopSection/LeftColumn/GeneralStatsCard/ContentVBox/StartDateLabel")
@onready var total_notes_hit_label: Label = $MainContent/MainVBox/TopSection/LeftColumn/GeneralStatsCard/ContentVBox/TotalNotesHitLabel 
@onready var total_drum_hits_label: Label = $MainContent/MainVBox/TopSection/RightColumn/PercussionCard/ContentVBox/TotalDrumHitsLabel
@onready var total_notes_missed_label: Label = $MainContent/MainVBox/TopSection/LeftColumn/GeneralStatsCard/ContentVBox/TotalNotesMissedLabel
@onready var total_drum_misses_label: Label = $MainContent/MainVBox/TopSection/RightColumn/PercussionCard/ContentVBox/TotalDrumMissesLabel
@onready var max_hit_streak_label: Label = $MainContent/MainVBox/TopSection/LeftColumn/GeneralStatsCard/ContentVBox/MaxHitStreakLabel
@onready var max_drum_hit_streak_label: Label = $MainContent/MainVBox/TopSection/RightColumn/PercussionCard/ContentVBox/MaxDrumHitStreakLabel
@onready var total_earned_currency_label: Label = $MainContent/MainVBox/TopSection/CenterColumn/EconomyCard/ContentVBox/TotalEarnedCurrencyLabel
@onready var spent_currency_label: Label = $MainContent/MainVBox/TopSection/CenterColumn/EconomyCard/ContentVBox/SpentCurrencyLabel
@onready var total_score_label: Label = $MainContent/MainVBox/TopSection/LeftColumn/GeneralStatsCard/ContentVBox/TotalScoreLabel
@onready var total_drum_score_label: Label = $MainContent/MainVBox/TopSection/RightColumn/PercussionCard/ContentVBox/TotalDrumScoreLabel
@onready var level_label: Label = $MainContent/MainVBox/TopSection/CenterColumn/LevelXPCard/ContentVBox/LevelLabel
@onready var xp_label: Label = $MainContent/MainVBox/TopSection/CenterColumn/LevelXPCard/ContentVBox/XPLabel
@onready var xp_progress_label: Label = $MainContent/MainVBox/TopSection/CenterColumn/LevelXPCard/ContentVBox/XPProgressLabel

@onready var ss_label: Label = $MainContent/MainVBox/TopSection/RightColumn/GradesCard/MainVBox/ContentHBox/SSLabel
@onready var s_label: Label = $MainContent/MainVBox/TopSection/RightColumn/GradesCard/MainVBox/ContentHBox/SLabel
@onready var a_label: Label = $MainContent/MainVBox/TopSection/RightColumn/GradesCard/MainVBox/ContentHBox/ALabel
@onready var b_label: Label = $MainContent/MainVBox/TopSection/RightColumn/GradesCard/MainVBox/ContentHBox/BLabel
@onready var daily_quests_completed_label: Label = $MainContent/MainVBox/TopSection/LeftColumn/GeneralStatsCard/ContentVBox/DailyQuestsCompletedLabel

@onready var accuracy_chart_line: Line2D = $MainContent/MainVBox/ChartCard/ChartContainer/ChartBackground/AccuracyChartLine
@onready var accuracy_chart_points: Control = $MainContent/MainVBox/ChartCard/ChartContainer/ChartBackground/AccuracyChartPoints
@onready var chart_background: ColorRect = $MainContent/MainVBox/ChartCard/ChartContainer/ChartBackground
@onready var tooltip_label: RichTextLabel = get_node_or_null(NodePath("MainContent/MainVBox/ChartCard/ChartContainer/TooltipLabel")) as RichTextLabel

@onready var favorite_track_card: PanelContainer = get_node_or_null("MainContent/MainVBox/TopSection/FavoriteTrackColumn/FavoriteTrackCard")
@onready var favorite_cover_texture_rect: TextureRect = get_node_or_null("MainContent/MainVBox/TopSection/FavoriteTrackColumn/FavoriteTrackCard/ContentVBox/FavoriteCoverTextureRect")
@onready var favorite_title_label: Label = get_node_or_null("MainContent/MainVBox/TopSection/FavoriteTrackColumn/FavoriteTrackCard/ContentVBox/FavoriteTitleLabel")
@onready var favorite_artist_label: Label = get_node_or_null("MainContent/MainVBox/TopSection/FavoriteTrackColumn/FavoriteTrackCard/ContentVBox/FavoriteArtistLabel")
@onready var favorite_genre_label: Label = get_node_or_null("MainContent/MainVBox/TopSection/FavoriteTrackColumn/FavoriteTrackCard/ContentVBox/FavoriteGenreLabel")

@onready var achievements_list_vbox: VBoxContainer = get_node_or_null("MainContent/MainVBox/TopSection/AchievementsColumn/RecentAchievementsCard/ContentVBox/AchievementsListVBox")
@onready var achievements_empty_label: Label = get_node_or_null("MainContent/MainVBox/TopSection/AchievementsColumn/RecentAchievementsCard/ContentVBox/AchievementsListVBox/EmptyLabel")
@onready var achievement_card_template: PanelContainer = get_node_or_null("MainContent/MainVBox/TopSection/AchievementsColumn/RecentAchievementsCard/ContentVBox/TemplateAchievementCard/AchievementCard")

var session_history_manager = null
var achievement_manager: AchievementManager = null

func _play_time_string_to_seconds(time_str: String) -> int:
	var parts = time_str.split(":")
	if parts.size() == 2:
		var hours = parts[0].to_int()
		var minutes = parts[1].to_int()
		return (hours * 3600) + (minutes * 60)
	return 0

func _ready():
	var game_engine = get_parent()
	if game_engine and \
	   game_engine.has_method("get_transitions"):
		
		var trans = game_engine.get_transitions()
		
		setup_managers(trans)  
		
		var session_hist_mgr = null
		if game_engine.has_method("get_session_history_manager"):
			session_hist_mgr = game_engine.get_session_history_manager()
		if game_engine.has_method("get_achievement_manager"):
			achievement_manager = game_engine.get_achievement_manager()

		if session_hist_mgr:
			setup_session_history_manager(session_hist_mgr)
		else:
			printerr("ProfileScreen.gd: SessionHistoryManager не получен из GameEngine.")

		PlayerDataManager.total_play_time_changed.connect(_on_total_play_time_changed)
		PlayerDataManager.daily_quests_updated.connect(_on_daily_quests_updated)
		if chart_background:
			chart_background.resized.connect(_on_chart_background_resized)
	else:
		printerr("ProfileScreen.gd: Не удалось получить transitions через GameEngine.")

	refresh_stats()

	if back_button:
		back_button.pressed.connect(_on_back_pressed)
	else:
		printerr("ProfileScreen: Кнопка back_button не найдена!")

func _on_total_play_time_changed(new_time: String):
	if play_time_label:
		play_time_label.text = "Времени в игре: %s" % new_time

func setup_session_history_manager(session_history_mgr):
	session_history_manager = session_history_mgr
	refresh_stats()

func refresh_stats():
	levels_completed_label.text = "Завершено уровней: %d" % PlayerDataManager.get_levels_completed()
	
	unique_levels_completed_label.text = "Пройдено уникальных треков: %d" % PlayerDataManager.get_unique_levels_completed()
	
	drum_levels_completed_label.text = "Завершено уровней: %d" % PlayerDataManager.get_drum_levels_completed()
	
	var favorite_track_path = PlayerDataManager.data.get("favorite_track", "")
	var favorite_track_count = PlayerDataManager.data.get("favorite_track_play_count", 0)
	if favorite_track_path == "" or favorite_track_count == 0:
		favorite_track_path = TrackStatsManager.get_favorite_track()
		favorite_track_count = TrackStatsManager.get_favorite_track_count()
	
	if favorite_track_card:
		var title_text = "Н/Д"
		var artist_text = "Н/Д"
		var cover_texture = null
		if favorite_track_path != "":
			favorite_track_path = favorite_track_path.replace("\\", "/").trim_suffix("/")
			var basic_md = _read_basic_metadata(favorite_track_path)
			title_text = str(basic_md.get("title", title_text))
			artist_text = str(basic_md.get("artist", artist_text))
			cover_texture = basic_md.get("cover", null)
			var user_md = SongMetadataManager.get_metadata_for_song(favorite_track_path)
			if user_md and typeof(user_md) == TYPE_DICTIONARY:
				title_text = str(user_md.get("title", title_text))
				artist_text = str(user_md.get("artist", artist_text))
		if favorite_cover_texture_rect:
			if cover_texture and cover_texture is ImageTexture:
				favorite_cover_texture_rect.texture = cover_texture
			else:
				var file_cover = _get_cover_from_file(favorite_track_path)
				if file_cover:
					favorite_cover_texture_rect.texture = file_cover
				else:
					var fallback_texture = _get_fallback_cover_texture()
					if fallback_texture:
						favorite_cover_texture_rect.texture = fallback_texture
					else:
						var gray_image = Image.create(400, 400, false, Image.FORMAT_RGBA8)
						gray_image.fill(Color(0.5, 0.5, 0.5, 1.0))
						var gray_texture = ImageTexture.create_from_image(gray_image)
						favorite_cover_texture_rect.texture = gray_texture
		if favorite_title_label:
			favorite_title_label.text = "Название: " + title_text
		if favorite_artist_label:
			favorite_artist_label.text = "Исполнитель: " + artist_text
		if favorite_genre_label:
			var fav_genre = str(PlayerDataManager.data.get("favorite_genre", "unknown"))
			if fav_genre == "unknown" or fav_genre == "":
				fav_genre = TrackStatsManager.get_favorite_genre()
			if fav_genre == "unknown" or fav_genre == "":
				fav_genre = "Н/Д"
			favorite_genre_label.text = "Любимый жанр: %s" % fav_genre
	
	var total_notes_hit = PlayerDataManager.get_total_notes_hit()
	var total_notes_missed = PlayerDataManager.get_total_notes_missed()
	var total_notes_played = total_notes_hit + total_notes_missed
	var overall_accuracy = 0.0
	if total_notes_played > 0:
		overall_accuracy = (float(total_notes_hit) / float(total_notes_played)) * 100.0
	else:
		if session_history_manager:
			var hist = session_history_manager.get_history()
			if hist.size() > 0:
				var sum_acc = 0.0
				for item in hist:
					sum_acc += float(item.get("accuracy", 0.0))
				overall_accuracy = sum_acc / float(hist.size())
	overall_accuracy_label.text = "Общая точность: %.2f%%" % overall_accuracy
	
	var total_drum_hits = PlayerDataManager.data.get("total_drum_hits", 0)
	var total_drum_misses = PlayerDataManager.data.get("total_drum_misses", 0)
	var total_drum_notes = total_drum_hits + total_drum_misses
	var drum_accuracy = 0.0
	if total_drum_notes > 0:
		drum_accuracy = (float(total_drum_hits) / float(total_drum_notes)) * 100.0
	drum_overall_accuracy_label.text = "Точность: %.2f%%" % drum_accuracy
	
	var play_time_formatted = PlayerDataManager.get_total_play_time_formatted() 
	play_time_label.text = "Времени в игре: %s" % play_time_formatted 
	if start_date_label:
		var created_str = str(PlayerDataManager.data.get("profile_created_date", ""))
		var display = _format_date_ru(created_str)
		start_date_label.text = "В RhythmFall с %s" % display
	if daily_quests_completed_label:
		daily_quests_completed_label.text = "Выполнено ежедневных заданий: %d" % PlayerDataManager.get_daily_quests_completed_total()

	var total_perfect_hits = PlayerDataManager.get_total_perfect_hits()
	total_notes_hit_label.text = "Точных попаданий: %d" % total_perfect_hits
	total_drum_hits_label.text = "Точных попаданий: %d" % total_drum_hits
	total_notes_missed_label.text = "Промахов: %d" % total_notes_missed
	total_drum_misses_label.text = "Промахов: %d" % total_drum_misses
	
	var max_streak = PlayerDataManager.data.get("max_combo_ever", 0)
	var max_drum_streak = PlayerDataManager.data.get("max_drum_combo_ever", 0)
	max_hit_streak_label.text = "Рекордная серия попаданий подряд: %d" % max_streak
	max_drum_hit_streak_label.text = "Рекордная серия попаданий подряд: %d" % max_drum_streak

	total_earned_currency_label.text = "Заработано всего: %d" % PlayerDataManager.data.get("total_earned_currency", 0)
	spent_currency_label.text = "Потрачено: %d" % PlayerDataManager.data.get("spent_currency", 0)

	var total_score = PlayerDataManager.data.get("total_score_ever", 0)
	var total_drum_score = PlayerDataManager.data.get("total_drum_score_ever", 0)
	if total_score_label:
		total_score_label.text = "Всего очков: %d" % total_score
	if total_drum_score_label:
		total_drum_score_label.text = "Очков: %d" % total_drum_score

	var grades = PlayerDataManager.data.get("grades", {})
	var ss_count = grades.get("SS", 0)
	var s_count = grades.get("S", 0)
	var a_count = grades.get("A", 0)
	var b_count = grades.get("B", 0)

	ss_label.text = "SS: %d" % ss_count
	s_label.text = "S: %d" % s_count
	a_label.text = "A: %d" % a_count
	b_label.text = "B: %d" % b_count

	ss_label.modulate = Color("#F2B35A")
	s_label.modulate = Color("#C8D2E6")
	a_label.modulate = Color("#6B91D2")
	b_label.modulate = Color("#59D1BE")

	if level_label:
		level_label.text = "Уровень: %d" % PlayerDataManager.get_current_level()
	if xp_label:
		xp_label.text = "XP: %s" % PlayerDataManager.get_xp_progress_text()
	if xp_progress_label:
		var progress_percent = PlayerDataManager.get_xp_progress() * 100.0
		xp_progress_label.text = "Прогресс: %.1f%%" % progress_percent

	if session_history_manager:
		_update_accuracy_chart()
	_update_recent_achievements()

func _format_date_ru(date_str: String) -> String:
	if date_str == "":
		var d = Time.get_date_dict_from_system()
		return _format_date_dict_ru(d)
	var parts = date_str.split("-")
	if parts.size() == 3:
		var year = int(parts[0])
		var month = int(parts[1])
		var day = int(parts[2])
		return _format_date_parts_ru(day, month, year)
	return date_str

func _format_date_dict_ru(d: Dictionary) -> String:
	return _format_date_parts_ru(int(d.get("day", 1)), int(d.get("month", 1)), int(d.get("year", 2000)))

func _format_date_parts_ru(day: int, month: int, year: int) -> String:
	var months = {
		1: "янв.", 2: "фев.", 3: "мар.", 4: "апр.", 5: "мая",
		6: "июн.", 7: "июл.", 8: "авг.", 9: "сен.", 10: "окт.", 11: "ноя.", 12: "дек."
	}
	var m = months.get(month, "")
	if m == "":
		m = str(month)
	return "%d %s %d" % [day, m, year]
func _on_daily_quests_updated():
	if daily_quests_completed_label:
		daily_quests_completed_label.text = "Выполнено ежедневных заданий: %d" % PlayerDataManager.get_daily_quests_completed_total()

func _read_basic_metadata(filepath: String) -> Dictionary:
	var result = {
		"title": filepath.get_file().get_basename(),
		"artist": "Неизвестен",
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

func _get_fallback_cover_texture():
	var active_cover_item_id = PlayerDataManager.get_active_item("Covers")
	var folder_name_map = {
		"covers_default": "default_covers"
	}
	var folder_name = folder_name_map.get(active_cover_item_id, active_cover_item_id.replace("covers_", ""))
	var rng = RandomNumberGenerator.new()
	rng.randomize()
	var random_index = rng.randi_range(1, 7)
	var fallback_cover_filename = "cover%d.png" % random_index
	var fallback_cover_path = "res://assets/shop/covers/%s/%s" % [folder_name, fallback_cover_filename]
	if FileAccess.file_exists(fallback_cover_path):
		var image = Image.new()
		var error = image.load(fallback_cover_path)
		if error == OK:
			var texture = ImageTexture.create_from_image(image)
			if texture:
				return texture
	else:
		var fallback_fallback_path = "res://assets/shop/covers/%s/cover1.png" % folder_name
		if fallback_cover_path != fallback_fallback_path and FileAccess.file_exists(fallback_fallback_path):
			var image_ff = Image.new()
			var error_ff = image_ff.load(fallback_fallback_path)
			if error_ff == OK:
				var texture_ff = ImageTexture.create_from_image(image_ff)
				if texture_ff:
					return texture_ff
	return null

func _update_recent_achievements():
	if achievements_list_vbox == null:
		return
	for child in achievements_list_vbox.get_children():
		achievements_list_vbox.remove_child(child)
		child.queue_free()
	var file = FileAccess.open(ACHIEVEMENTS_JSON_PATH, FileAccess.READ)
	if not file:
		if achievements_empty_label:
			achievements_empty_label.visible = true
		return
	var json_text = file.get_as_text()
	file.close()
	var parsed = JSON.parse_string(json_text)
	if not parsed or not parsed.has("achievements") or not (parsed.achievements is Array):
		if achievements_empty_label:
			achievements_empty_label.visible = true
		return
	var unlocked_list: Array[Dictionary] = []
	for item in parsed.achievements:
		if item is Dictionary and item.get("unlocked", false) and item.get("unlock_date", null) != null:
			unlocked_list.append(item)
	unlocked_list.sort_custom(Callable(self, "_sort_by_unlock_date_desc"))
	var to_display = unlocked_list.slice(0, min(5, unlocked_list.size()))
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
		card.title = str(ach.get("title", ""))
		card.description = str(ach.get("description", ""))
		card.progress_text = _get_progress_text(ach)
		card.is_unlocked = true
		card.unlock_date_text = str(ach.get("unlock_date", ""))
		var icon_tex = _load_achievement_icon(ach)
		if icon_tex:
			card.icon_texture = icon_tex
		achievements_list_vbox.add_child(card)

func _sort_by_unlock_date_desc(a: Dictionary, b: Dictionary) -> bool:
	var ka = _date_key(str(a.get("unlock_date", "")))
	var kb = _date_key(str(b.get("unlock_date", "")))
	if ka[0] != kb[0]:
		return ka[0] > kb[0]
	if ka[1] != kb[1]:
		return ka[1] > kb[1]
	if ka[2] != kb[2]:
		return ka[2] > kb[2]
	if ka[3] != kb[3]:
		return ka[3] > kb[3]
	return ka[4] > kb[4]

func _date_key(s: String) -> PackedInt32Array:
	var parts = s.split(",")
	if parts.size() != 2:
		return PackedInt32Array([0,0,0,0,0])
	var date_part = parts[0].strip_edges()
	var time_part = parts[1].strip_edges()
	var dparts = date_part.split(" ")
	if dparts.size() < 3:
		return PackedInt32Array([0,0,0,0,0])
	var day = int(dparts[0])
	var month_str = dparts[1]
	var year = int(dparts[2])
	var months = {
		"Янв": 1, "Фев": 2, "Мар": 3, "Апр": 4, "Мая": 5, "Июн": 6,
		"Июл": 7, "Авг": 8, "Сен": 9, "Окт": 10, "Ноя": 11, "Дек": 12
	}
	var month = int(months.get(month_str, 0))
	var tparts = time_part.split(":")
	var hour = tparts[0].to_int() if tparts.size() >= 1 else 0
	var minute = tparts[1].to_int() if tparts.size() >= 2 else 0
	return PackedInt32Array([year, month, day, hour, minute])

func _load_achievement_icon(ach: Dictionary) -> ImageTexture:
	var image_path = str(ach.get("image", ""))
	if image_path != "" and FileAccess.file_exists(image_path):
		var loaded_resource = ResourceLoader.load(image_path, "ImageTexture", ResourceLoader.CACHE_MODE_IGNORE)
		if loaded_resource and loaded_resource is ImageTexture:
			return loaded_resource
		var image = Image.new()
		var err = image.load(image_path)
		if err == OK:
			return ImageTexture.create_from_image(image)
	var category = str(ach.get("category", ""))
	var fallback_path = ""
	match category:
		"mastery": fallback_path = "res://assets/achievements/mastery.png"
		"drums": fallback_path = "res://assets/achievements/drums.png"
		"genres":  fallback_path = "res://assets/achievements/genres.png"
		"system": fallback_path = "res://assets/achievements/system.png"
		"shop": fallback_path = "res://assets/achievements/shop.png"
		"economy": fallback_path = "res://assets/achievements/economy.png"
		"daily": fallback_path = "res://assets/achievements/daily.png"
		"playtime": fallback_path = "res://assets/achievements/playtime.png"
		"events": fallback_path = "res://assets/achievements/events.png"
		"level": fallback_path = "res://assets/achievements/level.png"
		_: fallback_path = "res://assets/achievements/default.png"
	if FileAccess.file_exists(fallback_path):
		var loaded_default_resource = ResourceLoader.load(fallback_path, "ImageTexture", ResourceLoader.CACHE_MODE_IGNORE)
		if loaded_default_resource and loaded_default_resource is ImageTexture:
			return loaded_default_resource
		var image2 = Image.new()
		var err2 = image2.load(fallback_path)
		if err2 == OK:
			return ImageTexture.create_from_image(image2)
	var dummy_image = Image.create(1, 1, false, Image.FORMAT_RGBA8)
	dummy_image.set_pixel(0, 0, Color.WHITE)
	return ImageTexture.create_from_image(dummy_image)

func _get_progress_text(achievement: Dictionary) -> String:
	var current = achievement.get("current", 0)
	var total = achievement.get("total", 1)
	var unlocked = achievement.get("unlocked", false)
	var category = achievement.get("category", "")
	if category == "playtime" and achievement_manager:
		var formatted = achievement_manager.get_formatted_achievement_progress(int(achievement.get("id", -1)))
		if formatted:
			var display_total = str(int(total)) if total == floor(total) else "%0.2f" % [total]
			if unlocked:
				return "%s / %s" % [display_total, display_total]
			else:
				return "%s / %s" % [formatted.current, display_total]
	if category == "level":
		if unlocked:
			return "%d / %d" % [int(total), int(total)]
		else:
			return "%d / %d" % [int(current), int(total)]
	if typeof(current) == TYPE_BOOL:
		return "%d / %d" % [int(current), 1]
	var display_current = current
	if unlocked and typeof(current) != TYPE_FLOAT:
		display_current = min(current, total)
	if typeof(display_current) == TYPE_FLOAT:
		return "%d / %d" % [int(display_current), int(total)]
	return "%d / %d" % [int(display_current), int(total)]

func _update_accuracy_chart():
	if session_history_manager == null:
		printerr("ProfileScreen: SessionHistoryManager не установлен!")
		accuracy_chart_line.points = []
		for child in accuracy_chart_points.get_children():
			child.queue_free()
		if tooltip_label:
			tooltip_label.visible = false
		return

	var history = session_history_manager.get_history()
	if history.size() == 0:
		print("ProfileScreen: Нет истории сессий для отображения.")
		accuracy_chart_line.points = []
		for child in accuracy_chart_points.get_children():
			child.queue_free()
		if tooltip_label:
			tooltip_label.visible = false
		return
	
	if chart_background.size.x <= 0 or chart_background.size.y <= 0:
		call_deferred("_update_accuracy_chart")
		return

	for child in accuracy_chart_points.get_children():
		if child.has_signal("point_hovered"):
			child.point_hovered.disconnect(_on_point_hovered)
		if child.has_signal("point_unhovered"):
			child.point_unhovered.disconnect(_on_point_unhovered)
		child.queue_free()

	var start_index = max(0, history.size() - 20)
	var relevant_history = history.slice(start_index, history.size())

	var points = []
	for i in range(20):
		var session = null
		if i < relevant_history.size():
			session = relevant_history[i]
		else:
			session = {
				"accuracy": 0.0,
				"grade_color": {"r": 0.5, "g": 0.5, "b": 0.5, "a": 1.0} 
			}

		var accuracy = session.get("accuracy", 0.0)
		var bg_width = chart_background.size.x
		var bg_height = chart_background.size.y
		var x = 20 + i * ((bg_width - 40) / 19.0) if 19 > 0 else 20
		var y = bg_height - (accuracy / 100.0) * bg_height
		points.append(Vector2(x, y))
	accuracy_chart_line.points = points

	for i in range(20):
		var session = null
		var tooltip_text = "Н/Д - Н/Д (0.00%)"
		if i < relevant_history.size():
			session = relevant_history[i]
			var accuracy = session.get("accuracy", 0.0)
			var artist = session.get("artist", "Unknown")
			var title = session.get("title", "Unknown Track")
			tooltip_text = "%s - %s\n(%.2f%%)" % [artist, title, accuracy]
		else:
			var accuracy = session.get("accuracy", 0.0) if session else 0.0
			tooltip_text = "Н/Д - Н/Д\n(%.2f%%)" % accuracy

		var grade_color_dict = session.get("grade_color", {"r": 1.0, "g": 1.0, "b": 1.0, "a": 1.0}) if session else {"r": 0.5, "g": 0.5, "b": 0.5, "a": 1.0}
		var color = Color(grade_color_dict["r"], grade_color_dict["g"], grade_color_dict["b"], grade_color_dict["a"])

		var bg_width = chart_background.size.x
		var bg_height = chart_background.size.y
		var x = 20 + i * ((bg_width - 40) / 19.0) if 19 > 0 else 20
		var y = bg_height - (session.get("accuracy", 0.0) / 100.0) * bg_height if session else bg_height

		var point_position = Vector2(x, y)

		var point_control_script = load("res://scenes/profile/chart_point.gd")
		var point_control = point_control_script.new()

		point_control.set_tooltip_text(tooltip_text)

		point_control.point_color = color
		point_control.point_radius = 6.0
		point_control.border_width = 1.5
		point_control.border_color = Color.BLACK
		
		point_control._ready()

		point_control.position = point_position - point_control.size / 2
		point_control.name = "Point%d" % i

		point_control.point_hovered.connect(_on_point_hovered.bind(i))
		point_control.point_unhovered.connect(_on_point_unhovered)

		accuracy_chart_points.add_child(point_control)

func _on_point_hovered(global_pos: Vector2, tooltip_text: String, index: int):
	if tooltip_label:
		tooltip_label.text = tooltip_text
		tooltip_label.visible = true
		var local_pos = accuracy_chart_points.to_local(global_pos)
		tooltip_label.position = local_pos + Vector2(-tooltip_label.size.x / 2, -tooltip_label.size.y - 15) 

func _on_point_unhovered():
	if tooltip_label:
		tooltip_label.visible = false
		
func _on_chart_background_resized():
	_update_accuracy_chart()

func _execute_close_transition():
	MusicManager.play_cancel_sound()  

	if transitions:
		transitions.close_profile()
		
	if is_instance_valid(self):
		if PlayerDataManager.is_connected("total_play_time_changed", _on_total_play_time_changed):
			PlayerDataManager.total_play_time_changed.disconnect(_on_total_play_time_changed)
		queue_free()
