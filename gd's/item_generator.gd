# ItemGenerator.gd
class_name ItemGenerator
extends RefCounted

# Веса характеристик (множители баланса для 1 поинта)
const MULTIPLIERS = {
	"hp": 3.0,       # 1 поинт = 3 HP
	"defence": 0.3,  # 1 поинт = 0.2 брони
	"damage": 1.0,   # 1 поинт = 1 урона
	"regen": 0.2     # 1 поинт = 0.2 регенерации
}

# Массивы названий для каждого типа слота из твоего enum SlotType.
# Индексы строго соответствуют порядку: INVENTORY (0), WEAPON (1), HELMET (2), CHEST (3), LEGS (4), ARMS (5), RING (6)
const BASE_NAMES_BY_SLOT = {
	1: ["Меч", "Топор", "Кинжал", "Копье", "Посох"],         # WEAPON
	2: ["Шлем", "Капюшон", "Корона", "Маска"],                # HELMET
	3: ["Нагрудник", "Кираса", "Кольчуга", "Плащ"],          # CHEST
	4: ["Поножи", "Штаны", "Сапоги"],                        # LEGS
	5: ["Перчатки", "Рукавицы", "Наручи"],                    # ARMS
	6: ["Кольцо", "Перстень", "Печатка"]                     # RING
}

## Генерация случайного числа по Гауссу (Box-Muller transform)
static func _rand_gaussian() -> float:
	var u1: float = randf()
	var u2: float = randf()
	if u1 < 0.00001: u1 = 0.00001 
	return sqrt(-2.0 * log(u1)) * cos(2.0 * PI * u2)

## Генерирует абсолютно новый случайный предмет с нуля
static func generate_random_item() -> ItemData:
	var new_item = ItemData.new() # Создаем абсолютно пустой ресурс
	
	# 1. СЛУЧАЙНЫЙ ВЫБОР СЛОТА И ИМЕНИ
	# Выбираем случайный тип слота от 0 до 6 (всего 7 типов в твоем enum)
	var random_slot: int = randi() % 6+1
	new_item.slot_type = random_slot as ItemData.SlotType
	
	# Берем пул названий для этого слота и выбираем случайное
	var names_pool: Array = BASE_NAMES_BY_SLOT[random_slot]
	var base_name: String = names_pool.pick_random()
	
	# 2. РАСЧЕТ БЮДЖЕТА ПО ГАУССУ
	# Считаем силу предмета вокруг ценности лута текущей локации
	var center_luck: float = float(RunManager.current_location_loot_value)
	var gaussian_offset: float = clamp(_rand_gaussian() * 0.7, -2.0, 2.0)
	var final_power: float = max(1.0, center_luck + gaussian_offset)
	
	# Переводим силу в бюджет поинтов (сила 2.0 = 10 поинтов)
	var total_points: int = int(final_power * 14.0)
	
	# 3. РАСПРЕДЕЛЕНИЕ ПОИНТОВ
	var stat_keys = ["hp", "defence", "damage", "regen"]
	var distributed_points = { "hp": 0, "defence": 0, "damage": 0, "regen": 0 }
	
	for i in range(total_points):
		var random_stat = stat_keys.pick_random()
		distributed_points[random_stat] += 1
		
	# 4. ПРИМЕНЕНИЕ СТАТ (Целые числа, округление вниз)
	new_item.bonus_hp = int(floor(distributed_points["hp"] * MULTIPLIERS["hp"]))
	new_item.bonus_defence = int(floor(distributed_points["defence"] * MULTIPLIERS["defence"]))
	new_item.bonus_damage = int(floor(distributed_points["damage"] * MULTIPLIERS["damage"]))
	new_item.bonus_regen = int(floor(distributed_points["regen"] * MULTIPLIERS["regen"]))
	
	# 5. СБОРКА ФИНАЛЬНОГО ТЕКСТОВОГО НАЗВАНИЯ
	new_item.name = base_name 
	
	return new_item
