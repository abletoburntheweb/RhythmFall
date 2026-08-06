# scenes/song_select/song_details_manager.gd
class_name SongDetailsManager
extends Node

const GradeDisplay = preload("res://logic/ui/grade_display.gd")
const _SS = preload("res://logic/domain/library/song_select_strings.gd")
const _SongPreviewSegment = preload("res://logic/domain/library/song_preview_segment.gd")
const _UiMotionEffects = preload("res://logic/ui/ui_motion_effects.gd")
const _RhythmDnaCoverLoader = preload("res://scenes/song_select/rhythm_dna/lib/rhythm_dna_cover_loader.gd")
const _StatusToast = preload("res://logic/ui/status_toast.gd")
const _DNA_CAPTION_ACTIVE := Color(0.55, 0.78, 0.98, 0.92)
const _DNA_CAPTION_MUTED := Color(0.42, 0.45, 0.52, 0.72)
const _DNA_ICON_MUTED := Color(0.45, 0.48, 0.55, 0.75)

var title_label: Label = null
var artist_label: Label = null
var living_insight_label: Label = null
var year_label: Label = null
var bpm_label: Label = null
var duration_label: Label = null
var primary_genre_label: Label = null
var play_count_label: Label = null
var best_grade_label: Label = null
var rhythm_rating_label: Label = null
var chart_difficulty_label: Label = null
var chart_difficulty_meter: ChartDifficultyMeter = null
var chart_difficulty_value_label: Label = null
var chart_difficulty_mod_label: Label = null
var chart_difficulty_effective_row: HBoxContainer = null
var chart_difficulty_effective_label: Label = null
var chart_difficulty_effective_meter: ChartDifficultyMeter = null
var chart_difficulty_effective_value_label: Label = null
var chart_density_label: Label = null
var rhythm_dna_button: Button = null
var rhythm_dna_icon: TextureRect = null
var rhythm_dna_caption: Label = null
var _percussion_low := false
var _rhythm_dna_has_report := false
var chart_id_label: Label = null
var cover_texture_rect: TextureRect = null
var play_button: Button = null

var preview_player: AudioStreamPlayer = null

var _current_preview_file_path: String = ""
var _preview_request_id: int = 0
var _preview_snippet_plan: Dictionary = {}
var _preview_fade_tween: Tween = null
static var _pending_play_glow: Dictionary = {}
var _cover_loader: ThreadedTextureLoader = null
var _cover_loader_connected: bool = false
var _cover_request_id: int = 0
var _cover_loading_path: String = ""
var _pending_cover_path: String = ""
var _real_cover_applied_for_request_id: int = -1
var _fallback_applies_to_request_id: int = -1
var _sidecar_cover_thread: Thread = null
var _sidecar_cover_request_id: int = 0
var _embedded_cover_thread: Thread = null
var _embedded_cover_request_id: int = 0
static var _sidecar_cover_cache: Dictionary = {}
static var _embedded_cover_cache: Dictionary = {}

signal rhythm_dna_requested(song_path: String)
signal rhythm_dna_unavailable(song_path: String)
signal rhythm_dna_usage_tutorial_requested(target: Control)

var current_instrument: String = "drums"
var current_generation_mode: String = "basic"
var current_lanes: int = 4  
var _active_run_modifiers: Array[String] = []

var generation_status_label: Label = null
var is_generating_notes: bool = false
var _last_song_data: Dictionary = {}
var _chart_id_copy_timer: Timer = null
var _chart_id_tooltip_saved: String = ""

func set_generation_status_label(status_lbl: Label):
	generation_status_label = status_lbl


static func _normalize_song_path(p: String) -> String:
	return String(p).replace("\\", "/").trim_suffix("/")


static func _play_glow_key(song_path: String, instrument: String, mode: String, lanes: int) -> String:
	var path := _normalize_song_path(song_path)
	if path.is_empty():
		return ""
	return "%s|%s|%s|%d" % [path, instrument, mode, lanes]


static func mark_play_glow_pending(song_path: String, instrument: String, mode: String, lanes: int) -> void:
	var key := _play_glow_key(song_path, instrument, mode, lanes)
	if key.is_empty():
		return
	_pending_play_glow[key] = true


func _chart_lookup_key() -> String:
	var intent := ""
	if SettingsManager:
		intent = str(SettingsManager.get_setting("last_generation_intent", ""))
	return GenerationIntents.chart_lookup_key(current_generation_mode, intent)


func _consume_play_glow_pending() -> bool:
	var key := _play_glow_key(_current_preview_file_path, current_instrument, _chart_lookup_key(), current_lanes)
	if key.is_empty() or not _pending_play_glow.get(key, false):
		return false
	_pending_play_glow.erase(key)
	return true


func setup_ui_nodes(title_lbl: Label, artist_lbl: Label, year_lbl: Label, bpm_lbl: Label, duration_lbl: Label, genre_lbl: Label, play_count_lbl: Label, best_grade_lbl: Label, chart_difficulty_lbl: Label, chart_difficulty_meter_node: ChartDifficultyMeter, chart_difficulty_value_lbl: Label, chart_difficulty_mod_lbl: Label, chart_density_lbl: Label, cover_tex_rect: TextureRect, play_btn: Button, chart_id_lbl: Label = null, rhythm_rating_lbl: Label = null, rhythm_dna_btn: Button = null, chart_difficulty_effective_row_node: HBoxContainer = null, chart_difficulty_effective_lbl: Label = null, chart_difficulty_effective_meter_node: ChartDifficultyMeter = null, chart_difficulty_effective_value_lbl: Label = null, living_insight_lbl: Label = null):
	title_label = title_lbl
	artist_label = artist_lbl
	living_insight_label = living_insight_lbl
	year_label = year_lbl
	bpm_label = bpm_lbl
	duration_label = duration_lbl
	primary_genre_label = genre_lbl
	play_count_label = play_count_lbl
	best_grade_label = best_grade_lbl
	rhythm_rating_label = rhythm_rating_lbl
	chart_difficulty_label = chart_difficulty_lbl
	chart_difficulty_meter = chart_difficulty_meter_node
	chart_difficulty_value_label = chart_difficulty_value_lbl
	chart_difficulty_mod_label = chart_difficulty_mod_lbl
	chart_difficulty_effective_row = chart_difficulty_effective_row_node
	chart_difficulty_effective_label = chart_difficulty_effective_lbl
	chart_difficulty_effective_meter = chart_difficulty_effective_meter_node
	chart_difficulty_effective_value_label = chart_difficulty_effective_value_lbl
	chart_density_label = chart_density_lbl
	if chart_density_label:
		chart_density_label.mouse_filter = Control.MOUSE_FILTER_STOP
		chart_density_label.autowrap_mode = TextServer.AUTOWRAP_OFF
		chart_density_label.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		chart_density_label.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		chart_density_label.add_theme_font_size_override("font_size", 16)
	rhythm_dna_button = rhythm_dna_btn
	if rhythm_dna_button:
		rhythm_dna_caption = rhythm_dna_button.get_parent().get_node_or_null("RhythmDnaCaption") as Label
		rhythm_dna_icon = rhythm_dna_button.get_parent().get_node_or_null("RhythmDnaIcon") as TextureRect
		_configure_rhythm_dna_controls()
	chart_id_label = chart_id_lbl
	cover_texture_rect = cover_tex_rect
	play_button = play_btn
	if chart_difficulty_mod_label:
		chart_difficulty_mod_label.mouse_filter = Control.MOUSE_FILTER_STOP
	_setup_chart_id_copy()


