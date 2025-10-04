# screens/victory_screen.py
from PyQt5.QtWidgets import QWidget, QLabel, QPushButton, QVBoxLayout, QHBoxLayout
from PyQt5.QtCore import QTimer, Qt
from PyQt5.QtGui import QFont, QPixmap, QColor

from logic.creation import Create


class VictoryScreen(QWidget):
    def __init__(self, parent, score, combo, max_combo, song_info=None):
        super().__init__(parent)
        self.setFixedSize(1920, 1080)
        self.setStyleSheet("background-color: black;")

        self.score = score
        self.combo = combo
        self.max_combo = max_combo
        self.song_info = song_info or {}

        self.displayed_score = 0
        self.displayed_combo = 0
        self.displayed_max_combo = 0

        self.create = Create(self)
        self.bg_label = self.create.background(texture_path="assets/textures/town.png")

        layout = QVBoxLayout()
        layout.setAlignment(Qt.AlignCenter)

        title_label = QLabel("🎉 ПОЗДРАВЛЯЕМ!")
        title_font = QFont("Arial", 48, QFont.Bold)
        title_label.setFont(title_font)
        title_label.setStyleSheet("color: white;")
        title_label.setAlignment(Qt.AlignCenter)
        layout.addWidget(title_label)

        if self.song_info.get("title"):
            song_label = QLabel(f"Песня: {self.song_info.get('title', 'Неизвестная песня')}")
            song_font = QFont("Arial", 24)
            song_label.setFont(song_font)
            song_label.setStyleSheet("color: lightgray;")
            song_label.setAlignment(Qt.AlignCenter)
            layout.addWidget(song_label)

        stats_layout = QVBoxLayout()

        self.score_label = QLabel(f"Счёт: 0")
        score_font = QFont("Arial", 28, QFont.Bold)
        self.score_label.setFont(score_font)
        self.score_label.setStyleSheet("color: yellow;")
        self.score_label.setAlignment(Qt.AlignCenter)
        stats_layout.addWidget(self.score_label)

        self.combo_label = QLabel(f"Комбо: 0")
        combo_font = QFont("Arial", 24)
        self.combo_label.setFont(combo_font)
        self.combo_label.setStyleSheet("color: cyan;")
        self.combo_label.setAlignment(Qt.AlignCenter)
        stats_layout.addWidget(self.combo_label)

        self.max_combo_label = QLabel(f"Макс. комбо: 0")
        max_combo_font = QFont("Arial", 24)
        self.max_combo_label.setFont(max_combo_font)
        self.max_combo_label.setStyleSheet("color: cyan;")
        self.max_combo_label.setAlignment(Qt.AlignCenter)
        stats_layout.addWidget(self.max_combo_label)

        layout.addLayout(stats_layout)

        button_layout = QHBoxLayout()

        button_layout.setAlignment(Qt.AlignCenter)
        continue_button = self.create.victory_button(text="🎵 К списку песен", callback=self.go_to_song_select, preset='continue')
        replay_button = self.create.victory_button(text="🔄 Повторить", callback=self.replay_song, preset='replay')

        button_layout.addWidget(continue_button)
        button_layout.addWidget(replay_button)


        layout.addLayout(button_layout)
        self.setLayout(layout)

        self.animation_timer = QTimer(self)
        self.animation_timer.timeout.connect(self.animate_results)
        self.animation_timer.start(20)

    def animate_results(self):
        if self.displayed_score < self.score:
            step = max(1, int(self.score * 0.05))
            self.displayed_score += step
            if self.displayed_score > self.score:
                self.displayed_score = self.score
            self.score_label.setText(f"Счёт: {self.displayed_score}")

        elif self.displayed_combo < self.combo:
            step = max(1, int(self.combo * 0.05))
            self.displayed_combo += step
            if self.displayed_combo > self.combo:
                self.displayed_combo = self.combo
            self.combo_label.setText(f"Комбо: {self.displayed_combo}")

        elif self.displayed_max_combo < self.max_combo:
            step = max(1, int(self.max_combo * 0.05))
            self.displayed_max_combo += step
            if self.displayed_max_combo > self.max_combo:
                self.displayed_max_combo = self.max_combo
            self.max_combo_label.setText(f"Макс. комбо: {self.displayed_max_combo}")

        if (self.displayed_score == self.score and
                self.displayed_combo == self.combo and
                self.displayed_max_combo == self.max_combo):
            self.animation_timer.stop()

    def replay_song(self):
        from logic.transitions import transition_open_game_with_song
        transition_open_game_with_song(self.parent(), self.song_info)

    def go_to_song_select(self):
        from logic.transitions import transition_open_song_select
        transition_open_song_select(self.parent())