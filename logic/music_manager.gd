# logic/music_manager.gd
extends Node

const MUSIC_DIR = "res://assets/audio/"
const SHOP_SOUND_DIR = "res://assets/shop/sounds/"

const DEFAULT_MENU_MUSIC = "Tycho - Awake.mp3"
const DEFAULT_INTRO_MUSIC = "intro_music.mp3"
const DEFAULT_SELECT_SOUND = "select_click.mp3"
const DEFAULT_CANCEL_SOUND = "cancel_click.mp3"
const ANALYSIS_SUCCESS_SOUND = "analysis_success.wav"
const ANALYSIS_ERROR_SOUND = "analysis_error.wav"
const DEFAULT_ACHIEVEMENT_SOUND = "achievement_unlocked.mp3"
const SHOP_PURCHASE_SOUND = "shop_purchase.wav"
const SHOP_APPLY_SOUND = "shop_apply.wav"
const DEFAULT_DEFAULT_SHOP_SOUND = "missing_sound.mp3"
const DEFAULT_METRONOME_STRONG_SOUND = "metronome_strong.wav"
const DEFAULT_METRONOME_WEAK_SOUND = "metronome_weak.wav"
const DEFAULT_COVER_CLICK_SOUND = "page_flip.wav"
const DEFAULT_LEVEL_START_SOUND = "level_start_ripple.wav"
const DEFAULT_MISS_HIT_SOUND_1 = "miss_hit1.wav"
const DEFAULT_MISS_HIT_SOUND_2 = "miss_hit2.wav"
const DEFAULT_MISS_HIT_SOUND_3 = "miss_hit3.wav"
const DEFAULT_MISS_HIT_SOUND_4 = "miss_hit4.wav"
const DEFAULT_MISS_HIT_SOUND_5 = "miss_hit5.wav"

const DEFAULT_RESTART_SOUND = "restart_level.mp3"
const MODAL_POPUP_SOUND = "modal_popup.wav"

const DEFAULT_DRUMS_SELECT_SOUND = "drums_select.wav" 
const DEFAULT_STANDARD_SELECT_SOUND = "standard_select.wav"

var was_menu_music_playing_before_shop: bool = false
var menu_music_position_before_shop: float = 0.0

var music_player: AudioStreamPlayer = null
var sfx_player: AudioStreamPlayer = null
var hit_sound_player: AudioStreamPlayer = null
var metronome_player1: AudioStreamPlayer = null
var metronome_player2: AudioStreamPlayer = null

var metronome_active: bool = false
var _current_metronome_player_index: int = 0
var _metronome_players: Array[AudioStreamPlayer] = []

var active_kick_sound_path: String = ""
var active_snare_sound_path: String = ""

var current_menu_music_file: String = ""
var current_game_music_file: String = ""

var original_game_music_volume: float = 1.0

var _external_metronome_controlled: bool = false

var _last_beat_index: int = -1
var _menu_music_volume_pct: float = 50.0
var _game_music_volume_pct: float = 50.0
var _metronome_offset_sec: float = 0.0

func _ready():
	music_player = AudioStreamPlayer.new()
	music_player.name = "MusicPlayer"
	add_child(music_player)

	sfx_player = AudioStreamPlayer.new() 
	sfx_player.name = "SFXPlayer"
	add_child(sfx_player)

	hit_sound_player = AudioStreamPlayer.new()
	hit_sound_player.name = "HitSoundPlayer"
	add_child(hit_sound_player)

	metronome_player1 = AudioStreamPlayer.new()
	metronome_player1.name = "MetronomePlayer1"
	add_child(metronome_player1)

	metronome_player2 = AudioStreamPlayer.new()
	metronome_player2.name = "MetronomePlayer2"
	add_child(metronome_player2)

	_metronome_players = [metronome_player1, metronome_player2]
	_update_active_sound_paths()
	
func set_external_metronome_control(enabled: bool):
	_external_metronome_controlled = enabled
	if not enabled:
		_last_beat_index = -1  

func update_metronome(delta: float, game_time: float, bpm: float):
	if not _external_metronome_controlled or bpm <= 0:
		return
	var time_since_offset = game_time - _metronome_offset_sec
	if time_since_offset < 0.0:
		return

	var beat_interval = 60.0 / bpm
	var current_beat_index = int(floor(time_since_offset / beat_interval))
	var is_strong_beat = (current_beat_index % 4) == 0

	if current_beat_index != _last_beat_index:
		_last_beat_index = current_beat_index
		play_metronome_sound(is_strong_beat)