func _configure_rhythm_dna_controls() -> void:
	if rhythm_dna_button == null:
		return
	var row := rhythm_dna_button.get_parent() as BoxContainer
	if row:
		row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.alignment = BoxContainer.ALIGNMENT_BEGIN
	rhythm_dna_button.visible = false
	rhythm_dna_button.focus_mode = Control.FOCUS_NONE
	rhythm_dna_button.disabled = true
	if rhythm_dna_icon == null and rhythm_dna_caption != null and row:
		rhythm_dna_icon = UiIconHelper.make_texture_rect(
			UiIconHelper.load_tinted_icon("info.svg", UiIconHelper.ACCENT),
			14
		)
		rhythm_dna_icon.name = "RhythmDnaIcon"
		rhythm_dna_icon.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		rhythm_dna_icon.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		row.add_child(rhythm_dna_icon)
		row.move_child(rhythm_dna_icon, rhythm_dna_caption.get_index())
	if rhythm_dna_icon:
		rhythm_dna_icon.texture = UiIconHelper.load_tinted_icon("info.svg", UiIconHelper.ACCENT)
		rhythm_dna_icon.custom_minimum_size = Vector2(14, 14)
		rhythm_dna_icon.visible = false
		rhythm_dna_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if rhythm_dna_caption:
		rhythm_dna_caption.visible = false
		rhythm_dna_caption.mouse_filter = Control.MOUSE_FILTER_STOP
		rhythm_dna_caption.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		rhythm_dna_caption.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		rhythm_dna_caption.vertical_alignment = VERTICAL_ALIGNMENT_TOP
		rhythm_dna_caption.add_theme_color_override("font_color", Color(0.55, 0.78, 0.98, 0.92))
		rhythm_dna_caption.add_theme_font_size_override("font_size", 16)
		rhythm_dna_caption.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		if not rhythm_dna_caption.gui_input.is_connected(_on_rhythm_dna_caption_gui_input):
			rhythm_dna_caption.gui_input.connect(_on_rhythm_dna_caption_gui_input)
	_remove_legacy_percussion_badge()


func _remove_legacy_percussion_badge() -> void:
	if rhythm_dna_button == null:
		return
	var row := rhythm_dna_button.get_parent() as BoxContainer
	if row == null:
		return
	var legacy := row.get_node_or_null("PercussionBadge") as Label
	if legacy:
		legacy.queue_free()


func _update_percussion_hint(song_path: String, has_notes: bool) -> void:
	_percussion_low = false
	if song_path == "" or not has_notes:
		_sync_rhythm_dna_icon()
		return
	if not NotesUtils.has_full_rhythm_dna(
		song_path, current_instrument, _chart_lookup_key(), current_lanes
	):
		_sync_rhythm_dna_icon()
		return
	var dna := NotesUtils.load_rhythm_dna(
		song_path, current_instrument, _chart_lookup_key(), current_lanes
	)
	var genes: Dictionary = dna.get("genes", {}) if dna.get("genes", {}) is Dictionary else {}
	var rhythm: Dictionary = genes.get("rhythm", {}) if genes.get("rhythm", {}) is Dictionary else {}
	_percussion_low = String(rhythm.get("percussion_viable", "")).strip_edges().to_lower() == "low"
	_sync_rhythm_dna_icon()


func _sync_rhythm_dna_icon() -> void:
	if rhythm_dna_icon == null or not rhythm_dna_icon.visible:
		return
	if _percussion_low and _rhythm_dna_has_report:
		rhythm_dna_icon.texture = UiIconHelper.load_tinted_icon(
			"triangle-alert.svg", Color(0.95, 0.78, 0.35, 0.95)
		)
	elif _rhythm_dna_has_report:
		rhythm_dna_icon.texture = UiIconHelper.load_tinted_icon("info.svg", UiIconHelper.ACCENT)
	else:
		rhythm_dna_icon.texture = UiIconHelper.load_tinted_icon("info.svg", _DNA_ICON_MUTED)


func _set_rhythm_dna_controls_visible(show: bool, enabled: bool, tooltip: String = "") -> void:
	_rhythm_dna_has_report = enabled
	if rhythm_dna_icon:
		rhythm_dna_icon.visible = show
		rhythm_dna_icon.modulate = Color(1, 1, 1, 1 if enabled else 0.55)
		rhythm_dna_icon.tooltip_text = tooltip
		rhythm_dna_icon.mouse_filter = Control.MOUSE_FILTER_STOP if show and enabled else Control.MOUSE_FILTER_IGNORE
	if rhythm_dna_caption:
		rhythm_dna_caption.visible = show
		rhythm_dna_caption.modulate = Color(1, 1, 1, 1)
		rhythm_dna_caption.add_theme_color_override(
			"font_color", _DNA_CAPTION_ACTIVE if enabled else _DNA_CAPTION_MUTED
		)
		rhythm_dna_caption.tooltip_text = tooltip
		rhythm_dna_caption.mouse_default_cursor_shape = (
			Control.CURSOR_POINTING_HAND if enabled else Control.CURSOR_ARROW
		)
	if rhythm_dna_button:
		rhythm_dna_button.visible = false
		rhythm_dna_button.disabled = true
	_sync_rhythm_dna_icon()


