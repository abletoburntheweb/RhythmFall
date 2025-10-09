# screens/settings_menu.py
from PyQt5.QtCore import Qt
from PyQt5.QtGui import QKeySequence
from PyQt5.QtWidgets import (
    QWidget, QVBoxLayout, QHBoxLayout, QScrollArea,
    QStackedWidget, QSizePolicy, QPushButton, QLabel, QGridLayout
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

        self.btn_sound = self.create.button("Звук", lambda: self.stacked_widget.setCurrentIndex(0), x=0, y=0, w=100,
                                            h=40, preset=2)
        self.btn_graphics = self.create.button("Графика", lambda: self.stacked_widget.setCurrentIndex(1), x=0, y=0,
                                               w=100, h=40, preset=2)
        self.btn_controls = self.create.button("Управление", lambda: self.stacked_widget.setCurrentIndex(2), x=0, y=0,
                                               w=100, h=40, preset=2)
        self.btn_misc = self.create.button("Прочее", lambda: self.stacked_widget.setCurrentIndex(3), x=0, y=0, w=100,
                                           h=40, preset=2)

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

        print(
            f"[SettingsMenu] Подключаю update_music_volume с параметрами: music_volume={self.parent.settings.get('music_volume', 50)}")
        music_label, self.music_slider = self.create.settings_menu_slider(
            "Громкость музыки", 0, 100, self.parent.settings.get("music_volume", 50), callback=self.update_music_volume
        )

        print(
            f"[SettingsMenu] Подключаю update_effects_volume с параметрами: effects_volume={self.parent.settings.get('effects_volume', 50)}")
        sfx_label, self.sfx_slider = self.create.settings_menu_slider(
            "Громкость звуков", 0, 100, self.parent.settings.get("effects_volume", 50),
            callback=self.update_effects_volume
        )

        hit_sounds_label, self.hit_sounds_slider = self.create.settings_menu_slider(
            "Громкость нажатий", 0, 100, self.parent.settings.get("hit_sounds_volume", 70),
            callback=self.update_hit_sounds_volume
        )

        preview_label, self.preview_slider = self.create.settings_menu_slider(
            "Громкость предпросмотра", 0, 100, self.parent.settings.get("preview_volume", 70),
            callback=self.update_preview_volume
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

        title = self.create.settings_menu_controls_title_label()
        layout.addWidget(title)

        desc = self.create.settings_menu_controls_description_label()
        layout.addWidget(desc)

        headers_layout = QHBoxLayout()
        headers_layout.setContentsMargins(120, 0, 120, 0)

        actions_header = self.create.settings_menu_controls_header_label("Действия")
        keys_header = self.create.settings_menu_controls_header_label("Клавиши")

        headers_layout.addWidget(actions_header, alignment=Qt.AlignLeft)
        headers_layout.addStretch(1)
        headers_layout.addWidget(keys_header, alignment=Qt.AlignCenter)
        headers_layout.addStretch(1)
        layout.addLayout(headers_layout)

        keys_layout = QGridLayout()
        keys_layout.setSpacing(18)
        keys_layout.setContentsMargins(120, 10, 120, 10)

        current_keys_text = ["A", "S", "D", "F"]
        if self.game_screen and hasattr(self.game_screen, 'player'):
            current_keys_text = self.game_screen.player.get_current_keys_as_text()

        self.key_buttons = []
        for i, key_text in enumerate(current_keys_text):
            row_widget, btn = self.create.settings_menu_controls_row_widget(
                action_text=f"Линия {i + 1}",
                key_text=key_text,
                lane_index=i,
                callback=self.start_key_remap
            )
            self.key_buttons.append(btn)
            keys_layout.addWidget(row_widget, i, 0)

        layout.addLayout(keys_layout)

        hint_label = self.create.settings_menu_controls_hint_label()
        layout.addWidget(hint_label)

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

    def start_key_remap(self, button):
        if hasattr(self, 'remap_active') and self.remap_active:
            if hasattr(self, 'remap_target_button') and self.remap_target_button:
                lane_key_prev = f"lane_{self.remap_target_lane}_key"
                current_keymap = self.parent.settings.get("controls_keymap", {})
                old_scan = current_keymap.get(lane_key_prev, None)
                restored_text = getattr(self, "remap_old_text", None)
                if not restored_text:
                    try:
                        restored_text = QKeySequence(old_scan).toString() if old_scan else None
                    except Exception:
                        restored_text = None
                if restored_text and len(restored_text) == 1:
                    self.remap_target_button.setText(restored_text)
                else:
                    default_keys_text = ["A", "S", "D", "F"]
                    self.remap_target_button.setText(default_keys_text[self.remap_target_lane])

        self.remap_target_button = button
        self.remap_target_lane = button.property("lane")

        lane_key = f"lane_{self.remap_target_lane}_key"
        self.remap_old_scan = self.parent.settings.get("controls_keymap", {}).get(lane_key, None)

        self.remap_old_text = button.text()

        self.remap_active = True
        button.setText("...")
        print(f"[Settings] Ожидание нажатия клавиши для линии {self.remap_target_lane + 1}...")

    def toggle_fullscreen(self, state):
        if self.parent:
            self.parent.toggle_fullscreen()

    def update_music_volume(self, value):
        print(f"[DEBUG] update_music_volume вызван с значением: {value}")
        if self.parent:
            print(f"[DEBUG] self.parent существует: {self.parent}")
            print(f"[DEBUG] self.parent.music_manager существует: {hasattr(self.parent, 'music_manager')}")
            
            self.parent.music_manager.set_music_volume(value)
            
            self.parent.save_settings()
            print(f"[Settings] Громкость музыки обновлена: {value}")

    def update_effects_volume(self, value):
        print(f"[DEBUG] update_effects_volume вызван с значением: {value}")
        if self.parent:
            print(f"[DEBUG] self.parent существует: {self.parent}")
            print(f"[DEBUG] self.parent.music_manager существует: {hasattr(self.parent, 'music_manager')}")
            
            self.parent.music_manager.set_sfx_volume(value)
            
            self.parent.save_settings()
            print(f"[Settings] Громкость SFX обновлена: {value}")

    def update_hit_sounds_volume(self, value):
        if self.parent:
            
            self.parent.music_manager.set_hit_sounds_volume(value)
            
            self.parent.save_settings()
            print(f"[Settings] Громкость хит-звуков обновлена: {value}")

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
            if hasattr(self, 'remap_active') and self.remap_active:
                self.remap_active = False
                if hasattr(self, 'remap_target_button') and self.remap_target_button:
                    lane_key = f"lane_{self.remap_target_lane}_key"
                    current_keymap = self.parent.settings.get("controls_keymap", {})
                    old_scan = current_keymap.get(lane_key, None)

                    restored = None
                    if old_scan:
                        try:
                            restored = QKeySequence(old_scan).toString()
                        except Exception:
                            restored = None

                    if not restored or len(restored) != 1 or not restored.isalpha():
                        restored = ["A", "S", "D", "F"][self.remap_target_lane]

                    self.remap_target_button.setText(restored)
                print(f"[Settings] Переназначение отменено для линии {self.remap_target_lane + 1}.")
            else:
                self.transitions.close_settings()
            return

        if hasattr(self, 'remap_active') and self.remap_active:
            if Qt.Key_A <= event.key() <= Qt.Key_Z:
                new_key_text = QKeySequence(event.key()).toString().upper()
                new_scan = event.nativeScanCode()

                swap_button = None
                swap_lane = None
                for i, btn in enumerate(self.key_buttons):
                    if btn is self.remap_target_button:
                        continue
                    if btn.text().upper() == new_key_text:
                        swap_button = btn
                        swap_lane = i
                        break
                    lane_key_i = f"lane_{i}_key"
                    saved_scan = self.parent.settings.get("controls_keymap", {}).get(lane_key_i)
                    if saved_scan == new_scan:
                        swap_button = btn
                        swap_lane = i
                        break

                controls_map = self.parent.settings.setdefault("controls_keymap", {})

                if swap_button:
                    old_text = getattr(self, "remap_old_text", None)
                    if not old_text or len(old_text) != 1 or not old_text.isalpha():
                        if getattr(self, "remap_old_scan", None):
                            try:
                                old_text = QKeySequence(self.remap_old_scan).toString()
                            except Exception:
                                old_text = None
                        if not old_text or len(old_text) != 1:
                            old_text = ["A", "S", "D", "F"][self.remap_target_lane]

                    swap_button.setText(old_text)
                    self.remap_target_button.setText(new_key_text)

                    if getattr(self, "remap_old_scan", None):
                        controls_map[f"lane_{swap_lane}_key"] = self.remap_old_scan
                    else:
                        controls_map[f"lane_{swap_lane}_key"] = ord(old_text.upper())

                    controls_map[f"lane_{self.remap_target_lane}_key"] = new_scan
                    print(f"[Settings] Поменяли местами клавиши {old_text} ↔ {new_key_text}")
                else:
                    self.remap_target_button.setText(new_key_text)
                    controls_map[f"lane_{self.remap_target_lane}_key"] = new_scan
                    print(f"[Settings] Назначена новая клавиша {new_key_text} для линии {self.remap_target_lane + 1}")

                self.parent.save_settings()

                if self.game_screen and hasattr(self.game_screen, 'player'):
                    updated_keymap = {}
                    for i, btn in enumerate(self.key_buttons):
                        lane_key = f"lane_{i}_key"
                        val = self.parent.settings.get("controls_keymap", {}).get(lane_key)
                        if val is not None:
                            updated_keymap[val] = i
                    self.game_screen.player.set_keymap(updated_keymap)

                self.remap_active = False
            else:
                print(f"[Settings] Игнорируем: недопустимая клавиша ({event.key()})")
        else:
            super().keyPressEvent(event)