# logic/transitions.py
from PyQt5 import sip
from PyQt5.QtCore import QUrl
from PyQt5.QtWidgets import QWidget, QStackedWidget


def transition_open_game(parent, start_level=None, selected_song=None):
    if not hasattr(parent, "main_menu"):
        print("Ошибка: Родительский объект не содержит main_menu.")
        return

    main_menu = parent.main_menu

    if main_menu.is_game_open:
        transition_close_game(parent)
        return

    if hasattr(parent, "music_manager"):
        parent.music_manager.play_select_sound()

    from screens.game_screen import GameScreen
    parent.game_screen = GameScreen(parent=parent, start_level=start_level, selected_song=selected_song)

    main_menu.hide()

    parent.addWidget(parent.game_screen)
    parent.setCurrentWidget(parent.game_screen)

    parent.game_screen.start_game()
    main_menu.is_game_open = True


def transition_close_game(parent):
    if not hasattr(parent, "main_menu"):
        print("Ошибка: Родительский объект не содержит main_menu.")
        return

    main_menu = parent.main_menu

    if not main_menu.is_game_open:
        return

    if hasattr(parent, "music_manager"):
        parent.music_manager.play_cancel_sound()

    if hasattr(parent, "game_screen") and parent.game_screen:
        if hasattr(parent.game_screen, "timer") and parent.game_screen.timer.isActive():
            parent.game_screen.timer.stop()
        if hasattr(parent.game_screen, 'check_song_end_timer') and parent.game_screen.check_song_end_timer and parent.game_screen.check_song_end_timer.isActive():
            parent.game_screen.check_song_end_timer.stop()

    if hasattr(parent, "game_screen") and parent.game_screen:
        parent.game_screen.close()
        parent.removeWidget(parent.game_screen)
        parent.game_screen.deleteLater()
        parent.game_screen = None

    parent.setCurrentWidget(parent.main_menu)
    main_menu.show()
    main_menu.is_game_open = False


def transition_open_song_select(parent):
    if not hasattr(parent, "main_menu") or not parent.main_menu.is_intro_finished:
        return

    if hasattr(parent, "music_manager"):
        parent.music_manager.stop_music()

    from screens.song_select_screen import SongSelect
    if hasattr(parent, "song_select") and parent.song_select:
        parent.removeWidget(parent.song_select)
        parent.song_select.deleteLater()
        parent.song_select = None

    parent.song_select = SongSelect(parent=parent)
    parent.addWidget(parent.song_select)
    parent.setCurrentWidget(parent.song_select)

    parent.song_select.start_preview_music()


def transition_close_song_select(parent):
    if hasattr(parent, "song_select") and parent.song_select:
        parent.song_select.stop_preview()
        parent.removeWidget(parent.song_select)
        parent.song_select.deleteLater()
        parent.song_select = None

    if hasattr(parent, "music_manager"):
        current_url = parent.music_manager.music_player.currentMedia().canonicalUrl().toString() if parent.music_manager.music_player.currentMedia().canonicalUrl() else ""
        menu_music_url = QUrl.fromLocalFile(
            parent.music_manager._get_full_path(parent.music_manager.menu_music)).toString()

        if current_url != menu_music_url:
            parent.music_manager.play_music(parent.music_manager.menu_music, restart=True)

    parent.setCurrentWidget(parent.main_menu)
    parent.main_menu.show()

def transition_open_game_with_song(parent, selected_song):
    transition_open_game(parent, start_level=None, selected_song=selected_song)

def transition_resume_game(parent):
    if not hasattr(parent, "game_screen"):
        print("Ошибка: Родительский объект не содержит game_screen.")
        return

    parent.game_screen.timer.start()
    parent.setCurrentWidget(parent.game_screen)
    parent.game_screen.repaint()


def transition_exit_to_main_menu(parent):
    if not hasattr(parent, "main_menu"):
        print("Ошибка: Родительский объект не содержит main_menu.")
        return

    main_menu = parent.main_menu

    if hasattr(parent, "game_screen") and parent.game_screen:
        timer = getattr(parent.game_screen, "timer", None)
        if timer and not sip.isdeleted(timer):
            timer.stop()

    parent.setCurrentWidget(main_menu)
    main_menu.show()
    main_menu.is_game_open = False