func _on_rhythm_dna_caption_gui_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton):
		return
	var mb := event as InputEventMouseButton
	if mb.button_index != MOUSE_BUTTON_LEFT or not mb.pressed:
		return
	_on_rhythm_dna_button_pressed()


func _setup_chart_id_copy() -> void:
	if chart_id_label == null:
		return
	chart_id_label.mouse_filter = Control.MOUSE_FILTER_STOP
	if not chart_id_label.gui_input.is_connected(_on_chart_id_gui_input):
		chart_id_label.gui_input.connect(_on_chart_id_gui_input)


func _on_chart_id_gui_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton):
		return
	var mb := event as InputEventMouseButton
	if mb.button_index != MOUSE_BUTTON_LEFT or not mb.pressed:
		return
	if _last_song_data.is_empty():
		return
	var song_path := String(_last_song_data.get("path", "")).strip_edges()
	if song_path == "":
		return
	var chart_id := String(NotesUtils.chart_id_from_song_path(song_path))
	if chart_id == "":
		return
	DisplayServer.clipboard_set(chart_id)
	_flash_chart_id_copied()
	_StatusToast.show_from_node(self, "chart_id_copied", tr("SONG_CHART_ID_COPIED"), "success", 2.0)


func _flash_chart_id_copied() -> void:
	if chart_id_label == null:
		return
	_chart_id_tooltip_saved = chart_id_label.tooltip_text
	chart_id_label.tooltip_text = tr("SONG_CHART_ID_COPIED")
	if _chart_id_copy_timer == null:
		_chart_id_copy_timer = Timer.new()
		_chart_id_copy_timer.one_shot = true
		_chart_id_copy_timer.wait_time = 1.6
		_chart_id_copy_timer.timeout.connect(_restore_chart_id_tooltip)
		add_child(_chart_id_copy_timer)
	if _chart_id_copy_timer.time_left > 0.0:
		_chart_id_copy_timer.stop()
	_chart_id_copy_timer.start()


func _restore_chart_id_tooltip() -> void:
	if chart_id_label == null:
		return
	chart_id_label.tooltip_text = _chart_id_tooltip_saved if _chart_id_tooltip_saved != "" else _SS._translate("SONG_CHART_ID_TOOLTIP")


func setup_audio_player():
	preview_player = AudioStreamPlayer.new()
	preview_player.name = "PreviewPlayer"
	preview_player.finished.connect(_on_preview_finished)
	add_child(preview_player)

func _load_audio_stream_for_path(p: String) -> AudioStream:
	return FilePathUtils.load_audio_stream_for_path(p)
func apply_locale() -> void:
	if not _last_song_data.is_empty():
		update_details(_last_song_data)
	else:
		_apply_empty_details_labels()
		_update_play_button_state()
		_update_generation_status()


func _apply_empty_details_labels() -> void:
	if title_label:
		title_label.text = _SS._translate("META_FIELD_TITLE")
	if artist_label:
		artist_label.text = _SS._translate("META_FIELD_ARTIST")
	if year_label:
		year_label.text = _SS._translate("META_FIELD_YEAR")
	if bpm_label:
		bpm_label.text = _SS._translate("META_FIELD_BPM")
	if duration_label:
		duration_label.text = _SS._translate("META_FIELD_DURATION")
	if primary_genre_label:
		primary_genre_label.text = _SS._translate("META_FIELD_GENRE")
	if play_count_label:
		play_count_label.text = _SS._translate("SONG_PLAY_COUNT") % 0
	if best_grade_label:
		best_grade_label.text = _SS._translate("SONG_BEST_GRADE_NONE")
		best_grade_label.add_theme_color_override("font_color", Color.WHITE)
		best_grade_label.modulate = Color(0.72, 0.8, 0.92, 1.0)
	_set_living_insight("")
	_hide_chart_difficulty_display()
	_update_chart_id_display("")
	if cover_texture_rect:
		cover_texture_rect.texture = null

func _set_living_insight(text: String) -> void:
	if living_insight_label == null:
		return
	var line := text.strip_edges()
	living_insight_label.text = line
	living_insight_label.visible = line != ""


func _update_living_insight(song_path: String) -> void:
	const _DiaryVoice = preload("res://logic/domain/profile/diary_voice.gd")
	_set_living_insight(_DiaryVoice.living_library_line(song_path))

func update_details(song_data: Dictionary):
	var song_path := String(song_data.get("path", "")).strip_edges()
	if song_path == "":
		_last_song_data = {}
		_apply_empty_details_labels()
		_update_play_button_state()
		_update_generation_status()
		return

	_last_song_data = song_data.duplicate(true)

	if title_label:
		title_label.text = _SS._translate("SONG_FIELD_TITLE") % _SS.display_metadata_value(song_data.get("title", ""))
	if artist_label:
		artist_label.text = _SS._translate("SONG_FIELD_ARTIST") % _SS.display_metadata_value(song_data.get("artist", ""))
	_update_living_insight(song_path)
	if year_label:
		year_label.text = _SS._translate("SONG_FIELD_YEAR") % _SS.display_metadata_value(song_data.get("year", ""))
	if bpm_label:
		bpm_label.text = _SS._translate("SONG_FIELD_BPM") % _SS.display_metadata_value(song_data.get("bpm", ""))
	_update_duration_if_unknown(song_data)
	if title_label or artist_label or year_label:
		_apply_tags_if_needed(song_data)
	
	if primary_genre_label:
		var genre = String(song_data.get("primary_genre", "")).strip_edges()
		if genre == "" or genre == "unknown":
			genre = _SS._translate("VALUE_NA")
		primary_genre_label.text = _SS._translate("SONG_FIELD_GENRE") % genre
	if play_count_label:
		var count = 0
		if TrackStatsManager and TrackStatsManager.has_method("get_completion_count"):
			count = TrackStatsManager.get_completion_count(song_path)
		play_count_label.text = _SS._translate("SONG_PLAY_COUNT") % count
	if best_grade_label:
		var best_grade_text = _SS._translate("SONG_BEST_GRADE_NONE")
		var color_to_apply = Color.WHITE
		if song_path != "":
			var grade_str := GradeDisplay.best_grade_for_track(song_path)
			if grade_str == "":
				var svc = ResultsHistoryService.new()
				var top = svc.get_top_result_for_song(song_path)
				if top and top is Dictionary and not top.is_empty():
					grade_str = str(top.get("grade", ""))
			if grade_str != "" and not _SS.is_missing_metadata_value(grade_str):
				best_grade_text = _SS._translate("SONG_BEST_GRADE") % grade_str
				if grade_str == "SS":
					color_to_apply = GradeDisplay.color_for_track_best(song_path)
				else:
					color_to_apply = GradeDisplay.grade_color(grade_str)
		best_grade_label.text = best_grade_text
		best_grade_label.add_theme_color_override("font_color", Color.WHITE)
		if color_to_apply == Color.WHITE:
			best_grade_label.modulate = Color(0.72, 0.8, 0.92, 1.0)
		else:
			best_grade_label.modulate = color_to_apply

	if rhythm_rating_label:
		var best_rr := 0
		if ProfileMilestonesManager and song_path != "":
			best_rr = ProfileMilestonesManager.get_best_rr_for_song(song_path)
		const _VoiceLibrary = preload("res://logic/ui/voice_library.gd")
		if best_rr > 0:
			rhythm_rating_label.text = _VoiceLibrary.best_rr_value(best_rr, song_path)
			rhythm_rating_label.visible = true
		else:
			rhythm_rating_label.text = _SS._translate("SONG_BEST_RR_NONE")
			rhythm_rating_label.visible = false

	_update_chart_difficulty_display(song_path)
	_update_chart_id_display(song_path)

	var cover_texture = song_data.get("cover", null)
	if cover_texture_rect:
		_apply_cover_texture(song_data)

	_update_play_button_state()
	_update_generation_status() 

