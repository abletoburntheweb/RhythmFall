from PyQt5.QtWidgets import QWidget, QListWidget, QVBoxLayout, QHBoxLayout, QFrame, QPushButton, QLabel, QFileDialog, \
    QListWidgetItem, QLineEdit
from PyQt5.QtGui import QPixmap, QFont, QColor
from PyQt5.QtCore import Qt, QUrl, QTimer
from PyQt5.QtMultimedia import QMediaPlayer, QMediaContent
import os
from collections import defaultdict

from logic.creation import Create
from logic.song_manager import SongManager


class SongSelect(QWidget):
    def __init__(self, parent=None):
        super().__init__(parent)
        self.parent = parent
        self.create = Create(self)
        self.song_manager = SongManager()
        self.selected_song = None
        self.is_active = False

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

        self.init_ui()

    def init_ui(self):
        self.setFixedSize(1920, 1080)

        self.bg_label = self.create.shop_background(texture_path="assets/textures/town.png")

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
        details_layout.addWidget(self.cover_label)

        self.title_label = self.create.song_select_info_label("Название", font_size=28)
        details_layout.addWidget(self.title_label)

        self.artist_label = self.create.song_select_info_label("Исполнитель", font_size=22)
        details_layout.addWidget(self.artist_label)

        self.year_label = self.create.song_select_info_label("Год", font_size=18)
        details_layout.addWidget(self.year_label)

        self.bpm_label = self.create.song_select_info_label("BPM", font_size=18)
        details_layout.addWidget(self.bpm_label)

        self.duration_label = self.create.song_select_info_label("Длительность: 00:00", font_size=18)
        details_layout.addWidget(self.duration_label)

        separator = self.create.song_select_separator()
        details_layout.addWidget(separator)

        self.play_button = self.create.song_select_button("Играть", self.play_selected_song)
        details_layout.addWidget(self.play_button)

        self.add_button = self.create.song_select_button("Добавить песню", self.add_song)
        details_layout.addWidget(self.add_button)

        self.delete_button = self.create.song_select_button("Удалить песню", self.delete_song)
        details_layout.addWidget(self.delete_button)

        self.details_frame.setLayout(details_layout)
        content_layout.addWidget(self.details_frame)

        main_layout.addLayout(content_layout)

        if self.song_manager.songs:
            self.list_widget.setCurrentRow(0)

    def populate_song_list(self):
        self.list_widget.clear()
        self.song_manager.load_songs()
        songs_by_letter = defaultdict(list)

        for song in self.song_manager.songs:
            first_letter = song['title'][0].upper() if song['title'] else 'Unknown'
            songs_by_letter[first_letter].append(song)

        for letter in sorted(songs_by_letter.keys()):
            header_item = QListWidgetItem(f"{len(songs_by_letter[letter])} {letter}")
            header_item.setFont(QFont("Arial", 16, QFont.Bold))
            header_item.setForeground(Qt.white)
            header_item.setBackground(QColor(30, 30, 40))
            header_item.setFlags(Qt.ItemIsEnabled)
            self.list_widget.addItem(header_item)

            for song in songs_by_letter[letter]:
                item = QListWidgetItem(f"{song['artist']} — {song['title']}")
                item.setData(Qt.UserRole, song)

                font = QFont("Arial", 20)
                font.setWeight(QFont.Normal)
                item.setFont(font)

                self.list_widget.addItem(item)

        self.song_count_label.setText(f"Песен: {len(self.song_manager.songs)}")

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
            pixmap = pixmap.scaled(400, 400, Qt.KeepAspectRatio, Qt.SmoothTransformation)
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
        filtered_songs = [
            song for song in self.song_manager.songs
            if text.lower() in song['title'].lower() or text.lower() in song['artist'].lower()
        ]

        self.list_widget.clear()
        songs_by_letter = defaultdict(list)

        for song in filtered_songs:
            first_letter = song['title'][0].upper() if song['title'] else 'Unknown'
            songs_by_letter[first_letter].append(song)

        for letter in sorted(songs_by_letter.keys()):
            header_item = QListWidgetItem(f"{len(songs_by_letter[letter])} SONGS {letter}")
            header_item.setFont(QFont("Arial", 16, QFont.Bold))
            header_item.setForeground(Qt.white)
            header_item.setBackground(QColor(30, 30, 40))
            header_item.setFlags(Qt.ItemIsEnabled)
            self.list_widget.addItem(header_item)

            for song in songs_by_letter[letter]:
                item = QListWidgetItem(f"{song['artist']} — {song['title']}")
                item.setData(Qt.UserRole, song)

                font = QFont("Arial", 20)
                font.setWeight(QFont.Normal)
                item.setFont(font)

                self.list_widget.addItem(item)

        self.song_count_label.setText(f"Песен: {len(filtered_songs)}")

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
        if not self.is_active:
            return
        try:
            temp_mp3_path = self.song_manager.find_loudest_segment(filepath)
            if not temp_mp3_path:
                print("Не удалось найти громкий фрагмент.")
                return

            new_player = QMediaPlayer()
            new_player.setVolume(0)
            new_player.setMedia(QMediaContent(QUrl.fromLocalFile(temp_mp3_path)))
            new_player.play()

            self._fade_out_player = getattr(self, "_preview_player", None)
            self._fade_in_player = new_player
            self._fade_target_volume = self.preview_volume
            self._fade_timer.start()

            self._preview_player = new_player

            def on_media_status_changed(status):
                if status == QMediaPlayer.EndOfMedia:
                    new_player.setPosition(0)
                    new_player.play()

            new_player.mediaStatusChanged.connect(on_media_status_changed)

        except Exception as e:
            print(f"Ошибка воспроизведения фрагмента: {e}")

            def on_media_status_changed(status):
                if status == QMediaPlayer.EndOfMedia:
                    new_player.setPosition(0)
                    new_player.play()

            new_player.mediaStatusChanged.connect(on_media_status_changed)

        except Exception as e:
            print(f"Ошибка воспроизведения фрагмента: {e}")

    def stop_preview(self):
        if hasattr(self, "_preview_player") and self._preview_player:
            self._fade_out_player = self._preview_player
            self._fade_target_volume = 0
            self._fade_timer.start()

            def cleanup():
                if self._fade_out_player:
                    self._fade_out_player.stop()
                    self._fade_out_player.deleteLater()
                    self._fade_out_player = None

            QTimer.singleShot(int(self.preview_volume / self._fade_step_value * self._fade_timer.interval()), cleanup)

    def clear_song_info(self):
        self.cover_label.setPixmap(QPixmap())
        self.title_label.setText("Название")
        self.artist_label.setText("Исполнитель")
        self.year_label.setText("Год")
        self.bpm_label.setText("BPM")
        self.duration_label.setText("Длительность: 00:00")
        self.selected_song = None

    def _fade_step(self):
        if self._fade_out_player:
            vol = self._fade_out_player.volume()
            vol = max(vol - self._fade_step_value, 0)
            self._fade_out_player.setVolume(vol)
            if vol == 0:
                self._fade_out_player.stop()
                self._fade_out_player.deleteLater()
                self._fade_out_player = None

        if self._fade_in_player:
            vol = self._fade_in_player.volume()
            vol = min(vol + self._fade_step_value, self._fade_target_volume)
            self._fade_in_player.setVolume(vol)
            if vol >= self._fade_target_volume:
                self._fade_in_player.setVolume(self._fade_target_volume)
                self._fade_in_player = None

        if not self._fade_in_player and not self._fade_out_player:
            self._fade_timer.stop()

    def set_preview_volume(self, volume):
        self.preview_volume = volume
        if hasattr(self, "_preview_player") and self._preview_player:
            self._preview_player.setVolume(volume)

    def play_selected_song(self):
        if self.selected_song and hasattr(self.parent, "transitions"):
            self.parent.transitions.open_game_with_song(self.selected_song)

    def add_song(self):
        filepath, _ = QFileDialog.getOpenFileName(self, "Select MP3", "", "MP3 Files (*.mp3)")
        if filepath:
            metadata = self.song_manager.add_song(filepath)
            if metadata:
                self.populate_song_list()
                self.list_widget.setCurrentRow(len(self.song_manager.songs) - 1)

    def delete_song(self):
        if not self.selected_song:
            print("Нет выбранной песни для удаления.")
            return

        try:
            song_path = self.selected_song["path"]
            if os.path.exists(song_path):
                os.remove(song_path)
                print(f"Оригинальный файл удален: {song_path}")
            else:
                print(f"Файл не найден: {song_path}")

            preview_path = self.song_manager.cached_previews.get(song_path)
            if preview_path and os.path.exists(preview_path):
                os.remove(preview_path)
                print(f"Превью-версия удалена: {preview_path}")
            else:
                print(f"Превью-версия не найдена: {preview_path}")

            self.song_manager.songs = [song for song in self.song_manager.songs if song["path"] != song_path]

            self.populate_song_list()
            self.list_widget.setCurrentRow(-1)
            self.clear_song_info()

            print("Песня успешно удалена.")

        except Exception as e:
            print(f"Ошибка при удалении песни: {e}")

    def start_preview_music(self):
        if self.selected_song:
            self.play_song_preview(self.selected_song["path"])

    def keyPressEvent(self, event):
        if event.key() == Qt.Key_Escape:
            self.parent.transitions.close_song_select()
        else:
            super().keyPressEvent(event)