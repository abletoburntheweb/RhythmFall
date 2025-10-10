import os
import json
import random
import subprocess
from pathlib import Path

SONGS_CACHE_FILE = "data/songs_cache.json"
NOTES_DIR = Path("songs") / "notes"
WAV_CACHE_DIR = Path("temp") / "wav_cache"
SPLITTER_CACHE_DIR = Path("temp") / "demucs_cache"


def load_songs_cache():
    if os.path.exists(SONGS_CACHE_FILE):
        try:
            with open(SONGS_CACHE_FILE, 'r', encoding='utf-8') as f:
                return json.load(f)
        except (json.JSONDecodeError, FileNotFoundError) as e:
            print(f"⚠️ Ошибка загрузки кэша песен {SONGS_CACHE_FILE}: {e}")
            return {}
    return {}


def get_bpm_for_song(song_path):
    cache = load_songs_cache()

    if song_path in cache and 'bpm' in cache[song_path]:
        return cache[song_path]['bpm']

    filename = Path(song_path).name.lower()
    for path_key, info in cache.items():
        if Path(path_key).name.lower() == filename and 'bpm' in info:
            return info['bpm']

    return None


def convert_to_wav_if_needed(song_path):
    song_path_obj = Path(song_path)
    wav_filename = song_path_obj.stem + ".wav"
    wav_path = WAV_CACHE_DIR / wav_filename

    if wav_path.exists():
        print(f"[NoteGen] Используем кэшированный .wav: {wav_path}")
        return str(wav_path)

    try:
        from pydub import AudioSegment
        print(f"[NoteGen] Конвертируем {song_path} в .wav (качество 320kbps, 44.1kHz) для анализа...")
        audio = AudioSegment.from_file(song_path)
        audio = audio.set_frame_rate(44100).set_channels(2)
        WAV_CACHE_DIR.mkdir(parents=True, exist_ok=True)
        audio.export(wav_path, format="wav", parameters=["-q:a", "0"])
        print(f"[NoteGen] Конвертация завершена: {wav_path}")
        return str(wav_path)
    except ImportError:
        print("pydub не установлен. Невозможно конвертировать .mp3 в .wav. Используем оригинальный файл.")
        print("Установите: pip install pydub")
        return song_path
    except Exception as e:
        print(f"[NoteGen] Ошибка конвертации в .wav: {e}")
        return song_path


def separate_audio_with_demucs(wav_path):
    import subprocess
    from pathlib import Path
    import shutil

    song_path_obj = Path(wav_path)
    song_name = song_path_obj.stem
    final_cache_dir = SPLITTER_CACHE_DIR / song_name
    final_no_vocals_path = final_cache_dir / "no_vocals.wav"
    final_vocals_path = final_cache_dir / "vocals.wav"

    if final_no_vocals_path.exists() and final_vocals_path.exists():
        print(f"[NoteGen] Используем кэшированные разделённые дорожки (Demucs): {final_cache_dir}")
        return str(final_no_vocals_path), str(final_vocals_path)

    try:
        print(f"[NoteGen] Запускаю Demucs для {wav_path}...")
        cmd = [
            "demucs",
            "-n", "htdemucs",
            "--two-stems", "vocals",
            "-o", str(SPLITTER_CACHE_DIR),
            wav_path
        ]
        subprocess.run(cmd, check=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)

        demucs_output_subdir = SPLITTER_CACHE_DIR / "htdemucs" / song_name
        original_no_vocals = demucs_output_subdir / "no_vocals.wav"
        original_vocals = demucs_output_subdir / "vocals.wav"

        if original_no_vocals.exists():
            final_cache_dir.mkdir(parents=True, exist_ok=True)
            shutil.move(str(original_no_vocals), str(final_no_vocals_path))
            if original_vocals.exists():
                shutil.move(str(original_vocals), str(final_vocals_path))
            print(f"[NoteGen] Файлы перемещены в упрощённую структуру: {final_cache_dir}")
            try:
                demucs_output_subdir.rmdir()
                (SPLITTER_CACHE_DIR / "htdemucs").rmdir()
            except OSError:
                pass
            return str(final_no_vocals_path), str(final_vocals_path)
        else:
            print(f"[NoteGen] Ошибка: Demucs не создал no_vocals.wav в {demucs_output_subdir}")
            return None, None

    except subprocess.CalledProcessError as e:
        print(f"[NoteGen] Ошибка разделения Demucs: {e}")
        return None, None
    except FileNotFoundError:
        print("[NoteGen] Demucs не установлен. Установите: pip install demucs torch torchaudio")
        return None, None
    except Exception as e:
        print(f"[NoteGen] Неожиданная ошибка при разделении Demucs: {e}")
        import traceback
        traceback.print_exc()
        return None, None


