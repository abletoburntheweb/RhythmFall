# logic/player.py
from PyQt5.QtCore import QObject, pyqtSignal, Qt
from logic.notes import HoldNote


class Player(QObject):
    note_hit = pyqtSignal(int)
    lane_pressed_changed = pyqtSignal()

    def __init__(self, parent=None, settings=None):
        super().__init__(parent)
        self.settings = settings
        self.keymap = self.load_keymap_from_settings()
        self.key_to_lane = {key: lane for key, lane in self.keymap.items()}
        self.lanes_state = [False] * len(self.keymap)

    def load_keymap_from_settings(self):
        default_keymap = {
            Qt.Key_A: 0,
            Qt.Key_S: 1,
            Qt.Key_D: 2,
            Qt.Key_F: 3,
        }
        if self.settings:
            settings_keymap = self.settings.get("controls_keymap", {})
            if settings_keymap:
                loaded_keymap = {}
                for lane_str, key_int in settings_keymap.items():
                    lane = int(lane_str.replace("lane_", "").replace("_key", ""))
                    loaded_keymap[key_int] = lane
                if len(loaded_keymap) == 4 and len(set(loaded_keymap.values())) == 4:
                    print(f"[Player] Загружен маппинг клавиш: {loaded_keymap}")
                    return loaded_keymap
                else:
                    print(f"[Player] Невалидный маппинг клавиш в настройках: {settings_keymap}. Используем стандартный.")
                    return default_keymap
        print("[Player] Маппинг клавиш не найден в настройках. Используем стандартный.")
        return default_keymap

    def set_keymap(self, new_keymap):
        self.keymap = new_keymap
        self.key_to_lane = {key: lane for key, lane in self.keymap.items()}
        self.lanes_state = [False] * len(self.keymap)

    def get_current_keys_as_text(self):
        from PyQt5.QtGui import QKeySequence
        sorted_items = sorted(self.keymap.items(), key=lambda item: item[1])
        return [f"Scan:{key}" for key, lane in sorted_items] 

    def keyPressEvent(self, event):
        key = event.nativeScanCode()
        if key in self.keymap:
            lane = self.keymap[key]
            if 0 <= lane < len(self.lanes_state) and not self.lanes_state[lane]:
                self.lanes_state[lane] = True
                self.note_hit.emit(lane)
                self.lane_pressed_changed.emit()

    def keyReleaseEvent(self, event):
        key = event.nativeScanCode()
        if key in self.keymap:
            lane = self.keymap[key]
            if 0 <= lane < len(self.lanes_state):
                self.lanes_state[lane] = False
                self.lane_pressed_changed.emit()
