# engine/screens/game_logic.py

import json
from PyQt5.QtGui import QColor
from PyQt5.QtWidgets import QStackedWidget
from PyQt5.QtCore import Qt, pyqtSignal, QThread

from logic.achievement_manager import AchievementManager
from logic.creation import Create
from logic.intro_animation import IntroAnimation
from logic.music_manager import MusicManager
from logic.notification_manager import NotificationManager
from logic.transitions import Transitions
from screens.game_screen import GameScreen
from screens.song_select_screen import SongSelect
from screens.pause_menu import PauseMenu
from screens.settings_menu import SettingsMenu
from screens.main_menu import MainMenu
from logic.settings_manager import load_settings, save_settings
from screens.shop_screen import ShopScreen
from logic.song_manager import SongManager
from logic.player_data import PlayerDataManager


class SongLoaderThread(QThread):
    songs_loaded = pyqtSignal(list)

    def __init__(self, song_manager):
        super().__init__()
        self.song_manager = song_manager

    def run(self):
        self.song_manager.load_songs()
        self.songs_loaded.emit(self.song_manager.songs)


class GameEngine(QStackedWidget):
    def __init__(self):
        super().__init__()
        self.settings = load_settings()
        self.selected_modifiers = []

        self.player_data_manager = PlayerDataManager()

        self.music_manager = MusicManager(self.settings, player_data_manager=self.player_data_manager)

        self.achievement_manager = AchievementManager(parent=self)
        self.achievement_manager.music_manager = self.music_manager

        self.notification_manager = NotificationManager()
        self.notification_manager.set_parent(self)
        self.currentChanged.connect(self.on_screen_changed)
        self.transitions = Transitions(self)

        self.song_manager = SongManager(load_on_init=False, player_data_manager=self.player_data_manager)

        self.init_screens()

        self.song_loader_thread = SongLoaderThread(self.song_manager)
        self.song_loader_thread.songs_loaded.connect(self.on_songs_loaded)
        self.song_loader_thread.start()

        if self.settings.get("fullscreen", False):
            self.set_fullscreen(True)
        else:
            self.set_fullscreen(False)

        self.achievement_manager.game_screen = self.game_screen

        self.setCurrentWidget(self.intro)

    def init_screens(self):
        self.main_menu = MainMenu(self)
        self.intro = IntroAnimation(parent=self, main_menu_widget=self.main_menu)
        self.addWidget(self.intro)
        self.addWidget(self.main_menu)

        self.song_select = SongSelect(parent=self, song_manager=self.song_manager)
        self.addWidget(self.song_select)

        self.settings_menu = SettingsMenu(parent=self)
        self.addWidget(self.settings_menu)

        self.game_screen = GameScreen(parent=self)
        self.addWidget(self.game_screen)

        self.pause_menu = PauseMenu(parent=self)
        self.addWidget(self.pause_menu)

        self.shop_screen = ShopScreen(parent=self, game_screen=self.game_screen, music_manager=self.music_manager)
        self.addWidget(self.shop_screen)

        if self.settings.get("fullscreen", False):
            self.set_fullscreen(True)
        else:
            self.set_fullscreen(False)

        self.achievement_manager.game_screen = self.game_screen

        self.setCurrentWidget(self.intro)

    def save_settings(self):
        save_settings(self.settings)

    def on_screen_changed(self, index):
        current_widget = self.widget(index)
        if isinstance(current_widget, MainMenu):
            if not current_widget.is_intro_finished:
                print("Интро еще не завершено. Музыка главного меню не запускается.")
                return
            self.music_manager.play_music(self.music_manager.menu_music)
        elif isinstance(current_widget, GameScreen):
            self.music_manager.play_music(self.music_manager.game_music)

    def on_songs_loaded(self, songs):
        print(f"[GameEngine] Песни загружены в потоке. Количество: {len(songs)}")
        if hasattr(self, 'song_select'):
            self.song_select.update_songs_list()

    def toggle_fullscreen(self):
        if self.isFullScreen():
            self.set_fullscreen(False)
        else:
            self.set_fullscreen(True)

    def set_fullscreen(self, fullscreen):
        if fullscreen:
            self.setWindowFlags(Qt.FramelessWindowHint)
            self.showFullScreen()
            self.settings["fullscreen"] = True
        else:
            self.setWindowFlags(Qt.Window | Qt.WindowMinimizeButtonHint | Qt.WindowCloseButtonHint)
            self.showNormal()
            self.settings["fullscreen"] = False
        self.save_settings()

    def get_notification_manager(self):
        return self.notification_manager

    @staticmethod
    def interpolate_color(color1, color2, factor):
        r = int(color1.red() + (color2.red() - color1.red()) * factor)
        g = int(color1.green() + (color2.green() - color1.green()) * factor)
        b = int(color1.blue() + (color2.blue() - color1.blue()) * factor)
        return QColor(r, g, b)