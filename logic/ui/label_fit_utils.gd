# logic/ui/label_fit_utils.gd
## Shrink Label font to fit width; if still tight, wrap a few lines instead of crushing the type.
extends RefCounted
class_name LabelFitUtils

const DEFAULT_MIN_FONT := 14
## Shrink at most to this fraction of the base size before enabling wrap.
const DEFAULT_SHRINK_FLOOR_RATIO := 0.78


static func fit_label(
		label: Label,
		max_width: float = -1.0,
		base_font: int = -1,
		min_font: int = DEFAULT_MIN_FONT,
		allow_wrap: bool = true,
		max_lines: int = 2,
		shrink_floor_ratio: float = DEFAULT_SHRINK_FLOOR_RATIO
	) -> int:
	if label == null or not is_instance_valid(label):
		return 0
	var text := String(label.text)
	if text.strip_edges() == "":
		return _current_font_size(label)

	var width := max_width
	if width <= 1.0:
		width = _resolve_width(label)
	if width <= 1.0:
		return _current_font_size(label)

	var max_fs := base_font if base_font > 0 else _current_font_size(label)
	if max_fs <= 0:
		max_fs = 16
	var min_fs := clampi(min_font, 8, max_fs)
	var shrink_floor := clampi(int(round(float(max_fs) * shrink_floor_ratio)), min_fs, max_fs)

	_reset_wrap(label)
	label.add_theme_font_size_override("font_size", max_fs)

	if _single_line_fits(label, text, width, max_fs):
		return max_fs

	# Phase 1: mild shrink, still one line.
	var chosen := _shrink_single_line(label, text, width, max_fs, shrink_floor)
	if _single_line_fits(label, text, width, chosen):
		label.add_theme_font_size_override("font_size", chosen)
		return chosen

	if not allow_wrap or max_lines <= 1:
		# Last resort: go down to min_font, then ellipsis.
		chosen = _shrink_single_line(label, text, width, chosen, min_fs)
		label.add_theme_font_size_override("font_size", chosen)
		if not _single_line_fits(label, text, width, chosen):
			label.clip_text = true
			label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		return chosen

	# Phase 2: wrap + light further shrink so type stays readable.
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.max_lines_visible = max_lines
	label.clip_text = true
	label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	chosen = _shrink_wrapped(label, text, width, chosen, min_fs, max_lines)
	label.add_theme_font_size_override("font_size", chosen)
	return chosen


## Convenience: fit several labels with the same width.
static func fit_labels(
		labels: Array,
		max_width: float = -1.0,
		base_font: int = -1,
		min_font: int = DEFAULT_MIN_FONT,
		allow_wrap: bool = true,
		max_lines: int = 2
	) -> void:
	for item in labels:
		if item is Label:
			fit_label(item as Label, max_width, base_font, min_font, allow_wrap, max_lines)


static func _resolve_width(label: Label) -> float:
	if label.size.x > 1.0:
		return label.size.x
	var parent := label.get_parent() as Control
	if parent and parent.size.x > 1.0:
		return parent.size.x
	return 0.0


static func _current_font_size(label: Label) -> int:
	if label.has_theme_font_size_override("font_size"):
		return label.get_theme_font_size("font_size")
	return label.get_theme_font_size("font_size")


static func _font_of(label: Label) -> Font:
	return label.get_theme_font("font")


static func _reset_wrap(label: Label) -> void:
	label.autowrap_mode = TextServer.AUTOWRAP_OFF
	label.max_lines_visible = -1
	label.clip_text = false
	label.text_overrun_behavior = TextServer.OVERRUN_NO_TRIMMING


static func _single_line_fits(label: Label, text: String, width: float, font_size: int) -> bool:
	var font := _font_of(label)
	if font == null:
		return true
	var measured := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
	return measured.x <= width + 0.5


static func _shrink_single_line(
		label: Label,
		text: String,
		width: float,
		from_size: int,
		to_size: int
	) -> int:
	var lo := mini(from_size, to_size)
	var hi := maxi(from_size, to_size)
	var best := lo
	while lo <= hi:
		var mid := (lo + hi) >> 1
		if _single_line_fits(label, text, width, mid):
			best = mid
			lo = mid + 1
		else:
			hi = mid - 1
	return best


static func _wrapped_fits(
		label: Label,
		text: String,
		width: float,
		font_size: int,
		max_lines: int
	) -> bool:
	var font := _font_of(label)
	if font == null:
		return true
	var measured := font.get_multiline_string_size(
		text,
		HORIZONTAL_ALIGNMENT_LEFT,
		width,
		font_size,
		-1,
		TextServer.BREAK_WORD_BOUND | TextServer.BREAK_MANDATORY
	)
	var line_h := float(font.get_height(font_size))
	if line_h <= 0.0:
		return measured.x <= width + 0.5
	var lines_used := int(ceil(measured.y / line_h))
	return lines_used <= max_lines and measured.x <= width + 0.5


static func _shrink_wrapped(
		label: Label,
		text: String,
		width: float,
		from_size: int,
		to_size: int,
		max_lines: int
	) -> int:
	var lo := mini(from_size, to_size)
	var hi := maxi(from_size, to_size)
	var best := lo
	while lo <= hi:
		var mid := (lo + hi) >> 1
		if _wrapped_fits(label, text, width, mid, max_lines):
			best = mid
			lo = mid + 1
		else:
			hi = mid - 1
	return best
