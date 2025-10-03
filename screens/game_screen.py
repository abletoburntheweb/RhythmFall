# screens/game_screen.py
from PyQt5.QtGui import QPainter, QColor, QFont
from PyQt5.QtWidgets import QWidget
from PyQt5.QtCore import Qt, QTimer, QRect, QElapsedTimer
import json
from pathlib import Path
import math

from logic.player import Player
from logic.score import ScoreManager
from logic.notes import DefaultNote, HoldNote


class GameScreen(QWidget):
    def __init__(self, parent=None, start_level=1, selected_song=None):
        super().__init__(parent)
        self.start_level = start_level
        self.selected_song = selected_song
        self.setFixedSize(1920, 1080)
        self.setFocusPolicy(Qt.StrongFocus)

        self.lanes = 4
        self.notes = []
        self.note_spawn_queue = []
        self.lane_width = self.width() // self.lanes
        self.hit_zone_y = 900
        self.score_manager = ScoreManager(self)
        self.combo = 0

        self.bpm = 120
        self.speed = 6
        self.update_speed_from_bpm()

        self.game_timer = QElapsedTimer()
        self.game_start_time = 0.0
        self.game_time = 0.0
        self.audio_offset = -0.05

        self.player = Player()
        self.player.note_hit.connect(self.check_hit)
        self.player.lane_pressed_changed.connect(self.update)

        self.timer = QTimer(self)
        self.timer.timeout.connect(self.update_game)
        self.timer.setInterval(16)

        self.countdown_timer = QTimer(self)
        self.countdown_timer.timeout.connect(self.update_countdown)
        self.countdown_remaining = 5
        self.countdown_active = False

        self.selected_song_path = self.selected_song.get("path") if self.selected_song else None

    def start_game(self):
        if hasattr(self.parent(), "music_manager"):
            self.parent().music_manager.stop_music()

        self.notes.clear()
        self.note_spawn_queue.clear()
        self.combo = 0
        self.score_manager.score = 0

        if self.selected_song:
            self.load_notes_from_file(self.selected_song)
            if "bpm" in self.selected_song:
                self.bpm = self.selected_song["bpm"]
                self.update_speed_from_bpm()
            print(f"[GameScreen] Игра стартовала с песней: {self.selected_song.get('title', 'Unknown')}")

            self.start_countdown()
        else:
            print("[GameScreen] Игра стартовала (без песни).")
            self.setFocusPolicy(Qt.StrongFocus)
            self.grabKeyboard()
            self.timer.start(16)

    def start_countdown(self):
        print(f"[GameScreen] Начало отсчета: {self.countdown_remaining} секунд")
        self.countdown_active = True
        self.game_time = -self.countdown_remaining
        self.countdown_timer.start(1000)

        self.setFocusPolicy(Qt.StrongFocus)
        self.grabKeyboard()
        self.timer.start(16)

    def update_countdown(self):
        self.countdown_remaining -= 1
        print(f"[GameScreen] Отсчет: {self.countdown_remaining}")

        if self.countdown_remaining <= 0:
            self.countdown_timer.stop()
            self.countdown_active = False
            self.game_time = 0.0
            print("[GameScreen] Отсчет завершен, запуск музыки и игры.")
            self.start_audio()

    def load_notes_from_file(self, song_data):
        song_path = song_data.get("path")
        if not song_path:
            print("Ошибка: Путь к песне не указан.")
            return

        base_name = Path(song_path).stem
        notes_file_path = Path("songs") / "notes" / f"{base_name}.json"

        try:
            with open(notes_file_path, 'r', encoding='utf-8') as f:
                notes_data = json.load(f)
            print(f"Загружено {len(notes_data)} нот из {notes_file_path}")

            sorted_notes_data = sorted(notes_data, key=lambda x: x.get("time", 0))
            self.note_spawn_queue = sorted_notes_data

        except FileNotFoundError:
            print(f"Файл нот не найден: {notes_file_path}")
        except json.JSONDecodeError as e:
            print(f"Ошибка чтения JSON из {notes_file_path}: {e}")

    def start_audio(self):
        if not self.selected_song_path:
            print("[GameScreen] Нет пути к песне для воспроизведения.")
            return

        if not Path(self.selected_song_path).exists():
            print(f"[GameScreen] Файл не существует: {self.selected_song_path}")
            return

        if hasattr(self.parent(), "music_manager"):

            if self.timer.isActive():
                self.timer.stop()

            self.game_time = 0.0
            self.game_timer.start()
            print("[GameScreen] QElapsedTimer запущен.")

            success = self.parent().music_manager.play_game_music(self.selected_song_path)
            if success:
                print(f"[GameScreen] Воспроизведение запущено: {self.selected_song_path}")
            else:
                print(f"[GameScreen] Ошибка запуска аудио: {self.selected_song_path}")

            self.timer.start()
        else:
            print("[GameScreen] MusicManager не найден!")

    def update_speed_from_bpm(self):
        base_bpm = 120
        base_speed = 6
        self.speed = base_speed * (self.bpm / base_bpm)
        self.speed = max(2, min(12, self.speed))
        print(f"[GameScreen] Скорость обновлена: BPM={self.bpm}, Speed={self.speed:.2f}")

    def update_game(self):

        if not self.countdown_active and self.game_timer.isValid():
            self.game_time = self.game_timer.elapsed() / 1000.0 + self.audio_offset

        if not self.countdown_active:
            while self.note_spawn_queue and self.note_spawn_queue[0].get("time", 0) <= self.game_time:
                note_info = self.note_spawn_queue.pop(0)
                lane = note_info.get("lane", 0)
                time = note_info.get("time", 0.0)
                note_type = note_info.get("type", "DefaultNote")

                pixels_per_sec = self.speed * (1000 / 16)

                initial_y_offset_from_top = -20
                y_now = initial_y_offset_from_top + (self.game_time - time) * pixels_per_sec

                if note_type == "DefaultNote":
                    if y_now < self.height() + 20:
                        note = DefaultNote(lane, y=y_now)
                        self.notes.append(note)
                elif note_type == "HoldNote":
                    duration = note_info.get("duration", 1.0)
                    height = int(duration * pixels_per_sec)
                    if y_now < self.height() + height:
                        note = HoldNote(lane, y=y_now, length=height, hold_time=duration * 1000)
                        self.notes.append(note)
                else:
                    print(f"Неизвестный тип ноты: {note_type}")

        for note in self.notes:
            if isinstance(note, HoldNote):
                lane_pressed = self.player.lanes_state[note.lane]
                in_hit_zone = note.y + note.height >= self.hit_zone_y and note.y <= self.hit_zone_y + 20
                note.is_being_held = lane_pressed and in_hit_zone
                # if note.is_being_held:
                #     print(f"HOLD lane {note.lane} удерживается, прогресс {note.hit_progress:.2f}")

            note.update(speed=self.speed)

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
        if event.key() == Qt.Key_Escape:
            if hasattr(self.parent(), "transitions"):
                self.parent().transitions.close_game()
            return

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

    def closeEvent(self, event):
        print("[GameScreen] closeEvent вызван.")

        if self.timer.isActive():
            self.timer.stop()
        if self.countdown_timer.isActive():
            self.countdown_timer.stop()

        if hasattr(self.parent(), "music_manager"):
            self.parent().music_manager.stop_game_music()

        super().closeEvent(event)

    def paintEvent(self, event):
        painter = QPainter(self)

        for i in range(self.lanes):
            x = i * self.lane_width
            color = QColor(80, 80, 120) if self.player.lanes_state[i] else QColor(40, 40, 40)
            rect_x = int(x)
            rect_y = 0
            rect_width = int(self.lane_width)
            rect_height = int(self.height())
            if all(isinstance(v, (int, float)) and not (math.isnan(v) or math.isinf(v)) for v in
                   [rect_x, rect_y, rect_width, rect_height]):
                painter.fillRect(QRect(rect_x, rect_y, rect_width, rect_height), color)

        hit_zone_x = 0
        hit_zone_y = int(self.hit_zone_y)
        hit_zone_width = int(self.width())
        hit_zone_height = 20
        if all(isinstance(v, (int, float)) and not (math.isnan(v) or math.isinf(v)) for v in
               [hit_zone_x, hit_zone_y, hit_zone_width, hit_zone_height]):
            painter.fillRect(QRect(hit_zone_x, hit_zone_y, hit_zone_width, hit_zone_height), QColor(80, 80, 80))

        for note in self.notes:
            x = note.lane * self.lane_width

            if not all(isinstance(v, (int, float)) for v in [note.y, note.height]):
                continue

            if math.isnan(note.y) or math.isinf(note.y) or math.isnan(note.height) or math.isinf(note.height):
                continue

            if note.y + note.height < 0 or note.y > self.height():
                continue

            rect_y = int(note.y)
            rect_height = int(note.height)
            rect_x = int(x)

            if rect_height <= 0 or self.lane_width <= 0 or math.isnan(rect_height) or math.isinf(rect_height):
                continue

            if isinstance(note, HoldNote):
                painter.fillRect(QRect(rect_x, rect_y, self.lane_width, rect_height), QColor(200, 50, 50))
                green_height = int(rect_height * note.hit_progress)
                if green_height > 0:
                    green_y = int(note.y + rect_height - green_height)
                    if green_y >= 0 and green_y <= self.height() and green_height <= rect_height and not math.isnan(
                            green_y) and not math.isinf(green_y):
                        painter.fillRect(QRect(rect_x, green_y, self.lane_width, green_height), QColor(50, 200, 50))
            else:
                painter.fillRect(QRect(rect_x, rect_y, self.lane_width, rect_height), QColor(200, 50, 50))

        painter.setPen(QColor(255, 255, 255))
        painter.drawText(20, 40, f"Score: {self.score_manager.get_score()}")
        painter.drawText(20, 70, f"Combo: {self.combo}")
        painter.drawText(20, 100, f"BPM: {self.bpm}")
        painter.drawText(20, 130, f"Speed: {self.speed:.2f}")
        painter.drawText(20, 160, f"Time: {self.game_time:.3f}s")
        painter.drawText(20, 190, f"Offset: {self.audio_offset:.3f}s")

        if self.countdown_active:
            painter.setFont(QFont("Arial", 72, QFont.Bold))
            painter.setPen(QColor(255, 255, 255))
            fm = painter.fontMetrics()
            text_width = fm.width(str(self.countdown_remaining))
            text_height = fm.height()
            x_pos = (self.width() - text_width) // 2
            y_pos = (self.height() + text_height) // 2
            painter.drawText(x_pos, y_pos, str(self.countdown_remaining))