func set_metronome_offset(offset_sec: float):
	_metronome_offset_sec = max(0.0, offset_sec)


func get_volume_multiplier() -> float:
	if music_player:
		return db_to_linear(music_player.volume_db)
	return 1.0

func set_music_volume_multiplier(volume: float):
	if music_player:
		music_player.volume_db = linear_to_db(volume)

func get_game_music_position() -> float:
	if music_player and music_player.stream and current_game_music_file != "":
		if music_player.playing:
			return music_player.get_playback_position()
		else:
			return 0.0
	return 0.0

func stop_game_music():
	if music_player and music_player.stream and current_game_music_file != "":
		if music_player.playing:
			menu_music_position_before_shop = music_player.get_playback_position()
			music_player.stop()
			return
		else:
			menu_music_position_before_shop = 0.0
	else:
		pass 

func play_game_music_at_position(song_path: String, position: float):
	if FileAccess.file_exists(song_path):
		var stream = load(song_path) as AudioStream
		if stream:
			if music_player:
				current_game_music_file = song_path
				music_player.stream = stream
				if music_player.playing:
					music_player.stop()
				var game_vol = SettingsManager.get_music_volume() if SettingsManager.has_method("get_music_volume") else _game_music_volume_pct
				music_player.volume_db = linear_to_db(game_vol / 100.0)
				music_player.play(position)
			else:
				push_error("MusicManager.gd: music_player не установлен!")
		else:
			push_error("MusicManager.gd: Не удалось загрузить аудио для игры: " + song_path)
	else:
		push_error("MusicManager.gd: Файл игровой музыки не найден: " + song_path)

func pause_menu_music():
	if music_player and current_menu_music_file != "":
		if music_player.playing:
			was_menu_music_playing_before_shop = true
			menu_music_position_before_shop = music_player.get_playback_position() 
			music_player.stop() 
		else:
			was_menu_music_playing_before_shop = true
			menu_music_position_before_shop = 0.0
	else:
		pass 

func resume_menu_music():
	if current_menu_music_file != "":
		if was_menu_music_playing_before_shop:
			if not music_player.playing: 
				music_player.play(menu_music_position_before_shop)
			else:
				pass 
		else:
			if not music_player.playing:
				music_player.play(0.0) 
			else:
				pass 
	else:
		pass 
	was_menu_music_playing_before_shop = false
	menu_music_position_before_shop = 0.0

func _update_active_sound_paths():
	var active_kick_id = PlayerDataManager.get_active_item("Kick")
	var active_snare_id = PlayerDataManager.get_active_item("Snare")

	active_kick_sound_path = _get_sound_path_from_shop_data(active_kick_id, "Kick")
	if active_kick_sound_path == "":
		active_kick_sound_path = SHOP_SOUND_DIR + "kick/kick_default.wav"

	active_snare_sound_path = _get_sound_path_from_shop_data(active_snare_id, "Snare")
	if active_snare_sound_path == "":
		active_snare_sound_path = SHOP_SOUND_DIR + "snare/snare_default.wav"

func _get_sound_path_from_shop_data(item_id: String, category: String) -> String:
	var shop_data_file = FileAccess.open("res://data/shop_data.json", FileAccess.READ)
	if shop_data_file:
		var json_text = shop_data_file.get_as_text()
		shop_data_file.close()
		var json_result = JSON.parse_string(json_text)
		if json_result is Dictionary and json_result.has("items"):
			for item in json_result.items:
				if item.get("item_id", "") == item_id:
					var audio_path = item.get("audio", "")
					if audio_path != "":
						if not audio_path.begins_with("res://"):
							audio_path = SHOP_SOUND_DIR + audio_path
						return audio_path
	return ""

func set_active_kick_sound(path: String):
	active_kick_sound_path = path
	print("MusicManager: установлен активный кик-звук: ", path)

func set_active_snare_sound(path: String):
	active_snare_sound_path = path
	print("MusicManager: установлен активный снейр-звук: ", path)

func set_music_volume(volume: float):
	if music_player:
		_game_music_volume_pct = volume
		if current_game_music_file != "" or current_menu_music_file == "":
			music_player.volume_db = linear_to_db(volume / 100.0)

