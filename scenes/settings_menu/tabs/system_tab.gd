# scenes/settings_menu/tabs/system_tab.gd
extends Control

signal settings_changed

const _OptionButtonPopupUtils = preload("res://logic/ui/option_button_popup_utils.gd")
const _Overlay = preload("res://logic/ui/app_overlay_helpers.gd")
const _SettingsSectionUi = preload("res://logic/ui/settings_section_ui.gd")
const _CV := "ScrollWrap/CenterWrap/ContentVBox"
const _LANG := "%s/LanguagePanel/LanguagePanelMargin/LanguageRows" % _CV
const _UPDATES := "%s/UpdatesPanel/UpdatesPanelMargin/UpdatesRows" % _CV

@onready var language_label: Label = get_node("%s/LanguageRow/LanguageLabel" % _LANG)
@onready var language_option: OptionButton = get_node("%s/LanguageRow/LanguageOption" % _LANG)
@onready var version_info_label: Label = get_node("%s/VersionRow/VersionInfoLabel" % _UPDATES)
@onready var check_updates_button: Button = get_node("%s/VersionRow/CheckUpdatesButton" % _UPDATES)
@onready var check_updates_on_startup_checkbox: CheckBox = get_node("%s/CheckUpdatesOnStartupCheckBox" % _UPDATES)
@onready var whats_new_button: Button = %WhatsNewButton
@onready var about_button: Button = %AboutButton
@onready var language_header: Label = get_node("%s/LanguageHeader" % _LANG)
@onready var language_hint: Label = get_node("%s/LanguageHint" % _LANG)
@onready var updates_header: Label = get_node("%s/UpdatesHeader" % _UPDATES)
@onready var updates_hint: Label = get_node("%s/UpdatesHint" % _UPDATES)
@onready var _notice_overlay: AppNoticeOverlay = %NoticeOverlay
@onready var _confirm_overlay: AppConfirmOverlay = %ConfirmOverlay

var _pending_update_url: String = ""
var _whats_new_overlay: WhatsNewOverlay = null
var _about_overlay: AboutProjectOverlay = null


func _ready() -> void:
	add_to_group("locale_refresh")
	call_deferred("_apply_initial_settings")
	call_deferred("_setup_language_option_popup_font")
	call_deferred("apply_locale")
	call_deferred("_apply_settings_checkbox_styles")
	if UpdateChecker and not UpdateChecker.check_completed.is_connected(_on_update_check_completed):
		UpdateChecker.check_completed.connect(_on_update_check_completed)


func apply_locale() -> void:
	if language_header:
		language_header.text = tr("MISC_LANGUAGE")
	if language_hint:
		language_hint.text = tr("SETTINGS_LANGUAGE_SECTION_HINT")
	if updates_header:
		updates_header.text = tr("MISC_UPDATES_SECTION")
	if updates_hint:
		updates_hint.text = tr("SETTINGS_UPDATES_SECTION_HINT")
	if language_label:
		language_label.text = tr("MISC_LANGUAGE")
	if version_info_label:
		version_info_label.text = tr("UPDATE_VERSION_LABEL") % AppVersion.get_display_version()
	if check_updates_button:
		check_updates_button.text = tr("UPDATE_CHECK_BUTTON") if not UpdateChecker or not UpdateChecker.is_busy() else tr("UPDATE_CHECKING")
	if check_updates_on_startup_checkbox:
		check_updates_on_startup_checkbox.text = tr("UPDATE_CHECK_ON_STARTUP")
	if whats_new_button:
		whats_new_button.text = tr("WHATS_NEW_BUTTON")
	if about_button:
		about_button.text = tr("ABOUT_BUTTON")
	if _whats_new_overlay and is_instance_valid(_whats_new_overlay):
		_whats_new_overlay.apply_locale()
	if _about_overlay and is_instance_valid(_about_overlay):
		_about_overlay.apply_locale()
	_apply_update_dialog_locale()
	_apply_language_option_items()
	_sync_language_option_selection()
	_apply_tooltips()


func _ensure_whats_new_overlay() -> WhatsNewOverlay:
	if _whats_new_overlay and is_instance_valid(_whats_new_overlay):
		return _whats_new_overlay
	# Load on first open so Settings boot does not pull MarkdownLabel / overlay tree.
	var packed: PackedScene = load("res://ui/overlays/whats_new_overlay.tscn") as PackedScene
	if packed == null:
		return null
	_whats_new_overlay = packed.instantiate() as WhatsNewOverlay
	add_child(_whats_new_overlay)
	return _whats_new_overlay


func _setup_language_option_popup_font() -> void:
	_OptionButtonPopupUtils.apply_popup_font_size(language_option, 24)


func _apply_settings_checkbox_styles() -> void:
	_SettingsSectionUi.apply_settings_checkbox(
		check_updates_on_startup_checkbox, 22, false, Color(0.66, 0.58, 0.86, 1.0)
	)


