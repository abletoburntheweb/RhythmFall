from PyQt5.QtWidgets import QWidget, QLabel, QPushButton, QListWidget, QListWidgetItem, QVBoxLayout, QHBoxLayout, QFrame, QFileDialog
from PyQt5.QtGui import QPixmap, QFont
from PyQt5.QtCore import Qt
import os
from logic.song_manager import SongManager


class LevelSelect(QWidget):
    def __init__(self, parent=None):
        super().__init__(parent)
        self.parent = parent
        self.song_manager = SongManager()
        self.selected_song = None

        self.init_ui()

    def init_ui(self):
        self.setFixedSize(1920, 1080)

        self.bg_label = QLabel(self)
        self.bg_label.setPixmap(QPixmap("assets/textures/town.png").scaled(self.size(), Qt.IgnoreAspectRatio, Qt.SmoothTransformation))
        self.bg_label.setGeometry(0, 0, self.width(), self.height())
        self.bg_label.lower()

        overlay = QFrame(self)
        overlay.setStyleSheet("background-color: rgba(0,0,0,0.3);")
        overlay.setGeometry(0, 0, self.width(), self.height())
        overlay.lower()

        main_layout = QHBoxLayout()
        main_layout.setContentsMargins(50, 50, 50, 50)
        main_layout.setSpacing(50)

        self.list_widget = QListWidget()
        self.list_widget.setFixedWidth(700)
        self.list_widget.setStyleSheet("""
            QListWidget { background-color: rgba(0,0,0,0.6); border-radius: 15px; }
            QListWidget::item { color: white; padding: 15px; font-size: 20px; }
            QListWidget::item:selected { background-color: rgba(255,255,255,0.2); }
            QListWidget::item:hover { background-color: rgba(255,255,255,0.1); }
        """)
        self.populate_song_list()
        self.list_widget.currentRowChanged.connect(self.update_song_info)
        main_layout.addWidget(self.list_widget)

        self.details_frame = QFrame()
        self.details_frame.setStyleSheet("background-color: rgba(0,0,0,0.6); border-radius: 15px;")
        self.details_frame.setFixedWidth(900)
        details_layout = QVBoxLayout()
        details_layout.setAlignment(Qt.AlignTop)
        details_layout.setContentsMargins(20, 20, 20, 20)
        details_layout.setSpacing(15)

        self.cover_label = QLabel()
        self.cover_label.setFixedSize(400, 400)
        self.cover_label.setStyleSheet("background-color: gray; border-radius: 10px;")
        self.cover_label.setAlignment(Qt.AlignCenter)
        details_layout.addWidget(self.cover_label)

        self.title_label = QLabel("Название")
        self.title_label.setStyleSheet("color: white; font-size: 28px; font-weight: bold;")
        details_layout.addWidget(self.title_label)

        self.artist_label = QLabel("Исполнитель")
        self.artist_label.setStyleSheet("color: white; font-size: 22px;")
        details_layout.addWidget(self.artist_label)

        self.year_label = QLabel("Год")
        self.year_label.setStyleSheet("color: white; font-size: 18px;")
        details_layout.addWidget(self.year_label)

        self.bpm_label = QLabel("BPM")
        self.bpm_label.setStyleSheet("color: white; font-size: 18px;")
        details_layout.addWidget(self.bpm_label)

        self.play_button = QPushButton("Играть")
        self.play_button.setFixedHeight(60)
        self.play_button.setStyleSheet("font-size: 20px;")
        self.play_button.clicked.connect(self.play_selected_song)
        details_layout.addWidget(self.play_button)

        self.add_button = QPushButton("Добавить песню")
        self.add_button.setFixedHeight(60)
        self.add_button.setStyleSheet("font-size: 20px;")
        self.add_button.clicked.connect(self.add_song)
        details_layout.addWidget(self.add_button)

        self.details_frame.setLayout(details_layout)
        main_layout.addWidget(self.details_frame)
        self.setLayout(main_layout)

        if self.song_manager.songs:
            self.list_widget.setCurrentRow(0)
            self.update_song_info(0)

    def populate_song_list(self):
        self.list_widget.clear()
        for song in self.song_manager.songs:
            item = QListWidgetItem(f"{song['artist']} — {song['title']}")
            self.list_widget.addItem(item)

    def update_song_info(self, index):
        if index < 0 or index >= len(self.song_manager.songs):
            return
        song = self.song_manager.songs[index]
        self.selected_song = song

        if song['cover'] and os.path.exists(song['cover']):
            pixmap = QPixmap(song['cover']).scaled(400, 400, Qt.KeepAspectRatio, Qt.SmoothTransformation)
            self.cover_label.setPixmap(pixmap)
        else:
            self.cover_label.setPixmap(QPixmap())

        self.title_label.setText(song.get("title", "Н/Д"))
        self.artist_label.setText(song.get("artist", "Н/Д"))
        self.year_label.setText(f"Year: {song.get('year', 'Н/Д')}")
        self.bpm_label.setText(f"BPM: {song.get('bpm', 'Н/Д')}")

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