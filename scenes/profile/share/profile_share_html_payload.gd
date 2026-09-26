# scenes/profile/share/profile_share_html_payload.gd
class_name ProfileShareHtmlPayload
extends RefCounted

const _Snapshot = preload("res://scenes/profile/share/profile_share_snapshot.gd")
const _GenrePortrait = preload("res://logic/domain/profile/profile_genre_portrait.gd")
const _Facts = preload("res://scenes/profile/share/profile_share_card_facts.gd")
const _Taglines = preload("res://scenes/profile/share/profile_share_taglines.gd")
const _RunModifiers = preload("res://logic/domain/modifiers/run_modifiers.gd")
const _UiIconHelper = preload("res://logic/ui/ui_icon_helper.gd")
const _GenreGroupIcons = preload("res://logic/domain/library/genre_group_icons.gd")
const _PlayModes = preload("res://logic/domain/profile/profile_play_modes_stats.gd")
const _ChartDifficulty = preload("res://logic/domain/charts/chart_difficulty_analyzer.gd")

const CARD_HERO_KEYS := {
	"overview": "PROFILE_SHARE_RECAP_OVERVIEW",
	"statistics": "PROFILE_SHARE_RECAP_STATISTICS",
	"music": "PROFILE_SHARE_RECAP_MUSIC",
	"records": "PROFILE_SHARE_RECAP_RECORDS",
	"play_modes": "PROFILE_SHARE_RECAP_PLAY_MODES",
}

const CARD_HERO_SUBTITLE_KEYS := {
	"overview": "PROFILE_SHARE_RECAP_SUB_OVERVIEW",
	"statistics": "PROFILE_SHARE_RECAP_SUB_STATISTICS",
	"music": "PROFILE_SHARE_RECAP_SUB_MUSIC",
	"records": "PROFILE_SHARE_RECAP_SUB_RECORDS",
	"play_modes": "PROFILE_SHARE_RECAP_SUB_PLAY_MODES",
}

const CARD_ACCENT2 := {
	"overview": "#e879f9",
	"statistics": "#38bdf8",
	"music": "#34d399",
	"records": "#fb923c",
	"play_modes": "#c084fc",
}

const CARD_INDEX := {
	"overview": 1,
	"statistics": 2,
	"music": 3,
	"records": 4,
	"play_modes": 5,
}

const EXTREME_SPECS: Array = [
	["highest_accuracy", "PROFILE_RECORD_EXTREME_ACCURACY", "percent"],
	["hardest_chart_cleared", "PROFILE_RECORD_EXTREME_CHART", "rating"],
	["longest_fc", "PROFILE_RECORD_EXTREME_FC", "int"],
	["highest_bpm_cleared", "PROFILE_RECORD_EXTREME_BPM", "bpm"],
	["longest_track_duration_sec", "PROFILE_RECORD_EXTREME_DURATION", "duration"],
]

# Prestige ladder (easy → hard). Index drives Recap 4-slot pick.
const MILESTONE_SPECS: Array = [
	["first_track_played", "PROFILE_RECORD_MILESTONE_FIRST_TRACK"],
	["first_ss", "PROFILE_RECORD_MILESTONE_FIRST_SS"],
	["first_fc", "PROFILE_RECORD_MILESTONE_FIRST_FC"],
	["first_mod_clear", "PROFILE_RECORD_MILESTONE_FIRST_MOD"],
	["endless_unlocked", "PROFILE_RECORD_MILESTONE_ENDLESS"],
	["marathon_unlocked", "PROFILE_RECORD_MILESTONE_MARATHON"],
	["unique_100_tracks", "PROFILE_RECORD_MILESTONE_UNIQUE_100"],
	["clears_250", "PROFILE_RECORD_MILESTONE_CLEARS_250"],
	["total_rr_10000", "PROFILE_RECORD_MILESTONE_RR_10K"],
	["genre_group_level_10", "PROFILE_RECORD_MILESTONE_GENRE_L10"],
]


static func _css_hex(color: Color) -> String:
	## Godot to_html(false) is "rrggbb" without "#"; CSS needs "#rrggbb".
	return "#" + color.to_html(false)


