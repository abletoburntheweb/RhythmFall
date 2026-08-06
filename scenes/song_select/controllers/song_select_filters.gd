# scenes/song_select/controllers/song_select_filters.gd
class_name SongSelectFilters
extends Node

const _SS = preload("res://logic/domain/library/song_select_strings.gd")
const _OptionButtonPopupUtils = preload("res://logic/ui/option_button_popup_utils.gd")

var screen: BaseScreen = null
var restoring: bool = false


func initialize(host: BaseScreen) -> void:
	screen = host


func ensure_option_items() -> void:
	var filter: OptionButton = screen.filter_by_letter
	if not filter:
		return
	filter.set_block_signals(true)
	while filter.item_count < 9:
		filter.add_item("")
	filter.set_item_text(0, screen.tr("SONG_FILTER_TITLE"))
	filter.set_item_text(1, screen.tr("SONG_FILTER_ARTIST"))
	filter.set_item_text(2, screen.tr("SONG_FILTER_YEAR"))
	filter.set_item_text(3, _SS._translate("SONG_FILTER_BPM"))
	filter.set_item_text(4, _SS._translate("SONG_FILTER_DURATION"))
	filter.set_item_text(5, _SS._translate("SONG_FILTER_DIFFICULTY"))
	filter.set_item_text(6, _SS._translate("SONG_FILTER_PLAY_COUNT"))
	filter.set_item_text(7, _SS._translate("SONG_FILTER_NOTES_READY"))
	filter.set_item_text(8, screen.tr("SONG_FILTER_GENRE_GROUP"))
	filter.set_block_signals(false)
	refresh_option_icon()


func sync_option_selection() -> void:
	if not screen.filter_by_letter or not screen.song_list_manager:
		return
	ensure_option_items()
	var idx := mode_to_index(screen.song_list_manager.current_filter_mode)
	screen.filter_by_letter.select(clampi(idx, 0, screen.filter_by_letter.item_count - 1))
	refresh_option_icon()


func restore_and_populate() -> void:
	var mode := normalize_mode(
		String(SettingsManager.get_setting("song_select_filter_mode", "title"))
	)
	var query := String(SettingsManager.get_setting("song_select_search_query", ""))
	restoring = true
	screen.song_list_manager.set_filter_mode(mode)
	ensure_option_items()
	if screen.filter_by_letter:
		screen.filter_by_letter.set_block_signals(true)
		screen.filter_by_letter.select(clampi(mode_to_index(mode), 0, screen.filter_by_letter.item_count - 1))
		screen.filter_by_letter.set_block_signals(false)
	if screen._search_bar:
		screen._search_bar.text = query
	var defer_heavy := mode == "difficulty"
	if query.strip_edges() != "":
		if defer_heavy:
			screen.song_list_manager.call_deferred("filter_items", query, true)
		else:
			screen.song_list_manager.filter_items(query)
	else:
		if defer_heavy:
			screen.song_list_manager.call_deferred("populate_items_grouped", true)
		else:
			screen.song_list_manager.populate_items_grouped()
	restoring = false


func persist() -> void:
	if restoring:
		return
	SettingsManager.set_setting("song_select_filter_mode", screen.song_list_manager.current_filter_mode)
	var query: String = String(screen._search_bar.text if screen._search_bar else "")
	SettingsManager.set_setting("song_select_search_query", String(query))
	SettingsManager.save_settings()


func apply_popup_font() -> void:
	_OptionButtonPopupUtils.apply_popup_font_size(screen.filter_by_letter, 24)


func refresh_option_icon() -> void:
	if not screen.filter_by_letter:
		return
	var mode := "title"
	if screen.song_list_manager:
		mode = String(screen.song_list_manager.current_filter_mode)
	var icon_file := "chart_difficulty.svg"
	var tint := UiIconHelper.ACCENT
	if mode != "difficulty":
		icon_file = "arrow-down-narrow-wide.svg"
		tint = screen._ICON_NEUTRAL
		if mode == "genre_group":
			icon_file = "tags.svg"
			tint = UiIconHelper.ACCENT
	UiIconHelper.mark_option_button_icon(screen.filter_by_letter, icon_file, tint)


func normalize_mode(mode: String) -> String:
	match String(mode).strip_edges():
		"artist", "year", "bpm", "duration", "difficulty", "play_count", "notes_ready", "genre_group":
			return String(mode).strip_edges()
		_:
			return "title"


func mode_to_index(mode: String) -> int:
	match normalize_mode(mode):
		"artist":
			return 1
		"year":
			return 2
		"bpm":
			return 3
		"duration":
			return 4
		"difficulty":
			return 5
		"play_count":
			return 6
		"notes_ready":
			return 7
		"genre_group":
			return 8
		_:
			return 0
