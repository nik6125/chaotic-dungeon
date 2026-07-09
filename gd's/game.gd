extends Node2D
const ENEMY_SCENE = preload("res://tscn's/enemy.tscn")
const PORTAL_SCENE = preload("res://tscn's/portal.tscn")
const SOURCE_ID = 0

@onready var tile_map: TileMapLayer = $Map
@onready var player: Node2D = $Player
@onready var hud: Control = $UI/HUD
@export var current_location_data: LocationData
@export var current_generator: LocationGenerator
@onready var look_controller: LookModeController = $LookModeController
var current_portal_instance = null

var TILE_SIZE: int = 16
# Словарь для хранения всех мешочков на текущей карте: { Vector2i(x, y): WorldItem }
var active_items_on_map: Dictionary = {}

# Наша логическая сетка (двумерный массив)
var map_grid = []
var enemies_list = []
var generated_rooms: Array[Rect2i] = []

func _ready() -> void:
	player.movement_requested.connect(try_move_player)
	map_grid.clear()
	$Map.clear()
	var spawn_pos = RunManager.current_generator.generate_map(
		map_grid,
		$Map,
		RunManager.current_location_difficulty,
		self
	)
	player.position = Vector2(spawn_pos) * TILE_SIZE
	refresh_ui()

func advance_turn() -> void:
	if player.current_chaos_energy > 0:
		player.current_hp = min(player.current_hp + player.total_regen, player.total_max_hp)
	player.consume_chaos_energy(player.chaos_consumption)
	check_loot_pickup()
	run_enemies_turn()
	refresh_ui()
# Функция, которая запускает цикл для всех живых врагов
func run_enemies_turn() -> void:
	var player_grid_pos = Vector2i(player.position / TILE_SIZE)
	
	# Перебираем ВСЕХ врагов из нашего списка через цикл
	for enemy in enemies_list:
		if is_instance_valid(enemy):
			move_enemy(enemy, player_grid_pos)
			enemy.current_hp = calculate_regeneration(enemy.current_hp, enemy.max_hp, enemy.regen)


# Эта функция срабатывает, когда игрок нажимает клавишу на клавиатуре
func try_move_player(dir: Vector2i) -> void:
	# Вычисляем, где игрок стоит сейчас и куда хочет пойти
	var current_grid_pos = Vector2i(player.position / TILE_SIZE)
	var target_grid_pos = current_grid_pos + dir
	
	# 1. ПРОВЕРКА: Есть ли в этой клетке враг?
	var target_enemy = get_enemy_at_pos(target_grid_pos)
	if target_enemy != null:
		# Вызываем наш новый выделенный боевой движок!
		CombatEngine.deal_damage(player, target_enemy)
		advance_turn() 
		return
	# --- ДОБАВИЛИ ПРОПУСК ХОДА НА ПРОБЕЛ ---
	if dir == Vector2i.ZERO:
		advance_turn()
		return
	# 2. ПРОВЕРКА: Извлекаем тип клетки, чтобы код стал читаемым
	var target_tile = map_grid[target_grid_pos.x][target_grid_pos.y]
	# Разрешаем шаг, если там ОБЫЧНЫЙ ПОЛ или ПОРТАЛ
	if target_tile == "floor" or target_tile == "portal":
		# Передвигаем ноду игрока на новые координаты
		player.position = Vector2(target_grid_pos) * TILE_SIZE
		
		# ЕСЛИ ЭТО БЫЛ ПОРТАЛ — мгновенно перемещаем рыцаря в новый мир!
		if target_tile == "portal":
			enter_portal()
			return # Выходим, чтобы старые монстры не ходили на удаленной карте
			
		# Если это обычный пол — просто передаем ход врагам
		advance_turn()
	else:
		print("Там стена! Ход не засчитан, враги не ходят.")

# Помощник: ищет врага по координатам сетки
func get_enemy_at_pos(coords: Vector2i):
	for enemy in enemies_list:
		# Проверяем, что враг еще существует (не удален) и его координаты совпадают
		if is_instance_valid(enemy) and enemy.grid_pos == coords:
			return enemy
	return null

func data_enemies_turn():
	var player_grid_pos = Vector2i(player.position / TILE_SIZE)
	for enemy in enemies_list:
		move_enemy(enemy, player_grid_pos)

