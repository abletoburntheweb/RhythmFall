# scenes/profile/share/profile_share_card_facts.gd
class_name ProfileShareCardFacts
extends RefCounted

const _GenrePortrait = preload("res://logic/domain/profile/profile_genre_portrait.gd")
const _GenreMastery = preload("res://logic/domain/profile/profile_genre_mastery.gd")
const _RunModifiers = preload("res://logic/domain/modifiers/run_modifiers.gd")

# Insight facts — avoid repeating hero / grid numbers on the same card.
const FACT_KEYS := {
	"overview": [
		"PROFILE_SHARE_FACT_OVR_GENRE_GAP",
		"PROFILE_SHARE_FACT_OVR_SS_SHARE",
		"PROFILE_SHARE_FACT_OVR_FAVORITE",
		"PROFILE_SHARE_FACT_OVR_DAYS",
		"PROFILE_SHARE_FACT_OVR_XP",
		"PROFILE_SHARE_FACT_OVR_GRADE_PERFECT",
	],
	"statistics": [
		"PROFILE_SHARE_FACT_STAT_MISS_SHARE",
		"PROFILE_SHARE_FACT_STAT_AVG_HITS",
		"PROFILE_SHARE_FACT_STAT_TREND",
		"PROFILE_SHARE_FACT_STAT_SS_SHARE",
		"PROFILE_SHARE_FACT_STAT_COMBO_MISS",
	],
	"music": [
		"PROFILE_SHARE_FACT_MUS_GENRE_GAP",
		"PROFILE_SHARE_FACT_MUS_DISCOVERY",
		"PROFILE_SHARE_FACT_MUS_FULL_GROUPS",
		"PROFILE_SHARE_FACT_MUS_PLAY_VS_MASTERY",
		"PROFILE_SHARE_FACT_MUS_DEEP_GROUP",
	],
	"records": [
		"PROFILE_SHARE_FACT_REC_RR_SPREAD",
		"PROFILE_SHARE_FACT_REC_SHARED_TRACK",
		"PROFILE_SHARE_FACT_REC_MOD_CHALLENGE",
		"PROFILE_SHARE_FACT_REC_MILESTONE_STORY",
		"PROFILE_SHARE_FACT_REC_EXTREME",
	],
	"play_modes": [
		"PROFILE_SHARE_FACT_MOD_MARATHON_COMPLETE",
		"PROFILE_SHARE_FACT_MOD_TOP_MOD",
		"PROFILE_SHARE_FACT_MOD_HARDEST_STACK",
		"PROFILE_SHARE_FACT_MOD_ENDLESS_STREAK",
		"PROFILE_SHARE_FACT_MOD_BADGE_TIER",
	],
}


static func pick(card_id: String, data: Dictionary) -> String:
	var keys: Array = FACT_KEYS.get(card_id, [])
	if keys.is_empty():
		return ""
	var idx := _pick_index(card_id, data, keys.size())
	for attempt in range(keys.size()):
		var key := str(keys[(idx + attempt) % keys.size()])
		var text := _try_format(key, data)
		if text != "":
			return text
	return ""


static func _pick_index(card_id: String, data: Dictionary, count: int) -> int:
	if count <= 0:
		return 0
	var ctx := HashingContext.new()
	ctx.start(HashingContext.HASH_SHA256)
	var day := Time.get_date_dict_from_system(true)
	ctx.update(
		("%s|%s|%04d-%02d-%02d" % [
			card_id,
			JSON.stringify(data),
			int(day.get("year", 0)),
			int(day.get("month", 0)),
			int(day.get("day", 0)),
		]).to_utf8_buffer()
	)
	var hex := ctx.finish().hex_encode()
	return int(hex.substr(0, 8).hex_to_int()) % count


