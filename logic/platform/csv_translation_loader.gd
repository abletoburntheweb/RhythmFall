# logic/platform/csv_translation_loader.gd
extends RefCounted
class_name CsvTranslationLoader

const PerfTrace = preload("res://logic/utils/perf_trace.gd")

## Loads a Godot-style localization CSV (keys,en,ru,...) into TranslationServer at runtime.
## Avoids requiring generated *.translation files from the editor importer.

static var _loaded_by_path: Dictionary = {}


static func load_into_translation_server(csv_path: String) -> void:
	var _perf_cache_inv := PerfTrace.begin("perf.detail.song_select.run_modifiers.ready.data.translation.cache_invalidation")
	if _loaded_by_path.has(csv_path):
		var _cached_valid := true
		var _cached_list: Array = _loaded_by_path[csv_path]
		if _cached_list.is_empty():
			_cached_valid = false
		else:
			for _tr in _cached_list:
				if not (_tr is Translation):
					_cached_valid = false
					break
		if _cached_valid and FileAccess.file_exists(csv_path):
			PerfTrace.end("perf.detail.song_select.run_modifiers.ready.data.translation.cache_invalidation", _perf_cache_inv)
			return
		for old_translation in _loaded_by_path[csv_path]:
			if old_translation is Translation:
				TranslationServer.remove_translation(old_translation)
		_loaded_by_path.erase(csv_path)
	PerfTrace.end("perf.detail.song_select.run_modifiers.ready.data.translation.cache_invalidation", _perf_cache_inv)
	var _perf_file_read := PerfTrace.begin("perf.detail.song_select.run_modifiers.ready.data.translation.file_read")
	if not FileAccess.file_exists(csv_path):
		PerfTrace.end("perf.detail.song_select.run_modifiers.ready.data.translation.file_read", _perf_file_read)
		push_warning("CsvTranslationLoader: missing %s" % csv_path)
		return
	var text := FileAccess.open(csv_path, FileAccess.READ).get_as_text()
	PerfTrace.end("perf.detail.song_select.run_modifiers.ready.data.translation.file_read", _perf_file_read)
	var _perf_csv_parse := PerfTrace.begin("perf.detail.song_select.run_modifiers.ready.data.translation.csv_parse")
	var rows := _parse_csv_records(text)
	PerfTrace.end("perf.detail.song_select.run_modifiers.ready.data.translation.csv_parse", _perf_csv_parse)
	if rows.is_empty():
		return

	var header: PackedStringArray = rows[0]
	if header.size() < 2:
		push_warning("CsvTranslationLoader: invalid header in %s" % csv_path)
		return

	var _perf_create := PerfTrace.begin("perf.detail.song_select.run_modifiers.ready.data.translation.translation_create")
	var locale_columns: Dictionary = {}
	var created: Array = []
	for col in range(1, header.size()):
		var locale_code := String(header[col]).strip_edges().to_lower()
		if locale_code.is_empty() or locale_code.begins_with("_"):
			continue
		if locale_code.length() > 2:
			locale_code = locale_code.substr(0, 2)
		var translation := Translation.new()
		translation.locale = locale_code
		TranslationServer.add_translation(translation)
		locale_columns[col] = translation
		created.append(translation)
	PerfTrace.end("perf.detail.song_select.run_modifiers.ready.data.translation.translation_create", _perf_create)

	if locale_columns.is_empty():
		push_warning("CsvTranslationLoader: no locale columns in %s" % csv_path)
		return

	var _perf_messages := PerfTrace.begin("perf.detail.song_select.run_modifiers.ready.data.translation.translation_messages")
	for row_index in range(1, rows.size()):
		var cells: PackedStringArray = rows[row_index]
		if cells.is_empty():
			continue
		var key := String(cells[0]).strip_edges()
		if key.is_empty():
			continue
		for col in locale_columns.keys():
			if col >= cells.size():
				continue
			var _perf_cleanup := PerfTrace.begin("perf.detail.song_select.run_modifiers.ready.data.translation.message_cleanup")
			var value := _sanitize_unicode(_unescape_translation(String(cells[col])))
			PerfTrace.end("perf.detail.song_select.run_modifiers.ready.data.translation.message_cleanup", _perf_cleanup)
			var _perf_add := PerfTrace.begin("perf.detail.song_select.run_modifiers.ready.data.translation.add_message")
			var translation: Translation = locale_columns[col]
			translation.add_message(key, value)
			PerfTrace.end("perf.detail.song_select.run_modifiers.ready.data.translation.add_message", _perf_add)
	PerfTrace.end("perf.detail.song_select.run_modifiers.ready.data.translation.translation_messages", _perf_messages)

	_loaded_by_path[csv_path] = created


static func _parse_csv_records(text: String) -> Array:
	var rows: Array = []
	var current_row: PackedStringArray = []
	var field := ""
	var in_quotes := false
	var i := 0
	while i < text.length():
		var c: String = text[i]
		if c == '"':
			if in_quotes and i + 1 < text.length() and text[i + 1] == '"':
				field += '"'
				i += 2
				continue
			in_quotes = not in_quotes
			i += 1
			continue
		if c == "," and not in_quotes:
			current_row.append(field)
			field = ""
			i += 1
			continue
		if (c == "\n" or c == "\r") and not in_quotes:
			current_row.append(field)
			field = ""
			if not current_row.is_empty() or rows.is_empty():
				rows.append(current_row)
			current_row = []
			if c == "\r" and i + 1 < text.length() and text[i + 1] == "\n":
				i += 2
			else:
				i += 1
			continue
		field += c
		i += 1

	if not field.is_empty() or not current_row.is_empty():
		current_row.append(field)
	if not current_row.is_empty():
		rows.append(current_row)
	return rows


static func _unescape_translation(value: String) -> String:
	var result := value
	while "\\n" in result:
		result = result.replace("\\n", "\n")
	while "\\t" in result:
		result = result.replace("\\t", "\t")
	return result


static func _sanitize_unicode(text: String) -> String:
	if text.is_empty():
		return text
	var parts: PackedStringArray = []
	var i := 0
	while i < text.length():
		var cp := text.unicode_at(i)
		if cp >= 0xD800 and cp <= 0xDBFF:
			if i + 1 < text.length():
				var cp2 := text.unicode_at(i + 1)
				if cp2 >= 0xDC00 and cp2 <= 0xDFFF:
					parts.append(text.substr(i, 2))
					i += 2
					continue
			i += 1
			continue
		if cp >= 0xDC00 and cp <= 0xDFFF:
			i += 1
			continue
		parts.append(String.chr(cp))
		i += 1
	return "".join(parts)
