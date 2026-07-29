# logic/ui/generation_bulk_queue_actions.gd
class_name GenerationBulkQueueActions
extends RefCounted

const _GenerationBulkQueue = preload("res://logic/domain/generation/generation_bulk_queue.gd")
const _Overlay = preload("res://logic/ui/app_overlay_helpers.gd")
const _UserPresets = preload("res://logic/domain/modifiers/user_presets.gd")
const _StatusToast = preload("res://logic/ui/status_toast.gd")
const CHOICE_OVERLAY_SCENE := preload("res://ui/overlays/app_choice_overlay.tscn")


static func _tr(key: String) -> String:
	return TranslationServer.translate(key)


static func generation_service() -> GenerationService:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return null
	var ge: Node = tree.root.get_node_or_null("GameEngine")
	if ge and ge.has_method("get_background_service"):
		return ge.get_background_service() as GenerationService
	return null


static func read_generation_settings() -> Dictionary:
	var axes := GenerationGoalDifficulty.resolve_ready_axes()
	return {
		"instrument": str(SettingsManager.get_setting("last_generation_instrument", "drums")),
		"mode": str(SettingsManager.get_setting("last_generation_mode", "basic")),
		"lanes": int(SettingsManager.get_setting("last_generation_lanes", 4)),
		"ready_axes": axes,
		"scope": 1 if GenerationGoalDifficulty.ready_axes_is_mass(axes) else 0,
	}


static func bulk_force_regen_enabled() -> bool:
	return bool(SettingsManager.get_setting("generation_bulk_force_regen", true))


static func confirm_regeneration_enabled() -> bool:
	return bool(SettingsManager.get_setting("generation_confirm_before_rerun", true))


static func scope_is_mass(scope: int) -> bool:
	# Legacy int arg from older call sites; prefer ready_axes_is_mass.
	if scope != 0:
		return true
	return GenerationGoalDifficulty.ready_axes_is_mass(GenerationGoalDifficulty.resolve_ready_axes())


static func ready_axes_is_mass() -> bool:
	return GenerationGoalDifficulty.ready_axes_is_mass(GenerationGoalDifficulty.resolve_ready_axes())


static func should_block_mass_generation(scope: int = 0) -> bool:
	var mass := ready_axes_is_mass() if scope == 0 else scope_is_mass(scope)
	return mass and NotesUtils.get_active_generation_preset_slot() > 0


static func _confirm(host: Node, confirm: AppConfirmOverlay, title: String, message: String, ok_text: String) -> bool:
	if confirm == null:
		return true
	return await _Overlay.ask(confirm, message, "warning", title, ok_text, _tr("BTN_CANCEL"))


static func _ensure_choice_overlay(host: Node) -> AppChoiceOverlay:
	if host == null:
		return null
	var existing := host.get_node_or_null("ChoiceOverlay") as AppChoiceOverlay
	if existing:
		return existing
	var overlay := CHOICE_OVERLAY_SCENE.instantiate() as AppChoiceOverlay
	if overlay:
		overlay.name = "ChoiceOverlay"
		host.add_child(overlay)
	return overlay


static func _prompt_dirty_preset(host: Node) -> String:
	var overlay := _ensure_choice_overlay(host)
	if overlay == null:
		return "cancel"
	return await _Overlay.choose(
		overlay,
		_tr("GEN_PRESET_DIRTY_GEN_TITLE"),
		"warning",
		"",
		_tr("GEN_PRESET_DIRTY_GEN_SAVE"),
		_tr("BTN_CANCEL"),
		_tr("GEN_PRESET_DIRTY_GEN_TEMP"),
	)


static func _toast(host: Node, toast_id: String, text: String) -> void:
	if host:
		_StatusToast.show_from_node(host, toast_id, text, "queue", 4.0)


static func enqueue_bpm_for_library(host: Node, confirm: AppConfirmOverlay) -> void:
	var service := generation_service()
	if service == null:
		return
	var force_all := bulk_force_regen_enabled()
	var paths := _GenerationBulkQueue.collect_bpm_paths(force_all)
	if paths.is_empty():
		_toast(host, "gen_bulk_empty", _tr("GEN_BULK_QUEUE_BPM_NONE"))
		return
	if force_all and confirm_regeneration_enabled():
		var msg := _tr("GEN_BULK_QUEUE_BPM_CONFIRM") % paths.size()
		if not await _confirm(host, confirm, _tr("GEN_BULK_QUEUE_MENU"), msg, _tr("GEN_BULK_QUEUE_CONFIRM")):
			return
	var result := _GenerationBulkQueue.enqueue_bpm_for_library(service, force_all)
	_toast(host, "gen_bulk_bpm", _tr("GEN_BULK_QUEUE_BPM_DONE_FMT") % [
		result.get("queued", 0),
		result.get("skipped", 0),
		result.get("total", 0),
	])


static func enqueue_notes_for_library(host: Node, confirm: AppConfirmOverlay) -> void:
	var service := generation_service()
	if service == null:
		return
	var settings := read_generation_settings()
	if should_block_mass_generation():
		await _Overlay.ask(
			confirm,
			_tr("GEN_PRESET_MASS_BLOCKED"),
			"warning",
			"",
			_tr("BTN_OK"),
		)
		return
	var force_all := bulk_force_regen_enabled()
	var instrument := str(settings.get("instrument", "drums"))
	var mode := str(settings.get("mode", "basic"))
	var lanes := int(settings.get("lanes", 4))
	var generation_chart_tag := ""
	if mode == "custom" and NotesUtils.get_active_generation_preset_slot() > 0:
		if _UserPresets.is_active_generation_preset_dirty():
			var dirty_choice := await _prompt_dirty_preset(host)
			if dirty_choice == "cancel":
				return
			if dirty_choice == "confirm":
				_UserPresets.save_active_generation_preset_body()
				generation_chart_tag = NotesUtils.chart_tag_for_preset_slot(NotesUtils.get_active_generation_preset_slot())
		else:
			generation_chart_tag = NotesUtils.chart_tag_for_preset_slot(NotesUtils.get_active_generation_preset_slot())
	if force_all and confirm_regeneration_enabled() and ready_axes_is_mass():
		var song_count := SongLibrary.get_songs_list().size()
		var msg := _tr("GEN_BULK_QUEUE_NOTES_CONFIRM") % song_count
		if not await _confirm(host, confirm, _tr("GEN_BULK_QUEUE_MENU"), msg, _tr("GEN_BULK_QUEUE_CONFIRM")):
			return
	var result := _GenerationBulkQueue.enqueue_notes_for_library(
		service,
		instrument,
		mode,
		lanes,
		0,
		force_all,
		generation_chart_tag,
	)
	if int(result.get("total_jobs", 0)) <= 0 and int(result.get("skipped_no_bpm", 0)) <= 0:
		_toast(host, "gen_bulk_empty", _tr("GEN_BULK_QUEUE_NOTES_NONE"))
		return
	_toast(host, "gen_bulk_notes", _tr("GEN_BULK_QUEUE_NOTES_DONE_FMT") % [
		result.get("queued", 0),
		result.get("skipped", 0),
		result.get("total_jobs", 0),
		result.get("skipped_no_bpm", 0),
	])