def generate_notes_for_song(song_path, bpm, lanes=4):
    print(f"Генерация нот для: {song_path} (BPM: {bpm})")

    if not bpm or bpm <= 0:
        print(f"Ошибка: Некорректный BPM ({bpm}) для {song_path}")
        return None

    try:
        import librosa
        wav_path = convert_to_wav_if_needed(song_path)
        if not wav_path:
            print(f"[NoteGen] Ошибка: Не удалось получить .wav для {song_path}")
            return None

        accompaniment_path, vocals_path = separate_audio_with_demucs(wav_path)
        if not accompaniment_path:
            print(
                f"[NoteGen] Ошибка: Не удалось получить дорожку accompaniment для {song_path}. Использую оригинальный .wav.")
            audio_to_analyze_path = wav_path
        else:
            audio_to_analyze_path = accompaniment_path
            print(f"[NoteGen] ИСПОЛЬЗУЕМ NO_VOCALS ДЛЯ АНАЛИЗА: {audio_to_analyze_path}")

        y, sr = librosa.load(audio_to_analyze_path, sr=None, mono=False, dtype='float32')
        if y.ndim > 1:
            y = y.mean(axis=0)
        print(
            f"[NoteGen] Аудио для анализа загружено: {audio_to_analyze_path}, sr={sr}, shape={y.shape}, dtype={y.dtype}")

        y_harmonic, y_percussive = librosa.effects.hpss(y)
        print("[NoteGen] Аудио (для анализа) разделено на гармоническую и перкуссионную дорожки.")

        provided_tempo_float = float(bpm)
        tempo, beats = librosa.beat.beat_track(y=y_percussive, sr=sr, bpm=provided_tempo_float, units='time')
        print(
            f"[NoteGen] Используем предоставленный BPM: {provided_tempo_float:.2f}. Librosa уточнила его до: {tempo:.2f} и нашла {len(beats)} битов.")

        onset_env = librosa.onset.onset_strength(y=y_percussive, sr=sr)
        times = librosa.times_like(onset_env, sr=sr)

        onset_peaks = librosa.util.peak_pick(onset_env, pre_max=3, post_max=3, pre_avg=3, post_avg=5,
                                             delta=onset_env.max() * 0.10, wait=1)
        strong_onset_times = times[onset_peaks]
        print(f"[NoteGen] Найдено {len(strong_onset_times)} отфильтрованных onset'ов")

        synchronized_times = []
        for onset_time in strong_onset_times:
            closest_beat_idx = (beats - onset_time) ** 2
            closest_beat_idx = closest_beat_idx.argmin()
            closest_beat_time = beats[closest_beat_idx]
            if abs(onset_time - closest_beat_time) <= 0.25:
                synchronized_times.append(closest_beat_time)

        print(f"[NoteGen] Синхронизировано {len(synchronized_times)} onset'ов с битами")

        notes = []

        min_note_interval = 0.10
        last_note_time = -min_note_interval

        for onset_time in synchronized_times:
            if onset_time - last_note_time >= min_note_interval:
                if random.random() < 0.95:
                    lane = random.randint(0, lanes - 1)
                    notes.append({
                        "type": "DefaultNote",
                        "lane": lane,
                        "time": float(onset_time)
                    })
                    last_note_time = onset_time

        print(
            f"Сгенерировано {len(notes)} нот для {Path(song_path).name} на основе анализа accompaniment (Demucs), синхронизированной с битами")
        return notes

    except ImportError:
        print("librosa не установлена. Не могу выполнить анализ аудио.")
        print("Установите: pip install librosa")
        notes = [
            {"type": "DefaultNote", "lane": 0, "time": 1.0},
            {"type": "DefaultNote", "lane": 1, "time": 2.0},
            {"type": "DefaultNote", "lane": 2, "time": 3.5},
        ]
        return notes
    except Exception as e:
        print(f"Ошибка при генерации нот для {song_path}: {e}")
        import traceback
        traceback.print_exc()
        return None


def save_notes_to_file(notes_data, song_path):
    if not notes_data:
        print("Нет данных нот для сохранения.")
        return False

    NOTES_DIR.mkdir(parents=True, exist_ok=True)

    base_name = Path(song_path).stem
    notes_filename = f"{base_name}.json"
    notes_path = NOTES_DIR / notes_filename

    try:
        def convert_types(obj):
            import numpy as np
            if isinstance(obj, np.integer):
                return int(obj)
            elif isinstance(obj, np.floating):
                return float(obj)
            elif isinstance(obj, np.ndarray):
                return obj.tolist()
            elif isinstance(obj, list):
                return [convert_types(i) for i in obj]
            elif isinstance(obj, dict):
                return {key: convert_types(value) for key, value in obj.items()}
            return obj

        notes_data_serializable = convert_types(notes_data)

        temp_path = notes_path.with_suffix('.tmp')
        with open(temp_path, 'w', encoding='utf-8') as f:
            json.dump(notes_data_serializable, f, ensure_ascii=False, indent=4)
            f.flush()
            os.fsync(f.fileno())
        temp_path.replace(notes_path)

        print(f"Ноты сохранены в: {notes_path}")
        return True
    except Exception as e:
        print(f"Ошибка сохранения нот в {notes_path}: {e}")

        if temp_path.exists():
            temp_path.unlink()
        return False