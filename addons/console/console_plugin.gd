@tool
extends EditorPlugin

const CONSOLE_THEME : String = &"console/theme"


func _enter_tree():
	var settings_dirty := false

	if not ProjectSettings.has_setting(CONSOLE_THEME):
		ProjectSettings.set_setting(CONSOLE_THEME, "")
		ProjectSettings.add_property_info({
			"name": CONSOLE_THEME,
			"type": TYPE_STRING,
			"hint": PROPERTY_HINT_FILE,
			"hint_string": "*.tres",
		})
		ProjectSettings.set_initial_value(CONSOLE_THEME, "")
		ProjectSettings.set_as_basic(CONSOLE_THEME, true)
		settings_dirty = true

	# Already listed in project.godot — do not re-add (avoids "Добавить автозагрузку" + Ctrl+S prompt).
	if not ProjectSettings.has_setting("autoload/Console"):
		add_autoload_singleton("Console", "res://addons/console/console.gd")
		settings_dirty = true
	if not ProjectSettings.has_setting("autoload/DebugCommands"):
		add_autoload_singleton("DebugCommands", "res://addons/console/debug_commands.gd")
		settings_dirty = true

	if settings_dirty:
		ProjectSettings.save()

	print("Console plugin activated.")


func _exit_tree():
	pass
