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
        #print(f"⚠️ {CACHE_FILE} повреждён или не является JSON. Сбрасываю кэш.")
        BPM_CACHE = {}
    except Exception as e:
        #print(f"⚠️ Ошибка при чтении {CACHE_FILE}: {e}")
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
    "main_menu_mixed_and_mastered.mp3": 94
}

for filename, expected_bpm in EXPECTED_BPMS.items():
    if filename in BPM_CACHE:
        calculated_bpm = BPM_CACHE[filename]
        diff = abs(calculated_bpm - expected_bpm)
        #print(f"{filename:<30} {expected_bpm:<8} {calculated_bpm:<10} {diff:<8}")
    else:
        pass
        #print(f"{filename:<30} {expected_bpm:<8} {'(кэш)':<10} {'-':<8}")

#print("=" * 60 + "\n")



def preprocess_audio_for_bpm(y, sr):
    """Предварительная обработка аудио для лучшего определения BPM"""
    try:
        import librosa

        # 1. Если стерео - конвертируем в моно
        if y.ndim > 1:
            y = librosa.to_mono(y)

        # 2. Выделение перкуссии (грубый способ - HPF)
        # Это может помочь для треков с сильным вокалом/мелодией
        y_hpf = librosa.effects.preemphasis(y, coef=0.97)  # HPF

        # 3. Альтернатива - попробовать выделить "ударные" частоты
        # Фильтруем полосой, где обычно бывают ударные (100-5000 Hz)
        # librosa не имеет встроенного bandpass, но можно через STFT
        # Пока оставим HPF как основной метод

        return y_hpf
    except:
        # Если обработка не удалась, возвращаем оригинальный сигнал
        return y


def get_bpm_advanced(file_path, save_cache=True):
    """Улучшенная функция определения BPM с несколькими подходами"""
    fname = os.path.basename(file_path).lower()

    # Проверяем кэш
    if fname in BPM_CACHE:
        bpm = BPM_CACHE[fname]
        #print(f"{fname}: cached bpm={bpm}")

        # Выводим сравнение, если есть эталон
        for expected_file, expected_bpm in EXPECTED_BPMS.items():
            if expected_file.lower() in fname:
                diff = abs(bpm - expected_bpm)
                #print(f"  -> Сравнение с эталоном: {expected_bpm} (разница: {diff})")
                break
        return bpm

    try:
        import librosa
        from librosa.feature.rhythm import tempo as rhythm_tempo

        y, sr = librosa.load(file_path, sr=44100)

        y_processed = preprocess_audio_for_bpm(y, sr)

        tempos = []

        onset_env = librosa.onset.onset_strength(y=y_processed, sr=sr)

        tempo1 = rhythm_tempo(onset_envelope=onset_env, sr=sr, hop_length=512, ac_size=4.0, max_tempo=300.0)
        tempos.append(tempo1.item())

        tempo2 = rhythm_tempo(onset_envelope=onset_env, sr=sr, hop_length=512, ac_size=8.0, max_tempo=300.0)
        tempos.append(tempo2.item())

        tempo3, _ = librosa.beat.beat_track(y=y, sr=sr, hop_length=512)
        tempos.append(tempo3.item())

        tempo4, _ = librosa.beat.beat_track(y=y_processed, sr=sr, hop_length=512)
        tempos.append(tempo4.item())

        tempo5 = rhythm_tempo(onset_envelope=onset_env, sr=sr, hop_length=512, ac_size=2.0, max_tempo=300.0)
        tempos.append(tempo5.item())

        tempo6 = rhythm_tempo(onset_envelope=onset_env, sr=sr, hop_length=512, ac_size=16.0, max_tempo=300.0)
        tempos.append(tempo6.item())

        valid_tempos = []
        for t in tempos:
            if t < 20 or t > 300:
                continue

            temp_t = float(t)

            candidates = [temp_t]
            if temp_t < 60:
                candidates.extend([temp_t * 2, temp_t * 4])
            if temp_t > 200:
                candidates.extend([temp_t / 2, temp_t / 4])
            if temp_t < 40:
                candidates.extend([temp_t * 3, temp_t * 6])
            if temp_t > 400:
                candidates.extend([temp_t / 3, temp_t / 6])

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
        else:
            bpm = int(round(np.median(tempos)))

        bpm = max(60, min(200, bpm))

        if len(valid_tempos) > 1:
            std_dev = np.std(valid_tempos)
            if std_dev > 10:
                rounded_tempos = [round(t) for t in valid_tempos]
                from collections import Counter
                most_common = Counter(rounded_tempos).most_common(1)[0][0]
                bpm = most_common

        #print(f"{fname}: calculated bpm={bpm} (from {len(valid_tempos)}/{len(tempos)} valid methods)")

        for expected_file, expected_bpm in EXPECTED_BPMS.items():
            if expected_file.lower() in fname:
                diff = abs(bpm - expected_bpm)
                break

        if save_cache:
            BPM_CACHE[fname] = bpm
            with open(CACHE_FILE, "w", encoding="utf-8") as f:
                json.dump(BPM_CACHE, f, ensure_ascii=False, indent=2)

        return bpm

    except ImportError:
        #print("librosa не найдена в текущем окружении.")
        return None
    except Exception as e:
        #print(f"BPM error: {e}")
        #print(f"{fname}: error calculating bpm: {e}")
        return None


def get_bpm(file_path, save_cache=True):
    return get_bpm_advanced(file_path, save_cache)


def reset_cache():
    global BPM_CACHE
    BPM_CACHE = {}
    if os.path.exists(CACHE_FILE):
        os.remove(CACHE_FILE)
    #print("Кэш BPM сброшен")


def analyze_bpm_methods(file_path):
    try:
        import librosa
        from librosa.feature.rhythm import tempo as rhythm_tempo

        y, sr = librosa.load(file_path, sr=44100)
        fname = os.path.basename(file_path)

        #print(f"\n=== Анализ методов для {fname} ===")

        tempo1, _ = librosa.beat.beat_track(y=y, sr=sr, hop_length=512)
        #print(f"Beat track (hop=512): {tempo1.item():.2f}")

        onset_env = librosa.onset.onset_strength(y=y, sr=sr)
        tempo2 = rhythm_tempo(onset_envelope=onset_env, sr=sr, hop_length=512)
        #print(f"Tempo (onset): {tempo2.item():.2f}")

        tempo3, _ = librosa.beat.beat_track(y=y, sr=sr, hop_length=1024)
        #print(f"Beat track (hop=1024): {tempo3.item():.2f}")

        tempo4, _ = librosa.beat.beat_track(y=y, sr=sr, hop_length=256)
        #print(f"Beat track (hop=256): {tempo4.item():.2f}")

        tempo5 = rhythm_tempo(onset_envelope=onset_env, sr=sr, hop_length=512,
                              ac_size=4.0, max_tempo=300.0)
        #print(f"Tempo (autocorr): {tempo5.item():.2f}")

    except Exception as e:
        print(f"Ошибка анализа: {e}")
