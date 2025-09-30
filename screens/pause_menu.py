from PyQt5.QtWidgets import QWidget, QLabel
from PyQt5.QtGui import QFontDatabase, QColor, QPainter, QPixmap
from PyQt5.QtCore import Qt
from logic.creation import Create
from logic.transitions import Transitions
from screens.game_screen import GameScreen

class PauseMenu(QWidget):
    def __init__(self, parent=None):
        super().__init__(parent)
        self.parent = parent
        self.setAttribute(Qt.WA_TransparentForMouseEvents, False)
        self.setWindowFlags(Qt.FramelessWindowHint)
        self.setGeometry(0, 0, 1920, 1080)
        self.setVisible(False)

        self.background_label = QLabel(self)
        self.background_label.setGeometry(0, 0, 1920, 1080)
        self.background_label.lower()

        self.create = Create(self)

        self.c_font_l = QFontDatabase.applicationFontFamilies(
            QFontDatabase.addApplicationFont("assets/font/sonic-hud-c-italic.ttf")
        )[0]
        self.c_font_b = QFontDatabase.applicationFontFamilies(
            QFontDatabase.addApplicationFont("assets/font/MUNRO-sharedassets0.assets-232.otf")
        )[0]

        self.transitions = Transitions(self.parent)
        self.init_ui()

    def init_ui(self):
        self.setAutoFillBackground(True)
        p = self.palette()
        p.setColor(self.backgroundRole(), QColor(0, 0, 0, 180))
        self.setPalette(p)

        self.title = self.create.label("ПАУЗА", font_size=64, bold=True,
                                       x=0, y=200, w=1920, h=100, font_family=self.c_font_l)
        self.title.setAlignment(Qt.AlignCenter)

        btn_y = 350
        spacing = 80

        self.resume_btn = self.create.button(
            "Продолжить",
            self.transitions.close_pause,
            x=835, y=btn_y, w=250, h=60, font_family=self.c_font_b, preset=3
        )
        self.restart_btn = self.create.button(
            "Рестарт",
            self.restart_level,
            x=835, y=btn_y + spacing, w=250, h=60, font_family=self.c_font_b, preset=3
        )
        self.settings_btn = self.create.button(
            "Настройки",
            lambda: self.transitions.open_settings(from_pause=True),
            x=835, y=btn_y + 2 * spacing, w=250, h=60, font_family=self.c_font_b, preset=3
        )
        self.exit_btn = self.create.button(
            "В меню",
            lambda: self.transitions.close_game() or self.parent.setCurrentWidget(self.parent.main_menu),
            x=835, y=btn_y + 3 * spacing, w=250, h=60, font_family=self.c_font_b, preset=3
        )

    def set_background_snapshot(self, pixmap: QPixmap):
        darkened = QPixmap(pixmap.size())
        darkened.fill(Qt.transparent)

        painter = QPainter(darkened)
        painter.drawPixmap(0, 0, pixmap)
        painter.fillRect(darkened.rect(), QColor(0, 0, 0, 180))
        painter.end()

        self.background_label.setPixmap(darkened)
        self.background_label.show()

    def show_pause(self):
        self.setVisible(True)
        self.raise_()
        game_screen = None
        for i in range(self.parent.count()):
            w = self.parent.widget(i)
            from screens.game_screen import GameScreen
            if isinstance(w, GameScreen):
                game_screen = w
                break

        if game_screen:
            if hasattr(game_screen, "debug_update_timer"):
                game_screen.debug_update_timer.stop()

    def hide_pause(self):
        self.setVisible(False)
        game_screen = None
        for i in range(self.parent.count()):
            w = self.parent.widget(i)
            from screens.game_screen import GameScreen
            if isinstance(w, GameScreen):
                game_screen = w
                break
        if game_screen:
            if hasattr(game_screen, "debug_update_timer"):
                game_screen.debug_update_timer.start(500)

    def restart_level(self):
        game_screen = None
        for i in range(self.parent.count()):
            w = self.parent.widget(i)
            if isinstance(w, GameScreen):
                game_screen = w
                break

        if hasattr(game_screen, "reset_current_level"):
            game_screen.reset_current_level()
            self.parent.setCurrentWidget(game_screen)

        self.setVisible(False)

    def keyPressEvent(self, event):
        if event.key() == Qt.Key_Escape:
            if getattr(self, "settings_menu", None) and getattr(self, "overlay", None) and getattr(self,
                                                                                                   "is_settings_open",
                                                                                                   False):
                self.transitions.close_settings(from_pause=True)
            else:
                self.transitions.close_pause()
        else:
            super().keyPressEvent(event)