func set_menu_music_volume(volume: float):
	_menu_music_volume_pct = volume
	if music_player and current_menu_music_file != "":
		music_player.volume_db = linear_to_db(volume / 100.0)

func set_sfx_volume(volume: float):
	if sfx_player:
		sfx_player.volume_db = linear_to_db(volume / 100.0)

func set_hit_sounds_volume(volume: float): 
	if hit_sound_player: 
		hit_sound_player.volume_db = linear_to_db(volume / 100.0)

func set_metronome_volume(volume: float):
	for player in _metronome_players:
		if player: 
			player.volume_db = linear_to_db(volume / 100.0)

func play_menu_music(music_file: String = DEFAULT_MENU_MUSIC, restart: bool = false):
	var full_path = MUSIC_DIR + music_file
	var stream = load(full_path) as AudioStream
	if not stream:
		push_error("MusicManager: Не удалось загрузить аудио для меню: " + full_path)
		return

	if stream is AudioStreamMP3:
		stream.loop = true
	elif stream is AudioStreamWAV:
		stream.loop = true

	if music_player and music_player.stream == stream and not restart: 
		if music_player.playing:
			return 
		else:
			music_player.play() 
			return

	if music_player:
		current_menu_music_file = music_file
		current_game_music_file = ""
		music_player.stream = stream
		var menu_vol = SettingsManager.get_menu_music_volume() if SettingsManager.has_method("get_menu_music_volume") else _menu_music_volume_pct
		music_player.volume_db = linear_to_db(menu_vol / 100.0)
		music_player.play()

func play_game_music(music_file: String):
	if FileAccess.file_exists(music_file):
		var stream = load(music_file) as AudioStream
		if not stream:
			push_error("MusicManager: Не удалось загрузить аудио для игры: " + music_file)
			return

		if music_player:
			if music_player.stream == stream and music_player.playing:
				return

			current_game_music_file = music_file 
			music_player.stream = stream
			if music_player.playing:
				music_player.stop()
			var game_vol = SettingsManager.get_music_volume() if SettingsManager.has_method("get_music_volume") else _game_music_volume_pct
			music_player.volume_db = linear_to_db(game_vol / 100.0)
			music_player.play()
			original_game_music_volume = db_to_linear(music_player.volume_db)
			current_menu_music_file = ""
	else:
		push_error("MusicManager: Файл игровой музыки не найден: " + music_file)

func set_music_position(position: float):
	if music_player and music_player.stream:
		if music_player.playing:
			music_player.seek(position)
		else:
			music_player.play(position)
	else:
		push_error("MusicManager: Невозможно перемотать музыку. AudioStreamPlayer не установлен или нет аудио потока.")

func get_current_music_position() -> float:
	if music_player and music_player.playing:
		return music_player.get_playback_position()
	return 0.0

func stop_music():
	if music_player: 
		music_player.stop()
		current_menu_music_file = ""
		current_game_music_file = ""
		was_menu_music_playing_before_shop = false
		menu_music_position_before_shop = 0.0

func pause_music():
	if music_player and music_player.playing:
		menu_music_position_before_shop = music_player.get_playback_position()
		music_player.stop()

func resume_music():
	if music_player and not music_player.playing and music_player.stream: 
		var resume_pos = menu_music_position_before_shop if menu_music_position_before_shop > 0 else 0.0
		music_player.play(resume_pos)

func is_music_playing() -> bool:
	if music_player:
		return music_player.playing
	else:
		return false
		
func stop_metronome():
	for player in _metronome_players:
		if player and player.playing:
			player.stop()
			
func play_sfx(sound_path: String):
	var full_path = MUSIC_DIR + sound_path
	var stream = load(full_path) as AudioStream
	if stream:
		var new_player = AudioStreamPlayer.new()
		new_player.stream = stream
		if sfx_player:
			new_player.volume_db = sfx_player.volume_db
			
		add_child(new_player)
		
		new_player.finished.connect(Callable(self, "_on_sfx_player_finished").bind(new_player))
		
		new_player.play()
	else:
		push_error("MusicManager: Не удалось загрузить SFX: " + full_path)

func _on_sfx_player_finished(player: AudioStreamPlayer):
	if player and is_instance_valid(player):
		player.queue_free() 

func play_select_sound():
	play_sfx(DEFAULT_SELECT_SOUND)

