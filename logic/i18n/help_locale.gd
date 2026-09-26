# logic/i18n/help_locale.gd
extends RefCounted
class_name HelpLocale


static func localized_section_title(section: Dictionary) -> String:
	var sid := str(section.get("id", "")).strip_edges()
	if sid.is_empty():
		return str(section.get("title", ""))
	var key := "HELP_SEC_%s_TITLE" % sid
	var translated := _translate(key)
	if translated != key:
		return translated
	return str(section.get("title", ""))


static func localized_item_title(item: Dictionary) -> String:
	var iid := str(item.get("id", "")).strip_edges()
	if iid.is_empty():
		return str(item.get("title", ""))
	var key := "HELP_%s_TITLE" % iid
	var translated := _translate(key)
	if translated != key:
		return translated
	return str(item.get("title", ""))


static func localized_item_content(item: Dictionary) -> String:
	var json_content := str(item.get("content", ""))
	var iid := str(item.get("id", "")).strip_edges()
	if iid.is_empty():
		return json_content
	var key := "HELP_%s_CONTENT" % iid
	var translated := _translate(key)
	if translated == key:
		return HelpContentParser.normalize_inline_markup(json_content)
	var result := translated
	if "[showcase" in json_content and "[showcase" not in result:
		result = _prepend_showcase_blocks(json_content, result)
	if "[mod_list" in json_content and "[mod_list" not in result:
		result = _prepend_mod_list_blocks(json_content, result)
	if "[flow" in json_content and "[flow" not in result:
		result = _prepend_flow_blocks(json_content, result)
	return HelpContentParser.normalize_inline_markup(result)


static func _prepend_flow_blocks(json_content: String, translated: String) -> String:
	_ensure_flow_regex()
	var blocks: PackedStringArray = []
	for match in _flow_re.search_all(json_content):
		blocks.append(match.get_string(0).strip_edges())
	if blocks.is_empty():
		return translated
	var prefix := "\n\n".join(blocks)
	if translated.strip_edges() == "":
		return prefix
	return prefix + "\n\n" + translated


static func _prepend_mod_list_blocks(json_content: String, translated: String) -> String:
	_ensure_mod_list_regex()
	var out := translated
	for match in _mod_list_re.search_all(json_content):
		var block := match.get_string(0).strip_edges()
		if block == "" or block in out:
			continue
		var anchor := _mod_list_anchor_for_block(block, json_content)
		if anchor == "":
			continue
		var pos := out.find(anchor)
		if pos < 0:
			continue
		var insert_pos := pos + anchor.length()
		out = out.substr(0, insert_pos) + "\n\n" + block + out.substr(insert_pos)
	return out


static func _mod_list_anchor_for_block(block: String, json_content: String) -> String:
	_ensure_showcase_regex()
	var category := ""
	for token in block.strip_edges().trim_prefix("[mod_list").trim_suffix("]").strip_edges().split(" ", false):
		if token.begins_with("category="):
			category = token.substr(9).strip_edges()
			break
	if category != "":
		return "[showcase modifiers category=%s]" % category
	for showcase_match in _showcase_re.search_all(json_content):
		var showcase_block := showcase_match.get_string(0).strip_edges()
		var showcase_pos := int(showcase_match.get_start())
		var block_pos := json_content.find(block)
		if block_pos > showcase_pos:
			return showcase_block
	return ""


static func _prepend_showcase_blocks(json_content: String, translated: String) -> String:
	_ensure_showcase_regex()
	var blocks: PackedStringArray = []
	for match in _showcase_re.search_all(json_content):
		blocks.append(match.get_string(0).strip_edges())
	if blocks.is_empty():
		return translated
	var prefix := "\n\n".join(blocks)
	if translated.strip_edges() == "":
		return prefix
	return prefix + "\n\n" + translated


static func localized_item_summary(item: Dictionary) -> String:
	var iid := str(item.get("id", "")).strip_edges()
	if iid.is_empty():
		return str(item.get("summary", ""))
	var key := "HELP_%s_SUMMARY" % iid
	var translated := _translate(key)
	if translated != key:
		return translated
	return str(item.get("summary", ""))


static func localized_link_label(link: Dictionary) -> String:
	var label_key := str(link.get("label_key", "")).strip_edges()
	if label_key != "":
		var translated := _translate(label_key)
		if translated != label_key:
			return translated
	return str(link.get("label", ""))


static func _translate(key: String) -> String:
	return TranslationServer.translate(key)


static var _flow_re: RegEx
static var _showcase_re: RegEx
static var _mod_list_re: RegEx


static func _ensure_mod_list_regex() -> void:
	if _mod_list_re != null:
		return
	_mod_list_re = RegEx.new()
	_mod_list_re.compile("\\[mod_list[^\\]]*\\]")


static func _ensure_showcase_regex() -> void:
	if _showcase_re != null:
		return
	_showcase_re = RegEx.new()
	_showcase_re.compile("\\[showcase\\s+\\w+[^\\]]*\\]")


static func _ensure_flow_regex() -> void:
	if _flow_re != null:
		return
	_flow_re = RegEx.new()
	_flow_re.compile("\\[flow\\s+(?:linear|split|branch)\\][\\s\\S]*?\\[/flow\\]")
