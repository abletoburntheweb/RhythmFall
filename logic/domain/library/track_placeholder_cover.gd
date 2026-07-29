# logic/utils/track_placeholder_cover.gd
extends RefCounted
class_name TrackPlaceholderCover

const FOLDER := "res://assets/placeholders/track_covers/shards"
const COUNT := 7


static func path_for_index(index: int) -> String:
	var idx := clampi(index, 1, COUNT)
	return "%s/cover%d.png" % [FOLDER, idx]


static func path_for_song(song_path: String) -> String:
	if song_path.strip_edges() == "":
		return _resolve_existing(path_random())
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(song_path)
	return _resolve_existing(path_for_index(rng.randi_range(1, COUNT)))


static func path_random() -> String:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	return path_for_index(rng.randi_range(1, COUNT))


static func load_texture(song_path: String = "", stable: bool = true) -> Texture2D:
	var resource_path := path_for_song(song_path) if stable else _resolve_existing(path_random())
	if resource_path == "":
		return null
	if ResourceLoader.exists(resource_path):
		return load(resource_path) as Texture2D
	return null


static func warmup_paths() -> Array[String]:
	var paths: Array[String] = []
	for i in range(1, COUNT + 1):
		paths.append(path_for_index(i))
	return paths


static func _resolve_existing(resource_path: String) -> String:
	if FileAccess.file_exists(resource_path):
		return resource_path
	var fallback := path_for_index(1)
	if FileAccess.file_exists(fallback):
		return fallback
	return ""
