# scenes/song_select/rhythm_dna/rhythm_dna_timeline_panel.gd
extends VBoxContainer
class_name RhythmDnaTimelinePanel

const MAX_COLLAPSED := 5

const _UiModifierSounds = preload("res://logic/ui/ui_modifier_sounds.gd")

var _timeline: Array = []
var _total_duration: float = 1.0
var _expanded := false
var _list_host: VBoxContainer
var _toggle: Button


func _ready() -> void:
	add_theme_constant_override("separation", 8)


func setup(timeline: Array, total_duration: float) -> void:
	_timeline = timeline
	_total_duration = maxf(1.0, total_duration)
	_build()


func _build() -> void:
	for child in get_children():
		child.free()
	add_child(_build_bar())
	_list_host = VBoxContainer.new()
	_list_host.add_theme_constant_override("separation", 6)
	add_child(_list_host)
	_populate_list()
	if _timeline.size() > MAX_COLLAPSED:
		_toggle = Button.new()
		_toggle.flat = true
		_toggle.focus_mode = Control.FOCUS_NONE
		_toggle.pressed.connect(_on_toggle_pressed)
		add_child(_toggle)
		_update_toggle_text()


func _populate_list() -> void:
	if _list_host == null:
		return
	for child in _list_host.get_children():
		child.free()
	var indices := _visible_indices()
	for idx in indices:
		var seg: Variant = _timeline[idx]
		if seg is Dictionary:
			_list_host.add_child(RhythmDnaDialogContent.build_timeline_row(seg as Dictionary))


func _visible_indices() -> Array:
	var n := _timeline.size()
	if _expanded or n <= MAX_COLLAPSED:
		var all: Array = []
		for i in range(n):
			all.append(i)
		return all
	var out: Array = []
	for i in range(MAX_COLLAPSED):
		out.append(i)
	return out


func _on_toggle_pressed() -> void:
	_expanded = not _expanded
	_UiModifierSounds.play_toggle(_expanded)
	_populate_list()
	_update_toggle_text()


func _update_toggle_text() -> void:
	if _toggle == null:
		return
	var hidden := _timeline.size() - MAX_COLLAPSED
	if _expanded:
		_toggle.text = TranslationServer.translate("DNA_UI_TIMELINE_COLLAPSE")
	else:
		_toggle.text = TranslationServer.translate("DNA_UI_TIMELINE_EXPAND_FMT") % hidden


func _build_bar() -> Control:
	return RhythmDnaDialogContent.build_timeline_bar(_timeline, _total_duration)
