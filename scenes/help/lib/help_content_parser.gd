# scenes/help/lib/help_content_parser.gd
extends RefCounted
class_name HelpContentParser

static var _callout_re: RegEx
static var _flow_re: RegEx
static var _showcase_re: RegEx
static var _mod_list_re: RegEx
static var _bold_re: RegEx
static var _code_re: RegEx


static func parse(raw: String) -> Array:
	var text := raw if raw is String else ""
	if text.strip_edges() == "":
		return []
	_ensure_regex()
	var markers: Array = []
	for match in _callout_re.search_all(text):
		markers.append({
			"start": match.get_start(),
			"end": match.get_end(),
			"kind": "callout",
			"callout_type": match.get_string(1),
			"body": match.get_string(2).strip_edges(),
		})
	for match in _flow_re.search_all(text):
		markers.append({
			"start": match.get_start(),
			"end": match.get_end(),
			"kind": "flow",
			"flow_type": match.get_string(1),
			"body": match.get_string(2).strip_edges(),
		})
	for match in _showcase_re.search_all(text):
		markers.append({
			"start": match.get_start(),
			"end": match.get_end(),
			"kind": "showcase",
			"showcase_kind": match.get_string(1),
			"params": _parse_showcase_params(match.get_string(2)),
		})
	for match in _mod_list_re.search_all(text):
		markers.append({
			"start": match.get_start(),
			"end": match.get_end(),
			"kind": "mod_list",
			"params": _parse_showcase_params(match.get_string(1)),
		})
	markers.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return int(a.get("start", 0)) < int(b.get("start", 0))
	)
	var segments: Array = []
	var last_end := 0
	for marker in markers:
		var start := int(marker.get("start", 0))
		if start > last_end:
			segments.append(_text_segment(text.substr(last_end, start - last_end)))
		if marker.get("kind") == "callout":
			segments.append({
				"type": "callout",
				"callout_type": str(marker.get("callout_type", "info")),
				"text": str(marker.get("body", "")),
			})
		elif str(marker.get("flow_type", "")) == "split":
			segments.append(_split_flow_segment(str(marker.get("body", ""))))
		elif str(marker.get("flow_type", "")) == "branch":
			segments.append(_branch_flow_segment(str(marker.get("body", ""))))
		elif marker.get("kind") == "showcase":
			segments.append({
				"type": "showcase",
				"showcase_kind": str(marker.get("showcase_kind", "")),
				"params": marker.get("params", {}),
			})
		elif marker.get("kind") == "mod_list":
			segments.append({
				"type": "mod_list",
				"params": marker.get("params", {}),
			})
		else:
			segments.append(_linear_flow_segment(str(marker.get("body", ""))))
		last_end = int(marker.get("end", 0))
	if last_end < text.length():
		segments.append(_text_segment(text.substr(last_end)))
	if segments.is_empty():
		segments.append(_text_segment(text))
	return segments


## Converts accidental Markdown in help copy to BBCode (RichTextLabel does not parse ** or `).
static func normalize_inline_markup(text: String) -> String:
	var raw := text if text is String else ""
	if raw.strip_edges() == "":
		return raw
	_ensure_inline_markup_regex()
	var result := _bold_re.sub(raw, "[b]$1[/b]", true)
	return _code_re.sub(result, "[color=#{muted}]$1[/color]", true)


static func strip_callouts(raw: String) -> String:
	var text := raw if raw is String else ""
	if text.strip_edges() == "":
		return ""
	_ensure_regex()
	text = _callout_re.sub(text, "", true)
	text = _flow_re.sub(text, "", true)
	text = _showcase_re.sub(text, "", true)
	text = _mod_list_re.sub(text, "", true)
	return text


static func _linear_flow_segment(body: String) -> Dictionary:
	var steps: Array = []
	for line in body.split("\n", false):
		var step := _parse_step_line(line)
		if not step.is_empty():
			steps.append(step)
	return {"type": "flow", "flow_type": "linear", "steps": steps}


static func _split_flow_segment(body: String) -> Dictionary:
	var left: Dictionary = {}
	var right: Dictionary = {}
	for line in body.split("\n", false):
		var trimmed := line.strip_edges()
		if trimmed.begins_with("left="):
			left = _parse_split_side(trimmed.substr(5))
		elif trimmed.begins_with("right="):
			right = _parse_split_side(trimmed.substr(6))
	return {"type": "flow", "flow_type": "split", "left": left, "right": right}


static func _branch_flow_segment(body: String) -> Dictionary:
	var hub: Dictionary = {}
	var arms: Array = []
	for line in body.split("\n", false):
		var side := _parse_split_side(line)
		if side.is_empty():
			continue
		if hub.is_empty():
			hub = side
		else:
			arms.append(side)
	return {"type": "flow", "flow_type": "branch", "hub": hub, "arms": arms}


static func _parse_step_line(line: String) -> Dictionary:
	var trimmed := line.strip_edges()
	if trimmed == "" or trimmed.begins_with("#"):
		return {}
	var parts := trimmed.split("|", false)
	if parts.size() < 3:
		return {}
	return {
		"icon": parts[0].strip_edges(),
		"color": parts[1].strip_edges(),
		"label": "|".join(parts.slice(2)).strip_edges(),
	}


static func _parse_showcase_params(raw: String) -> Dictionary:
	var out: Dictionary = {}
	var trimmed := raw.strip_edges()
	if trimmed == "":
		return out
	for token in trimmed.split(" ", false):
		var parts := token.split("=", false, 1)
		if parts.size() == 2:
			out[parts[0].strip_edges()] = parts[1].strip_edges()
	return out


static func _parse_split_side(payload: String) -> Dictionary:
	var parts := payload.split("|", false)
	if parts.size() < 4:
		return {}
	return {
		"icon": parts[0].strip_edges(),
		"color": parts[1].strip_edges(),
		"title": parts[2].strip_edges(),
		"subtitle": "|".join(parts.slice(3)).strip_edges(),
	}


static func _text_segment(chunk: String) -> Dictionary:
	return {"type": "text", "text": chunk.strip_edges()}


static func _ensure_regex() -> void:
	if _callout_re != null:
		return
	_callout_re = RegEx.new()
	_callout_re.compile("\\[callout\\s+(tip|info|warning)\\]([\\s\\S]*?)\\[/callout\\]")
	_flow_re = RegEx.new()
	_flow_re.compile("\\[flow\\s+(linear|split|branch)\\]([\\s\\S]*?)\\[/flow\\]")
	_showcase_re = RegEx.new()
	_showcase_re.compile("\\[showcase\\s+(\\w+)([^\\]]*)\\]")
	_mod_list_re = RegEx.new()
	_mod_list_re.compile("\\[mod_list([^\\]]*)\\]")


static func _ensure_inline_markup_regex() -> void:
	if _bold_re != null:
		return
	_bold_re = RegEx.new()
	_bold_re.compile("\\*\\*([^*]+)\\*\\*")
	_code_re = RegEx.new()
	_code_re.compile("`([^`]+)`")