func move_enemy(enemy, player_pos: Vector2i):
	if not is_instance_valid(enemy): return
	
	var dir = enemy.get_next_move_direction(player_pos)
	if dir == Vector2i.ZERO: return
	
	var target_pos = enemy.grid_pos + dir
	
	# 1. СНАЧАЛА ПРОВЕРЯЕМ: Если враг хочет наступить на игрока — он атакует!
	if target_pos == player_pos:
		# Исправлено: передаем ОСОБЬ (enemy) в качестве атакующего, а не self!
		CombatEngine.deal_damage(enemy, player)
		return # Обязательно выходим из функции, чтобы монстр не шагал после удара

	# 2. ЕСЛИ ИГРОКА ТАМ НЕТ: Проверяем обычный шаг по полу
	if map_grid[target_pos.x][target_pos.y] == "floor" and get_enemy_at_pos(target_pos) == null:
		enemy.grid_pos = target_pos
		enemy.position = Vector2(target_pos) * TILE_SIZE
	else:
		# Если уперся в стену или другого врага — пропускает ход
		pass


func refresh_ui() -> void:
	if not player or not hud: return
	hud.update_player_stats(
		player.current_hp,
		player.total_max_hp,        
		player.total_attack_power, 
		player.total_defence,      
		player.total_regen,         
		player.current_chaos_energy,
		player.max_chaos_energy
	)
	hud.update_dungeon_stats(
		RunManager.current_dimension_floor
	)

func calculate_regeneration(hp: int, max_hp: int, regen_value: int) -> int:
	if hp > 0 and hp < max_hp:
		hp += regen_value
		if hp > max_hp:
			hp = max_hp
	return hp # Возвращаем измененное число обратно

func spawn_portal_at(coords: Vector2i) -> void:
	var portal_obj = PORTAL_SCENE.instantiate()
	portal_obj.grid_pos = coords
	portal_obj.position = Vector2(coords) * TILE_SIZE
	portal_obj.scale = player.sprite.scale
	add_child(portal_obj)
	current_portal_instance = portal_obj

## Функция проверки, наступил ли игрок на лут. 
## Вызывай её в Game.gd сразу ПОСЛЕ того, как игрок переместился на новую клетку.
func check_loot_pickup() -> void:
	# Высчитываем клетку игрока из его пиксельных координат
	var player_tile: Vector2i = Vector2i(
		floori(player.global_position.x / 16.0),
		floori(player.global_position.y / 16.0)
	)

	if active_items_on_map.has(player_tile):
		var item_node: WorldItem = active_items_on_map[player_tile]
		
		# Добавляем сгенерированный ресурс предмета в инвентарь игрока
		player.inventory_list.append(item_node.item_data)
		print("Подобран предмет: ", item_node.item_data.name)
		
		# Удаляем мешочек с карты и из памяти
		active_items_on_map.erase(player_tile)
		item_node.queue_free()
		
		# Так как инвентарь изменился, сразу даем команду меню перерисоваться
		# (Подставь правильное имя переменной твоего InventoryMenu, если оно другое)
		if has_node("InventoryMenu"):
			$InventoryMenu.update_lists() 

func enter_portal() -> void:
	# --- СНАЧАЛА КРУТИМ МАТЕМАТИКУ НОВОГО ЭТАЖА ---
	RunManager.roll_next_dimension() 

	# Очистка старого этажа (врагов, портала, тайлов)
	if is_instance_valid(current_portal_instance): current_portal_instance.queue_free()
	current_portal_instance = null
	for enemy in enemies_list: if is_instance_valid(enemy): enemy.queue_free()
	enemies_list.clear()
	map_grid.clear()
	$Map.clear()
	for item in active_items_on_map.values():
		if is_instance_valid(item):
			item.queue_free()
	active_items_on_map.clear()
	var spawn_pos = RunManager.current_generator.generate_map(
		map_grid,
		$Map,
		RunManager.current_location_difficulty,
		self
	)
	player.position = Vector2(spawn_pos) * TILE_SIZE
	refresh_ui()

func _unhandled_input(event: InputEvent) -> void:
	# Ловим нажатие нашей новой кнопки из Input Map
	if event.is_action_pressed("look_mode_toggle"):
		# Если мы просто ходили по карте — замораживаем игрока и включаем оверлей осмотра
		if GlobalSignals.current_state == GlobalSignals.GameState.CONTROL_PLAYER:
			GlobalSignals.current_state = GlobalSignals.GameState.LOOK_MODE
			look_controller.activate() 
			
		# Если мы уже были в режиме осмотра — выключаем его и возвращаем управление игроку
		elif GlobalSignals.current_state == GlobalSignals.GameState.LOOK_MODE:
			GlobalSignals.current_state = GlobalSignals.GameState.CONTROL_PLAYER
			look_controller.deactivate() 
		return
