# logic/utils/settings_dialog_utils.gd
extends RefCounted
class_name SettingsDialogUtils

const APP_THEME := preload("res://ui/theme/app_theme.tres")


static func apply_modal_style(dlg: Window) -> void:
	if dlg == null:
		return
	dlg.borderless = true
	dlg.unresizable = true
	dlg.exclusive = true
	dlg.initial_position = 2
	dlg.oversampling_override = 1.0
	dlg.title = ""
	if dlg.theme == null:
		dlg.theme = APP_THEME


static func apply_to_descendants(root: Node) -> void:
	if root == null:
		return
	if root is ConfirmationDialog or root is AcceptDialog:
		apply_modal_style(root as Window)
	for child in root.get_children():
		apply_to_descendants(child)
