from PyQt5.QtGui import QPainter, QColor
from PyQt5.QtWidgets import QWidget
from PyQt5.QtCore import Qt, QTimer, QRect
import random

from logic.player import Player
from logic.score import ScoreManager

class Note:
    def __init__(self, lane, y=0):
        self.lane = lane
        self.y = y
        self.active = True

class GameScreen(QWidget):
    def __init__(self, parent=None, start_level=1):
        super().__init__(parent)
        self.setFixedSize(1920, 1080)
        self.setFocusPolicy(Qt.StrongFocus)
        self.grabKeyboard()

        self.lanes = 4
        self.notes = []
        self.lane_width = self.width() // self.lanes
        self.hit_zone_y = 900

        self.score_manager = ScoreManager(self)

        self.player = Player()
        self.player.note_hit.connect(self.check_hit)
        self.player.lane_pressed_changed.connect(self.update)

        self.combo = 0

        self.timer = QTimer(self)
        self.timer.timeout.connect(self.update_game)
        self.timer.start(16)

        self.spawn_timer = QTimer(self)
        self.spawn_timer.timeout.connect(self.spawn_random_note)
        self.spawn_timer.start(600)

    def start_game(self):
        self.notes.clear()
        self.combo = 0
        self.score_manager.score = 0
        print("[GameScreen] Игра стартовала!")

    def spawn_random_note(self):
        lane = random.randint(0, self.lanes - 1)
        self.notes.append(Note(lane))

    def update_game(self):
        for note in self.notes:
            note.y += 6
            if note.y > self.height():
                note.active = False
                self.combo = 0
        self.notes = [n for n in self.notes if n.active]
        self.update()

    def check_hit(self, lane):
        for note in self.notes:
            if note.lane == lane and abs(note.y - self.hit_zone_y) < 30:
                note.active = False
                self.score_manager.add_score(100)
                self.combo += 1
                print(f"HIT lane {lane} | Combo: {self.combo}")
                break

    def keyPressEvent(self, event):
        self.player.keyPressEvent(event)
        super().keyPressEvent(event)

    def keyReleaseEvent(self, event):
        self.player.keyReleaseEvent(event)
        super().keyReleaseEvent(event)

    def paintEvent(self, event):
        painter = QPainter(self)

        for i in range(self.lanes):
            x = i * self.lane_width
            color = QColor(80, 80, 120) if self.player.lanes_state[i] else QColor(40, 40, 40)
            painter.fillRect(QRect(x, 0, self.lane_width, self.height()), color)

        painter.fillRect(QRect(0, self.hit_zone_y, self.width(), 20), QColor(80, 80, 80))

        for note in self.notes:
            x = note.lane * self.lane_width
            painter.fillRect(QRect(x, note.y, self.lane_width, 20), QColor(200, 50, 50))

        painter.setPen(QColor(255, 255, 255))
        painter.drawText(20, 40, f"Score: {self.score_manager.get_score()}")
        painter.drawText(20, 70, f"Combo: {self.combo}")
