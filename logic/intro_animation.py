from PyQt5.QtWidgets import QWidget, QLabel, QGraphicsOpacityEffect
from PyQt5.QtCore import Qt, QPropertyAnimation, QEasingCurve, QTimer
from PyQt5.QtGui import QPixmap


class IntroAnimation(QWidget):
    def __init__(self, parent=None, main_menu_widget=None, logo_path="assets/textures/logo2.png", duration=1500,
                 intro_length=4500):
        super().__init__(parent)
        self.parent = parent
        self.main_menu_widget = main_menu_widget
        self.parent = parent
        self.logo_path = logo_path
        self.duration = duration
        self.intro_length = intro_length
        self.logo_label = None
        self.is_finished = False
        self.setFixedSize(1920, 1080)
        self.music_manager = getattr(parent, "music_manager", None)

        self.setFocusPolicy(Qt.StrongFocus)
        self.setFocus()
        self.init_intro()

    def init_intro(self):
        self.logo_label = QLabel(self)
        pixmap = QPixmap(self.logo_path)

        if pixmap.isNull():
            print(f"Ошибка: не удалось загрузить файл {self.logo_path}")
            self.finish_intro()
            return

        self.logo_label.setPixmap(
            pixmap.scaled(self.size(), Qt.IgnoreAspectRatio, Qt.SmoothTransformation)
        )
        self.logo_label.setGeometry(0, 0, 1920, 1080)
        self.logo_label.setAlignment(Qt.AlignCenter)
        self.logo_label.show()
        self.fade_in(self.logo_label)

        QTimer.singleShot(self.intro_length, self.finish_intro)

        if self.music_manager:
            self.music_manager.play_music(self.music_manager.intro_music)

    def fade_in(self, widget):
        effect = QGraphicsOpacityEffect(widget)
        widget.setGraphicsEffect(effect)
        anim = QPropertyAnimation(effect, b"opacity")
        anim.setDuration(self.duration)
        anim.setEasingCurve(QEasingCurve.OutQuad)
        anim.setStartValue(0)
        anim.setEndValue(1)
        anim.start()
        widget.anim = anim

    def fade_out(self, widget, callback=None):
        effect = QGraphicsOpacityEffect(widget)
        widget.setGraphicsEffect(effect)
        anim = QPropertyAnimation(effect, b"opacity")
        anim.setDuration(self.duration)
        anim.setEasingCurve(QEasingCurve.InQuad)
        anim.setStartValue(1)
        anim.setEndValue(0)
        anim.finished.connect(lambda: callback() if callback else None)
        anim.start()
        widget.anim = anim

    def finish_intro(self):
        if self.is_finished:
            return

        if self.logo_label:
            self.logo_label.hide()
            self.logo_label.deleteLater()
            self.logo_label = None

        self.is_finished = True

        if self.parent and self.main_menu_widget:
            self.parent.setCurrentWidget(self.main_menu_widget)

            if self.music_manager:
                self.music_manager.stop_music()
                self.music_manager.play_music(self.music_manager.menu_music)

            if hasattr(self.main_menu_widget, "is_intro_finished"):
                self.main_menu_widget.is_intro_finished = True

    def keyPressEvent(self, event):
        if event.key() == Qt.Key_Space:
            self.finish_intro()
