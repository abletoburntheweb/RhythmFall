# scenes/song_select/controllers/song_results_view.gd
# Results: left passport column + right best/history (mockup V1/V3).
extends HBoxContainer
class_name SongResultsView

const _SS = preload("res://logic/domain/library/song_select_strings.gd")

@onready var passport: SongMuseumPanel = $MuseumPassport
@onready var _best_header: Label = $MainColumn/BestBlock/BestHeader
@onready var _best_slot: VBoxContainer = $MainColumn/BestBlock/BestSlot
@onready var _history_header: Label = $MainColumn/HistoryBlock/HistoryHeader
@onready var _history_list: VBoxContainer = $MainColumn/HistoryBlock/HistoryScroll/HistoryList
@onready var _trunc_label: Label = $MainColumn/HistoryBlock/TruncLabel
@onready var _empty_label: Label = $MainColumn/EmptyLabel
@onready var _best_block: VBoxContainer = $MainColumn/BestBlock
@onready var _history_block: VBoxContainer = $MainColumn/HistoryBlock


func _ready() -> void:
	add_theme_constant_override("separation", 12)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	if _best_header:
		_best_header.add_theme_font_size_override("font_size", 15)
		_best_header.add_theme_color_override("font_color", Color(0.85, 0.76, 0.40, 1.0))
	if _history_header:
		_history_header.add_theme_font_size_override("font_size", 15)
		_history_header.add_theme_color_override("font_color", Color(0.72, 0.76, 0.84, 1.0))
	if _trunc_label:
		_trunc_label.add_theme_font_size_override("font_size", 12)
		_trunc_label.add_theme_color_override("font_color", Color(0.55, 0.58, 0.64, 1.0))
	if _empty_label:
		_empty_label.add_theme_font_size_override("font_size", 16)
		_empty_label.add_theme_color_override("font_color", Color(0.62, 0.66, 0.74, 1.0))
		_empty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_empty_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER


func clear_view() -> void:
	_clear_slot(_best_slot)
	_clear_slot(_history_list)
	if _trunc_label:
		_trunc_label.visible = false
		_trunc_label.text = ""
	if _empty_label:
		_empty_label.visible = false
	if _best_block:
		_best_block.visible = false
	if _history_block:
		_history_block.visible = false
	if passport:
		passport.clear_passport()


func show_empty() -> void:
	clear_view()
	if _empty_label:
		_empty_label.text = _SS._translate("SONG_RESULTS_NONE")
		_empty_label.visible = true


func show_filled(
	passport_data: Dictionary,
	best: Dictionary,
	history: Array,
	bind_row: Callable,
	history_footer: String = ""
) -> void:
	clear_view()
	if passport:
		passport.show_passport(passport_data)

	if _empty_label:
		_empty_label.visible = false

	if not best.is_empty() and _best_block and _best_slot:
		_best_block.visible = true
		_best_header.text = _SS._translate("SONG_RESULTS_BEST")
		var best_row := SongResultRow.new(true)
		_best_slot.add_child(best_row)
		bind_row.call(best_row, best, true)

	if _history_block and _history_list:
		_history_block.visible = true
		_history_header.text = _SS._translate("SONG_RESULTS_HISTORY")
		for item in history:
			if item is Dictionary:
				var row := SongResultRow.new(false)
				_history_list.add_child(row)
				bind_row.call(row, item, false)

	if history_footer.strip_edges() != "" and _trunc_label:
		_trunc_label.text = history_footer
		_trunc_label.visible = true


func _clear_slot(slot: Node) -> void:
	if slot == null:
		return
	for child in slot.get_children():
		child.queue_free()
