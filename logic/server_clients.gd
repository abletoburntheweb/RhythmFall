# logic/server_clients.gd
extends Node
class_name ServerClients

signal bpm_analysis_started
signal bpm_analysis_completed(bpm: int)
signal bpm_analysis_error(message: String)

signal genres_detection_completed(artist: String, title: String, genres: Array)
signal genres_detection_error(message: String)

signal notes_generation_started
signal notes_generation_completed(notes: Array, bpm: float, instrument: String)
signal notes_generation_error(message: String)
signal manual_identification_needed(path: String)

var bpm_client: Node
var genre_client: Node
var note_client: Node

func _ready():
	bpm_client = preload("res://server/bpm_analyzer_client.gd").new()
	bpm_client.bpm_analysis_started.connect(_on_bpm_started)
	bpm_client.bpm_analysis_completed.connect(_on_bpm_completed)
	bpm_client.bpm_analysis_error.connect(_on_bpm_error)
	add_child(bpm_client)
	
	genre_client = preload("res://server/genre_detector_client.gd").new()
	genre_client.genres_detection_completed.connect(_on_genres_completed)
	genre_client.genres_detection_error.connect(_on_genres_error)
	add_child(genre_client)
	
	note_client = preload("res://server/note_generator_client.gd").new()
	note_client.notes_generation_started.connect(_on_notes_started)
	note_client.notes_generation_completed.connect(_on_notes_completed)
	note_client.notes_generation_error.connect(_on_notes_error)
	note_client.manual_identification_needed.connect(_on_manual_identification)
	add_child(note_client)

func _on_bpm_started():
	bpm_analysis_started.emit()

func _on_bpm_completed(bpm: int):
	bpm_analysis_completed.emit(bpm)

func _on_bpm_error(message: String):
	bpm_analysis_error.emit(message)

func _on_genres_completed(artist: String, title: String, genres: Array):
	genres_detection_completed.emit(artist, title, genres)

func _on_genres_error(message: String):
	genres_detection_error.emit(message)

func _on_notes_started():
	notes_generation_started.emit()

func _on_notes_completed(notes: Array, bpm: float, instrument: String):
	notes_generation_completed.emit(notes, bpm, instrument)

func _on_notes_error(message: String):
	notes_generation_error.emit(message)

func _on_manual_identification(path: String):
	manual_identification_needed.emit(path)

func analyze_bpm(path: String):
	bpm_client.analyze_bpm(path)

func get_genres_for_manual_entry(artist: String, title: String):
	genre_client.get_genres_for_manual_entry(artist, title)

func generate_notes(path: String, instrument: String, bpm: float, lanes: int, tolerance: float, auto: bool, artist: String, title: String, mode: String):
	note_client.generate_notes(path, instrument, bpm, lanes, tolerance, auto, artist, title, mode)
