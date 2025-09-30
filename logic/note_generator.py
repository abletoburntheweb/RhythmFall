import os
import json
from pydub import AudioSegment

NOTES_FOLDER = "notes"

class NoteGenerator:
    def __init__(self):
        os.makedirs(NOTES_FOLDER, exist_ok=True)

    def generate_notes(self, song_path, bpm):
        """
        Генерирует файл с нотами на основе BPM песни.
        :param song_path: Путь к исходному MP3 файлу.
        :param bpm: Темп песни (удары в минуту).
        :return: Путь к созданному файлу с нотами.
        """
        try:
            # Определяем длительность одного такта (в миллисекундах)
            beat_duration_ms = int(60000 / bpm)

            # Загружаем аудиофайл
            audio = AudioSegment.from_file(song_path)
            total_duration_ms = len(audio)

            # Генерируем ноты
            notes = []
            lanes = [1, 2, 3, 4]  # Пример: 4 линии для нот
            for time_ms in range(0, total_duration_ms, beat_duration_ms * 4):  # Каждые 4 такта
                lane = lanes[len(notes) % len(lanes)]  # Чередуем линии
                note_type = "default" if len(notes) % 2 == 0 else "hold"
                note_data = {
                    "time": time_ms / 1000,  # Время в секундах
                    "type": note_type,
                    "lane": lane
                }
                if note_type == "hold":
                    note_data["length"] = 150  # Пример длины hold-ноты
                    note_data["hold_time"] = 1000  # Пример времени удержания
                notes.append(note_data)

            # Сохраняем ноты в JSON-файл
            song_name = os.path.splitext(os.path.basename(song_path))[0]
            notes_file_path = os.path.join(NOTES_FOLDER, f"{song_name}_notes.json")
            with open(notes_file_path, "w", encoding="utf-8") as f:
                json.dump({"bpm": bpm, "notes": notes}, f, ensure_ascii=False, indent=4)

            return notes_file_path

        except Exception as e:
            print(f"Ошибка при генерации нот: {e}")
            return None