# logic/locale_manager.gd
extends Node

signal locale_changed(new_locale: String)

const DEFAULT_LOCALE := "en"
const SUPPORTED_LOCALES: Array[String] = ["ru", "en"]

var _ready_applied := false


func _ready() -> void:
	CsvTranslationLoader.load_into_translation_server("res://translations/ui.csv")
	CsvTranslationLoader.load_into_translation_server("res://translations/shop_items.csv")
	CsvTranslationLoader.load_into_translation_server("res://translations/achievements.csv")
	CsvTranslationLoader.load_into_translation_server("res://translations/daily_quests.csv")
	CsvTranslationLoader.load_into_translation_server("res://translations/help.csv")
	apply_saved_locale(false)
	_ready_applied = true


func get_locale() -> String:
	return TranslationServer.get_locale()


func normalize_locale(locale: String) -> String:
	var code := locale.strip_edges().to_lower()
	if code.length() >= 2:
		code = code.substr(0, 2)
	if SUPPORTED_LOCALES.has(code):
		return code
	return DEFAULT_LOCALE


func apply_saved_locale(emit_change: bool = true) -> void:
	var saved := String(SettingsManager.get_setting("language", DEFAULT_LOCALE))
	set_locale(saved, emit_change)


func set_locale(locale: String, emit_change: bool = true, persist: bool = true) -> void:
	var code := normalize_locale(locale)
	if TranslationServer.get_locale() == code and _ready_applied and not emit_change:
		return
	TranslationServer.set_locale(code)
	SettingsManager.set_setting("language", code)
	if persist:
		SettingsManager.save_settings()
	if emit_change:
		_notify_locale_refresh()


func _notify_locale_refresh() -> void:
	locale_changed.emit(get_locale())
	var tree := get_tree()
	if tree == null:
		return
	for node in tree.get_nodes_in_group("locale_refresh"):
		if node.has_method("apply_locale"):
			node.apply_locale()
