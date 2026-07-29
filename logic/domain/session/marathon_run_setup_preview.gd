# logic/domain/session/marathon_run_setup_preview.gd
class_name MarathonRunSetupPreview
extends RefCounted

const _EndlessSessionConfig = preload("res://logic/domain/session/endless_session_config.gd")
const _MarathonSessionConfig = preload("res://logic/domain/session/marathon_session_config.gd")
const _RunModifiers = preload("res://logic/domain/modifiers/run_modifiers.gd")


static func mods_items(template: Dictionary, effective_config: Dictionary = {}) -> Array[Dictionary]:
	var cfg := effective_config
	if cfg.is_empty():
		cfg = _MarathonSessionConfig.resolve_effective_run_config(
			_MarathonSessionConfig.default_config(),
			template
		)
	else:
		cfg = _MarathonSessionConfig.resolve_effective_run_config(cfg, template)
	var policy := str(cfg.get("mod_policy", _EndlessSessionConfig.MOD_POLICY_NONE))
	if policy == _EndlessSessionConfig.MOD_POLICY_NONE:
		return [{
			"icon": "ban.svg",
			"text": TranslationServer.translate("MARATHON_SUMMARY_MODS_NONE"),
			"tint": Color(0.62, 0.68, 0.78, 1.0),
			"mod_id": "",
		}]
	if policy == _EndlessSessionConfig.MOD_POLICY_FIXED:
		var items: Array[Dictionary] = []
		for mod_id in cfg.get("mod_pool", []):
			var sid := str(mod_id).strip_edges()
			if sid == "":
				continue
			items.append({
				"icon": "sparkles.svg",
				"text": TranslationServer.translate(_RunModifiers.title_i18n_key(sid)),
				"tint": Color(0.72, 0.58, 0.95, 1.0),
				"mod_id": sid,
			})
		if items.is_empty():
			return [{
				"icon": "ban.svg",
				"text": TranslationServer.translate("MARATHON_SUMMARY_MODS_NONE"),
				"tint": Color(0.62, 0.68, 0.78, 1.0),
				"mod_id": "",
			}]
		return items
	var count := int(cfg.get("mod_random_count", _EndlessSessionConfig.DEFAULT_MOD_RANDOM_COUNT))
	return [{
		"icon": "shuffle.svg",
		"text": TranslationServer.translate("MARATHON_SUMMARY_MODS_RANDOM_FMT") % count,
		"tint": Color(0.62, 0.78, 0.95, 1.0),
		"mod_id": "",
	}]
