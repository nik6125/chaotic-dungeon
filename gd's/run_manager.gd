extends Node
# Глобальные параметры текущего этажа, которые сгенерировал кубик
var current_location_difficulty: int = 1
var current_location_loot_value: int = 1
# Номер текущего измерения/портала
var current_dimension_floor: int = 1
# Функция кидает кубик на сложность и ценность при переходе в портал
func roll_next_dimension() -> void:
	current_dimension_floor += 1
		# Простейшая базовая формула: сложность растет, но имеет случайный разброс
	current_location_difficulty = current_dimension_floor + randi_range(-1, 2)
	current_location_difficulty = max(1, current_location_difficulty) # Защита от нуля
		# Ценность лута генерируется отдельно! 
	# Может выпасть "бедная", но сложная локация, или "богатая", но легкая.
	current_location_loot_value = current_dimension_floor + randi_range(-2, 2)
	current_location_loot_value = max(1, current_location_loot_value)
	# СЛУЧАЙНЫЙ ВЫБОР МИРА:
	var random_index = randi() % GENERATORS.size()
	current_generator = GENERATORS[random_index]

const GENERATORS = [
	preload("res://tres's/generators/dungeon_generator.tres"),
	preload("res://tres's/generators/forest_generator.tres")
]

# Сюда игра будет записывать то, что выпало на текущем этаже
var current_biome: LocationData
var current_generator: LocationGenerator

func _ready() -> void:
	# При первом старте игры выбираем стартовый биом (например, самый первый в списке — Dungeon)
	current_generator = GENERATORS[0]

func reset_run() -> void:
	current_dimension_floor = 1
	current_location_difficulty = 1
	current_location_loot_value = 1
	current_generator = GENERATORS[0]
