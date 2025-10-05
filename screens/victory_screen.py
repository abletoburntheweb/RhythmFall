from PyQt5.QtWidgets import QWidget, QLabel, QPushButton, QVBoxLayout, QHBoxLayout, QGraphicsOpacityEffect, QFrame
from PyQt5.QtCore import QTimer, Qt, QPropertyAnimation
from PyQt5.QtGui import QFont, QColor
from logic.creation import Create


class VictoryScreen(QWidget):
    def __init__(self, parent, score, combo, max_combo, accuracy=100.0, song_info=None):
        super().__init__(parent)
        self.setFixedSize(1920, 1080)
        self.setStyleSheet("background-color: black;")

        self.score = score
        self.combo = combo
        self.max_combo = max_combo
        self.accuracy = accuracy
        self.song_info = song_info or {}

        self.displayed_score = 0
        self.displayed_combo = 0
        self.displayed_max_combo = 0
        self.displayed_accuracy = 0.0

        self.create = Create(self)
        self.bg_label = self.create.background(texture_path="assets/textures/town.png")

        layout = QVBoxLayout()
        layout.setAlignment(Qt.AlignCenter)
        layout.setContentsMargins(0, 100, 0, 100)
        layout.setSpacing(40)

        title_label = QLabel("✨ ПОБЕДА ✨")
        title_label.setFont(QFont("Arial", 56, QFont.Bold))
        title_label.setStyleSheet("""
            color: qlineargradient(x1:0, y1:0, x2:1, y2:1,
                                   stop:0 #FFD700, stop:1 #FFA500);
            text-shadow: 2px 2px 4px rgba(0,0,0,0.6);
        """)
        title_label.setAlignment(Qt.AlignCenter)
        layout.addWidget(title_label)

        if self.song_info.get("title"):
            song_label = QLabel(f"{self.song_info.get('title', 'Неизвестная песня')}")
            song_label.setFont(QFont("Arial", 26, QFont.Bold))
            song_label.setStyleSheet("color: #CCCCCC;")
            song_label.setAlignment(Qt.AlignCenter)
            layout.addWidget(song_label)

        stats_frame = QFrame()
        stats_frame.setStyleSheet("""
            QFrame {
                background-color: rgba(0, 0, 0, 0.6);
                border: 2px solid rgba(255, 255, 255, 0.2);
                border-radius: 20px;
            }
        """)
        stats_layout = QVBoxLayout(stats_frame)
        stats_layout.setAlignment(Qt.AlignCenter)
        stats_layout.setSpacing(20)

        self.score_label = QLabel("Счёт: 0")
        self.score_label.setFont(QFont("Consolas", 32, QFont.Bold))
        self.score_label.setStyleSheet("color: #FFD700;")
        self.score_label.setAlignment(Qt.AlignCenter)
        stats_layout.addWidget(self.score_label)

        self.combo_label = QLabel("Комбо: 0")
        self.combo_label.setFont(QFont("Consolas", 28, QFont.Bold))
        self.combo_label.setStyleSheet("color: #00FFFF;")
        self.combo_label.setAlignment(Qt.AlignCenter)
        stats_layout.addWidget(self.combo_label)

        self.max_combo_label = QLabel("Макс. комбо: 0")
        self.max_combo_label.setFont(QFont("Consolas", 24))
        self.max_combo_label.setStyleSheet("color: #88E0FF;")
        self.max_combo_label.setAlignment(Qt.AlignCenter)
        stats_layout.addWidget(self.max_combo_label)

        self.accuracy_label = QLabel("Точность: 0%")
        self.accuracy_label.setFont(QFont("Consolas", 28, QFont.Bold))
        self.accuracy_label.setStyleSheet("color: #FF66CC;")
        self.accuracy_label.setAlignment(Qt.AlignCenter)
        stats_layout.addWidget(self.accuracy_label)

        layout.addWidget(stats_frame)

        button_layout = QHBoxLayout()
        button_layout.setAlignment(Qt.AlignCenter)
        button_layout.setSpacing(80)

        continue_button = self.create.victory_button(text="🎵 К списку песен", callback=self.go_to_song_select, preset='continue')
        replay_button = self.create.victory_button(text="🔄 Повторить", callback=self.replay_song, preset='replay')

        button_layout.addWidget(continue_button)
        button_layout.addWidget(replay_button)
        layout.addLayout(button_layout)

        self.setLayout(layout)

        self.fade_in_effect = QGraphicsOpacityEffect(self)
        self.setGraphicsEffect(self.fade_in_effect)
        self.fade_in = QPropertyAnimation(self.fade_in_effect, b"opacity")
        self.fade_in.setDuration(1500)
        self.fade_in.setStartValue(0)
        self.fade_in.setEndValue(1)
        self.fade_in.start()

        self.animation_timer = QTimer(self)
        self.animation_timer.timeout.connect(self.animate_results)
        self.animation_timer.start(30)

    def animate_results(self):
        finished = True

        if self.displayed_score < self.score:
            self.displayed_score += max(1, int(self.score * 0.02))
            if self.displayed_score > self.score:
                self.displayed_score = self.score
            self.score_label.setText(f"Счёт: {self.displayed_score}")
            finished = False

        if self.displayed_combo < self.combo:
            self.displayed_combo += 1
            self.combo_label.setText(f"Комбо: {self.displayed_combo}")
            finished = False

        if self.displayed_max_combo < self.max_combo:
            self.displayed_max_combo += 1
            self.max_combo_label.setText(f"Макс. комбо: {self.displayed_max_combo}")
            finished = False

        if self.displayed_accuracy < self.accuracy:
            self.displayed_accuracy += 0.5
            if self.displayed_accuracy > self.accuracy:
                self.displayed_accuracy = self.accuracy
            self.accuracy_label.setText(f"Точность: {self.displayed_accuracy:.1f}%")
            finished = False

        if finished:
            self.animation_timer.stop()

    def replay_song(self):
        from logic.transitions import transition_open_game_with_song
        transition_open_game_with_song(self.parent(), self.song_info)

    def go_to_song_select(self):
        from logic.transitions import transition_open_song_select
        transition_open_song_select(self.parent())
