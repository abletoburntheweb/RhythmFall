# logic/domain/editor/chart_editor_commands.gd
extends RefCounted
class_name ChartEditorCommands

# Command pattern for undo/redo + corrections mapping.

class EditorCommand extends RefCounted:
	var label: String = ""
	func do(state: ChartEditorState) -> String:
		return ""
	func undo(state: ChartEditorState) -> String:
		return ""

class AddNoteCommand extends EditorCommand:
	var time: float
	var lane: int
	var drum: String
	var added_key: String = ""
	func _init(p_time: float, p_lane: int, p_drum: String) -> void:
		label = "Add"
		time = p_time
		lane = p_lane
		drum = p_drum
	func do(state: ChartEditorState) -> String:
		var n := EditorNoteUtils.make_note(time, lane, drum, state.lanes)
		if state.grid and state.snap_enabled:
			n["time"] = state.grid.snap_time(float(n["time"]), state.snap_division)
		state.document.notes.append(n)
		state.document.notes = EditorNoteUtils.sort_by_time(state.document.notes)
		added_key = EditorNoteUtils.note_key(n)
		state.select_only([added_key])
		return ""
	func undo(state: ChartEditorState) -> String:
		var keys := {added_key: true}
		state.document.remove_notes_by_keys(keys)
		state.clear_selection()
		return ""

class DeleteNotesCommand extends EditorCommand:
	var keys: Array[String] = []
	var removed_notes: Array = []
	func _init(p_keys: Array) -> void:
		label = "Delete %d" % p_keys.size()
		for k in p_keys:
			keys.append(String(k))
	func do(state: ChartEditorState) -> String:
		removed_notes.clear()
		var keep: Array = []
		for n in state.document.notes:
			var k := EditorNoteUtils.note_key(n as Dictionary)
			if k in keys:
				removed_notes.append((n as Dictionary).duplicate(true))
			else:
				keep.append(n)
		state.document.notes = keep
		state.clear_selection()
		return ""
	func undo(state: ChartEditorState) -> String:
		for n in removed_notes:
			state.document.notes.append(n)
		state.document.notes = EditorNoteUtils.sort_by_time(state.document.notes)
		state.select_only(keys)
		return ""

class MoveNotesCommand extends EditorCommand:
	var keys: Array[String] = []
	var delta_t: float = 0.0
	var delta_lane: int = 0
	var snap_div: int = 0
	var before_snapshot: Array = []
	func _init(p_keys: Array, p_delta_t: float, p_delta_lane: int = 0, p_snap_div: int = 0) -> void:
		label = "Move"
		for k in p_keys:
			keys.append(String(k))
		delta_t = p_delta_t
		delta_lane = p_delta_lane
		snap_div = p_snap_div
	func do(state: ChartEditorState) -> String:
		before_snapshot = EditorNoteUtils.clone_notes(state.document.notes)
		var key_set: Dictionary = {}
		for k in keys:
			key_set[k] = true
		var new_keys: Array[String] = []
		for n in state.document.notes:
			var k := EditorNoteUtils.note_key(n as Dictionary)
			if key_set.has(k):
				var nt := float(n.get("time", 0.0)) + delta_t
				if snap_div > 0 and state.grid:
					nt = state.grid.snap_time(nt, snap_div)
				nt = EditorNoteUtils.sanitize_time(nt)
				n["time"] = nt
				if delta_lane != 0:
					var nl := int(n.get("lane", 0)) + delta_lane
					n["lane"] = float(EditorNoteUtils.sanitize_lane(nl, state.lanes))
				new_keys.append(EditorNoteUtils.note_key(n as Dictionary))
		state.document.notes = EditorNoteUtils.sort_by_time(state.document.notes)
		state.select_only(new_keys)
		return ""
	func undo(state: ChartEditorState) -> String:
		state.document.notes = EditorNoteUtils.clone_notes(before_snapshot)
		state.select_only(keys)
		return ""

