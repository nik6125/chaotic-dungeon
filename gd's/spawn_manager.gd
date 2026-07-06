extends Node
class_name SpawnManager

const TILE_SIZE: int = 16

@export var current_biome_pool: BiomePool
var main_map_node: Node

func initialize(map_node: Node) -> void:
	main_map_node = map_node

# (Здесь у вас живет функция populate_location, которую мы писали ранее)

func try_spawn_enemy(monster_data: MonsterData, room: Rect2i) -> bool:
	var rand_x := randi_range(room.position.x, room.end.x - 1)
	var rand_y := randi_range(room.position.y, room.end.y - 1)
	var enemy_grid_pos := Vector2i(rand_x, rand_y)
	
	if main_map_node.get_enemy_at_pos(enemy_grid_pos) != null:
		return false
	if main_map_node.map_grid[enemy_grid_pos.x][enemy_grid_pos.y] == "portal":
		return false
		
	var enemy = monster_data.monster_scene.instantiate()
	# ВАЖНО: Передаем ссылку на ресурс данных, чтобы враг знал свои базовые статы!
	enemy.data = monster_data 
	
	enemy.grid_pos = enemy_grid_pos
	enemy.position = Vector2(enemy.grid_pos) * TILE_SIZE
	
	if main_map_node.player and main_map_node.player.sprite:
		enemy.scale = main_map_node.player.sprite.scale
		
	# === ВОТ СЮДА ЗАКИНУТЬ ЭТОТ ВЕРХНИЙ КУСОК ===
	var target_difficulty: int = RunManager.current_location_difficulty
	var dynamic_max_diff: int = target_difficulty + 5 

	var final_enemy_stat_buff: int = ProcGenUtils.get_gaussian_difficulty(
		target_difficulty, 
		1, 
		dynamic_max_diff
	)
	
	# Передаем итоговый уровень баффа монстру
	enemy.initialize_stats(final_enemy_stat_buff)
	# ============================================
	
	main_map_node.add_child(enemy)
	main_map_node.enemies_list.append(enemy)
	return true
