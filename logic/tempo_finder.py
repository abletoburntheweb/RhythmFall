import os
import json
import numpy as np
from pathlib import Path

SONGS_CACHE_FILE = "data/songs_cache.json"
SONGS_DIR = "songs"


def load_songs_cache():
    if os.path.exists(SONGS_CACHE_FILE):
        try:
            with open(SONGS_CACHE_FILE, "r", encoding="utf-8") as f:
                return json.load(f)
        except (json.JSONDecodeError, FileNotFoundError) as e:
            print(f"⚠️ Ошибка загрузки кэша песен {SONGS_CACHE_FILE}: {e}")
            return {}
    return {}


def save_songs_cache(cache):
    os.makedirs(os.path.dirname(SONGS_CACHE_FILE), exist_ok=True)
    with open(SONGS_CACHE_FILE, "w", encoding="utf-8") as f:
        json.dump(cache, f, ensure_ascii=False, indent=2)


def get_bpm_from_cache(song_path):
    cache = load_songs_cache()

    song_key = song_path
    if song_key in cache:
        return cache[song_key].get('bpm')

    filename = Path(song_path).name.lower()
    for key, info in cache.items():
        if Path(key).name.lower() == filename:
            return info.get('bpm')

    return None


def save_bpm_to_cache(song_path, bpm):
    cache = load_songs_cache()

    song_key = song_path
    if song_key not in cache:
        cache[song_key] = {
            "path": song_path,
            "title": Path(song_path).stem,
            "artist": "Неизвестен",
            "bpm": bpm,
            "year": "Н/Д",
            "duration": "Н/Д"
        }
    else:
        cache[song_key]["bpm"] = bpm

    save_songs_cache(cache)


def get_bpm_cache():
    cache = load_songs_cache()
    bpm_dict = {}
    for song_path, info in cache.items():
        filename = Path(song_path).name.lower()
        bpm_dict[filename] = info.get('bpm')
    return bpm_dict


BPM_CACHE = get_bpm_cache()

EXPECTED_BPMS = {
    "daydreaming.mp3": 113,
    "hyperpop5demo.mp3": 157,
    "killshot - eminem.mp3": 106,
    "listen! - hako.mp3": 134,
    "motto - nf.mp3": 80,
    "intro_mixed_and_mastered.mp3": 130,
    "main_menu_mixed_and_mastered.mp3": 94,
    "around the world - daft punk.mp3": 121,
    "hypernova.mp3": 170
}


def preprocess_audio_for_bpm(y, sr):
    try:
        import librosa

        if y.ndim > 1:
            y = librosa.to_mono(y)

        spectral_centroids = librosa.feature.spectral_centroid(y=y, sr=sr)[0]
        avg_centroid = np.mean(spectral_centroids)

        if avg_centroid > 2000:
            y = librosa.effects.preemphasis(y, coef=0.8)
        else:
            y = librosa.effects.preemphasis(y, coef=0.97)

        y = librosa.util.normalize(y)

        y = librosa.effects.trim(y, top_db=40)[0]

        return y
    except:
        return y


