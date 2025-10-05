from logic.notes import HoldNote, DefaultNote


class AutoPlayer:
    def __init__(self, game_screen):
        self.game_screen = game_screen
        self.hit_tolerance = 30
        self.pressed_lanes = {}

    def simulate(self):
        if not self.game_screen.debug_menu.is_auto_play_enabled():
            return

        current_time = self.game_screen.game_time * 1000
        min_press_duration = 100

        active_notes = []
        for note in self.game_screen.note_manager.get_notes():
            in_hit_zone = False
            if isinstance(note, HoldNote):
                in_hit_zone = (note.y + note.height >= self.game_screen.hit_zone_y - 10 and
                               note.y <= self.game_screen.hit_zone_y + 30)
            else:
                in_hit_zone = abs(note.y - self.game_screen.hit_zone_y) < self.hit_tolerance

            if in_hit_zone:
                active_notes.append((note.lane, note))

        lanes_to_keep_pressed = set()

        for lane, note in active_notes:
            lanes_to_keep_pressed.add(lane)

            if lane not in self.pressed_lanes:
                self.pressed_lanes[lane] = {
                    'time': current_time,
                    'type': 'hold' if isinstance(note, HoldNote) else 'tap'
                }
                self.game_screen.player.lanes_state[lane] = True
                self.game_screen.check_hit(lane)
                self.game_screen.player.lane_pressed_changed.emit()
            else:
                self.pressed_lanes[lane]['time'] = current_time
                if isinstance(note, HoldNote):
                    note.is_being_held = True

        lanes_to_release = []
        for lane, press_info in self.pressed_lanes.items():
            if lane not in lanes_to_keep_pressed:
                time_held = current_time - press_info['time']
                if time_held >= min_press_duration:
                    lanes_to_release.append(lane)

        for lane in lanes_to_release:
            press_info = self.pressed_lanes.pop(lane)
            self.game_screen.player.lanes_state[lane] = False

            for note in self.game_screen.note_manager.get_notes():
                if isinstance(note, HoldNote) and note.lane == lane:
                    note.is_being_held = False

            self.game_screen.player.lane_pressed_changed.emit()

    def reset(self):
        self.pressed_lanes.clear()
        for i in range(len(self.game_screen.player.lanes_state)):
            self.game_screen.player.lanes_state[i] = False
        self.game_screen.player.lane_pressed_changed.emit()