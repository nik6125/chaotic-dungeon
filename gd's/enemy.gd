extends Node2D
@warning_ignore("integer_division")
@export var vision_range: int = 2
var grid_pos: Vector2i

# --- БАЗОВЫЕ ХАРАКТЕРИСТИКИ (для 1-го этажа) ---
var base_max_hp: int = 50
var base_attack_power: int = 6
var base_regen: int = 0
var base_defense: int = 0
var base_chaos:int = 30
# --- АКТУАЛЬНЫЕ ХАРАКТЕРИСТИКИ ТЕКУЩЕЙ ОСОБИ ---
var max_hp: int
var current_hp: int 
var attack_power: int
var regen: int
var defense: int
var chaos:int
# Функция, которая вызывается ГЛАВНЫМ СКРИПТОМ сразу после спавна
func initialize_stats(difficulty: int) -> void:
	# Рассчитываем здоровье: +10 ОЗ за каждый этаж после первого
	max_hp = randi_range((base_max_hp + (difficulty - 1) * 30)/2,base_max_hp + (difficulty - 1) * 30)
	current_hp = max_hp
	defense = randi_range(base_defense,base_defense+(difficulty-1)*2)
	attack_power = base_attack_power + (difficulty - 1) * 2
	regen = randi_range((difficulty - 1),(base_regen + (difficulty - 1) * 2))
	chaos = randi_range((base_chaos+(difficulty-3)*5),(base_chaos+difficulty*5))
func take_damage(amount: int) -> bool: # Меняем тип возвращаемого значения на bool
	current_hp -= max(0,(amount-defense))
	print("Враг получил ", amount, " урона! Осталось HP: ", current_hp)
	if current_hp <= 0:
		print("Враг погиб!")
		queue_free()
		return true # Сигнализируем, что враг мертв
	return false # Враг еще жив

# Функция решает, куда идти
func get_next_move_direction(player_grid_pos: Vector2i) -> Vector2i:
	# Считаем расстояние до игрока по осям
	var dx = player_grid_pos.x - grid_pos.x
	var dy = player_grid_pos.y - grid_pos.y
	
	# Проверяем, входит ли игрок в зону видимости (5x5)
	if abs(dx) <= vision_range and abs(dy) <= vision_range:
		# ИГРОК ЗАМЕЧЕН: Преследуем его (твой прошлый код)
		var direction = Vector2i.ZERO
		if abs(dx) > abs(dy):
			direction.x = sign(dx)
		elif abs(dy) > 0:
			direction.y = sign(dy)
		return direction
	else:
		# ИГРОК НЕ ЗАМЕЧЕН: Выбираем случайное направление (включая "стоять на месте")
		var directions = [
			Vector2i(0, 0),   # Стоять на месте
			Vector2i(1, 0),   # Вправо
			Vector2i(-1, 0),  # Влево
			Vector2i(0, 1),   # Вниз
			Vector2i(0, -1)   # Вверх
		]
		return directions.pick_random()
