from PyQt5.QtWidgets import QWidget, QListWidget, QVBoxLayout, QHBoxLayout, QFrame, QPushButton, QLabel, QFileDialog, \
    QListWidgetItem, QLineEdit
from PyQt5.QtGui import QPixmap, QFont, QColor
from PyQt5.QtCore import Qt, QUrl, QTimer
from PyQt5.QtMultimedia import QMediaPlayer, QMediaContent
import os
from collections import defaultdict

from logic.creation import Create
from logic.song_manager import SongManager
from logic.song_select_logic import SongSelectLogic


class SongSelect(QWidget):
    def __init__(self, parent=None, song_manager=None):
        super().__init__(parent)
        self.parent = parent
        self.create = Create(self)
        self.song_manager = song_manager if song_manager is not None else SongManager()
        self.song_logic = SongSelectLogic(self, self.song_manager)
        self.selected_song = None
        self.is_active = False
        self.edit_mode = False

        if hasattr(parent, "settings"):
            self.preview_volume = parent.settings.get("preview_volume", 70)
        else:
            self.preview_volume = 70

        self._fade_timer = QTimer()
        self._fade_timer.setInterval(200)
        self._fade_timer.timeout.connect(self._fade_step)
        self._fade_step_value = 2
        self._fade_target_volume = self.preview_volume
        self._fade_in_player = None
        self._fade_out_player = None

        self.edit_button = None
        self.init_ui()

    def init_ui(self):
        self.setFixedSize(1920, 1080)

        self.bg_label = self.create.background(texture_path="assets/textures/town.png")

        main_layout = QVBoxLayout()
        main_layout.setContentsMargins(50, 50, 50, 50)
        main_layout.setSpacing(20)
        self.setLayout(main_layout)

        top_bar = QFrame()
        top_bar.setFixedHeight(70)
        top_bar.setStyleSheet("background-color: rgba(0,0,0,0.5); border-radius: 10px;")
        top_layout = QHBoxLayout()
        top_layout.setContentsMargins(15, 5, 15, 5)
        top_layout.setSpacing(15)

        self.search_bar = self.create.song_select_search_bar()
        self.search_bar.textChanged.connect(self.filter_songs)
        top_layout.addWidget(self.search_bar)

        self.add_button = self.create.song_select_top_bar_button("Добавить", self.add_song)
        top_layout.addWidget(self.add_button)

        self.edit_button = self.create.song_select_edit_button("Редактировать", self.toggle_edit_mode)
        top_layout.addWidget(self.edit_button)

        self.song_count_label = self.create.song_select_song_count_label(len(self.song_manager.songs))
        top_layout.addStretch()
        top_layout.addWidget(self.song_count_label)

        top_bar.setLayout(top_layout)
        main_layout.addWidget(top_bar)

        content_layout = QHBoxLayout()
        content_layout.setSpacing(50)

        self.list_widget = self.create.song_select_list_widget()
        self.populate_song_list()
        self.list_widget.currentRowChanged.connect(self.update_song_info)
        content_layout.addWidget(self.list_widget)

        self.details_frame = self.create.song_select_details_frame()
        self.details_frame.setFixedWidth(900)
        details_layout = QVBoxLayout()
        details_layout.setAlignment(Qt.AlignTop)
        details_layout.setContentsMargins(20, 20, 20, 20)
        details_layout.setSpacing(15)

        self.cover_label = self.create.song_select_cover_label()
        self.cover_label.mouseDoubleClickEvent = self.cover_double_clicked
        self.cover_label.setMouseTracking(True)
        details_layout.addWidget(self.cover_label)

        self.title_label = self.create.song_select_info_label("Название", font_size=28)
        self.title_label.mouseDoubleClickEvent = self.title_double_clicked
        self.title_label.setMouseTracking(True)
        details_layout.addWidget(self.title_label)

        self.artist_label = self.create.song_select_info_label("Исполнитель", font_size=22)
        self.artist_label.mouseDoubleClickEvent = self.artist_double_clicked
        self.artist_label.setMouseTracking(True)
        details_layout.addWidget(self.artist_label)

        self.year_label = self.create.song_select_info_label("Год", font_size=18)
        self.year_label.mouseDoubleClickEvent = self.year_double_clicked
        self.year_label.setMouseTracking(True)
        details_layout.addWidget(self.year_label)

        self.bpm_label = self.create.song_select_info_label("BPM", font_size=18)
        self.bpm_label.mouseDoubleClickEvent = self.bpm_double_clicked
        self.bpm_label.setMouseTracking(True)
        details_layout.addWidget(self.bpm_label)

        self.duration_label = self.create.song_select_info_label("Длительность: 00:00", font_size=18)
        details_layout.addWidget(self.duration_label)

        separator = self.create.song_select_separator()
        details_layout.addWidget(separator)

        self.play_button = self.create.song_select_action_button("Играть", self.play_selected_song)
        details_layout.addWidget(self.play_button)

        self.generate_notes_button = self.create.song_select_action_button("Сгенерировать ноты", self.generate_notes)
        details_layout.addWidget(self.generate_notes_button)

        self.delete_button = self.create.song_select_action_button("Удалить песню", self.delete_song)
        details_layout.addWidget(self.delete_button)

        self.details_frame.setLayout(details_layout)
        content_layout.addWidget(self.details_frame)

        main_layout.addLayout(content_layout)

        if self.song_manager.songs:
            self.list_widget.setCurrentRow(0)

    def update_songs_list(self):
        self.populate_song_list()
        if self.song_manager.songs:
            self.list_widget.setCurrentRow(0)

    def populate_song_list(self):
        self.song_logic.populate_song_list()

    def update_song_info(self, index):
        if index < 0 or index >= self.list_widget.count():
            return

        item = self.list_widget.item(index)
        song_data = item.data(Qt.UserRole)

        if not song_data:
            return

        self.selected_song = song_data

        if song_data['cover']:
            pixmap = QPixmap()
            pixmap.loadFromData(song_data['cover'])
            pixmap = pixmap.scaled(400, 400, Qt.KeepAspectRatioByExpanding, Qt.SmoothTransformation)
            self.cover_label.setPixmap(pixmap)
        else:
            self.cover_label.setPixmap(QPixmap())

        self.title_label.setText(song_data.get("title", "Н/Д"))
        self.artist_label.setText(song_data.get("artist", "Н/Д"))
        self.year_label.setText(f"Year: {song_data.get('year', 'Н/Д')}")
        self.bpm_label.setText(f"BPM: {song_data.get('bpm', 'Н/Д')}")
        self.duration_label.setText(f"Длительность: {song_data.get('duration', '00:00')}")

        self.play_song_preview(song_data["path"])

    def filter_songs(self, text):
        self.song_logic.filter_songs(text)

    def toggle_edit_mode(self):
        self.song_logic.toggle_edit_mode()

    def title_double_clicked(self, event):
        self.song_logic.title_double_clicked(event)

    def artist_double_clicked(self, event):
        self.song_logic.artist_double_clicked(event)

    def year_double_clicked(self, event):
        self.song_logic.year_double_clicked(event)

    def bpm_double_clicked(self, event):
        self.song_logic.bpm_double_clicked(event)

    def cover_double_clicked(self, event):
        self.song_logic.cover_double_clicked(event)

    def showEvent(self, event):
        super().showEvent(event)
        self.is_active = True
        if self.selected_song:
            self.play_song_preview(self.selected_song["path"])

    def hideEvent(self, event):
        super().hideEvent(event)
        self.is_active = False
        self.stop_preview()

    def play_song_preview(self, filepath):
        self.song_logic.play_song_preview(filepath)

    def stop_preview(self):
        self.song_logic.stop_preview()


    def _fade_step(self):
        self.song_logic._fade_step()

    def set_preview_volume(self, volume):
        self.preview_volume = volume
        if hasattr(self, "_preview_player") and self._preview_player:
            self._preview_player.setVolume(volume)

    def play_selected_song(self):
        self.song_logic.play_selected_song()

    def add_song(self):
        self.song_logic.add_song()
    def generate_notes(self):
        self.song_logic.generate_notes()

    def delete_song(self):
        self.song_logic.delete_song()

    def start_preview_music(self):
        if self.selected_song:
            self.play_song_preview(self.selected_song["path"])

    def clear_song_info(self):
        self.cover_label.setPixmap(QPixmap())
        self.title_label.setText("Название")
        self.artist_label.setText("Исполнитель")
        self.year_label.setText("Год")
        self.bpm_label.setText("BPM")
        self.duration_label.setText("Длительность: 00:00")
        self.selected_song = None
        self.stop_preview()

    def keyPressEvent(self, event):
        if event.key() == Qt.Key_Escape:
            self.parent.transitions.close_song_select()
        else:
            super().keyPressEvent(event)