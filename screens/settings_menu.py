from PyQt5.QtCore import Qt
from PyQt5.QtWidgets import (
    QWidget, QVBoxLayout, QHBoxLayout, QScrollArea,
    QStackedWidget, QSizePolicy
)
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

        content_widget = QWidget()
        content_widget.setGeometry(0, 0, self.parent.width(), self.parent.height())
        content_layout = QVBoxLayout(content_widget)
        content_layout.setContentsMargins(40, 60, 40, 40)
        content_layout.setSpacing(20)

        title_label = self.create.label("Настройки", font_size=72, bold=True)
        title_layout = QHBoxLayout()
        title_layout.addStretch(1)
        title_layout.addWidget(title_label, alignment=Qt.AlignCenter)
        title_layout.addStretch(1)
        content_layout.addLayout(title_layout)

        tabs_layout = QHBoxLayout()
        tabs_layout.addStretch(1)

        self.btn_sound = self.create.button("Звук", lambda: self.stacked_widget.setCurrentIndex(0), x=0, y=0, w=100, h=40, preset=2)
        self.btn_graphics = self.create.button("Графика", lambda: self.stacked_widget.setCurrentIndex(1), x=0, y=0, w=100, h=40, preset=2)
        self.btn_controls = self.create.button("Управление", lambda: self.stacked_widget.setCurrentIndex(2), x=0, y=0, w=100, h=40, preset=2)
        self.btn_misc = self.create.button("Прочее", lambda: self.stacked_widget.setCurrentIndex(3), x=0, y=0, w=100, h=40, preset=2)

        tabs_layout.addWidget(self.btn_sound)
        tabs_layout.addWidget(self.btn_graphics)
        tabs_layout.addWidget(self.btn_controls)
        tabs_layout.addWidget(self.btn_misc)
        tabs_layout.addStretch(1)
        content_layout.addLayout(tabs_layout)

        self.stacked_widget = QStackedWidget()
        self.stacked_widget.setSizePolicy(QSizePolicy.Expanding, QSizePolicy.Expanding)

        self.sound_widget = self.create_sound_widget()
        self.graphics_widget = self.create_graphics_widget()
        self.controls_widget = self.create_controls_widget()
        self.misc_widget = self.create_misc_widget()

        self.stacked_widget.addWidget(self.sound_widget)
        self.stacked_widget.addWidget(self.graphics_widget)
        self.stacked_widget.addWidget(self.controls_widget)
        self.stacked_widget.addWidget(self.misc_widget)

        content_layout.addWidget(self.stacked_widget)

        bottom_buttons_layout = QHBoxLayout()
        bottom_buttons_layout.addStretch(1)
        self.back_button = self.create.button(
            "Назад",
            lambda: self.transitions.close_settings(from_pause=bool(self.game_screen)),
            x=0, y=0, w=400, h=60,
            preset=3
        )
        bottom_buttons_layout.addWidget(self.back_button, alignment=Qt.AlignCenter)
        bottom_buttons_layout.addStretch(1)
        content_layout.addLayout(bottom_buttons_layout)

        content_widget.setParent(panel)
        content_widget.show()

    def create_sound_widget(self):
        content_widget, layout = self.create.settings_menu_content_widget()

        music_label, self.music_slider = self.create.settings_menu_slider(
            "Громкость музыки", 0, 100, self.parent.settings.get("music_volume", 50), self.update_music_volume
        )
        sfx_label, self.sfx_slider = self.create.settings_menu_slider(
            "Громкость звуков", 0, 100, self.parent.settings.get("effects_volume", 50), self.update_effects_volume
        )
        hit_sounds_label, self.hit_sounds_slider = self.create.settings_menu_slider(
            "Громкость нажатий", 0, 100, self.parent.settings.get("hit_sounds_volume", 70),
            self.update_hit_sounds_volume
        )
        preview_label, self.preview_slider = self.create.settings_menu_slider(
            "Громкость предпросмотра", 0, 100, self.parent.settings.get("preview_volume", 70),
            self.update_preview_volume
        )

        layout.addWidget(music_label)
        layout.addWidget(self.music_slider)
        layout.addWidget(sfx_label)
        layout.addWidget(self.sfx_slider)
        layout.addWidget(hit_sounds_label)
        layout.addWidget(self.hit_sounds_slider)
        layout.addWidget(preview_label)
        layout.addWidget(self.preview_slider)

        return self.create.settings_menu_scroll_area_widget(content_widget)

    def create_graphics_widget(self):
        content_widget, layout = self.create.settings_menu_content_widget()

        self.fps_toggle = self.create.settings_menu_checkbox(
            "Показывать FPS",
            checked=self.parent.settings.get("show_fps", False),
            callback=self.toggle_fps
        )
        self.fullscreen_checkbox = self.create.settings_menu_checkbox(
            "Полноэкранный режим",
            checked=self.parent.settings.get("fullscreen", False),
            callback=self.toggle_fullscreen
        )
        layout.addWidget(self.fps_toggle)
        layout.addWidget(self.fullscreen_checkbox)

        return self.create.settings_menu_scroll_area_widget(content_widget)

    def create_controls_widget(self):
        content_widget, layout = self.create.settings_menu_content_widget()

        self.controls_checkbox = self.create.settings_menu_checkbox(
            "Управление WASD",
            checked=self.parent.settings.get("use_wasd", False),
            callback=self.toggle_controls
        )
        layout.addWidget(self.controls_checkbox)

        return self.create.settings_menu_scroll_area_widget(content_widget)

    def create_misc_widget(self):
        content_widget, layout = self.create.settings_menu_content_widget()

        self.reset_achievements_button = self.create.button(
            "🗑️ Стереть прогресс ачивок",
            self.reset_achievements,
            x=0, y=0, w=400, h=60,
            preset=5
        )
        layout.addWidget(self.reset_achievements_button, alignment=Qt.AlignLeft)

        return self.create.settings_menu_scroll_area_widget(content_widget)

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
