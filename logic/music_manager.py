# logic/music_manager.py
import os
from PyQt5.QtMultimedia import QMediaPlayer, QMediaContent
from PyQt5.QtCore import QUrl
import json


class MusicManager:
    AUDIO_DIR = "assets/audio"
    SHOP_AUDIO_DIR = "assets/shop/sounds"

    def __init__(self, settings, player_data_manager=None):
        self.menu_music = "Niamos!.mp3"
        self.game_music = "Why Did You Tell Me That You Loved Me.mp3"
        self.intro_music = "intro_music.mp3"
        self.select_sound = "select_click.mp3"
        self.cancel_sound = "cancel_click.mp3"

        
        self.player_data_manager = player_data_manager

        self.music_player = QMediaPlayer()
        self.sfx_player = QMediaPlayer()

        self.current_music_file = None
        self.current_game_music_file = None

        
        self.settings = settings

        
        self.set_music_volume(settings.get("music_volume", 50))
        self.set_sfx_volume(settings.get("effects_volume", 80))
        self.set_hit_sounds_volume(settings.get("hit_sounds_volume", 70))

        self._last_hit_sound_was_kick = True

    def _get_full_path(self, filename):
        return os.path.join(self.AUDIO_DIR, filename)

    def _get_shop_audio_path(self, filename):
        return os.path.join(self.SHOP_AUDIO_DIR, filename)

    def set_music_volume(self, volume):
        self.music_player.setVolume(volume)
        
        if isinstance(self.settings, dict):
            self.settings["music_volume"] = volume

    def set_sfx_volume(self, volume):
        
        self._sfx_volume = volume
        if isinstance(self.settings, dict):
            self.settings["effects_volume"] = volume

    def set_hit_sounds_volume(self, volume):
        self._hit_sounds_volume = volume
        if isinstance(self.settings, dict):
            self.settings["hit_sounds_volume"] = volume

    def play_music(self, music_file, loop=True, restart=False):
        music_path = self._get_full_path(music_file)

        try:
            
            current_url = self.music_player.currentMedia().canonicalUrl().toString() if self.music_player.currentMedia().canonicalUrl() else ""
            target_url = QUrl.fromLocalFile(music_path).toString()

            if current_url == target_url and not restart:
                return

            self.current_music_file = music_file
            self.music_player.stop()

            media_content = QMediaContent(QUrl.fromLocalFile(music_path))
            self.music_player.setMedia(media_content)
            self.music_player.play()

        except Exception as e:
            print(f"Ошибка воспроизведения музыки: {e}")

    def stop_music(self):
        try:
            self.music_player.stop()
            self.current_music_file = None
        except Exception as e:
            print(f"Ошибка остановки музыки: {e}")

    def play_game_music(self, music_file):
        try:
            self.current_game_music_file = music_file
            self.music_player.stop()

            media_content = QMediaContent(QUrl.fromLocalFile(music_file))
            self.music_player.setMedia(media_content)
            self.music_player.play()

            return True
        except Exception as e:
            print(f"Ошибка воспроизведения игровой музыки: {e}")
            return False

    def stop_game_music(self):
        try:
            self.music_player.stop()
            self.current_game_music_file = None
        except Exception as e:
            print(f"Ошибка остановки игровой музыки: {e}")

    def is_game_music_playing(self):
        return self.music_player.state() == QMediaPlayer.PlayingState

    def play_sfx(self, sound_path):
        
        full_path = self._get_full_path(sound_path)

        
        
        kick_sound_file = getattr(self, 'kick_sound_file', 'kick_sound.wav')
        snare_sound_file = getattr(self, 'snare_sound_file', 'snare_sound.wav')

        if 'hit' in sound_path.lower() or sound_path in [kick_sound_file, snare_sound_file]:
            volume = self._hit_sounds_volume
        else:
            
            volume = getattr(self, '_sfx_volume', self.settings.get("effects_volume", 80))

        
        temp_player = QMediaPlayer()
        media_content = QMediaContent(QUrl.fromLocalFile(full_path))
        temp_player.setMedia(media_content)
        temp_player.setVolume(volume)
        temp_player.play()

        
        def cleanup(state):
            if state == QMediaPlayer.StoppedState:
                temp_player.deleteLater()

        temp_player.stateChanged.connect(cleanup)

    def play_select_sound(self):
        self.play_sfx(self.select_sound)

    def play_cancel_sound(self):
        self.play_sfx(self.cancel_sound)

    def _get_kick_sound_file(self):
        if self.player_data_manager:
            active_kick_id = self.player_data_manager.get_active_item("Kick")
            if active_kick_id:
                
                try:
                    with open("data/shop_data.json", "r", encoding="utf-8") as f:
                        shop_data = json.load(f)

                    for item in shop_data["items"]:
                        if item["item_id"] == active_kick_id:
                            audio_path = item.get("audio", "kick/kick_default.wav")
                            if not audio_path.startswith("assets/"):
                                audio_path = self._get_shop_audio_path(audio_path)
                            return audio_path
                except Exception as e:
                    print(f"[MusicManager] Ошибка при получении кик-звука: {e}")

        
        return self._get_shop_audio_path("kick/kick_default.wav")

    def _get_snare_sound_file(self):
        if self.player_data_manager:
            active_snare_id = self.player_data_manager.get_active_item("Snare")
            if active_snare_id:
                
                try:
                    with open("data/shop_data.json", "r", encoding="utf-8") as f:
                        shop_data = json.load(f)

                    for item in shop_data["items"]:
                        if item["item_id"] == active_snare_id:
                            audio_path = item.get("audio", "snare/snare_default.wav")
                            if not audio_path.startswith("assets/"):
                                audio_path = self._get_shop_audio_path(audio_path)
                            return audio_path
                except Exception as e:
                    print(f"[MusicManager] Ошибка при получении снейр-звука: {e}")

        
        return self._get_shop_audio_path("snare/snare_default.wav")

    def play_hit_sound(self):
        if self._last_hit_sound_was_kick:
            sound_file = self._get_kick_sound_file()
        else:
            sound_file = self._get_snare_sound_file()

        self._last_hit_sound_was_kick = not self._last_hit_sound_was_kick

        
        temp_player = QMediaPlayer()
        media_content = QMediaContent(QUrl.fromLocalFile(sound_file))
        temp_player.setMedia(media_content)
        temp_player.setVolume(self._hit_sounds_volume)
        temp_player.play()

        
        def cleanup(state):
            if state == QMediaPlayer.StoppedState:
                temp_player.deleteLater()

        temp_player.stateChanged.connect(cleanup)

    def play_custom_hit_sound(self, sound_path):
        
        if not os.path.isabs(sound_path):
            if not sound_path.startswith("assets/"):
                sound_path = self._get_shop_audio_path(sound_path)
            else:
                sound_path = os.path.abspath(sound_path)

        temp_player = QMediaPlayer()
        media_content = QMediaContent(QUrl.fromLocalFile(sound_path))
        temp_player.setMedia(media_content)
        temp_player.setVolume(self._hit_sounds_volume)
        temp_player.play()

        def cleanup(state):
            if state == QMediaPlayer.StoppedState:
                temp_player.deleteLater()

        temp_player.stateChanged.connect(cleanup)

    def reset_hit_sound_state(self):
        self._last_hit_sound_was_kick = True