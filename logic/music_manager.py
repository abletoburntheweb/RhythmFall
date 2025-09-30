# logic/music_manager.py
import os

from PyQt5.QtMultimedia import QMediaPlayer, QMediaContent
from PyQt5.QtCore import QUrl

class MusicManager:
    AUDIO_DIR = "assets/audio"

    def __init__(self, settings):
        self.menu_music = "Niamos!.mp3"
        self.game_music = "Why Did You Tell Me That You Loved Me.mp3"
        self.intro_music = "intro_music.mp3"
        self.select_sound = "select_click.mp3"
        self.cancel_sound = "cancel_click.mp3"

        self.music_player = QMediaPlayer()
        self.sfx_player = QMediaPlayer()

        self.set_music_volume(settings.get("music_volume", 50))
        self.set_sfx_volume(settings.get("effects_volume", 80))

    def _get_full_path(self, filename):
        return os.path.join(self.AUDIO_DIR, filename)
    def set_music_volume(self, volume):
        self.music_player.setVolume(volume)

    def set_sfx_volume(self, volume):
        self.sfx_player.setVolume(volume)

    def play_music(self, music_file, loop=True):
        music_path = self._get_full_path(music_file)
        try:
            current = self.music_player.currentMedia()
            if current and current.canonicalUrl().toString() == QUrl.fromLocalFile(music_path).toString():
                print("Музыка уже играет. Ничего не делаем.")
                return
            self.music_player.stop()
            media_content = QMediaContent(QUrl.fromLocalFile(music_path))
            self.music_player.setMedia(media_content)
            self.music_player.setPosition(0)
            if loop:
                self.music_player.mediaStatusChanged.connect(self.loop_music)
            self.music_player.play()
        except Exception as e:
            print(f"Ошибка воспроизведения музыки: {e}")

    def loop_music(self, status):
        if status == QMediaPlayer.EndOfMedia:
            self.music_player.setPosition(0)
            self.music_player.play()

    def stop_music(self):
        try:
            self.music_player.stop()
            try:
                self.music_player.mediaStatusChanged.disconnect()
            except TypeError:
                pass
        except Exception as e:
            print(f"Ошибка остановки музыки: {e}")

    def play_sfx(self, sound_path):
        full_path = self._get_full_path(sound_path)
        media_content = QMediaContent(QUrl.fromLocalFile(full_path))
        self.sfx_player.setMedia(media_content)
        self.sfx_player.play()

    def play_select_sound(self):
        self.play_sfx(self.select_sound)

    def play_cancel_sound(self):
        self.play_sfx(self.cancel_sound)