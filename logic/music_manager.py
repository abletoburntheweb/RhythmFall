# logic/music_manager.py
import os
import pygame

from PyQt5.QtMultimedia import QMediaPlayer, QMediaContent
from PyQt5.QtCore import QUrl
from logic.audio_backend_pygame import PygameAudioManager


class MusicManager:
    AUDIO_DIR = "assets/audio"

    def __init__(self, settings):
        self.menu_music = "Niamos!.mp3"
        self.game_music = "Why Did You Tell Me That You Loved Me.mp3"
        self.intro_music = "intro_music.mp3"
        self.select_sound = "select_click.mp3"
        self.cancel_sound = "cancel_click.mp3"

        self.pygame_audio = PygameAudioManager()

        self.current_music = None
        self.current_game_music = None

        self.set_music_volume(settings.get("music_volume", 50))
        self.set_sfx_volume(settings.get("effects_volume", 80))

    def _get_full_path(self, filename):
        return os.path.join(self.AUDIO_DIR, filename)

    def set_music_volume(self, volume):
        self.pygame_audio.set_music_volume(volume / 100.0)

    def set_sfx_volume(self, volume):
        self.pygame_audio.set_sfx_volume(volume / 100.0)

    def play_music(self, music_file, loop=True, restart=False):
        music_path = self._get_full_path(music_file)

        try:
            if self.current_music == music_path and not restart:
                print("Музыка уже играет. Ничего не делаем.")
                return

            self.stop_music()
            self.current_music = music_path

            self.pygame_audio.play_file(music_path)

        except Exception as e:
            print(f"Ошибка воспроизведения музыки: {e}")

    def stop_music(self):
        try:
            self.pygame_audio.stop()
            self.current_music = None
        except Exception as e:
            print(f"Ошибка остановки музыки: {e}")

    def play_game_music(self, music_file):
        try:
            success = self.pygame_audio.play_file(music_file) # Не передаем volume!
            if success:
                self.current_game_music = music_file
            return success
        except Exception as e:
            print(f"Ошибка воспроизведения игровой музыки: {e}")
            return False

    def stop_game_music(self):
        try:
            self.pygame_audio.stop()
            self.current_game_music = None
        except Exception as e:
            print(f"Ошибка остановки игровой музыки: {e}")

    def is_game_music_playing(self):
        return self.pygame_audio.is_playing()

    def play_sfx(self, sound_path):
        full_path = self._get_full_path(sound_path)
        self.pygame_audio.play_sfx(full_path)

    def play_select_sound(self):
        self.play_sfx(self.select_sound)

    def play_cancel_sound(self):
        self.play_sfx(self.cancel_sound)