static func build(card_id: String, data: Dictionary) -> Dictionary:
	var accent: Color = _Snapshot.CARD_ACCENT_COLORS.get(card_id, Color.WHITE)
	var payload := {
		"card_id": card_id,
		"card_index": CARD_INDEX.get(card_id, 1),
		"locale": TranslationServer.get_locale(),
		"accent": _css_hex(accent),
		"accent2": CARD_ACCENT2.get(card_id, _css_hex(accent)),
		"brand": TranslationServer.translate("PROFILE_SHARE_RECAP_BRAND"),
		"hero_subtitle": TranslationServer.translate(CARD_HERO_SUBTITLE_KEYS.get(card_id, "")),
		"hero_title": TranslationServer.translate(CARD_HERO_KEYS.get(card_id, "")),
		"footer_site": TranslationServer.translate("PROFILE_SHARE_FOOTER_SITE"),
		"footer_date": str(data.get("footer_date", _Snapshot.export_date_text())),
		"labels": _common_labels(),
	}
	match card_id:
		"overview":
			_merge_overview(payload, data)
		"statistics":
			_merge_statistics(payload, data)
		"music":
			_merge_music(payload, data)
		"records":
			_merge_records(payload, data)
		"play_modes":
			_merge_play_modes(payload, data)
	if str(payload.get("tagline", "")).strip_edges() == "":
		payload["tagline"] = str(data.get("tagline", ""))
		if str(payload["tagline"]).strip_edges() == "":
			payload["tagline"] = _Taglines.pick(card_id, data)
	return payload


static func _common_labels() -> Dictionary:
	return {
		"rr": TranslationServer.translate("PROFILE_STAT_TOTAL_RR"),
		"accuracy": TranslationServer.translate("PROFILE_ACCURACY"),
		"play_time": TranslationServer.translate("PROFILE_PLAY_TIME"),
		"tracks": TranslationServer.translate("PROFILE_SHARE_LEVELS_COMPLETED"),
		"member_since": TranslationServer.translate("PROFILE_SHARE_MEMBER_SINCE_LABEL"),
		"plays": TranslationServer.translate("PROFILE_PLAYS"),
		"best_grade": TranslationServer.translate("PROFILE_SHARE_BEST_GRADE").split(":")[0].strip_edges(),
		"sec_fav_track": TranslationServer.translate("PROFILE_SHARE_SEC_FAV_TRACK"),
		"sec_fav_genre": TranslationServer.translate("PROFILE_SHARE_SEC_FAV_GENRE"),
		"sec_combat": TranslationServer.translate("PROFILE_SHARE_SEC_RUN_TOTALS"),
		"sec_progress": TranslationServer.translate("PROFILE_SHARE_SEC_PROGRESS"),
		"sec_stats": TranslationServer.translate("PROFILE_SHARE_SEC_STATS_GRID"),
		"sec_grades": TranslationServer.translate("PROFILE_SHARE_SEC_GRADES_SHORT"),
		"sec_chart": TranslationServer.translate("PROFILE_SHARE_SEC_CHART"),
		"sec_genres": TranslationServer.translate("PROFILE_SHARE_SEC_TOP_GENRES"),
		"sec_collection": TranslationServer.translate("PROFILE_SHARE_SEC_COLLECTION"),
		"collection_groups": TranslationServer.translate("PROFILE_SHARE_COLLECTION_GROUPS"),
		"collection_genres": TranslationServer.translate("PROFILE_SHARE_COLLECTION_GENRES"),
		"collection_full": TranslationServer.translate("PROFILE_SHARE_COLLECTION_FULL"),
		"collection_best": TranslationServer.translate("PROFILE_SHARE_COLLECTION_BEST"),
		"sec_mastery": TranslationServer.translate("PROFILE_SHARE_SEC_MASTERY"),
		"sec_mastery_hint": TranslationServer.translate("PROFILE_SHARE_MASTERY_HINT"),
		"sec_leaders": TranslationServer.translate("PROFILE_SHARE_SEC_LEADERS"),
		"sec_fact": TranslationServer.translate("PROFILE_SHARE_SEC_FACT"),
		"sec_story": TranslationServer.translate("PROFILE_SHARE_SEC_STORY"),
		"sec_hall": TranslationServer.translate("PROFILE_SHARE_SEC_HALL"),
		"sec_discoveries": TranslationServer.translate("PROFILE_SHARE_SEC_DISCOVERIES"),
		"trend_new": TranslationServer.translate("PROFILE_SHARE_TREND_NEW"),
		"trend_growing": TranslationServer.translate("PROFILE_SHARE_TREND_GROWING"),
		"sec_rr_top": TranslationServer.translate("PROFILE_SHARE_SEC_RR_TOP"),
		"sec_milestones": TranslationServer.translate("PROFILE_SHARE_SEC_MILESTONES"),
		"sec_records": TranslationServer.translate("PROFILE_SHARE_SEC_RECORDS"),
		"sec_mods": TranslationServer.translate("PROFILE_SHARE_SEC_MODS"),
		"hit_rate": TranslationServer.translate("PROFILE_SHARE_HIT_RATE"),
		"hero_caption": TranslationServer.translate("PROFILE_SHARE_HIT_RATE"),
		"hero_sub": TranslationServer.translate("PROFILE_SHARE_STAT_HERO_SUB"),
		"hit": TranslationServer.translate("PROFILE_STAT_NOTES_HIT"),
		"miss": TranslationServer.translate("PROFILE_STAT_NOTES_MISS"),
		"combo": TranslationServer.translate("PROFILE_STAT_MAX_STREAK"),
		"score": TranslationServer.translate("PROFILE_STAT_TOTAL_SCORE"),
		"medals": TranslationServer.translate("PROFILE_STAT_MEDALS_TOTAL"),
		"daily": TranslationServer.translate("PROFILE_SHARE_DAILY_QUESTS"),
		"avg_diff": TranslationServer.translate("PROFILE_SHARE_AVG_DIFFICULTY"),
		"empty_genre": TranslationServer.translate("PROFILE_GENRE_PORTRAIT_EMPTY"),
		"level_short": TranslationServer.translate("PROFILE_LEVEL_SHORT"),
		"rr_peak": TranslationServer.translate("PROFILE_SHARE_RR_PEAK"),
		"marathon": TranslationServer.translate("PROFILE_SHARE_SEC_MARATHON"),
		"mod_clears": TranslationServer.translate("PROFILE_SHARE_SEC_MOD_CLEARS"),
		"endless": TranslationServer.translate("PROFILE_SHARE_SEC_ENDLESS"),
		"mods_mastered": TranslationServer.translate("PROFILE_OVERVIEW_MODS_MASTERED_FMT"),
		"hero_marathon": TranslationServer.translate("PROFILE_SHARE_HERO_MARATHON_ROUTES"),
		"hero_mods": TranslationServer.translate("PROFILE_SHARE_HERO_MOD_CLEARS"),
		"endless_streak": TranslationServer.translate("PROFILE_RECORD_ENDLESS_BEST_STREAK"),
		"endless_rr": TranslationServer.translate("PROFILE_RECORD_ENDLESS_BEST_RR"),
		"endless_accuracy": TranslationServer.translate("PROFILE_RECORD_ENDLESS_BEST_ACCURACY"),
		"marathon_empty": TranslationServer.translate("PROFILE_SHARE_PLAY_MODES_MARATHON_EMPTY"),
		"endless_empty": TranslationServer.translate("PROFILE_SHARE_PLAY_MODES_ENDLESS_EMPTY"),
		"mods_empty": TranslationServer.translate("PROFILE_OVERVIEW_MODS_EMPTY"),
	}