def transition_open_achievements(parent):
    if not hasattr(parent, "main_menu"):
        print("Ошибка: Родительский объект не содержит main_menu.")
        return

    main_menu = parent.main_menu

    if hasattr(parent, "music_manager"):
        parent.music_manager.play_select_sound()

    from screens.achievements_screen import AchievementsScreen

    if hasattr(parent, "achievements_screen") and parent.achievements_screen:
        parent.removeWidget(parent.achievements_screen)
        parent.achievements_screen.deleteLater()
        parent.achievements_screen = None

    parent.achievements_screen = AchievementsScreen(parent=parent)
    parent.addWidget(parent.achievements_screen)
    parent.setCurrentWidget(parent.achievements_screen)

def transition_close_achievements(parent):
    if not hasattr(parent, "main_menu"):
        print("Ошибка: Родительский объект не содержит main_menu.")
        return

    if hasattr(parent, "achievements_screen") and parent.achievements_screen:
        parent.removeWidget(parent.achievements_screen)
        parent.achievements_screen.deleteLater()
        parent.achievements_screen = None

    parent.setCurrentWidget(parent.main_menu)
    parent.main_menu.show()
    if hasattr(parent, "music_manager"):
        parent.music_manager.play_cancel_sound()

def transition_open_shop(parent):
    if not hasattr(parent, "main_menu"):
        print("Ошибка: Родительский объект не содержит main_menu.")
        return

    main_menu = parent.main_menu

    if hasattr(parent, "music_manager"):
        parent.music_manager.stop_music()
        parent.music_manager.play_select_sound()

    from screens.shop_screen import ShopScreen

    if hasattr(parent, "shop_screen") and parent.shop_screen:
        parent.removeWidget(parent.shop_screen)
        parent.shop_screen.deleteLater()
        parent.shop_screen = None

    parent.shop_screen = ShopScreen(
        parent=parent,
        game_screen=parent.game_screen,
        music_manager=parent.music_manager
    )
    parent.addWidget(parent.shop_screen)
    parent.setCurrentWidget(parent.shop_screen)
def transition_close_shop(parent):
    if not hasattr(parent, "main_menu"):
        print("Ошибка: Родительский объект не содержит main_menu.")
        return

    main_menu = parent.main_menu

    if hasattr(parent, "shop_screen") and parent.shop_screen:
        parent.removeWidget(parent.shop_screen)
        parent.shop_screen.deleteLater()
        parent.shop_screen = None

    parent.setCurrentWidget(main_menu)
    main_menu.show()

    if hasattr(parent, "music_manager"):
        parent.music_manager.play_cancel_sound()

        menu_music_url = QUrl.fromLocalFile(
            parent.music_manager._get_full_path(parent.music_manager.menu_music)
        )
        current_url = (
            parent.music_manager.music_player.currentMedia().canonicalUrl()
            if parent.music_manager.music_player.currentMedia()
            else None
        )

        if not current_url or current_url != menu_music_url:
            parent.music_manager.play_music(parent.music_manager.menu_music, restart=True)


def transition_open_settings(parent, from_pause=False):
    if from_pause:
        if not hasattr(parent, "pause_menu"):
            print("Ошибка: Родительский объект не содержит pause_menu.")
            return
        overlay_parent = parent.pause_menu
    else:
        if not hasattr(parent, "main_menu"):
            print("Ошибка: Родительский объект не содержит main_menu.")
            return
        overlay_parent = parent.main_menu

    if getattr(overlay_parent, "is_settings_open", False):
        transition_close_settings(parent)
        return

    if hasattr(parent, "music_manager"):
        parent.music_manager.play_select_sound()

    if not getattr(overlay_parent, "overlay", None):
        overlay_parent.overlay = QWidget(overlay_parent)
        overlay_parent.overlay.setGeometry(0, 0, 1920, 1080)
        overlay_parent.overlay.setStyleSheet("background-color: rgba(0, 0, 0, 100);")
        overlay_parent.overlay.hide()

    if not getattr(overlay_parent, "settings_menu", None):
        from screens.settings_menu import SettingsMenu
        game_screen = getattr(parent, "game_screen", None) if from_pause else None
        overlay_parent.settings_menu = SettingsMenu(
            parent=parent,
            settings=getattr(parent, "settings", None),
            game_screen=game_screen
        )
        overlay_parent.settings_menu.setParent(overlay_parent.overlay)
        overlay_parent.settings_menu.resize(overlay_parent.overlay.size())

    overlay_parent.overlay.show()
    overlay_parent.settings_menu.show()
    overlay_parent.is_settings_open = True

