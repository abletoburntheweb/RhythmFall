extends VBoxContainer

# Discovery Tab — recommendation cards and tried section.

signal discovery_try_pressed(mods: Array, params: Dictionary)

var _rec_cards: Array = []
var _tried_cards: Array = []
var _current_song_path: String = ""
var _tried_title_label: Label = null
var _tried_row: HBoxContainer = null
var _separator: HSeparator = null
var _tried_section: VBoxContainer = null


func build(song_path: String = "") -> void:
	_current_song_path = song_path
	_clear_all()
	_build_ui()
	_populate_recommendations()
	_populate_tried()
	call_deferred("apply_locale")


func _clear_all() -> void:
	for c in _rec_cards:
		if is_instance_valid(c):
			c.queue_free()
	_rec_cards.clear()
	for c in _tried_cards:
		if is_instance_valid(c):
			c.queue_free()
	_tried_cards.clear()
	for child in get_children():
		child.queue_free()


func _build_ui() -> void:
	add_theme_constant_override("separation", 12)

	# --- Recommendation cards row ---
	var rec_row := HBoxContainer.new()
	rec_row.name = "RecommendationRow"
	rec_row.add_theme_constant_override("separation", 10)
	rec_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rec_row.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	add_child(rec_row)

	# --- Separator ---
	_separator = HSeparator.new()
	_separator.name = "Separator"
	_separator.add_theme_stylebox_override("separator", _make_separator_style())
	add_child(_separator)

	# --- Tried section ---
	_tried_section = VBoxContainer.new()
	_tried_section.name = "TriedSection"
	_tried_section.add_theme_constant_override("separation", 6)
	add_child(_tried_section)

	_tried_title_label = Label.new()
	_tried_title_label.name = "TriedTitleLabel"
	_tried_title_label.text = tr("MODREC_TRIED_TITLE")
	_tried_title_label.add_theme_font_size_override("font_size", 13)
	_tried_title_label.add_theme_color_override("font_color", Color(0.72, 0.78, 0.98, 0.9))
	_tried_section.add_child(_tried_title_label)

	_tried_row = HBoxContainer.new()
	_tried_row.name = "TriedRow"
	_tried_row.add_theme_constant_override("separation", 10)
	_tried_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_tried_section.add_child(_tried_row)


func _make_separator_style() -> StyleBoxLine:
	var s := StyleBoxLine.new()
	s.color = Color(1, 1, 1, 0.08)
	s.thickness = 1
	return s


func _populate_recommendations() -> void:
	var rec_row: HBoxContainer = get_node_or_null("RecommendationRow") as HBoxContainer
	if rec_row == null:
		return
	var candidates: Array = ModifierDiscovery.build(_current_song_path)
	if candidates.is_empty():
		_show_empty(rec_row)
		return
	var count := mini(candidates.size(), 3)
	for i in count:
		var cand: Dictionary = candidates[i]
		var card := DiscoveryCard.new()
		rec_row.add_child(card)
		_rec_cards.append(card)
		card.setup(cand)
		if not card.try_pressed.is_connected(_on_card_try):
			card.try_pressed.connect(_on_card_try)


func _populate_tried() -> void:
	var tried := _build_tried_data()
	_tried_section.visible = true
	if tried.is_empty():
		# Show empty state as a separate label below the title
		var empty_lbl := Label.new()
		empty_lbl.name = "TriedEmptyLabel"
		empty_lbl.text = tr("MODREC_TRIED_EMPTY")
		empty_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		empty_lbl.add_theme_color_override("font_color", TEXT_MUTED)
		empty_lbl.add_theme_font_size_override("font_size", 12)
		_tried_section.add_child(empty_lbl)
		_tried_row.visible = false
		return
	_tried_row.visible = true
	var count := mini(tried.size(), 3)
	for i in count:
		var entry: Dictionary = tried[i]
		var card := TriedRecommendationCard.new()
		_tried_row.add_child(card)
		_tried_cards.append(card)
		card.setup(
			str(entry.get("mod_id", "")),
			int(entry.get("attempts", 0)),
			float(entry.get("avg_accuracy", -1.0)),
			int(entry.get("best_rating", 0)),
		)


func _build_tried_data() -> Array:
	var result: Array = []
	var pdm = PlayerDataManager
	if pdm == null or not pdm.has_method("get_modifier_stats"):
		return result

	var svc = preload("res://logic/data/results_history_service.gd").new()
	var hist: Array = svc.get_history()
	if hist.is_empty():
		return result

	var mod_ids: Array[String] = [
		"hidden", "strict_timing", "no_fail", "mirror_mode",
		"sudden", "easy_windows", "fast_150", "slow_75",
	]

	for mod_id in mod_ids:
		var attempts := _count_mod_in_history(hist, mod_id)
		if attempts <= 0:
			continue
		var avg_acc := _avg_accuracy_for_mod(hist, mod_id)
		var best_rating := _best_rating_for_mod(hist, mod_id)
		result.append({
			"mod_id": mod_id,
			"attempts": attempts,
			"avg_accuracy": avg_acc,
			"best_rating": best_rating,
		})

	result.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return int(a.get("attempts", 0)) > int(b.get("attempts", 0))
	)
	return result.slice(0, 3)


func _count_mod_in_history(hist: Array, mod_id: String) -> int:
	var count := 0
	for s in hist:
		var mods: Array = s.get("modifiers", [])
		for m in mods:
			if str(m) == mod_id:
				count += 1
				break
	return count


func _avg_accuracy_for_mod(hist: Array, mod_id: String) -> float:
	var sum := 0.0
	var n := 0
	for s in hist:
		var mods: Array = s.get("modifiers", [])
		for m in mods:
			if str(m) == mod_id:
				sum += _normalize_history_accuracy(float(s.get("accuracy", 0)))
				n += 1
				break
	if n <= 0:
		return -1.0
	return sum / float(n)


## Нормализация как в tried_recommendation_card / series_finish:
## поддерживает 0-1, 0-100, 0-10000.
static func _normalize_history_accuracy(raw: float) -> float:
	if raw < 0.0:
		return raw
	if raw >= 0.0 and raw <= 1.5:
		return clampf(raw * 100.0, 0.0, 100.0)
	if raw > 1000.0:
		return clampf(raw / 100.0, 0.0, 100.0)
	return clampf(raw, 0.0, 100.0)


func _best_rating_for_mod(hist: Array, mod_id: String) -> int:
	var best := 0
	for s in hist:
		var mods: Array = s.get("modifiers", [])
		for m in mods:
			if str(m) == mod_id:
				var r: int = int(s.get("chart_rating", 0))
				if r > best:
					best = r
				break
	return best


func _show_empty(container: Control) -> void:
	var lbl := Label.new()
	lbl.text = tr("MODREC_EMPTY")
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lbl.add_theme_color_override("font_color", TEXT_MUTED)
	lbl.add_theme_font_size_override("font_size", 13)
	container.add_child(lbl)
	_rec_cards.append(lbl)


func apply_locale() -> void:
	if _tried_title_label:
		_tried_title_label.text = tr("MODREC_TRIED_TITLE")


func _on_card_try(mods: Array, params: Dictionary) -> void:
	discovery_try_pressed.emit(mods, params)


const TEXT_MUTED := Color(0.58, 0.64, 0.74, 0.92)