static func _merge_overview(payload: Dictionary, data: Dictionary) -> void:
	payload["level"] = int(data.get("level", 1))
	payload["level_label"] = TranslationServer.translate("PROFILE_LEVEL") % payload["level"]
	payload["xp_text"] = str(data.get("xp_text", ""))
	payload["xp_ratio"] = float(data.get("xp_ratio", 0.0))
	payload["rr_earned"] = int(data.get("rr_earned", 0))
	payload["accuracy"] = float(data.get("accuracy", 0.0))
	payload["play_time"] = _format_play_time(str(data.get("play_time", "0:00")))
	payload["levels_completed"] = int(data.get("levels_completed", 0))
	payload["member_since"] = str(data.get("member_since", ""))
	payload["medals_total"] = int(data.get("medals_total", 0))
	payload["max_combo"] = int(data.get("max_combo", 0))
	payload["total_score"] = int(data.get("total_score", 0))
	payload["daily_quests"] = int(data.get("daily_quests", 0))
	_apply_avg_difficulty(payload, float(data.get("avg_difficulty", 0.0)))
	payload["ss"] = int(data.get("ss", 0))
	payload["s"] = int(data.get("s", 0))
	payload["a"] = int(data.get("a", 0))
	payload["b"] = int(data.get("b", 0))
	payload["title"] = str(data.get("title", TranslationServer.translate("VALUE_NA")))
	payload["artist"] = str(data.get("artist", ""))
	payload["genre"] = str(data.get("genre", ""))
	payload["play_count"] = int(data.get("play_count", 0))
	payload["best_grade"] = str(data.get("best_grade", ""))
	payload["cover_b64"] = _texture_to_b64(data.get("cover"))
	var group_id := str(data.get("favorite_group_id", ""))
	payload["favorite_group"] = _group_label(group_id) if group_id != "" else ""
	payload["favorite_group_percent"] = float(data.get("favorite_group_percent", 0.0))
	if payload["favorite_group_percent"] > 0.0 and group_id != "":
		payload["genre_percent_text"] = TranslationServer.translate("PROFILE_SHARE_GENRE_PERCENT") % payload["favorite_group_percent"]
	payload["favorite_group_icon"] = _genre_icon_entry(group_id)
	var story: Array = []
	for line in data.get("story_lines", []):
		var s := str(line).strip_edges()
		if s != "":
			story.append(s)
	payload["story_lines"] = story
	payload["tagline"] = str(data.get("tagline", ""))
	payload["card_fact"] = _Facts.pick("overview", data)


