import os
import shutil
from mutagen.mp3 import MP3
from mutagen.id3 import ID3

SONG_FOLDER = "songs"

class SongManager:
    def __init__(self):
        if not os.path.exists(SONG_FOLDER):
            os.makedirs(SONG_FOLDER)
        self.songs = []
        self.load_songs()

    def load_songs(self):
        self.songs.clear()
        for file in os.listdir(SONG_FOLDER):
            if file.lower().endswith(".mp3"):
                path = os.path.join(SONG_FOLDER, file)
                metadata = self.read_mp3_metadata(path)
                self.songs.append(metadata)

    def read_mp3_metadata(self, filepath):
        metadata = {
            "path": filepath,
            "title": os.path.splitext(os.path.basename(filepath))[0],
            "artist": "Неизвестен",
            "cover": None,
            "bpm": "Н/Д",
            "year": "Н/Д"
        }
        try:
            audio = MP3(filepath, ID3=ID3)
            if audio.tags:
                if 'TIT2' in audio.tags:
                    metadata['title'] = audio.tags['TIT2'].text[0]
                if 'TPE1' in audio.tags:
                    metadata['artist'] = audio.tags['TPE1'].text[0]
                if 'TDRC' in audio.tags:
                    metadata['year'] = str(audio.tags['TDRC'])
                for tag in audio.tags.keys():
                    if tag.startswith("APIC"):
                        cover_path = os.path.join(SONG_FOLDER, f"{metadata['title']}_cover.png")
                        with open(cover_path, "wb") as img:
                            img.write(audio.tags[tag].data)
                        metadata['cover'] = cover_path
                        break
        except Exception as e:
            print(f"Ошибка чтения mp3: {e}")
        return metadata

    def add_song(self, file_path):
        if not os.path.exists(file_path) or not file_path.lower().endswith(".mp3"):
            return None
        dest_path = os.path.join(SONG_FOLDER, os.path.basename(file_path))
        if not os.path.exists(dest_path):
            shutil.copy(file_path, dest_path)
        metadata = self.read_mp3_metadata(dest_path)
        self.songs.append(metadata)
        return metadata