func play_cancel_sound():
	play_sfx(DEFAULT_CANCEL_SOUND)
	
func play_analysis_success():
	play_sfx(ANALYSIS_SUCCESS_SOUND)

func play_analysis_error():
	play_sfx(ANALYSIS_ERROR_SOUND)

func play_modal_popup():
	play_sfx(MODAL_POPUP_SOUND)

func play_achievement_sound():
	play_sfx(DEFAULT_ACHIEVEMENT_SOUND)

func play_shop_purchase():
	play_sfx(SHOP_PURCHASE_SOUND)

func play_shop_apply():
	play_sfx(SHOP_APPLY_SOUND)
	
func play_default_shop_sound():
	play_sfx(DEFAULT_DEFAULT_SHOP_SOUND)
	
func play_cover_click_sound():
	play_sfx(DEFAULT_COVER_CLICK_SOUND)
	
func play_level_start_sound():
	play_sfx(DEFAULT_LEVEL_START_SOUND)

func play_restart_sound():
	play_sfx(DEFAULT_RESTART_SOUND)

func play_miss_hit_sound():
	var random_index = randi() % 5
	var sound_path = ""
	match random_index:
		0: sound_path = DEFAULT_MISS_HIT_SOUND_1
		1: sound_path = DEFAULT_MISS_HIT_SOUND_2
		2: sound_path = DEFAULT_MISS_HIT_SOUND_3
		3: sound_path = DEFAULT_MISS_HIT_SOUND_4
		4: sound_path = DEFAULT_MISS_HIT_SOUND_5
	play_sfx(sound_path)

func play_hit_sound(is_kick: bool = true):
	var sound_path = ""
	if is_kick:
		sound_path = active_kick_sound_path
	else:
		sound_path = active_snare_sound_path

	var stream = load(sound_path) as AudioStream
	if stream:
		if hit_sound_player: 
			hit_sound_player.stream = stream
			hit_sound_player.play()
	else:
		push_error("MusicManager: Не удалось загрузить звук удара: " + sound_path)

func play_custom_hit_sound(sound_path: String):
	var full_path = sound_path
	if not full_path.begins_with("res://"):
		pass
	var stream = load(full_path) as AudioStream
	if stream:
		if hit_sound_player:
			hit_sound_player.stream = stream
			hit_sound_player.play()
		else:
			push_error("MusicManager: hit_sound_player не установлен!")
	else:
		push_error("MusicManager: Не удалось загрузить кастомный звук удара: " + full_path)

func play_metronome_sound(is_strong_beat: bool = true):
	var sound_file = DEFAULT_METRONOME_STRONG_SOUND if is_strong_beat else DEFAULT_METRONOME_WEAK_SOUND
	var full_path = MUSIC_DIR + sound_file
	var stream = load(full_path) as AudioStream
	if stream:
		var player_index = _current_metronome_player_index
		_current_metronome_player_index = (player_index + 1) % _metronome_players.size()
		var player = _metronome_players[player_index]
		if player:
			player.stream = stream
			player.play()
	else:
		push_error("MusicManager: Не удалось загрузить звук метронома: " + full_path)

func update_volumes_from_settings():
	_game_music_volume_pct = SettingsManager.get_music_volume()
	_menu_music_volume_pct = SettingsManager.get_menu_music_volume() if SettingsManager.has_method("get_menu_music_volume") else _menu_music_volume_pct
	if current_game_music_file != "":
		set_music_volume(_game_music_volume_pct)
	if current_menu_music_file != "":
		set_menu_music_volume(_menu_music_volume_pct)
	set_sfx_volume(SettingsManager.get_effects_volume())
	set_hit_sounds_volume(SettingsManager.get_hit_sounds_volume())
	set_metronome_volume(SettingsManager.get_metronome_volume())

func play_instrument_select_sound(instrument_type: String):
	var sound_file_name = ""
	match instrument_type:
		"drums":
			sound_file_name = DEFAULT_DRUMS_SELECT_SOUND
		"standard": 
			sound_file_name = DEFAULT_STANDARD_SELECT_SOUND
		_:
			printerr("MusicManager: Неизвестный тип инструмента для звука: ", instrument_type)
			return 

	var full_path = MUSIC_DIR + sound_file_name
	if FileAccess.file_exists(full_path):
		play_sfx(sound_file_name) 
	else:
		print("MusicManager: Файл звука инструмента не найден: ", full_path)
