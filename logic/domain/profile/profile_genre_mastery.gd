# logic/domain/profile/profile_genre_mastery.gd
class_name ProfileGenreMastery
extends RefCounted

# Level 1 = first clear in the group; each next level needs 5 more clears in that group.
# Level 20 ~= 96 cumulative clears (1 + 19 * 5).
const MAX_LEVEL := 20
const PLAYS_AFTER_FIRST := 5


static func cumulative_plays_for_level(level: int) -> int:
	if level <= 0:
		return 0
	if level == 1:
		return 1
	return 1 + (level - 1) * PLAYS_AFTER_FIRST


static func level_from_plays(plays: int) -> int:
	if plays <= 0:
		return 0
	var level := 1 + int((plays - 1) / PLAYS_AFTER_FIRST)
	return mini(level, MAX_LEVEL)


static func progress_to_next_level(plays: int) -> Dictionary:
	var level := level_from_plays(plays)
	if level >= MAX_LEVEL:
		var cap := cumulative_plays_for_level(MAX_LEVEL)
		return {
			"level": MAX_LEVEL,
			"current": plays,
			"from": cap,
			"to": cap,
			"ratio": 1.0,
			"at_max": true,
		}
	var from_plays := 0 if level <= 0 else cumulative_plays_for_level(level)
	var to_plays := cumulative_plays_for_level(level + 1)
	var span := maxi(to_plays - from_plays, 1)
	var ratio := clampf(float(plays - from_plays) / float(span), 0.0, 1.0)
	return {
		"level": level,
		"current": plays,
		"from": from_plays,
		"to": to_plays,
		"ratio": ratio,
		"at_max": false,
	}


static func best_level_in_groups(genre_play_counts: Dictionary) -> int:
	var best := 0
	for group_id in ProfileGenrePortrait.all_group_ids():
		var plays := ProfileGenrePortrait.group_play_count(genre_play_counts, group_id)
		best = maxi(best, level_from_plays(plays))
	return best


static func groups_at_least_level(genre_play_counts: Dictionary, min_level: int) -> int:
	if min_level <= 0:
		return 0
	var count := 0
	for group_id in ProfileGenrePortrait.all_group_ids():
		if level_from_plays(ProfileGenrePortrait.group_play_count(genre_play_counts, group_id)) >= min_level:
			count += 1
	return count


static func level_accent_color(level: int) -> Color:
	if level <= 0:
		return Color(0.5, 0.52, 0.58, 0.92)
	if level >= MAX_LEVEL:
		return Color(0.86, 0.52, 0.72, 1)
	if level >= 15:
		return Color(0.95, 0.55, 0.45, 1)
	if level >= 10:
		return Color(0.9490196, 0.7019608, 0.3529412, 1)
	if level >= 5:
		return Color(0.62, 0.86, 0.72, 1)
	return Color(0.52, 0.76, 0.92, 1)


static func catalog_size_for_group(group_id: String) -> int:
	return ProfileGenrePortrait.genres_for_group(group_id).size()


static func discovered_count_in_group(group_id: String, genre_play_counts: Dictionary) -> int:
	var count := 0
	for genre_id in ProfileGenrePortrait.genres_for_group(group_id):
		if ProfileGenrePortrait.display_genre_play_count(genre_play_counts, genre_id) > 0:
			count += 1
	return count


static func discovery_ratio(discovered: int, total: int) -> float:
	if total <= 0:
		return 0.0
	return clampf(float(discovered) / float(total), 0.0, 1.0)


static func total_catalog_size() -> int:
	var seen: Dictionary = {}
	for group_id in ProfileGenrePortrait.all_group_ids():
		for genre_id in ProfileGenrePortrait.genres_for_group(group_id):
			seen[genre_id] = true
	return seen.size()


static func total_discovered(genre_play_counts: Dictionary) -> int:
	var count := 0
	for group_id in ProfileGenrePortrait.all_group_ids():
		count += discovered_count_in_group(group_id, genre_play_counts)
	return count


static func best_group_discovery(genre_play_counts: Dictionary) -> Dictionary:
	var best := {"group_id": "", "discovered": 0, "total": 0, "ratio": 0.0}
	for group_id in ProfileGenrePortrait.all_group_ids():
		var total := catalog_size_for_group(group_id)
		if total <= 0:
			continue
		var discovered := discovered_count_in_group(group_id, genre_play_counts)
		var ratio := discovery_ratio(discovered, total)
		var best_ratio := float(best.get("ratio", 0.0))
		if ratio > best_ratio or (is_equal_approx(ratio, best_ratio) and discovered > int(best.get("discovered", 0))):
			best = {"group_id": group_id, "discovered": discovered, "total": total, "ratio": ratio}
	return best


static func groups_with_full_discovery(genre_play_counts: Dictionary) -> int:
	var count := 0
	for group_id in ProfileGenrePortrait.all_group_ids():
		var total := catalog_size_for_group(group_id)
		if total > 0 and discovered_count_in_group(group_id, genre_play_counts) >= total:
			count += 1
	return count


static func best_group_discovered_count(genre_play_counts: Dictionary) -> int:
	var best := 0
	for group_id in ProfileGenrePortrait.all_group_ids():
		best = maxi(best, discovered_count_in_group(group_id, genre_play_counts))
	return best


static func has_completed_small_group(genre_play_counts: Dictionary, max_catalog: int = 10) -> bool:
	for group_id in ProfileGenrePortrait.all_group_ids():
		var total := catalog_size_for_group(group_id)
		if total <= 0 or total > max_catalog:
			continue
		if discovered_count_in_group(group_id, genre_play_counts) >= total:
			return true
	return false


static func discovery_accent_color(discovered: int, total: int) -> Color:
	if discovered <= 0 or total <= 0:
		return Color(0.38, 0.4, 0.46, 0.92)
	var ratio := discovery_ratio(discovered, total)
	if ratio >= 1.0:
		return Color(0.86, 0.52, 0.72, 1)
	if ratio >= 0.75:
		return Color(0.95, 0.55, 0.45, 1)
	if ratio >= 0.5:
		return Color(0.9490196, 0.7019608, 0.3529412, 1)
	if ratio >= 0.25:
		return Color(0.62, 0.86, 0.72, 1)
	return Color(0.52, 0.76, 0.92, 1)