static func _merge_statistics(payload: Dictionary, data: Dictionary) -> void:
	payload["notes_hit"] = int(data.get("notes_hit", 0))
	payload["notes_miss"] = int(data.get("notes_miss", 0))
	payload["hit_rate"] = float(data.get("hit_rate", 0.0))
	payload["accuracy_percent"] = float(data.get("accuracy", 0.0))
	payload["max_combo"] = int(data.get("max_combo", 0))
	payload["total_score"] = int(data.get("total_score", 0))
	payload["unique_tracks"] = int(data.get("unique_tracks", 0))
	payload["medals_total"] = int(data.get("medals_total", 0))
	payload["rr_earned"] = int(data.get("rr_earned", 0))
	payload["daily_quests"] = int(data.get("daily_quests", 0))
	_apply_avg_difficulty(payload, float(data.get("avg_difficulty", 0.0)))
	payload["ss"] = int(data.get("ss", 0))
	payload["s"] = int(data.get("s", 0))
	payload["a"] = int(data.get("a", 0))
	payload["b"] = int(data.get("b", 0))
	payload["grades_total"] = payload["ss"] + payload["s"] + payload["a"] + payload["b"]
	var points: Array = []
	for p in data.get("accuracy_points", []):
		points.append(float(p))
	payload["accuracy_points"] = points
	var session_count := int(data.get("session_count", points.size()))
	if session_count > 0:
		payload["chart_caption"] = TranslationServer.translate("PROFILE_SHARE_CHART_SESSIONS") % session_count
	else:
		payload["chart_caption"] = ""
	payload["hero_sub_text"] = TranslationServer.translate("PROFILE_SHARE_STAT_HERO_HITS") % fmt_int(payload["notes_hit"])
	payload["accuracy_delta_text"] = str(data.get("accuracy_delta_text", ""))
	payload["tracks_delta_text"] = str(data.get("tracks_delta_text", ""))
	payload["rr_delta_text"] = str(data.get("rr_delta_text", ""))
	payload["tagline"] = str(data.get("tagline", ""))
	payload["card_fact"] = _Facts.pick("statistics", data)


static func fmt_int(value: int) -> String:
	var v := int(value)
	if v >= 1_000_000:
		return "%.1fM" % (float(v) / 1000000.0)
	if v >= 10000:
		return "%dk" % int(round(float(v) / 1000.0))
	return str(v)


