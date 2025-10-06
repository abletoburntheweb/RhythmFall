# tempo_finder.py
import os
import json
import numpy as np

SONGS_DIR = "songs"
CACHE_FILE = os.path.join(SONGS_DIR, "bpms.json")

os.makedirs(SONGS_DIR, exist_ok=True)

BPM_CACHE = {}
if os.path.exists(CACHE_FILE):
    try:
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

EXPECTED_BPMS = {
    "daydreaming.mp3": 113,
    "hyperpop5demo.mp3": 157,
    "killshot - eminem.mp3": 106,
    "listen! - hako.mp3": 134,
    "motto - nf.mp3": 80,
    "intro_mixed_and_mastered.mp3": 130,
    "main_menu_mixed_and_mastered.mp3": 94,
    "around the world - daft punk.mp3": 121
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

        return y
    except:
        return y


def get_bpm_advanced(file_path, save_cache=True):
    fname = os.path.basename(file_path).lower()

    if fname in BPM_CACHE:
        bpm = BPM_CACHE[fname]
       # print(f"{fname}: cached bpm={bpm}")

        for expected_file, expected_bpm in EXPECTED_BPMS.items():
            expected_mp3 = expected_file.lower()
            expected_wav = expected_file.lower().replace('.mp3', '.wav')

            if expected_mp3 in fname or expected_wav in fname:
                diff = abs(bpm - expected_bpm)
                song_name = expected_file.replace('.mp3', '').replace('.wav', '')
              #  print(f"  -> {song_name}: ожидаемо {expected_bpm} BPM, реальность: {bpm} BPM (разница: {diff})")
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
            tempo_bt, _ = librosa.beat.beat_track(y=y, sr=sr, hop_length=512)
            tempos.append(tempo_bt.item())
        except:
            pass

        try:
            tempo_bt_processed, _ = librosa.beat.beat_track(y=y_processed, sr=sr, hop_length=512)
            tempos.append(tempo_bt_processed.item())
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
            if temp_t > 200:
                candidates.extend([temp_t / 2, temp_t / 4, temp_t / 3])
            if temp_t < 40:
                candidates.extend([temp_t * 6, temp_t * 8])
            if temp_t > 400:
                candidates.extend([temp_t / 6, temp_t / 8])

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
            bpm = int(round(np.median(tempos))) if tempos else 120

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
            BPM_CACHE[fname] = bpm
            with open(CACHE_FILE, "w", encoding="utf-8") as f:
                json.dump(BPM_CACHE, f, ensure_ascii=False, indent=2)

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
    for expected_file, expected_bpm in EXPECTED_BPMS.items():
        expected_base = expected_file.replace('.mp3', '').lower()
        for cached_file, cached_bpm in BPM_CACHE.items():
            if expected_base in cached_file:
                updated[expected_file] = cached_bpm
                print(f"Обновлено: {expected_file} = {cached_bpm} BPM")
                break
        else:
            updated[expected_file] = expected_bpm

    return updated


def analyze_bpm_quality(file_path):
    try:
        import librosa
        from librosa.feature.rhythm import tempo as rhythm_tempo

        y, sr = librosa.load(file_path, sr=44100)
        fname = os.path.basename(file_path)

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
    BPM_CACHE = {}
    if os.path.exists(CACHE_FILE):
        os.remove(CACHE_FILE)
    print("Кэш BPM сброшен")


def analyze_bpm_methods(file_path):
    try:
        import librosa
        from librosa.feature.rhythm import tempo as rhythm_tempo

        y, sr = librosa.load(file_path, sr=44100)
        fname = os.path.basename(file_path)

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