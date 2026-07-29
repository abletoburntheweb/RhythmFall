# scenes/profile/components/profile_category_nav.gd
class_name ProfileCategoryNav
extends Node

const _UiCategoryButton = preload("res://logic/ui/ui_category_button.gd")
const _UiListSlideTransition = preload("res://logic/ui/ui_list_slide_transition.gd")

const CATEGORIES_HBOX_PATH := "MainVBox/CategoryRow/CategoryBarPanel/CategoriesHBox"
const CATEGORY_BUTTON_SPECS: Array = [
	["overview", "CategoryButtonOverview"],
	["stats", "CategoryButtonStats"],
	["genres", "CategoryButtonGenres"],
	["records", "CategoryButtonRecords"],
]
const CATEGORY_LOCALE_KEYS := {
	"overview": "PROFILE_CAT_OVERVIEW",
	"stats": "PROFILE_CAT_STATS",
	"genres": "PROFILE_CAT_GENRES",
	"records": "PROFILE_CAT_RECORDS",
}
const CATEGORY_BTN_HORIZONTAL_PAD := 40.0
const CATEGORY_BTN_MIN_HEIGHT := 42.0
const CATEGORY_ICON_PAD := 26.0

var profile: ProfileScreen = null
var current_category: String = "overview"
var skip_transition: bool = true


func initialize(host: ProfileScreen) -> void:
	profile = host


func is_valid_category(category: String) -> bool:
	for spec in CATEGORY_BUTTON_SPECS:
		if String(spec[0]) == category:
			return true
	return false


func restore_from_settings() -> void:
	var saved := str(SettingsManager.get_setting("last_profile_category", "overview"))
	if saved == "medals":
		saved = "overview"
	current_category = saved if is_valid_category(saved) else "overview"


func setup() -> void:
	_setup_bar_style()
	apply_button_labels()
	sync_all_button_layouts()
	update_buttons(current_category)


func select(category: String, animate: bool = true) -> void:
	if not is_valid_category(category) or category == current_category:
		return
	var previous_category := current_category
	_reset_hover_before_switch(previous_category)
	UiScreenHotkeys.play_section_switch_sound()
	var apply := func() -> void:
		current_category = category
		SettingsManager.set_setting("last_profile_category", category)
		SettingsManager.save_settings()
		update_buttons(category)
		profile.on_category_nav_changed(category)
	var host: Control = profile.profile_root if profile.profile_root else profile
	_UiListSlideTransition.crossfade(host, apply, skip_transition if animate else true)


func get_category_button(category: String) -> Button:
	var hbox := _categories_hbox()
	if hbox == null:
		return null
	for spec in CATEGORY_BUTTON_SPECS:
		if String(spec[0]) == category:
			return hbox.get_node_or_null(String(spec[1])) as Button
	return null


func apply_button_labels() -> void:
	var hbox := _categories_hbox()
	if hbox == null:
		return
	for spec in CATEGORY_BUTTON_SPECS:
		var category := String(spec[0])
		var btn := hbox.get_node_or_null(String(spec[1])) as Button
		if btn and CATEGORY_LOCALE_KEYS.has(category):
			var locale_key: String = CATEGORY_LOCALE_KEYS[category]
			var label := profile.tr(locale_key)
			btn.text = category if label == locale_key else label
	sync_all_button_layouts()


func update_buttons(selected: String) -> void:
	_apply_category_buttons(selected)
	if profile and profile.get_tree():
		profile.get_tree().create_timer(0.05).timeout.connect(
			func() -> void: _apply_category_buttons(selected),
			CONNECT_ONE_SHOT
		)


func _apply_category_buttons(selected: String) -> void:
	var hbox := _categories_hbox()
	if hbox == null:
		return
	for spec in CATEGORY_BUTTON_SPECS:
		var category := String(spec[0])
		var btn := hbox.get_node_or_null(String(spec[1])) as Button
		if btn:
			_UiCategoryButton.apply_selection(btn, selected == category, 14)


func sync_all_button_layouts() -> void:
	var hbox := _categories_hbox()
	if hbox == null:
		return
	for spec in CATEGORY_BUTTON_SPECS:
		var btn := hbox.get_node_or_null(String(spec[1])) as Button
		if btn:
			btn.clip_text = false
			btn.text_overrun_behavior = TextServer.OVERRUN_NO_TRIMMING
			btn.custom_minimum_size = Vector2(_measure_button_min_width(btn), CATEGORY_BTN_MIN_HEIGHT)
	if profile and profile.has_method("_balance_category_export_row"):
		profile.call_deferred("_balance_category_export_row")


func ensure_records_button() -> void:
	var hbox := _categories_hbox()
	if hbox and hbox.get_node_or_null("CategoryButtonRecords") == null:
		var ref_btn := hbox.get_node_or_null("CategoryButtonGenres") as Button
		var records_btn := Button.new()
		records_btn.name = "CategoryButtonRecords"
		records_btn.text = profile.tr("PROFILE_CAT_RECORDS")
		if ref_btn:
			records_btn.theme = ref_btn.theme
		records_btn.set_meta("ui_icon_file", "trophy.svg")
		records_btn.set_meta("ui_variation_inactive", &"CategoryCover")
		records_btn.set_meta("ui_variation_active", &"ActiveCover")
		records_btn.theme_type_variation = &"CategoryCover"
		hbox.add_child(records_btn)
		if not records_btn.pressed.is_connected(profile._on_profile_category_selected):
			records_btn.pressed.connect(profile._on_profile_category_selected.bind("records"))


func _setup_bar_style() -> void:
	if profile.category_bar_panel == null:
		return
	profile.category_bar_panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.09, 0.1, 0.14, 0.72)
	panel_style.border_color = Color(1, 1, 1, 0.08)
	panel_style.set_border_width_all(1)
	panel_style.set_corner_radius_all(12)
	panel_style.content_margin_left = 10.0
	panel_style.content_margin_top = 8.0
	panel_style.content_margin_right = 10.0
	panel_style.content_margin_bottom = 8.0
	profile.category_bar_panel.add_theme_stylebox_override("panel", panel_style)


func _categories_hbox() -> HBoxContainer:
	return profile.get_node_or_null(CATEGORIES_HBOX_PATH) as HBoxContainer


func _measure_button_min_width(btn: Button) -> float:
	var font := btn.get_theme_font("font")
	var font_size := btn.get_theme_font_size("font_size")
	if font == null:
		return 88.0
	var text_size := font.get_string_size(btn.text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
	return text_size.x + CATEGORY_BTN_HORIZONTAL_PAD + CATEGORY_ICON_PAD


func _reset_hover_before_switch(previous_category: String) -> void:
	var hbox := _categories_hbox()
	if hbox:
		for spec in CATEGORY_BUTTON_SPECS:
			var btn := hbox.get_node_or_null(String(spec[1])) as Button
			_UiCategoryButton.reset_hover_state(btn)
	_reset_panel_hover(previous_category)


func _reset_panel_hover(category: String) -> void:
	if profile == null:
		return
	var panel: Node = null
	match category:
		"overview":
			panel = profile.overview_tab
		"stats":
			panel = profile.stats_tab
		"genres":
			panel = profile.genres_tab
		"records":
			panel = profile.records_tab
	if panel:
		_UiCategoryButton.reset_hover_in_subtree(panel)
