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

# --- КЭШИРОВАННЫЕ ИТОГОВЫЕ ХАРАКТЕРИСТИКИ ---
var total_max_hp: int = 100
var total_attack_power: int = 0
var total_defence: int = 0
var total_regen: int = 0

func _ready() -> void:
	update_all_total_stats()
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
	current_hp -= max(0, (amount - total_defence))
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
# Вызывать ОДИН РАЗ при готовности игрока и при любой смене экипировки!
func update_all_total_stats() -> void:
	# 1. Сбрасываем локальные счетчики на базовые значения персонажа
	var t_hp = max_hp
	var t_atk = attack_power
	var t_def = defense
	var t_reg = regen
	
	# 2. Собираем бонусы от одиночных шмоток
	if equipped_weapon:
		t_atk += equipped_weapon.bonus_damage
		
	if equipped_helmet:
		t_hp += equipped_helmet.bonus_hp
		t_atk += equipped_helmet.bonus_damage
		t_def += equipped_helmet.bonus_defence
		t_reg += equipped_helmet.bonus_regen
		
	if equipped_chest:
		t_hp += equipped_chest.bonus_hp
		t_atk += equipped_chest.bonus_damage
		t_def += equipped_chest.bonus_defence
		t_reg += equipped_chest.bonus_regen
		
	if equipped_legs:
		t_hp += equipped_legs.bonus_hp
		t_atk += equipped_legs.bonus_damage
		t_def += equipped_legs.bonus_defence
		t_reg += equipped_legs.bonus_regen
		
	if equipped_arms:
		t_hp += equipped_arms.bonus_hp
		t_atk += equipped_arms.bonus_damage
		t_def += equipped_arms.bonus_defence
		t_reg += equipped_arms.bonus_regen
		
	# 3. Собираем бонусы из массива колец в один цикл (экономим процы!)
	for ring in equipped_rings:
		t_hp += ring.bonus_hp
		t_atk += ring.bonus_damage
		t_def += ring.bonus_defence
		t_reg += ring.bonus_regen
		
	# 4. Записываем результаты в глобальный кэш
	total_max_hp = t_hp
	total_attack_power = t_atk
	total_defence = t_def
	total_regen = t_reg
	
	# Корректируем текущее ХП, если из-за снятия шмотки макс_хп стало меньше текущего
	if current_hp > total_max_hp:
		current_hp = total_max_hp
		
	# Автоматически обновляем UI, так как статы гарантированно изменились
	if has_method("refresh_ui"):
		if get_parent() and get_parent().has_method("refresh_ui"):
			get_parent().refresh_ui()
