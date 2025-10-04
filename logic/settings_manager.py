# settings_manager.py
import json
import os

SETTINGS_FILE = "config/settings.json"
DEFAULT_SETTINGS = {
    "fullscreen": False,
    "music_volume": 50,
    "effects_volume": 80,
    "preview_volume": 70,
    "show_fps": False,
    "hit_sounds_volume": 70
}

def load_settings():
    try:
        if os.path.exists(SETTINGS_FILE):
            with open(SETTINGS_FILE, "r", encoding="utf-8") as f:
                return _apply_defaults(json.load(f))
        else:
            print("Файл настроек не найден. Используются значения по умолчанию.")
            return DEFAULT_SETTINGS.copy()
    except (json.JSONDecodeError, IOError) as e:
        print(f"Ошибка чтения файла настроек: {e}. Используются значения по умолчанию.")
        return DEFAULT_SETTINGS.copy()

def save_settings(settings):
    try:
        with open(SETTINGS_FILE, "w", encoding="utf-8") as f:
            json.dump(settings, f, indent=4)
        print("Настройки успешно сохранены.")
    except Exception as e:
        print(f"Ошибка при сохранении настроек: {e}")

def _apply_defaults(settings_dict):
    result = DEFAULT_SETTINGS.copy()
    result.update(settings_dict)
    return result