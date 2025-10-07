import json
import os


class PlayerDataManager:
    def __init__(self, path="data/player_data.json"):
        self.path = path
        self.data = {
            "currency": 0,
            "items": {},
            "active_items": {
                "Kick": "kick_default",
                "Snare": "snare_default",
                "Backgrounds": "background_default"
            }
        }
        self._load()

    def _load(self):
        if os.path.exists(self.path):
            with open(self.path, "r") as f:
                loaded_data = json.load(f)
                self.data["currency"] = loaded_data.get("currency", 0)
                self.data["items"] = loaded_data.get("items", {})
                self.data["active_items"].update(loaded_data.get("active_items", {}))
        else:
            self._save()

    def _save(self):
        active_items_clean = {
            "Kick": self.data["active_items"].get("Kick", "kick_default"),
            "Snare": self.data["active_items"].get("Snare", "snare_default"),
            "Backgrounds": self.data["active_items"].get("Backgrounds", "background_default"),
            "Misc": self.data["active_items"].get("Misc", None)
        }
        self.data["active_items"] = active_items_clean

        with open(self.path, "w", encoding="utf-8") as f:
            json.dump(self.data, f, indent=4, ensure_ascii=False)

    def save_player_data(self):
        self._save()

    def get_currency(self):
        return self.data.get("currency", 0)

    def add_currency(self, amount):
        self.data["currency"] = self.get_currency() + amount
        self._save()

    def get_items(self):
        return self.data.get("items", {})

    def unlock_item(self, item_name):
        self.data["items"][item_name] = True
        self._save()

    def is_item_unlocked(self, item_name):
        return self.data["items"].get(item_name, False)

    def set_active_item(self, category, item_id):
        if category in self.data["active_items"]:
            self.data["active_items"][category] = item_id
            self.save_player_data()
            print(f"✅ {item_id} установлен как активный для категории {category}")

            if hasattr(self, "game_screen") and self.game_screen:
                self.game_screen.update_active_items()

    def get_active_item(self, category):
        return self.data["active_items"].get(category, None)

    def is_achievement_unlocked(self, achievement_id):
        if "achievements" not in self.data:
            self.data["achievements"] = {}
            self._save()

        return self.data["achievements"].get(str(achievement_id), False)

    def unlock_achievement(self, achievement_id):
        if "achievements" not in self.data:
            self.data["achievements"] = {}
        self.data["achievements"][str(achievement_id)] = True
        self._save()

    def get_all_unlocked_items(self):
        return [item_id for item_id, unlocked in self.data.get("items", {}).items() if unlocked]