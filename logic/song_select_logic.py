# logic/song_select_logic.py    
import os
import json
from pathlib import Path

from PyQt5.QtWidgets import QInputDialog, QFileDialog, QListWidgetItem
from PyQt5.QtGui import QPixmap, QFont, QColor
from PyQt5.QtCore import Qt, QUrl, QTimer
from PyQt5.QtMultimedia import QMediaPlayer, QMediaContent
from collections import defaultdict

from logic.note_generator import generate_notes_for_song, save_notes_to_file

SONGS_DIR = Path("songs")
BPM_CACHE_FILE = SONGS_DIR / "bpms.json"

class SongSelectLogic:
    def __init__(self, song_select_widget, song_manager):
        self.song_select = song_select_widget
        self.song_manager = song_manager

    def populate_song_list(self):
        self.song_select.list_widget.clear()
        songs_by_letter = defaultdict(list)

        if not self.song_manager.songs:
            print("[SongSelectLogic] Предупреждение: список песен пуст при попытке заполнения.")
            empty_item = QListWidgetItem("Нет доступных песен")
            empty_item.setFlags(Qt.NoItemFlags)
            self.song_select.list_widget.addItem(empty_item)
            self.song_select.song_count_label.setText("Песен: 0")
            return

        for song in self.song_manager.songs:
            first_letter = song['title'][0].upper() if song['title'] else 'Unknown'
            songs_by_letter[first_letter].append(song)

        for letter in sorted(songs_by_letter.keys()):
            header_item = QListWidgetItem(f"{len(songs_by_letter[letter])} {letter}")
            header_item.setFont(QFont("Arial", 16, QFont.Bold))
            header_item.setForeground(Qt.white)
            header_item.setBackground(QColor(30, 30, 40))
            header_item.setFlags(Qt.ItemIsEnabled)
            self.song_select.list_widget.addItem(header_item)

            for song in songs_by_letter[letter]:
                item = QListWidgetItem(f"{song['artist']} — {song['title']}")
                item.setData(Qt.UserRole, song)

                font = QFont("Arial", 20)
                font.setWeight(QFont.Normal)
                item.setFont(font)

                self.song_select.list_widget.addItem(item)

        self.song_select.song_count_label.setText(f"Песен: {len(self.song_manager.songs)}")

    def filter_songs(self, text):
        filtered_songs = [
            song for song in self.song_manager.songs
            if text.lower() in song['title'].lower() or text.lower() in song['artist'].lower()
        ]

        self.song_select.list_widget.clear()
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
            self.song_select.list_widget.addItem(header_item)

            for song in songs_by_letter[letter]:
                item = QListWidgetItem(f"{song['artist']} — {song['title']}")
                item.setData(Qt.UserRole, song)

                font = QFont("Arial", 20)
                font.setWeight(QFont.Normal)
                item.setFont(font)

                self.song_select.list_widget.addItem(item)

        self.song_select.song_count_label.setText(f"Песен: {len(filtered_songs)}")

    def play_song_preview(self, filepath):
        if not self.song_select.is_active:
            return

        self.stop_preview()

        try:
            temp_mp3_path = self.song_manager.find_loudest_segment(filepath)
            if not temp_mp3_path:
                print("Не удалось найти громкий фрагмент.")
                return

            new_player = QMediaPlayer()
            new_player.setVolume(0)
            new_player.setMedia(QMediaContent(QUrl.fromLocalFile(temp_mp3_path)))
            new_player.play()

            self.song_select._fade_out_player = getattr(self.song_select, "_preview_player", None)
            self.song_select._fade_in_player = new_player
            self.song_select._fade_target_volume = self.song_select.preview_volume
            self.song_select._fade_timer.start()

            self.song_select._preview_player = new_player

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
        if hasattr(self.song_select, "_preview_player") and self.song_select._preview_player:
            self.song_select._preview_player.stop()
            self.song_select._preview_player.deleteLater()
            self.song_select._preview_player = None

        if hasattr(self.song_select, "_fade_out_player") and self.song_select._fade_out_player:
            self.song_select._fade_out_player.stop()
            self.song_select._fade_out_player.deleteLater()
            self.song_select._fade_out_player = None

        if hasattr(self.song_select, "_fade_in_player") and self.song_select._fade_in_player:
            self.song_select._fade_in_player.stop()
            self.song_select._fade_in_player.deleteLater()
            self.song_select._fade_in_player = None

    def _fade_step(self):
        if self.song_select._fade_out_player:
            vol = self.song_select._fade_out_player.volume()
            vol = max(vol - self.song_select._fade_step_value, 0)
            self.song_select._fade_out_player.setVolume(vol)
            if vol == 0:
                self.song_select._fade_out_player.stop()
                self.song_select._fade_out_player.deleteLater()
                self.song_select._fade_out_player = None

        if self.song_select._fade_in_player:
            vol = self.song_select._fade_in_player.volume()
            vol = min(vol + self.song_select._fade_step_value, self.song_select._fade_target_volume)
            self.song_select._fade_in_player.setVolume(vol)
            if vol >= self.song_select._fade_target_volume:
                self.song_select._fade_in_player.setVolume(self.song_select._fade_target_volume)
                self.song_select._fade_in_player = None

        if not self.song_select._fade_in_player and not self.song_select._fade_out_player:
            self.song_select._fade_timer.stop()

    def toggle_edit_mode(self):
        self.song_select.edit_mode = not self.song_select.edit_mode

        text = "Редактировать"
        is_active = self.song_select.edit_mode
        new_edit_button = self.song_select.create.song_select_edit_button(text,
                                                                          self.song_select.toggle_edit_mode,
                                                                          is_active)

        for i in range(self.song_select.layout().count()):
            top_widget = self.song_select.layout().itemAt(i).widget()
            if hasattr(top_widget, 'layout') and top_widget.layout():
                top_layout = top_widget.layout()
                index = top_layout.indexOf(self.song_select.edit_button)
                if index != -1:
                    top_layout.removeWidget(self.song_select.edit_button)
                    self.song_select.edit_button.deleteLater()
                    top_layout.insertWidget(index, new_edit_button)
                    break

        self.song_select.edit_button = new_edit_button

    def title_double_clicked(self, event):
        if not self.song_select.edit_mode or not self.song_select.selected_song:
            return

        new_title, ok = QInputDialog.getText(self.song_select, "Редактировать название", "Введите новое название:",
                                             text=self.song_select.selected_song.get('title', ''))
        if ok and new_title:
            old_title = self.song_select.selected_song.get('title', '')
            self.song_select.selected_song['title'] = new_title
            self.song_select.title_label.setText(new_title)

            self.song_manager.update_song_metadata(self.song_select.selected_song)

            self.populate_song_list()
            current_row = self.song_select.list_widget.currentRow()
            if current_row != -1:
                self.song_select.list_widget.setCurrentRow(current_row)

            print(f"Название обновлено: {old_title} -> {new_title}")

    def artist_double_clicked(self, event):
        if not self.song_select.edit_mode or not self.song_select.selected_song:
            return

        new_artist, ok = QInputDialog.getText(self.song_select, "Редактировать исполнителя",
                                              "Введите нового исполнителя:",
                                              text=self.song_select.selected_song.get('artist', ''))
        if ok and new_artist:
            old_artist = self.song_select.selected_song.get('artist', '')
            self.song_select.selected_song['artist'] = new_artist
            self.song_select.artist_label.setText(new_artist)

            self.song_manager.update_song_metadata(self.song_select.selected_song)

            self.populate_song_list()
            current_row = self.song_select.list_widget.currentRow()
            if current_row != -1:
                self.song_select.list_widget.setCurrentRow(current_row)

            print(f"Исполнитель обновлен: {old_artist} -> {new_artist}")

    def year_double_clicked(self, event):
        if not self.song_select.edit_mode or not self.song_select.selected_song:
            return

        new_year, ok = QInputDialog.getText(self.song_select, "Редактировать год", "Введите новый год:",
                                            text=str(self.song_select.selected_song.get('year', '')))
        if ok and new_year:
            old_year = self.song_select.selected_song.get('year', '')
            self.song_select.selected_song['year'] = int(new_year) if new_year.isdigit() else new_year
            self.song_select.year_label.setText(f"Year: {new_year}")

            self.song_manager.update_song_metadata(self.song_select.selected_song)

            self.populate_song_list()
            current_row = self.song_select.list_widget.currentRow()
            if current_row != -1:
                self.song_select.list_widget.setCurrentRow(current_row)

            print(f"Год обновлен: {old_year} -> {new_year}")

    def bpm_double_clicked(self, event):
        if not self.song_select.edit_mode or not self.song_select.selected_song:
            return

        current_bpm_str = self.song_select.selected_song.get('bpm', 'Н/Д')
        current_bpm = '0'
        if isinstance(current_bpm_str, (int, float)) or (
                isinstance(current_bpm_str, str) and current_bpm_str.isdigit()):
            current_bpm = str(current_bpm_str)

        new_bpm_str, ok = QInputDialog.getText(
            self.song_select,
            "Редактировать BPM",
            "Введите новый BPM (60-200):",
            text=current_bpm
        )

        if ok and new_bpm_str:
            try:
                new_bpm = int(new_bpm_str)

                if 60 <= new_bpm <= 200:
                    old_bpm = self.song_select.selected_song.get('bpm', 'Н/Д')
                    self.song_select.selected_song['bpm'] = new_bpm

                    self._update_bpm_cache(self.song_select.selected_song["path"], new_bpm)

                    self.song_manager.update_song_metadata(self.song_select.selected_song)

                    print(f"BPM обновлен: {old_bpm} -> {new_bpm}")
                else:
                    print(f"Введенный BPM {new_bpm} вне допустимого диапазона (60-200).")
            except ValueError:
                print(f"Введено некорректное значение BPM: {new_bpm_str}. Ожидалось число.")
                pass

    def _update_bpm_cache(self, song_path, new_bpm):
        filename = Path(song_path).name.lower()

        cache = {}
        if BPM_CACHE_FILE.exists():
            try:
                with open(BPM_CACHE_FILE, 'r', encoding='utf-8') as f:
                    cache = json.load(f)
            except (json.JSONDecodeError, FileNotFoundError) as e:
                print(f"⚠️ Ошибка загрузки кэша BPM {BPM_CACHE_FILE}: {e}")
                cache = {}

        cache[filename] = new_bpm

        try:
            with open(BPM_CACHE_FILE, 'w', encoding='utf-8') as f:
                json.dump(cache, f, ensure_ascii=False, indent=4)
            print(f"BPM кэш обновлен для {filename}: {new_bpm}")
        except Exception as e:
            print(f"Ошибка сохранения кэша BPM в {BPM_CACHE_FILE}: {e}")

    def cover_double_clicked(self, event):
        if not self.song_select.edit_mode or not self.song_select.selected_song:
            return

        filepath, _ = QFileDialog.getOpenFileName(self.song_select, "Выберите изображение", "",
                                                  "Image Files (*.png *.jpg *.jpeg *.bmp)")
        if filepath:
            try:
                with open(filepath, 'rb') as f:
                    cover_data = f.read()

                self.song_select.selected_song['cover'] = cover_data
                pixmap = QPixmap()
                pixmap.loadFromData(cover_data)
                pixmap = pixmap.scaled(400, 400, Qt.KeepAspectRatioByExpanding, Qt.SmoothTransformation)
                self.song_select.cover_label.setPixmap(pixmap)

                self.song_manager.update_song_metadata(self.song_select.selected_song)

                self.populate_song_list()
                current_row = self.song_select.list_widget.currentRow()
                if current_row != -1:
                    self.song_select.list_widget.setCurrentRow(current_row)

                print(f"Обложка обновлена")
            except Exception as e:
                print(f"Ошибка при обновлении обложки: {e}")

    def play_selected_song(self):
        if not self.song_select.selected_song:
            print("❌ Нет выбранной песни.")
            return

        import json
        from pathlib import Path

        song_path = self.song_select.selected_song["path"]
        base_name = Path(song_path).stem
        notes_file_path = Path("songs") / "notes" / f"{base_name}.json"

        if not notes_file_path.exists():
            print(f"❌ Файл нот не найден: {notes_file_path}")
            from PyQt5.QtWidgets import QMessageBox
            msg = QMessageBox()
            msg.setIcon(QMessageBox.Warning)
            msg.setWindowTitle("Ошибка")
            msg.setText(f"Файл нот для песни '{base_name}' не найден.")
            msg.setInformativeText("Сгенерируйте ноты перед игрой.")
            msg.exec_()
            return

        if hasattr(self.song_select.parent, "transitions"):
            self.song_select.parent.transitions.open_game_with_song(self.song_select.selected_song)

    def add_song(self):
        filepath, _ = QFileDialog.getOpenFileName(self.song_select, "Select Song", "", "Audio Files (*.mp3 *.wav)")
        if filepath:
            metadata = self.song_manager.add_song(filepath)
            if metadata:
                self.populate_song_list()
                self.song_select.list_widget.setCurrentRow(len(self.song_manager.songs) - 1)
                self.song_select.song_count_label.setText(f"Песен: {len(self.song_manager.songs)}")

    def generate_notes(self):
        if not self.song_select.selected_song:
            print("Нет выбранной песни для генерации нот.")
            return

        song_path = self.song_select.selected_song["path"]
        song_bpm = self.song_select.selected_song.get("bpm")

        if not song_bpm:
            print(f"Для песни {os.path.basename(song_path)} не указан BPM. Невозможно сгенерировать ноты.")
            return

        try:
            notes_data = generate_notes_for_song(song_path, song_bpm)

            if notes_data:
                success = save_notes_to_file(notes_data, song_path)
                if success:
                    print(f"Ноты успешно сгенерированы и сохранены для {os.path.basename(song_path)}")
                else:
                    print(f"Не удалось сохранить ноты для {os.path.basename(song_path)}")
            else:
                print(f"Не удалось сгенерировать ноты для {os.path.basename(song_path)}")

        except Exception as e:
            print(f"Ошибка при генерации нот для {os.path.basename(song_path)}: {e}")

    def delete_song(self):
        if not self.song_select.selected_song:
            print("Нет выбранной песни для удаления.")
            return

        try:
            song_path = self.song_select.selected_song["path"]
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
            self.song_select.list_widget.setCurrentRow(-1)
            self.song_select.clear_song_info()

            print("Песня успешно удалена.")

        except Exception as e:
            print(f"Ошибка при удалении песни: {e}")