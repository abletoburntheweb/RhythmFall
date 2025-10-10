import os
import shutil
import random
import json
from mutagen.mp3 import MP3
from mutagen.id3 import ID3, APIC, TDRC, TPE1, TIT2
from pydub import AudioSegment
from .tempo_finder import get_bpm

SONG_FOLDER = "songs"
PREVIEW_FOLDER = os.path.join("temp", "previews")
CACHE_FILE = os.path.join("data", "songs_cache.json")


class SongManager:
    def __init__(self, load_on_init=True, player_data_manager=None):
        self.player_data_manager = player_data_manager
        os.makedirs(SONG_FOLDER, exist_ok=True)
        os.makedirs(PREVIEW_FOLDER, exist_ok=True)
        os.makedirs(os.path.dirname(CACHE_FILE), exist_ok=True)

        self.songs = []
        self.cached_previews = {}
        if load_on_init:
            self.load_songs()

    def load_songs(self):
        cache = self._load_cache()
        self.songs.clear()

        for file in os.listdir(SONG_FOLDER):
            if file.lower().endswith((".mp3", ".wav")):
                path = os.path.join(SONG_FOLDER, file)

                cached_song = cache.get(path)
                file_modified_time = os.path.getmtime(path)

                if cached_song and cached_song.get("file_mtime") == file_modified_time:
                    metadata = cached_song
                else:
                    if file.lower().endswith(".mp3"):
                        metadata = self.read_mp3_metadata(path)
                    else:
                        metadata = self.read_wav_metadata(path)

                    metadata['bpm'] = get_bpm(path) or "Н/Д"

                    metadata["file_mtime"] = file_modified_time

                self.songs.append(metadata)

        self._save_cache(cache)

    def _load_cache(self):
        try:
            with open(CACHE_FILE, 'r', encoding='utf-8') as f:
                return json.load(f)
        except (json.JSONDecodeError, FileNotFoundError):
            return {}

    def _save_cache(self, existing_cache):
        updated_cache = {}
        for song in self.songs:
            path = song["path"]
            song_data = song.copy()
            song_data.pop("file_mtime", None)
            song_data.pop("cover", None)
            updated_cache[path] = song_data

        try:
            with open(CACHE_FILE, 'w', encoding='utf-8') as f:
                json.dump(updated_cache, f, ensure_ascii=False, indent=4)
        except Exception as e:
            print(f"[SongManager] Ошибка сохранения кэша: {e}")

    def read_mp3_metadata(self, filepath):
        metadata = {
            "path": filepath,
            "title": os.path.splitext(os.path.basename(filepath))[0],
            "artist": "Неизвестен",
            "cover": None,
            "bpm": "Н/Д",
            "year": "Н/Д",
            "duration": "00:00",
            "file_mtime": os.path.getmtime(filepath)
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
            self._set_cover_from_active_pack(metadata)

        return metadata

    def read_wav_metadata(self, filepath):
        metadata = {
            "path": filepath,
            "title": os.path.splitext(os.path.basename(filepath))[0],
            "artist": "Неизвестен",
            "cover": None,
            "bpm": "Н/Д",
            "year": "Н/Д",
            "duration": "00:00",
            "file_mtime": os.path.getmtime(filepath)
        }
        try:
            audio = AudioSegment.from_file(filepath)
            total_seconds = len(audio) / 1000.0
            minutes = int(total_seconds // 60)
            seconds = int(total_seconds % 60)
            metadata['duration'] = f"{minutes:02d}:{seconds:02d}"

            filename_stem = os.path.splitext(os.path.basename(filepath))[0]
            if " - " in filename_stem:
                parts = filename_stem.split(" - ", 1)
                metadata['artist'] = parts[0].strip()
                metadata['title'] = parts[1].strip()
            else:
                metadata['title'] = filename_stem

        except Exception as e:
            print(f"Ошибка чтения wav: {e}")
            metadata['title'] = os.path.splitext(os.path.basename(filepath))[0]

        if metadata['cover'] is None:
            self._set_cover_from_active_pack(metadata)

        return metadata

    def _set_cover_from_active_pack(self, metadata):
        active_covers_pack = None
        if self.player_data_manager:
            active_covers_pack = self.player_data_manager.get_active_item("Covers")

        covers_dir = None
        if active_covers_pack and active_covers_pack != "covers_default":

            pack_name = active_covers_pack.replace("covers_", "")
            covers_dir = os.path.join("assets", "shop", "covers", pack_name)
        else:

            covers_dir = os.path.join("assets", "shop", "covers", "default_covers")

        try:
            available_covers = [
                os.path.join(covers_dir, f)
                for f in os.listdir(covers_dir)
                if f.lower().endswith((".png", ".jpg", ".jpeg"))
            ]
            if available_covers:
                random_cover_path = random.choice(available_covers)
                with open(random_cover_path, "rb") as f:
                    metadata['cover'] = f.read()
            else:
                raise FileNotFoundError(f"Папка {covers_dir} пуста или не существует")
        except Exception as e:

            try:
                covers_dir = os.path.join("assets", "shop", "covers", "default_covers")
                available_covers = [
                    os.path.join(covers_dir, f)
                    for f in os.listdir(covers_dir)
                    if f.lower().endswith((".png", ".jpg", ".jpeg"))
                ]
                if available_covers:
                    random_cover_path = random.choice(available_covers)
                    with open(random_cover_path, "rb") as f:
                        metadata['cover'] = f.read()
            except Exception as e2:
                pass

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
        if not os.path.exists(file_path) or not file_path.lower().endswith((".mp3", ".wav")):
            return None

        dest_path = os.path.join(SONG_FOLDER, os.path.basename(file_path))
        if not os.path.exists(dest_path):
            shutil.copy(file_path, dest_path)

        cache = self._load_cache()
        cache.pop(dest_path, None)
        self._save_cache(cache)

        if file_path.lower().endswith(".mp3"):
            metadata = self.read_mp3_metadata(dest_path)
        else:
            metadata = self.read_wav_metadata(dest_path)

        metadata['bpm'] = get_bpm(dest_path) or "Н/Д"
        metadata["file_mtime"] = os.path.getmtime(dest_path)

        self.songs.append(metadata)
        return metadata

    def update_song_metadata(self, song_data):
        filepath = song_data['path']
        if not filepath.lower().endswith(".mp3"):
            print(f"Обновление метаданных не поддерживается для .wav: {filepath}")
            return

        try:
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

            cache = self._load_cache()
            cached_entry = cache.get(filepath)
            if cached_entry:
                cached_entry.update(song_data)
                cached_entry["file_mtime"] = os.path.getmtime(filepath)
                self._save_cache(cache)

            for song in self.songs:
                if song['path'] == filepath:
                    song.update(song_data)
                    song["file_mtime"] = os.path.getmtime(filepath)
                    break

        except Exception as e:
            print(f"Ошибка при обновлении метаданных: {e}")