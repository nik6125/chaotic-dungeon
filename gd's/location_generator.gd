# location_generator.gd
class_name LocationGenerator extends Resource

# === НОВАЯ СВЯЗУЮЩАЯ СТРОКА ===
# Теперь генератор намертво несет в себе настройки своего биома!
@export var location_data: LocationData

@export var world_item_scene: PackedScene
@export var tile_size: int = 16

var active_items_on_map: Dictionary = {}

# Изменено: убрали 'location: LocationData' из аргументов функции
func generate_map(map_grid: Array, tile_map: TileMapLayer, difficulty: int, game_node: Node2D) -> Vector2i:
	# Если данные биома не настроены в инспекторе — выдаем ошибку, чтобы игра не упала
	if not location_data:
		push_error("LocationGenerator: В ресурсе генератора не задан LocationData!")
		return Vector2i.ZERO

	if location_data.tile_set:
		tile_map.tile_set = location_data.tile_set
		
	# 1. СНАЧАЛА ПОЛНОСТЬЮ ЗАЛИВАЕМ КАРТУ СТЕНАМИ
	# Используем размеры из привязанного location_data
	for x in range(location_data.map_width):
		map_grid.append([])
		for y in range(location_data.map_height):
			map_grid[x].append("stone_wall")
			
	var rooms: Array[Rect2i] = []
	@warning_ignore("integer_division")
	var player_spawn_grid = Vector2i(location_data.map_width / 2, location_data.map_height / 2)
	
	# 2. ЦИКЛ СЛУЧАЙНОЙ ГЕНЕРАЦИИ КОМНАТ
	for i in range(location_data.max_rooms):
		# Размеры и позиции берем строго из настроек привязанного биома
		var w = randi_range(location_data.min_room_size, location_data.max_room_size)
		var h = randi_range(location_data.min_room_size, location_data.max_room_size)
		var x = randi_range(1, location_data.map_width - w - 1)
		var y = randi_range(1, location_data.map_height - h - 1)
		
		var new_room = Rect2i(x, y, w, h)
		
		var intersects = false
		for other_room in rooms:
			if new_room.intersects(other_room):
				intersects = true
				break
				
		if not intersects:
			carve_room(map_grid, new_room)
			
			if rooms.size() > 0:
				var prev_room = rooms[-1]
				create_corridor(map_grid, prev_room.get_center(), new_room.get_center())
				
			if rooms.size() == 0:
				player_spawn_grid = new_room.get_center()
			
			rooms.append(new_room)
			
	# 3. ПОРТАЛ В ЦЕНТРЕ ПОСЛЕДНЕЙ КОМНАТЫ
	if rooms.size() > 1:
		var last_room = rooms[-1]
		var portal_x = last_room.position.x + (last_room.size.x / 2)
		var portal_y = last_room.position.y + (last_room.size.y / 2)
		var portal_grid_pos = Vector2i(portal_x, portal_y)
		
		map_grid[portal_grid_pos.x][portal_grid_pos.y] = "portal"
		
		if game_node.has_method("spawn_portal_at"):
			game_node.spawn_portal_at(portal_grid_pos)

	# 4. ОТКРЫВАЕМ ПОРТАЛ И ОТРИСОВЫВАЕМ ТАЙЛЫ
	for x in range(location_data.map_width):
		for y in range(location_data.map_height):
			if map_grid[x][y] == "stone_wall":
				var random_wall = location_data.wall_atlas_coords.pick_random()
				tile_map.set_cell(Vector2i(x, y), 0, random_wall)
			else:
				var random_floor = location_data.floor_atlas_coords.pick_random()
				tile_map.set_cell(Vector2i(x, y), 0, random_floor)
				
	generate_loot_in_rooms(map_grid, rooms)
	
	# Вытаскиваем пул монстров прямо из встроенного ресурса биома!
	populate_location_with_budget(rooms, game_node, location_data.biome_monster_pool)
		
	return player_spawn_grid

