# scenes/song_select/rhythm_dna/rhythm_dna_dialog.gd
extends Control
class_name RhythmDnaDialog

signal closed

const _RhythmDnaDialogContent = preload("res://scenes/song_select/rhythm_dna/rhythm_dna_dialog_content.gd")
const _CoverLoader = preload("res://scenes/song_select/rhythm_dna/lib/rhythm_dna_cover_loader.gd")
const _UiIconHelper = preload("res://logic/ui/ui_icon_helper.gd")
const _HelpSectionUi = preload("res://logic/ui/settings_section_ui.gd")

@onready var _back_button: Button = $Container/BackButtonWrap/BackButton
@onready var _title_label: Label = $Container/TitleLabel
@onready var _subtitle_label: Label = $Container/SubtitleLabel
@onready var _content_host: VBoxContainer = $Container/BodyCenter/CardPanel/CardMargin/VBox/Scroll/ContentHost
@onready var _close_button: Button = $Container/BodyCenter/CardPanel/CardMargin/VBox/CloseButton

var _dna: Dictionary = {}
var _song_path: String = ""
var _cover: Texture2D = null


func _ready() -> void:
	UiIconHelper.configure_modal_overlay(self, 105)
	if _back_button:
		UiIconHelper.apply_standard_back_button(_back_button)
		_back_button.pressed.connect(_on_close_pressed)
	if _close_button:
		_close_button.theme_type_variation = &"FlatModalPrimaryButton"
		UiIconHelper.setup_confirm_button(_close_button)
		_close_button.pressed.connect(_on_close_pressed)
	_ensure_help_button()
	call_deferred("_ensure_help_button")
	_ensure_debug_buttons()
	set_process_input(true)
	call_deferred("apply_locale")
	if not _dna.is_empty():
		_refresh_body()
		_ensure_cover()


func setup(dna: Dictionary, song_path: String = "", cover: Texture2D = null) -> void:
	_dna = dna.duplicate(true) if dna is Dictionary else {}
	_song_path = song_path.strip_edges()
	_cover = cover
	if is_node_ready():
		_refresh_body()
		_ensure_cover()


func apply_locale() -> void:
	if _title_label:
		_title_label.text = tr("DNA_DIALOG_TITLE")
	if _subtitle_label:
		_subtitle_label.text = tr("DNA_DIALOG_SUBTITLE")
	if _back_button:
		_back_button.text = tr("BTN_BACK")
	if _close_button:
		_close_button.text = tr("BTN_OK")
	_ensure_help_button()
	_refresh_body()


func _ensure_cover() -> void:
	if _cover != null or _song_path == "":
		return
	call_deferred("_load_cover_deferred")


func _load_cover_deferred() -> void:
	if not is_instance_valid(self) or _cover != null or _song_path == "":
		return
	var loaded := _CoverLoader.load_cover(_song_path)
	if loaded == null:
		loaded = _CoverLoader.fallback_cover(_song_path)
	if loaded and is_instance_valid(self):
		_cover = loaded
		_refresh_body()


func _refresh_body() -> void:
	if _content_host == null:
		return
	for child in _content_host.get_children():
		child.free()
	var viewport_w := get_viewport_rect().size.x if is_inside_tree() else 1280.0
	var built: Control = _RhythmDnaDialogContent.build(_dna, _cover, viewport_w)
	_content_host.add_child(built)
	_update_debug_buttons()


func _ensure_debug_buttons() -> void:
	if not ProjectSettings.get_setting("debug/verbose_rhythm_dna", false):
		return
	var vbox := $Container/BodyCenter/CardPanel/CardMargin/VBox as VBoxContainer
	if vbox == null:
		return
	if vbox.get_node_or_null("DebugRfdRow") != null:
		return
	var row := HBoxContainer.new()
	row.name = "DebugRfdRow"
	row.add_theme_constant_override("separation", 8)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	var copy_btn := Button.new()
	copy_btn.text = "Copy .rfd path"
	copy_btn.tooltip_text = "Copy absolute .rfd path to clipboard"
	copy_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	copy_btn.pressed.connect(_on_copy_rfd_pressed)
	row.add_child(copy_btn)
	var open_btn := Button.new()
	open_btn.text = "Open folder"
	open_btn.tooltip_text = "Open folder containing .rfd"
	open_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	open_btn.pressed.connect(_on_open_rfd_folder_pressed)
	row.add_child(open_btn)
	# Insert before CloseButton (last child)
	var close_idx := vbox.get_child_count() - 1
	if close_idx < 0:
		vbox.add_child(row)
	else:
		vbox.add_child(row)
		vbox.move_child(row, close_idx)
	_update_debug_buttons()


func _update_debug_buttons() -> void:
	var vbox := $Container/BodyCenter/CardPanel/CardMargin/VBox as VBoxContainer
	if vbox == null:
		return
	var row := vbox.get_node_or_null("DebugRfdRow") as HBoxContainer
	if row == null:
		return
	var verbose := bool(ProjectSettings.get_setting("debug/verbose_rhythm_dna", false))
	row.visible = verbose
	if not verbose:
		return
	var rfd_path := _get_rfd_path_for_debug()
	row.visible = rfd_path != ""


