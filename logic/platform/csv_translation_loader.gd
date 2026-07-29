# logic/utils/csv_translation_loader.gd
extends RefCounted
class_name CsvTranslationLoader

## Loads a Godot-style localization CSV (keys,en,ru,...) into TranslationServer at runtime.
## Avoids requiring generated *.translation files from the editor importer.

static var _loaded_by_path: Dictionary = {}


static func load_into_translation_server(csv_path: String) -> void:
	if _loaded_by_path.has(csv_path):
		for old_translation in _loaded_by_path[csv_path]:
			if old_translation is Translation:
				TranslationServer.remove_translation(old_translation)
		_loaded_by_path.erase(csv_path)
	if not FileAccess.file_exists(csv_path):
		push_warning("CsvTranslationLoader: missing %s" % csv_path)
		return

	var text := FileAccess.open(csv_path, FileAccess.READ).get_as_text()
	var rows := _parse_csv_records(text)
	if rows.is_empty():
		return

	var header: PackedStringArray = rows[0]
	if header.size() < 2:
		push_warning("CsvTranslationLoader: invalid header in %s" % csv_path)
		return

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

	if locale_columns.is_empty():
		push_warning("CsvTranslationLoader: no locale columns in %s" % csv_path)
		return

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
			var value := _sanitize_unicode(_unescape_translation(String(cells[col])))
			var translation: Translation = locale_columns[col]
			translation.add_message(key, value)

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
