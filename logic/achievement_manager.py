import json
import os
from PyQt5.QtWidgets import QWidget


class AchievementManager:
    def __init__(self, parent=None, json_path="data/achievements_data.json"):
        self.parent = parent
        self.json_path = json_path

        self.achievements = self.load_achievements()

    def load_achievements(self):
        if not os.path.exists(self.json_path):
            print(f"[AchievementManager] Файл {self.json_path} не найден. Загружен пустой список.")
            return []

        try:
            with open(self.json_path, "r", encoding="utf-8") as f:
                data = json.load(f)
            return data.get("achievements", [])
        except Exception as e:
            print(f"[AchievementManager] Ошибка при загрузке: {e}")
            return []

    def save_achievements(self):
        try:
            with open(self.json_path, "w", encoding="utf-8") as f:
                json.dump({"achievements": self.achievements}, f, ensure_ascii=False, indent=4)
            print(f"[AchievementManager] Данные сохранены в {self.json_path}")
        except Exception as e:
            print(f"[AchievementManager] Ошибка при сохранении: {e}")

    def get_achievement_progress(self, achievement):
        return achievement.get("current", 0), achievement.get("total", 1)

    def update_progress(self, achievement_id, value):
        for a in self.achievements:
            if a.get("id") == achievement_id:
                a["current"] = min(value, a.get("total", 1))
                if a["current"] >= a.get("total", 1):
                    self.unlock_achievement(a)
                self.save_achievements()
                return
        print(f"[AchievementManager] Достижение с id={achievement_id} не найдено")

    def unlock_achievement(self, achievement):
        if not achievement.get("unlocked", False):
            achievement["unlocked"] = True
            achievement["current"] = achievement.get("total", 1)
            print(f"🏆 Достижение открыто: {achievement['title']}")
            self.save_achievements()

            if hasattr(self, "music_manager") and self.music_manager:
                print(f"[AchievementManager] Воспроизводим звук ачивки через напрямую")
                self.music_manager.play_achievement_sound()
            elif self.parent and hasattr(self.parent, "music_manager"):
                print(f"[AchievementManager] Воспроизводим звук ачивки через parent")
                self.parent.music_manager.play_achievement_sound()
            else:
                print(f"[AchievementManager] НЕТ music_manager для воспроизведения звука!")

            if self.parent and hasattr(self.parent, "get_notification_manager"):
                notification_manager = self.parent.get_notification_manager()
                notification_manager.show_popup(
                    title=achievement["title"],
                    description=achievement.get("description", "Описание отсутствует"),
                    icon_path=achievement.get("image", "assets/achievements/default.png"),
                )

    def reset_achievements(self):
        for a in self.achievements:
            a["unlocked"] = False
            a["current"] = 0
        self.save_achievements()
        print("[AchievementManager] Все достижения сброшены.")

    def update_purchase_achievements(self, player_data_manager):
        unlocked_items = player_data_manager.get_all_unlocked_items()
        purchased_count = len(unlocked_items)

        purchase_achievements = {
            7: 3,
            8: 5,
            9: 10,
            10: 15
        }

        for ach_id, required_count in purchase_achievements.items():
            achievement = next((a for a in self.achievements if a.get("id") == ach_id), None)
            if achievement:
                achievement["current"] = purchased_count
                if purchased_count >= required_count and not achievement.get("unlocked", False):
                    self.unlock_achievement(achievement)

        self.save_achievements()