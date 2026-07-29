# logic/utils/option_button_popup_utils.gd
extends RefCounted
class_name OptionButtonPopupUtils

const DEFAULT_POPUP_FONT_SIZE := 24

static func apply_popup_font_size(option_button: OptionButton, font_size: int = DEFAULT_POPUP_FONT_SIZE) -> void:
	if option_button == null or not is_instance_valid(option_button):
		return
	var popup: PopupMenu = option_button.get_popup()
	if popup == null:
		return
	popup.add_theme_font_size_override("font_size", font_size)
