from PyQt5.QtWidgets import QWidget, QVBoxLayout, QHBoxLayout, QScrollArea, QGridLayout
from PyQt5.QtCore import Qt
import json
from logic.creation import Create
from logic.transitions import Transitions
from logic.player_data import PlayerDataManager

CATEGORY_MAP = {
    "Кик": "Kick",
    "Снейр": "Snare",
    "Фоны": "Backgrounds",
    "Прочее": "Misc"
}


class ShopScreen(QWidget):
    def __init__(self, parent=None, game_screen=None, music_manager=None):
        super().__init__(parent)
        self.parent = parent
        self.create = Create(self)
        self.transitions = Transitions(self.parent)
        self.player_data_manager = PlayerDataManager()
        self.game_screen = game_screen
        self.music_manager = music_manager
        self.setFixedSize(1920, 1080)
        self.setFocusPolicy(Qt.StrongFocus)

        self.bg_label = self.create.background(texture_path="default")

        self.layout = QVBoxLayout()
        self.layout.setContentsMargins(40, 40, 40, 40)
        self.layout.setSpacing(20)
        self.setLayout(self.layout)

        self.back_button = self.create.button(
            "Назад",
            self.transitions.close_shop,
            x=40, y=40, w=180, h=60,
            preset=3
        )

        self.currency_label = self.create.shop_currency_label(currency=self.player_data_manager.get_currency())
        self.layout.addWidget(self.currency_label)

        category_layout = QHBoxLayout()
        category_layout.setSpacing(20)
        categories = ["Все", "Кик", "Снейр", "Фоны", "Прочее"]

        for category in categories:
            btn = self.create.shop_category_button(
                text=category,
                callback=lambda _, cat=category: self.filter_items(cat),
                is_all=(category == "Все")
            )
            category_layout.addWidget(btn)

        self.layout.addLayout(category_layout)

        scroll = QScrollArea()
        scroll.setWidgetResizable(True)
        scroll.setStyleSheet("background: transparent; border: none;")
        content = QWidget()
        scroll.setWidget(content)

        self.grid_layout = QGridLayout()
        self.grid_layout.setSpacing(30)
        content.setLayout(self.grid_layout)

        with open("data/shop_data.json", "r", encoding="utf-8") as f:
            self.shop_data = json.load(f)

        self.items = self.shop_data["items"]
        self.update_items()

        self.layout.addWidget(scroll)

    def update_items(self):
        for index, item in enumerate(self.items):
            row = index // 5
            col = index % 5
            item_id = item["item_id"]
            category_ru = item["category"]
            category = CATEGORY_MAP.get(category_ru, None)
            is_purchased = self.player_data_manager.is_item_unlocked(item_id)
            is_active = self.player_data_manager.get_active_item(category) == item_id if category else False

            item_widget = self.create.shop_item_widget(
                item,
                is_purchased=is_purchased,
                is_active=is_active,
                buy_callback=self.buy_item,
                use_callback=self.use_item if item.get("is_equippable", True) else None
            )
            self.grid_layout.addWidget(item_widget, row, col)

    def filter_items(self, category):
        while self.grid_layout.count():
            item = self.grid_layout.takeAt(0)
            if item.widget():
                item.widget().deleteLater()

        filtered_items = []
        for item in self.items:
            item_category = item.get("category", "Прочее")
            if category == "Все" or item_category == category:
                filtered_items.append(item)

        for index, item in enumerate(filtered_items):
            row = index // 5
            col = index % 5

            item_id = item["item_id"]
            category_ru = item["category"]
            internal_category = CATEGORY_MAP.get(category_ru, category_ru)

            is_purchased = self.player_data_manager.is_item_unlocked(item_id)
            is_active = self.player_data_manager.get_active_item(
                internal_category) == item_id if internal_category and internal_category != category_ru else False

            item_widget = self.create.shop_item_widget(
                item,
                is_purchased=is_purchased,
                is_active=is_active,
                buy_callback=self.buy_item,
                use_callback=self.use_item if item.get("is_equippable", True) else None
            )
            self.grid_layout.addWidget(item_widget, row, col)

        print(f"[ShopScreen] Отфильтровано {len(filtered_items)} предметов для категории: {category}")

    def buy_item(self, item):
        current_currency = self.player_data_manager.get_currency()
        item_id = item["item_id"]

        if current_currency >= item["price"] and not self.player_data_manager.is_item_unlocked(item_id):
            self.player_data_manager.add_currency(-item["price"])
            self.player_data_manager.unlock_item(item_id)
            print(f"[ShopScreen] Игрок купил {item['item_id']} за {item['price']} валюты")
            self.currency_label.setText(f"💰 Валюта: {self.player_data_manager.get_currency()}")

            self.apply_passive_item(item)

            self.parent.achievement_manager.update_purchase_achievements(self.player_data_manager)

            self.refresh()
        else:
            print(f"[ShopScreen] Недостаточно валюты или предмет уже куплен.")

    def use_item(self, item):
        item_id = item["item_id"]
        category_ru = item["category"]
        category = CATEGORY_MAP.get(category_ru, None)

        if category_ru in ["Кик", "Снейр"]:
            internal_category = "Kick" if category_ru == "Кик" else "Snare"
            self.player_data_manager.set_active_item(internal_category, item_id)
            print(f"[ShopScreen] Игрок выбрал {item_id} для {internal_category}")

            self.preview_sound(item)
            return

        if category:
            self.player_data_manager.set_active_item(category, item_id)
            print(f"[ShopScreen] Игрок использует {item_id}")

            self.refresh()
        else:
            print(f"⚠️ Игнорируем неизвестную категорию: {category_ru}")

    def preview_sound(self, item):
        audio_path = item.get("audio")
        if audio_path:
            print(f"[ShopScreen] Воспроизводим предпросмотр: {audio_path}")
            if self.music_manager:
                self.music_manager.play_custom_hit_sound(audio_path)
            else:
                print("[ShopScreen] MusicManager не найден для воспроизведения.")
        else:
            print(f"[ShopScreen] У элемента {item['item_id']} нет аудио для предпросмотра.")

    def refresh(self):
        while self.grid_layout.count():
            item = self.grid_layout.takeAt(0)
            if item.widget():
                item.widget().deleteLater()

        self.update_items()

    def apply_passive_item(self, item):
        item_id = item.get("item_id")
        if item_id == "misc_1":
            self.game_screen.lives_display.set_shop_extra_life(True)
            print(f"[ShopScreen] Доп. жизнь активирована ({self.game_screen.lives_display.total_lives})")
        elif item_id == "misc_2":
            self.game_screen.score_manager.combo_booster_bonus = 1
            print("[ShopScreen] Combo Booster активирован (стартовый множитель x2)")
            self.game_screen.player_data_manager.save_player_data()
            self.game_screen.player_data_manager.save_player_data()

    def keyPressEvent(self, event):
        if event.key() == Qt.Key_Escape:
            self.transitions.close_shop()
        else:
            super().keyPressEvent(event)