# === ВСПОМОГАТЕЛЬНЫЕ ФУНКЦИИ КОПАНИЯ (ДОЛЖНЫ БЫТЬ ВНУТРИ ЭТОГО ЖЕ СКРИПТА) ===
func generate_loot_in_rooms(map_grid: Array, rooms: Array) -> void:
	# Получаем ссылку на главный узел игры для записи в словарь предметов
	var game_node = Engine.get_main_loop().current_scene
	if game_node and "active_items_on_map" in game_node:
		# Очищаем старые предметы перед генерацией новых
		game_node.active_items_on_map.clear()
	
	# Проходим циклом по каждой созданной комнате
	for room in rooms:
		# ВРЕМЕННО: 100% шанс спавна для тестов. Позже поменяешь на: 0.08 * RunManager.current_location_loot_value
		var final_spawn_chance: float = 2 
		
		if randf() <= final_spawn_chance:
			var random_tile: Vector2i = Vector2i.ZERO
			var found_valid_spot: bool = false
			var attempts: int = 0
			
			# Пытаемся найти чистый пол (максимум 15 попыток, чтобы игра не зависла)
			while not found_valid_spot and attempts < 15:
				attempts += 1
				var rand_x: int = randi_range(room.position.x + 1, room.position.x + room.size.x - 2)
				var rand_y: int = randi_range(room.position.y + 1, room.position.y + room.size.y - 2)
				var test_tile = Vector2i(rand_x, rand_y)
				
				# ПРОВЕРКА ПО МАТРИЦЕ КАРТЫ:
				# Клетка должна быть внутри границ массива и НЕ должна быть стеной или порталом
				if map_grid[test_tile.x][test_tile.y] != "stone_wall" and map_grid[test_tile.x][test_tile.y] != "portal":
					random_tile = test_tile
					found_valid_spot = true
			
			# Если за 15 попыток свободный пол в комнате так и не нашли (комната забита хламом),
			# просто пропускаем спавн в этой комнате, чтобы не лезть в стены
			if not found_valid_spot:
				continue
				
			# === ДАЛЬШЕ ИДЕТ ВАШ ГОТОВЫЙ КОД СПАВНА БЕЗ ИЗМЕНЕНИЙ ===
			var rolled_item_data: ItemData = ItemGenerator.generate_random_item()
			
			var item_instance = world_item_scene.instantiate()
			Engine.get_main_loop().current_scene.add_child(item_instance)
			
			var world_pos = Vector2(
				random_tile.x * tile_size + (tile_size / 2.0),
				random_tile.y * tile_size + (tile_size / 2.0)
			)
			item_instance.global_position = world_pos
			item_instance.initialize(rolled_item_data)
			
			if game_node and "active_items_on_map" in game_node:
				game_node.active_items_on_map[random_tile] = item_instance


func carve_room(map_grid: Array, room: Rect2i) -> void:
	for x in range(room.position.x, room.end.x):
		for y in range(room.position.y, room.end.y):
			map_grid[x][y] = "floor"

func create_corridor(map_grid: Array, start: Vector2i, end: Vector2i) -> void:
	# Копаем горизонтальную часть коридора
	var x_start = min(start.x, end.x)
	var x_end = max(start.x, end.x)
	for x in range(x_start, x_end + 1):
		map_grid[x][start.y] = "floor"
		
	# Копаем вертикальную часть коридора
	var y_start = min(start.y, end.y)
	var y_end = max(start.y, end.y)
	for y in range(y_start, y_end + 1):
		map_grid[end.x][y] = "floor"

func try_spawn_loot_in_room(room_tile_coords: Vector2i) -> WorldItem:
	var base_loot: float = float(RunManager.current_location_loot_value)
	var final_spawn_chance: float = min(0.50, 0.08 * base_loot)
	
	if randf() <= final_spawn_chance:
		var rolled_item_data: ItemData = ItemGenerator.generate_random_item()
		var item_instance = world_item_scene.instantiate()
		
		# Спавним напрямую в текущую активную сцену
		Engine.get_main_loop().current_scene.add_child(item_instance)
		
		var world_pos = Vector2(
			room_tile_coords.x * tile_size + (tile_size / 2.0),
			room_tile_coords.y * tile_size + (tile_size / 2.0)
		)
		item_instance.global_position = world_pos
		item_instance.initialize(rolled_item_data)
		
		return item_instance
		
	return null