func _get_fallback_cover_texture():
	var path := _get_fallback_cover_path()
	if path != "" and _cover_loader:
		var cached := _cover_loader.get_cached(path)
		if cached:
			return cached
	return null

func _get_fallback_cover_path() -> String:
	return TrackPlaceholderCover.path_random()

func set_current_instrument(instrument: String):
	current_instrument = instrument
	_update_play_button_state()
	_refresh_chart_difficulty_if_needed()
	
func set_current_generation_mode(mode: String):
	current_generation_mode = mode
	_update_play_button_state()
	_refresh_chart_difficulty_if_needed()

func set_current_lanes(lanes: int):
	current_lanes = lanes
	_update_play_button_state()
	_refresh_chart_difficulty_if_needed()


func set_active_run_modifiers(modifiers: Array) -> void:
	_active_run_modifiers = RunModifiers.sanitize(modifiers)
	_refresh_chart_difficulty_if_needed()

func _refresh_chart_difficulty_if_needed() -> void:
	if _last_song_data.is_empty():
		return
	_update_chart_difficulty_display(String(_last_song_data.get("path", "")))


func _apply_empty_chart_difficulty_labels() -> void:
	var muted := ChartDifficultyAnalyzer.rating_color(0)
	if chart_difficulty_label:
		chart_difficulty_label.visible = true
		chart_difficulty_label.text = _SS._translate("SONG_DIFFICULTY_NONE")
		chart_difficulty_label.add_theme_color_override("font_color", Color.WHITE)
		chart_difficulty_label.modulate = muted
	if chart_difficulty_meter:
		chart_difficulty_meter.visible = false
	if chart_difficulty_value_label:
		chart_difficulty_value_label.visible = false
	if chart_difficulty_mod_label:
		chart_difficulty_mod_label.visible = false
	if chart_difficulty_effective_row:
		chart_difficulty_effective_row.visible = false
	if chart_difficulty_effective_label:
		chart_difficulty_effective_label.visible = false
	if chart_difficulty_effective_meter:
		chart_difficulty_effective_meter.visible = false
	if chart_difficulty_effective_value_label:
		chart_difficulty_effective_value_label.visible = false
	if chart_density_label:
		chart_density_label.visible = true
		chart_density_label.add_theme_color_override("font_color", Color.WHITE)
		chart_density_label.modulate = muted
		chart_density_label.text = _SS._translate("SONG_DENSITY_NONE")
		chart_density_label.tooltip_text = ""


func _should_show_chart_id() -> bool:
	return SettingsManager != null and bool(SettingsManager.get_setting("show_chart_id", false))


func _update_chart_id_display(song_path: String) -> void:
	if chart_id_label == null:
		return
	var show := _should_show_chart_id() and song_path != ""
	chart_id_label.visible = show
	if not show:
		return
	var chart_id := String(NotesUtils.chart_id_from_song_path(song_path))
	chart_id_label.text = _SS._translate("SONG_CHART_ID") % chart_id
	_chart_id_tooltip_saved = _SS._translate("SONG_CHART_ID_TOOLTIP")
	chart_id_label.tooltip_text = _chart_id_tooltip_saved
	chart_id_label.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND


func refresh_chart_id_visibility() -> void:
	if _last_song_data.is_empty():
		_update_chart_id_display("")
	else:
		_update_chart_id_display(String(_last_song_data.get("path", "")))


func _get_chart_rating_snapshot(song_path: String) -> Dictionary:
	var lookup := _chart_lookup_key()
	var base := ChartDifficultyAnalyzer.ensure_persisted(
		song_path, current_instrument, lookup, current_lanes
	)
	return ChartDifficultyAnalyzer.build_rating_snapshot(
		base,
		_active_run_modifiers,
		RunModifiers.sync_params_from_modifiers(
			_active_run_modifiers,
			SettingsManager.get_run_modifier_params()
		)
	)