static func _try_format(key: String, data: Dictionary) -> String:
	match key:
		"PROFILE_SHARE_FACT_OVR_GENRE_GAP":
			return _format_genre_gap(data.get("top_genres_pair", []))
		"PROFILE_SHARE_FACT_OVR_SS_SHARE":
			var share := _ss_share_percent(data)
			if share < 0.0:
				return ""
			return TranslationServer.translate(key) % int(round(share))
		"PROFILE_SHARE_FACT_OVR_FAVORITE":
			var plays := int(data.get("play_count", 0))
			var title := str(data.get("title", "")).strip_edges()
			if plays <= 1 or title == "":
				return ""
			return TranslationServer.translate(key) % [title, plays]
		"PROFILE_SHARE_FACT_OVR_DAYS":
			var days := int(data.get("days_in_game", 0))
			if days <= 0:
				return ""
			return TranslationServer.translate(key) % days
		"PROFILE_SHARE_FACT_OVR_XP":
			var ratio := float(data.get("xp_ratio", 0.0))
			if ratio <= 0.01 or ratio >= 0.99:
				return ""
			return TranslationServer.translate(key) % int(round(ratio * 100.0))
		"PROFILE_SHARE_FACT_OVR_GRADE_PERFECT":
			var ss := int(data.get("ss", 0))
			var tracks := int(data.get("levels_completed", 0))
			if ss <= 0 or tracks <= 0 or ss < tracks:
				return ""
			return TranslationServer.translate(key) % tracks
		"PROFILE_SHARE_FACT_STAT_MISS_SHARE":
			var hit := int(data.get("notes_hit", 0))
			var miss := int(data.get("notes_miss", 0))
			var total := hit + miss
			if total <= 0 or miss <= 0:
				return ""
			var miss_pct := (float(miss) / float(total)) * 100.0
			return TranslationServer.translate(key) % [miss, "%.2f" % miss_pct]
		"PROFILE_SHARE_FACT_STAT_AVG_HITS":
			var hit := int(data.get("notes_hit", 0))
			var sessions := int(data.get("session_count", 0))
			if hit <= 0 or sessions <= 0:
				return ""
			return TranslationServer.translate(key) % int(round(float(hit) / float(sessions)))
		"PROFILE_SHARE_FACT_STAT_TREND":
			return _format_accuracy_trend(data.get("accuracy_points", []))
		"PROFILE_SHARE_FACT_STAT_SS_SHARE":
			var share := _ss_share_percent(data)
			if share < 0.0:
				return ""
			return TranslationServer.translate(key) % int(round(share))
		"PROFILE_SHARE_FACT_STAT_COMBO_MISS":
			var combo := int(data.get("max_combo", 0))
			var miss := int(data.get("notes_miss", 0))
			if combo <= 0 or miss <= 0:
				return ""
			var ratio := float(combo) / float(miss)
			if ratio < 5.0:
				return ""
			return TranslationServer.translate(key) % int(round(ratio))
		"PROFILE_SHARE_FACT_MUS_GENRE_GAP":
			return _format_genre_gap(data.get("top_genres", []))
		"PROFILE_SHARE_FACT_MUS_DISCOVERY":
			var discovered := int(data.get("genres_discovered", 0))
			var catalog := int(data.get("catalog_total", 0))
			if catalog <= 0 or discovered <= 0:
				return ""
			return TranslationServer.translate(key) % [discovered, catalog]
		"PROFILE_SHARE_FACT_MUS_FULL_GROUPS":
			var full := int(data.get("full_groups_count", 0))
			if full <= 0:
				return ""
			return TranslationServer.translate(key) % full
		"PROFILE_SHARE_FACT_MUS_PLAY_VS_MASTERY":
			return _format_play_vs_mastery(data)
		"PROFILE_SHARE_FACT_MUS_DEEP_GROUP":
			return _format_deep_group(data.get("top_genres", []))
		"PROFILE_SHARE_FACT_REC_RR_SPREAD":
			var spread := int(data.get("rr_spread", 0))
			if spread <= 0:
				return ""
			return TranslationServer.translate(key) % spread
		"PROFILE_SHARE_FACT_REC_SHARED_TRACK":
			var line := str(data.get("shared_extreme_track", "")).strip_edges()
			if line == "":
				return ""
			return TranslationServer.translate(key) % line
		"PROFILE_SHARE_FACT_REC_MOD_CHALLENGE":
			var bonus := int(data.get("mod_hard_bonus", 0))
			if bonus <= 0:
				return ""
			return TranslationServer.translate(key) % bonus
		"PROFILE_SHARE_FACT_REC_MILESTONE_STORY":
			return _format_milestone_story(data.get("milestones", {}))
		"PROFILE_SHARE_FACT_REC_EXTREME":
			var acc := str(data.get("extreme_accuracy_line", "")).strip_edges()
			if acc == "":
				return ""
			return TranslationServer.translate(key) % acc
		"PROFILE_SHARE_FACT_MOD_MARATHON_COMPLETE":
			var completed := int(data.get("routes_completed", 0))
			var attempted := int(data.get("routes_attempted", 0))
			if completed <= 0 or attempted <= 0:
				return ""
			return TranslationServer.translate(key) % [completed, attempted]
		"PROFILE_SHARE_FACT_MOD_TOP_MOD":
			var mod: Dictionary = data.get("mod", {}) if data.get("mod") is Dictionary else {}
			var mod_id := str(mod.get("top_mod_id", "")).strip_edges()
			var count := int(mod.get("top_mod_count", 0))
			if mod_id == "" or count <= 0:
				return ""
			var label := TranslationServer.translate(_RunModifiers.title_i18n_key(mod_id))
			return TranslationServer.translate(key) % [label, count]
		"PROFILE_SHARE_FACT_MOD_HARDEST_STACK":
			var mod_stack: Dictionary = data.get("mod", {}) if data.get("mod") is Dictionary else {}
			var stack := int(mod_stack.get("hardest_stack", 0))
			if stack < 2:
				return ""
			return TranslationServer.translate(key) % stack
		"PROFILE_SHARE_FACT_MOD_ENDLESS_STREAK":
			var endless: Dictionary = data.get("endless", {}) if data.get("endless") is Dictionary else {}
			var streak := int(endless.get("best_streak", 0))
			if streak <= 0:
				return ""
			return TranslationServer.translate(key) % streak
		"PROFILE_SHARE_FACT_MOD_BADGE_TIER":
			var marathon: Dictionary = data.get("marathon", {}) if data.get("marathon") is Dictionary else {}
			var tier := str(marathon.get("best_badge_tier", "")).strip_edges()
			if tier == "":
				return ""
			const _PlayModes = preload("res://logic/domain/profile/profile_play_modes_stats.gd")
			var tier_label := _PlayModes.badge_tier_label(tier)
			if tier_label == "":
				return ""
			return TranslationServer.translate(key) % tier_label
		_:
			var text := TranslationServer.translate(key)
			return "" if text == key else text


