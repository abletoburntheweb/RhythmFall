# logic/audio_backend_pygame.py
import pygame
import os
from pathlib import Path


class PygameAudioManager:
    _instance = None

    def __new__(cls):
        if cls._instance is None:
            cls._instance = super().__new__(cls)
        return cls._instance

    def __init__(self):
        if hasattr(self, '_initialized'):
            return
        super().__init__()
        self._initialized = True

        pygame.mixer.init(frequency=44100, size=-16, channels=2, buffer=512)

        self._current_file = None
        self._music_volume = 0.5
        self._sfx_volume = 0.8

        self.set_music_volume(self._music_volume)

    def set_music_volume(self, volume):
        self._music_volume = max(0.0, min(1.0, volume))
        pygame.mixer.music.set_volume(self._music_volume)

    def set_sfx_volume(self, volume):
        self._sfx_volume = max(0.0, min(1.0, volume))

    def play_file(self, filepath, volume=None):
        if volume is not None:
            self.set_music_volume(volume / 100.0)
        else:
            self.set_music_volume(self._music_volume)

        try:
            pygame.mixer.music.load(filepath)
            pygame.mixer.music.play()
            self._current_file = filepath
            return True
        except Exception as e:
            print(f"Ошибка воспроизведения {filepath}: {e}")
            return False

    def skip_to(self, seconds):
        if not self._current_file:
            print("⚠️ Нет загруженного трека для промотки.")
            return False

        try:
            pygame.mixer.music.stop()
            pygame.mixer.music.load(self._current_file)

            pygame.mixer.music.play(start=seconds)
            print(f"⏩ Промотка на {seconds:.2f} секунд")

            return True
        except Exception as e:
            print(f"Ошибка при промотке: {e}")
            return False
    def play_sfx(self, filepath, volume=None):
        try:
            sound = pygame.mixer.Sound(filepath)

            sfx_vol = self._sfx_volume
            if volume is not None:
                sfx_vol = max(0.0, min(1.0, volume / 100.0))

            sound.set_volume(sfx_vol)

            sound.play()
            return True
        except Exception as e:
            print(f"Ошибка воспроизведения SFX {filepath}: {e}")
            return False

    def stop(self):
        if pygame.mixer.music.get_busy():
            pygame.mixer.music.stop()
        self._current_file = None

    def pause(self):
        pygame.mixer.music.pause()

    def resume(self):
        pygame.mixer.music.unpause()

    def is_playing(self):
        return pygame.mixer.music.get_busy()

    def fadeout(self, time_ms):
        pygame.mixer.music.fadeout(time_ms)
        self._current_file = None

    def seek(self, seconds):
        try:
            import pygame
            pygame.mixer.music.rewind()
            pygame.mixer.music.set_pos(seconds)
        except Exception as e:
            print(f"[PygameAudioManager] Ошибка при seek: {e}")

    def quit(self):
        pygame.mixer.quit()