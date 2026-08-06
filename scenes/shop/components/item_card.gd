# scenes/shop/components/item_card.gd
extends PanelContainer

signal buy_pressed(item_id: String)
signal medal_buy_pressed(item_id: String)
signal use_pressed(item_id: String)
signal preview_pressed(item_id: String)

@export var item_data: Dictionary = {}

const _AchievementLocale = preload("res://logic/i18n/achievement_locale.gd")
const _UiRoundedClip = preload("res://logic/ui/ui_rounded_clip.gd")
const _PREVIEW_CORNER_RADIUS := 10.0

var is_purchased: bool = false
var is_active: bool = false
var is_default: bool = false

var is_achievement_reward: bool = false
var achievement_required: String = ""
var achievement_name: String = "" 
var achievement_unlocked: bool = false

var is_level_reward: bool = false
var required_level: int = 0
var level_unlocked: bool = false
var is_daily_reward: bool = false
var required_daily_completed: int = 0
var daily_unlocked: bool = false
var is_medal_reward: bool = false
var medal_price: int = 0
var medal_unlocked: bool = false
var is_new_reward: bool = false
const NEW_REWARD_BORDER_COLOR := Color("#F2B35A")
const _PREVIEW_IMAGE_SIZE := Vector2(240, 180)

static var _reward_shell: StyleBoxFlat
static var _preview_frames: Dictionary = {}
static var _shell_styles: Dictionary = {}
static var _color_textures: Dictionary = {}
static var _note_textures: Dictionary = {}

const _ShopItemLocale = preload("res://logic/i18n/shop_item_locale.gd")
const _HitParticlePresets = preload("res://logic/domain/rhythm/hit_particle_presets.gd")
const _UiMotionEffects = preload("res://logic/ui/ui_motion_effects.gd")
const _KickPreviewFx = preload("res://scenes/shop/components/kick_preview_fx.gd")
const _ParticleShopPreviewFx = preload("res://scenes/shop/components/particle_shop_preview_fx.gd")

const _ACCENT_BY_CATEGORY := {
	"Кик": Color(0.38, 0.78, 0.74),
	"Ноты": Color(0.52, 0.76, 0.92),
	"Подсветка линий": Color(0.62, 0.86, 0.72),
	"Частицы хита": Color(0.92, 0.68, 0.32),
	"Все": Color(0.42, 0.57, 0.82),
}
var _achievements_data_cache = null
var _loader: ThreadedTextureLoader = null
var _loader_connected: bool = false
var _current_image_path: String = ""
var _kick_preview_fx: Control = null
var _particle_preview_fx: Node2D = null
var _preview_fx_ready := false

@onready var _card_anim: AnimationPlayer = get_node_or_null("CardAnim")

func apply_locale() -> void:
	if not is_node_ready():
		return
	var name_label := get_node_or_null("MarginContainer/ContentContainer/NameLabel") as Label
	if name_label:
		_set_name_label(name_label)
	var open_button := _get_open_reward_button()
	if open_button:
		open_button.text = tr("SHOP_OPEN")
	_update_buttons_and_status()


func _ready():
	if not item_data.has("item_id"):
		visible = false
		queue_free()
		return

	custom_minimum_size = Vector2(280, 350)
	_update_card_pivot()
	if not resized.is_connected(_update_card_pivot):
		resized.connect(_update_card_pivot)
	if not visibility_changed.is_connected(_on_visibility_changed):
		visibility_changed.connect(_on_visibility_changed)
	_finish_shop_setup()


func _finish_shop_setup() -> void:
	_apply_card_text_layout()
	_setup_item()
	_update_new_reward_visuals()

func _apply_card_text_layout() -> void:
	var content := get_node_or_null("MarginContainer/ContentContainer") as VBoxContainer
	if content == null:
		return
	var name_label := content.get_node_or_null("NameLabel") as Label
	if name_label:
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var buttons_container := content.get_node_or_null("ButtonsContainer") as VBoxContainer
	if buttons_container:
		buttons_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var top_row := buttons_container.get_node_or_null("TopButtonContainer") as HBoxContainer if buttons_container else null
	if top_row:
		top_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		top_row.alignment = BoxContainer.ALIGNMENT_CENTER
	for child in top_row.get_children() if top_row else []:
		if child is Button:
			child.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			child.alignment = HORIZONTAL_ALIGNMENT_CENTER
	var preview_button := buttons_container.get_node_or_null("PreviewButton") as Button if buttons_container else null
	if preview_button:
		preview_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		preview_button.alignment = HORIZONTAL_ALIGNMENT_CENTER


func set_new_reward_highlight(enabled: bool) -> void:
	is_new_reward = enabled
	if is_node_ready():
		_update_new_reward_visuals()

