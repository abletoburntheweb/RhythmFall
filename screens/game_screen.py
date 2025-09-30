from PyQt5.QtGui import QPainter, QColor
from PyQt5.QtWidgets import QWidget
from PyQt5.QtCore import Qt, QTimer, QRect
import random

from logic.player import Player
from logic.score import ScoreManager
from logic.notes import DefaultNote, HoldNote


class GameScreen(QWidget):
    def __init__(self, parent=None, start_level=1):
        super().__init__(parent)
        self.start_level = start_level
        self.setFixedSize(1920, 1080)
        self.setFocusPolicy(Qt.StrongFocus)

        self.lanes = 4
        self.notes = []
        self.lane_width = self.width() // self.lanes
        self.hit_zone_y = 900
        self.score_manager = ScoreManager(self)
        self.combo = 0

        self.player = Player()
        self.player.note_hit.connect(self.check_hit)
        self.player.lane_pressed_changed.connect(self.update)

        self.timer = QTimer(self)
        self.timer.timeout.connect(self.update_game)

        self.spawn_timer = QTimer(self)
        self.spawn_timer.timeout.connect(self.spawn_random_note)

    def start_game(self):
        self.notes.clear()
        self.combo = 0
        self.score_manager.score = 0
        print("[GameScreen] Игра стартовала!")
        self.setFocusPolicy(Qt.StrongFocus)
        self.grabKeyboard()

        self.timer.start(16)
        self.spawn_timer.start(600)
        self.timer.start(16)
        self.spawn_timer.start(600)

    def spawn_random_note(self):
        lane = random.randint(0, self.lanes - 1)
        note = HoldNote(lane, length=150)
        self.notes.append(note)

    def update_game(self):
        delta_ms = 16
        for note in self.notes:
            if isinstance(note, HoldNote):
                lane_pressed = self.player.lanes_state[note.lane]
                in_hit_zone = note.y + note.height >= self.hit_zone_y and note.y <= self.hit_zone_y + 20

                note.is_being_held = lane_pressed and in_hit_zone
                if note.is_being_held:
                    print(f"HOLD lane {note.lane} удерживается, прогресс {note.hit_progress:.2f}")

            note.update(delta_ms=delta_ms)

            if not note.active:
                self.combo = 0

        self.notes = [n for n in self.notes if n.active]
        self.update()

    def check_hit(self, lane):
        for note in self.notes:
            if note.lane == lane and isinstance(note, HoldNote):
                if abs(note.y - self.hit_zone_y) < 30:
                    note.is_being_held = True
                    print(f"HOLD lane {lane} захвачена")
            elif note.lane == lane and abs(note.y - self.hit_zone_y) < 30:
                points = note.on_hit()
                self.score_manager.add_score(points)
                self.combo += 1
                print(f"HIT lane {lane} | Combo: {self.combo}")

    def keyPressEvent(self, event):
        self.player.keyPressEvent(event)
        super().keyPressEvent(event)

    def keyReleaseEvent(self, event):
        self.player.keyReleaseEvent(event)
        lane = self.player.keymap.get(event.key())
        if lane is not None:
            for note in self.notes:
                if isinstance(note, HoldNote) and note.lane == lane:
                    note.is_being_held = False
                    print(f"HOLD lane {lane} отпущена")
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

            if isinstance(note, HoldNote):
                painter.fillRect(QRect(x, note.y, self.lane_width, note.height), QColor(200, 50, 50))

                green_height = int(note.height * note.hit_progress)
                if green_height > 0:
                    painter.fillRect(
                        QRect(x, note.y + note.height - green_height, self.lane_width, green_height),
                        QColor(50, 200, 50)
                    )
            else:
                painter.fillRect(QRect(x, note.y, self.lane_width, note.height), QColor(200, 50, 50))

        painter.setPen(QColor(255, 255, 255))
        painter.drawText(20, 40, f"Score: {self.score_manager.get_score()}")
        painter.drawText(20, 70, f"Combo: {self.combo}")
