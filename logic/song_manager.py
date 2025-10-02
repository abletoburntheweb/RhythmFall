import os
import shutil
import random
from mutagen.mp3 import MP3
from mutagen.id3 import ID3, APIC, TDRC, TPE1, TIT2
from pydub import AudioSegment
from .tempo_finder import get_bpm

SONG_FOLDER = "songs"
PREVIEW_FOLDER = os.path.join("temp", "previews")


class SongManager:
    def __init__(self):
        os.makedirs(SONG_FOLDER, exist_ok=True)
        os.makedirs(PREVIEW_FOLDER, exist_ok=True)

        self.songs = []
        self.cached_previews = {}
        self.load_songs()

    def load_songs(self):
        self.songs.clear()
        for file in os.listdir(SONG_FOLDER):
            if file.lower().endswith(".mp3"):
                path = os.path.join(SONG_FOLDER, file)
                metadata = self.read_mp3_metadata(path)
                metadata['bpm'] = get_bpm(path) or "Н/Д"
                self.songs.append(metadata)

    def read_mp3_metadata(self, filepath):
        metadata = {
            "path": filepath,
            "title": os.path.splitext(os.path.basename(filepath))[0],
            "artist": "Неизвестен",
            "cover": None,
            "bpm": "Н/Д",
            "year": "Н/Д",
            "duration": "00:00"
        }
        try:
            audio = MP3(filepath, ID3=ID3)
            if audio.info and audio.info.length:
                total_seconds = int(audio.info.length)
                minutes = total_seconds // 60
                seconds = total_seconds % 60
                metadata['duration'] = f"{minutes:02d}:{seconds:02d}"

            if audio.tags:
                if 'TIT2' in audio.tags:
                    metadata['title'] = audio.tags['TIT2'].text[0]
                if 'TPE1' in audio.tags:
                    metadata['artist'] = audio.tags['TPE1'].text[0]
                if 'TDRC' in audio.tags:
                    metadata['year'] = str(audio.tags['TDRC'])
                for tag in audio.tags.keys():
                    if tag.startswith("APIC"):
                        metadata['cover'] = audio.tags[tag].data
                        break
        except Exception as e:
            print(f"Ошибка чтения mp3: {e}")

        if metadata['cover'] is None:
            try:
                covers_dir = os.path.join("songs", "covers")
                available_covers = [
                    os.path.join(covers_dir, f)
                    for f in os.listdir(covers_dir)
                    if f.lower().endswith((".png", ".jpg", ".jpeg"))
                ]
                if available_covers:
                    random_cover_path = random.choice(available_covers)
                    with open(random_cover_path, "rb") as f:
                        metadata['cover'] = f.read()
            except Exception as e:
                print(f"Не удалось загрузить дефолтную обложку: {e}")

        return metadata

    def find_loudest_segment(self, filepath, duration_ms=15000):
        filename = os.path.splitext(os.path.basename(filepath))[0] + "_preview.mp3"
        preview_path = os.path.join(PREVIEW_FOLDER, filename)

        if os.path.exists(preview_path):
            self.cached_previews[filepath] = preview_path
            return preview_path

        try:
            audio = AudioSegment.from_file(filepath)
            if len(audio) <= duration_ms:
                loudest_chunk = audio
            else:
                chunks = [audio[i:i + duration_ms] for i in range(0, len(audio) - duration_ms, 1000)]
                loudest_chunk = max(chunks, key=lambda c: c.rms)

            loudest_chunk.export(preview_path, format="mp3")
            self.cached_previews[filepath] = preview_path
            return preview_path
        except Exception as e:
            print(f"Ошибка при поиске громкого фрагмента: {e}")
            return None

    def add_song(self, file_path):
        if not os.path.exists(file_path) or not file_path.lower().endswith(".mp3"):
            return None
        dest_path = os.path.join(SONG_FOLDER, os.path.basename(file_path))
        if not os.path.exists(dest_path):
            shutil.copy(file_path, dest_path)
        metadata = self.read_mp3_metadata(dest_path)
        metadata['bpm'] = get_bpm(dest_path) or "Н/Д"
        self.songs.append(metadata)
        return metadata

    def update_song_metadata(self, song_data):
        """Обновление метаданных в MP3 файле"""
        try:
            filepath = song_data['path']
            audio = MP3(filepath, ID3=ID3)

            try:
                audio.add_tags()
            except:
                pass

            if 'title' in song_data:
                audio.tags.add(TIT2(encoding=3, text=song_data['title']))

            if 'artist' in song_data:
                audio.tags.add(TPE1(encoding=3, text=song_data['artist']))

            if 'year' in song_data:
                audio.tags.add(TDRC(encoding=3, text=str(song_data['year'])))

            if 'cover' in song_data and song_data['cover']:
                audio.tags.add(APIC(encoding=3, mime='image/jpeg', type=3, desc='Cover', data=song_data['cover']))

            audio.save()

            print(f"Метаданные обновлены для: {filepath}")

            for song in self.songs:
                if song['path'] == filepath:
                    song.update(song_data)
                    break

        except Exception as e:
            print(f"Ошибка при обновлении метаданных: {e}")