static func _merge_music(payload: Dictionary, data: Dictionary) -> void:
	var genres: Array = []
	var palette := ["#34d399", "#38bdf8", "#e879f9", "#fbbf24", "#f87171", "#a78bfa"]
	var idx := 0
	for row in data.get("top_genres", []):
		if not row is Dictionary:
			continue
		var trend := str(row.get("trend", "")).strip_edges().to_lower()
		genres.append({
			"name": _group_label(str(row.get("group_id", ""))),
			"percent": float(row.get("percent", 0.0)),
			"count": int(row.get("count", 0)),
			"color": palette[idx % palette.size()],
			"mastery_level": int(row.get("mastery_level", 0)),
			"mastery_ratio": float(row.get("mastery_ratio", 0.0)),
			"discovered": int(row.get("discovered", 0)),
			"catalog": int(row.get("catalog", 0)),
			"group_id": str(row.get("group_id", "")),
			"icon": _genre_icon_entry(str(row.get("group_id", ""))),
			"trend": trend,
		})
		idx += 1
	payload["top_genres"] = genres
	var discoveries: Array = []
	for gid_raw in data.get("new_discovery_ids", []):
		var gid := str(gid_raw).strip_edges()
		if gid == "":
			continue
		discoveries.append({
			"name": _group_label(gid),
			"group_id": gid,
			"icon": _genre_icon_entry(gid),
		})
	payload["new_discoveries"] = discoveries
	if not genres.is_empty():
		payload["hero_genre_name"] = str(genres[0].get("name", ""))
		payload["hero_genre_percent"] = float(genres[0].get("percent", 0.0))
		payload["hero_genre_percent_text"] = TranslationServer.translate("PROFILE_SHARE_GENRE_PERCENT") % payload["hero_genre_percent"]
		payload["hero_genre_icon"] = genres[0].get("icon", {})
	var unlocked := int(data.get("groups_unlocked", 0))
	var total := int(data.get("groups_total", 0))
	payload["groups_unlocked"] = unlocked
	payload["groups_total"] = total
	payload["best_mastery_level"] = int(data.get("best_mastery_level", 0))
	payload["best_mastery_group_id"] = str(data.get("best_mastery_group_id", ""))
	payload["best_mastery_group"] = _group_label(payload["best_mastery_group_id"]) if payload["best_mastery_group_id"] != "" else ""
	payload["genres_discovered"] = int(data.get("genres_discovered", 0))
	payload["catalog_total"] = int(data.get("catalog_total", 0))
	payload["full_groups_count"] = int(data.get("full_groups_count", 0))
	payload["collection_percent"] = (float(unlocked) / float(total) * 100.0) if total > 0 else 0.0
	payload["collection_groups_text"] = TranslationServer.translate("PROFILE_SHARE_COLLECTION_GROUPS") % [unlocked, total]
	payload["collection_genres_text"] = TranslationServer.translate("PROFILE_SHARE_COLLECTION_GENRES") % [
		int(data.get("genres_discovered", 0)),
		int(data.get("catalog_total", 0)),
	]
	payload["collection_full_text"] = TranslationServer.translate("PROFILE_SHARE_COLLECTION_FULL") % int(data.get("full_groups_count", 0))
	if payload["best_mastery_group"] != "" and payload["best_mastery_level"] > 0:
		payload["collection_best_text"] = TranslationServer.translate("PROFILE_SHARE_COLLECTION_BEST") % [
			payload["best_mastery_group"],
			payload["best_mastery_level"],
		]
	else:
		payload["collection_best_text"] = ""
	var fact_data := data.duplicate(true)
	fact_data["top_genres"] = genres
	payload["tagline"] = str(data.get("tagline", ""))
	payload["card_fact"] = _Facts.pick("music", fact_data)


static func _merge_records(payload: Dictionary, data: Dictionary) -> void:
	payload["best_rr_peak"] = int(data.get("best_rr_peak", 0))
	payload["best_rr_track"] = str(data.get("best_rr_track", ""))

	# RR #1 is the hero; drop 02–03 on Recap to keep the fact panel on-card.
	payload["rr_top"] = []

	var milestones: Dictionary = data.get("milestones", {}) if data.get("milestones") is Dictionary else {}
	payload["milestones"] = _pick_milestone_rows(milestones, 4)

	var hall_rows: Array = []
	var extremes_for_hall: Dictionary = data.get("extremes", {}) if data.get("extremes") is Dictionary else {}
	for row in data.get("hall_rows", []):
		if not row is Dictionary:
			continue
		var row_dict: Dictionary = row
		var caption_key := str(row_dict.get("caption_key", ""))
		var caption: String = ""
		if caption_key != "":
			caption = str(TranslationServer.translate(caption_key))
		else:
			caption = str(row_dict.get("caption", ""))
		var hall_id := str(row_dict.get("id", ""))
		var value_text := str(row_dict.get("value", ""))
		var value_color := ""
		var zap_icon: Dictionary = {}
		if hall_id == "hardest_chart" and extremes_for_hall.get("hardest_chart_cleared") is Dictionary:
			var hard_entry: Dictionary = extremes_for_hall["hardest_chart_cleared"]
			var rating := float(hard_entry.get("value", 0.0))
			var diff := _difficulty_display(rating)
			value_text = str(diff.get("text", value_text))
			value_color = str(diff.get("color", ""))
			var zap_raw: Variant = diff.get("zap", {})
			if zap_raw is Dictionary:
				zap_icon = zap_raw
		hall_rows.append({
			"caption": caption,
			"value": value_text,
			"track": str(row_dict.get("track", "")),
			"id": hall_id,
			"value_color": value_color,
			"zap_icon": zap_icon,
		})
	payload["hall_rows"] = hall_rows

	var extremes: Dictionary = data.get("extremes", {}) if data.get("extremes") is Dictionary else {}
	var rec_rows: Array = []
	for spec in EXTREME_SPECS:
		# Hall of fame already covers hardest / FC; keep accuracy / bpm / duration extras.
		var spec_id := str(spec[0])
		if spec_id in ["hardest_chart_cleared", "longest_fc"]:
			continue
		var caption := TranslationServer.translate(str(spec[1]))
		var value := TranslationServer.translate("VALUE_NA")
		var track := ""
		if extremes.has(spec_id) and extremes[spec_id] is Dictionary:
			var entry: Dictionary = extremes[spec_id]
			value = _format_extreme(entry, str(spec[2]))
			track = _track_line(entry)
			if value == "":
				value = TranslationServer.translate("VALUE_NA")
		rec_rows.append({
			"caption": caption,
			"value": value,
			"track": track,
		})
	payload["records"] = rec_rows
	payload["mod_rows"] = _mod_rows(data.get("mod_records", {}))
	payload["tagline"] = str(data.get("tagline", ""))
	payload["card_fact"] = _Facts.pick("records", data)


