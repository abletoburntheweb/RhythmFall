import os

from PyQt5.QtWidgets import QWidget, QLabel, QVBoxLayout, QScrollArea, QFrame, QHBoxLayout
from PyQt5.QtGui import QPixmap, QLinearGradient, QBrush, QPainter, QColor
from PyQt5.QtCore import Qt
from logic.creation import Create
from logic.player_data import PlayerDataManager
import json

class AchievementsScreen(QWidget):
    def __init__(self, parent=None):
        super().__init__(parent)
        self.parent = parent
        self.create = Create(self)
        self.player_data_manager = PlayerDataManager()
        self.setFixedSize(1920, 1080)
        self.setFocusPolicy(Qt.StrongFocus)

        self.bg_label = self.create.background(texture_path="default")

        self.layout = QVBoxLayout()
        self.layout.setContentsMargins(50, 50, 50, 50)
        self.layout.setSpacing(20)
        self.setLayout(self.layout)

        self.title_label = self.create.achievement_title()
        self.layout.addWidget(self.title_label)

        self.scroll = QScrollArea()
        self.scroll.setWidgetResizable(True)
        self.scroll.setStyleSheet("background: transparent; border: none;")
        self.layout.addWidget(self.scroll)

        self.content = QWidget()
        self.scroll.setWidget(self.content)
        self.grid_layout = QVBoxLayout(self.content)
        self.grid_layout.setSpacing(10)

        with open("data/achievements_data.json", "r", encoding="utf-8") as f:
            self.achievements = json.load(f)["achievements"]

        self.update_achievements()

        self.back_button = self.create.button(
            "Назад",
            self.parent.transitions.close_achievements,
            x=40, y=40, w=180, h=60,
            preset=3
        )

    @staticmethod
    def safe_icon(path, fallback="assets/achievements/default.png"):
        return path if os.path.exists(path) else fallback

    def update_achievements(self):
        for i in reversed(range(self.grid_layout.count())):
            widget = self.grid_layout.itemAt(i).widget()
            if widget:
                widget.deleteLater()

        for ach in self.achievements:
            current, total = self.parent.achievement_manager.get_achievement_progress(ach)
            progress_text = f"{current} / {total}" if total > 1 else ""
            unlocked = ach.get("unlocked", False)

            card = self.create.achievement_card(
                title=ach["title"],
                description=ach.get("description", "Описание отсутствует"),
                progress_text=progress_text,
                icon_path=self.safe_icon(ach.get("image", "")),
                unlocked=unlocked
            )
            self.grid_layout.addWidget(card)

    def keyPressEvent(self, event):
        if event.key() == Qt.Key_Escape:
            self.parent.transitions.close_achievements()
        else:
            super().keyPressEvent(event)