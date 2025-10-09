import os

from PyQt5.QtWidgets import QWidget, QLabel, QHBoxLayout, QVBoxLayout, QFrame
from PyQt5.QtGui import QPixmap
from PyQt5.QtCore import Qt, QTimer, QPropertyAnimation, QRect, QEasingCurve


class AchievementPopUp(QWidget):
    def __init__(self, title, description, progress_text="", icon_path=None, parent=None):
        super().__init__(parent)
        self.setWindowFlags(Qt.FramelessWindowHint | Qt.WindowStaysOnTopHint | Qt.Tool)
        self.setAttribute(Qt.WA_TranslucentBackground)
        self.setParent(parent)

        frame = QFrame(self)
        frame.setStyleSheet("""
            QFrame {
                background-color: rgba(30, 30, 30, 220);
                border-radius: 15px;
                border: 2px solid rgba(255, 215, 0, 120);
            }
        """)
        frame.setFixedSize(500, 140)

        layout = QHBoxLayout(frame)
        layout.setContentsMargins(15, 15, 15, 15)
        layout.setSpacing(15)

        if icon_path and os.path.exists(icon_path):
            icon_label = QLabel(frame)
            pixmap = QPixmap(icon_path).scaled(90, 90, Qt.KeepAspectRatio, Qt.SmoothTransformation)
            icon_label.setPixmap(pixmap)
            icon_label.setFixedSize(90, 90)
            icon_label.setAlignment(Qt.AlignCenter)
            layout.addWidget(icon_label, stretch=0)
        else:
            default_icon_path = "assets/achievements/default.png"
            if os.path.exists(default_icon_path):
                icon_label = QLabel(frame)
                pixmap = QPixmap(default_icon_path).scaled(90, 90, Qt.KeepAspectRatio, Qt.SmoothTransformation)
                icon_label.setPixmap(pixmap)
                icon_label.setFixedSize(90, 90)
                icon_label.setAlignment(Qt.AlignCenter)
                layout.addWidget(icon_label, stretch=0)

        text_label = QLabel(frame)
        text_label.setText(f"""
            <div style="font-family: Segoe UI; color: white; line-height: 1.4;">
                <span style="color: gold; font-size: 14px;">🏆 Достижение получено!</span><br>
                <span style="font-size: 20px; font-weight: bold; color: white;">{title}</span><br>
                <span style="font-size: 14px; color: #DDDDDD;">{description}</span><br>
                {f"<span style='font-size: 13px; color: lightgreen;'>{progress_text}</span>" if progress_text else ""}
            </div>
        """)
        text_label.setWordWrap(True)
        text_label.setAlignment(Qt.AlignLeft | Qt.AlignTop)
        layout.addWidget(text_label, stretch=1)

        self.animation = QPropertyAnimation(self, b"geometry")
        self.animation.setDuration(600)
        self.animation.setEasingCurve(QEasingCurve.OutCubic)

        self.timer = QTimer(self)
        self.timer.timeout.connect(self.close)

        self.frame = frame

    def show_popup(self):
        if not self.parent():
            print("[AchievementPopUp] Нет родителя!")
            return

        screen_geometry = self.parent().geometry()
        active_popup_count = len(
            [p for p in self.parent().children() if isinstance(p, AchievementPopUp) and p.isVisible()])
        y_offset = active_popup_count * (self.frame.height() + 5)

        x = screen_geometry.width() - self.frame.width() - 40
        y = screen_geometry.height() - self.frame.height() - 40 - y_offset

        start_rect = QRect(x, screen_geometry.height(), self.frame.width(), self.frame.height())
        end_rect = QRect(x, y, self.frame.width(), self.frame.height())

        self.setGeometry(start_rect)
        self.show()

        self.animation.setStartValue(start_rect)
        self.animation.setEndValue(end_rect)
        self.animation.start()

        self.timer.start(5000)

    def close(self):
        current_rect = self.geometry()
        end_rect = QRect(current_rect.x(),
                         self.parent().height(),
                         self.frame.width(),
                         self.frame.height())

        self.animation.setStartValue(current_rect)
        self.animation.setEndValue(end_rect)
        self.animation.finished.connect(super().close)
        self.animation.start()