static func _merge_play_modes(payload: Dictionary, data: Dictionary) -> void:
	var marathon: Dictionary = data.get("marathon", {}) if data.get("marathon") is Dictionary else {}
	var mod: Dictionary = data.get("mod", {}) if data.get("mod") is Dictionary else {}
	var endless: Dictionary = data.get("endless", {}) if data.get("endless") is Dictionary else {}
	var routes_completed := int(data.get("routes_completed", 0))
	var routes_attempted := int(data.get("routes_attempted", 0))
	var mod_mastered := int(data.get("mod_mastered", 0))
	var mod_total := int(data.get("mod_total", 0))

	payload["hero_value"] = int(data.get("hero_value", 0))
	payload["hero_kind"] = str(data.get("hero_kind", "mods"))
	payload["hero_caption_key"] = (
		"hero_marathon" if payload["hero_kind"] == "marathon" else "hero_mods"
	)
	payload["marathon_routes_text"] = TranslationServer.translate("PROFILE_OVERVIEW_MARATHON_ROUTES_FMT") % [
		routes_completed,
		routes_attempted,
	]
	var tier := str(marathon.get("best_badge_tier", ""))
	payload["marathon_badge"] = _PlayModes.badge_tier_label(tier) if tier != "" else ""
	payload["mods_mastered_text"] = TranslationServer.translate("PROFILE_OVERVIEW_MODS_MASTERED_FMT") % [
		mod_mastered,
		mod_total,
	]
	payload["hardest_stack"] = int(mod.get("hardest_stack", 0))
	var top_mod_id := str(mod.get("top_mod_id", ""))
	payload["top_mod_icon"] = _mod_icon_entry(top_mod_id) if top_mod_id != "" else {}

	var marathon_rows: Array = []
	for row in data.get("top_marathon", []):
		if not row is Dictionary:
			continue
		marathon_rows.append({
			"title": str(row.get("title", "")),
			"ratio_text": str(row.get("ratio_text", "")),
			"badge_label": str(row.get("badge_label", "")),
		})
	payload["marathon_rows"] = marathon_rows

	var mod_clear_rows: Array = []
	for row in data.get("mod_clears", []):
		if not row is Dictionary:
			continue
		var mod_id := str(row.get("mod_id", ""))
		if mod_id == "":
			continue
		mod_clear_rows.append({
			"mod_id": mod_id,
			"count": int(row.get("count", 0)),
			"icon": _mod_icon_entry(mod_id),
		})
	payload["mod_clear_rows"] = mod_clear_rows

	payload["endless_unlocked"] = not endless.is_empty()
	payload["endless_best_streak"] = int(endless.get("best_streak", 0))
	payload["endless_best_rr"] = int(endless.get("best_rr", 0))
	payload["endless_best_accuracy"] = float(endless.get("best_accuracy", 0.0))
	payload["endless_total_runs"] = int(endless.get("total_runs", 0))
	payload["marathon_has_data"] = routes_attempted > 0
	payload["endless_has_data"] = (
		not endless.is_empty()
		and (
			int(endless.get("total_runs", 0)) > 0
			or int(endless.get("best_streak", 0)) > 0
		)
	)
	payload["mod_has_data"] = not mod_clear_rows.is_empty()
	payload["marathon_empty_text"] = TranslationServer.translate("PROFILE_SHARE_PLAY_MODES_MARATHON_EMPTY")
	payload["endless_empty_text"] = TranslationServer.translate("PROFILE_SHARE_PLAY_MODES_ENDLESS_EMPTY")
	payload["endless_story"] = str(data.get("endless_story", ""))
	payload["marathon_story"] = str(data.get("marathon_story", ""))
	payload["tagline"] = str(data.get("tagline", ""))
	payload["card_fact"] = _Facts.pick("play_modes", data)


