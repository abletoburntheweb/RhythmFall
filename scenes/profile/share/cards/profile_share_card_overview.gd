# scenes/profile/share/cards/profile_share_card_overview.gd
extends ProfileShareCardBase

const _GenreGroupIcons = preload("res://logic/domain/library/genre_group_icons.gd")

@onready var _hero_level: Label = %HeroLevel
@onready var _xp_bar: ProgressBar = %XPBar
@onready var _xp_text: Label = %XPText
@onready var _chip_rr: PanelContainer = %ChipRR
@onready var _chip_acc: PanelContainer = %ChipAcc
@onready var _chip_time: PanelContainer = %ChipTime
@onready var _chip_tracks: PanelContainer = %ChipTracks
@onready var _cover: TextureRect = %Cover
@onready var _fav_title: Label = %FavTitle
@onready var _fav_artist: Label = %FavArtist
@onready var _fav_meta: Label = %FavMeta
@onready var _genre_name: Label = %GenreName
@onready var _genre_pct: Label = %GenrePct
@onready var _genre_icon_host: Control = %GenreIconHost


func _ready() -> void:
	card_id = "overview"
	super._ready()


func _apply_card_content(data: Dictionary) -> void:
	var accent := _accent()
	var level := int(data.get("level", 1))
	_set_label(_hero_level, tr("PROFILE_LEVEL") % level, 72, accent)
	_apply_glass_panel(get_node_or_null("%LevelPanel") as PanelContainer, true)

	if _xp_bar:
		_style_progress(_xp_bar, accent)
		_xp_bar.custom_minimum_size.y = _fs(18)
		_xp_bar.value = clampf(float(data.get("xp_ratio", 0.0)), 0.0, 1.0) * 100.0
		_xp_bar.max_value = 100.0
	_set_label(_xp_text, str(data.get("xp_text", "")), 22, _MUTED)

	_apply_chip(_chip_rr, tr("PROFILE_STAT_TOTAL_RR"), str(int(data.get("rr_earned", 0))), _Wrapped.VALUE_COLORS["rr"], 40, 20)
	_apply_chip(_chip_acc, tr("PROFILE_ACCURACY"), "%.1f%%" % float(data.get("accuracy", 0.0)), _Wrapped.VALUE_COLORS["accuracy"], 36, 20)
	_apply_chip(_chip_time, tr("PROFILE_PLAY_TIME"), _format_play_time(str(data.get("play_time", "0:00"))), _TEXT, 32, 20)
	_apply_chip(_chip_tracks, tr("PROFILE_LEVELS_COMPLETED"), str(int(data.get("unique_tracks", 0))), accent, 36, 20)

	if _cover:
		_cover.custom_minimum_size = Vector2(_fs(112), _fs(112))
		_cover.texture = data.get("cover") as Texture2D
	_apply_glass_panel(get_node_or_null("%FavoritePanel") as PanelContainer)
	_set_label(_fav_title, str(data.get("title", tr("VALUE_NA"))), 28, _TEXT)
	_set_label(_fav_artist, str(data.get("artist", "")), 22, _MUTED)
	_set_label(_fav_meta, tr("PROFILE_SHARE_OVERVIEW_META") % [str(data.get("genre", "")), int(data.get("play_count", 0))], 18, _MUTED)

	var group_id := str(data.get("favorite_group_id", ""))
	_apply_glass_panel(get_node_or_null("%GenrePanel") as PanelContainer, true)
	if group_id == "":
		_set_label(_genre_name, tr("PROFILE_GENRE_PORTRAIT_EMPTY"), 24, _MUTED)
		_set_label(_genre_pct, "", 20, _MUTED)
	else:
		_set_label(_genre_name, _group_label(group_id), 26, accent)
		_set_label(_genre_pct, tr("PROFILE_SHARE_GENRE_PERCENT") % float(data.get("favorite_group_percent", 0.0)), 20, _MUTED)
	_populate_genre_icon(group_id)


func _populate_genre_icon(group_id: String) -> void:
	if _genre_icon_host == null:
		return
	for child in _genre_icon_host.get_children():
		child.queue_free()
	if group_id == "":
		return
	var tint := _GenreGroupIcons.tint_for_group(group_id)
	_genre_icon_host.custom_minimum_size = Vector2(_fs(40), _fs(40))
	_genre_icon_host.add_child(_GenreGroupIcons.make_icon_frame_for_group(group_id, tint, _fs(40), _fs(18)))
