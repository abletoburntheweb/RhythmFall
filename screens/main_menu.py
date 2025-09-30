from PyQt5.QtWidgets import QWidget, QLabel
from PyQt5.QtGui import QPixmap, QFontDatabase
from PyQt5.QtCore import Qt

from logic.save_utils import get_last_unfinished_level
from logic.transitions import Transitions
from logic.creation import Create
from logic.settings_manager import load_settings


class MainMenu(QWidget):
    def __init__(self, parent=None):
        super().__init__(parent)
        self.parent = parent
        self.overlay = None
        self.settings_menu = None
        self.game_screen = None
        self.is_leaderboard_open = False
        self.is_settings_open = False
        self.is_game_open = False

        self.settings = load_settings()

        self.c_font_l = QFontDatabase.applicationFontFamilies(QFontDatabase.addApplicationFont("assets/font/sonic-hud-c-italic.ttf"))[0]
        self.c_font_b = QFontDatabase.applicationFontFamilies(QFontDatabase.addApplicationFont("assets/font/MUNRO-sharedassets0.assets-232.otf"))[0]

        self.create = Create(self)
        self.music_manager = self.parent.music_manager
        self.transitions = Transitions(self.parent)
        self.b_x = 1600
        self.b_y = 400
        self.button_spacing = 80
        self.is_intro_finished = False
        self.current_level_label = None

        self.init_ui()

    def init_ui(self):
        self.setFixedSize(1920, 1080)
        self.setFocusPolicy(Qt.StrongFocus)
        self.setFocus()

        self.background_label = QLabel(self)
        self.background_label.setPixmap(QPixmap("assets/textures/town.png").scaled(self.size(), Qt.IgnoreAspectRatio, Qt.SmoothTransformation))

        self.title_label = self.create.label(
            "ARKANOID", font_size=66, bold=True, x=200, y=220, w=750, h=150, font_family=self.c_font_l
        )
        self.title_label.setAlignment(Qt.AlignCenter)

        self.create.ver_label(version="1.0.0", font_family=self.c_font_b)

        button_count = 4
        total_height = button_count * 60 + (
                    button_count - 1) * self.button_spacing
        start_y = (self.height() - total_height) // 2

        button_x = (self.width() - 250) // 2

        self.start_button = self.create.button(
            "ИГРАТЬ",
            lambda: self.transitions.open_game(
                start_level=get_last_unfinished_level()
            ),
            x=button_x, y=start_y + 0 * self.button_spacing, w=250, h=60,
            font_family=self.c_font_b, preset=3
        )
        self.song_select_button = self.create.button(
            "ВЫБОР ПЕСНИ",
            lambda: self.transitions.open_song_select(),
            x=button_x,
            y=start_y + 1 * self.button_spacing,
            w=250,
            h=60,
            font_family=self.c_font_b,
            preset=3
        )
        self.achievements_button = self.create.button(
            "ДОСТИЖЕНИЯ", self.transitions.open_achievements,
            x=button_x, y=start_y + 2 * self.button_spacing, w=250, h=60,
            font_family=self.c_font_b, preset=3
        )
        self.shop_button = self.create.button(
            "МАГАЗИН", self.transitions.open_shop,
            x=button_x,
            y=start_y + 3 * self.button_spacing,
            w=250, h=60,
            font_family=self.c_font_b,
            preset=3
        )
        self.settings_button = self.create.button(
            "НАСТРОЙКИ", self.transitions.open_settings, x=button_x, y=start_y + 4 * self.button_spacing, w=250, h=60,
            font_family=self.c_font_b, preset=3
        )
        self.exit_button = self.create.button(
            "ВЫХОД", self.transitions.exit_game, x=button_x, y=start_y + 5 * self.button_spacing, w=250, h=60,
            font_family=self.c_font_b, preset=3
        )

        self.widgets_to_restore = [
            self.background_label, self.title_label,
            self.start_button, self.song_select_button, self.achievements_button, self.shop_button, self.settings_button, self.exit_button
        ]

        for widget in self.widgets_to_restore:
            widget.setProperty("original_pos", widget.pos())

    def open_leaderboard(self):
        print("Открытие таблицы рекордов...")

    def restore_positions(self):
        for widget in self.widgets_to_restore:
            original_pos = widget.property("original_pos")
            widget.move(original_pos)

    def disable_buttons(self):
        for btn in [self.start_button, self.song_select_button, self.achievements_button, self.shop_button, self.settings_button, self.exit_button]:
            btn.setDisabled(True)

    def enable_buttons(self):
        for btn in [self.start_button, self.song_select_button, self.achievements_button, self.shop_button, self.settings_button, self.exit_button]:
            btn.setDisabled(False)