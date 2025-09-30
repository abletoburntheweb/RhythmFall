import json
import os

SAVE_FILE = "config/completed_levels.json"
LEVELS_FILE = "config/levels.json"

def load_completed_levels():
    print("[save_utils] Загрузка данных о пройденных уровнях...")
    if not os.path.exists(SAVE_FILE):
        print("[save_utils] Файл completed_levels.json не найден.")
        return []

    with open(SAVE_FILE, "r", encoding="utf-8") as f:
        data = json.load(f)
        completed_levels = data.get("completed_levels", [])
        return completed_levels

def get_max_level():
    with open(LEVELS_FILE, "r", encoding="utf-8") as f:
        data = json.load(f)
    return len(data.get("levels", []))


def mark_level_completed(level_number, score):
    print(f"[save_utils] mark_level_completed вызван для уровня {level_number} с очками {score}")
    data = {}
    if os.path.exists(SAVE_FILE):
        with open(SAVE_FILE, "r", encoding="utf-8") as f:
            data = json.load(f)

    completed = data.get("completed_levels", [])
    level_exists = False

    for lvl in completed:
        if lvl["level"] == level_number:
            lvl["score"] = max(lvl["score"], score)
            level_exists = True
            break

    if not level_exists:
        completed.append({"level": level_number, "score": score})

    data["completed_levels"] = completed

    with open(SAVE_FILE, "w", encoding="utf-8") as f:
        json.dump(data, f, indent=2, ensure_ascii=False)

    print(f"[save_utils] Уровень {level_number} сохранён с очками {score}.")

def is_level_completed(level_id):
    return any(lvl["level"] == level_id for lvl in load_completed_levels())

def get_last_unfinished_level():
    """Возвращает последний непройденный уровень.
    Если все уровни пройдены — возвращает максимальный доступный."""
    completed = load_completed_levels()

    if not completed:
        print("[save_utils] Сохранений нет, начинаем с уровня 1.")
        return 1

    max_available = get_max_level()  # ← тянем из levels.json
    completed_levels = {lvl["level"] for lvl in completed}

    # Проверяем от 1 до максимального доступного уровня
    for level in range(1, max_available + 1):
        if level not in completed_levels:
            print(f"[save_utils] Последний непройденный уровень: {level}")
            return level

    # Если всё пройдено — возвращаем последний уровень
    print(f"[save_utils] Все уровни пройдены, возвращаем максимальный: {max_available}")
    return max_available

