# logic/score.py
class ScoreManager:
    def __init__(self, game_screen):
        self.game_screen = game_screen
        self.score = 0
        self.combo = 0
        self.max_combo = 0
        self.combo_multiplier = 1.0
        self.base_hit_points = 100

        self.total_notes = 0
        self.missed_notes = 0
        self.accuracy = 100.0

    def add_score(self, hit_type="perfect"):

        combo_multiplier = min(4, 1 + (self.combo // 10))
        self.combo_multiplier = combo_multiplier

        self.combo += 1
        self.max_combo = max(self.max_combo, self.combo)

        final_points = int(self.base_hit_points * self.combo_multiplier)
        self.score += final_points

        print(
            f"[ScoreManager] {hit_type} hit! +{self.base_hit_points} -> {final_points} (x{self.combo_multiplier:.1f}) | Комбо: {self.combo} | Всего: {self.score}")
        return final_points

    def reset_combo(self):
        if self.combo > 0:
            print(f"[ScoreManager] Комбо сброшено! Было: {self.combo}")
        self.combo = 0
        self.combo_multiplier = 1.0

    def get_combo_multiplier(self):
        return self.combo_multiplier

    def get_score(self):
        return self.score

    def get_combo(self):
        return self.combo

    def get_max_combo(self):
        return self.max_combo

    def set_total_notes(self, total):
        self.total_notes = total
        self.update_accuracy()

    def update_accuracy(self):
        if self.total_notes == 0:
            self.accuracy = 100.0
        else:
            self.accuracy = max(0, 100 - (self.missed_notes / self.total_notes) * 100)

    def add_perfect_hit(self):
        return self.add_score("perfect")

    def add_good_hit(self):
        return self.add_score("good")

    def add_miss_hit(self):
        self.missed_notes += 1
        self.reset_combo()
        self.update_accuracy()
        print(f"[ScoreManager] Промах! Комбо сброшено, очки не начислены. Точность: {self.accuracy:.2f}%")
        return 0

    def get_accuracy(self):
        return self.accuracy