func _get_use_button() -> Button:
	return get_node_or_null("MarginContainer/ContentContainer/ButtonsContainer/TopButtonContainer/UseButton") as Button

func _get_open_reward_button() -> Button:
	return get_node_or_null("MarginContainer/ContentContainer/ButtonsContainer/TopButtonContainer/OpenRewardButton") as Button

func _is_reward_type_item() -> bool:
	return is_achievement_reward or is_level_reward or is_daily_reward or is_medal_reward

func _is_medal_reward_item() -> bool:
	return int(item_data.get("medal_price", 0)) > 0

func _is_reward_unlocked_and_usable() -> bool:
	if is_medal_reward:
		return medal_unlocked and not is_purchased
	if is_level_reward:
		return level_unlocked
	if is_achievement_reward:
		return achievement_unlocked
	if is_daily_reward:
		return daily_unlocked
	return false

func _should_show_open_button() -> bool:
	return is_new_reward and _is_reward_type_item() and _is_reward_unlocked_and_usable() and not is_active

func _update_new_reward_visuals() -> void:
	_apply_open_reward_button_state()
	if is_node_ready():
		_apply_card_style()

func _apply_open_reward_button_state() -> void:
	var use_button := _get_use_button()
	var open_button := _get_open_reward_button()
	if open_button == null:
		return
	if _should_show_open_button():
		open_button.visible = true
		open_button.text = tr("SHOP_OPEN")
		if use_button:
			use_button.visible = false
	else:
		open_button.visible = false

func _maybe_mark_new_reward_seen() -> void:
	if not is_new_reward:
		return
	var item_id := str(item_data.get("item_id", ""))
	if item_id == "":
		return
	PlayerDataManager.mark_shop_reward_seen(item_id)
	set_new_reward_highlight(false)
	_update_buttons_and_status()

func _update_card_pivot() -> void:
	pivot_offset = size * 0.5

func _play_card_anim(anim_name: String) -> void:
	if _card_anim and _card_anim.has_animation(anim_name):
		_update_card_pivot()
		_card_anim.stop()
		_card_anim.play(anim_name)


func _on_image_rect_gui_input(event: InputEvent):
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		var category := str(item_data.get("category", ""))
		if category == "Частицы хита":
			play_particle_preview_fx()


func _setup_item():
	if not item_data.has("item_id"):
		return

	var item_id_str = item_data.get("item_id", "") 
	is_default = item_data.get("is_default", false)

	is_achievement_reward = item_data.get("is_achievement_reward", false)
	achievement_required = item_data.get("achievement_required", "")
	
	is_level_reward = item_data.get("is_level_reward", false)
	required_level = item_data.get("required_level", 0)
	is_daily_reward = item_data.get("is_daily_reward", false)
	required_daily_completed = item_data.get("required_daily_completed", 0)
	is_medal_reward = _is_medal_reward_item()
	medal_price = int(item_data.get("medal_price", 0))
	if is_medal_reward:
		medal_unlocked = PlayerDataManager.get_total_medals_earned() >= medal_price

	var image_rect = $MarginContainer/ContentContainer/ImageWrapper/ImageRect
	var name_label = $MarginContainer/ContentContainer/NameLabel
	var status_hbox = get_node_or_null("MarginContainer/ContentContainer/StatusDefaultHBox")
	var status_label = get_node_or_null("MarginContainer/ContentContainer/StatusDefaultHBox/StatusLabel")

	if status_hbox:
		status_hbox.visible = false

	_apply_initial_image()

	if image_rect:
		image_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		var category := str(item_data.get("category", ""))
		if category == "Кик":
			_update_kick_preview_image_visibility()
		else:
			image_rect.visible = true
			image_rect.modulate.a = 1.0
		if item_data.get("category", "") == "Частицы хита":
			image_rect.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		else:
			image_rect.mouse_default_cursor_shape = Control.CURSOR_ARROW

	if name_label:
		_set_name_label(name_label)

	_update_buttons_and_status()


func _update_preview_button(preview_button):
	var category := str(item_data.get("category", ""))
	var audio_path := str(item_data.get("audio", ""))
	if category == "Частицы хита":
		preview_button.visible = false
		return
	preview_button.visible = audio_path != ""
	if preview_button.visible:
		preview_button.text = tr("SHOP_PREVIEW")