# === ЭТОТ КУСОК КОДА ДОБАВЛЯЕМ В КОНЕЦ ФАЙЛА LOCATION_GENERATOR ===

# Функция, которая считает общий бюджет очков и распределяет монстров по комнатам
func populate_location_with_budget(rooms_list: Array[Rect2i], game_node: Node2D, current_biome_pool: BiomePool) -> void:
	if not current_biome_pool or current_biome_pool.available_monsters.is_empty():
		push_error("LocationGenerator: Пул биома пуст или не задан!")
		return

	# 1. Считаем общий бюджет очков на всю локацию по вашей формуле
	var diff: float = float(RunManager.current_location_difficulty)
	var total_budget: float = pow(1.125, diff)*len(rooms_list)
	
	# Перемешиваем комнаты для равномерного спавна
	var rooms = rooms_list.duplicate()
	rooms.shuffle()
	var current_room_index := 0
	
	# 2. Цикл закупки монстров, пока хватает бюджета
	while total_budget > 0.125 and not rooms.is_empty():
		var affordable_monsters: Array[MonsterData] = []
		for monster in current_biome_pool.available_monsters:
			if pow(monster.challenge_rating + 0.75,2) <= total_budget:
				affordable_monsters.append(monster)

				
		if affordable_monsters.is_empty():
			break
			
		var chosen_monster: MonsterData = affordable_monsters.pick_random()
		var room = rooms[current_room_index]
		
		# Пытаемся заспавнить
		var success = try_spawn_enemy_direct(chosen_monster, room, game_node)
		
		if success:
			total_budget -= chosen_monster.challenge_rating
			
		current_room_index = (current_room_index + 1) % rooms.size()

# Вспомогательная функция спавна конкретной тушки
func try_spawn_enemy_direct(monster_data: MonsterData, room: Rect2i, game_node: Node2D) -> bool:
	var rand_x := randi_range(room.position.x, room.end.x - 1)
	var rand_y := randi_range(room.position.y, room.end.y - 1)
	var enemy_grid_pos := Vector2i(rand_x, rand_y)
	
	# Вызываем проверки занятости клетки у главной ноды (game_node / Game)
	if game_node.get_enemy_at_pos(enemy_grid_pos) != null:
		return false
	if game_node.map_grid[enemy_grid_pos.x][enemy_grid_pos.y] == "portal":
		return false
		
	var enemy = load("res://tscn's/enemy.tscn").instantiate()
	enemy.data = monster_data
	
	# === ВОТ ЭТОТ КУСОК ВСТАВЛЯЕМ СЮДА ===
	enemy.grid_pos = enemy_grid_pos
	enemy.position = Vector2(enemy.grid_pos) * tile_size
	
	if game_node.player and game_node.player.sprite:
		enemy.scale = game_node.player.sprite.scale
		
	# Считаем Гаусс-бафф стат через ваш синглтон ProcGenUtils
	var target_difficulty: int = RunManager.current_location_difficulty
	var dynamic_max_diff: int = target_difficulty + 5 

	var final_enemy_stat_buff: int = ProcGenUtils.get_gaussian_difficulty(
		target_difficulty, 
		1, 
		dynamic_max_diff
	)
	# 1. СНАЧАЛА ДОБАВЛЯЕМ ВРАГА НА СЦЕНУ (чтобы сработал @onready внутри enemy.gd)
	game_node.add_child(enemy)
	game_node.enemies_list.append(enemy)
	
	# 2. ТЕПЕРЬ ПРИНУДИТЕЛЬНО МЕНЯЕМ ЕМУ ТЕКСТУРУ (теперь узел "Sprite" точно готов!)
	var enemy_sprite = enemy.get_node("Sprite") as Sprite2D
	if enemy_sprite and monster_data.icon:
		enemy_sprite.texture = monster_data.icon
		
	# 3. И В САМОМ КОНЦЕ инициализируем статы
	enemy.initialize_stats(final_enemy_stat_buff)
	return true
