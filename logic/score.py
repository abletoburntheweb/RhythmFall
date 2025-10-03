# logic/score.py
class ScoreManager:
    def __init__(self, game_screen):
        self.game_screen = game_screen
        self.score = 0
        self.combo = 0
        self.max_combo = 0
        self.combo_multiplier = 1.0
        self.base_hit_points = 100

    def add_score(self, hit_type="perfect"):

        combo_multiplier = min(4, 1 + (self.combo // 10))
        self.combo_multiplier = combo_multiplier

        self.combo += 1
        self.max_combo = max(self.max_combo, self.combo)

        final_points = int(self.base_hit_points * self.combo_multiplier)
        self.score += final_points

        print(
            f"[ScoreManager] {hit_type} hit! +{self.base_hit_points} -> {final_points} (x{self.combo_multiplier:.1f}) | Combo: {self.combo} | Total: {self.score}")
        return final_points

    def reset_combo(self):
        if self.combo > 0:
            print(f"[ScoreManager] Combo сброшено! Было: {self.combo}")
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

    def add_perfect_hit(self):
        return self.add_score("perfect")

    def add_good_hit(self):
        return self.add_score("good")

    def add_miss_hit(self):
        self.reset_combo()
        print(f"[ScoreManager] Miss! Combo сброшен, очки не начислены")
        return 0