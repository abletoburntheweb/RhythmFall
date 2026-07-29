# logic/utils/ui_modifier_sounds.gd
extends RefCounted
class_name UiModifierSounds


static func play_select() -> void:
	if MusicManager and MusicManager.has_method("play_modifier_select_sound"):
		MusicManager.play_modifier_select_sound()


static func play_deselect() -> void:
	if MusicManager and MusicManager.has_method("play_modifier_deselect_sound"):
		MusicManager.play_modifier_deselect_sound()


static func play_toggle(on: bool) -> void:
	if on:
		play_select()
	else:
		play_deselect()