func ensure_preview_fx() -> void:
	if _preview_fx_ready:
		return
	if not is_node_ready() or not is_inside_tree() or not visible:
		call_deferred("ensure_preview_fx")
		return
	var category := str(item_data.get("category", ""))
	if category == "Кик":
		_ensure_kick_preview_fx()
		_update_kick_preview_image_visibility()
		if SettingsManager and SettingsManager.get_shop_kick_waveform_preview():
			var audio_path := str(item_data.get("audio", ""))
			if audio_path == "" or not FileAccess.file_exists(audio_path):
				_preview_fx_ready = true
				return
			if _kick_preview_fx != null and _kick_preview_fx.has_method("has_waveform_data"):
				_preview_fx_ready = true
				return
			return
	_ensure_particle_preview_fx()
	_preview_fx_ready = true


func _on_visibility_changed() -> void:
	if visible:
		call_deferred("refresh_shop_preview")


func refresh_shop_preview() -> void:
	if not visible or not is_inside_tree():
		return
	_apply_preview_frame()
	var category := str(item_data.get("category", ""))
	var image_rect := get_node_or_null("MarginContainer/ContentContainer/ImageWrapper/ImageRect") as TextureRect
	if image_rect:
		image_rect.queue_redraw()
	if category == "Частицы хита":
		_preview_fx_ready = false
		ensure_preview_fx()
		_update_particle_preview_position()
		if _particle_preview_fx:
			_particle_preview_fx.queue_redraw()
	elif category == "Кик":
		_update_kick_preview_image_visibility()
		if _kick_preview_fx:
			_kick_preview_fx.queue_redraw()


func _request_threaded_load(path: String) -> void:
	_current_image_path = path
	if _loader == null:
		var loader_script = preload("res://logic/platform/threaded_texture_loader.gd")
		_loader = loader_script.get_instance()
	if _loader and not _loader_connected:
		_loader.loaded.connect(_on_loader_loaded)
		_loader_connected = true
	if _loader:
		_loader.request(path)

func _process(delta):
	pass

func _get_achievements_data():
	var user_path = "user://achievements_data.json"
	var path = user_path if FileAccess.file_exists(user_path) else "res://data/achievements_data.json"
	if _achievements_data_cache != null:
		return _achievements_data_cache
	if not FileAccess.file_exists(path):
		return null
	var file = FileAccess.open(path, FileAccess.READ)
	if not file:
		return null
	var text = file.get_as_text()
	file.close()
	var parsed = JSON.parse_string(text)
	if not (parsed and parsed.has("achievements")):
		return null
	_achievements_data_cache = parsed.achievements
	return _achievements_data_cache


func _is_valid_color_hex(hex: String) -> bool:
	var s := str(hex).strip_edges()
	return s.length() >= 4 and s.begins_with("#")


func _safe_color(hex: String, fallback: Color = Color(0.5, 0.5, 0.5, 1.0)) -> Color:
	if not _is_valid_color_hex(hex):
		return fallback
	return Color(hex)


func _create_color_texture(color: Color) -> Texture2D:
	var key := color.to_html(false)
	if _color_textures.has(key):
		return _color_textures[key]
	var image = Image.create(240, 180, false, Image.FORMAT_RGBA8)
	image.fill(color)
	var tex := ImageTexture.create_from_image(image)
	_color_textures[key] = tex
	return tex


func _create_note_preview_texture(colors: Array) -> Texture2D:
	var key := "|".join(colors)
	if _note_textures.has(key):
		return _note_textures[key]
	var width = 240
	var height = 180
	var image = Image.create(width, height, false, Image.FORMAT_RGBA8)
	
	if colors.size() == 1:
		image.fill(_safe_color(str(colors[0])))
	elif colors.size() == 5:
		var stripe_width = width / 5
		for i in range(5):
			var color := _safe_color(str(colors[i]))
			var rect = Rect2i(i * stripe_width, 0, stripe_width, height)
			image.fill_rect(rect, color)
	else:
		image.fill(Color(0.5, 0.5, 0.5, 1.0))
	var tex := ImageTexture.create_from_image(image)
	_note_textures[key] = tex
	return tex



func _create_placeholder_with_text():
	var image_rect = $MarginContainer/ContentContainer/ImageWrapper/ImageRect
	if image_rect:
		var category = item_data.get("category", "")
		var color_hex = item_data.get("color_hex", "")
		var note_colors = item_data.get("note_colors", [])
		
		if category == "Подсветка линий" and _is_valid_color_hex(color_hex):
			var hex_color := Color(color_hex)
			var color_texture = _create_color_texture(hex_color)
			image_rect.texture = color_texture
		elif category == "Ноты" and not note_colors.is_empty():
			var texture = _create_note_preview_texture(note_colors)
			image_rect.texture = texture
		elif category == "Частицы хита":
			var preset: Variant = item_data.get("particle_preset", {})
			if preset is Dictionary:
				image_rect.texture = _HitParticlePresets.create_preview_texture(preset)
		else:
			pass


