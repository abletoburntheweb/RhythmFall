# calibration.py
import json
from pathlib import Path


CALIBRATION_FILE = Path("songs") / "calibration.json"


def load_calibration():
    if not CALIBRATION_FILE.exists():
        print(f"[Calibration] Файл калибровки не найден: {CALIBRATION_FILE}")
        return {}

    try:
        with open(CALIBRATION_FILE, 'r', encoding='utf-8') as f:
            data = json.load(f)
        print(f"[Calibration] Загружено калибровок: {len(data)}")
        return data
    except Exception as e:
        print(f"[Calibration] Ошибка чтения калибровки: {e}")
        return {}


def save_calibration(data):
    try:
        CALIBRATION_FILE.parent.mkdir(parents=True, exist_ok=True)
        with open(CALIBRATION_FILE, 'w', encoding='utf-8') as f:
            json.dump(data, f, indent=2, ensure_ascii=False)
        print(f"[Calibration] Калибровка сохранена: {CALIBRATION_FILE}")
    except Exception as e:
        print(f"[Calibration] Ошибка сохранения калибровки: {e}")


def get_audio_offset_for_song(song_path):

    data = load_calibration()
    song_str = str(Path(song_path).as_posix())
    return data.get(song_str, {}).get("audio_offset", 2.4)


def set_audio_offset_for_song(song_path, audio_offset):
    data = load_calibration()
    song_str = str(Path(song_path).as_posix())
    data[song_str] = {
        "audio_offset": audio_offset
    }
    save_calibration(data)