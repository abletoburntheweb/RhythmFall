# scenes/song_select/song_edit_manager.gd
class_name SongEditManager
extends Node

signal song_edited(song_data: Dictionary, item_list_index: int) # Изменили сигнатуру сигнала

var song_manager = null
var item_list: ItemList = null 

var edit_mode: bool = false

var song_metadata_manager = null

var _edit_context = {
	"dialog": null,
	"line_edit": null,
	"spin_box": null,
	"song_data": null, # Хранит оригинальные данные, полученные из SongListManager
	"field_name": null,
	"selected_index": -1, # Хранит индекс *в ItemList*, переданный из SongSelect
	"type": ""
}

func set_metadata_manager(sm_manager):
	song_metadata_manager = sm_manager
	if song_metadata_manager:
		print("SongEditManager.gd: SongMetadataManager установлен.")
	else:
		print("SongEditManager.gd: SongMetadataManager сброшен.")

func set_song_manager(manager):
	song_manager = manager

func set_item_list(list_control: ItemList):
	item_list = list_control

func set_edit_mode(enabled: bool):
	edit_mode = enabled
	print("SongEditManager.gd: Режим редактирования ", "ВКЛЮЧЕН" if edit_mode else "ВЫКЛЮЧЕН")

func is_edit_mode_active() -> bool:
	return edit_mode

func start_editing(field_type: String, song_data: Dictionary, selected_item_list_index: int): # Переименовали параметр
	if not edit_mode:
		print("SongEditManager.gd: Редактирование отключено.")
		return

	if not song_manager:
		printerr("SongEditManager.gd: SongManager не установлен!")
		return

	_edit_context["song_data"] = song_data.duplicate(true) # Копируем полученные данные
	_edit_context["selected_index"] = selected_item_list_index # Сохраняем индекс из ItemList
	_edit_context["field_name"] = field_type
	_edit_context["type"] = "field"  

	match field_type:
		"title":
			_edit_title()
		"artist":
			_edit_field("artist")
		"year":
			_edit_field("year")
		"bpm":
			_edit_bpm()
		"cover":
			_edit_cover_stub()
		_:
			print("SongEditManager.gd: Редактирование для поля '", field_type, "' не реализовано.")

func _edit_title():
	var song_data = _edit_context["song_data"]
	var old_title = song_data.get("title", "")

	_edit_context["type"] = "title"

	var dialog = AcceptDialog.new()
	dialog.title = "Редактировать название"
	dialog.dialog_text = "Введите новое название:"

	var line_edit = LineEdit.new()
	line_edit.text = old_title
	line_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_edit_context["line_edit"] = line_edit

	var vbox_container = VBoxContainer.new()
	vbox_container.add_child(line_edit)
	dialog.add_child(vbox_container)

	dialog.confirmed.connect(_on_edit_title_confirmed)
	dialog.close_requested.connect(_on_dialog_closed) 

	_edit_context["dialog"] = dialog

	add_child(dialog)
	dialog.popup_centered()

func _edit_field(field_name: String):
	var song_data = _edit_context["song_data"]
	var old_value = str(song_data.get(field_name, ""))

	_edit_context["type"] = "field"

	var dialog = AcceptDialog.new()
	dialog.title = "Редактировать " + field_name.capitalize()
	dialog.dialog_text = "Введите новое значение для '" + field_name + "':"

	var line_edit = LineEdit.new()
	line_edit.text = old_value
	line_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_edit_context["line_edit"] = line_edit

	var vbox_container = VBoxContainer.new()
	vbox_container.add_child(line_edit)
	dialog.add_child(vbox_container)

	dialog.confirmed.connect(_on_edit_field_confirmed)
	dialog.close_requested.connect(_on_dialog_closed)

	_edit_context["dialog"] = dialog

	add_child(dialog)
	dialog.popup_centered()

func _edit_bpm():
	var song_data = _edit_context["song_data"]
	var old_bpm = song_data.get("bpm", "Н/Д")
	var old_bpm_int = -1
	if old_bpm is int:
		old_bpm_int = old_bpm
	elif old_bpm is String and old_bpm.is_valid_int():
		old_bpm_int = old_bpm.to_int()

	_edit_context["type"] = "bpm"

	var dialog = AcceptDialog.new()
	dialog.title = "Редактировать BPM"
	dialog.dialog_text = "Введите новый BPM (60-200):"

	var spin_box = SpinBox.new()
	spin_box.set_min(60)
	spin_box.set_max(200)
	spin_box.set_step(1)
	spin_box.value = old_bpm_int if old_bpm_int != -1 else 120
	spin_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_edit_context["spin_box"] = spin_box

	var vbox_container = VBoxContainer.new()
	vbox_container.add_child(spin_box)
	dialog.add_child(vbox_container)

	dialog.confirmed.connect(_on_edit_bpm_confirmed)
	dialog.close_requested.connect(_on_dialog_closed)

	_edit_context["dialog"] = dialog

	add_child(dialog)
	dialog.popup_centered()