func _update_chart_difficulty_display(song_path: String) -> void:
	if chart_density_label == null and chart_difficulty_meter == null and chart_difficulty_label == null:
		return
	if song_path == "" or not NotesUtils.notes_exist(
		song_path,
		current_instrument,
		_chart_lookup_key(),
		current_lanes,
		_play_chart_tag(song_path),
	):
		_hide_chart_difficulty_display()
		return
	var snapshot := _get_chart_rating_snapshot(song_path)
	var base_decimal := float(snapshot.get("base_decimal", 0.0))
	if base_decimal <= 0.0:
		_hide_chart_difficulty_display()
		return
	var effective_stats: Dictionary = snapshot.get("effective_stats", {})
	var modified := bool(snapshot.get("has_mods", false))
	var base_color := ChartDifficultyAnalyzer.rating_color_for_decimal(base_decimal)
	var base_display := minf(base_decimal, float(ChartDifficultyAnalyzer.MAX_RATING))
	if chart_difficulty_label:
		chart_difficulty_label.visible = true
		chart_difficulty_label.text = _SS._translate("SONG_DIFFICULTY_BASE_PREFIX")
		chart_difficulty_label.add_theme_color_override("font_color", Color.WHITE)
		chart_difficulty_label.modulate = base_color
	if chart_difficulty_meter:
		chart_difficulty_meter.set_decimal_rating(base_display, base_color)
		chart_difficulty_meter.tooltip_text = ChartDifficultyAnalyzer.format_difficulty_tooltip(
			snapshot.get("base_stats", {})
		)
	if chart_difficulty_value_label:
		chart_difficulty_value_label.visible = true
		chart_difficulty_value_label.text = ChartDifficultyAnalyzer.format_decimal_rating(base_display, true)
		chart_difficulty_value_label.add_theme_color_override("font_color", Color.WHITE)
		chart_difficulty_value_label.modulate = base_color
	var effective_decimal := float(snapshot.get("effective_decimal", base_decimal))
	if chart_difficulty_mod_label:
		if modified:
			var pct_text := ChartDifficultyAnalyzer.format_modifier_influence_percent(
				base_decimal,
				effective_decimal
			)
			chart_difficulty_mod_label.visible = true
			chart_difficulty_mod_label.text = _SS._translate("SONG_DIFFICULTY_MOD_INFLUENCE_FMT") % pct_text
			chart_difficulty_mod_label.tooltip_text = ChartDifficultyAnalyzer.format_effective_tooltip(snapshot)
		else:
			chart_difficulty_mod_label.visible = false
			chart_difficulty_mod_label.tooltip_text = ""
	if chart_difficulty_effective_row or chart_difficulty_effective_label or chart_difficulty_effective_meter or chart_difficulty_effective_value_label:
		if modified:
			var effective_color := ChartDifficultyAnalyzer.rating_color_for_decimal(effective_decimal)
			var effective_tooltip := ChartDifficultyAnalyzer.format_effective_tooltip(snapshot)
			if chart_difficulty_effective_row:
				chart_difficulty_effective_row.visible = true
			if chart_difficulty_effective_label:
				chart_difficulty_effective_label.visible = true
				chart_difficulty_effective_label.text = _SS._translate("SONG_DIFFICULTY_MOD_PREFIX")
				chart_difficulty_effective_label.add_theme_color_override("font_color", Color.WHITE)
				chart_difficulty_effective_label.modulate = effective_color
				chart_difficulty_effective_label.tooltip_text = effective_tooltip
			if chart_difficulty_effective_meter:
				chart_difficulty_effective_meter.visible = true
				chart_difficulty_effective_meter.set_decimal_rating(effective_decimal, effective_color)
				chart_difficulty_effective_meter.tooltip_text = effective_tooltip
			if chart_difficulty_effective_value_label:
				chart_difficulty_effective_value_label.visible = true
				chart_difficulty_effective_value_label.text = ChartDifficultyAnalyzer.format_decimal_rating(
					effective_decimal, true
				)
				chart_difficulty_effective_value_label.add_theme_color_override("font_color", Color.WHITE)
				chart_difficulty_effective_value_label.modulate = effective_color
				chart_difficulty_effective_value_label.tooltip_text = effective_tooltip
		else:
			if chart_difficulty_effective_row:
				chart_difficulty_effective_row.visible = false
			if chart_difficulty_effective_label:
				chart_difficulty_effective_label.visible = false
				chart_difficulty_effective_label.tooltip_text = ""
			if chart_difficulty_effective_meter:
				chart_difficulty_effective_meter.visible = false
				chart_difficulty_effective_meter.tooltip_text = ""
			if chart_difficulty_effective_value_label:
				chart_difficulty_effective_value_label.visible = false
				chart_difficulty_effective_value_label.tooltip_text = ""
	if chart_density_label:
		chart_density_label.visible = true
		chart_density_label.add_theme_color_override("font_color", Color.WHITE)
		chart_density_label.modulate = ChartDifficultyAnalyzer.rating_color_for_decimal(
			float(snapshot.get("effective_decimal", base_decimal))
		)
		chart_density_label.text = ChartDifficultyAnalyzer.format_density_text(effective_stats, modified)
		chart_density_label.tooltip_text = ChartDifficultyAnalyzer.format_density_tooltip(effective_stats)
	_update_rhythm_dna_button(song_path)


func _hide_chart_difficulty_display() -> void:
	if chart_difficulty_label:
		chart_difficulty_label.visible = false
	if chart_difficulty_meter:
		chart_difficulty_meter.visible = false
	if chart_difficulty_value_label:
		chart_difficulty_value_label.visible = false
	if chart_difficulty_mod_label:
		chart_difficulty_mod_label.visible = false
		chart_difficulty_mod_label.tooltip_text = ""
	if chart_difficulty_effective_row:
		chart_difficulty_effective_row.visible = false
	if chart_difficulty_effective_label:
		chart_difficulty_effective_label.visible = false
		chart_difficulty_effective_label.tooltip_text = ""
	if chart_difficulty_effective_meter:
		chart_difficulty_effective_meter.visible = false
		chart_difficulty_effective_meter.tooltip_text = ""
	if chart_difficulty_effective_value_label:
		chart_difficulty_effective_value_label.visible = false
		chart_difficulty_effective_value_label.tooltip_text = ""
	if chart_density_label:
		chart_density_label.visible = false
		chart_density_label.tooltip_text = ""
	_update_rhythm_dna_button(String(_last_song_data.get("path", "")))


func _should_show_rhythm_dna_button() -> bool:
	return SettingsManager != null and bool(SettingsManager.get_setting("show_rhythm_dna_button", false))


func refresh_rhythm_dna_button_visibility() -> void:
	if _last_song_data.is_empty():
		_update_rhythm_dna_button("")
	else:
		_update_rhythm_dna_button(String(_last_song_data.get("path", "")))