static func _ss_share_percent(data: Dictionary) -> float:
	var ss := int(data.get("ss", 0))
	var s := int(data.get("s", 0))
	var a := int(data.get("a", 0))
	var b := int(data.get("b", 0))
	var total := ss + s + a + b
	if total <= 0:
		return -1.0
	return (float(ss) / float(total)) * 100.0


static func _format_genre_gap(genres: Variant) -> String:
	if not genres is Array or genres.size() < 2:
		return ""
	var first: Dictionary = genres[0] if genres[0] is Dictionary else {}
	var second: Dictionary = genres[1] if genres[1] is Dictionary else {}
	var name1 := _genre_row_name(first)
	var name2 := _genre_row_name(second)
	var pct1 := _genre_row_percent(first)
	var pct2 := _genre_row_percent(second)
	if name1 == "" or name2 == "" or pct1 <= pct2:
		return ""
	var gap := int(round(pct1 - pct2))
	if gap < 3:
		return ""
	return TranslationServer.translate("PROFILE_SHARE_FACT_GENRE_GAP") % [name1, name2, gap]


static func _genre_row_name(row: Dictionary) -> String:
	var name := str(row.get("name", "")).strip_edges()
	if name != "":
		return name
	var group_id := str(row.get("group_id", "")).strip_edges()
	if group_id == "":
		return ""
	var key := _GenrePortrait.group_locale_key(group_id)
	var label := TranslationServer.translate(key)
	return label if label != key else group_id.replace("_", " ").capitalize()