func _edit_cover_stub():
	print("SongEditManager.gd: Редактирование обложки пока не реализовано (двойной клик).")

func _on_edit_title_confirmed():
	var dialog = _edit_context["dialog"]
	var line_edit = _edit_context["line_edit"]
	var song_data = _edit_context["song_data"] # Берём из контекста
	var selected_item_list_index = _edit_context["selected_index"] # Берём индекс из контекста
	var old_title = song_data.get("title", "")

	if dialog and line_edit:
		var new_title = line_edit.text.strip_edges()
		if new_title != "" and new_title != old_title:
			# Обновляем копию данных
			song_data["title"] = new_title 
			# print("SongEditManager.gd: Название обновлено: '", old_title, "' -> '", new_title, "'")
			# Не обновляем ItemList напрямую, передаём индекс в сигнале
			emit_signal("song_edited", song_data, selected_item_list_index) # Передаём обновлённые данные и индекс в ItemList
			
			if song_metadata_manager:
				var song_file_path = song_data["path"]
				var fields_to_update = {"title": new_title}
				song_metadata_manager.update_metadata(song_file_path, fields_to_update)
				print("SongEditManager.gd: Изменения названия для '%s' переданы в SongMetadataManager для сохранения." % song_file_path)
			else:
				printerr("SongEditManager.gd: SongMetadataManager не установлен, изменения названия не сохранены в файл!")

	_cleanup_edit_context() 
	
func _on_edit_field_confirmed():
	var dialog = _edit_context["dialog"]
	var line_edit = _edit_context["line_edit"]
	var song_data = _edit_context["song_data"] # Берём из контекста
	var selected_item_list_index = _edit_context["selected_index"] # Берём индекс из контекста
	var field_name = _edit_context["field_name"]
	var old_value = str(song_data.get(field_name, ""))

	if dialog and line_edit and song_data and field_name:
		var new_value = line_edit.text.strip_edges()
		if new_value != old_value:
			# Обновляем копию данных
			song_data[field_name] = new_value 
			# print("SongEditManager.gd: Поле '", field_name, "' обновлено: '", old_value, "' -> '", new_value, "'")
			# Не обновляем ItemList напрямую, передаём индекс в сигнале
			emit_signal("song_edited", song_data, selected_item_list_index) # Передаём обновлённые данные и индекс в ItemList

			if song_metadata_manager:
				var song_file_path = song_data["path"]
				var fields_to_update = {field_name: new_value}
				song_metadata_manager.update_metadata(song_file_path, fields_to_update)
				print("SongEditManager.gd: Изменения поля '%s' для '%s' переданы в SongMetadataManager для сохранения." % [field_name, song_file_path])
			else:
				printerr("SongEditManager.gd: SongMetadataManager не установлен, изменения поля '%s' не сохранены в файл!" % field_name)

	_cleanup_edit_context() 
	
func _on_edit_bpm_confirmed():
	var dialog = _edit_context["dialog"]
	var spin_box = _edit_context["spin_box"]
	var song_data = _edit_context["song_data"] # Берём из контекста
	var selected_item_list_index = _edit_context["selected_index"] # Берём индекс из контекста
	var old_bpm = song_data.get("bpm", "Н/Д")
	var old_bpm_int = -1
	if old_bpm is int:
		old_bpm_int = old_bpm
	elif old_bpm is String and old_bpm.is_valid_int():
		old_bpm_int = old_bpm.to_int()

	if dialog and spin_box:
		var new_bpm_int = int(spin_box.value)
		if new_bpm_int != old_bpm_int:
			var new_bpm_str = str(new_bpm_int)
			# Обновляем копию данных
			song_data["bpm"] = new_bpm_str 
			# print("SongEditManager.gd: BPM обновлен: '", old_bpm, "' -> '", new_bpm_str, "'")
			# Не обновляем ItemList напрямую, передаём индекс в сигнале
			emit_signal("song_edited", song_data, selected_item_list_index) # Передаём обновлённые данные и индекс в ItemList
			
			if song_metadata_manager:
				var song_file_path = song_data["path"]
				var fields_to_update = {"bpm": new_bpm_str}
				song_metadata_manager.update_metadata(song_file_path, fields_to_update)
				print("SongEditManager.gd: Изменения BPM для '%s' переданы в SongMetadataManager для сохранения." % song_file_path)
			else:
				printerr("SongEditManager.gd: SongMetadataManager не установлен, изменения BPM не сохранены в файл!")

	_cleanup_edit_context()

func _cleanup_edit_context():
	if _edit_context["dialog"] and is_instance_valid(_edit_context["dialog"]):
		_edit_context["dialog"].queue_free()

	_edit_context["dialog"] = null
	_edit_context["line_edit"] = null
	_edit_context["spin_box"] = null
	_edit_context["song_data"] = null
	_edit_context["field_name"] = null
	_edit_context["selected_index"] = -1 # Сброс индекса
	_edit_context["type"] = ""

func _on_dialog_closed():
	_cleanup_edit_context() 
