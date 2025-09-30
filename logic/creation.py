from PyQt5.QtWidgets import QPushButton, QLabel, QCheckBox, QSlider, QFrame, QVBoxLayout, QHBoxLayout, QWidget
from PyQt5.QtGui import QFont, QPixmap
from PyQt5.QtCore import Qt


class Create:
    def __init__(self, parent):
        self.parent = parent

    def bc_image(label, pixmap, size):
        scaled_pixmap = pixmap.scaled(size, Qt.IgnoreAspectRatio, Qt.SmoothTransformation)
        label.setPixmap(scaled_pixmap)
        label.resize(size)
        label.show()

    def button(self, text, callback, x, y, w, h, bold=False, font_family="Montserrat", preset=1):
        button = QPushButton(text, self.parent)
        font = QFont(font_family, 20)
        if bold:
            font.setBold(True)
        button.setFont(font)
        button.clicked.connect(lambda: self.callback(callback))
        button.setGeometry(x, y, w, h)

        # Стиль 1: Прозрачный градиент
        if preset == 1:
            button.setStyleSheet("""
                QPushButton {
                    background-color: qlineargradient(x1:0, y1:0, x2:1, y2:0,
                                                  stop:0 black, stop:1 transparent);
                    color: white;
                    border: none;
                    padding-left: 10px;
                    font-size: 20px;
                    text-align: left;
                }
                QPushButton:hover {
                    background-color: qlineargradient(x1:0, y1:0, x2:1, y2:0,
                                                  stop:0 darkgray, stop:1 transparent);
                }
            """)

        # Стиль 2: Полупрозрачный белый фон
        elif preset == 2:
            button.setStyleSheet("""
                QPushButton {
                    color: white;
                    background-color: rgba(255, 255, 255, 20);
                    border: 2px solid white;
                    border-radius: 10px;
                    padding: 10px;
                }
                QPushButton:hover {
                    background-color: rgba(255, 255, 255, 40);
                }
            """)

        # Стиль 3: Синие кнопки с белым текстом
        elif preset == 3:
            button.setStyleSheet("""
                QPushButton {
                    background-color: #007bff; /* Синий цвет */
                    color: white;
                    border: none;
                    padding: 10px 20px;
                    font-size: 24px;
                    border-radius: 10px; /* Закругленные углы */
                }
                QPushButton:hover {
                    background-color: #0056b3; /* Темнее при наведении */
                }
            """)

        return button

    def vert_buttons(self, buttons_data, spacing=80):
        buttons = []
        total_height = len(buttons_data) * 60 + (len(buttons_data) - 1) * spacing
        start_y = (self.parent.height() - total_height) // 2

        for i, item in enumerate(buttons_data):
            text = item['text']
            callback = item['callback']

            w = item.get('w', 250)
            h = item.get('h', 60)
            x = (self.parent.width() - w) // 2
            y = start_y + i * (h + spacing)

            btn = self.button(text=text, callback=callback, x=x, y=y, w=w, h=h)
            buttons.append(btn)

        return buttons

    def label(self, text, font_size=18, bold=False, x=None, y=None, w=200, h=50, font_family="Montserrat"):
        label = QLabel(text, self.parent)
        font = QFont(font_family, font_size)
        if bold:
            font.setBold(True)
        label.setFont(font)
        label.setStyleSheet("""
            color: white;
            background-color: transparent;
            font-size: 48px;
            text-shadow: 0 0 10px #ff00ff;
        """)
        label.setAlignment(Qt.AlignCenter)

        if x is None:
            x = (self.parent.width() - w) // 2
        if y is None:
            y = (self.parent.height() - h) // 4

        label.setGeometry(x, y, w, h)
        return label

    def ver_label(self, version="unknown", x=20, y=None, w=100, h=30, font_size=14, font_family="Montserrat"):
        text = f"ver{version}"
        label = QLabel(text, self.parent)
        font = QFont(font_family, font_size)
        label.setFont(font)
        label.setStyleSheet("color: white;")
        if y is None:
            y = self.parent.height() - h - 10
        label.setGeometry(x, y, w, h)
        return label

    def g_panel(self, x=0, y=0, w=800, h=1080):
        label = QLabel(self.parent)
        label.setGeometry(x, y, w, h)
        label.setStyleSheet("""
            background-color: qlineargradient(x1:0, y1:0, x2:1, y2:0,
                                              stop:0 rgba(0,0,0,250), stop:1 rgba(0,0,0,40));
        """)
        return label

    def slider(self, text, min_value=0, max_value=100, value=50, bold=False, callback=None, x=0, y=0, w=600, h=30,
               font_family="Montserrat"):
        label = QLabel(text, self.parent)
        font = QFont(font_family, 18)
        if bold:
            font.setBold(True)
        label.setFont(font)
        label.setStyleSheet("color: white; background-color: transparent;")
        label.setGeometry(x, y, w, h)

        slider = QSlider(Qt.Horizontal, self.parent)
        slider.setMinimum(min_value)
        slider.setMaximum(max_value)
        slider.setValue(value)
        slider.setGeometry(x, y + 40, w, 20)

        slider.setStyleSheet("""
            QSlider::groove:horizontal {
                height: 10px;
                background: qlineargradient(x1:0, y1:0, x2:1, y2:0,
                                            stop:0 #ff00cc, stop:1 #6600ff);
                border-radius: 5px;
            }
            QSlider::handle:horizontal {
                width: 24px;
                margin: -8px 0;
                background-color: white;
                border-radius: 12px;
                border: 2px solid #ff99ff;
            }
            QSlider::sub-page:horizontal {
                background: qlineargradient(x1:0, y1:0, x2:1, y2:0,
                                            stop:0 #ffccff, stop:1 #cc99ff);
                border-radius: 5px;
            }
        """)

        if callback:
            slider.valueChanged.connect(callback)

        return label, slider

    def checkbox(self, text, checked=False, bold=False, callback=None, x=0, y=0, w=250, h=30, font_family="Montserrat"):
        checkbox = QCheckBox(text, self.parent)
        font = QFont(font_family, 18)
        if bold:
            font.setBold(True)
        checkbox.setFont(font)
        checkbox.setChecked(checked)
        checkbox.setGeometry(x, y, w, h)

        checkbox.setStyleSheet("""
            QCheckBox {
                color: white;
                background-color: transparent;
                spacing: 10px;
                font-size: 48px;
            }
            QCheckBox::indicator {
                width: 24px;
                height: 24px;
                border: 2px solid #ffffff;
                border-radius: 6px;
                background-color: rgba(255, 255, 255, 20);
            }
            QCheckBox::indicator:checked {
                background-color: #ff00cc;
                border: 2px solid white;
            }
            QCheckBox::indicator:!checked {
                background-color: white;
                border: 2px solid white;
            }
            QCheckBox::indicator:hover {
                border: 2px solid #ff99ff;
            }
        """)

        if callback:
            checkbox.stateChanged.connect(lambda state: callback(state))

        return checkbox

    def separator(self, x=0, y=0, w=600, h=20, color="rgba(255, 255, 255, 50)"):
        line = QFrame(self.parent)
        line.setFrameShape(QFrame.HLine)
        line.setFrameShadow(QFrame.Sunken)
        line.setStyleSheet(f"color: {color};")
        line.setGeometry(x, y, w, h)
        return line

    def shop_background(self, texture_path="assets/textures/town.png"):
        bg_label = QLabel(self.parent)
        pixmap = QPixmap(texture_path).scaled(self.parent.size(), Qt.IgnoreAspectRatio, Qt.SmoothTransformation)
        bg_label.setPixmap(pixmap)
        bg_label.setGeometry(0, 0, self.parent.width(), self.parent.height())
        return bg_label

    def shop_currency_label(self, currency=0):
        label = QLabel(f"💰 Валюта: {currency}", self.parent)
        label.setStyleSheet("color: gold; font-size: 32px; font-weight: bold; text-shadow: 1px 1px 3px black;")
        label.setAlignment(Qt.AlignCenter)
        return label

    def shop_category_button(self, text, callback=None, is_all=False):
        btn = QPushButton(text, self.parent)
        btn.setFixedSize(120, 50)
        if is_all:
            btn.setStyleSheet("""
                QPushButton {
                    background-color: gold;
                    color: black;
                    border-radius: 15px;
                    font-size: 18px;
                    font-weight: bold;
                }
                QPushButton:hover {
                    background-color: #ffcc00;
                }
            """)
        else:
            btn.setStyleSheet("""
                QPushButton {
                    background-color: rgba(0, 0, 0, 0.3);
                    color: white;
                    border-radius: 15px;
                    font-size: 18px;
                    font-weight: bold;
                }
                QPushButton:hover {
                    background-color: rgba(0, 0, 0, 0.5);
                }
            """)
        if callback:
            btn.clicked.connect(callback)
        return btn

    def shop_item_widget(self, item, is_purchased=False, is_active=False, buy_callback=None, use_callback=None):
        widget = QFrame(self.parent)
        widget.setFixedSize(280, 350)
        widget.setStyleSheet("""
            QFrame {
                background-color: rgba(30, 30, 30, 180);
                border-radius: 20px;
                border: 2px solid #555;
                box-shadow: 3px 3px 10px rgba(0,0,0,0.7);
                overflow: hidden; /* Обрезаем всё, что выходит за границы */
            }
            QFrame:hover {
                border-color: gold;
                background-color: rgba(40, 40, 40, 230);
            }
        """)

        layout = QVBoxLayout()
        layout.setContentsMargins(15, 15, 15, 15)
        layout.setSpacing(15)
        widget.setLayout(layout)

        widget.setProperty("item_data", item)

        if item["category"] == "Платформы":
            pass
        else:
            image_label = QLabel(widget)
            pixmap = QPixmap(item["image"])
            scaled_pixmap = pixmap.scaled(240, 180, Qt.KeepAspectRatio, Qt.SmoothTransformation)
            image_label.setPixmap(scaled_pixmap)
            image_label.setAlignment(Qt.AlignCenter)
            image_label.setStyleSheet("""
                border-radius: 20px; /* Скругления для изображения */
                overflow: hidden;   /* Обрезаем всё, что выходит за границы */
            """)
            layout.addWidget(image_label)

        name_label = QLabel(item["name"], widget)
        name_label.setStyleSheet("""
            color: white; 
            font-size: 22px; 
            font-weight: bold;
            border-radius: 10px;
            padding: 5px;
        """)
        name_label.setAlignment(Qt.AlignCenter)
        layout.addWidget(name_label)

        if item["item_id"].endswith("_default"):
            default_label = QLabel("✔️ Дефолтный", widget)
            default_label.setStyleSheet("""
                color: lightblue; 
                font-size: 20px; 
                font-weight: bold;
                border-radius: 10px;
                padding: 5px;
            """)
            default_label.setAlignment(Qt.AlignCenter)
            layout.addWidget(default_label)

            if is_active:
                active_label = QLabel("✅ Используется", widget)
                active_label.setStyleSheet("""
                    color: lightblue; 
                    font-size: 20px; 
                    font-weight: bold;
                    border-radius: 10px;
                    padding: 5px;
                """)
                active_label.setAlignment(Qt.AlignCenter)
                layout.addWidget(active_label)
            elif use_callback is not None:
                use_button = self.shop_use_button(callback=lambda _: use_callback(item))
                layout.addWidget(use_button)

        elif is_purchased:
            if is_active:
                active_label = QLabel("✅ Используется", widget)
                active_label.setStyleSheet("""
                    color: lightblue; 
                    font-size: 20px; 
                    font-weight: bold;
                    border-radius: 10px;
                    padding: 5px;
                """)
                active_label.setAlignment(Qt.AlignCenter)
                layout.addWidget(active_label)
            elif use_callback is not None:
                use_button = self.shop_use_button(callback=lambda _: use_callback(item))
                layout.addWidget(use_button)
        else:
            buy_button = self.shop_buy_button(price=item["price"], callback=lambda _: buy_callback(item))
            layout.addWidget(buy_button)

        return widget

    def shop_buy_button(self, price, callback=None):
        button = QPushButton(f"Купить за {price} 💰", self.parent)
        button.setStyleSheet("""
            QPushButton {
                background-color: gold;
                color: black;
                font-weight: bold;
                font-size: 18px;
                border-radius: 12px;
                padding: 10px;
            }
            QPushButton:hover {
                background-color: #ffcc33;
            }
        """)
        if callback:
            button.clicked.connect(callback)
        return button

    def shop_use_button(self, callback=None):
        button = QPushButton("Использовать", self.parent)
        button.setStyleSheet("""
            QPushButton {
                background-color: lightblue;
                color: black;
                font-weight: bold;
                font-size: 18px;
                border-radius: 12px;
                padding: 10px;
            }
            QPushButton:hover {
                background-color: #add8e6;
            }
        """)
        if callback:
            button.clicked.connect(callback)
        return button

    def achievement_card(self, title, description, progress_text, icon_path, unlocked=False):
        widget = QFrame(self.parent)
        widget.setStyleSheet("""
            QFrame {
                background-color: rgba(30, 30, 30, 180);
                border-radius: 15px;
            }
            QFrame:hover {
                background-color: rgba(50, 50, 50, 220);
            }
        """)
        widget.setFixedHeight(100)

        h_layout = QHBoxLayout(widget)
        h_layout.setContentsMargins(15, 10, 15, 10)
        h_layout.setSpacing(10)

        icon = QLabel(widget)
        icon_pixmap = QPixmap(icon_path).scaled(70, 70, Qt.KeepAspectRatio, Qt.SmoothTransformation)
        icon.setPixmap(icon_pixmap)
        icon.setFixedSize(70, 70)
        icon.setAlignment(Qt.AlignCenter)
        h_layout.addWidget(icon, stretch=0)

        v_layout = QVBoxLayout()

        text = f"<b style='font-size:20px; color:gold;'>{title}</b><br>" \
               f"<span style='font-size:16px; color:white;'>{description}</span><br>" \
               f"<span style='font-size:14px; color:lightgreen;'>{progress_text}</span>"
        label = QLabel(text, widget)
        label.setWordWrap(True)
        v_layout.addWidget(label)

        h_layout.addLayout(v_layout, stretch=1)

        status = QLabel("✅ Разблокировано" if unlocked else "🔒 Заблокировано", widget)
        status.setStyleSheet("color: lightblue; font-size: 14px; font-weight: bold;")
        status.setFixedWidth(140)
        status.setAlignment(Qt.AlignCenter)
        h_layout.addWidget(status, stretch=0)

        return widget

    def achievement_title(self, text="Достижения"):
        title_label = QLabel(text, self.parent)
        title_label.setStyleSheet("color: white; font-size: 48px; font-weight: bold;")
        title_label.setAlignment(Qt.AlignCenter)
        return title_label
    
    def callback(self, callback):
        callback()