static func _genre_row_percent(row: Dictionary) -> float:
	return float(row.get("percent", 0.0))


static func _format_accuracy_trend(points: Variant) -> String:
	if not points is Array or points.size() < 4:
		return ""
	var nums: Array = []
	for p in points:
		nums.append(float(p))
	var half := maxi(1, nums.size() / 2)
	var early_sum := 0.0
	var late_sum := 0.0
	for i in range(nums.size()):
		if i < half:
			early_sum += float(nums[i])
		else:
			late_sum += float(nums[i])
	var early_avg := early_sum / float(half)
	var late_avg := late_sum / float(nums.size() - half)
	var delta := late_avg - early_avg
	var trend_key := "PROFILE_SHARE_FACT_TREND_STABLE"
	if delta >= 1.5:
		trend_key = "PROFILE_SHARE_FACT_TREND_UP"
	elif delta <= -1.5:
		trend_key = "PROFILE_SHARE_FACT_TREND_DOWN"
	var trend := TranslationServer.translate(trend_key)
	return TranslationServer.translate("PROFILE_SHARE_FACT_STAT_TREND") % [trend, nums.size()]


static func _format_play_vs_mastery(data: Dictionary) -> String:
	var top_genres: Variant = data.get("top_genres", [])
	if not top_genres is Array or top_genres.is_empty():
		return ""
	var play_row: Dictionary = top_genres[0] if top_genres[0] is Dictionary else {}
	var play_name := _genre_row_name(play_row)
	var play_level := int(play_row.get("mastery_level", 0))
	if play_name == "":
		return ""
	var best_id := str(data.get("best_mastery_group_id", "")).strip_edges()
	if best_id == "":
		return ""
	var best_name := _genre_row_name({"group_id": best_id})
	var best_level := int(data.get("best_mastery_level", 0))
	if best_name == "" or best_level <= 0:
		return ""
	if play_name == best_name:
		return ""
	return TranslationServer.translate("PROFILE_SHARE_FACT_MUS_PLAY_VS_MASTERY") % [play_name, play_level, best_name, best_level]


static func _format_deep_group(genres: Variant) -> String:
	if not genres is Array:
		return ""
	var best_row: Dictionary = {}
	var best_level := 0
	for row in genres:
		if not row is Dictionary:
			continue
		var level := int(row.get("mastery_level", 0))
		if level > best_level:
			best_level = level
			best_row = row
	if best_level <= 1:
		return ""
	var name := _genre_row_name(best_row)
	if name == "":
		return ""
	var discovered := int(best_row.get("discovered", 0))
	var catalog := int(best_row.get("catalog", 0))
	if catalog > 0 and discovered > 0:
		return TranslationServer.translate("PROFILE_SHARE_FACT_MUS_DEEP_GROUP_DISC") % [name, best_level, discovered, catalog]
	return TranslationServer.translate("PROFILE_SHARE_FACT_MUS_DEEP_GROUP") % [name, best_level]


static func _format_milestone_story(milestones: Variant) -> String:
	if not milestones is Dictionary:
		return ""
	for key in ["first_ss", "first_fc", "first_s"]:
		if not milestones.has(key):
			continue
		var entry: Dictionary = milestones[key] if milestones[key] is Dictionary else {}
		var title := str(entry.get("title", "")).strip_edges()
		if title == "":
			continue
		var milestone_key := "PROFILE_RECORD_MILESTONE_%s" % key.to_upper()
		var label := TranslationServer.translate(milestone_key)
		return TranslationServer.translate("PROFILE_SHARE_FACT_REC_MILESTONE_STORY") % [label, title]
	return ""
