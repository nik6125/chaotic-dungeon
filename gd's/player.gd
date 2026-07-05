extends Node2D
@onready var sprite: Sprite2D = $sprite
signal movement_requested(direction: Vector2i)

# --- ХАРАКТЕРИСТИКИ ИГРОКА ---
@export var max_chaos_energy: int = 100
@export var current_chaos_energy: int = 100
@export var max_hp: int = 100
@export var current_hp: int = 100
@export var attack_power: int = 10
@export var defense: int = 0
@export var regen: int = 1
@export var chaos_consumption: int = 1

# Слоты для надетого снаряжения (хранят объекты нашего ItemData)
var equipped_weapon: ItemData = null
var equipped_helmet: ItemData = null
var equipped_chest: ItemData = null
var equipped_legs: ItemData = null
var equipped_arms: ItemData = null
var equipped_rings: Array[ItemData] = [] # Бесконечный список колец!
# Общий список предметов в рюкзаке
var inventory_list: Array[ItemData] = []


func _unhandled_input(event: InputEvent) -> void:
	# Если состояние игры НЕ соответствует контролю игрока, полностью блокируем ввод
	if GlobalSignals.current_state != GlobalSignals.GameState.CONTROL_PLAYER:
		# Если открыт инвентарь, поглощаем ввод для стабильности UI
		if GlobalSignals.current_state == GlobalSignals.GameState.INVENTORY:
			get_viewport().set_input_as_handled()
		return

	var direction = Vector2i.ZERO	
	if event.is_action_pressed("ui_right"):
		direction.x = 1
	elif event.is_action_pressed("ui_left"):
		direction.x = -1
	elif event.is_action_pressed("ui_down"):
		direction.y = 1
	elif event.is_action_pressed("ui_up"):
		direction.y = -1
	elif event.is_action_pressed("ui_accept"): 
		movement_requested.emit(Vector2i.ZERO)
		return
		
	if direction != Vector2i.ZERO:
		movement_requested.emit(direction)


# Функция получения урона
func take_damage(amount: int) -> void:
	# Вычитаем динамическую общую защиту (базовая + шмотки + кольца) из входящего урона
	var final_damage = max(0, amount - get_total_defence())
	current_hp -= final_damage
	print("Игрок получил ", final_damage, " урона! Текущее HP: ", current_hp, "/", max_hp)
	
	if current_hp <= 0:
		die()


func die() -> void:
	if is_inside_tree() and get_tree():
		print("Игрок погиб! Обнуляем забег и перезапускаем подземелья...")
		
		# Сбрасываем глобальный менеджер в начальное состояние
		RunManager.reset_run()
		
		# Безопасный отложенный перезапуск сцены в конце кадра
		get_tree().call_deferred("reload_current_scene")

@warning_ignore("shadowed_variable")
func consume_chaos_energy(chaos_consumption) -> void:
	if current_chaos_energy > 0:
		current_chaos_energy -= chaos_consumption
	if current_chaos_energy <= 0:
		current_chaos_energy = 0
		take_chaos_damage(chaos_consumption)
		print("Хаос истощен! Вы теряете здоровье!")


func take_chaos_damage(amount) -> void:
	current_hp-=amount
	if current_hp <= 0:
		die()
# Универсальная функция, которая считает общую защиту с учетом всех надетых вещей
# Универсальная функция для подсчета общей защиты
func get_total_defence() -> int:
	var total = defense # Базовая защита рыцаря
	if equipped_helmet: total += equipped_helmet.bonus_defence
	if equipped_chest: total += equipped_chest.bonus_defence
	if equipped_legs: total += equipped_legs.bonus_defence
	if equipped_arms: total += equipped_arms.bonus_defence
	for ring in equipped_rings:
		total += ring.bonus_defence
	return total

# Динамический подсчет максимального здоровья (базовое + бонусы шмоток)
func get_total_max_hp() -> int:
	var total = max_hp
	if equipped_helmet: total += equipped_helmet.bonus_hp
	if equipped_chest: total += equipped_chest.bonus_hp
	if equipped_legs: total += equipped_legs.bonus_hp
	if equipped_arms: total += equipped_arms.bonus_hp
	for ring in equipped_rings:
		total += ring.bonus_hp
	return total

# Динамический подсчет силы атаки (базовая + урон от оружия и колец)
func get_total_attack_power() -> int:
	var total = attack_power
	if equipped_weapon: total += equipped_weapon.bonus_damage
	if equipped_helmet: total += equipped_helmet.bonus_damage
	if equipped_chest: total += equipped_chest.bonus_damage
	if equipped_legs: total += equipped_legs.bonus_damage
	if equipped_arms: total += equipped_arms.bonus_damage
	for ring in equipped_rings:
		total += ring.bonus_damage
	return total

# Динамический подсчет регенерации
# Динамический подсчет регенерации (базовая + шмотки + кольца)
func get_total_regen() -> int:
	var total = regen # Базовая регенерация (1)
	if equipped_helmet: total += equipped_helmet.bonus_regen
	if equipped_chest: total += equipped_chest.bonus_regen
	if equipped_legs: total += equipped_legs.bonus_regen
	if equipped_arms: total += equipped_arms.bonus_regen
	for ring in equipped_rings:
		total += ring.bonus_regen
	return total