func _update_buttons_and_status():
	var buy_button = $MarginContainer/ContentContainer/ButtonsContainer/TopButtonContainer/BuyButton
	var achievement_button = $MarginContainer/ContentContainer/ButtonsContainer/TopButtonContainer/AchievementRewardButton 
	var level_reward_button = $MarginContainer/ContentContainer/ButtonsContainer/TopButtonContainer/LevelRewardButton 
	var daily_reward_button = $MarginContainer/ContentContainer/ButtonsContainer/TopButtonContainer/DailyRewardButton
	var medal_buy_button = get_node_or_null("MarginContainer/ContentContainer/ButtonsContainer/TopButtonContainer/MedalBuyButton") as Button
	var use_button = $MarginContainer/ContentContainer/ButtonsContainer/TopButtonContainer/UseButton
	var preview_button = $MarginContainer/ContentContainer/ButtonsContainer/PreviewButton
	var status_hbox = get_node_or_null("MarginContainer/ContentContainer/StatusDefaultHBox")
	var status_label = get_node_or_null("MarginContainer/ContentContainer/StatusDefaultHBox/StatusLabel")
	
	if achievement_button:
		achievement_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		achievement_button.size_flags_stretch_ratio = 1
	if level_reward_button:
		level_reward_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		level_reward_button.size_flags_stretch_ratio = 1
	if daily_reward_button:
		daily_reward_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		daily_reward_button.size_flags_stretch_ratio = 1

	if is_level_reward:
		buy_button.visible = false
		if medal_buy_button:
			medal_buy_button.visible = false
		achievement_button.visible = false
		if daily_reward_button:
			daily_reward_button.visible = false
		_update_preview_button(preview_button)

		if level_unlocked:
			level_reward_button.visible = false
			_set_use_button(use_button, not is_active)
			_set_status(status_hbox, status_label, is_active, tr("SHOP_IN_USE"))
		else:
			level_reward_button.visible = true
			level_reward_button.text = tr("SHOP_LEVEL_BTN") % required_level
			level_reward_button.disabled = true 
			if level_reward_button:
				var current_level = PlayerDataManager.get_current_level()
				level_reward_button.tooltip_text = tr("SHOP_LEVEL_TOOLTIP") % [current_level, required_level]
			_set_use_button(use_button, false)
			_set_status(status_hbox, status_label, false, "")

	elif is_achievement_reward:
		buy_button.visible = false
		if medal_buy_button:
			medal_buy_button.visible = false
		level_reward_button.visible = false  
		if daily_reward_button:
			daily_reward_button.visible = false
		_update_preview_button(preview_button)

		if achievement_unlocked:
			achievement_button.visible = false
			if achievement_button:
				achievement_button.tooltip_text = ""
			_set_use_button(use_button, not is_active)
			_set_status(status_hbox, status_label, is_active, tr("SHOP_IN_USE"))
		else:
			achievement_button.visible = true
			var display_name = achievement_name if achievement_name != "" else tr("SHOP_ACH_REWARD")
			achievement_button.text = display_name 
			achievement_button.disabled = true 
			if achievement_button:
				var ach_desc = _get_achievement_description_by_id(achievement_required)
				var prog = _get_achievement_progress_by_id(achievement_required)
				var cur = int(prog.get("current", 0))
				var tot = int(prog.get("total", 0))
				if ach_desc == "":
					ach_desc = tr("SHOP_ACH_DESC")
				if tot > 0:
					achievement_button.tooltip_text = "%s (%d/%d)" % [ach_desc, cur, tot]
				else:
					achievement_button.tooltip_text = ach_desc
			_set_use_button(use_button, false)
			_set_status(status_hbox, status_label, false, "")
	elif is_daily_reward:
		buy_button.visible = false
		if medal_buy_button:
			medal_buy_button.visible = false
		level_reward_button.visible = false
		achievement_button.visible = false
		_update_preview_button(preview_button)
		if daily_unlocked:
			if daily_reward_button:
				daily_reward_button.visible = false
				daily_reward_button.tooltip_text = ""
			_set_use_button(use_button, not is_active)
			_set_status(status_hbox, status_label, is_active, tr("SHOP_IN_USE"))
		else:
			if daily_reward_button:
				daily_reward_button.visible = true
				daily_reward_button.text = tr("SHOP_DAILY_BTN") % required_daily_completed
				daily_reward_button.disabled = true
				var completed = PlayerDataManager.get_daily_quests_completed_total()
				daily_reward_button.tooltip_text = tr("SHOP_DAILY_TOOLTIP") % [completed, required_daily_completed]
			_set_use_button(use_button, false)
			_set_status(status_hbox, status_label, false, "")
	elif is_medal_reward:
		buy_button.visible = false
		achievement_button.visible = false
		level_reward_button.visible = false
		if daily_reward_button:
			daily_reward_button.visible = false
		_update_preview_button(preview_button)

		if is_purchased:
			if medal_buy_button:
				medal_buy_button.visible = false
				medal_buy_button.tooltip_text = ""
			_set_use_button(use_button, not is_active)
			_set_status(status_hbox, status_label, is_active, tr("SHOP_IN_USE"))
		elif medal_unlocked:
			if medal_buy_button:
				medal_buy_button.visible = false
				medal_buy_button.tooltip_text = ""
			_set_use_button(use_button, false)
			_set_status(status_hbox, status_label, false, "")
		else:
			if medal_buy_button:
				medal_buy_button.visible = true
				medal_buy_button.disabled = true
				medal_buy_button.text = tr("SHOP_BUY_MEDALS") % medal_price
				var collected := PlayerDataManager.get_total_medals_earned()
				medal_buy_button.tooltip_text = tr("SHOP_MEDALS_TOOLTIP") % [collected, medal_price]
			_set_use_button(use_button, false)
			_set_status(status_hbox, status_label, false, "")
	else:
		achievement_button.visible = false
		level_reward_button.visible = false
		if daily_reward_button:
			daily_reward_button.visible = false
		if medal_buy_button:
			medal_buy_button.visible = false
		buy_button.visible = not is_purchased and not is_default
		if buy_button.visible:
			var price = item_data.get("price", 0)
			buy_button.text = tr("SHOP_BUY") % price

		var show_use_button = (is_purchased and not is_active) or (is_default and not is_active)
		_set_use_button(use_button, show_use_button)
		_update_preview_button(preview_button)

		if is_active:
			_set_status(status_hbox, status_label, true, tr("SHOP_IN_USE"))
		elif is_default:
			_set_status(status_hbox, status_label, true, tr("SHOP_DEFAULT"))
		else:
			_set_status(status_hbox, status_label, false, "")

	_apply_open_reward_button_state()
	_update_new_reward_visuals()


