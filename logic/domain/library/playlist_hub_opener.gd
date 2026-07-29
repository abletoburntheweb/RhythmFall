# logic/domain/library/playlist_hub_opener.gd
class_name PlaylistHubOpener
extends RefCounted

## Entry point for opening the playlist hub from future surfaces (library, profile).
## Endless session setup uses Transitions directly in v1.


static func open_manage(transitions: Object, config: Dictionary = {}) -> void:
	if transitions == null:
		return
	if transitions.has_method("open_playlist_hub_from_song_select"):
		transitions.open_playlist_hub_from_song_select()
	elif transitions.has_method("open_playlist_hub_from_session_setup"):
		transitions.open_playlist_hub_from_session_setup(config, false)


static func open_pick(transitions: Object, config: Dictionary, selected_playlist_id: String = "") -> void:
	if transitions == null:
		return
	var cfg := config.duplicate(true)
	if str(selected_playlist_id).strip_edges() != "":
		cfg["playlist_id"] = str(selected_playlist_id).strip_edges()
	if transitions.has_method("open_playlist_hub_from_session_setup"):
		transitions.open_playlist_hub_from_session_setup(cfg, true)
