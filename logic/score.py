class ScoreManager:
    def __init__(self, game_screen):
        self.game_screen = game_screen
        self.score = 0

    def add_score(self, points):
        self.score += points
        print(f"[ScoreManager] Добавлено {points} очков, всего: {self.score}")
        return self.score

    def get_score(self):
        return self.score