func _is_locked_reward_state() -> bool:
	if is_level_reward:
		return not level_unlocked
	if is_achievement_reward:
		return not achievement_unlocked
	if is_daily_reward:
		return not daily_unlocked
	if is_medal_reward:
		return not is_purchased and not medal_unlocked
	return false


func _category_accent() -> Color:
	var category := str(item_data.get("category", ""))
	return _ACCENT_BY_CATEGORY.get(category, _ACCENT_BY_CATEGORY["Все"])


func _apply_card_style() -> void:
	if is_new_reward:
		_apply_preview_frame()
		if _reward_shell == null:
			_reward_shell = StyleBoxFlat.new()
			_reward_shell.bg_color = Color(1.0, 0.97, 0.88, 0.08)
			_reward_shell.border_color = NEW_REWARD_BORDER_COLOR
			_reward_shell.set_border_width_all(3)
			_reward_shell.set_corner_radius_all(12)
			_reward_shell.content_margin_left = 0.0
			_reward_shell.content_margin_top = 0.0
			_reward_shell.content_margin_right = 0.0
			_reward_shell.content_margin_bottom = 0.0
		add_theme_stylebox_override("panel", _reward_shell)
		_apply_status_label_style()
		_UiMotionEffects.pulse_panel_border(self, NEW_REWARD_BORDER_COLOR, 0.45, 0.95, 0.8)
		return
	var accent := _category_accent()
	var category := str(item_data.get("category", "Все"))
	if is_active:
		theme_type_variation = &"CardActive"
		add_theme_stylebox_override("panel", _cached_shell_style(category, accent, true))
	elif _is_locked_reward_state() and not is_purchased and not is_default:
		theme_type_variation = &"CardLocked"
		add_theme_stylebox_override("panel", _cached_shell_style(category, accent, false))
	else:
		theme_type_variation = &"CardDefault"
		add_theme_stylebox_override("panel", _cached_shell_style(category, accent, false))
	_apply_preview_frame()
	_apply_status_label_style()
	_UiMotionEffects.stop_panel_border_pulse(self)


func _cached_shell_style(category: String, accent: Color, active: bool) -> StyleBoxFlat:
	var key := "%s|%s" % [category, "1" if active else "0"]
	if _shell_styles.has(key):
		return _shell_styles[key]
	var shell := _build_card_shell_style(accent, active)
	_shell_styles[key] = shell
	return shell


