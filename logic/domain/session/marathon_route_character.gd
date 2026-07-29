# logic/domain/session/marathon_route_character.gd
class_name MarathonRouteCharacter
extends RefCounted

const _MarathonSeason = preload("res://logic/domain/session/marathon_season.gd")
const _MarathonDailyRoute = preload("res://logic/domain/session/marathon_daily_route.gd")
const _MarathonRouteBadges = preload("res://logic/domain/session/marathon_route_badges.gd")
const _ProfileGenrePortrait = preload("res://logic/domain/profile/profile_genre_portrait.gd")


static func display_title(template: Dictionary, route_meta: Dictionary = {}) -> String:
	if bool(template.get("is_daily", false)):
		var genre_id := str(template.get("genre_group_id", "")).strip_edges()
		if genre_id != "":
			var genre_name := TranslationServer.translate(_ProfileGenrePortrait.group_locale_key(genre_id))
			return TranslationServer.translate("MARATHON_ROUTE_DISPLAY_FMT") % [
				genre_name,
				TranslationServer.translate("MARATHON_DAILY_TITLE"),
			]
		return TranslationServer.translate("MARATHON_DAILY_TITLE")
	var genre_id := str(template.get("genre_group_id", "")).strip_edges()
	var genre_name := TranslationServer.translate(_ProfileGenrePortrait.group_locale_key(genre_id))
	var archetype_title := ""
	var title_key := str(template.get("title_key", route_meta.get("title_key", ""))).strip_edges()
	if title_key != "":
		archetype_title = TranslationServer.translate(title_key)
	if archetype_title == "":
		archetype_title = str(template.get("archetype_id", "")).capitalize()
	if genre_name != "" and genre_name != title_key:
		return TranslationServer.translate("MARATHON_ROUTE_DISPLAY_FMT") % [genre_name, archetype_title]
	return archetype_title


static func tagline(template: Dictionary) -> String:
	var key := str(template.get("tagline_key", "")).strip_edges()
	if key != "":
		return TranslationServer.translate(key)
	var subtitle_key := str(template.get("subtitle_key", "")).strip_edges()
	if subtitle_key != "":
		return TranslationServer.translate(subtitle_key)
	return ""


static func idea_label(template: Dictionary) -> String:
	var key := str(template.get("idea_key", "")).strip_edges()
	if key == "":
		return ""
	return TranslationServer.translate(key)


static func difficulty_star_count(template: Dictionary) -> int:
	var dmin := float(template.get("difficulty_min", 2.0))
	var dmax := float(template.get("difficulty_max", 7.0))
	return clampi(int(round((dmin + dmax) * 0.5)), 1, 10)


static func difficulty_stars_text(template: Dictionary) -> String:
	var count := difficulty_star_count(template)
	return "★".repeat(count)


static func avg_bpm_from_preview(preview: Dictionary) -> int:
	var entries: Variant = preview.get("entries", [])
	if not entries is Array or (entries as Array).is_empty():
		return 0
	var sum := 0.0
	var n := 0
	for raw in entries:
		if not raw is Dictionary:
			continue
		var path := str((raw as Dictionary).get("song_path", "")).strip_edges()
		if path == "" or SongLibrary == null:
			continue
		var meta := SongLibrary.get_display_metadata_for_song(path)
		if not meta is Dictionary:
			continue
		var bpm := _parse_bpm(meta.get("bpm", 0))
		if bpm > 0.0:
			sum += bpm
			n += 1
	if n <= 0:
		return 0
	return int(round(sum / float(n)))


static func progress_snapshot(route_id: String, template: Dictionary) -> Dictionary:
	var rid := str(route_id).strip_edges()
	var out := {
		"attempted": false,
		"best_ratio": 0.0,
		"best_acc": 0.0,
		"best_badge_tier": "",
		"best_badge_name": "",
		"earned_badges": [],
		"next_tier": "",
		"next_medal_name": "",
		"next_medal_desc": "",
		"all_complete": false,
	}
	if PlayerDataManager == null or rid == "":
		return out
	var completions: Variant = PlayerDataManager.data.get("marathon_completions", {})
	if not completions is Dictionary:
		return out
	var entry: Variant = completions.get(rid, {})
	if not entry is Dictionary:
		return out
	var rec: Dictionary = entry
	out["attempted"] = true
	out["best_ratio"] = float(rec.get("best_ratio", 0.0))
	out["best_acc"] = float(rec.get("best_acc", 0.0))
	out["best_badge_tier"] = str(rec.get("best_badge_tier", ""))
	var badges: Variant = rec.get("badges", [])
	if badges is Array:
		out["earned_badges"] = badges.duplicate()
	if out["best_badge_tier"] != "":
		out["best_badge_name"] = _MarathonRouteBadges.medal_name(rid, out["best_badge_tier"], template)
	var tiers := _MarathonRouteBadges.active_tiers_for_template(rid, template)
	var earned_set: Dictionary = {}
	for tier in out["earned_badges"]:
		earned_set[str(tier)] = true
	for tier in tiers:
		if not earned_set.has(tier):
			out["next_tier"] = tier
			out["next_medal_name"] = _MarathonRouteBadges.medal_name(rid, tier, template)
			out["next_medal_desc"] = _MarathonRouteBadges.medal_description(rid, tier, template)
			break
	if out["next_tier"] == "" and not tiers.is_empty():
		out["all_complete"] = true
	return out


static func _parse_bpm(raw: Variant) -> float:
	if typeof(raw) == TYPE_FLOAT or typeof(raw) == TYPE_INT:
		return maxf(0.0, float(raw))
	var text := str(raw).strip_edges()
	if text == "":
		return 0.0
	return maxf(0.0, float(text))
