# tempo_finder.py
from pydub import AudioSegment
import numpy as np


def get_bpm(file_path, chunk_ms=100):
    try:
        audio = AudioSegment.from_file(file_path)
        audio = audio.set_channels(1)
        audio = audio.set_frame_rate(44100)

        chunks = [audio[i:i + chunk_ms] for i in range(0, len(audio), chunk_ms)]
        rms_values = np.array([chunk.rms for chunk in chunks])

        threshold = rms_values.mean() + 0.5 * rms_values.std()
        peaks = np.where(rms_values > threshold)[0]

        if len(peaks) < 2:
            return None

        intervals_ms = np.diff(peaks) * chunk_ms
        avg_interval_ms = np.mean(intervals_ms)

        bpm = 60000 / avg_interval_ms
        while bpm < 60:
            bpm *= 2
        while bpm > 180:
            bpm /= 2
        bpm = int(round(bpm))
        return int(round(bpm))
    except Exception as e:
        print(f"Ошибка при определении BPM: {e}")
        return None
