extends Node
# Глобальный боевой движок для всех сущностей в игре

# 1. ГЛАВНАЯ ФУНКЦИЯ БОЯ: Рассчитывает урон от атакующего и бьет цель
func deal_damage(attacker: Node2D, target: Node2D) -> void:
	if not target:
		return
		
	# Вытаскиваем силу атаки (у игрока берем закэшированную total_attack_power, у мобов — обычную attack_power)
	var raw_atk: int = 0
	if "total_attack_power" in attacker:
		raw_atk = attacker.total_attack_power
	elif "attack_power" in attacker:
		raw_atk = attacker.attack_power
		
	# Считаем случайный разброс урона (от половины до максимума)
	var rolled_damage := randi_range(raw_atk / 2, raw_atk)
	
	# Вызываем глобальную функцию получения урона для цели
	take_damage(target, rolled_damage, attacker)


# 2. ГЛОБАЛЬНАЯ ФУНКЦИЯ ПОЛУЧЕНИЯ УРОНА
func take_damage(target: Node2D, amount: int, attacker: Node2D = null) -> void:
	# Вытаскиваем защиту существа (у игрока — total_defense, у мобов — defense)
	var target_def: int = 0
	if "total_defense" in target:
		target_def = target.total_defense
	elif "defense" in target:
		target_def = target.defense
		
	# Считаем чистый урон с вычетом брони (flat damage reduction, как у вас и было)
	var final_damage = max(0, amount - target_def)
	
	if "current_hp" in target:
		target.current_hp -= final_damage
		
		# Выводим логи в зависимости от того, кто цель
		var target_name = target.data.monster_name if "data" in target and target.data else "Игрок"
		print(target_name, " получил ", final_damage, " урона! Осталось HP: ", target.current_hp)
		
		# Если здоровье упало до нуля — запускаем глобальную смерть
		if target.current_hp <= 0:
			die(target, attacker)


func die(target: Node2D, killer: Node2D = null) -> void:
	# Проверяем, кто именно погиб, чтобы вывести правильное имя в логи
	var target_name = target.data.monster_name if "data" in target and target.data else "Игрок"
	print(target_name, " погиб!")
	
	# === ИНКРУСТИРУЕМ ЛОГИКУ СМЕРТИ ИГРОКА ===
	# Проверяем по имени класса или по кастомному методу/переменной, что погиб ИГРОК
	if target.has_method("absorb_chaos_from") or target.name == "Player": 
		if target.is_inside_tree() and target.get_tree():
			print("Игрок погиб! Обнуляем забег и перезапускаем подземелья...")
			
			# Сбрасываем глобальный менеджер в начальное состояние
			RunManager.reset_run()
			
			# Безопасный отложенный перезапуск сцены в конце кадра
			target.get_tree().call_deferred("reload_current_scene")
			return # Выходим из функции, queue_free() для игрока делать не нужно, сцена сама ре things
	
	# === ЛОГИКА СМЕРТИ МОНСТРОВ (Остается без изменений) ===
	# Если убийца — это игрок, кормим его Хаосом из статов убитого моба
	if killer and killer.has_method("absorb_chaos_from"):
		killer.absorb_chaos_from(target)
		
	# Окончательно удаляем монстра из памяти
	target.queue_free()