class ReclassNotesCommand extends EditorCommand:
	var keys: Array[String] = []
	var new_drum: String = "kick"
	var _indices: Array[int] = []
	var _old_drums: Array[String] = []
	func _init(p_keys: Array, p_drum: String) -> void:
		label = "Reclass to %s" % p_drum
		for k in p_keys:
			keys.append(String(k))
		new_drum = EditorNoteUtils.sanitize_drum(p_drum)
	func do(state: ChartEditorState) -> String:
		_indices.clear()
		_old_drums.clear()
		var key_set: Dictionary = {}
		for k in keys:
			key_set[k] = true
		var new_keys: Array[String] = []
		for i in range(state.document.notes.size()):
			var n: Dictionary = state.document.notes[i]
			var k := EditorNoteUtils.note_key(n)
			if key_set.has(k):
				_indices.append(i)
				_old_drums.append(String(n.get("drum", "kick")))
				n["drum"] = new_drum
				new_keys.append(EditorNoteUtils.note_key(n))
		# Keys changed (drum in key) — rebuild selection.
		state.select_only(new_keys)
		return ""
	func undo(state: ChartEditorState) -> String:
		# Restore by stable indices recorded at do() time; order unchanged by reclass.
		for idx in range(_indices.size()):
			var i: int = _indices[idx]
			if i >= 0 and i < state.document.notes.size():
				var n: Dictionary = state.document.notes[i]
				n["drum"] = _old_drums[idx]
		state.document.notes = EditorNoteUtils.sort_by_time(state.document.notes)
		# Restore original selection keys.
		state.select_only(keys)
		return ""

class QuantizeNotesCommand extends EditorCommand:
	var keys: Array[String] = []
	var division: int = 16
	var before_snapshot: Array = []
	func _init(p_keys: Array, p_div: int) -> void:
		label = "Quantize 1/%d" % p_div
		for k in p_keys:
			keys.append(String(k))
		division = p_div
	func do(state: ChartEditorState) -> String:
		before_snapshot = EditorNoteUtils.clone_notes(state.document.notes)
		if state.grid == null or division <= 0:
			return ""
		var key_set: Dictionary = {}
		for k in keys:
			key_set[k] = true
		var new_keys: Array[String] = []
		for n in state.document.notes:
			var k := EditorNoteUtils.note_key(n as Dictionary)
			if key_set.has(k):
				var nt := state.grid.snap_time(float(n.get("time", 0.0)), division)
				n["time"] = EditorNoteUtils.sanitize_time(nt)
				new_keys.append(EditorNoteUtils.note_key(n as Dictionary))
		# Do not dedupe — preserve count even if multiple notes snap to same lane/time (spec 5)
		# Sorting keeps visual order deterministic; overlapping notes will share position but remain distinct entries
		state.document.notes = EditorNoteUtils.sort_by_time(state.document.notes)
		state.select_only(new_keys)
		return ""
	func undo(state: ChartEditorState) -> String:
		state.document.notes = EditorNoteUtils.clone_notes(before_snapshot)
		# Restore original selection (spec 3)
		state.select_only(keys)
		return ""

class PasteNotesCommand extends EditorCommand:
	var clipboard: Array = []
	var at_time: float = 0.0
	var added_keys: Array[String] = []
	func _init(p_clipboard: Array, p_at_time: float) -> void:
		label = "Paste %d" % p_clipboard.size()
		clipboard = EditorNoteUtils.clone_notes(p_clipboard)
		at_time = p_at_time
	func do(state: ChartEditorState) -> String:
		if clipboard.is_empty():
			return ""
		var min_t := 1e9
		for n in clipboard:
			min_t = minf(min_t, float(n.get("time", 0.0)))
		if min_t >= 1e9:
			min_t = 0.0
		added_keys.clear()
		for n in clipboard:
			var nt := float(n.get("time", 0.0)) - min_t + at_time
			if state.snap_enabled and state.grid and state.snap_division > 0:
				nt = state.grid.snap_time(nt, state.snap_division)
			var nn := EditorNoteUtils.make_note(nt, int(n.get("lane", 0)), String(n.get("drum", "kick")), state.lanes)
			state.document.notes.append(nn)
			added_keys.append(EditorNoteUtils.note_key(nn))
		state.document.notes = EditorNoteUtils.sort_by_time(state.document.notes)
		state.select_only(added_keys)
		return ""
	func undo(state: ChartEditorState) -> String:
		var kill: Dictionary = {}
		for k in added_keys:
			kill[k] = true
		state.document.remove_notes_by_keys(kill)
		state.clear_selection()
		return ""