def get_bpm_advanced(file_path, save_cache=True):
    fname = Path(file_path).name.lower()

    cached_bpm = get_bpm_from_cache(file_path)
    if cached_bpm is not None:
        bpm = cached_bpm
        for expected_file, expected_bpm in EXPECTED_BPMS.items():
            expected_mp3 = expected_file.lower()
            expected_wav = expected_file.lower().replace('.mp3', '.wav')

            if expected_mp3 in fname or expected_wav in fname:
                diff = abs(bpm - expected_bpm)
                song_name = expected_file.replace('.mp3', '').replace('.wav', '')
                break
        return bpm

    try:
        import librosa
        from librosa.feature.rhythm import tempo as rhythm_tempo

        y, sr = librosa.load(file_path, sr=44100)

        y_processed = preprocess_audio_for_bpm(y, sr)

        tempos = []

        onset_env = librosa.onset.onset_strength(y=y_processed, sr=sr)

        tempo_configs = [
            (512, 4.0),
            (512, 8.0),
            (512, 2.0),
            (512, 16.0),
            (1024, 4.0),
            (256, 4.0),
            (256, 8.0),
            (1024, 2.0),

            (128, 4.0),
            (2048, 4.0),
        ]

        for hop_length, ac_size in tempo_configs:
            try:
                tempo = rhythm_tempo(
                    onset_envelope=onset_env,
                    sr=sr,
                    hop_length=hop_length,
                    ac_size=ac_size,
                    max_tempo=300.0
                )
                tempos.append(tempo.item())
            except:
                continue

        try:
            tempo_bt, _ = librosa.beat.beat_track(y=y, sr=sr, hop_length=512, start_bpm=120)
            tempos.append(tempo_bt.item())
        except:
            pass

        try:
            tempo_bt_processed, _ = librosa.beat.beat_track(y=y_processed, sr=sr, hop_length=512, start_bpm=120)
            tempos.append(tempo_bt_processed.item())
        except:
            pass

        try:

            y_harmonic, y_percussive = librosa.effects.hpss(y_processed)
            tempo_perc, _ = librosa.beat.beat_track(y=y_percussive, sr=sr, hop_length=512)
            tempos.append(tempo_perc.item())
        except:
            pass

        valid_tempos = []
        for t in tempos:
            if t < 20 or t > 300:
                continue

            temp_t = float(t)

            candidates = [temp_t]

            if temp_t < 60:
                candidates.extend([temp_t * 2, temp_t * 4, temp_t * 3])

            elif temp_t > 200:
                candidates.extend([temp_t / 2, temp_t / 4, temp_t / 3])

            elif temp_t > 180:
                candidates.extend([temp_t / 2])
            elif temp_t < 80:
                candidates.extend([temp_t * 2])

            if temp_t < 40:
                candidates.extend([temp_t * 6, temp_t * 8])

            if temp_t > 400:
                candidates.extend([temp_t / 6, temp_t / 8])

            candidates.extend([temp_t * 3, temp_t / 3])

            best_candidate = None
            min_fractional_part = float('inf')
            for candidate in candidates:
                if 60 <= candidate <= 200:
                    fractional_part = abs(candidate - round(candidate))
                    if fractional_part < min_fractional_part:
                        min_fractional_part = fractional_part
                        best_candidate = candidate

            if best_candidate is not None:
                valid_tempos.append(best_candidate)

        if valid_tempos:

            bpm = int(round(np.median(valid_tempos)))

            std_dev = np.std(valid_tempos) if len(valid_tempos) > 1 else 0
            if std_dev > 15:

                rounded_tempos = [round(t) for t in valid_tempos]
                from collections import Counter
                most_common = Counter(rounded_tempos).most_common(1)[0][0]
                bpm = most_common
            else:

                bpm = int(round(np.median(valid_tempos)))

                from collections import Counter
                rounded_tempos = [round(t) for t in valid_tempos]
                counts = Counter(rounded_tempos)
                most_common_bpm, count = counts.most_common(1)[0]

                if count > len(valid_tempos) // 2:
                    bpm = most_common_bpm
        else:
            bpm = int(round(np.median(tempos))) if tempos else 120

        if bpm < 60:

            if bpm * 2 <= 200:
                bpm = int(bpm * 2)
        elif bpm > 200:

            if bpm / 2 >= 60:
                bpm = int(bpm / 2)

        bpm = max(60, min(200, bpm))

        print(f"{fname}: calculated bpm={bpm} (from {len(valid_tempos)}/{len(tempos)} valid methods)")

        for expected_file, expected_bpm in EXPECTED_BPMS.items():
            expected_mp3 = expected_file.lower()
            expected_wav = expected_file.lower().replace('.mp3', '.wav')

            if expected_mp3 in fname or expected_wav in fname:
                diff = abs(bpm - expected_bpm)
                song_name = expected_file.replace('.mp3', '').replace('.wav', '')
                print(f"  -> {song_name}: ожидаемо {expected_bpm} BPM, реальность: {bpm} BPM (разница: {diff})")

                if diff > 20:
                    print(f"     ⚠️  БОЛЬШАЯ РАЗНИЦА! Проверьте файл или обновите эталон.")
                break

        if save_cache:
            save_bpm_to_cache(file_path, bpm)
            BPM_CACHE[fname] = bpm

        return bpm

    except ImportError:
        print("librosa не найдена в текущем окружении.")
        return None
    except Exception as e:
        print(f"BPM error: {e}")
        print(f"{fname}: error calculating bpm: {e}")
        return None