func _update_rhythm_dna_button(song_path: String) -> void:
	if rhythm_dna_button == null:
		return
	if not _should_show_rhythm_dna_button():
		_set_rhythm_dna_controls_visible(false, false)
		_update_percussion_hint("", false)
		return
	var has_notes := song_path != "" and NotesUtils.notes_exist(
		song_path,
		current_instrument,
		_chart_lookup_key(),
		current_lanes,
		_play_chart_tag(song_path),
	)
	if not has_notes:
		_set_rhythm_dna_controls_visible(false, false)
		_update_percussion_hint(song_path, false)
		return
	var has_full_dna := NotesUtils.has_full_rhythm_dna(
		song_path, current_instrument, _chart_lookup_key(), current_lanes
	)
	_update_percussion_hint(song_path, true)
	var tooltip := (
		_SS._translate("DNA_TOOLTIP_OPEN") if has_full_dna else _SS._translate("DNA_TOOLTIP_UNAVAILABLE")
	)
	if _percussion_low and has_full_dna:
		tooltip = "%s\n%s" % [tooltip, _SS._translate("DNA_BADGE_WEAK_PERCUSSION_TIP")]
	_set_rhythm_dna_controls_visible(true, has_full_dna, tooltip)
	if rhythm_dna_caption:
		rhythm_dna_caption.text = _SS._translate("BTN_RHYTHM_DNA")
	if has_full_dna and rhythm_dna_caption:
		if SettingsManager and SettingsManager.has_method("get_tutorial_rhythm_dna_usage_done"):
			if not SettingsManager.get_tutorial_rhythm_dna_usage_done():
				rhythm_dna_usage_tutorial_requested.emit(rhythm_dna_caption)


func _on_rhythm_dna_button_pressed() -> void:
	var song_path := String(_last_song_data.get("path", _current_preview_file_path)).strip_edges()
	if song_path == "":
		return
	if not _rhythm_dna_has_report:
		rhythm_dna_unavailable.emit(song_path)
		return
	rhythm_dna_requested.emit(song_path)

func _play_chart_tag(song_path: String) -> String:
	return NotesUtils.resolve_play_chart_tag(
		song_path,
		current_instrument,
		current_generation_mode,
		current_lanes,
	)


func _has_notes_for_instrument(song_path: String, instrument: String) -> bool:
	if song_path == "":
		return false
	return NotesUtils.notes_exist(
		song_path,
		instrument,
		_chart_lookup_key(),
		current_lanes,
		_play_chart_tag(song_path),
	)

func _update_play_button_state():
	if play_button:
		var ready := _current_preview_file_path != "" and _has_notes_for_instrument(_current_preview_file_path, current_instrument)
		if ready:
			play_button.disabled = false
			play_button.text = _SS._translate("SONG_PLAY")
			if _consume_play_glow_pending():
				_UiMotionEffects.pulse_play_ready(play_button)
		else:
			play_button.disabled = true
			play_button.text = _SS._translate("SONG_PLAY_NEED_NOTES")

func set_generation_status(status: String, is_error: bool = false):
	if generation_status_label:
		generation_status_label.text = status
		if is_error:
			generation_status_label.modulate = Color.RED
		else:
			generation_status_label.modulate = Color.YELLOW if _SS.is_generating_status(status) else Color.GREEN

func _update_generation_status():
	if _current_preview_file_path != "":
		if _has_notes_for_instrument(_current_preview_file_path, current_instrument):
			const _VoiceLibrary = preload("res://logic/ui/voice_library.gd")
			set_generation_status(_VoiceLibrary.chart_ready(_current_preview_file_path), false)
		else:
			set_generation_status(_SS._translate("SONG_STATUS_NO_NOTES"), false)
	else:
		set_generation_status("", false)

func _on_preview_finished() -> void:
	if _current_preview_file_path == "":
		return
	if SettingsManager.get_song_preview_mode() == "full":
		play_song_preview(_current_preview_file_path)
	elif not _preview_snippet_plan.is_empty() and preview_player and preview_player.stream:
		_start_preview_playback(preview_player.stream, _current_preview_file_path)


func play_song_preview(filepath: String):
	var started_ms := Time.get_ticks_msec()
	if filepath == "":
		printerr("SongDetailsManager.gd: Путь к файлу пуст, воспроизведение невозможно.")
		return

	var file_extension = filepath.get_extension().to_lower()
	if file_extension != "mp3" and file_extension != "wav":
		printerr("SongDetailsManager.gd: Неподдерживаемый формат файла для воспроизведения: " + file_extension)
		return

	if preview_player.playing:
		preview_player.stop()
	_cancel_preview_scheduling()
	if filepath != _current_preview_file_path:
		_preview_snippet_plan = {}

	_preview_request_id += 1
	var request_id := _preview_request_id
	_current_preview_file_path = filepath
	if MusicManager and MusicManager.has_method("load_audio_stream_async"):
		MusicManager.load_audio_stream_async(filepath, "", func(audio_stream): _on_preview_stream_loaded(filepath, request_id, audio_stream))
	else:
		printerr("SongDetailsManager.gd: MusicManager не поддерживает асинхронную загрузку preview.")
	print("[Perf] SongDetails preview request: %d ms" % [Time.get_ticks_msec() - started_ms])

func _on_preview_stream_loaded(filepath: String, request_id: int, audio_stream: AudioStream) -> void:
	if request_id != _preview_request_id or filepath != _current_preview_file_path:
		return
	if audio_stream:
		_start_preview_playback(audio_stream, filepath)
	else:
		printerr("SongDetailsManager.gd: Не удалось загрузить аудио поток из: " + filepath)


func _start_preview_playback(audio_stream: AudioStream, filepath: String) -> void:
	if preview_player == null:
		return
	preview_player.stream = audio_stream
	var target_db := linear_to_db(SettingsManager.get_preview_volume() / 100.0)
	_cancel_preview_scheduling()

	if SettingsManager.get_song_preview_mode() == "full":
		_preview_snippet_plan = {}
		preview_player.volume_db = target_db
		preview_player.play()
		return

	if _preview_snippet_plan.is_empty() or filepath != _current_preview_file_path:
		_preview_snippet_plan = _SongPreviewSegment.compute_plan(audio_stream, filepath)
	if String(_preview_snippet_plan.get("mode", "")) == "full":
		preview_player.volume_db = target_db
		preview_player.play()
		return

	_play_snippet_segment(target_db)


func _play_snippet_segment(target_db: float) -> void:
	if preview_player == null:
		return
	_cancel_preview_scheduling()
	var start_sec := float(_preview_snippet_plan.get("start_sec", 0.0))
	var play_sec := float(_preview_snippet_plan.get("play_sec", _SongPreviewSegment.SNIPPET_SEC))
	preview_player.volume_db = -80.0
	preview_player.play(start_sec)
	_fade_preview_volume(-80.0, target_db, _SongPreviewSegment.FADE_IN_SEC)
	var fade_out_at := maxf(0.05, play_sec - _SongPreviewSegment.FADE_OUT_SEC)
	var tree := get_tree()
	if tree:
		tree.create_timer(fade_out_at).timeout.connect(func() -> void:
			if not is_instance_valid(self) or _current_preview_file_path == "":
				return
			if preview_player == null or not preview_player.playing:
				return
			_fade_preview_volume(preview_player.volume_db, -80.0, _SongPreviewSegment.FADE_OUT_SEC, true)
		, CONNECT_ONE_SHOT)


