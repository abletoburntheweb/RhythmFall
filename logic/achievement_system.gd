# logic/achievement_system.gd
class_name AchievementSystem
extends RefCounted

var achievement_manager: AchievementManager = null
var player_data_manager: PlayerDataManager = null
var music_manager: MusicManager = null

func _init(ach_manager: AchievementManager, pd_manager: PlayerDataManager, music_mgr: MusicManager):
	achievement_manager = ach_manager
	player_data_manager = pd_manager
	music_manager = music_mgr
	
	# Связываем обратно для обратной совместимости
	achievement_manager.player_data_mgr = pd_manager
	achievement_manager.music_mgr = music_mgr
	player_data_manager.achievement_manager = ach_manager

# Единый метод для проверки завершения уровня
func on_level_completed(accuracy: float):
	print("[AchievementSystem] on_level_completed вызван с accuracy: ", accuracy)
	achievement_manager.check_first_level_achievement()
	achievement_manager.check_perfect_accuracy_achievement(accuracy)
	# Обновляем levels_completed через player_data_manager
	player_data_manager.add_completed_level() # Этот метод увеличивает счётчик
	# Теперь получаем обновлённое значение и проверяем ачивки уровней
	var total_levels_completed = player_data_manager.get_levels_completed() # Получаем новое значение
	achievement_manager.check_levels_completed_achievement(total_levels_completed)
	achievement_manager.save_achievements() # Сохраняем после проверки

# Единый метод для проверки покупки
func on_purchase_made():
	var total_purchases = player_data_manager.get_items().size()
	achievement_manager.check_purchase_count(total_purchases)
	# Явно передаём player_data_manager в методы, которые зависят от него
	achievement_manager.check_style_hunter_achievement(player_data_manager)
	achievement_manager.check_collection_completed_achievement(player_data_manager)
	achievement_manager.save_achievements() # Сохраняем после проверки

# Единый метод для проверки валюты
func on_currency_changed():
	var total_earned = player_data_manager.data.get("total_earned_currency", 0)
	var total_spent = player_data_manager.data.get("spent_currency", 0)
	achievement_manager.check_currency_achievements(player_data_manager) # Передаём override
	achievement_manager.check_spent_currency_achievement(total_spent)
	achievement_manager.save_achievements() # Сохраняем после проверки

# Единый метод для проверки входа
func on_daily_login():
	var login_streak = player_data_manager.get_login_streak()
	achievement_manager.check_daily_login_achievements(player_data_manager) # Передаём override
	achievement_manager.save_achievements() # Сохраняем после проверки