class DuplicateNotesCommand extends EditorCommand:
	var keys: Array[String] = []
	var duplicated_keys: Array[String] = []
	var offset_t: float = 0.0
	func _init(p_keys: Array) -> void:
		label = "Duplicate %d" % p_keys.size()
		for k in p_keys:
			keys.append(String(k))
	func do(state: ChartEditorState) -> String:
		if keys.is_empty():
			return "no selection"
		duplicated_keys.clear()
		# Collect notes to duplicate.
		var to_dup: Array = []
		var min_t := 1e9
		var max_t := -1e9
		for n in state.document.notes:
			var k := EditorNoteUtils.note_key(n as Dictionary)
			if k in keys:
				to_dup.append((n as Dictionary).duplicate(true))
				var t := float(n.get("time", 0.0))
				min_t = minf(min_t, t)
				max_t = maxf(max_t, t)
		if to_dup.is_empty():
			return "no matching notes"
		# Offset = one beat (or 0.5s fallback) to keep relative intervals.
		if offset_t == 0.0:
			if state.grid and state.grid.beat_interval > 0.0:
				offset_t = state.grid.beat_interval
			else:
				offset_t = 0.5
			# If snap enabled, quantize offset to snap grid? Keep beat offset.
		for n in to_dup:
			var nt := float(n.get("time", 0.0)) + offset_t
			if state.snap_enabled and state.grid and state.snap_division > 0:
				nt = state.grid.snap_time(nt, state.snap_division)
			var nn := EditorNoteUtils.make_note(nt, int(n.get("lane", 0)), String(n.get("drum", "kick")), state.lanes)
			state.document.notes.append(nn)
			duplicated_keys.append(EditorNoteUtils.note_key(nn))
		state.document.notes = EditorNoteUtils.sort_by_time(state.document.notes)
		state.select_only(duplicated_keys)
		return ""
	func undo(state: ChartEditorState) -> String:
		var kill: Dictionary = {}
		for k in duplicated_keys:
			kill[k] = true
		state.document.remove_notes_by_keys(kill)
		state.clear_selection()
		# Restore original selection.
		state.select_only(keys)
		return ""

class AddPatternNotesCommand extends EditorCommand:
	var notes_to_add: Array = []
	var added_keys: Array[String] = []
	var pattern_id: String = ""
	func _init(p_notes: Array, p_pattern_id: String = "") -> void:
		label = "Add Pattern %d" % p_notes.size()
		notes_to_add = p_notes.duplicate(true)
		pattern_id = p_pattern_id
	func do(state: ChartEditorState) -> String:
		if notes_to_add.is_empty():
			return "no notes"
		added_keys.clear()
		for n in notes_to_add:
			if not n is Dictionary:
				continue
			var nn: Dictionary = (n as Dictionary).duplicate(true)
			# Ensure type
			nn["type"] = "DrumNote"
			state.document.notes.append(nn)
			added_keys.append(EditorNoteUtils.note_key(nn))
		state.document.notes = EditorNoteUtils.sort_by_time(state.document.notes)
		state.select_only(added_keys)
		return ""
	func undo(state: ChartEditorState) -> String:
		var kill: Dictionary = {}
		for k in added_keys:
			kill[k] = true
		state.document.remove_notes_by_keys(kill)
		state.clear_selection()
		return ""

class UndoStack extends RefCounted:
	var stack: Array[EditorCommand] = []
	var cursor: int = -1 # points to last done command. -1 = clean (no commands done)
	var save_cursor: int = -1

	func can_undo() -> bool:
		return cursor >= 0

	func can_redo() -> bool:
		return cursor + 1 < stack.size()

	func push_and_do(cmd: EditorCommand, state: ChartEditorState) -> String:
		# Truncate redo branch.
		if cursor + 1 < stack.size():
			stack.resize(cursor + 1)
		var err := cmd.do(state)
		if err != "":
			return err
		stack.append(cmd)
		cursor += 1
		return ""

	func undo(state: ChartEditorState) -> String:
		if not can_undo():
			return "nothing to undo"
		var cmd := stack[cursor]
		var err := cmd.undo(state)
		if err != "":
			return err
		cursor -= 1
		return ""

	func redo(state: ChartEditorState) -> String:
		if not can_redo():
			return "nothing to redo"
		cursor += 1
		var cmd := stack[cursor]
		return cmd.do(state)

	func mark_saved() -> void:
		save_cursor = cursor

	func is_dirty() -> bool:
		return cursor != save_cursor

	func get_changes_count() -> int:
		return absi(cursor - save_cursor)

	func clear() -> void:
		stack.clear()
		cursor = -1
		save_cursor = -1
