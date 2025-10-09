# logic/debug_menu.py
from PyQt5.QtWidgets import QWidget, QLabel, QVBoxLayout, QPushButton
from PyQt5.QtCore import Qt
from PyQt5.QtGui import QPainter, QColor


class DebugMenu(QWidget):
    def __init__(self, parent=None):
        super().__init__(parent)
        self.setWindowTitle("Debug Menu")
        self.setFixedSize(400, 550)

        self.setWindowFlags(Qt.FramelessWindowHint | Qt.WindowStaysOnTopHint)
        self.setAttribute(Qt.WA_TranslucentBackground)

        layout = QVBoxLayout()
        layout.addWidget(self.create_label("🛠 DEBUG: управление игрой"))

        self.fps_label = self.create_label("FPS: ---")
        layout.addWidget(self.fps_label)

        self.score_label = self.create_label("Счёт: ---")
        layout.addWidget(self.score_label)

        self.combo_label = self.create_label("Комбо: ---")
        layout.addWidget(self.combo_label)

        self.max_combo_label = self.create_label("Макс. комбо: ---")
        layout.addWidget(self.max_combo_label)

        self.combo_multiplier_label = self.create_label("Множитель комбо: ---")
        layout.addWidget(self.combo_multiplier_label)

        self.max_combo_multiplier_label = self.create_label("Макс. множитель: ---")
        layout.addWidget(self.max_combo_multiplier_label)

        self.bpm_label = self.create_label("BPM: ---")
        layout.addWidget(self.bpm_label)

        self.notes_total_label = self.create_label("Всего нот: ---")
        layout.addWidget(self.notes_total_label)

        self.notes_current_label = self.create_label("Активные ноты: ---")
        layout.addWidget(self.notes_current_label)

        self.song_time_label = self.create_label("Время песни: ---")
        layout.addWidget(self.song_time_label)

        self.auto_play_button = QPushButton("🤖 Автопрохождение: ВЫКЛ")
        self.auto_play_button.setStyleSheet("background-color: #a33; color: white; font-weight: bold;")
        self.auto_play_button.clicked.connect(self.toggle_auto_play)
        layout.addWidget(self.auto_play_button)

        self.add_1000_button = QPushButton("+1000 очков")
        self.add_1000_button.setStyleSheet("background-color: #3a3; color: white; font-weight: bold;")
        self.add_1000_button.clicked.connect(self.add_1000_points)
        layout.addWidget(self.add_1000_button)

        self.minus_1000_button = QPushButton("-1000 очков")
        self.minus_1000_button.setStyleSheet("background-color: #a33; color: white; font-weight: bold;")
        self.minus_1000_button.clicked.connect(self.minus_1000_points)
        layout.addWidget(self.minus_1000_button)

        self.win_button = QPushButton("✅ Завершить уровень (Победа)")
        self.win_button.setStyleSheet("background-color: #3a3; color: white; font-weight: bold;")
        self.win_button.clicked.connect(self.finish_level)
        layout.addWidget(self.win_button)

        self.setLayout(layout)

        self.is_auto_playing = False

    def create_label(self, text, bold=False):
        label = QLabel(text, self)
        style = "color: white; font-size: 11pt; font-family: 'Arial';"
        if bold:
            style += " font-weight: bold;"
        label.setStyleSheet(style)
        return label

    def paintEvent(self, event):
        painter = QPainter(self)
        background_color = QColor(30, 30, 30, 200)
        painter.fillRect(self.rect(), background_color)

    def toggle_visibility(self):
        self.setVisible(not self.isVisible())
        if self.isVisible():
            self.raise_()
            self.setFocus()

    def update_debug_info(self, game_screen):
        fps = getattr(game_screen, "fps", "---")
        self.fps_label.setText(f"FPS: {fps}")

        if hasattr(game_screen, "score_manager"):
            score = game_screen.score_manager.get_score()
            combo = game_screen.score_manager.get_combo()
            max_combo = game_screen.score_manager.get_max_combo()
            combo_multiplier = game_screen.score_manager.get_combo_multiplier()
            self.score_label.setText(f"Счёт: {score}")
            self.combo_label.setText(f"Комбо: {combo}")
            self.max_combo_label.setText(f"Макс. комбо: {max_combo}")
            self.combo_multiplier_label.setText(f"Множитель комбо: x{combo_multiplier:.1f}")

        if hasattr(game_screen, "note_manager"):
            self.notes_current_label.setText(f"Активные ноты: {len(game_screen.note_manager.get_notes())}")

        if hasattr(game_screen, "note_manager"):
            self.notes_total_label.setText(f"Всего нот: {game_screen.note_manager.get_spawn_queue_size()}")

        if hasattr(game_screen, "bpm"):
            self.bpm_label.setText(f"BPM: {game_screen.bpm}")

        if hasattr(game_screen, "game_time") and hasattr(game_screen, "selected_song_path"):
            try:
                import mutagen
                audio_file = mutagen.File(game_screen.selected_song_path)
                duration = audio_file.info.length
                current_time = max(0, game_screen.game_time)
                total_time = int(duration)
                current_min, current_sec = int(current_time // 60), int(current_time % 60)
                total_min, total_sec = int(total_time // 60), int(total_time % 60)
                self.song_time_label.setText(
                    f"Время песни: {current_min:02d}:{current_sec:02d}/{total_min:02d}:{total_sec:02d}")
            except:
                self.song_time_label.setText(f"Время песни: {game_screen.game_time:.1f}s")

    def toggle_auto_play(self):
        self.is_auto_playing = not self.is_auto_playing
        if self.is_auto_playing:
            self.auto_play_button.setText("🤖 Автопрохождение: ВКЛ")
            self.auto_play_button.setStyleSheet("background-color: #3a3; color: white; font-weight: bold;")
        else:
            self.auto_play_button.setText("🤖 Автопрохождение: ВЫКЛ")
            self.auto_play_button.setStyleSheet("background-color: #a33; color: white; font-weight: bold;")

    def add_1000_points(self):
        if self.parent() and hasattr(self.parent(), "score_manager"):
            current_score = self.parent().score_manager.get_score()
            self.parent().score_manager.score = current_score + 1000

    def minus_1000_points(self):
        if self.parent() and hasattr(self.parent(), "score_manager"):
            current_score = self.parent().score_manager.get_score()
            new_score = max(0, current_score - 1000)
            self.parent().score_manager.score = new_score

    def finish_level(self):
        if self.parent():
            self.parent().end_game()

    def is_auto_play_enabled(self):
        return self.is_auto_playing

    def keyPressEvent(self, event):
        if event.key() == Qt.Key_1:
            self.add_1000_points()
        elif event.key() == Qt.Key_2:
            self.minus_1000_points()
        elif event.key() == Qt.Key_3:
            self.toggle_auto_play()
        elif event.key() == Qt.Key_4:
            self.finish_level()