static func _genre_icon_entry(group_id: String) -> Dictionary:
	var gid := str(group_id).strip_edges().to_lower()
	if gid == "":
		return {}
	var tint := _GenreGroupIcons.tint_for_group(gid)
	var icon_file := _GenreGroupIcons.icon_file_for_group(gid)
	var tex := _UiIconHelper.load_tinted_icon(icon_file, tint, 48)
	return {
		"group_id": gid,
		"b64": _texture_to_b64(tex),
		"tint": _css_hex(tint),
	}


static func _mod_icon_entry(mod_id: String) -> Dictionary:
	var id := str(mod_id).strip_edges()
	if id == "":
		return {}
	var icon_file := _RunModifiers.icon_file(id)
	if icon_file.strip_edges() == "":
		return {}
	var tint := _RunModifiers.category_tint(id, true)
	var tex := _UiIconHelper.load_tinted_icon(icon_file, tint, 48)
	return {
		"mod_id": id,
		"b64": _texture_to_b64(tex),
		"tint": _css_hex(tint),
	}


static func _mod_icon_entries(mod_ids: Variant, limit: int = 8) -> Array:
	if not mod_ids is Array:
		return []
	var out: Array = []
	for raw in _RunModifiers.sanitize(mod_ids):
		if out.size() >= limit:
			break
		var entry := _mod_icon_entry(str(raw))
		if not entry.is_empty():
			out.append(entry)
	return out


static func _mod_rows(mod_records: Variant) -> Array:
	if not mod_records is Dictionary:
		return []
	var rows: Array = []
	var max_rec: Variant = mod_records.get("max_mod_count")
	if max_rec is Dictionary and int(max_rec.get("count", 0)) > 0:
		rows.append({
			"caption": TranslationServer.translate("PROFILE_RECORD_MOD_MAX_COUNT"),
			"value": TranslationServer.translate("PROFILE_RECORDS_MOD_COUNT_SHORT") % int(max_rec.get("count", 0)),
			"icons": _mod_icon_entries(max_rec.get("modifiers", [])),
		})
	var hard_rec: Variant = mod_records.get("hardest_mod_combo")
	if hard_rec is Dictionary and float(hard_rec.get("hardness", 0.0)) > 0.0:
		var bonus := int(round(float(hard_rec.get("hardness", 0.0)) * 100.0))
		rows.append({
			"caption": TranslationServer.translate("PROFILE_RECORD_MOD_HARDEST"),
			"value": TranslationServer.translate("PROFILE_RECORD_MOD_HARD_BONUS") % bonus,
			"icons": _mod_icon_entries(hard_rec.get("modifiers", [])),
		})
	var score_rec: Variant = mod_records.get("best_score_with_mods")
	if score_rec is Dictionary and int(score_rec.get("score", 0)) > 0:
		rows.append({
			"caption": TranslationServer.translate("PROFILE_RECORD_MOD_BEST_SCORE"),
			"value": fmt_int(int(score_rec.get("score", 0))),
			"icons": _mod_icon_entries(score_rec.get("modifiers", [])),
		})
	var rr_rec: Variant = mod_records.get("best_rr_with_mods")
	if rr_rec is Dictionary and int(rr_rec.get("best_rr", rr_rec.get("rr", 0))) > 0:
		var rr_val := int(rr_rec.get("best_rr", 0))
		if rr_val <= 0:
			rr_val = int(rr_rec.get("rr", 0))
		rows.append({
			"caption": TranslationServer.translate("PROFILE_RECORD_MOD_BEST_RR"),
			"value": fmt_int(rr_val),
			"icons": _mod_icon_entries(rr_rec.get("modifiers", [])),
		})
	var acc_rec: Variant = mod_records.get("best_accuracy_with_mods")
	if acc_rec is Dictionary and float(acc_rec.get("accuracy", 0.0)) > 0.0:
		rows.append({
			"caption": TranslationServer.translate("PROFILE_RECORD_MOD_BEST_ACCURACY"),
			"value": "%.1f%%" % float(acc_rec.get("accuracy", 0.0)),
			"icons": _mod_icon_entries(acc_rec.get("modifiers", [])),
		})
	# Stack peaks first; one legendary score run for share. Cap at 3.
	if rows.size() > 3:
		rows.resize(3)
	return rows


