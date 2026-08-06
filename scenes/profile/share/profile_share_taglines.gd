# Template taglines for Recap cards (rules, not AI). Impersonal voice.
extends RefCounted
class_name ProfileShareTaglines

const _GenrePortrait = preload("res://logic/domain/profile/profile_genre_portrait.gd")


static func pick(card_id: String, data: Dictionary) -> String:
	var candidates: Array[String] = _candidates(card_id, data)
	if candidates.is_empty():
		return TranslationServer.translate("PROFILE_SHARE_WRAPPED_TAGLINE")
	var idx := _pick_index(card_id, data, candidates.size())
	var key := candidates[idx]
	if key == "PROFILE_SHARE_TAGLINE_GENRE_HOME":
		var group_id := str(data.get("favorite_group_id", data.get("best_mastery_group_id", "")))
		var label := genre_home_arg(group_id)
		if label == "":
			return TranslationServer.translate("PROFILE_SHARE_TAGLINE_RHYTHM")
		return TranslationServer.translate(key) % label
	return TranslationServer.translate(key)


static func _candidates(card_id: String, data: Dictionary) -> Array[String]:
	var out: Array[String] = []
	var accuracy := float(data.get("accuracy", data.get("accuracy_percent", 0.0)))
	var ss := int(data.get("ss", 0))
	var clears := int(data.get("levels_completed", data.get("unique_tracks", 0)))
	var group_id := str(data.get("favorite_group_id", data.get("best_mastery_group_id", "")))
	var endless_streak := 0
	var endless: Variant = data.get("endless", {})
	if endless is Dictionary:
		endless_streak = int(endless.get("best_streak", 0))
	var best_rr := int(data.get("best_rr_peak", data.get("rr_earned", 0)))
	var max_combo := int(data.get("max_combo", 0))

	if accuracy >= 96.0:
		out.append("PROFILE_SHARE_TAGLINE_PERFECTION")
	if ss > 0 and clears > 0 and float(ss) / float(clears) >= 0.35:
		out.append("PROFILE_SHARE_TAGLINE_ACCURACY")
	if group_id == "metal" or group_id == "rock":
		out.append("PROFILE_SHARE_TAGLINE_METAL" if group_id == "metal" else "PROFILE_SHARE_TAGLINE_ROCK")
	elif group_id != "" and group_id != "_other":
		out.append("PROFILE_SHARE_TAGLINE_GENRE_HOME")
	if endless_streak >= 8 or max_combo >= 500:
		out.append("PROFILE_SHARE_TAGLINE_ONE_MORE")
	if best_rr >= 8000:
		out.append("PROFILE_SHARE_TAGLINE_PEAK")
	if int(data.get("mod_record_count", 0)) > 0 or int(data.get("mod_mastered", 0)) >= 3:
		out.append("PROFILE_SHARE_TAGLINE_CHALLENGE")
	if int(data.get("login_streak", 0)) >= 7 or int(data.get("best_login_streak", 0)) >= 14:
		out.append("PROFILE_SHARE_TAGLINE_CONSISTENCY")

	match card_id:
		"music":
			out.append("PROFILE_SHARE_TAGLINE_COLLECTION")
		"play_modes":
			out.append("PROFILE_SHARE_TAGLINE_MODES")
		"records":
			out.append("PROFILE_SHARE_TAGLINE_LEGEND")
		_:
			out.append("PROFILE_SHARE_TAGLINE_RHYTHM")

	# Dedup while preserving order.
	var seen: Dictionary = {}
	var uniq: Array[String] = []
	for key in out:
		if seen.has(key):
			continue
		seen[key] = true
		uniq.append(key)
	return uniq


static func _pick_index(card_id: String, data: Dictionary, count: int) -> int:
	if count <= 0:
		return 0
	var ctx := HashingContext.new()
	ctx.start(HashingContext.HASH_SHA256)
	var day := Time.get_date_dict_from_system(true)
	ctx.update(
		("%s|tagline|%s|%04d-%02d-%02d" % [
			card_id,
			JSON.stringify({
				"a": data.get("accuracy", 0),
				"g": data.get("favorite_group_id", ""),
				"rr": data.get("rr_earned", 0),
			}),
			int(day.get("year", 0)),
			int(day.get("month", 0)),
			int(day.get("day", 0)),
		]).to_utf8_buffer()
	)
	return int(ctx.finish().hex_encode().substr(0, 8).hex_to_int()) % count


static func genre_home_arg(group_id: String) -> String:
	if group_id == "" or group_id == "_other":
		return ""
	return TranslationServer.translate(_GenrePortrait.group_locale_key(group_id))
