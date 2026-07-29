# scenes/song_select/song_select_tutorials.gd
class_name SongSelectTutorials
extends Node

const _SpotlightTutorialScene := preload("res://ui/spotlight_tutorial.tscn")

var screen: BaseScreen = null
var spotlight_tutorial: CanvasLayer = null
var _close_handler: Callable = Callable()


func initialize(host: BaseScreen) -> void:
	screen = host


func maybe_show_song_select(force: bool = false) -> void:
	if not SettingsManager or not SettingsManager.has_method("get_tutorial_song_select_done"):
		return
	if not force and SettingsManager.get_tutorial_song_select_done():
		return
	if not _ensure_spotlight():
		return
	_bind_close_handlers(on_song_select_closed)
	var steps: Array = [
		{
			"title_key": "TUTORIAL_SS_1_TITLE",
			"body_key": "TUTORIAL_SS_1_BODY",
			"target": screen.song_item_list_ref,
		},
		{
			"title_key": "TUTORIAL_SS_2_TITLE",
			"body_key": "TUTORIAL_SS_2_BODY",
			"target": screen._gen_settings_button,
		},
		{
			"title_key": "TUTORIAL_SS_MODS_TITLE",
			"body_key": "TUTORIAL_SS_MODS_BODY",
			"target": screen.modifiers_button,
		},
		{
			"title_key": "TUTORIAL_SS_3_TITLE",
			"body_key": "TUTORIAL_SS_3_BODY",
			"target": screen._generate_notes_button,
		},
		{
			"title_key": "TUTORIAL_SS_4_TITLE",
			"body_key": "TUTORIAL_SS_4_BODY",
			"target": screen._play_button,
		},
	]
	spotlight_tutorial.start(steps)


func on_song_select_closed() -> void:
	if SettingsManager and SettingsManager.has_method("set_tutorial_song_select_done"):
		SettingsManager.set_tutorial_song_select_done(true)


func debug_show_song_select() -> void:
	maybe_show_song_select(true)


func maybe_show_rhythm_dna_usage(target: Control, force: bool = false) -> void:
	if target == null or not is_instance_valid(target):
		return
	if spotlight_tutorial != null and spotlight_tutorial.visible:
		return
	if not SettingsManager or not SettingsManager.has_method("get_tutorial_rhythm_dna_usage_done"):
		return
	if not force and SettingsManager.get_tutorial_rhythm_dna_usage_done():
		return
	if not bool(SettingsManager.get_setting("show_rhythm_dna_button", false)):
		return
	if not _ensure_spotlight():
		return
	_bind_close_handlers(on_rhythm_dna_usage_closed)
	var steps: Array = [
		{
			"title_key": "TUTORIAL_DNA_USE_1_TITLE",
			"body_key": "TUTORIAL_DNA_USE_1_BODY",
			"target": target,
		},
	]
	spotlight_tutorial.start(steps)


func on_rhythm_dna_usage_closed() -> void:
	if SettingsManager and SettingsManager.has_method("set_tutorial_rhythm_dna_usage_done"):
		SettingsManager.set_tutorial_rhythm_dna_usage_done(true)


func debug_show_rhythm_dna_usage(target: Control) -> void:
	maybe_show_rhythm_dna_usage(target, true)


func _ensure_spotlight() -> bool:
	if spotlight_tutorial != null:
		return true
	spotlight_tutorial = _SpotlightTutorialScene.instantiate() as CanvasLayer
	if spotlight_tutorial == null:
		return false
	screen.add_child(spotlight_tutorial)
	return true


func _bind_close_handlers(callback: Callable) -> void:
	if spotlight_tutorial == null:
		return
	if _close_handler.is_valid():
		if spotlight_tutorial.finished.is_connected(_close_handler):
			spotlight_tutorial.finished.disconnect(_close_handler)
		if spotlight_tutorial.skipped.is_connected(_close_handler):
			spotlight_tutorial.skipped.disconnect(_close_handler)
	_close_handler = callback
	spotlight_tutorial.finished.connect(callback)
	spotlight_tutorial.skipped.connect(callback)
