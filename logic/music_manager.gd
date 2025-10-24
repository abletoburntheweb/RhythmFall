# logic/music_manager.gd
class_name MusicManager
extends Node

const MUSIC_DIR = "res://assets/audio/"
const SHOP_SOUND_DIR = "res://assets/shop/sounds/"

const DEFAULT_MENU_MUSIC = "Niamos!.mp3"
const DEFAULT_INTRO_MUSIC = "intro_music.mp3"
const DEFAULT_SELECT_SOUND = "select_click.mp3"
const DEFAULT_CANCEL_SOUND = "cancel_click.mp3"
const DEFAULT_ACHIEVEMENT_SOUND = "achievement_unlocked.mp3"
const DEFAULT_DEFAULT_SHOP_SOUND = "missing_sound.mp3"
const DEFAULT_METRONOME_STRONG_SOUND = "metronome_strong.wav"
const DEFAULT_METRONOME_WEAK_SOUND = "metronome_weak.wav"
var was_menu_music_playing_before_shop: bool = false
var menu_music_position_before_shop: float = 0.0

var music_player: AudioStreamPlayer = null
var sfx_player: AudioStreamPlayer = null
var hit_sound_player: AudioStreamPlayer = null
var metronome_player1: AudioStreamPlayer = null
var metronome_player2: AudioStreamPlayer = null

var metronome_timer: Timer = null
var metronome_active: bool = false
var _current_metronome_player_index: int = 0
var _metronome_players: Array[AudioStreamPlayer] = []

var player_data_manager = null
var active_kick_sound_path: String = ""
var active_snare_sound_path: String = ""

var current_menu_music_file: String = ""
var current_game_music_file: String = ""

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
func pause_menu_music():
	if music_player and current_menu_music_file != "":
		if music_player.playing:
			was_menu_music_playing_before_shop = true
			menu_music_position_before_shop = music_player.get_playback_position() 
			music_player.stop() 
			print("MusicManager.gd: Музыка меню остановлена, позиция: ", menu_music_position_before_shop)
		else:
			was_menu_music_playing_before_shop = true
			menu_music_position_before_shop = 0.0
			print("MusicManager.gd: Музыка меню была загружена, но не играла. Запоминаем для возобновления с начала.")
	else:
		print("MusicManager.gd: Музыка меню не была загружена или music_player недоступен.")
func resume_menu_music():
	if current_menu_music_file != "":
		if was_menu_music_playing_before_shop:
			if not music_player.playing: 
				music_player.play(menu_music_position_before_shop)
				print("MusicManager.gd: Музыка меню возобновлена с позиции: ", menu_music_position_before_shop)
			else:
				print("MusicManager.gd: Музыка меню уже играет.")
		else:
			if not music_player.playing:
				music_player.play(0.0) 
				print("MusicManager.gd: Музыка меню запущена с начала (не играла до магазина).")
			else:
				print("MusicManager.gd: Музыка меню уже играет (не играла до магазина).")
	else:
		print("MusicManager.gd: Нет загруженной музыки меню для возобновления.")
	was_menu_music_playing_before_shop = false
	menu_music_position_before_shop = 0.0

func set_player_data_manager(pdm):
	player_data_manager = pdm
	_update_active_sound_paths()

func _update_active_sound_paths():
	if player_data_manager:
		var active_kick_id = player_data_manager.get_active_item("Kick")
		var active_snare_id = player_data_manager.get_active_item("Snare")

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

func set_music_volume(volume: float):
	if music_player: 
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
		printerr("MusicManager: Не удалось загрузить аудио для меню: ", full_path)
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
		music_player.stream = stream
		music_player.play()

func play_game_music(music_file: String):
	if FileAccess.file_exists(music_file):
		var stream = load(music_file) as AudioStream
		if not stream:
			printerr("MusicManager: Не удалось загрузить аудио для игры: ", music_file)
			return


		if music_player:
			current_game_music_file = music_file
			music_player.stream = stream
			music_player.play()
	else:
		printerr("MusicManager: Файл игровой музыки не найден: ", music_file)

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
		print("MusicManager.gd: Музыка остановлена (pause_music). Позиция: ", menu_music_position_before_shop)

func resume_music():
	if music_player and not music_player.playing and music_player.stream: 
		var resume_pos = menu_music_position_before_shop if menu_music_position_before_shop > 0 else 0.0
		music_player.play(resume_pos)
		print("MusicManager.gd: Музыка возобновлена (resume_music) с позиции: ", resume_pos)

func is_music_playing() -> bool:
	if music_player:
		return music_player.playing
	else:
		return false


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
		printerr("MusicManager: Не удалось загрузить SFX: ", full_path)

func _on_sfx_player_finished(player: AudioStreamPlayer):
	if player and is_instance_valid(player):
		player.queue_free() 

func play_select_sound():
	play_sfx(DEFAULT_SELECT_SOUND)

func play_cancel_sound():
	play_sfx(DEFAULT_CANCEL_SOUND)

func play_achievement_sound():
	play_sfx(DEFAULT_ACHIEVEMENT_SOUND)

func play_default_shop_sound():
	play_sfx(DEFAULT_DEFAULT_SHOP_SOUND)

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
		printerr("MusicManager: Не удалось загрузить звук удара: ", sound_path)

func play_custom_hit_sound(sound_path: String):
	var full_path = sound_path
	if not full_path.begins_with("res://"):
		full_path = SHOP_SOUND_DIR + sound_path
	var stream = load(full_path) as AudioStream
	if stream:
		if hit_sound_player:
			hit_sound_player.stream = stream
			hit_sound_player.play()
	else:
		printerr("MusicManager: Не удалось загрузить кастомный звук удара: ", full_path)

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
		printerr("MusicManager: Не удалось загрузить звук метронома: ", full_path)

func start_metronome(bpm: float, start_delay_ms: float = 0.0):
	stop_metronome()

	metronome_active = true
	var interval_ms = 60000.0 / bpm
	var interval_sec = interval_ms / 1000.0

	if not metronome_timer:
		metronome_timer = Timer.new()
		metronome_timer.one_shot = false
		metronome_timer.autostart = false
		metronome_timer.timeout.connect(_on_metronome_timeout)
		add_child(metronome_timer)

	metronome_timer.wait_time = interval_sec
	metronome_timer.start()

func _on_metronome_timeout():
	var is_strong_beat = (int(Time.get_ticks_msec() / (metronome_timer.wait_time * 1000)) % 4) == 0
	play_metronome_sound(is_strong_beat)

func stop_metronome():
	if metronome_timer:
		metronome_timer.stop()
		metronome_active = false

func is_metronome_active() -> bool:
	return metronome_active

func update_volumes_from_settings(settings_manager: SettingsManager):
	if settings_manager:
		set_music_volume(settings_manager.get_music_volume())
		set_sfx_volume(settings_manager.get_effects_volume())
		set_hit_sounds_volume(settings_manager.get_hit_sounds_volume())
		set_metronome_volume(settings_manager.get_metronome_volume())