def transition_close_settings(parent, from_pause=False):
    if from_pause:
        if not hasattr(parent, "pause_menu"):
            print("Ошибка: Родительский объект не содержит pause_menu.")
            return
        overlay_parent = parent.pause_menu
    else:
        if not hasattr(parent, "main_menu"):
            print("Ошибка: Родительский объект не содержит main_menu.")
            return
        overlay_parent = parent.main_menu

    if not getattr(overlay_parent, "is_settings_open", False):
        return

    if hasattr(parent, "music_manager"):
        parent.music_manager.play_cancel_sound()

    if getattr(overlay_parent, "settings_menu", None):
        overlay_parent.settings_menu.hide()
    if getattr(overlay_parent, "overlay", None):
        overlay_parent.overlay.hide()

    overlay_parent.is_settings_open = False


def transition_open_victory_screen(parent, score, combo, max_combo, song_info=None):
    if hasattr(parent, "music_manager"):
        parent.music_manager.stop_game_music()

    from screens.victory_screen import VictoryScreen
    victory_screen = VictoryScreen(
        parent=parent,
        score=score,
        combo=combo,
        max_combo=max_combo,
        song_info=song_info or {}
    )

    parent.addWidget(victory_screen)
    parent.setCurrentWidget(victory_screen)


def transition_close_victory_screen(parent):
    if hasattr(parent, "victory_screen") and parent.victory_screen:
        parent.removeWidget(parent.victory_screen)
        parent.victory_screen.deleteLater()
        parent.victory_screen = None

    if hasattr(parent, "music_manager"):
        parent.music_manager.play_music(parent.music_manager.menu_music)

    parent.setCurrentWidget(parent.main_menu)
    parent.main_menu.show()

def transition_open_pause(parent):
    if not hasattr(parent, "game_screen"):
        print("Ошибка: Родительский объект не содержит game_screen.")
        return

    game_screen = parent.game_screen
    if not hasattr(parent, "pause_menu") or parent.pause_menu is None:
        from screens.pause_menu import PauseMenu
        parent.pause_menu = PauseMenu(parent=parent)

    snapshot = game_screen.grab()
    parent.pause_menu.set_background_snapshot(snapshot)
    parent.addWidget(parent.pause_menu)
    parent.setCurrentWidget(parent.pause_menu)
    parent.pause_menu.show_pause()


def transition_close_pause(parent):
    if hasattr(parent, "pause_menu") and parent.pause_menu:
        parent.setCurrentWidget(parent.game_screen)
        parent.pause_menu.hide_pause()


def transition_exit_game(parent):
    if hasattr(parent, "music_manager"):
        parent.music_manager.stop_music()

    parent.close()

class Transitions:
    def __init__(self, parent):
        self.parent = parent

    def open_game(self, start_level=None):
        transition_open_game(self.parent, start_level)

    def close_game(self):
        transition_close_game(self.parent)

    def open_song_select(self):
        transition_open_song_select(self.parent)

    def close_song_select(self):
        transition_close_song_select(self.parent)

    def open_game_with_song(self, selected_song):
        transition_open_game_with_song(self.parent, selected_song)

    def resume_game(self):
        transition_resume_game(self.parent)

    def exit_to_main_menu(self):
        transition_exit_to_main_menu(self.parent)

    def open_achievements(self):
        transition_open_achievements(self.parent)

    def close_achievements(self):
        transition_close_achievements(self.parent)

    def open_shop(self):
        transition_open_shop(self.parent)

    def close_shop(self):
        transition_close_shop(self.parent)

    def open_settings(self, from_pause=False):
        transition_open_settings(self.parent, from_pause=from_pause)

    def close_settings(self, from_pause=False):
        transition_close_settings(self.parent, from_pause=from_pause)

    def open_victory_screen(self, score, combo, max_combo, song_info=None):
        transition_open_victory_screen(self.parent, score, combo, max_combo, song_info)

    def close_victory_screen(self):
        transition_close_victory_screen(self.parent)

    def open_pause(self):
        transition_open_pause(self.parent)

    def close_pause(self):
        transition_close_pause(self.parent)

    def exit_game(self):
        transition_exit_game(self.parent)