func _apply_tooltips() -> void:
	if language_label:
		language_label.tooltip_text = tr("MISC_LANGUAGE_TOOLTIP")
	if language_option:
		language_option.tooltip_text = tr("MISC_LANGUAGE_TOOLTIP")
	if check_updates_button:
		check_updates_button.tooltip_text = tr("UPDATE_CHECK_BUTTON_TOOLTIP")
	if check_updates_on_startup_checkbox:
		check_updates_on_startup_checkbox.tooltip_text = tr("MISC_CHECK_UPDATES_ON_STARTUP_TOOLTIP")
	if whats_new_button:
		whats_new_button.tooltip_text = tr("WHATS_NEW_BUTTON_TOOLTIP")
	if about_button:
		about_button.tooltip_text = tr("ABOUT_BUTTON_TOOLTIP")


func _ensure_about_overlay() -> AboutProjectOverlay:
	if _about_overlay and is_instance_valid(_about_overlay):
		return _about_overlay
	var packed: PackedScene = load("res://ui/overlays/about_project_overlay.tscn") as PackedScene
	if packed == null:
		return null
	_about_overlay = packed.instantiate() as AboutProjectOverlay
	add_child(_about_overlay)
	return _about_overlay


func _on_whats_new_pressed() -> void:
	var overlay := _ensure_whats_new_overlay()
	if overlay:
		overlay.show_latest()


func _on_about_pressed() -> void:
	var overlay := _ensure_about_overlay()
	if overlay:
		overlay.show_about()


func _apply_update_dialog_locale() -> void:
	if _confirm_overlay:
		_confirm_overlay.apply_locale()


func _apply_language_option_items() -> void:
	if language_option == null:
		return
	var current := LocaleManager.get_locale() if LocaleManager else "ru"
	language_option.set_block_signals(true)
	language_option.clear()
	language_option.add_item(tr("LANG_RU"), 0)
	language_option.set_item_metadata(0, "ru")
	language_option.add_item(tr("LANG_EN"), 1)
	language_option.set_item_metadata(1, "en")
	language_option.select(1 if current == "en" else 0)
	language_option.set_block_signals(false)


func _sync_language_option_selection() -> void:
	if language_option == null or language_option.item_count < 2:
		return
	var current := LocaleManager.get_locale() if LocaleManager else "ru"
	language_option.set_block_signals(true)
	language_option.select(1 if current == "en" else 0)
	language_option.set_block_signals(false)


func _apply_initial_settings() -> void:
	if check_updates_on_startup_checkbox:
		check_updates_on_startup_checkbox.set_pressed_no_signal(
			bool(SettingsManager.get_setting("check_updates_on_startup", true))
		)


func _on_language_selected(index: int) -> void:
	if language_option == null or LocaleManager == null:
		return
	var code := String(language_option.get_item_metadata(index))
	LocaleManager.set_locale(code, true, false)
	apply_locale()
	emit_signal("settings_changed")


func _on_check_updates_pressed() -> void:
	if UpdateChecker == null or UpdateChecker.is_busy():
		return
	if check_updates_button:
		check_updates_button.disabled = true
		check_updates_button.text = tr("UPDATE_CHECKING")
	UpdateChecker.check_for_updates(false)


func _on_check_updates_on_startup_toggled(enabled: bool) -> void:
	SettingsManager.set_setting("check_updates_on_startup", enabled)
	emit_signal("settings_changed")


func _on_update_check_completed(result: Dictionary) -> void:
	if result.get("silent", false):
		return
	if check_updates_button:
		check_updates_button.disabled = false
		check_updates_button.text = tr("UPDATE_CHECK_BUTTON")
	_show_manual_update_check_result(result)


func _show_manual_update_check_result(result: Dictionary) -> void:
	if not result.get("ok", false):
		var err_key := str(result.get("error_key", "UPDATE_ERROR_NETWORK"))
		_Overlay.notify(_notice_overlay, tr(err_key))
		return
	if result.get("up_to_date", false):
		_Overlay.notify(
			_notice_overlay,
			tr("UPDATE_UP_TO_DATE") % str(result.get("current", AppVersion.get_display_version())),
		)
		return
	_pending_update_url = str(result.get("latest_url", AppVersion.get_releases_url()))
	_apply_update_dialog_locale()
	var accepted := await _Overlay.ask(
		_confirm_overlay,
		tr("UPDATE_AVAILABLE_TEXT") % [
			str(result.get("latest", "")),
			str(result.get("current", AppVersion.get_display_version())),
		],
		"info",
		tr("UPDATE_AVAILABLE_TITLE"),
		tr("UPDATE_BTN_OPEN"),
		tr("UPDATE_BTN_LATER"),
	)
	if accepted:
		_on_update_available_manual_confirmed()


func _on_update_available_manual_confirmed() -> void:
	if _pending_update_url != "":
		OS.shell_open(_pending_update_url)
	_pending_update_url = ""
