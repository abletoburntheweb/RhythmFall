# logic/debug_menu.py
from PyQt5.QtWidgets import QWidget, QLabel, QVBoxLayout
from PyQt5.QtCore import Qt
from PyQt5.QtGui import QPainter, QColor


class DebugMenu(QWidget):
    def __init__(self, parent=None):
        super().__init__(parent)
        self.setWindowTitle("Debug Menu")
        self.setFixedSize(400, 200)

        self.setWindowFlags(Qt.FramelessWindowHint | Qt.WindowStaysOnTopHint)
        self.setAttribute(Qt.WA_TranslucentBackground)

        layout = QVBoxLayout()

        # Заголовок
        title = QLabel("🛠 DEBUG: управление игрой", self)
        title.setStyleSheet("color: white; font-size: 12pt; font-weight: bold;")
        layout.addWidget(title)

        # FPS
        self.fps_label = QLabel("FPS: ---", self)
        self.fps_label.setStyleSheet("color: white; font-size: 11pt;")
        layout.addWidget(self.fps_label)

        self.setLayout(layout)

    def paintEvent(self, event):
        painter = QPainter(self)
        background_color = QColor(30, 30, 30, 200)  # полупрозрачный тёмный фон
        painter.fillRect(self.rect(), background_color)

    def toggle_visibility(self):
        self.setVisible(not self.isVisible())
        if self.isVisible():
            self.raise_()
            self.setFocus()

    def update_debug_info(self, game_screen):
        fps = getattr(game_screen, "fps", "---")
        self.fps_label.setText(f"FPS: {fps}")
