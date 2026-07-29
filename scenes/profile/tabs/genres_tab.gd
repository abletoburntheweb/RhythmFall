# scenes/profile/tabs/genres_tab.gd
extends VBoxContainer

var screen: ProfileScreen = null

var _genres_bars_animated := false
var _genres_refresh_token := 0
var _genres_refresh_running := false

@onready var profile_genres_panel: ProfileGenresPanel = get_node_or_null("ProfileGenresPanel") as ProfileGenresPanel
@onready var genres_title_label: Label = get_node_or_null("GenresPlaceholderCard/ContentVBox/GenresTitleLabel") as Label
@onready var genres_body_label: Label = get_node_or_null("GenresPlaceholderCard/ContentVBox/GenresBodyLabel") as Label


func bind(host: ProfileScreen) -> void:
	screen = host


func apply_locale() -> void:
	if profile_genres_panel:
		profile_genres_panel.apply_locale()


func refresh_if_visible() -> void:
	if screen == null or screen.current_profile_category != "genres" or profile_genres_panel == null:
		return
	if profile_genres_panel.is_built():
		profile_genres_panel.refresh_catalog_only()
		return
	call_deferred("refresh_panel")


func refresh_panel() -> void:
	if _genres_refresh_running:
		return
	_genres_refresh_running = true
	if screen:
		await screen.with_profile_loading(_rebuild_async)
	_genres_refresh_running = false


func rebuild_async() -> void:
	await _rebuild_async()


func get_genres_panel() -> ProfileGenresPanel:
	return profile_genres_panel


func _rebuild_async() -> void:
	var token := _genres_refresh_token + 1
	_genres_refresh_token = token
	if profile_genres_panel == null:
		return
	var animate := not _genres_bars_animated
	await profile_genres_panel.refresh_async({}, animate)
	if token != _genres_refresh_token:
		return
	if animate:
		_genres_bars_animated = true
	await get_tree().process_frame