func _build_card_shell_style(accent: Color, active: bool) -> StyleBoxFlat:
	var shell := StyleBoxFlat.new()
	shell.bg_color = Color(0.13, 0.15, 0.19) if active else Color(0.11, 0.12, 0.16)
	shell.border_color = accent.lightened(0.08 if active else 0.0)
	shell.set_border_width_all(3)
	shell.set_corner_radius_all(12)
	shell.shadow_color = Color(accent.r, accent.g, accent.b, 0.22 if active else 0.0)
	shell.shadow_size = 8 if active else 0
	shell.shadow_offset = Vector2(0, 3)
	if not active:
		shell.border_color.a = 0.0
	return shell


func _apply_preview_frame() -> void:
	var wrapper := get_node_or_null("MarginContainer/ContentContainer/ImageWrapper") as PanelContainer
	if wrapper == null:
		return
	var category := str(item_data.get("category", "Все"))
	if not _preview_frames.has(category):
		var accent_ref: Color = _ACCENT_BY_CATEGORY.get(category, _ACCENT_BY_CATEGORY["Все"])
		var frame := StyleBoxFlat.new()
		frame.bg_color = Color(0.05, 0.06, 0.09)
		frame.border_color = Color(accent_ref.r, accent_ref.g, accent_ref.b, 0.45)
		frame.border_width_top = 3
		frame.border_width_left = 1
		frame.border_width_right = 1
		frame.border_width_bottom = 1
		frame.set_corner_radius_all(10)
		frame.content_margin_left = 4.0
		frame.content_margin_top = 4.0
		frame.content_margin_right = 4.0
		frame.content_margin_bottom = 4.0
		_preview_frames[category] = frame
	wrapper.add_theme_stylebox_override("panel", _preview_frames[category])
	var image := wrapper.get_node_or_null("ImageRect") as TextureRect
	if image:
		image.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		_UiRoundedClip.apply_cover(wrapper, image, _PREVIEW_CORNER_RADIUS)


func _apply_status_label_style() -> void:
	var label := get_node_or_null("MarginContainer/ContentContainer/StatusDefaultHBox/StatusLabel") as Label
	var hbox := get_node_or_null("MarginContainer/ContentContainer/StatusDefaultHBox") as HBoxContainer
	if label == null or hbox == null or not hbox.visible:
		return
	if is_active:
		label.add_theme_color_override("font_color", Color(0.55, 0.92, 0.86))
		label.add_theme_color_override("font_outline_color", Color(0.12, 0.28, 0.24))
		label.add_theme_constant_override("outline_size", 4)
	elif is_default:
		label.add_theme_color_override("font_color", Color(0.72, 0.82, 0.96))
		label.add_theme_color_override("font_outline_color", Color(0.14, 0.2, 0.32))
		label.add_theme_constant_override("outline_size", 4)


func set_keyboard_selected(on: bool) -> void:
	modulate = Color(1.08, 1.1, 1.14, 1.0) if on else Color.WHITE


func activate_preview() -> bool:
	var preview_button := get_node_or_null(
		"MarginContainer/ContentContainer/ButtonsContainer/PreviewButton"
	) as Button
	if preview_button == null or not preview_button.visible or preview_button.disabled:
		return false
	_on_preview_pressed()
	return true


func activate_primary_action() -> bool:
	## Prefer Use when available, else Buy / medal buy / open reward.
	var use_button := get_node_or_null(
		"MarginContainer/ContentContainer/ButtonsContainer/TopButtonContainer/UseButton"
	) as Button
	if use_button and use_button.visible and not use_button.disabled:
		_on_use_pressed()
		return true
	var buy_button := get_node_or_null(
		"MarginContainer/ContentContainer/ButtonsContainer/TopButtonContainer/BuyButton"
	) as Button
	if buy_button and buy_button.visible and not buy_button.disabled:
		_on_buy_pressed()
		return true
	var medal_buy := get_node_or_null(
		"MarginContainer/ContentContainer/ButtonsContainer/TopButtonContainer/MedalBuyButton"
	) as Button
	if medal_buy and medal_buy.visible and not medal_buy.disabled:
		_on_medal_buy_pressed()
		return true
	var open_btn := _get_open_reward_button()
	if open_btn and open_btn.visible and not open_btn.disabled:
		_on_open_reward_pressed()
		return true
	return false


func _on_buy_pressed():
	var item_id_str = item_data.get("item_id", "")
	_play_card_anim("buy_pop")
	emit_signal("buy_pressed", item_id_str)


func get_purchase_fx_origin_global() -> Vector2:
	var btn := get_node_or_null(
		"MarginContainer/ContentContainer/ButtonsContainer/TopButtonContainer/BuyButton"
	) as Control
	if btn:
		return btn.get_global_rect().get_center()
	return get_global_rect().get_center()