func _get_rfd_path_for_debug() -> String:
	if _song_path.strip_edges() == "":
		return ""
	var track: Dictionary = _dna.get("track", {}) if _dna.get("track", {}) is Dictionary else {}
	var instrument := String(track.get("instrument", "drums")).strip_edges().to_lower()
	if instrument == "":
		instrument = "drums"
	var mode := String(track.get("mode", track.get("preset_id", ""))).strip_edges().to_lower()
	if mode == "":
		mode = "basic"
	var lanes: int = int(track.get("lanes", 4))
	var tag := String(track.get("chart_tag", "")).strip_edges()
	var rel := NotesUtils.rhythm_dna_path_for_mode_with_lanes(_song_path, instrument, mode, lanes, tag)
	# Fallback to chart path if mode path not found
	if rel == "" or not FileAccess.file_exists(DirectoryUtils.to_absolute(rel)):
		var chart_path := NotesUtils.resolve_existing_path(_song_path, instrument, mode, lanes, tag)
		if chart_path != "":
			rel = NotesUtils.rhythm_dna_path_for_chart(chart_path)
	return DirectoryUtils.to_absolute(rel) if rel != "" else ""


func _on_copy_rfd_pressed() -> void:
	var abs_path := _get_rfd_path_for_debug()
	if abs_path == "":
		return
	DisplayServer.clipboard_set(abs_path)
	var dock := get_tree().root.get_node_or_null("GameEngine/NotificationsLayer/StatusDock") as StatusDock
	if dock and dock.has_method("show_transient"):
		dock.show_transient("rfd_copy", "Скопировано: " + abs_path.get_file(), "info", 2.5)


func _on_open_rfd_folder_pressed() -> void:
	var abs_path := _get_rfd_path_for_debug()
	if abs_path == "":
		return
	var dir := abs_path.get_base_dir()
	if dir != "":
		OS.shell_open(dir)


func _on_close_pressed() -> void:
	closed.emit()
	queue_free()


func _ensure_help_button() -> void:
	# Spec: Generation Passport label in Rhythm DNA interface -> SubtitleLabel "Generation passport [?]"
	var target_label: Label = _subtitle_label if _subtitle_label != null and is_instance_valid(_subtitle_label) else _title_label
	if target_label == null or not is_instance_valid(target_label):
		return
	if target_label.has_meta("help_icon_btn"):
		var existing_meta: Variant = target_label.get_meta("help_icon_btn")
		if existing_meta is Button and is_instance_valid(existing_meta):
			(existing_meta as Button).tooltip_text = tr("HELP_LINK_RHYTHM_DNA")
			(existing_meta as Button).visible = true
			return
	var parent := target_label.get_parent()
	if parent == null:
		return
	var existing_btn := parent.get_node_or_null("HelpButton") as Button
	if existing_btn != null and is_instance_valid(existing_btn):
		existing_btn.tooltip_text = tr("HELP_LINK_RHYTHM_DNA")
		existing_btn.visible = true
		return
	var row_existing := parent.get_node_or_null("TitleHelpRow") as HBoxContainer
	if row_existing != null:
		var btn_in_row := row_existing.get_node_or_null("HelpButton") as Button
		if btn_in_row != null and is_instance_valid(btn_in_row):
			btn_in_row.tooltip_text = tr("HELP_LINK_RHYTHM_DNA")
			btn_in_row.visible = true
			return
	var legacy_row := parent.get_node_or_null("SubtitleLabelHelpRow") as HBoxContainer
	if legacy_row != null:
		var btn_legacy := legacy_row.get_node_or_null("HelpButton") as Button
		if btn_legacy != null and is_instance_valid(btn_legacy):
			btn_legacy.tooltip_text = tr("HELP_LINK_RHYTHM_DNA")
			return
	var legacy_title_row := parent.get_node_or_null("TitleLabelHelpRow") as HBoxContainer
	if legacy_title_row != null:
		var btn_legacy2 := legacy_title_row.get_node_or_null("HelpButton") as Button
		if btn_legacy2 != null and is_instance_valid(btn_legacy2):
			btn_legacy2.tooltip_text = tr("HELP_LINK_RHYTHM_DNA")
			return
	var btn := _HelpSectionUi.attach_help_icon_beside_label(
		target_label,
		tr("HELP_LINK_RHYTHM_DNA"),
		_on_help_pressed,
		true
	)
	if btn and is_instance_valid(btn):
		btn.name = "HelpButton"
		btn.visible = true


func _on_help_pressed() -> void:
	_open_help_item("rhythm_dna_overview")


func _open_help_item(item_id: String) -> void:
	var tree := get_tree()
	if tree == null:
		return
	var root: Node = tree.root.get_node_or_null("GameEngine") as Node
	if root and root.has_method("get_transitions"):
		var trans = root.get_transitions()
		if trans and trans.has_method("open_help_item"):
			trans.open_help_item(item_id)
			return
	var n: Node = self
	while n:
		if n.has_method("open_help_item"):
			n.open_help_item(item_id)
			return
		if n.has_method("get_transitions"):
			var t = n.get_transitions()
			if t and t.has_method("open_help_item"):
				t.open_help_item(item_id)
				return
		n = n.get_parent()
	if tree:
		for child in tree.root.get_children():
			if child.has_method("get_transitions"):
				var t2 = child.get_transitions()
				if t2 and t2.has_method("open_help_item"):
					t2.open_help_item(item_id)
					return


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		accept_event()
		_on_close_pressed()