func _fade_preview_volume(from_db: float, to_db: float, duration_sec: float, stop_after: bool = false) -> void:
	if preview_player == null:
		return
	if _preview_fade_tween and is_instance_valid(_preview_fade_tween):
		_preview_fade_tween.kill()
	var from_linear := db_to_linear(from_db)
	var to_linear := db_to_linear(to_db)
	_preview_fade_tween = create_tween()
	_preview_fade_tween.set_trans(Tween.TRANS_SINE)
	_preview_fade_tween.set_ease(Tween.EASE_IN_OUT)
	_preview_fade_tween.tween_method(_apply_preview_volume_linear, from_linear, to_linear, duration_sec)
	if stop_after:
		_preview_fade_tween.tween_callback(_stop_preview_player_after_fade)


func _apply_preview_volume_linear(linear_vol: float) -> void:
	if is_instance_valid(preview_player):
		preview_player.volume_db = linear_to_db(maxf(linear_vol, 0.00001))


func _stop_preview_player_after_fade() -> void:
	var should_loop_snippet := (
		_current_preview_file_path != ""
		and SettingsManager.get_song_preview_mode() != "full"
		and String(_preview_snippet_plan.get("mode", "")) == "snippet"
		and preview_player != null
		and preview_player.stream != null
	)
	if is_instance_valid(preview_player):
		preview_player.stop()
	if should_loop_snippet:
		var target_db := linear_to_db(SettingsManager.get_preview_volume() / 100.0)
		_play_snippet_segment(target_db)


func _cancel_preview_scheduling() -> void:
	if _preview_fade_tween and is_instance_valid(_preview_fade_tween):
		_preview_fade_tween.kill()
		_preview_fade_tween = null


func stop_preview():
	_current_preview_file_path = ""
	_preview_snippet_plan = {}
	_cancel_preview_scheduling()
	if preview_player and preview_player.playing:
		preview_player.stop()

func _update_duration_if_unknown(song_data: Dictionary) -> void:
	if not duration_label:
		return
	var dur = song_data.get("duration", "00:00")
	duration_label.text = _SS._translate("SONG_FIELD_DURATION") % dur
	if dur != "00:00":
		return
	var path = song_data.get("path", "")
	if path == "":
		return
	if SongLibrary and SongLibrary.has_method("request_duration_update"):
		SongLibrary.request_duration_update(path)

var _tag_sync_in_progress := false

func _apply_tags_if_needed(song_data: Dictionary) -> void:
	var path_for_tags = song_data.get("path", "")
	if path_for_tags == "":
		return
	if _tag_sync_in_progress:
		return
	var current_meta = SongLibrary.get_metadata_for_song(path_for_tags)
	var stem: String = String(path_for_tags).get_file().get_basename()
	var need_title := true
	var need_artist := true
	var need_year := true
	var need_bpm := true
	if not current_meta.is_empty():
		var cur_title = str(current_meta.get("title", ""))
		var cur_artist = str(current_meta.get("artist", ""))
		var cur_year = str(current_meta.get("year", ""))
		var cur_bpm = str(current_meta.get("bpm", ""))
		need_title = _SS.is_default_title(cur_title, stem)
		need_artist = _SS.is_default_artist(cur_artist)
		need_year = _SS.is_missing_metadata_value(cur_year)
		need_bpm = _SS.is_missing_metadata_value(cur_bpm)
	var global_path = ProjectSettings.globalize_path(path_for_tags)
	if not FileAccess.file_exists(global_path):
		return
	if need_title or need_artist or need_year or need_bpm:
		if SongLibrary and SongLibrary.has_method("request_id3_update"):
			SongLibrary.request_id3_update(path_for_tags)

func _apply_cover_texture(song_data: Dictionary) -> void:
	var cover_texture = song_data.get("cover", null)
	if cover_texture and cover_texture is ImageTexture:
		cover_texture_rect.texture = cover_texture
		_cover_loading_path = ""
		_pending_cover_path = ""
		return
	var path_for_cover = String(song_data.get("path", "")).replace("\\", "/").strip_edges()
	# Same path already loading — keep the in-flight request (do not bump id).
	if path_for_cover != "" and path_for_cover == _cover_loading_path and _cover_threads_busy():
		return
	# Shared loader used by feed/list rows — cache hit after feed open.
	if path_for_cover != "":
		var shared: Texture2D = _RhythmDnaCoverLoader.load_cover(path_for_cover)
		if shared:
			cover_texture_rect.texture = shared
			_cover_loading_path = ""
			_pending_cover_path = ""
			_cover_request_id += 1
			_real_cover_applied_for_request_id = _cover_request_id
			return
	_cover_request_id += 1
	var request_id := _cover_request_id
	_real_cover_applied_for_request_id = -1
	_cover_loading_path = path_for_cover
	_pending_cover_path = ""
	if path_for_cover != "":
		var global_path = _RhythmDnaCoverLoader._readable_audio_path(path_for_cover)
		if global_path == "":
			global_path = ProjectSettings.globalize_path(path_for_cover)
		if _embedded_cover_cache.has(global_path):
			cover_texture_rect.texture = _embedded_cover_cache[global_path]
			_real_cover_applied_for_request_id = request_id
			_cover_loading_path = ""
			return
		if _sidecar_cover_cache.has(global_path):
			cover_texture_rect.texture = _sidecar_cover_cache[global_path]
			_real_cover_applied_for_request_id = request_id
			_cover_loading_path = ""
			return
		if _cover_threads_busy():
			_pending_cover_path = path_for_cover
			_request_fallback_cover_texture(request_id)
			return
		_start_embedded_cover_load(global_path, request_id)
		_start_sidecar_cover_load(global_path, request_id)
	_request_fallback_cover_texture(request_id)


func _cover_threads_busy() -> bool:
	return (_embedded_cover_thread != null and _embedded_cover_thread.is_alive()) \
			or (_sidecar_cover_thread != null and _sidecar_cover_thread.is_alive())


