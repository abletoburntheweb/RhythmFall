# screens/settings_menu.py
from PyQt5.QtCore import Qt
from PyQt5.QtWidgets import QWidget, QVBoxLayout, QFrame, QMessageBox, QScrollArea
from logic.creation import Create
from logic.transitions import Transitions


class SettingsMenu(QWidget):
    def __init__(self, parent=None, settings=None, game_screen=None):
        super().__init__(parent)
        self.parent = parent
        self.settings = settings or {}
        self.game_screen = game_screen
        self.create = Create(self)
        self.transitions = Transitions(self.parent)
        self.setFocusPolicy(Qt.StrongFocus)
        self.init_ui()

    def init_ui(self):
        self.resize(self.parent.size())
        panel = self.create.g_panel(x=0, y=0, w=self.parent.width(), h=self.parent.height())

        scroll_area = QScrollArea(self)
        scroll_area.setWidgetResizable(True)
        scroll_area.setHorizontalScrollBarPolicy(Qt.ScrollBarAlwaysOff)
        scroll_area.setVerticalScrollBarPolicy(Qt.ScrollBarAsNeeded)

        content_widget = QWidget()

        layout = QVBoxLayout(content_widget)
        layout.setAlignment(Qt.AlignCenter)
        layout.setSpacing(40)
        layout.setContentsMargins(20, 20, 20, 20)

        scroll_area.setWidget(content_widget)

        main_layout = QVBoxLayout(self)
        main_layout.setContentsMargins(0, 0, 0, 0)
        main_layout.addWidget(scroll_area)

        self.title_label = self.create.label("Настройки", font_size=72, bold=True)
        layout.addWidget(self.title_label)

        music_block = QVBoxLayout()
        music_label, self.music_slider = self.create.slider(
            "Громкость музыки",
            min_value=0,
            max_value=100,
            value=self.parent.settings.get("music_volume", 50),
            callback=self.update_music_volume,
        )
        self.fps_toggle = self.create.checkbox(
            "Показывать FPS",
            checked=self.parent.settings.get("show_fps", False),
            callback=self.toggle_fps,
        )
        music_block.addWidget(music_label)
        music_block.addWidget(self.music_slider)
        music_block.addWidget(self.fps_toggle)
        layout.addLayout(music_block)

        sfx_block = QVBoxLayout()
        sfx_label, self.sfx_slider = self.create.slider(
            "Громкость звуков",
            min_value=0,
            max_value=100,
            value=self.parent.settings.get("effects_volume", 50),
            callback=self.update_effects_volume,
        )
        hit_sounds_label, self.hit_sounds_slider = self.create.slider(
            "Громкость нажатий",
            min_value=0,
            max_value=100,
            value=self.parent.settings.get("hit_sounds_volume", 70),
            callback=self.update_hit_sounds_volume,
        )
        self.fullscreen_checkbox = self.create.checkbox(
            "Полноэкранный режим",
            checked=self.parent.settings.get("fullscreen", False),
            callback=self.toggle_fullscreen,
        )
        sfx_block.addWidget(sfx_label)
        sfx_block.addWidget(self.sfx_slider)
        sfx_block.addWidget(hit_sounds_label)
        sfx_block.addWidget(self.hit_sounds_slider)
        sfx_block.addWidget(self.fullscreen_checkbox)
        layout.addLayout(sfx_block)

        preview_block = QVBoxLayout()
        preview_label, self.preview_slider = self.create.slider(
            "Громкость предпросмотра",
            min_value=0,
            max_value=100,
            value=self.parent.settings.get("preview_volume", 70),
            callback=self.update_preview_volume,
        )
        preview_block.addWidget(preview_label)
        preview_block.addWidget(self.preview_slider)
        layout.addLayout(preview_block)

        layout.addSpacing(40)

        self.controls_checkbox = self.create.checkbox(
            "Управление WASD",
            checked=self.parent.settings.get("use_wasd", False),
            callback=self.toggle_controls,
        )
        layout.addWidget(self.controls_checkbox)

        self.reset_achievements_button = self.create.button(
            "🗑️ Стереть прогресс ачивок",
            self.reset_achievements,
            x=0, y=0, w=400, h=60,
            preset=3
        )
        layout.addWidget(self.reset_achievements_button, alignment=Qt.AlignCenter)

        self.back_button = self.create.button(
            "🔙 Назад",
            lambda: self.transitions.close_settings(from_pause=bool(self.game_screen)),
            x=0, y=0, w=400, h=60,
            preset=3
        )
        layout.addWidget(self.back_button, alignment=Qt.AlignCenter)

    def toggle_fullscreen(self, state):
        if self.parent:
            self.parent.toggle_fullscreen()

    def update_music_volume(self, value):
        if self.parent:
            self.parent.settings["music_volume"] = value
            self.parent.music_manager.set_music_volume(value)
            self.parent.save_settings()

    def update_effects_volume(self, value):
        if self.parent:
            self.parent.settings["effects_volume"] = value
            self.parent.music_manager.set_sfx_volume(value)
            self.parent.save_settings()


    def update_hit_sounds_volume(self, value):
        if self.parent:
            self.parent.settings["hit_sounds_volume"] = value
            self.parent.music_manager.set_hit_sounds_volume(value)
            self.parent.save_settings()
            print(f"[Settings] Громкость нажатий: {value}")

    def update_preview_volume(self, value):
        if self.parent:
            self.parent.settings["preview_volume"] = value
            self.parent.save_settings()
            print(f"[Settings] Громкость предпросмотра: {value}")

            if hasattr(self.parent, "song_select") and self.parent.song_select:
                self.parent.song_select.set_preview_volume(value)

    def toggle_fps(self, state):
        if self.parent:
            self.parent.settings["show_fps"] = bool(state)
            self.parent.save_settings()
            if hasattr(self.parent.game_screen, "update_fps_visibility"):
                self.parent.game_screen.update_fps_visibility(bool(state))

    def toggle_controls(self, state):
        self.settings["use_wasd"] = bool(state)
        if self.game_screen and hasattr(self.game_screen, "player"):
            print(f"[Settings] Управление WASD: {state}")

    def reset_achievements(self):
        if hasattr(self.parent, "achievement_manager"):
            self.parent.achievement_manager.reset_achievements()
            print("[Settings] Прогресс ачивок сброшен.")

    def keyPressEvent(self, event):
        if event.key() == Qt.Key_Escape:
            self.transitions.close_settings()
        else:
            super().keyPressEvent(event)