func _on_medal_buy_pressed() -> void:
	var item_id_str := String(item_data.get("item_id", ""))
	_play_card_anim("buy_pop")
	emit_signal("medal_buy_pressed", item_id_str)


func _on_use_pressed():
	var item_id_str = item_data.get("item_id", "")
	_play_card_anim("buy_pop")
	emit_signal("use_pressed", item_id_str)

func _on_open_reward_pressed():
	if MusicManager and MusicManager.has_method("play_shop_open"):
		MusicManager.play_shop_open()
	if is_medal_reward and not is_purchased:
		_play_card_anim("buy_pop")
		emit_signal("medal_buy_pressed", String(item_data.get("item_id", "")))
		return
	_play_card_anim("buy_pop")
	_maybe_mark_new_reward_seen()

func _ensure_kick_preview_fx() -> void:
	if _kick_preview_fx != null:
		return
	if SettingsManager and not SettingsManager.get_shop_kick_waveform_preview():
		return
	if str(item_data.get("category", "")) != "Кик":
		return
	if str(item_data.get("audio", "")) == "":
		return
	var audio_path := str(item_data.get("audio", ""))
	if not FileAccess.file_exists(audio_path):
		return
	var slot := get_node_or_null("%KickPreviewSlot") as Control
	if slot == null:
		call_deferred("_ensure_kick_preview_fx")
		return
	_kick_preview_fx = _KickPreviewFx.new()
	_kick_preview_fx.name = "KickPreviewFx"
	_kick_preview_fx.set_anchors_preset(Control.PRESET_FULL_RECT)
	_kick_preview_fx.custom_minimum_size = _PREVIEW_IMAGE_SIZE
	_kick_preview_fx.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_kick_preview_fx.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_kick_preview_fx.mouse_filter = Control.MOUSE_FILTER_IGNORE
	slot.add_child(_kick_preview_fx)
	if not slot.resized.is_connected(_on_kick_preview_wrapper_resized):
		slot.resized.connect(_on_kick_preview_wrapper_resized)
	if _kick_preview_fx.has_method("set_audio_source"):
		_kick_preview_fx.set_audio_source(audio_path)
	_update_kick_preview_image_visibility()


func _on_kick_preview_wrapper_resized() -> void:
	if _kick_preview_fx:
		_kick_preview_fx.queue_redraw()


func _update_kick_preview_image_visibility() -> void:
	if str(item_data.get("category", "")) != "Кик":
		return
	var image_rect := get_node_or_null("MarginContainer/ContentContainer/ImageWrapper/ImageRect") as TextureRect
	if image_rect == null:
		return
	var has_waveform := false
	if _kick_preview_fx != null and _kick_preview_fx.has_method("has_waveform_data"):
		has_waveform = _kick_preview_fx.has_waveform_data()
	image_rect.visible = true
	image_rect.modulate.a = 0.0 if has_waveform else 1.0
	if _kick_preview_fx:
		_kick_preview_fx.visible = has_waveform
		_kick_preview_fx.queue_redraw()


func play_kick_preview_fx() -> void:
	var audio_path := str(item_data.get("audio", ""))
	if audio_path != "" and FileAccess.file_exists(audio_path):
		if MusicManager and MusicManager.has_method("play_custom_hit_sound"):
			MusicManager.play_custom_hit_sound(audio_path)
	if SettingsManager and not SettingsManager.get_shop_kick_waveform_preview():
		return
	ensure_preview_fx()
	if _kick_preview_fx == null:
		return
	if _kick_preview_fx.has_method("trigger"):
		_kick_preview_fx.trigger()


func _ensure_particle_preview_fx() -> void:
	if _particle_preview_fx != null:
		return
	if str(item_data.get("category", "")) != "Частицы хита":
		return
	var slot := get_node_or_null("%ParticlePreviewSlot") as Control
	if slot == null:
		return
	_particle_preview_fx = _ParticleShopPreviewFx.new()
	_particle_preview_fx.name = "ParticlePreviewFx"
	slot.resized.connect(_update_particle_preview_position)
	_update_particle_preview_position()
	slot.add_child(_particle_preview_fx)


func _update_particle_preview_position() -> void:
	if _particle_preview_fx == null:
		return
	var slot := get_node_or_null("%ParticlePreviewSlot") as Control
	if slot == null:
		return
	_particle_preview_fx.position = Vector2(slot.size.x * 0.5, slot.size.y * 0.62)


func play_particle_preview_fx() -> void:
	ensure_preview_fx()
	if _particle_preview_fx == null:
		return
	_update_particle_preview_position()
	var preset: Variant = item_data.get("particle_preset", {})
	if preset is Dictionary:
		_particle_preview_fx.burst(preset)


