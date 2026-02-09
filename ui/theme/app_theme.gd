extends Object
class_name AppTheme

static func _make_button_box(bg: Color, border_col: Color, draw_center := true, border_w := 0) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.draw_center = draw_center
	sb.border_color = border_col
	sb.border_width_top = border_w
	sb.border_width_right = border_w
	sb.border_width_bottom = border_w
	sb.border_width_left = border_w
	sb.corner_radius_top_left = 10
	sb.corner_radius_top_right = 10
	sb.corner_radius_bottom_right = 10
	sb.corner_radius_bottom_left = 10
	sb.shadow_color = Color(0, 0, 0, 0.35)
	sb.shadow_size = 6
	sb.shadow_offset = Vector2(0, 2)
	sb.content_margin_left = 16
	sb.content_margin_right = 16
	sb.content_margin_top = 10
	sb.content_margin_bottom = 10
	return sb

static func build_theme() -> Theme:
	var theme := Theme.new()
	theme.add_type("Palette")
	theme.set_color("primary", "Palette", Color(0.42, 0.57, 0.82, 1.0))
	theme.set_color("secondary", "Palette", Color(0.27, 0.32, 0.40, 1.0))
	theme.set_color("danger", "Palette", Color(0.85, 0.30, 0.34, 1.0))
	theme.set_color("outline", "Palette", Color(1, 1, 1, 0.85))
	theme.set_color("text", "Palette", Color(1, 1, 1, 1.0))
	theme.set_color("text_muted", "Palette", Color(0.92, 0.94, 0.98, 1.0))
	theme.set_color("panel_bg", "Palette", Color(0.11, 0.12, 0.16, 1.0))
	theme.set_color("panel_border", "Palette", Color(1, 1, 1, 0.22))
	theme.set_color("accent_teal", "Palette", Color(0.38, 0.78, 0.74, 1.0))
	theme.set_color("accent_purple", "Palette", Color(0.66, 0.58, 0.86, 1.0))
	theme.set_color("accent_pink", "Palette", Color(0.86, 0.52, 0.72, 1.0))
	theme.set_color("accent_sky", "Palette", Color(0.52, 0.76, 0.92, 1.0))
	theme.set_color("accent_mint", "Palette", Color(0.62, 0.86, 0.72, 1.0))
	theme.set_color("accent_slate", "Palette", Color(0.80, 0.86, 0.94, 1.0))
	var blue := theme.get_color("primary", "Palette")
	var blue_hover := blue.lightened(0.1)
	var blue_pressed := blue.darkened(0.1)
	var outline := theme.get_color("outline", "Palette")
	var text := theme.get_color("text", "Palette")
	var transparent := Color(0, 0, 0, 0)

	var btn_outline_normal := _make_button_box(transparent, outline, false, 2)
	var btn_outline_hover := _make_button_box(transparent, outline, false, 2)
	var btn_outline_pressed := _make_button_box(transparent, outline.darkened(0.2), true, 2)
	var btn_outline_disabled := _make_button_box(transparent, outline.darkened(0.5), false, 2)
	var btn_outline_focus := _make_button_box(transparent, outline, false, 3)

	theme.set_stylebox("normal", "Button", btn_outline_normal)
	theme.set_stylebox("hover", "Button", btn_outline_hover)
	theme.set_stylebox("pressed", "Button", btn_outline_pressed)
	theme.set_stylebox("disabled", "Button", btn_outline_disabled)
	theme.set_stylebox("focus", "Button", btn_outline_focus)
	theme.set_color("font_color", "Button", text)
	theme.set_color("font_hover_color", "Button", text)
	theme.set_color("font_pressed_color", "Button", text)
	theme.set_color("font_disabled_color", "Button", text.darkened(0.5))

	theme.set_type_variation("FlatButton", "Button")
	theme.set_stylebox("normal", "FlatButton", btn_outline_normal)
	theme.set_stylebox("hover", "FlatButton", btn_outline_hover)
	theme.set_stylebox("pressed", "FlatButton", btn_outline_pressed)
	theme.set_stylebox("disabled", "FlatButton", btn_outline_disabled)
	theme.set_stylebox("focus", "FlatButton", btn_outline_focus)
	theme.set_color("font_color", "FlatButton", text)
	theme.set_color("font_hover_color", "FlatButton", text)
	theme.set_color("font_pressed_color", "FlatButton", text)
	theme.set_color("font_disabled_color", "FlatButton", text.darkened(0.5))

	var play_outline := theme.get_color("accent_teal", "Palette")
	var fb_play_normal := _make_button_box(transparent, play_outline, false, 2)
	var fb_play_hover := _make_button_box(transparent, play_outline, false, 2)
	var fb_play_pressed := _make_button_box(transparent, play_outline.darkened(0.2), true, 2)
	var fb_play_disabled := _make_button_box(transparent, play_outline.darkened(0.5), false, 2)
	var fb_play_focus := _make_button_box(transparent, play_outline, false, 3)
	theme.set_type_variation("FlatPlayButton", "Button")
	theme.set_stylebox("normal", "FlatPlayButton", fb_play_normal)
	theme.set_stylebox("hover", "FlatPlayButton", fb_play_hover)
	theme.set_stylebox("pressed", "FlatPlayButton", fb_play_pressed)
	theme.set_stylebox("disabled", "FlatPlayButton", fb_play_disabled)
	theme.set_stylebox("focus", "FlatPlayButton", fb_play_focus)
	theme.set_color("font_color", "FlatPlayButton", text)
	theme.set_color("font_hover_color", "FlatPlayButton", text)
	theme.set_color("font_pressed_color", "FlatPlayButton", text)
	theme.set_color("font_disabled_color", "FlatPlayButton", text.darkened(0.5))

	var exit_outline := theme.get_color("accent_pink", "Palette")
	var fb_exit_normal := _make_button_box(transparent, exit_outline, false, 2)
	var fb_exit_hover := _make_button_box(transparent, exit_outline, false, 2)
	var fb_exit_pressed := _make_button_box(transparent, exit_outline.darkened(0.2), true, 2)
	var fb_exit_disabled := _make_button_box(transparent, exit_outline.darkened(0.5), false, 2)
	var fb_exit_focus := _make_button_box(transparent, exit_outline, false, 3)
	theme.set_type_variation("FlatExitButton", "Button")
	theme.set_stylebox("normal", "FlatExitButton", fb_exit_normal)
	theme.set_stylebox("hover", "FlatExitButton", fb_exit_hover)
	theme.set_stylebox("pressed", "FlatExitButton", fb_exit_pressed)
	theme.set_stylebox("disabled", "FlatExitButton", fb_exit_disabled)
	theme.set_stylebox("focus", "FlatExitButton", fb_exit_focus)
	theme.set_color("font_color", "FlatExitButton", text)
	theme.set_color("font_hover_color", "FlatExitButton", text)
	theme.set_color("font_pressed_color", "FlatExitButton", text)
	theme.set_color("font_disabled_color", "FlatExitButton", text.darkened(0.5))

	var gen_outline := theme.get_color("accent_mint", "Palette")
	var fb_gen_normal := btn_outline_normal.duplicate()
	fb_gen_normal.border_color = gen_outline
	var fb_gen_hover := btn_outline_hover.duplicate()
	fb_gen_hover.border_color = gen_outline
	var fb_gen_pressed := btn_outline_pressed.duplicate()
	fb_gen_pressed.border_color = gen_outline.darkened(0.2)
	var fb_gen_disabled := btn_outline_disabled.duplicate()
	fb_gen_disabled.border_color = gen_outline.darkened(0.5)
	var fb_gen_focus := btn_outline_focus.duplicate()
	fb_gen_focus.border_color = gen_outline
	theme.set_type_variation("FlatGenerateButton", "Button")
	theme.set_stylebox("normal", "FlatGenerateButton", fb_gen_normal)
	theme.set_stylebox("hover", "FlatGenerateButton", fb_gen_hover)
	theme.set_stylebox("pressed", "FlatGenerateButton", fb_gen_pressed)
	theme.set_stylebox("disabled", "FlatGenerateButton", fb_gen_disabled)
	theme.set_stylebox("focus", "FlatGenerateButton", fb_gen_focus)
	theme.set_color("font_color", "FlatGenerateButton", text)
	theme.set_color("font_hover_color", "FlatGenerateButton", text)
	theme.set_color("font_pressed_color", "FlatGenerateButton", text)
	theme.set_color("font_disabled_color", "FlatGenerateButton", text.darkened(0.5))

	var bpm_outline := theme.get_color("accent_sky", "Palette")
	var fb_bpm_normal := btn_outline_normal.duplicate()
	fb_bpm_normal.border_color = bpm_outline
	var fb_bpm_hover := btn_outline_hover.duplicate()
	fb_bpm_hover.border_color = bpm_outline
	var fb_bpm_pressed := btn_outline_pressed.duplicate()
	fb_bpm_pressed.border_color = bpm_outline.darkened(0.2)
	var fb_bpm_disabled := btn_outline_disabled.duplicate()
	fb_bpm_disabled.border_color = bpm_outline.darkened(0.5)
	var fb_bpm_focus := btn_outline_focus.duplicate()
	fb_bpm_focus.border_color = bpm_outline
	theme.set_type_variation("FlatBpmButton", "Button")
	theme.set_stylebox("normal", "FlatBpmButton", fb_bpm_normal)
	theme.set_stylebox("hover", "FlatBpmButton", fb_bpm_hover)
	theme.set_stylebox("pressed", "FlatBpmButton", fb_bpm_pressed)
	theme.set_stylebox("disabled", "FlatBpmButton", fb_bpm_disabled)
	theme.set_stylebox("focus", "FlatBpmButton", fb_bpm_focus)
	theme.set_color("font_color", "FlatBpmButton", text)
	theme.set_color("font_hover_color", "FlatBpmButton", text)
	theme.set_color("font_pressed_color", "FlatBpmButton", text)
	theme.set_color("font_disabled_color", "FlatBpmButton", text.darkened(0.5))

	var res_outline := theme.get_color("accent_purple", "Palette")
	var fb_res_normal := btn_outline_normal.duplicate()
	fb_res_normal.border_color = res_outline
	var fb_res_hover := btn_outline_hover.duplicate()
	fb_res_hover.border_color = res_outline
	var fb_res_pressed := btn_outline_pressed.duplicate()
	fb_res_pressed.border_color = res_outline.darkened(0.2)
	var fb_res_disabled := btn_outline_disabled.duplicate()
	fb_res_disabled.border_color = res_outline.darkened(0.5)
	var fb_res_focus := btn_outline_focus.duplicate()
	fb_res_focus.border_color = res_outline
	theme.set_type_variation("FlatResultsButton", "Button")
	theme.set_stylebox("normal", "FlatResultsButton", fb_res_normal)
	theme.set_stylebox("hover", "FlatResultsButton", fb_res_hover)
	theme.set_stylebox("pressed", "FlatResultsButton", fb_res_pressed)
	theme.set_stylebox("disabled", "FlatResultsButton", fb_res_disabled)
	theme.set_stylebox("focus", "FlatResultsButton", fb_res_focus)
	theme.set_color("font_color", "FlatResultsButton", text)
	theme.set_color("font_hover_color", "FlatResultsButton", text)
	theme.set_color("font_pressed_color", "FlatResultsButton", text)
	theme.set_color("font_disabled_color", "FlatResultsButton", text.darkened(0.5))
	
	var menu_song_outline := theme.get_color("primary", "Palette")
	var fb_menu_song_normal := btn_outline_normal.duplicate()
	fb_menu_song_normal.border_color = menu_song_outline
	var fb_menu_song_hover := btn_outline_hover.duplicate()
	fb_menu_song_hover.border_color = menu_song_outline
	var fb_menu_song_pressed := btn_outline_pressed.duplicate()
	fb_menu_song_pressed.border_color = menu_song_outline.darkened(0.2)
	var fb_menu_song_disabled := btn_outline_disabled.duplicate()
	fb_menu_song_disabled.border_color = menu_song_outline.darkened(0.5)
	var fb_menu_song_focus := btn_outline_focus.duplicate()
	fb_menu_song_focus.border_color = menu_song_outline
	theme.set_type_variation("FlatMenuSongButton", "Button")
	theme.set_stylebox("normal", "FlatMenuSongButton", fb_menu_song_normal)
	theme.set_stylebox("hover", "FlatMenuSongButton", fb_menu_song_hover)
	theme.set_stylebox("pressed", "FlatMenuSongButton", fb_menu_song_pressed)
	theme.set_stylebox("disabled", "FlatMenuSongButton", fb_menu_song_disabled)
	theme.set_stylebox("focus", "FlatMenuSongButton", fb_menu_song_focus)
	theme.set_color("font_color", "FlatMenuSongButton", text)
	theme.set_color("font_hover_color", "FlatMenuSongButton", text)
	theme.set_color("font_pressed_color", "FlatMenuSongButton", text)
	theme.set_color("font_disabled_color", "FlatMenuSongButton", text.darkened(0.5))

	var menu_shop_outline := theme.get_color("accent_mint", "Palette")
	var fb_menu_shop_normal := btn_outline_normal.duplicate()
	fb_menu_shop_normal.border_color = menu_shop_outline
	var fb_menu_shop_hover := btn_outline_hover.duplicate()
	fb_menu_shop_hover.border_color = menu_shop_outline
	var fb_menu_shop_pressed := btn_outline_pressed.duplicate()
	fb_menu_shop_pressed.border_color = menu_shop_outline.darkened(0.2)
	var fb_menu_shop_disabled := btn_outline_disabled.duplicate()
	fb_menu_shop_disabled.border_color = menu_shop_outline.darkened(0.5)
	var fb_menu_shop_focus := btn_outline_focus.duplicate()
	fb_menu_shop_focus.border_color = menu_shop_outline
	theme.set_type_variation("FlatMenuShopButton", "Button")
	theme.set_stylebox("normal", "FlatMenuShopButton", fb_menu_shop_normal)
	theme.set_stylebox("hover", "FlatMenuShopButton", fb_menu_shop_hover)
	theme.set_stylebox("pressed", "FlatMenuShopButton", fb_menu_shop_pressed)
	theme.set_stylebox("disabled", "FlatMenuShopButton", fb_menu_shop_disabled)
	theme.set_stylebox("focus", "FlatMenuShopButton", fb_menu_shop_focus)
	theme.set_color("font_color", "FlatMenuShopButton", text)
	theme.set_color("font_hover_color", "FlatMenuShopButton", text)
	theme.set_color("font_pressed_color", "FlatMenuShopButton", text)
	theme.set_color("font_disabled_color", "FlatMenuShopButton", text.darkened(0.5))

	var menu_profile_outline := theme.get_color("accent_slate", "Palette")
	var fb_menu_profile_normal := btn_outline_normal.duplicate()
	fb_menu_profile_normal.border_color = menu_profile_outline
	var fb_menu_profile_hover := btn_outline_hover.duplicate()
	fb_menu_profile_hover.border_color = menu_profile_outline
	var fb_menu_profile_pressed := btn_outline_pressed.duplicate()
	fb_menu_profile_pressed.border_color = menu_profile_outline.darkened(0.2)
	var fb_menu_profile_disabled := btn_outline_disabled.duplicate()
	fb_menu_profile_disabled.border_color = menu_profile_outline.darkened(0.5)
	var fb_menu_profile_focus := btn_outline_focus.duplicate()
	fb_menu_profile_focus.border_color = menu_profile_outline
	theme.set_type_variation("FlatMenuProfileButton", "Button")
	theme.set_stylebox("normal", "FlatMenuProfileButton", fb_menu_profile_normal)
	theme.set_stylebox("hover", "FlatMenuProfileButton", fb_menu_profile_hover)
	theme.set_stylebox("pressed", "FlatMenuProfileButton", fb_menu_profile_pressed)
	theme.set_stylebox("disabled", "FlatMenuProfileButton", fb_menu_profile_disabled)
	theme.set_stylebox("focus", "FlatMenuProfileButton", fb_menu_profile_focus)
	theme.set_color("font_color", "FlatMenuProfileButton", text)
	theme.set_color("font_hover_color", "FlatMenuProfileButton", text)
	theme.set_color("font_pressed_color", "FlatMenuProfileButton", text)
	theme.set_color("font_disabled_color", "FlatMenuProfileButton", text.darkened(0.5))

	var menu_ach_outline := theme.get_color("accent_purple", "Palette")
	var fb_menu_ach_normal := btn_outline_normal.duplicate()
	fb_menu_ach_normal.border_color = menu_ach_outline
	var fb_menu_ach_hover := btn_outline_hover.duplicate()
	fb_menu_ach_hover.border_color = menu_ach_outline
	var fb_menu_ach_pressed := btn_outline_pressed.duplicate()
	fb_menu_ach_pressed.border_color = menu_ach_outline.darkened(0.2)
	var fb_menu_ach_disabled := btn_outline_disabled.duplicate()
	fb_menu_ach_disabled.border_color = menu_ach_outline.darkened(0.5)
	var fb_menu_ach_focus := btn_outline_focus.duplicate()
	fb_menu_ach_focus.border_color = menu_ach_outline
	theme.set_type_variation("FlatMenuAchievementsButton", "Button")
	theme.set_stylebox("normal", "FlatMenuAchievementsButton", fb_menu_ach_normal)
	theme.set_stylebox("hover", "FlatMenuAchievementsButton", fb_menu_ach_hover)
	theme.set_stylebox("pressed", "FlatMenuAchievementsButton", fb_menu_ach_pressed)
	theme.set_stylebox("disabled", "FlatMenuAchievementsButton", fb_menu_ach_disabled)
	theme.set_stylebox("focus", "FlatMenuAchievementsButton", fb_menu_ach_focus)
	theme.set_color("font_color", "FlatMenuAchievementsButton", text)
	theme.set_color("font_hover_color", "FlatMenuAchievementsButton", text)
	theme.set_color("font_pressed_color", "FlatMenuAchievementsButton", text)
	theme.set_color("font_disabled_color", "FlatMenuAchievementsButton", text.darkened(0.5))

	var menu_settings_outline := theme.get_color("accent_sky", "Palette")
	var fb_menu_settings_normal := btn_outline_normal.duplicate()
	fb_menu_settings_normal.border_color = menu_settings_outline
	var fb_menu_settings_hover := btn_outline_hover.duplicate()
	fb_menu_settings_hover.border_color = menu_settings_outline
	var fb_menu_settings_pressed := btn_outline_pressed.duplicate()
	fb_menu_settings_pressed.border_color = menu_settings_outline.darkened(0.2)
	var fb_menu_settings_disabled := btn_outline_disabled.duplicate()
	fb_menu_settings_disabled.border_color = menu_settings_outline.darkened(0.5)
	var fb_menu_settings_focus := btn_outline_focus.duplicate()
	fb_menu_settings_focus.border_color = menu_settings_outline
	theme.set_type_variation("FlatMenuSettingsButton", "Button")
	theme.set_stylebox("normal", "FlatMenuSettingsButton", fb_menu_settings_normal)
	theme.set_stylebox("hover", "FlatMenuSettingsButton", fb_menu_settings_hover)
	theme.set_stylebox("pressed", "FlatMenuSettingsButton", fb_menu_settings_pressed)
	theme.set_stylebox("disabled", "FlatMenuSettingsButton", fb_menu_settings_disabled)
	theme.set_stylebox("focus", "FlatMenuSettingsButton", fb_menu_settings_focus)
	theme.set_color("font_color", "FlatMenuSettingsButton", text)
	theme.set_color("font_hover_color", "FlatMenuSettingsButton", text)
	theme.set_color("font_pressed_color", "FlatMenuSettingsButton", text)
	theme.set_color("font_disabled_color", "FlatMenuSettingsButton", text.darkened(0.5))
	
	var modal_bg := theme.get_color("panel_bg", "Palette").lightened(0.06)
	var modal_primary_outline := theme.get_color("accent_mint", "Palette")
	var fb_modal_primary_normal := btn_outline_normal.duplicate()
	fb_modal_primary_normal.draw_center = true
	fb_modal_primary_normal.bg_color = modal_bg
	fb_modal_primary_normal.border_color = modal_primary_outline
	var fb_modal_primary_hover := btn_outline_hover.duplicate()
	fb_modal_primary_hover.draw_center = true
	fb_modal_primary_hover.bg_color = modal_bg.lightened(0.06)
	fb_modal_primary_hover.border_color = modal_primary_outline
	var fb_modal_primary_pressed := btn_outline_pressed.duplicate()
	fb_modal_primary_pressed.draw_center = true
	fb_modal_primary_pressed.bg_color = modal_bg.darkened(0.08)
	fb_modal_primary_pressed.border_color = modal_primary_outline.darkened(0.2)
	var fb_modal_primary_disabled := btn_outline_disabled.duplicate()
	fb_modal_primary_disabled.draw_center = true
	fb_modal_primary_disabled.bg_color = modal_bg.darkened(0.12)
	fb_modal_primary_disabled.border_color = modal_primary_outline.darkened(0.5)
	var fb_modal_primary_focus := btn_outline_focus.duplicate()
	fb_modal_primary_focus.draw_center = true
	fb_modal_primary_focus.bg_color = modal_bg
	fb_modal_primary_focus.border_color = modal_primary_outline
	theme.set_type_variation("FlatModalPrimaryButton", "Button")
	theme.set_stylebox("normal", "FlatModalPrimaryButton", fb_modal_primary_normal)
	theme.set_stylebox("hover", "FlatModalPrimaryButton", fb_modal_primary_hover)
	theme.set_stylebox("pressed", "FlatModalPrimaryButton", fb_modal_primary_pressed)
	theme.set_stylebox("disabled", "FlatModalPrimaryButton", fb_modal_primary_disabled)
	theme.set_stylebox("focus", "FlatModalPrimaryButton", fb_modal_primary_focus)
	theme.set_color("font_color", "FlatModalPrimaryButton", text)
	theme.set_color("font_hover_color", "FlatModalPrimaryButton", text)
	theme.set_color("font_pressed_color", "FlatModalPrimaryButton", text)
	theme.set_color("font_disabled_color", "FlatModalPrimaryButton", text.darkened(0.5))

	var modal_back_outline := theme.get_color("accent_slate", "Palette")
	var fb_modal_back_normal := btn_outline_normal.duplicate()
	fb_modal_back_normal.draw_center = true
	fb_modal_back_normal.bg_color = theme.get_color("panel_bg", "Palette").darkened(0.02)
	fb_modal_back_normal.border_color = modal_back_outline
	var fb_modal_back_hover := btn_outline_hover.duplicate()
	fb_modal_back_hover.draw_center = true
	fb_modal_back_hover.bg_color = fb_modal_back_normal.bg_color.lightened(0.06)
	fb_modal_back_hover.border_color = modal_back_outline
	var fb_modal_back_pressed := btn_outline_pressed.duplicate()
	fb_modal_back_pressed.draw_center = true
	fb_modal_back_pressed.bg_color = fb_modal_back_normal.bg_color.darkened(0.08)
	fb_modal_back_pressed.border_color = modal_back_outline.darkened(0.2)
	var fb_modal_back_disabled := btn_outline_disabled.duplicate()
	fb_modal_back_disabled.draw_center = true
	fb_modal_back_disabled.bg_color = fb_modal_back_normal.bg_color.darkened(0.12)
	fb_modal_back_disabled.border_color = modal_back_outline.darkened(0.5)
	var fb_modal_back_focus := btn_outline_focus.duplicate()
	fb_modal_back_focus.draw_center = true
	fb_modal_back_focus.bg_color = fb_modal_back_normal.bg_color
	fb_modal_back_focus.border_color = modal_back_outline
	theme.set_type_variation("FlatBackButton", "Button")
	theme.set_stylebox("normal", "FlatBackButton", fb_modal_back_normal)
	theme.set_stylebox("hover", "FlatBackButton", fb_modal_back_hover)
	theme.set_stylebox("pressed", "FlatBackButton", fb_modal_back_pressed)
	theme.set_stylebox("disabled", "FlatBackButton", fb_modal_back_disabled)
	theme.set_stylebox("focus", "FlatBackButton", fb_modal_back_focus)
	theme.set_color("font_color", "FlatBackButton", text)
	theme.set_color("font_hover_color", "FlatBackButton", text)
	theme.set_color("font_pressed_color", "FlatBackButton", text)
	theme.set_color("font_disabled_color", "FlatBackButton", text.darkened(0.5))

	theme.set_type_variation("Danger", "Button")
	var red := theme.get_color("danger", "Palette")
	var btn_danger_normal := _make_button_box(red, Color(0, 0, 0, 0), true, 0)
	var btn_danger_hover := _make_button_box(red.lightened(0.06), Color(0, 0, 0, 0), true, 0)
	var btn_danger_pressed := _make_button_box(red.darkened(0.08), Color(0, 0, 0, 0), true, 0)
	var btn_danger_disabled := _make_button_box(red.darkened(0.25), Color(0, 0, 0, 0), true, 0)
	var btn_danger_focus := _make_button_box(red, outline, true, 2)
	theme.set_stylebox("normal", "Danger", btn_danger_normal)
	theme.set_stylebox("hover", "Danger", btn_danger_hover)
	theme.set_stylebox("pressed", "Danger", btn_danger_pressed)
	theme.set_stylebox("disabled", "Danger", btn_danger_disabled)
	theme.set_stylebox("focus", "Danger", btn_danger_focus)
	theme.set_color("font_color", "Danger", text)
	theme.set_color("font_hover_color", "Danger", text)
	theme.set_color("font_pressed_color", "Danger", text)
	theme.set_color("font_disabled_color", "Danger", text.darkened(0.5))


	var slider_box := StyleBoxFlat.new()
	slider_box.bg_color = Color(0.18, 0.2, 0.26, 1.0)
	slider_box.corner_radius_top_left = 6
	slider_box.corner_radius_top_right = 6
	slider_box.corner_radius_bottom_right = 6
	slider_box.corner_radius_bottom_left = 6
	slider_box.content_margin_top = 6
	slider_box.content_margin_bottom = 6

	var grabber_area := StyleBoxFlat.new()
	grabber_area.bg_color = Color(0, 0, 0, 0.0)
	grabber_area.content_margin_top = 6
	grabber_area.content_margin_bottom = 6

	theme.set_stylebox("slider", "HSlider", slider_box)
	theme.set_stylebox("grabber_area", "HSlider", grabber_area)

	var le_normal := StyleBoxFlat.new()
	le_normal.bg_color = Color(0.12, 0.13, 0.17, 1.0)
	le_normal.border_color = Color(1, 1, 1, 0.18)
	le_normal.border_width_left = 1
	le_normal.border_width_right = 1
	le_normal.border_width_top = 1
	le_normal.border_width_bottom = 1
	le_normal.corner_radius_top_left = 10
	le_normal.corner_radius_top_right = 10
	le_normal.corner_radius_bottom_right = 10
	le_normal.corner_radius_bottom_left = 10
	le_normal.content_margin_left = 12
	le_normal.content_margin_right = 12
	le_normal.content_margin_top = 8
	le_normal.content_margin_bottom = 8

	var le_focus := le_normal.duplicate()
	le_focus.border_color = blue
	le_focus.border_width_left = 2
	le_focus.border_width_right = 2
	le_focus.border_width_top = 2
	le_focus.border_width_bottom = 2

	theme.set_stylebox("normal", "LineEdit", le_normal)
	theme.set_stylebox("focus", "LineEdit", le_focus)
	theme.set_color("font_color", "LineEdit", Color(0.92, 0.92, 0.94, 1.0))
	theme.set_color("font_placeholder_color", "LineEdit", Color(0.65, 0.68, 0.75, 1.0))
	theme.set_color("caret_color", "LineEdit", Color(0.95, 0.95, 0.95, 1.0))
	theme.set_color("clear_button_color", "LineEdit", Color(0.8, 0.85, 0.95, 1.0))
	theme.set_color("clear_button_color_pressed", "LineEdit", Color(1, 1, 1, 1.0))

	theme.set_type_variation("SearchField", "LineEdit")
	var sf_normal := le_normal.duplicate()
	sf_normal.bg_color = Color(0.14, 0.16, 0.22, 1.0)
	var sf_focus := le_focus.duplicate()
	theme.set_stylebox("normal", "SearchField", sf_normal)
	theme.set_stylebox("focus", "SearchField", sf_focus)
	theme.set_color("font_color", "SearchField", Color(0.95, 0.95, 0.98, 1.0))
	theme.set_color("font_placeholder_color", "SearchField", Color(0.7, 0.74, 0.8, 1.0))
	theme.set_color("caret_color", "SearchField", Color(1, 1, 1, 1.0))
	
	var pb_bg := StyleBoxFlat.new()
	pb_bg.bg_color = Color(0.12, 0.13, 0.17, 1.0)
	pb_bg.corner_radius_top_left = 8
	pb_bg.corner_radius_top_right = 8
	pb_bg.corner_radius_bottom_right = 8
	pb_bg.corner_radius_bottom_left = 8
	pb_bg.content_margin_top = 6
	pb_bg.content_margin_bottom = 6
	theme.set_stylebox("background", "ProgressBar", pb_bg)
	var pb_fill := StyleBoxFlat.new()
	pb_fill.bg_color = theme.get_color("accent_teal", "Palette")
	pb_fill.corner_radius_top_left = 8
	pb_fill.corner_radius_top_right = 8
	pb_fill.corner_radius_bottom_right = 8
	pb_fill.corner_radius_bottom_left = 8
	theme.set_stylebox("fill", "ProgressBar", pb_fill)
	theme.set_color("font_color", "ProgressBar", Color.WHITE)
	theme.set_color("font_outline_color", "ProgressBar", Color(0, 0, 0, 0.8))
	theme.set_constant("outline_size", "ProgressBar", 0)

	theme.set_type_variation("LevelLabel", "Label")
	theme.set_color("font_color", "LevelLabel", theme.get_color("text_muted", "Palette"))
	theme.set_type_variation("XPAmountLabel", "Label")
	theme.set_color("font_color", "XPAmountLabel", theme.get_color("text", "Palette"))

	theme.add_type("ChartPoint")
	theme.set_color("point_color", "ChartPoint", Color(0.6, 0.8, 1.0, 1.0))
	theme.set_color("border_color", "ChartPoint", Color(0, 0, 0, 1.0))
	theme.set_constant("point_radius", "ChartPoint", 6)
	theme.set_constant("border_width", "ChartPoint", 2)

	var card_base := StyleBoxFlat.new()
	card_base.bg_color = theme.get_color("panel_bg", "Palette")
	card_base.border_color = theme.get_color("panel_border", "Palette")
	card_base.border_width_left = 1
	card_base.border_width_right = 1
	card_base.border_width_top = 1
	card_base.border_width_bottom = 1
	card_base.corner_radius_top_left = 12
	card_base.corner_radius_top_right = 12
	card_base.corner_radius_bottom_right = 12
	card_base.corner_radius_bottom_left = 12
	card_base.shadow_color = Color(0, 0, 0, 0.35)
	card_base.shadow_size = 8
	card_base.shadow_offset = Vector2(0, 3)

	theme.set_stylebox("panel", "PanelContainer", card_base)

	theme.set_type_variation("CardDefault", "PanelContainer")
	var card_default := card_base.duplicate()
	card_default.shadow_size = 0
	card_default.shadow_offset = Vector2(0, 0)
	theme.set_stylebox("panel", "CardDefault", card_default)

	theme.set_type_variation("CardActive", "PanelContainer")
	var card_active := card_base.duplicate()
	card_active.border_color = blue
	card_active.border_width_left = 2
	card_active.border_width_right = 2
	card_active.border_width_top = 2
	card_active.border_width_bottom = 2
	card_active.shadow_size = 0
	card_active.shadow_offset = Vector2(0, 0)
	theme.set_stylebox("panel", "CardActive", card_active)

	theme.set_type_variation("CardLocked", "PanelContainer")
	var card_locked := card_base.duplicate()
	card_locked.bg_color = card_base.bg_color.darkened(0.15)
	card_locked.border_color = Color(1, 1, 1, 0.12)
	card_locked.shadow_size = 0
	card_locked.shadow_offset = Vector2(0, 0)
	theme.set_stylebox("panel", "CardLocked", card_locked)

	var opt_normal := _make_button_box(transparent, outline, true, 1)
	opt_normal.content_margin_left = 12
	opt_normal.content_margin_right = 12
	opt_normal.content_margin_top = 8
	opt_normal.content_margin_bottom = 8
	var opt_hover := opt_normal.duplicate()
	opt_hover.border_color = outline.lightened(0.2)
	var opt_pressed := _make_button_box(transparent, outline.darkened(0.2), true, 1)
	var opt_disabled := _make_button_box(transparent, outline.darkened(0.5), true, 1)
	var opt_focus := opt_normal.duplicate()
	opt_focus.border_width_left = 2
	opt_focus.border_width_right = 2
	opt_focus.border_width_top = 2
	opt_focus.border_width_bottom = 2
	theme.set_stylebox("normal", "OptionButton", opt_normal)
	theme.set_stylebox("hover", "OptionButton", opt_hover)
	theme.set_stylebox("pressed", "OptionButton", opt_pressed)
	theme.set_stylebox("disabled", "OptionButton", opt_disabled)
	theme.set_stylebox("focus", "OptionButton", opt_focus)
	theme.set_color("font_color", "OptionButton", text)
	theme.set_color("font_hover_color", "OptionButton", text)
	theme.set_color("font_pressed_color", "OptionButton", text)
	theme.set_color("font_disabled_color", "OptionButton", text.darkened(0.5))

	theme.set_type_variation("Dropdown", "OptionButton")
	theme.set_stylebox("normal", "Dropdown", opt_normal)
	theme.set_stylebox("hover", "Dropdown", opt_hover)
	theme.set_stylebox("pressed", "Dropdown", opt_pressed)
	theme.set_stylebox("disabled", "Dropdown", opt_disabled)
	theme.set_stylebox("focus", "Dropdown", opt_focus)
	theme.set_color("font_color", "Dropdown", text)
	theme.set_color("font_hover_color", "Dropdown", text)
	theme.set_color("font_pressed_color", "Dropdown", text)
	theme.set_color("font_disabled_color", "Dropdown", text.darkened(0.5))


	var v_track := StyleBoxFlat.new()
	v_track.bg_color = Color(0.12, 0.13, 0.17, 1.0)
	v_track.corner_radius_top_left = 8
	v_track.corner_radius_top_right = 8
	v_track.corner_radius_bottom_right = 8
	v_track.corner_radius_bottom_left = 8
	v_track.content_margin_left = 12
	v_track.content_margin_right = 12
	var v_grabber := StyleBoxFlat.new()
	v_grabber.bg_color = Color(0.30, 0.34, 0.44, 1.0)
	v_grabber.corner_radius_top_left = 8
	v_grabber.corner_radius_top_right = 8
	v_grabber.corner_radius_bottom_right = 8
	v_grabber.corner_radius_bottom_left = 8
	var v_grabber_high := v_grabber.duplicate()
	v_grabber_high.bg_color = v_grabber.bg_color.lightened(0.12)
	var v_grabber_pressed := v_grabber.duplicate()
	v_grabber_pressed.bg_color = v_grabber.bg_color.darkened(0.12)
	theme.set_stylebox("scroll", "VScrollBar", v_track)
	theme.set_stylebox("scroll_focus", "VScrollBar", v_track)
	theme.set_stylebox("grabber", "VScrollBar", v_grabber)
	theme.set_stylebox("grabber_highlight", "VScrollBar", v_grabber_high)
	theme.set_stylebox("grabber_pressed", "VScrollBar", v_grabber_pressed)

	var h_track := StyleBoxFlat.new()
	h_track.bg_color = Color(0.12, 0.13, 0.17, 1.0)
	h_track.corner_radius_top_left = 8
	h_track.corner_radius_top_right = 8
	h_track.corner_radius_bottom_right = 8
	h_track.corner_radius_bottom_left = 8
	h_track.content_margin_top = 12
	h_track.content_margin_bottom = 12
	var h_grabber := StyleBoxFlat.new()
	h_grabber.bg_color = Color(0.30, 0.34, 0.44, 1.0)
	h_grabber.corner_radius_top_left = 8
	h_grabber.corner_radius_top_right = 8
	h_grabber.corner_radius_bottom_right = 8
	h_grabber.corner_radius_bottom_left = 8
	var h_grabber_high := h_grabber.duplicate()
	h_grabber_high.bg_color = h_grabber.bg_color.lightened(0.12)
	var h_grabber_pressed := h_grabber.duplicate()
	h_grabber_pressed.bg_color = h_grabber.bg_color.darkened(0.12)
	theme.set_stylebox("scroll", "HScrollBar", h_track)
	theme.set_stylebox("scroll_focus", "HScrollBar", h_track)
	theme.set_stylebox("grabber", "HScrollBar", h_grabber)
	theme.set_stylebox("grabber_highlight", "HScrollBar", h_grabber_high)
	theme.set_stylebox("grabber_pressed", "HScrollBar", h_grabber_pressed)

	var pm_panel := StyleBoxFlat.new()
	pm_panel.bg_color = Color(0.10, 0.11, 0.15, 1.0)
	pm_panel.corner_radius_top_left = 10
	pm_panel.corner_radius_top_right = 10
	pm_panel.corner_radius_bottom_right = 10
	pm_panel.corner_radius_bottom_left = 10
	pm_panel.border_color = Color(1, 1, 1, 0.18)
	pm_panel.border_width_left = 1
	pm_panel.border_width_right = 1
	pm_panel.border_width_top = 1
	pm_panel.border_width_bottom = 1
	var pm_hover := StyleBoxFlat.new()
	pm_hover.bg_color = Color(0.18, 0.20, 0.26, 1.0)
	pm_hover.corner_radius_top_left = 6
	pm_hover.corner_radius_top_right = 6
	pm_hover.corner_radius_bottom_right = 6
	pm_hover.corner_radius_bottom_left = 6
	var pm_sep := StyleBoxFlat.new()
	pm_sep.bg_color = Color(1, 1, 1, 0.12)
	pm_sep.content_margin_top = 1
	pm_sep.content_margin_bottom = 1
	theme.set_stylebox("panel", "PopupMenu", pm_panel)
	theme.set_stylebox("hover", "PopupMenu", pm_hover)
	theme.set_stylebox("separator", "PopupMenu", pm_sep)
	theme.set_color("font_color", "PopupMenu", Color(0.92, 0.94, 0.98, 1.0))
	theme.set_color("font_hover_color", "PopupMenu", theme.get_color("text", "Palette"))
	theme.set_color("font_disabled_color", "PopupMenu", theme.get_color("text_muted", "Palette"))
	theme.set_color("font_accelerator_color", "PopupMenu", theme.get_color("accent_slate", "Palette"))

	var il_panel := StyleBoxFlat.new()
	il_panel.bg_color = Color(0.10, 0.11, 0.15, 1.0)
	il_panel.corner_radius_top_left = 10
	il_panel.corner_radius_top_right = 10
	il_panel.corner_radius_bottom_right = 10
	il_panel.corner_radius_bottom_left = 10
	il_panel.border_color = Color(1, 1, 1, 0.14)
	il_panel.border_width_left = 1
	il_panel.border_width_right = 1
	il_panel.border_width_top = 1
	il_panel.border_width_bottom = 1
	var il_hovered := il_panel.duplicate()
	il_hovered.bg_color = il_panel.bg_color.lightened(0.04)
	var il_selected := il_panel.duplicate()
	il_selected.bg_color = Color(0.18, 0.20, 0.26, 1.0)
	il_selected.border_color = blue
	il_selected.border_width_left = 2
	il_selected.border_width_right = 2
	il_selected.border_width_top = 2
	il_selected.border_width_bottom = 2
	var il_selected_focus := il_selected.duplicate()
	var il_cursor := StyleBoxFlat.new()
	il_cursor.bg_color = Color(1, 1, 1, 0.08)
	il_cursor.corner_radius_top_left = 6
	il_cursor.corner_radius_top_right = 6
	il_cursor.corner_radius_bottom_right = 6
	il_cursor.corner_radius_bottom_left = 6
	theme.set_stylebox("panel", "ItemList", il_panel)
	theme.set_stylebox("hovered", "ItemList", il_hovered)
	theme.set_stylebox("selected", "ItemList", il_selected)
	theme.set_stylebox("selected_focus", "ItemList", il_selected_focus)
	theme.set_stylebox("cursor", "ItemList", il_cursor)
	theme.set_stylebox("cursor_unfocused", "ItemList", il_cursor)
	theme.set_color("font_color", "ItemList", Color(0.92, 0.94, 0.98, 1.0))
	theme.set_color("font_hovered_color", "ItemList", Color.WHITE)
	theme.set_color("font_selected_color", "ItemList", Color.WHITE)
	theme.set_color("font_hovered_selected_color", "ItemList", Color.WHITE)

	var cb_normal := _make_button_box(transparent, Color(0, 0, 0, 0), true, 0)
	cb_normal.content_margin_left = 8
	cb_normal.content_margin_right = 8
	cb_normal.content_margin_top = 4
	cb_normal.content_margin_bottom = 4
	var cb_hover := cb_normal.duplicate()
	cb_hover.bg_color = Color(1, 1, 1, 0.06)
	var cb_pressed := cb_normal.duplicate()
	cb_pressed.bg_color = Color(1, 1, 1, 0.1)
	var cb_disabled := cb_normal.duplicate()
	cb_disabled.bg_color = Color(1, 1, 1, 0.02)
	var cb_focus := cb_normal.duplicate()
	cb_focus.border_color = blue
	cb_focus.border_width_left = 2
	cb_focus.border_width_right = 2
	cb_focus.border_width_top = 2
	cb_focus.border_width_bottom = 2
	theme.set_stylebox("normal", "CheckBox", cb_normal)
	theme.set_stylebox("hover", "CheckBox", cb_hover)
	theme.set_stylebox("pressed", "CheckBox", cb_pressed)
	theme.set_stylebox("disabled", "CheckBox", cb_disabled)
	theme.set_stylebox("focus", "CheckBox", cb_focus)
	theme.set_color("font_color", "CheckBox", text)
	theme.set_color("font_hover_color", "CheckBox", text)
	theme.set_color("font_pressed_color", "CheckBox", text)
	theme.set_color("font_disabled_color", "CheckBox", text.darkened(0.5))
	theme.set_color("checkbox_checked_color", "CheckBox", blue)
	theme.set_color("checkbox_unchecked_color", "CheckBox", Color(0.75, 0.80, 0.90, 1.0))

	theme.set_type_variation("ShopCurrencyLabel", "Label")
	theme.set_color("font_color", "ShopCurrencyLabel", Color(0.82, 0.92, 1.0, 1.0))
	theme.set_color("font_outline_color", "ShopCurrencyLabel", Color(0, 0, 0, 0.6))
	theme.set_constant("outline_size", "ShopCurrencyLabel", 1)

	var cat_bg := Color(0.12, 0.13, 0.17, 1.0)
	var cat_border := Color(1, 1, 1, 0.16)
	var cat_base := _make_button_box(cat_bg, cat_border, true, 1)
	var cat_base_hover := _make_button_box(cat_bg.lightened(0.06), cat_border.lightened(0.1), true, 1)
	var cat_base_pressed := _make_button_box(cat_bg.darkened(0.06), cat_border.darkened(0.1), true, 1)
	var cat_base_focus := _make_button_box(cat_bg, blue, true, 2)

	theme.set_type_variation("CategoryAll", "Button")
	theme.set_stylebox("normal", "CategoryAll", cat_base)
	theme.set_stylebox("hover", "CategoryAll", cat_base_hover)
	theme.set_stylebox("pressed", "CategoryAll", cat_base_pressed)
	theme.set_stylebox("focus", "CategoryAll", cat_base_focus)
	theme.set_color("font_color", "CategoryAll", blue)
	theme.set_color("font_hover_color", "CategoryAll", blue.lightened(0.08))
	theme.set_color("font_pressed_color", "CategoryAll", blue.darkened(0.08))
	theme.set_color("font_disabled_color", "CategoryAll", blue.darkened(0.4))

	var col_all := blue
	var col_kick := theme.get_color("accent_teal", "Palette")
	var col_snare := theme.get_color("accent_purple", "Palette")
	var col_cover := theme.get_color("accent_pink", "Palette")
	var col_notes := theme.get_color("accent_sky", "Palette")
	var col_lane := theme.get_color("accent_mint", "Palette")
	var col_misc := theme.get_color("accent_slate", "Palette")

	theme.set_type_variation("CategoryKick", "Button")
	theme.set_stylebox("normal", "CategoryKick", cat_base)
	theme.set_stylebox("hover", "CategoryKick", cat_base_hover)
	theme.set_stylebox("pressed", "CategoryKick", cat_base_pressed)
	theme.set_stylebox("focus", "CategoryKick", cat_base_focus)
	theme.set_color("font_color", "CategoryKick", col_kick)
	theme.set_color("font_hover_color", "CategoryKick", col_kick.lightened(0.08))
	theme.set_color("font_pressed_color", "CategoryKick", col_kick.darkened(0.08))
	theme.set_color("font_disabled_color", "CategoryKick", col_kick.darkened(0.4))

	theme.set_type_variation("CategorySnare", "Button")
	theme.set_stylebox("normal", "CategorySnare", cat_base)
	theme.set_stylebox("hover", "CategorySnare", cat_base_hover)
	theme.set_stylebox("pressed", "CategorySnare", cat_base_pressed)
	theme.set_stylebox("focus", "CategorySnare", cat_base_focus)
	theme.set_color("font_color", "CategorySnare", col_snare)
	theme.set_color("font_hover_color", "CategorySnare", col_snare.lightened(0.08))
	theme.set_color("font_pressed_color", "CategorySnare", col_snare.darkened(0.08))
	theme.set_color("font_disabled_color", "CategorySnare", col_snare.darkened(0.4))

	theme.set_type_variation("CategoryCover", "Button")
	theme.set_stylebox("normal", "CategoryCover", cat_base)
	theme.set_stylebox("hover", "CategoryCover", cat_base_hover)
	theme.set_stylebox("pressed", "CategoryCover", cat_base_pressed)
	theme.set_stylebox("focus", "CategoryCover", cat_base_focus)
	theme.set_color("font_color", "CategoryCover", col_cover)
	theme.set_color("font_hover_color", "CategoryCover", col_cover.lightened(0.08))
	theme.set_color("font_pressed_color", "CategoryCover", col_cover.darkened(0.08))
	theme.set_color("font_disabled_color", "CategoryCover", col_cover.darkened(0.4))

	theme.set_type_variation("CategoryNotes", "Button")
	theme.set_stylebox("normal", "CategoryNotes", cat_base)
	theme.set_stylebox("hover", "CategoryNotes", cat_base_hover)
	theme.set_stylebox("pressed", "CategoryNotes", cat_base_pressed)
	theme.set_stylebox("focus", "CategoryNotes", cat_base_focus)
	theme.set_color("font_color", "CategoryNotes", col_notes)
	theme.set_color("font_hover_color", "CategoryNotes", col_notes.lightened(0.08))
	theme.set_color("font_pressed_color", "CategoryNotes", col_notes.darkened(0.08))
	theme.set_color("font_disabled_color", "CategoryNotes", col_notes.darkened(0.4))

	theme.set_type_variation("CategoryLane", "Button")
	theme.set_stylebox("normal", "CategoryLane", cat_base)
	theme.set_stylebox("hover", "CategoryLane", cat_base_hover)
	theme.set_stylebox("pressed", "CategoryLane", cat_base_pressed)
	theme.set_stylebox("focus", "CategoryLane", cat_base_focus)
	theme.set_color("font_color", "CategoryLane", col_lane)
	theme.set_color("font_hover_color", "CategoryLane", col_lane.lightened(0.08))
	theme.set_color("font_pressed_color", "CategoryLane", col_lane.darkened(0.08))
	theme.set_color("font_disabled_color", "CategoryLane", col_lane.darkened(0.4))

	theme.set_type_variation("CategoryMisc", "Button")
	theme.set_stylebox("normal", "CategoryMisc", cat_base)
	theme.set_stylebox("hover", "CategoryMisc", cat_base_hover)
	theme.set_stylebox("pressed", "CategoryMisc", cat_base_pressed)
	theme.set_stylebox("focus", "CategoryMisc", cat_base_focus)
	theme.set_color("font_color", "CategoryMisc", col_misc)
	theme.set_color("font_hover_color", "CategoryMisc", col_misc.lightened(0.08))
	theme.set_color("font_pressed_color", "CategoryMisc", col_misc.darkened(0.08))
	theme.set_color("font_disabled_color", "CategoryMisc", col_misc.darkened(0.4))

	var act := cat_base.duplicate()
	act.bg_color = cat_bg.lightened(0.10)
	act.border_color = blue
	act.border_width_left = 2
	act.border_width_right = 2
	act.border_width_top = 2
	act.border_width_bottom = 2

	theme.set_type_variation("ActiveAll", "Button")
	theme.set_stylebox("normal", "ActiveAll", act)
	theme.set_stylebox("hover", "ActiveAll", act)
	theme.set_stylebox("pressed", "ActiveAll", act)
	theme.set_stylebox("focus", "ActiveAll", act)
	theme.set_color("font_color", "ActiveAll", blue.lightened(0.16))
	theme.set_color("font_hover_color", "ActiveAll", blue.lightened(0.16))
	theme.set_color("font_pressed_color", "ActiveAll", blue.lightened(0.16))
	theme.set_color("font_disabled_color", "ActiveAll", blue.darkened(0.4))

	theme.set_type_variation("ActiveKick", "Button")
	theme.set_stylebox("normal", "ActiveKick", act)
	theme.set_stylebox("hover", "ActiveKick", act)
	theme.set_stylebox("pressed", "ActiveKick", act)
	theme.set_stylebox("focus", "ActiveKick", act)
	theme.set_color("font_color", "ActiveKick", col_kick.lightened(0.16))
	theme.set_color("font_hover_color", "ActiveKick", col_kick.lightened(0.16))
	theme.set_color("font_pressed_color", "ActiveKick", col_kick.lightened(0.16))
	theme.set_color("font_disabled_color", "ActiveKick", col_kick.darkened(0.4))

	theme.set_type_variation("ActiveSnare", "Button")
	theme.set_stylebox("normal", "ActiveSnare", act)
	theme.set_stylebox("hover", "ActiveSnare", act)
	theme.set_stylebox("pressed", "ActiveSnare", act)
	theme.set_stylebox("focus", "ActiveSnare", act)
	theme.set_color("font_color", "ActiveSnare", col_snare.lightened(0.16))
	theme.set_color("font_hover_color", "ActiveSnare", col_snare.lightened(0.16))
	theme.set_color("font_pressed_color", "ActiveSnare", col_snare.lightened(0.16))
	theme.set_color("font_disabled_color", "ActiveSnare", col_snare.darkened(0.4))

	theme.set_type_variation("ActiveCover", "Button")
	theme.set_stylebox("normal", "ActiveCover", act)
	theme.set_stylebox("hover", "ActiveCover", act)
	theme.set_stylebox("pressed", "ActiveCover", act)
	theme.set_stylebox("focus", "ActiveCover", act)
	theme.set_color("font_color", "ActiveCover", col_cover.lightened(0.16))
	theme.set_color("font_hover_color", "ActiveCover", col_cover.lightened(0.16))
	theme.set_color("font_pressed_color", "ActiveCover", col_cover.lightened(0.16))
	theme.set_color("font_disabled_color", "ActiveCover", col_cover.darkened(0.4))

	theme.set_type_variation("ActiveNotes", "Button")
	theme.set_stylebox("normal", "ActiveNotes", act)
	theme.set_stylebox("hover", "ActiveNotes", act)
	theme.set_stylebox("pressed", "ActiveNotes", act)
	theme.set_stylebox("focus", "ActiveNotes", act)
	theme.set_color("font_color", "ActiveNotes", col_notes.lightened(0.16))
	theme.set_color("font_hover_color", "ActiveNotes", col_notes.lightened(0.16))
	theme.set_color("font_pressed_color", "ActiveNotes", col_notes.lightened(0.16))
	theme.set_color("font_disabled_color", "ActiveNotes", col_notes.darkened(0.4))

	theme.set_type_variation("ActiveLane", "Button")
	theme.set_stylebox("normal", "ActiveLane", act)
	theme.set_stylebox("hover", "ActiveLane", act)
	theme.set_stylebox("pressed", "ActiveLane", act)
	theme.set_stylebox("focus", "ActiveLane", act)
	theme.set_color("font_color", "ActiveLane", col_lane.lightened(0.16))
	theme.set_color("font_hover_color", "ActiveLane", col_lane.lightened(0.16))
	theme.set_color("font_pressed_color", "ActiveLane", col_lane.lightened(0.16))
	theme.set_color("font_disabled_color", "ActiveLane", col_lane.darkened(0.4))

	theme.set_type_variation("ActiveMisc", "Button")
	theme.set_stylebox("normal", "ActiveMisc", act)
	theme.set_stylebox("hover", "ActiveMisc", act)
	theme.set_stylebox("pressed", "ActiveMisc", act)
	theme.set_stylebox("focus", "ActiveMisc", act)
	theme.set_color("font_color", "ActiveMisc", col_misc.lightened(0.16))
	theme.set_color("font_hover_color", "ActiveMisc", col_misc.lightened(0.16))
	theme.set_color("font_pressed_color", "ActiveMisc", col_misc.lightened(0.16))
	theme.set_color("font_disabled_color", "ActiveMisc", col_misc.darkened(0.4))

	theme.set_type_variation("DailyTasksPanel", "PanelContainer")
	var dt_panel := card_base.duplicate()
	dt_panel.bg_color = theme.get_color("panel_bg", "Palette").darkened(0.02)
	dt_panel.border_color = Color(1, 1, 1, 0.12)
	dt_panel.shadow_size = 0
	dt_panel.shadow_offset = Vector2(0, 0)
	theme.set_stylebox("panel", "DailyTasksPanel", dt_panel)

	theme.set_type_variation("DailyTasksCard", "PanelContainer")
	var dt_card := card_base.duplicate()
	dt_card.bg_color = theme.get_color("panel_bg", "Palette").darkened(0.01)
	dt_card.border_color = Color(1, 1, 1, 0.12)
	dt_card.shadow_color = Color(0, 0, 0, 0.25)
	dt_card.shadow_size = 4
	dt_card.shadow_offset = Vector2(0, 2)
	theme.set_stylebox("panel", "DailyTasksCard", dt_card)

	theme.set_type_variation("DailyTasksHeader", "Label")
	theme.set_color("font_color", "DailyTasksHeader", theme.get_color("text", "Palette"))

	theme.set_type_variation("DailyTasksTitle", "Label")
	theme.set_color("font_color", "DailyTasksTitle", theme.get_color("text", "Palette"))

	theme.set_type_variation("DailyTasksDescription", "Label")
	theme.set_color("font_color", "DailyTasksDescription", theme.get_color("text_muted", "Palette"))

	theme.set_type_variation("DailyTasksProgressBar", "ProgressBar")
	var dt_pb_bg := pb_bg.duplicate()
	var dt_pb_fill := pb_fill.duplicate()
	dt_pb_fill.bg_color = theme.get_color("accent_teal", "Palette")
	theme.set_stylebox("background", "DailyTasksProgressBar", dt_pb_bg)
	theme.set_stylebox("fill", "DailyTasksProgressBar", dt_pb_fill)
	theme.set_color("font_color", "DailyTasksProgressBar", Color.WHITE)
	theme.set_constant("outline_size", "DailyTasksProgressBar", 0)

	return theme
