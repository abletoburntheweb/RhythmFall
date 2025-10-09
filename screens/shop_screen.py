from PyQt5.QtGui import QPixmap
from PyQt5.QtWidgets import QWidget, QVBoxLayout, QHBoxLayout, QScrollArea, QGridLayout, QLabel, QFrame, QPushButton
from PyQt5.QtCore import Qt
import json
from logic.creation import Create
from logic.transitions import Transitions
from logic.player_data import PlayerDataManager

CATEGORY_MAP = {
    "Кик": "Kick",
    "Снейр": "Snare",
    "Фоны": "Backgrounds",
    "Обложки": "Covers",
    "Прочее": "Misc"
}


class ShopScreen(QWidget):
    def __init__(self, parent=None, game_screen=None, music_manager=None):
        super().__init__(parent)
        self.parent = parent
        self.create = Create(self)
        self.transitions = Transitions(self.parent)
        self.player_data_manager = PlayerDataManager()
        self.music_manager = music_manager
        self.game_screen = game_screen

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

        self.currency_label = self.create.shop_currency_label(
            currency=self.player_data_manager.get_currency()
        )
        self.layout.addWidget(self.currency_label)

        category_layout = QHBoxLayout()
        category_layout.setSpacing(20)
        categories = ["Все", "Кик", "Снейр", "Фоны", "Обложки", "Прочее"]

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
            is_active = (
                self.player_data_manager.get_active_item(category) == item_id
                if category else False
            )

            item_widget = self.create.shop_item_widget(
                item,
                is_purchased=is_purchased,
                is_active=is_active,
                buy_callback=self.buy_item,
                use_callback=self.use_item if item.get("is_equippable", True) else None,
                cover_click_callback=self.show_cover_gallery
            )
            self.grid_layout.addWidget(item_widget, row, col)

    def filter_items(self, category):
        while self.grid_layout.count():
            item = self.grid_layout.takeAt(0)
            if item.widget():
                item.widget().deleteLater()

        filtered_items = [
            item for item in self.items
            if category == "Все" or item.get("category", "Прочее") == category
        ]

        for index, item in enumerate(filtered_items):
            row = index // 5
            col = index % 5

            item_id = item["item_id"]
            category_ru = item["category"]
            internal_category = CATEGORY_MAP.get(category_ru, category_ru)

            is_purchased = self.player_data_manager.is_item_unlocked(item_id)
            is_active = (
                self.player_data_manager.get_active_item(internal_category) == item_id
                if internal_category else False
            )

            item_widget = self.create.shop_item_widget(
                item,
                is_purchased=is_purchased,
                is_active=is_active,
                buy_callback=self.buy_item,
                use_callback=self.use_item if item.get("is_equippable", True) else None,
                cover_click_callback=self.show_cover_gallery
            )
            self.grid_layout.addWidget(item_widget, row, col)

        print(f"[ShopScreen] Отфильтровано {len(filtered_items)} предметов ({category})")

    def buy_item(self, item):
        current_currency = self.player_data_manager.get_currency()
        item_id = item["item_id"]

        if current_currency >= item["price"] and not self.player_data_manager.is_item_unlocked(item_id):
            self.player_data_manager.add_currency(-item["price"])
            self.player_data_manager.unlock_item(item_id)
            print(f"[ShopScreen] Куплен {item_id} за {item['price']}")

            self.currency_label.setText(
                f"💰 Валюта: {self.player_data_manager.get_currency()}"
            )

            if hasattr(self.parent, "achievement_manager"):
                self.parent.achievement_manager.update_purchase_achievements(self.player_data_manager)

            self.refresh()
        else:
            print("[ShopScreen] Недостаточно валюты или уже куплено.")

    def use_item(self, item):
        item_id = item["item_id"]
        category_ru = item["category"]
        category = CATEGORY_MAP.get(category_ru, None)

        if category in ["Kick", "Snare"]:
            self.player_data_manager.set_active_item(category, item_id)
            print(f"[ShopScreen] Активирован {item_id} для {category}")
            self.preview_sound(item)
        elif category == "Covers":

            self.player_data_manager.set_active_item(category, item_id)
            print(f"[ShopScreen] Активирован пак обложек {item_id}")
        elif category == "Backgrounds":
            self.player_data_manager.set_active_item(category, item_id)
            print(f"[ShopScreen] Активирован фон {item_id}")
        elif category == "Misc":

            self.player_data_manager.set_active_item(category, item_id)
            print(f"[ShopScreen] Активирован пассивный предмет {item_id}")
            self.apply_passive_item(item)
        elif category:
            self.player_data_manager.set_active_item(category, item_id)
            print(f"[ShopScreen] Активирован {item_id}")
        else:
            print(f"⚠️ Неизвестная категория: {category_ru}")

        self.refresh()

    def preview_sound(self, item):
        audio_path = item.get("audio")
        if audio_path and self.music_manager:
            print(f"[ShopScreen] Предпросмотр: {audio_path}")
            self.music_manager.play_custom_hit_sound(audio_path)
        else:
            print(f"[ShopScreen] Нет аудио у {item.get('item_id')}")

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
            print(f"[ShopScreen] Доп. жизнь активирована")
        elif item_id == "misc_2":
            self.game_screen.score_manager.combo_booster_bonus = 1
            print("[ShopScreen] Combo Booster активирован")
            self.player_data_manager.save_player_data()

    def show_cover_gallery(self, item):
        self.overlay = self.create.shop_cover_gallery_overlay(self)

        back_button = self.create.button(
            "Назад",
            self.close_cover_gallery,
            x=40, y=40, w=180, h=60,
            preset=3
        )
        back_button.setParent(self.overlay)

        images_folder = item.get("images_folder")
        images_count = item.get("images_count", 0)

        if not images_folder or images_count == 0:
            error_label = QLabel("Нет доступных обложек", self.overlay)
            error_label.setStyleSheet("color: red; font-size: 24px;")
            error_label.setAlignment(Qt.AlignCenter)
            error_label.setGeometry(0, 150, self.width(), 50)
            error_label.show()
            self.overlay.show()
            return

        loaded_pixmaps = []
        for i in range(1, images_count + 1):
            cover_path = f"{images_folder}/cover{i}.png"
            pixmap = QPixmap(cover_path)
            if not pixmap.isNull():
                scaled_pixmap = pixmap.scaled(330, 330, Qt.KeepAspectRatio, Qt.SmoothTransformation)
                loaded_pixmaps.append(scaled_pixmap)
            else:
                loaded_pixmaps.append(None)

        cover_widgets = []
        for i in range(1, images_count + 1):
            cover_path = f"{images_folder}/cover{i}.png"

            row = 0 if i <= 4 else 1
            col = (i - 1) % 4 if i <= 4 else (i - 5) % 3
            x = 300 + col * 370
            y = 150 + row * 370

            cover_widget = self.create.shop_cover_gallery_cover_widget(cover_path, x, y, size=350)
            cover_widget.setParent(self.overlay)
            cover_widgets.append(cover_widget)

        self.overlay.show()
        back_button.show()
        for widget in cover_widgets:
            widget.show()

        self.overlay.setFocusPolicy(Qt.StrongFocus)
        self.overlay.setFocus()

    def close_cover_gallery(self):
        if hasattr(self, 'overlay'):
            self.overlay.deleteLater()
            del self.overlay

    def keyPressEvent(self, event):
        if event.key() == Qt.Key_Escape:
            self.transitions.close_shop()
        else:
            super().keyPressEvent(event)