func _on_preview_pressed():
	var category := str(item_data.get("category", ""))
	if category == "Частицы хита":
		return
	if category == "Кик":
		play_kick_preview_fx()
		return
	var item_id_str := str(item_data.get("item_id", ""))
	emit_signal("preview_pressed", item_id_str)
	
func update_state(purchased: bool, active: bool, file_available: bool = true, achievement_unlocked_param: bool = false, achievement_name_param: String = "", level_unlocked_param: bool = false, daily_unlocked_param: bool = false):
	is_purchased = purchased
	is_active = active
	self.achievement_unlocked = achievement_unlocked_param
	self.achievement_name = achievement_name_param
	self.is_achievement_reward = item_data.get("is_achievement_reward", false)
	self.level_unlocked = level_unlocked_param
	self.is_level_reward = item_data.get("is_level_reward", false)
	self.daily_unlocked = daily_unlocked_param
	self.is_daily_reward = item_data.get("is_daily_reward", false)
	is_medal_reward = _is_medal_reward_item()
	medal_price = int(item_data.get("medal_price", 0))
	if is_medal_reward:
		medal_unlocked = PlayerDataManager.get_total_medals_earned() >= medal_price
	
	if is_level_reward and level_unlocked_param:
		is_purchased = true 
	elif is_achievement_reward and achievement_unlocked_param:
		is_purchased = true 
	elif is_daily_reward and daily_unlocked_param:
		is_purchased = true

	if is_node_ready():
		_update_buttons_and_status()
	
func _get_achievement_description_by_id(achievement_id_str: String) -> String:
	if achievement_id_str == "" or not achievement_id_str.is_valid_int():
		return ""
	var achievements = _get_achievements_data()
	if not achievements:
		return ""
	var id_val = int(achievement_id_str)
	for a in achievements:
		if a is Dictionary:
			var aid = int(a.get("id", -1))
			if aid == id_val:
				return _AchievementLocale.localized_description(a)
	return ""

func _get_achievement_progress_by_id(achievement_id_str: String) -> Dictionary:
	if achievement_id_str == "" or not achievement_id_str.is_valid_int():
		return {"current": 0, "total": 0}
	var achievements = _get_achievements_data()
	if not achievements:
		return {"current": 0, "total": 0}
	var id_val = int(achievement_id_str)
	for a in achievements:
		if a is Dictionary:
			var aid = int(a.get("id", -1))
			if aid == id_val:
				return {"current": int(a.get("current", 0)), "total": int(a.get("total", 0))}
	return {"current": 0, "total": 0}

func _apply_initial_image() -> void:
	var image_rect = $MarginContainer/ContentContainer/ImageWrapper/ImageRect
	if image_rect == null:
		return
	var image_path = item_data.get("image", "") 
	var images_folder = item_data.get("images_folder", "")
	var category = item_data.get("category", "")
	var color_hex = item_data.get("color_hex", "")
	var note_colors = item_data.get("note_colors", [])
	if category == "Подсветка линий" and color_hex != "":
		var hex_color = Color(color_hex)
		var texture = _create_color_texture(hex_color)
		if texture:
			image_rect.texture = texture
			return
	if category == "Ноты" and not note_colors.is_empty():
		var texture2 = _create_note_preview_texture(note_colors)
		if texture2:
			image_rect.texture = texture2
			return
	if image_path != "" and FileAccess.file_exists(image_path):
		_create_placeholder_with_text()
		_request_threaded_load(image_path)
		return
	_create_placeholder_with_text()

func _on_loader_loaded(p: String, tex: Texture2D) -> void:
	if p != _current_image_path:
		return
	var image_rect = get_node_or_null("MarginContainer/ContentContainer/ImageWrapper/ImageRect")
	if image_rect and tex:
		image_rect.texture = tex
		image_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		if str(item_data.get("category", "")) == "Кик":
			_update_kick_preview_image_visibility()
		else:
			image_rect.visible = true
			image_rect.modulate.a = 1.0
	_current_image_path = ""

func _exit_tree():
	if _loader and _loader_connected:
		_loader.loaded.disconnect(_on_loader_loaded)
		_loader_connected = false

func _set_name_label(lbl: Label) -> void:
	lbl.text = _ShopItemLocale.localized_name(item_data)
	lbl.visible = true

func _set_use_button(btn: Button, visible: bool) -> void:
	if btn:
		if _should_show_open_button():
			btn.visible = false
		else:
			btn.visible = visible
			if visible:
				btn.text = tr("SHOP_USE")

func _set_status(hbox: HBoxContainer, lbl: Label, visible: bool, text: String) -> void:
	if hbox:
		hbox.visible = visible
	if visible and lbl:
		lbl.text = text
