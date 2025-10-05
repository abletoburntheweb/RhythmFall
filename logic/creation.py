from PyQt5.QtWidgets import QPushButton, QLabel, QCheckBox, QSlider, QFrame, QVBoxLayout, QHBoxLayout, QWidget, \
    QLineEdit, QListWidget, QScrollArea
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
        # Стиль 4: Мягкий серый фон с лёгким hover
        elif preset == 4:
            button.setStyleSheet("""
                QPushButton {
                    background-color: #3a3a3a;  /* тёмно-серый */
                    color: white;
                    border: 1px solid #555;
                    border-radius: 8px;
                    padding: 10px 15px;
                    font-size: 20px;
                }
                QPushButton:hover {
                    background-color: #4a4a4a;
                }
            """)

        # Стиль 5: Однотонный фиолетовый фон, аккуратный и нейтральный для настроек
        elif preset == 5:
            button.setStyleSheet("""
                QPushButton {
                    background-color: #4b0082;  /* тёмно-фиолетовый */
                    color: white;
                    border: 2px solid #ffffff;
                    border-radius: 10px;
                    padding: 10px 20px;
                    font-size: 22px;
                }
                QPushButton:hover {
                    background-color: #5a0099;  /* чуть светлее на hover */
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

    def settings_menu_slider(self, text, min_value=0, max_value=100, value=50, bold=False, callback=None, x=0, y=0, w=600, h=30,
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

    def settings_menu_checkbox(self, text, checked=False, bold=False, callback=None, x=0, y=0, w=250, h=30, font_family="Montserrat"):
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

    def settings_menu_content_widget(self, top=20, left=20, right=20, bottom=20, spacing=20):
        content_widget = QWidget()
        layout = QVBoxLayout(content_widget)
        layout.setAlignment(Qt.AlignTop)
        layout.setSpacing(spacing)
        layout.setContentsMargins(left, top, right, bottom)
        return content_widget, layout

    def settings_menu_scroll_area_widget(self, inner_widget):
        scroll_area = QScrollArea()
        scroll_area.setWidgetResizable(True)
        scroll_area.setHorizontalScrollBarPolicy(Qt.ScrollBarAlwaysOff)
        scroll_area.setVerticalScrollBarPolicy(Qt.ScrollBarAsNeeded)
        scroll_area.setWidget(inner_widget)

        wrapper = QWidget()
        layout = QVBoxLayout(wrapper)
        layout.addWidget(scroll_area)
        return wrapper

    def settings_menu_controls_title_label(self, text="Настройка управления"):
        label = QLabel(text, self.parent)
        label.setAlignment(Qt.AlignCenter)
        label.setStyleSheet("""
            color: #ffcc00;
            font-size: 40px;
            font-weight: bold;
            background: transparent;
            margin-bottom: 10px;
        """)
        return label

    def settings_menu_controls_description_label(self, text="Нажмите на клавишу, чтобы изменить её назначение."):
        label = QLabel(text, self.parent)
        label.setAlignment(Qt.AlignCenter)
        label.setStyleSheet("""
            color: rgba(255, 255, 255, 0.8);
            font-size: 20px;
            background: transparent;
            margin-bottom: 35px;
        """)
        return label

    def settings_menu_controls_header_label(self, text):
        label = QLabel(text, self.parent)
        label.setStyleSheet("""
            color: #ffcc00+;
            font-size: 26px;
            font-weight: bold;
            background: transparent;
        """)
        return label


    def settings_menu_controls_row_widget(self, action_text, key_text, lane_index, callback=None):
        row_widget = QWidget()
        row_widget.setStyleSheet("""
            background-color: rgba(255, 255, 255, 0.05);
            border-radius: 10px;
        """)
        row_layout = QHBoxLayout(row_widget)
        row_layout.setSpacing(20)
        row_layout.setContentsMargins(20, 10, 20, 10)

        line_label = QLabel(action_text)
        line_label.setAlignment(Qt.AlignVCenter | Qt.AlignLeft)
        line_label.setStyleSheet("""
            color: white;
            font-size: 22px;
            font-weight: 600;
            padding: 5px 10px;
            background: transparent;
        """)
        row_layout.addWidget(line_label)

        btn = QPushButton(key_text)
        btn.setFixedSize(160, 55)
        btn.setProperty("lane", lane_index)
        if callback:
            btn.clicked.connect(lambda _, b=btn: callback(b))
        btn.setStyleSheet("""
            QPushButton {
                background-color: rgba(255, 255, 255, 0.1);
                color: white;
                border: 2px solid rgba(255, 255, 255, 0.25);
                border-radius: 10px;
                font-size: 22px;
                font-weight: bold;
            }
            QPushButton:hover {
                background-color: rgba(255, 255, 255, 0.2);
                border-color: white;
            }
            QPushButton:pressed {
                background-color: rgba(255, 255, 255, 0.35);
                color: black;
            }
        """)
        row_layout.addStretch(1)
        row_layout.addWidget(btn, alignment=Qt.AlignCenter)
        row_layout.addStretch(1)

        return row_widget, btn

    def settings_menu_controls_hint_label(self, text="Нажмите ESC, чтобы отменить переназначение клавиши"):
        label = QLabel(text, self.parent)
        label.setAlignment(Qt.AlignCenter)
        label.setStyleSheet("""
            color: white;
            font-size: 16px;
            margin-top: 25px;
            background: transparent;
        """)
        return label

    def separator(self, x=0, y=0, w=600, h=20, color="rgba(255, 255, 255, 50)"):
        line = QFrame(self.parent)
        line.setFrameShape(QFrame.HLine)
        line.setFrameShadow(QFrame.Sunken)
        line.setStyleSheet(f"color: {color};")
        line.setGeometry(x, y, w, h)
        return line

    def background(self, texture_path="default"):
        if texture_path == "default":
            actual_path = "assets/textures/town.png"
        else:
            actual_path = texture_path

        bg_label = QLabel(self.parent)
        pixmap = QPixmap(actual_path).scaled(self.parent.size(), Qt.IgnoreAspectRatio, Qt.SmoothTransformation)
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
                overflow: hidden;
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

    def song_select_search_bar(self):
        search_bar = QLineEdit(self.parent)
        search_bar.setPlaceholderText("Поиск по названию или исполнителю...")
        search_bar.setStyleSheet("""
            QLineEdit {
                background-color: rgba(0,0,0,0.7);
                color: white;
                font-size: 20px;
                border: 1px solid rgba(255,255,255,0.5);
                border-radius: 12px;
                padding: 8px 15px;
            }
            QLineEdit:focus {
                border: 1px solid #00bfff;
                background-color: rgba(0,0,0,0.8);
            }
        """)
        return search_bar

    def song_select_song_count_label(self, count):
        label = QLabel(f"Песен: {count}", self.parent)
        label.setStyleSheet("color: white; font-size: 18px; font-weight: bold;")
        return label

    def song_select_top_bar_button(self, text, callback):
        button = QPushButton(text, self.parent)
        button.setStyleSheet("""
            QPushButton {
                font-size: 18px;
                color: white;
                background-color: rgba(0,0,0,0.7);
                border: 1px solid rgba(255,255,255,0.5);
                border-radius: 12px;
                padding: 8px 15px;
                min-width: 120px;
            }
            QPushButton:hover {
                background-color: rgba(0,0,0,0.8);
                border: 1px solid #00bfff;
            }
        """)
        button.clicked.connect(callback)
        return button

    def song_select_edit_button(self, text, callback, is_active=False):
        button = QPushButton(text, self.parent)

        if is_active:
            button.setStyleSheet("""
                QPushButton {
                    font-size: 18px;
                    color: white;
                    background-color: rgba(60, 60, 60, 0.9); /* Темно-серый цвет */
                    border: 1px solid rgba(255,255,255,0.7);
                    border-radius: 12px;
                    padding: 8px 15px;
                    min-width: 120px;
                }
                QPushButton:hover {
                    background-color: rgba(80, 80, 80, 0.9); /* Светлее при ховере */
                    border: 1px solid #00bfff;
                }
            """)
        else:
            button.setStyleSheet("""
                QPushButton {
                    font-size: 18px;
                    color: white;
                    background-color: rgba(0,0,0,0.7);
                    border: 1px solid rgba(255,255,255,0.5);
                    border-radius: 12px;
                    padding: 8px 15px;
                    min-width: 120px;
                }
                QPushButton:hover {
                    background-color: rgba(0,0,0,0.8);
                    border: 1px solid #00bfff;
                }
            """)

        button.clicked.connect(callback)
        return button

    def song_select_list_widget(self):
        list_widget = QListWidget(self.parent)
        list_widget.setStyleSheet("""
            QListWidget { 
                background-color: rgba(0,0,0,0.65); 
                border-radius: 15px; 
                padding: 10px;
            }
            QListWidget::item { 
                color: white; 
                padding: 18px; 
                font-size: 50px; 
            }
            QListWidget::item:selected { 
                background-color: rgba(255,255,255,0.25); 
                border-radius: 8px;
            }
            QListWidget::item:hover { 
                background-color: rgba(255,255,255,0.15); 
                border-radius: 8px;
            }
            QListWidget::item { border-bottom: 1px solid rgba(255,255,255,0.1); }
        """)
        return list_widget

    def song_select_details_frame(self):
        frame = QFrame(self.parent)
        frame.setStyleSheet("background-color: rgba(0,0,0,0.6); border-radius: 15px;")
        return frame

    def song_select_cover_label(self):
        label = QLabel(self.parent)
        label.setFixedSize(400, 400)
        label.setStyleSheet("background-color: gray; border-radius: 10px;")
        label.setAlignment(Qt.AlignCenter)
        return label

    def song_select_info_label(self, text, font_size=22, bold=True):
        label = QLabel(text, self.parent)
        label.setStyleSheet(f"color: white; font-size: {font_size}px; font-weight: {'bold' if bold else 'normal'};")
        return label

    def song_select_action_button(self, text, callback, fixed_height=60):
        button = QPushButton(text, self.parent)
        button.setFixedHeight(fixed_height)
        button.setStyleSheet("""
            QPushButton {
                font-size: 22px;
                color: white;
                background-color: rgba(0,0,0,0.5);
                border-radius: 10px;
            }
            QPushButton:hover {
                background-color: rgba(255,255,255,0.2);
            }
        """)
        button.clicked.connect(callback)
        return button

    def song_select_separator(self):
        separator = QFrame(self.parent)
        separator.setFrameShape(QFrame.HLine)
        separator.setStyleSheet("background-color: rgba(255,255,255,0.1);")
        return separator

    def victory_button(self, text, callback=None, preset='default'):
        button = QPushButton(text, self.parent)
        if preset == 'replay':
            button.setFixedSize(200, 60)
        elif preset == 'continue':
            button.setFixedSize(250, 60)
        else:
            button.setFixedSize(200, 60)

        button.setFont(QFont("Arial", 16, QFont.Bold))

        styles = {
            'replay': """
                QPushButton {
                    background-color: #4CAF50;
                    color: white;
                    border: 2px solid #45a049;
                    border-radius: 10px;
                }
                QPushButton:hover {
                    background-color: #45a049;
                }
                QPushButton:pressed {
                    background-color: #3d8b40;
                }
            """,
            'continue': """
                QPushButton {
                    background-color: #2196F3;
                    color: white;
                    border: 2px solid #1976D2;
                    border-radius: 10px;
                }
                QPushButton:hover {
                    background-color: #1976D2;
                }
                QPushButton:pressed {
                    background-color: #1565C0;
                }
            """,
            'default': """
                QPushButton {
                    background-color: #555555;
                    color: white;
                    border: 2px solid #777777;
                    border-radius: 10px;
                }
                QPushButton:hover {
                    background-color: #777777;
                }
                QPushButton:pressed {
                    background-color: #333333;
                }
            """
        }

        style_sheet = styles.get(preset, styles['default'])
        button.setStyleSheet(style_sheet)

        if callback:
            button.clicked.connect(callback)
        return button

    def callback(self, callback):
        callback()