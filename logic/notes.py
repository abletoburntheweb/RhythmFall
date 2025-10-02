# logic/notes.py
class BaseNote:
    def __init__(self, lane, y=0, height=20):
        self.lane = lane
        self.y = y
        self.height = height
        self.active = True

    def update(self, speed=6):
        self.y += speed
        if self.y > 1080:
            self.active = False

    def on_hit(self):
        self.active = False
        return 100


class DefaultNote(BaseNote):
    pass


class HoldNote(BaseNote):
    def __init__(self, lane, y=0, length=150, hold_time=1000):
        super().__init__(lane, y, height=length)
        self.hold_time = hold_time
        self.held_time = 0
        self.hit_progress = 0.0
        self.is_being_held = False
        self.captured = False
        self.fall_speed = 6

    def update(self, speed=None, delta_ms=16):
        current_fall_speed = speed if speed is not None else self.fall_speed

        if self.is_being_held and not self.captured:
            self.held_time += delta_ms
            self.hit_progress = min(self.held_time / self.hold_time, 1.0)

            if self.hit_progress >= 1.0:
                self.captured = True
                self.active = False
        else:
            self.y += current_fall_speed

        if self.y > 1080 and not self.captured:
            self.active = False

    def on_hit(self):

        if not self.is_being_held and not self.captured:
             self.active = False
        return 100