static func _pick_milestone_rows(milestones: Dictionary, limit: int = 4) -> Array:
	## Exactly `limit` slots. Prestige grows with MILESTONE_SPECS index.
	## ≥limit unlocked → hardest unlocked; else fill empties with easiest locked.
	var unlocked_idxs: Array[int] = []
	var locked_idxs: Array[int] = []
	for i in range(MILESTONE_SPECS.size()):
		var key := str(MILESTONE_SPECS[i][0])
		if _milestone_unlocked(milestones, key):
			unlocked_idxs.append(i)
		else:
			locked_idxs.append(i)
	var pick: Array[int] = []
	if unlocked_idxs.size() >= limit:
		unlocked_idxs.sort()
		for j in range(unlocked_idxs.size() - limit, unlocked_idxs.size()):
			pick.append(unlocked_idxs[j])
	else:
		pick.append_array(unlocked_idxs)
		locked_idxs.sort()
		for idx in locked_idxs:
			if pick.size() >= limit:
				break
			pick.append(idx)
	pick.sort()
	var ms_rows: Array = []
	for idx in pick:
		var spec: Array = MILESTONE_SPECS[idx]
		ms_rows.append({
			"title": TranslationServer.translate(str(spec[1])),
			"unlocked": _milestone_unlocked(milestones, str(spec[0])),
		})
	return ms_rows


static func _apply_avg_difficulty(payload: Dictionary, avg: float) -> void:
	var diff := _difficulty_display(avg)
	payload["avg_difficulty_text"] = str(diff.get("text", TranslationServer.translate("VALUE_NA")))
	payload["avg_difficulty_color"] = str(diff.get("color", ""))
	var zap_raw: Variant = diff.get("zap", {})
	payload["avg_difficulty_zap"] = zap_raw if zap_raw is Dictionary else {}


static func _difficulty_display(rating: float) -> Dictionary:
	if rating <= 0.01:
		return {
			"text": TranslationServer.translate("VALUE_NA"),
			"color": "",
			"zap": {},
		}
	var color := _ChartDifficulty.rating_color_for_decimal(rating)
	var text := _ChartDifficulty.format_decimal_rating(rating, false)
	var tex := _UiIconHelper.load_tinted_icon("zap.svg", color, 48)
	return {
		"text": text,
		"color": _css_hex(color),
		"zap": {
			"b64": _texture_to_b64(tex),
			"tint": _css_hex(color),
		},
	}


static func _track_line(entry: Dictionary) -> String:
	var title := str(entry.get("title", "")).strip_edges()
	var artist := str(entry.get("artist", "")).strip_edges()
	if title == "" and artist == "":
		return ""
	if artist == "":
		return title
	if title == "":
		return artist
	return "%s — %s" % [artist, title]


static func _milestone_unlocked(milestones: Dictionary, key: String) -> bool:
	if milestones.has(key):
		return true
	if key == "first_hidden_clear" and milestones.has("first_hidden"):
		return true
	return false


static func _group_label(group_id: String) -> String:
	if group_id == "" or group_id == "_other":
		return TranslationServer.translate("PROFILE_GENRE_GRP_OTHER")
	var key := _GenrePortrait.group_locale_key(group_id)
	var label := TranslationServer.translate(key)
	if label == key:
		return group_id.replace("_", " ").capitalize()
	return label


static func _format_play_time(raw: String) -> String:
	var parts := raw.split(":")
	if parts.size() >= 2:
		var h := int(parts[0]) if parts[0].is_valid_int() else 0
		var m := int(parts[1]) if parts[1].is_valid_int() else 0
		return TranslationServer.translate("PROFILE_PLAY_TIME_FMT") % [h, m]
	return raw


static func _texture_to_b64(tex: Variant) -> String:
	if tex == null or not tex is Texture2D:
		return ""
	var img: Image = tex.get_image()
	if img == null or img.is_empty():
		return ""
	if img.get_width() > 256 or img.get_height() > 256:
		img = img.duplicate()
		img.resize(256, 256, Image.INTERPOLATE_LANCZOS)
	return Marshalls.raw_to_base64(img.save_png_to_buffer())


static func _days_str(days: int) -> String:
	if days <= 0:
		return TranslationServer.translate("VALUE_NA")
	return TranslationServer.translate("PROFILE_DAYS_FMT") % days


static func _format_extreme(entry: Dictionary, kind: String) -> String:
	match kind:
		"percent":
			return "%.2f%%" % float(entry.get("value", 0.0))
		"rating":
			return "%.2f★" % float(entry.get("value", 0.0))
		"bpm":
			return "%d BPM" % int(entry.get("value", 0))
		"duration":
			var sec := int(entry.get("value", 0))
			var m := sec / 60
			var s := sec % 60
			return "%d:%02d" % [m, s]
		_:
			return str(int(entry.get("value", 0)))