func _flush_pending_cover_load() -> void:
	if _pending_cover_path == "" or _cover_threads_busy():
		return
	if _last_song_data.is_empty():
		_pending_cover_path = ""
		return
	var pending := _pending_cover_path
	_pending_cover_path = ""
	if String(_last_song_data.get("path", "")).replace("\\", "/").strip_edges() != pending:
		return
	_apply_cover_texture(_last_song_data)


func _start_embedded_cover_load(global_audio_path: String, request_id: int) -> void:
	if _embedded_cover_thread and _embedded_cover_thread.is_alive():
		return
	if not FileAccess.file_exists(global_audio_path):
		return
	_embedded_cover_request_id = request_id
	_embedded_cover_thread = Thread.new()
	var err := _embedded_cover_thread.start(Callable(self, "_embedded_cover_worker").bind(global_audio_path))
	if err != OK:
		_embedded_cover_thread = null
		return
	call_deferred("_poll_embedded_cover_thread")

func _embedded_cover_worker(global_audio_path: String) -> Dictionary:
	var buf := _read_id3_tag_blob(global_audio_path)
	if buf.is_empty():
		var fa := FileAccess.open(global_audio_path, FileAccess.READ)
		if not fa:
			return {}
		buf = fa.get_buffer(fa.get_length())
		fa.close()
	var mm := MusicMetadata.new()
	mm.set_from_data(buf)
	if mm.cover and mm.cover is ImageTexture:
		var img := mm.cover.get_image()
		if img:
			return {"audio_path": global_audio_path, "image": img}
	return {}

func _read_id3_tag_blob(global_audio_path: String) -> PackedByteArray:
	var fa := FileAccess.open(global_audio_path, FileAccess.READ)
	if not fa:
		return PackedByteArray()
	var header := fa.get_buffer(10)
	if header.size() < 10:
		fa.close()
		return PackedByteArray()
	var is_id3 := header.slice(0, 3).get_string_from_ascii() == "ID3"
	if not is_id3:
		fa.close()
		return PackedByteArray()
	var size_bytes := header.slice(6, 10)
	var size := 0
	for b in size_bytes:
		size = (size << 7) | int(b & 0x7f)
	var tag := fa.get_buffer(size)
	fa.close()
	var data := PackedByteArray()
	data.append_array(header)
	data.append_array(tag)
	return data


func _poll_embedded_cover_thread() -> void:
	if not _embedded_cover_thread:
		return
	if _embedded_cover_thread.is_alive():
		await get_tree().process_frame
		call_deferred("_poll_embedded_cover_thread")
		return
	var result = _embedded_cover_thread.wait_to_finish()
	_embedded_cover_thread = null
	if result is Dictionary and not result.is_empty() and _embedded_cover_request_id == _cover_request_id:
		var image = result.get("image", null)
		var audio_path := str(result.get("audio_path", ""))
		if image and image is Image:
			var tex := ImageTexture.create_from_image(image)
			_embedded_cover_cache[audio_path] = tex
			if cover_texture_rect:
				cover_texture_rect.texture = tex
				_real_cover_applied_for_request_id = _cover_request_id
			_cover_loading_path = ""
	call_deferred("_flush_pending_cover_load")

func _start_sidecar_cover_load(global_audio_path: String, request_id: int) -> void:
	if _sidecar_cover_thread and _sidecar_cover_thread.is_alive():
		return
	var candidates := _get_sidecar_cover_candidates(global_audio_path)
	if candidates.is_empty():
		return
	_sidecar_cover_request_id = request_id
	_sidecar_cover_thread = Thread.new()
	var err := _sidecar_cover_thread.start(Callable(self, "_sidecar_cover_worker").bind(global_audio_path, candidates))
	if err != OK:
		_sidecar_cover_thread = null
		return
	call_deferred("_poll_sidecar_cover_thread")

func _get_sidecar_cover_candidates(global_audio_path: String) -> Array:
	var base_dir = global_audio_path.get_base_dir()
	var stem = global_audio_path.get_file().get_basename()
	var candidates := [
		base_dir + "/" + stem + ".jpg",
		base_dir + "/" + stem + ".png",
		base_dir + "/cover.jpg",
		base_dir + "/cover.png"
	]
	var existing := []
	for img_path in candidates:
		if FileAccess.file_exists(img_path):
			existing.append(img_path)
	return existing

func _sidecar_cover_worker(global_audio_path: String, candidates: Array) -> Dictionary:
	for img_path in candidates:
		var image := Image.new()
		var err := image.load(String(img_path))
		if err == OK:
			return {"audio_path": global_audio_path, "image": image}
	return {}

func _poll_sidecar_cover_thread() -> void:
	if not _sidecar_cover_thread:
		return
	if _sidecar_cover_thread.is_alive():
		await get_tree().process_frame
		call_deferred("_poll_sidecar_cover_thread")
		return
	var result = _sidecar_cover_thread.wait_to_finish()
	_sidecar_cover_thread = null
	if result is Dictionary and not result.is_empty() and _sidecar_cover_request_id == _cover_request_id:
		var image = result.get("image", null)
		var audio_path := str(result.get("audio_path", ""))
		if image and image is Image:
			var tex := ImageTexture.create_from_image(image)
			_sidecar_cover_cache[audio_path] = tex
			if cover_texture_rect:
				cover_texture_rect.texture = tex
				_real_cover_applied_for_request_id = _cover_request_id
			_cover_loading_path = ""
	call_deferred("_flush_pending_cover_load")
func _request_fallback_cover_texture(request_id: int) -> void:
	_fallback_applies_to_request_id = request_id
	var fallback_path := _get_fallback_cover_path()
	if fallback_path == "":
		return
	if _cover_loader == null:
		_cover_loader = ThreadedTextureLoader.get_instance()
	if _cover_loader == null:
		return
	if not _cover_loader_connected:
		_cover_loader.loaded.connect(_on_fallback_cover_loaded)
		_cover_loader_connected = true
	var cached := _cover_loader.get_cached(fallback_path)
	if cached:
		if request_id != _cover_request_id:
			return
		if _real_cover_applied_for_request_id == request_id:
			return
		cover_texture_rect.texture = cached
		return
	_cover_loader.request(fallback_path)

func _on_fallback_cover_loaded(path: String, tex: Texture2D) -> void:
	if not cover_texture_rect or tex == null:
		return
	if _fallback_applies_to_request_id != _cover_request_id:
		return
	if _real_cover_applied_for_request_id == _cover_request_id:
		return
	cover_texture_rect.texture = tex
  
