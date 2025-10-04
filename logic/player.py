from PyQt5.QtCore import QObject, pyqtSignal, Qt

from logic.notes import HoldNote


class Player(QObject):
    note_hit = pyqtSignal(int)
    lane_pressed_changed = pyqtSignal()

    def __init__(self, parent=None):
        super().__init__(parent)
        self.keymap = {
            Qt.Key_A: 0,
            Qt.Key_S: 1,
            Qt.Key_D: 2,
            Qt.Key_F: 3,
        }
        self.lanes_state = [False, False, False, False]

    def keyPressEvent(self, event):
        if event.key() in self.keymap:
            lane = self.keymap[event.key()]
            if not self.lanes_state[lane]:
                self.lanes_state[lane] = True
                self.note_hit.emit(lane)
                self.lane_pressed_changed.emit()

    def keyReleaseEvent(self, event):
        if event.key() in self.keymap:
            lane = self.keymap[event.key()]
            self.lanes_state[lane] = False
            self.lane_pressed_changed.emit()
