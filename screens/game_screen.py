# screens/game_screen.py
from PyQt5.QtGui import QPainter, QColor, QFont
from PyQt5.QtWidgets import QWidget
from PyQt5.QtCore import Qt, QTimer, QRect, QElapsedTimer
import json
from pathlib import Path
import math

from logic.bot import AutoPlayer
from logic.debug_menu import DebugMenu
from logic.game_render import GameRenderer
from logic.note_manager import NoteManager
from logic.player import Player
from logic.score import ScoreManager
from logic.notes import DefaultNote, HoldNote


class GameScreen(QWidget):
    def __init__(self, parent=None, start_level=1, selected_song=None):
        super().__init__(parent)
        self.start_level = start_level
        self.selected_song = selected_song
        self.setFixedSize(1920, 1080)
        self.setFocusPolicy(Qt.StrongFocus)

        self.lanes = 4

        self.lane_width = self.width() // self.lanes
        self.hit_zone_y = 900

        self.score_manager = ScoreManager(self)
        self.debug_menu = DebugMenu(self)
        self.debug_menu.hide()
        self.bpm = 120
        self.speed = 6
        self.update_speed_from_bpm()

        self.auto_player = AutoPlayer(self)

        self._is_being_deleted = False

        self.game_timer = QElapsedTimer()
        self.game_start_time = 0.0
        self.game_time = 0.0
        self.audio_offset = 2.4  
        self.calibration_offset = 0.0
        self.total_audio_offset = self.audio_offset + self.calibration_offset

        self.game_finished = False

        self.game_engine = parent
        print(f"[GameScreen] game_engine: {self.game_engine is not None}")
        print(
            f"[GameScreen] game_engine.music_manager: {hasattr(self.game_engine, 'music_manager') if self.game_engine else False}")
        print(
            f"[GameScreen] game_engine.player_data_manager: {hasattr(self.game_engine, 'player_data_manager') if self.game_engine else False}")
        self.music_manager = None
        if hasattr(self.game_engine, "music_manager"):
            
            player_data_manager = getattr(self.game_engine, "player_data_manager", None)
            self.game_engine.music_manager.player_data_manager = player_data_manager
            self.music_manager = self.game_engine.music_manager

        settings_for_player = self.game_engine.settings if self.game_engine else None
        self.player = Player(parent=self, settings=settings_for_player)

        self.player.note_hit.connect(self.on_player_hit)
        self.player.lane_pressed_changed.connect(self.update)

        self.timer = QTimer(self)
        self.timer.timeout.connect(self.update_game)
        self.timer.setInterval(16)

        self.countdown_timer = QTimer(self)
        self.countdown_timer.timeout.connect(self.update_countdown)
        self.countdown_remaining = 5
        self.countdown_active = False

        self.selected_song_path = self.selected_song.get("path") if self.selected_song else None
        self.skip_used = False
        self.skip_time_threshold = 10.0
        self.time_offset = 0.0  
        self.skip_target_time = 0.0  
        self.renderer = GameRenderer(self)

        
        self.note_manager = NoteManager(self)

    def calibrate_offset(self, offset_adjustment):
        self.calibration_offset += offset_adjustment
        self.total_audio_offset = self.audio_offset + self.calibration_offset
        print(
            f"[GameScreen] Оффсет калиброван: base={self.audio_offset}, cal={self.calibration_offset}, total={self.total_audio_offset:.3f}")

    def reset_hit_sound_chain(self):
        if self.music_manager:
            self.music_manager.reset_hit_sound_state()

    def start_game(self):
        if hasattr(self.game_engine, "music_manager"):
            self.game_engine.music_manager.stop_music()

        self.reset_hit_sound_chain()
        print(f"[GameScreen] Перед reset_hit_sound_chain, music_manager: {self.music_manager is not None}")
        self.note_manager.clear_notes()
        self.score_manager.reset_combo()
        self.score_manager.score = 0
        self.score_manager.missed_notes = 0
        self.score_manager.accuracy = 100.0
        self.game_finished = False

        if self.selected_song:
            self.note_manager.load_notes_from_file(self.selected_song)
            if "bpm" in self.selected_song:
                self.bpm = self.selected_song["bpm"]
                self.update_speed_from_bpm()
            print(f"[GameScreen] Игра стартовала с песней: {self.selected_song.get('title', 'Unknown')}")

            self.score_manager.set_total_notes(self.note_manager.get_spawn_queue_size())

            self.start_countdown()
        else:
            print("[GameScreen] Игра стартовала (без песни).")
            self.setFocusPolicy(Qt.StrongFocus)
            self.grabKeyboard()
            self.timer.start(16)

        if hasattr(self, 'player') and self.player:
            self.player.deleteLater()
        settings_to_use = self.game_engine.settings if self.game_engine else None
        self.player = Player(parent=self, settings=settings_to_use)
        self.player.note_hit.connect(self.on_player_hit)
        self.player.lane_pressed_changed.connect(self.update)

    def start_countdown(self):
        print(f"[GameScreen] Начало отсчета: {self.countdown_remaining} секунд")
        self.countdown_active = True
        self.game_time = -self.countdown_remaining
        self.countdown_timer.start(1000)

        self.setFocusPolicy(Qt.StrongFocus)
        self.grabKeyboard()
        self.timer.start(16)

    def update_countdown(self):
        self.countdown_remaining -= 1
        print(f"[GameScreen] Отсчет: {self.countdown_remaining}")

        if self.countdown_remaining <= 0:
            self.countdown_timer.stop()
            self.countdown_active = False
            self.game_time = 0.0
            print("[GameScreen] Отсчет завершен, запуск музыки и игры.")
            self.start_audio()

    def start_audio(self):
        if not self.selected_song_path:
            print("[GameScreen] Нет пути к песне для воспроизведения.")
            return

        if not Path(self.selected_song_path).exists():
            print(f"[GameScreen] Файл не существует: {self.selected_song_path}")
            return

        self.note_manager.load_notes_from_file(self.selected_song)

        first_note_time = float('inf')
        if self.note_manager.note_spawn_queue:
            first_note_time = self.note_manager.note_spawn_queue[0].get("time", float('inf'))

        if first_note_time != float('inf') and first_note_time > 5.0:
            self.skip_target_time = max(0.0, first_note_time - 5.0)
        else:
            self.skip_target_time = 0.0

        print(f"[GameScreen] Первая нота в: {first_note_time}s, пропуск до: {self.skip_target_time}s")

        if hasattr(self.game_engine, "music_manager"):
            if self.timer.isActive():
                self.timer.stop()

            self.game_timer.restart()
            self.game_start_time = 0.0
            self.game_time = 0.0

            print(f"[GameScreen] QElapsedTimer запущен. game_start_time: {self.game_start_time:.3f}")

            success = self.game_engine.music_manager.play_game_music(self.selected_song_path)

            if success:
                print(f"[GameScreen] Воспроизведение запущено: {self.selected_song_path}")
                QTimer.singleShot(50, self._sync_audio_and_game_time)

                self.check_song_end_timer = QTimer(self)
                self.check_song_end_timer.timeout.connect(self.check_song_end)
                self.check_song_end_timer.start(100)

                self.timer.start()

            else:
                print(f"[GameScreen] Ошибка запуска аудио: {self.selected_song_path}")
        else:
            print("[GameScreen] MusicManager не найден!")

    def _sync_audio_and_game_time(self):
        if hasattr(self.game_engine, "music_manager"):
            
            if not self.game_engine.music_manager.is_game_music_playing():
                print("[GameScreen] Аудио ещё не запущено, откладываем синхронизацию...")
                QTimer.singleShot(10, self._sync_audio_and_game_time)
                return

        
        elapsed = self.game_timer.elapsed() / 1000.0
        
        self.game_start_time = elapsed - self.total_audio_offset
        print(f"[GameScreen] Аудио запущено, синхронизация времени: game_start_time = {self.game_start_time:.3f}")

    def check_song_end(self):
        if self.selected_song_path:
            try:
                import mutagen
                audio_file = mutagen.File(self.selected_song_path)
                duration = audio_file.info.length

                if self.game_time >= duration - 0.1:
                    self.end_game()
            except Exception as e:
                print(f"[DEBUG] Ошибка проверки окончания песни: {e}")
                if hasattr(self.game_engine, "music_manager"):
                    if not self.game_engine.music_manager.is_game_music_playing():
                        self.end_game()

    def end_game(self):
        if self.game_finished:
            return

        print(f"[GameScreen] Игра завершена в {self.game_time:.3f}с, переход к экрану победы...")
        self.game_finished = True

        if self.timer.isActive():
            self.timer.stop()
        if self.countdown_timer.isActive():
            self.countdown_timer.stop()
        if hasattr(self, 'check_song_end_timer') and self.check_song_end_timer.isActive():
            self.check_song_end_timer.stop()

        if hasattr(self, 'auto_player'):
            self.auto_player.reset()

        from logic.transitions import transition_open_victory_screen
        transition_open_victory_screen(
            self.game_engine,
            self.score_manager.get_score(),
            self.score_manager.get_combo(),
            self.score_manager.get_max_combo(),
            self.selected_song
        )

    def update_speed_from_bpm(self):
        base_bpm = 120
        base_speed = 6
        self.speed = base_speed * (self.bpm / base_bpm)
        self.speed = max(2, min(12, self.speed))
        print(f"[GameScreen] Скорость обновлена: BPM={self.bpm}, Speed={self.speed:.2f}")

    def on_player_hit(self, lane):
        self.check_hit(lane)

    def check_hit(self, lane):
        if self.game_finished or getattr(self, '_is_being_deleted', False):
            return

        hit_occurred = False
        current_time = self.game_time

        for note in self.note_manager.get_notes():
            if note.lane == lane and abs(note.y - self.hit_zone_y) < 30:
                try:
                    
                    
                    
                    
                    initial_y = -20  
                    speed = self.speed * (1000 / 16)  
                    expected_time_at_hit_zone = note.time + (self.hit_zone_y - initial_y) / speed

                    time_diff = abs(current_time - expected_time_at_hit_zone)
                    print(
                        f"HIT at {current_time:.3f}s, note expected at hit zone at {expected_time_at_hit_zone:.3f}s, diff: {time_diff:.3f}s")

                    points = note.on_hit()
                    if self.music_manager:
                        self.music_manager.play_hit_sound()
                    self.score_manager.add_perfect_hit()
                    print(f"PERFECT HIT lane {lane} | Combo: {self.score_manager.get_combo()}")
                    hit_occurred = True
                except Exception as e:
                    print(f"[ERROR] Ошибка при обработке хита ноты: {e}")
                    if note in self.note_manager.get_notes():
                        self.note_manager.get_notes().remove(note)

        if not hit_occurred:
            self.score_manager.reset_combo()
            print(f"MISSED HIT lane {lane} | Combo сброшен")

    def update_game(self):
        if self.game_finished or getattr(self, '_is_being_deleted', False):
            return

        if not self.countdown_active and self.game_timer.isValid():
            
            elapsed_time = self.game_timer.elapsed() / 1000.0
            
            self.game_time = self.game_start_time + elapsed_time + self.total_audio_offset

        if not self.countdown_active:
            self.note_manager.spawn_notes()

        self.auto_player.simulate()

        self.note_manager.update_notes()

        self.update()

    def skip_intro(self):
        if self.skip_used:
            print("[GameScreen] Пропуск уже был использован.")
            return

        if not self.note_manager.note_spawn_queue:
            print("[GameScreen] Ноты не загружены — нечего проматывать.")
            return

        first_note_time = self.note_manager.note_spawn_queue[0].get("time", 0)
        if first_note_time < self.skip_time_threshold:
            print(f"[GameScreen] Первая нота слишком близко ({first_note_time:.2f}с) — пропуск не требуется.")
            return

        target_time = max(0.0, first_note_time - 5.0)
        print(f"[GameScreen] Промотка песни до {target_time:.2f}с...")
        self.skip_used = True

        self.note_manager.note_spawn_queue = [
            n for n in self.note_manager.note_spawn_queue if n.get("time", 0) >= target_time
        ]

        if hasattr(self.game_engine, "music_manager"):
            success = self.game_engine.music_manager.set_music_position(target_time)
            if success:
                print(f"[GameScreen] Позиция аудио установлена на {target_time:.2f}с")
            else:
                print(f"[GameScreen] Не удалось установить позицию аудио")

        self.game_time = target_time
        self.game_start_time = target_time - self.total_audio_offset - (self.game_timer.elapsed() / 1000.0)

        print(f"[GameScreen] Установлено новое игровое время: {self.game_time:.3f}s")
        print(f"[GameScreen] Общий оффсет: {self.total_audio_offset:.3f}s, время начала: {self.game_start_time:.3f}s")

    def keyPressEvent(self, event):
        if self.game_finished:
            return

        
        if self.countdown_active:
            print("[GameScreen] Пропуск недоступен во время отсчёта.")
            return

        
        if event.key() == Qt.Key_PageUp:  
            self.calibrate_offset(-0.01)
            return
        elif event.key() == Qt.Key_PageDown:  
            self.calibrate_offset(0.01)
            return
        elif event.key() == Qt.Key_Home:  
            self.calibration_offset = 0.0
            self.total_audio_offset = self.audio_offset + self.calibration_offset
            print(f"[GameScreen] Оффсет сброшен: {self.total_audio_offset:.3f}")
            return

        if event.key() == Qt.Key_Space:
            self.skip_intro()
            return

        if event.key() == Qt.Key_AsciiTilde:
            self.debug_menu.toggle_visibility()

        if event.key() == Qt.Key_Escape:
            if hasattr(self.game_engine, "transitions"):
                self.game_engine.transitions.close_game()
            return

        self.player.keyPressEvent(event)
        super().keyPressEvent(event)

    def keyReleaseEvent(self, event):
        if self.game_finished:
            return

        self.player.keyReleaseEvent(event)
        lane = self.player.keymap.get(event.key())
        if lane is not None:
            for note in self.note_manager.get_notes():
                if isinstance(note, HoldNote) and note.lane == lane:
                    note.is_being_held = False
                    print(f"HOLD lane {lane} отпущена")
        super().keyReleaseEvent(event)

    def closeEvent(self, event):
        print("[GameScreen] closeEvent вызван.")
        if self.timer.isActive():
            self.timer.stop()
        if self.countdown_timer.isActive():
            self.countdown_timer.stop()
        if hasattr(self, 'check_song_end_timer') and self.check_song_end_timer.isActive():
            self.check_song_end_timer.stop()

        if hasattr(self, 'debug_menu'):
            self.debug_menu.hide()

        if hasattr(self.game_engine, "music_manager"):
            self.game_engine.music_manager.stop_game_music()

        for note in self.note_manager.get_notes():
            note.active = False
        self.note_manager.clear_notes()
        self.player = None

        event.accept()

    def paintEvent(self, event):
        self.renderer.render(event)