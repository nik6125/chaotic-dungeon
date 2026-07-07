extends Node2D
@warning_ignore("integer_division")

@export var vision_range: int = 2
var grid_pos: Vector2i
var sprite: Sprite2D = null

func _ready() -> void:
	# Ищем узел "Sprite" аккуратно. Если он ещё не готов, игра не будет ругаться красным
	sprite = get_node_or_null("Sprite") as Sprite2D
# Сюда SpawnManager передаст конкретный .tres ресурс монстра со всеми его базовыми кубами и статами
var data: MonsterData

# --- АКТУАЛЬНЫЕ ХАРАКТЕРИСТИКИ ТЕКУЩЕЙ ОСОБИ ---
var max_hp: int
var current_hp: int 
var attack_power: int
var regen: int
var defense: int
var chaos: int
# Функция, которая вызывается ГЛАВНЫМ СКРИПТОМ сразу после спавна
# Вызывается из SpawnManager. Передаем итоговый Гауссов бафф этажа
func initialize_stats(difficulty: int) -> void:
	if not data:
		push_error("Enemy: Ресурс MonsterData не передан!")
		return
		
	# МЕНЯЕМ СЛУЧАЙНЫЙ СПРАЙТ НА ЛЕТУ:
	if sprite and data.icon:
		sprite.texture = data.icon
	var stat_multiplier: float = pow(float(difficulty),1.25)
	
	# 1. ЗДОРОВЬЕ (D&D стиль: разброс от базового HP монстра)
	# Берем базовое HP из ресурса, умножаем на корень сложности и даем случайный разброс особи (+-20%)
	var calculated_hp: float = data.base_max_hp * stat_multiplier
	max_hp = randi_range(int(calculated_hp * 0.5), int(calculated_hp * 1.5))
	max_hp = max(1, max_hp) # Защита от нуля
	current_hp = max_hp
	
	# 2. ЗАЩИТА (Броня)
	# Базовая защита монстра + небольшая прибавка от сложности
	defense = randi_range(data.base_defense, int(data.base_defense * stat_multiplier))
	
	# 3. АТАКА
	# Базовая атака умножается на наш плавный множитель
	attack_power = randi_range(data.base_attack_power, int(data.base_attack_power * stat_multiplier))
	
	# 4. РЕГЕНЕРАЦИЯ И ХАОС
	regen = randi_range(data.base_regen, data.base_regen + int(difficulty * 0.3))
	
	# Хаос считает разброс вокруг базового значения хаоса монстра
	var min_chaos = data.base_chaos + (difficulty - 3) * 5
	var max_chaos = data.base_chaos + difficulty * 5
	chaos = randi_range(min(min_chaos, max_chaos), max(min_chaos, max_chaos))

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
