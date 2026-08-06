# logic/ui/app_overlay_helpers.gd
class_name AppOverlayHelpers
extends RefCounted


static func ask(
	confirm: AppConfirmOverlay,
	message: String,
	variant: String = "warning",
	title: String = "",
	confirm_text: String = "",
	cancel_text: String = "",
) -> bool:
	if confirm == null:
		return false
	confirm.show_confirm(title, message, variant, confirm_text, cancel_text)
	return await confirm.finished


static func choose(
	choice: AppChoiceOverlay,
	message: String,
	variant: String = "warning",
	title: String = "",
	confirm_text: String = "",
	cancel_text: String = "",
	extra_text: String = "",
) -> String:
	if choice == null:
		return "cancel"
	choice.show_choice(title, message, variant, confirm_text, cancel_text, extra_text)
	return await choice.finished


static func ask_songs_folder_change(
	overlay: AppSongsFolderChangeOverlay,
	message: String,
) -> Dictionary:
	if overlay == null:
		return {"action": "cancel", "delete_notes": false}
	overlay.show_change_folder(message)
	var result: Array = await overlay.finished
	return {"action": String(result[0]), "delete_notes": bool(result[1])}


static func notify(notice: AppNoticeOverlay, message: String) -> void:
	if notice == null:
		return
	notice.show_message(message)


static func notify_with_actions(
	notice: AppNoticeOverlay,
	title: String,
	message: String,
	primary_text: String = "",
	secondary_text: String = "",
) -> String:
	if notice == null:
		return "primary"
	notice.show_with_actions(title, message, primary_text, secondary_text)
	return await notice.action_chosen
