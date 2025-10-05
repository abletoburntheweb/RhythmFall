from PyQt5.QtGui import QPainter, QColor, QFont
from PyQt5.QtCore import Qt, QRect
import math


class GameRenderer:
    def __init__(self, game_screen):
        self.game_screen = game_screen
        self.lane_width = game_screen.lane_width
        self.hit_zone_y = game_screen.hit_zone_y

    def render(self, event):
        painter = QPainter(self.game_screen)

        self.render_lanes(painter)

        self.render_hit_zone(painter)

        self.render_notes(painter)

        self.render_ui(painter)

        if self.game_screen.countdown_active:
            self.render_countdown(painter)

        if self.game_screen.debug_menu and self.game_screen.debug_menu.isVisible():
            self.game_screen.debug_menu.update_debug_info(self.game_screen)

    def render_lanes(self, painter):
        for i in range(self.game_screen.lanes):
            x = i * self.lane_width
            color = QColor(80, 80, 120) if self.game_screen.player.lanes_state[i] else QColor(40, 40, 40)
            rect_x = int(x)
            rect_y = 0
            rect_width = int(self.lane_width)
            rect_height = int(self.game_screen.height())
            if all(isinstance(v, (int, float)) and not (math.isnan(v) or math.isinf(v)) for v in
                   [rect_x, rect_y, rect_width, rect_height]):
                painter.fillRect(QRect(rect_x, rect_y, rect_width, rect_height), color)

    def render_hit_zone(self, painter):
        hit_zone_x = 0
        hit_zone_y = int(self.hit_zone_y)
        hit_zone_width = int(self.game_screen.width())
        hit_zone_height = 20
        if all(isinstance(v, (int, float)) and not (math.isnan(v) or math.isinf(v)) for v in
               [hit_zone_x, hit_zone_y, hit_zone_width, hit_zone_height]):
            painter.fillRect(QRect(hit_zone_x, hit_zone_y, hit_zone_width, hit_zone_height), QColor(80, 80, 80))

    def render_notes(self, painter):
        from logic.notes import HoldNote

        for note in self.game_screen.note_manager.get_notes():
            x = note.lane * self.lane_width

            if not all(isinstance(v, (int, float)) for v in [note.y, note.height]):
                continue

            if math.isnan(note.y) or math.isinf(note.y) or math.isnan(note.height) or math.isinf(note.height):
                continue

            if note.y + note.height < 0 or note.y > self.game_screen.height():
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
                    if green_y >= 0 and green_y <= self.game_screen.height() and green_height <= rect_height and not math.isnan(
                            green_y) and not math.isinf(green_y):
                        painter.fillRect(QRect(rect_x, green_y, self.lane_width, green_height), QColor(50, 200, 50))
            else:
                painter.fillRect(QRect(rect_x, rect_y, self.lane_width, rect_height), QColor(200, 50, 50))

    def render_ui(self, painter):
        painter.setPen(QColor(255, 255, 255))
        painter.drawText(20, 40, f"Счёт: {self.game_screen.score_manager.get_score()}")
        painter.drawText(20, 70,
                         f"Комбо: {self.game_screen.score_manager.get_combo()} (x{self.game_screen.score_manager.get_combo_multiplier():.1f})")
        painter.drawText(20, 100, f"Макс. комбо: {self.game_screen.score_manager.get_max_combo()}")
        painter.drawText(20, 130, f"BPM: {self.game_screen.bpm}")
        painter.drawText(20, 160, f"Скорость: {self.game_screen.speed:.2f}")
        painter.drawText(20, 190, f"Время: {self.game_screen.game_time:.3f}с")
        painter.drawText(20, 220, f"Смещение: {self.game_screen.audio_offset:.3f}с")
        painter.drawText(20, 250, f"Точность: {self.game_screen.score_manager.get_accuracy():.2f}%")

    def render_countdown(self, painter):
        painter.setFont(QFont("Arial", 72, QFont.Bold))
        painter.setPen(QColor(255, 255, 255))
        fm = painter.fontMetrics()
        text_width = fm.width(str(self.game_screen.countdown_remaining))
        text_height = fm.height()
        x_pos = (self.game_screen.width() - text_width) // 2
        y_pos = (self.game_screen.height() + text_height) // 2
        painter.drawText(x_pos, y_pos, str(self.game_screen.countdown_remaining))