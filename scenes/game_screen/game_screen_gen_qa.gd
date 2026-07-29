# scenes/game_screen/game_screen_gen_qa.gd
class_name GameScreenGenQa
extends Node

const _GenerationQualityReports = preload("res://logic/data/generation_quality_reports.gd")
const _GEN_QA_DIALOG_SCENE := preload("res://scenes/game_screen/generation_quality_report_dialog.tscn")

var game_screen = null
var dialog: Control = null
var soft_pause_active := false
var saved_music_pos := 0.0


func initialize(gs) -> void:
	game_screen = gs


func blocks_input() -> bool:
	return dialog != null and is_instance_valid(dialog) and dialog.visible


func open_report() -> void:
	if dialog and is_instance_valid(dialog):
		return
	var song_path := str(game_screen.selected_song_data.get("path", "")).strip_edges()
	var ctx := _GenerationQualityReports.build_context(
		song_path,
		game_screen._get_mark_song_time(),
		game_screen.bpm,
		game_screen.current_instrument,
		game_screen.current_generation_mode,
		game_screen.lanes,
		game_screen.run_modifiers,
		str(game_screen.selected_song_data.get("title", "")),
		str(game_screen.selected_song_data.get("artist", ""))
	)
	if not game_screen.pauser.is_paused:
		_begin_soft_pause()
	var dlg := _GEN_QA_DIALOG_SCENE.instantiate() as Control
	dialog = dlg
	game_screen.add_child(dlg)
	if dlg.has_method("setup"):
		dlg.setup(ctx)
	if dlg.has_signal("saved"):
		dlg.saved.connect(_on_saved)
	if dlg.has_signal("cancelled"):
		dlg.cancelled.connect(_on_closed)
	if dlg.has_method("apply_locale"):
		dlg.apply_locale()


func close_range_end() -> void:
	if dialog and is_instance_valid(dialog):
		return
	var song_path := str(game_screen.selected_song_data.get("path", "")).strip_edges()
	var end_time: float = game_screen._get_mark_song_time()
	var updated := _GenerationQualityReports.close_open_range(
		song_path,
		game_screen.current_generation_mode,
		game_screen.current_instrument,
		game_screen.lanes,
		end_time,
		game_screen.bpm
	)
	_show_toast(
		game_screen.tr("GENQA_RANGE_END_SAVED") if not updated.is_empty() else game_screen.tr("GENQA_NO_OPEN_MARK")
	)


func _begin_soft_pause() -> void:
	if soft_pause_active:
		return
	if game_screen.has_method("is_resume_rewind_active") and game_screen.is_resume_rewind_active():
		return
	soft_pause_active = true
	saved_music_pos = game_screen.get_song_time()
	if game_screen.game_timer and not game_screen.game_timer.is_stopped():
		game_screen.game_timer.stop()
	if MusicManager.is_music_playing():
		MusicManager.stop_game_music()
	game_screen.input_enabled = false


func _end_soft_pause() -> void:
	if not soft_pause_active:
		return
	soft_pause_active = false
	var song_path := str(game_screen.selected_song_data.get("path", "")).strip_edges()
	if song_path != "":
		if MusicManager.has_method("play_game_music_at_position"):
			MusicManager.play_game_music_at_position(song_path, saved_music_pos)
		else:
			MusicManager.play_game_music(song_path)
			game_screen.call_deferred("_restore_gen_qa_music_position")
	if (
		game_screen.game_timer
		and game_screen.game_timer.is_stopped()
		and not game_screen.game_finished
		and not game_screen.countdown_active
	):
		game_screen.game_timer.start()
	game_screen.input_enabled = true


func restore_music_position() -> void:
	MusicManager.set_music_position(saved_music_pos)


func _on_saved(_entry: Dictionary) -> void:
	_on_closed()
	_show_toast(game_screen.tr("GENQA_SAVED"))


func _on_closed() -> void:
	dialog = null
	if soft_pause_active:
		_end_soft_pause()


func _show_toast(message: String) -> void:
	var engine = game_screen.game_engine
	if engine and engine.has_method("get_status_dock"):
		var dock: StatusDock = engine.get_status_dock()
		if dock:
			dock.show_transient("gen_qa", message, "success", 4.0)
