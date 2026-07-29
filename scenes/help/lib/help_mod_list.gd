# scenes/help/lib/help_mod_list.gd
extends RefCounted
class_name HelpModList

const _RunModifiers = preload("res://logic/domain/modifiers/run_modifiers.gd")


static func modifier_ids_for_params(params: Dictionary) -> Array:
	var ids_param := str(params.get("ids", "")).strip_edges()
	if ids_param != "":
		var out: Array = []
		for raw_id in ids_param.split(",", false):
			var sid := str(raw_id).strip_edges()
			if sid != "" and sid in _RunModifiers.ALL_IDS:
				out.append(sid)
		return out
	var category := str(params.get("category", "")).strip_edges()
	match category:
		"easing":
			return _RunModifiers.EASING_IDS.duplicate()
		"hardening":
			return _RunModifiers.HARDENING_IDS.duplicate()
		"special":
			return _RunModifiers.SPECIAL_IDS.duplicate()
		"dna":
			return _RunModifiers.DNA_IDS.duplicate()
		_:
			return []


static func plain_i18n_key(modifier_id: String) -> String:
	var desc_key := _RunModifiers.desc_i18n_key(modifier_id)
	if desc_key.begins_with("MOD_DESC_"):
		return "HELP_MOD_PLAIN_%s" % desc_key.substr(9)
	return "HELP_MOD_PLAIN_%s" % modifier_id.to_upper()


static func plain_text_for(modifier_id: String) -> String:
	var plain_key := plain_i18n_key(modifier_id)
	var plain := TranslationServer.translate(plain_key)
	if plain != plain_key:
		return plain
	return TranslationServer.translate(_RunModifiers.desc_i18n_key(modifier_id))


static func bbcode_for_params(params: Dictionary) -> String:
	var lines: PackedStringArray = []
	for mod_id in modifier_ids_for_params(params):
		var title := TranslationServer.translate(_RunModifiers.title_i18n_key(mod_id))
		var plain := plain_text_for(mod_id)
		lines.append("· [b]%s[/b] — %s" % [title, plain])
	return "\n".join(lines)
