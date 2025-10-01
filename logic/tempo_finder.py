import numpy as np
from pydub import AudioSegment
from collections import Counter
import os
import json

SONGS_DIR = "songs"
CACHE_FILE = os.path.join(SONGS_DIR, "bpms.json")

# Убедимся, что папка songs существует
os.makedirs(SONGS_DIR, exist_ok=True)

# Безопасная загрузка кэша bpms.json — учитываем пустой/битый файл
BPM_CACHE = {}
if os.path.exists(CACHE_FILE):
    try:
        # если файл пустой — инициализируем пустым объектом
        if os.path.getsize(CACHE_FILE) == 0:
            with open(CACHE_FILE, "w", encoding="utf-8") as f:
                f.write("{}")
            BPM_CACHE = {}
        else:
            with open(CACHE_FILE, "r", encoding="utf-8") as f:
                BPM_CACHE = json.load(f)
    except json.JSONDecodeError:
        print(f"⚠️ {CACHE_FILE} повреждён или не является JSON. Сбрасываю кэш.")
        BPM_CACHE = {}
    except Exception as e:
        print(f"⚠️ Ошибка при чтении {CACHE_FILE}: {e}")
        BPM_CACHE = {}
else:
    BPM_CACHE = {}


def get_bpm(file_path, chunk_ms=20, min_bpm=60, max_bpm=200, save_cache=True):
    fname = os.path.basename(file_path).lower()

    # ⚡ если BPM уже в кэше — возвращаем его
    if fname in BPM_CACHE:
        return BPM_CACHE[fname]

    try:
        audio = AudioSegment.from_file(file_path)
        audio = audio.set_channels(1).set_frame_rate(44100)

        # делим на чанки
        chunks = [audio[i:i + chunk_ms] for i in range(0, len(audio), chunk_ms)]
        rms_values = np.array([c.rms for c in chunks])

        # нормализация (NumPy 2.0 совместимо)
        rms_values = rms_values.astype(float)
        rms_range = np.ptp(rms_values)
        if rms_range == 0:
            return None
        rms_values = (rms_values - rms_values.min()) / rms_range

        # порог по RMS
        threshold = 0.5 * (np.median(rms_values) + rms_values.max())
        peaks = np.where(rms_values > threshold)[0]
        if len(peaks) < 4:
            return None

        # интервалы между пиками
        intervals = np.diff(peaks) * chunk_ms
        if len(intervals) == 0:
            return None

        # фильтрация слишком коротких/длинных интервалов
        intervals = [i for i in intervals if 250 < i < 2000]  # 30–240 BPM
        if not intervals:
            return None

        # находим наиболее часто встречающийся интервал
        counter = Counter(intervals)
        common_interval = counter.most_common(1)[0][0]

        bpm = 60000 / common_interval

        # нормализация в диапазон
        while bpm < min_bpm:
            bpm *= 2
        while bpm > max_bpm:
            bpm /= 2

        bpm = int(round(bpm))

        # 🎵 тест с "эталонными" темпами
        expected = None
        if "daydreaming" in fname:
            expected = 113
        elif "hyperpop5demo" in fname:
            expected = 157

        if expected:
            print(f"{fname}: expected {expected}, got {bpm}")
        else:
            print(f"{fname}: bpm={bpm}")

        # ⚡ сохраняем в кэш (bpms.json в songs/)
        if save_cache:
            BPM_CACHE[fname] = bpm
            with open(CACHE_FILE, "w", encoding="utf-8") as f:
                json.dump(BPM_CACHE, f, ensure_ascii=False, indent=2)

        return bpm

    except Exception as e:
        print(f"BPM error: {e}")
        return None
