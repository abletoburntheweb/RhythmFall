# logic/domain/audio/audio_source_resolver.gd
extends RefCounted
class_name AudioSourceResolver

# Single source of truth for drums stem discovery / validation / fallback.
# Chart Editor (T toggle) and gameplay mods must use this, not duplicate ChartStemManager logic.
# ChartStemManager remains responsible for low-level file lookup; this resolver adds the
# fallback policy (stems -> metronome/original) and a unified has_stem check.

const ChartStemManagerClass = preload("res://logic/domain/editor/chart_stem_manager.gd")

static func has_drums_stem(song_path: String) -> bool:
	if String(song_path).strip_edges() == "":
		return false
	return ChartStemManagerClass.has_stem(song_path, "drums")

static func get_drums_stem_rel(song_path: String) -> String:
	if String(song_path).strip_edges() == "":
		return ""
	# Persistent content-based first (Phase 3E), then server, then legacy
	var rel := ChartStemManagerClass.persistent_stem_path_for(song_path, "drums")
	if rel == "":
		rel = ChartStemManagerClass.server_stem_path_for(song_path, "drums")
	if rel == "":
		rel = ChartStemManagerClass.stem_path_for(song_path, "drums")
	# Validate without loading twice if possible
	if rel != "":
		var info := ChartStemManagerClass.validate_stem(rel)
		if bool(info.get("valid", false)):
			return rel
	return ""

static func get_drums_stem_abs(song_path: String) -> String:
	var rel := get_drums_stem_rel(song_path)
	if rel == "":
		return ""
	return DirectoryUtils.to_absolute(rel)

# Effective path for "stems if found, otherwise fallback".
# want_stems == true -> drums stem if has_stem else fallback_path (original or empty)
# want_stems == false -> always fallback_path
static func effective_stems_or_fallback(song_path: String, want_stems: bool, fallback_path: String = "") -> String:
	if want_stems and has_drums_stem(song_path):
		var rel := get_drums_stem_rel(song_path)
		if rel != "":
			return rel
	return fallback_path if fallback_path != "" else song_path

# For silence gap: source in {"silence","metronome","stems"}
# Returns "silence" (meaning mute), "metronome", or "stems" (only if has_stem, otherwise metronome fallback)
static func resolve_silence_gap_source(song_path: String, gap_source: String) -> String:
	var g := String(gap_source).strip_edges().to_lower()
	if g not in ["silence", "metronome", "stems"]:
		g = "silence"
	if g == "stems":
		if has_drums_stem(song_path):
			return "stems"
		# Fallback to metronome per spec
		return "metronome"
	return g

static func gap_source_is_stems(gap_source: String) -> bool:
	return String(gap_source).strip_edges().to_lower() == "stems"

static func gap_source_is_metronome(gap_source: String) -> bool:
	return String(gap_source).strip_edges().to_lower() == "metronome"

static func gap_source_is_silence(gap_source: String) -> bool:
	var g := String(gap_source).strip_edges().to_lower()
	return g == "silence" or g == ""
