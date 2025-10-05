import json
from pathlib import Path
from logic.notes import DefaultNote, HoldNote


class NoteManager:
    def __init__(self, game_screen):
        self.game_screen = game_screen
        self.notes = []
        self.note_spawn_queue = []

    def load_notes_from_file(self, song_data):
        song_path = song_data.get("path")
        if not song_path:
            print("Ошибка: Путь к песне не указан.")
            return

        base_name = Path(song_path).stem
        notes_file_path = Path("songs") / "notes" / f"{base_name}.json"

        try:
            if not notes_file_path.exists():
                print(f"Файл нот не найден: {notes_file_path}")
                return

            with open(notes_file_path, 'r', encoding='utf-8') as f:
                notes_data = json.load(f)

            if not isinstance(notes_data, list):
                print(f"Ошибка: Файл нот {notes_file_path} содержит некорректные данные (ожидается список).")
                return

            print(f"Загружено {len(notes_data)} нот из {notes_file_path}")

            for note in notes_data:
                if not isinstance(note, dict):
                    print(f"Предупреждение: Некорректная запись ноты в {notes_file_path}: {note}")
                    continue
                if "time" not in note or "lane" not in note or "type" not in note:
                    print(f"Предупреждение: Неполная запись ноты в {notes_file_path}: {note}")
                    continue

            sorted_notes_data = sorted(notes_data, key=lambda x: x.get("time", 0))
            self.note_spawn_queue = sorted_notes_data

        except json.JSONDecodeError as e:
            print(f"Ошибка чтения JSON из {notes_file_path}: {e}")
        except FileNotFoundError:
            print(f"Файл нот не найден: {notes_file_path}")
        except Exception as e:
            print(f"Неизвестная ошибка при загрузке нот: {e}")

    def spawn_notes(self):
        game_time = self.game_screen.game_time
        speed = self.game_screen.speed
        hit_zone_y = self.game_screen.hit_zone_y

        while self.note_spawn_queue and self.note_spawn_queue[0].get("time", 0) <= game_time:
            note_info = self.note_spawn_queue.pop(0)
            lane = note_info.get("lane", 0)
            time = note_info.get("time", 0.0)
            note_type = note_info.get("type", "DefaultNote")

            pixels_per_sec = speed * (1000 / 16)
            initial_y_offset_from_top = -20
            y_now = initial_y_offset_from_top + (game_time - time) * pixels_per_sec

            if note_type == "DefaultNote":
                if y_now < self.game_screen.height() + 20:
                    note = DefaultNote(lane, y=y_now)
                    note.time = time
                    self.notes.append(note)
            elif note_type == "HoldNote":
                duration = note_info.get("duration", 1.0)
                height = int(duration * pixels_per_sec)
                if y_now < self.game_screen.height() + height:
                    note = HoldNote(lane, y=y_now, length=height, hold_time=duration * 1000)
                    note.time = time
                    self.notes.append(note)
            else:
                print(f"Неизвестный тип ноты: {note_type}")

    def update_notes(self):
        speed = self.game_screen.speed
        hit_zone_y = self.game_screen.hit_zone_y

        for note in self.notes:
            try:
                note.update(speed=speed)
            except Exception as e:
                print(f"[ERROR] Ошибка при обновлении ноты: {e}")
                note.active = False

            if note.y > hit_zone_y + 20:
                self.game_screen.score_manager.add_miss_hit()
                note.active = False

        self.notes = [n for n in self.notes if n.active]

    def get_notes(self):
        return self.notes

    def clear_notes(self):
        self.notes.clear()
        self.note_spawn_queue.clear()

    def get_spawn_queue_size(self):
        return len(self.note_spawn_queue)