def update_expected_bpms():
    updated = {}
    cache = load_songs_cache()

    for expected_file, expected_bpm in EXPECTED_BPMS.items():
        expected_base = expected_file.replace('.mp3', '').lower()
        for cached_path, cached_info in cache.items():
            if expected_base in cached_path.lower():
                updated[expected_file] = cached_info.get('bpm', expected_bpm)
                print(f"Обновлено: {expected_file} = {cached_info.get('bpm')} BPM")
                break
        else:
            updated[expected_file] = expected_bpm

    return updated


def analyze_bpm_quality(file_path):
    try:
        import librosa
        from librosa.feature.rhythm import tempo as rhythm_tempo

        y, sr = librosa.load(file_path, sr=44100)
        fname = Path(file_path).name

        print(f"\n=== Анализ качества BPM для {fname} ===")

        onset_env = librosa.onset.onset_strength(y=y, sr=sr)
        tempo_main = rhythm_tempo(onset_envelope=onset_env, sr=sr, hop_length=512)
        print(f"Основной метод: {tempo_main.item():.2f}")

        configs = [
            (256, 4.0, "короткий хоп"),
            (512, 2.0, "короткий автокорр"),
            (512, 8.0, "длинный автокорр"),
            (1024, 4.0, "длинный хоп"),
        ]

        results = []
        for hop, ac_size, name in configs:
            try:
                tempo = rhythm_tempo(onset_envelope=onset_env, sr=sr, hop_length=hop, ac_size=ac_size)
                results.append(tempo.item())
                print(f"{name}: {tempo.item():.2f}")
            except:
                print(f"{name}: ошибка")

        if len(results) > 1:
            std_dev = np.std(results)
            print(f"Стандартное отклонение: {std_dev:.2f}")
            if std_dev > 10:
                print("⚠️  Высокая вариативность результатов - BPM может быть неточным")
            else:
                print("✅  Результаты стабильны")

        if results:
            median_val = np.median(results)
            outliers = [r for r in results if abs(r - median_val) > 20]
            if outliers:
                print(f"⚠️  Найдены выбросы: {outliers}")

    except Exception as e:
        print(f"Ошибка анализа: {e}")


def get_bpm(file_path, save_cache=True):
    return get_bpm_advanced(file_path, save_cache)


def reset_cache():
    global BPM_CACHE
    cache = load_songs_cache()

    for key in cache:
        if 'bpm' in cache[key]:
            del cache[key]['bpm']

    save_songs_cache(cache)
    BPM_CACHE = {}
    print("Кэш BPM сброшен, остальные метаданные сохранены")


def analyze_bpm_methods(file_path):
    try:
        import librosa
        from librosa.feature.rhythm import tempo as rhythm_tempo

        y, sr = librosa.load(file_path, sr=44100)
        fname = Path(file_path).name

        print(f"\n=== Анализ методов для {fname} ===")

        tempo1, _ = librosa.beat.beat_track(y=y, sr=sr, hop_length=512)
        print(f"Beat track (hop=512): {tempo1.item():.2f}")

        onset_env = librosa.onset.onset_strength(y=y, sr=sr)
        tempo2 = rhythm_tempo(onset_envelope=onset_env, sr=sr, hop_length=512)
        print(f"Tempo (onset): {tempo2.item():.2f}")

        tempo3, _ = librosa.beat.beat_track(y=y, sr=sr, hop_length=1024)
        print(f"Beat track (hop=1024): {tempo3.item():.2f}")

        tempo4, _ = librosa.beat.beat_track(y=y, sr=sr, hop_length=256)
        print(f"Beat track (hop=256): {tempo4.item():.2f}")

        tempo5 = rhythm_tempo(onset_envelope=onset_env, sr=sr, hop_length=512,
                              ac_size=4.0, max_tempo=300.0)
        print(f"Tempo (autocorr): {tempo5.item():.2f}")

    except Exception as e:
        print(f"Ошибка анализа: {e}")
