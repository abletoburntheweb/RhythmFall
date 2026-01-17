# logic/sound_instrument_factory.gd
extends RefCounted 

const DEFAULT_KICK_PATH = "res://assets/shop/sounds/kick/kick_default.wav"
const DEFAULT_SNARE_PATH = "res://assets/shop/sounds/snare/snare_default.wav"

func get_sound_path_for_note(note_type: String, instrument: String) -> String:
	var sound_path = ""

	if instrument == "drums":
		if note_type == "KickNote":
			if MusicManager.active_kick_sound_path:
				sound_path = MusicManager.active_kick_sound_path
			else:
				sound_path = DEFAULT_KICK_PATH
		elif note_type == "SnareNote": 
			if MusicManager.active_snare_sound_path:
				sound_path = MusicManager.active_snare_sound_path
			else:
				sound_path = DEFAULT_SNARE_PATH

	if sound_path.is_empty():
		printerr("SoundInstrumentFactory: Не найден звук для типа ноты '%s' и инструмента '%s'. Используется заглушка." % [note_type, instrument])
		sound_path = "res://assets/audio/missing_sound.mp3"

	return sound_path
