# location_generator.gd
class_name LocationGenerator extends Resource
# В начале твоего скрипта генератора уровней:
@export var world_item_scene: PackedScene
@export var tile_size: int = 16

# Словарь, где ключом будут координаты клетки Vector2i, а значением — ссылка на узел WorldItem
# Например: { Vector2i(5, 7): [WorldItem Instance] }
var active_items_on_map: Dictionary = {}
# Главная функция, которая делает ВСЁ. Она принимает ссылки на сетку, 
# узел карты TileMapLayer, ресурс настроек биома и сложность для спавна.
func generate_map(map_grid: Array, tile_map: TileMapLayer, location: LocationData, difficulty: int, game_node: Node2D) -> Vector2i:
	if location and location.tile_set:
		tile_map.tile_set = location.tile_set
	# 1. СНАЧАЛА ПОЛНОСТЬЮ ЗАЛИВАЕМ КАРТУ СТЕНАМИ
	# Используем размеры map_width и map_height из нашего файла настроек биома
	for x in range(location.map_width):
		map_grid.append([])
		for y in range(location.map_height):
			map_grid[x].append("stone_wall")
			
	var rooms: Array[Rect2i] = []
	@warning_ignore("integer_division")
	var player_spawn_grid = Vector2i(location.map_width / 2, location.map_height / 2)
	
	# 2. ЦИКЛ СЛУЧАЙНОЙ ГЕНЕРАЦИИ КОМНАТ
	for i in range(location.max_rooms):
		# Размеры и позиции берем строго из настроек текущего биома
		var w = randi_range(location.min_room_size, location.max_room_size)
		var h = randi_range(location.min_room_size, location.max_room_size)
		var x = randi_range(1, location.map_width - w - 1)
		var y = randi_range(1, location.map_height - h - 1)
		
		var new_room = Rect2i(x, y, w, h)
		
		# Проверяем, пересекается ли новая комната с уже созданными
		var intersects = false
		for other_room in rooms:
			if new_room.intersects(other_room):
				intersects = true
				break
				
		# Если комната уникальна и встала безопасно — прорубаем её!
		if not intersects:
			# Вызов внутренней функции прорубания пола (код ниже)
			carve_room(map_grid, new_room)
			
			# Если это не первая комната, соединяем её с предыдущей коридором
			if rooms.size() > 0:
				var prev_room = rooms[-1]
				create_corridor(map_grid, prev_room.get_center(), new_room.get_center())
				
			# Логика распределения спавна
			if rooms.size() == 0:
				# В самой первой комнате запоминаем центр для рыцаря
				player_spawn_grid = new_room.get_center()
			else:
				# Во всех остальных комнатах спавним врагов!
				# Передаем узел игры (game_node), чтобы генератор мог вызывать функцию спавна монстров
				if game_node.has_method("spawn_enemy_in_room"):
					# Твоя крутая формула густонаселенности теперь зависит от сложности локации!
					for j in randi_range(min(difficulty, 3), (min(difficulty, 5) + 1) * 2):
						game_node.spawn_enemy_in_room(new_room)
						
			rooms.append(new_room)
			
	# 3. ОТКРЫВАЕМ ПОРТАЛ В ЦЕНТРЕ САМОЙ ПОСЛЕДНЕЙ КОМНАТЫ
	if rooms.size() > 1:
		var last_room = rooms[-1]
		var portal_x = last_room.position.x + (last_room.size.x / 2)
		var portal_y = last_room.position.y + (last_room.size.y / 2)
		var portal_grid_pos = Vector2i(portal_x, portal_y)
		
		map_grid[portal_grid_pos.x][portal_grid_pos.y] = "portal"
		
		# Вызываем спавн физической ноды портала в главном скрипте
		if game_node.has_method("spawn_portal_at"):
			game_node.spawn_portal_at(portal_grid_pos)

	# 4. ТЕПЕРЬ ПЕРЕНОСИМ ВСЁ НА ЭКРАН (ОТРИСОВКА СЛУЧАЙНЫХ ТАЙЛОВ)
	for x in range(location.map_width):
		for y in range(location.map_height):
			if map_grid[x][y] == "stone_wall":
				# Берём случайную стену из списка стен в настройках биома
				var random_wall = location.wall_atlas_coords.pick_random()
				tile_map.set_cell(Vector2i(x, y), 0, random_wall) # 0 — это ID твоего источника в TileSet
			else:
				# То же самое для пола
				var random_floor = location.floor_atlas_coords.pick_random()
				tile_map.set_cell(Vector2i(x, y), 0, random_floor)
	generate_loot_in_rooms(rooms)
	# Возвращаем координаты, куда главному скрипту поставить рыцаря
	return player_spawn_grid


# === ВСПОМОГАТЕЛЬНЫЕ ФУНКЦИИ КОПАНИЯ (ДОЛЖНЫ БЫТЬ ВНУТРИ ЭТОГО ЖЕ СКРИПТА) ===
func generate_loot_in_rooms(rooms: Array) -> void:
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
			# Выбираем случайную клетку пола внутри Rect2i (отступая 1 тайл от стен)
			var rand_x: int = randi_range(room.position.x + 1, room.position.x + room.size.x - 2)
			var rand_y: int = randi_range(room.position.y + 1, room.position.y + room.size.y - 2)
			var random_tile: Vector2i = Vector2i(rand_x, rand_y)
			
			# 1. Генерируем абсолютно случайную вещь «из воздуха»
			var rolled_item_data: ItemData = ItemGenerator.generate_random_item()
			
			# 2. Спавним объект мешочка на сцену
			var item_instance = world_item_scene.instantiate()
			Engine.get_main_loop().current_scene.add_child(item_instance)
			
			# 3. Рассчитываем точные мировые координаты центра этой клетки пола
			var world_pos = Vector2(
				random_tile.x * tile_size + (tile_size / 2.0),
				random_tile.y * tile_size + (tile_size / 2.0)
			)
			item_instance.global_position = world_pos
			item_instance.initialize(rolled_item_data)
			
			# 4. Записываем мешочек в словарь активных предметов в Game.gd
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
