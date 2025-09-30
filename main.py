import sys
from PyQt5.QtWidgets import QApplication
from logic.game_logic import GameEngine

if __name__ == "__main__":
    try:
        print("Инициализация QApplication...")
        app = QApplication(sys.argv)
        print("Создание экземпляра GameEngine...")
        game = GameEngine()
        print("Запуск цикла событий...")
        game.setFixedSize(1920, 1080)
        game.move(0,0)
        game.setWindowTitle("BOLLS")
        sys.exit(app.exec_())
    except Exception as e:
        print(f"Ошибка: {e}")