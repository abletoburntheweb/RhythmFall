from PyQt5.QtCore import QTimer

from logic.achievement_pop_up import AchievementPopUp


class NotificationManager:
    def __init__(self):
        self.parent_widget = None
        self.queue = []
        self.active_popups = []
        self.max_active_popups = 3
        self.timer = QTimer()
        self.timer.timeout.connect(self.check_queue)

    def set_parent(self, parent_widget):
        self.parent_widget = parent_widget

    def show_popup(self, title, description, icon_path=None):
        if not self.parent_widget:
            print("[NotificationManager] Родительский виджет не установлен!")
            return

        self.queue.append({
            "title": title,
            "description": description,
            "icon_path": icon_path
        })

        if not self.timer.isActive():
            self.timer.start(1000)

        self.show_next_popups()

    def show_next_popups(self):
        while len(self.active_popups) < self.max_active_popups and self.queue:
            popup_data = self.queue.pop(0)
            popup = AchievementPopUp(
                title=popup_data["title"],
                description=popup_data["description"],
                icon_path=popup_data["icon_path"],
                parent=self.parent_widget
            )

            self.active_popups.append(popup)

            popup.show_popup()

    def check_queue(self):
        self.active_popups = [popup for popup in self.active_popups if popup.isVisible()]

        if len(self.active_popups) < self.max_active_popups and self.queue:
            self.show_next_popups()

        if not self.queue and not self.active_popups:
            self.timer.stop()