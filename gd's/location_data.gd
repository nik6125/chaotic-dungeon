class_name LocationData extends Resource

@export var location_name: String = "Подземелье"

# Переносим твои переменные настроек из game.gd
@export var map_width: int = 50
@export var map_height: int = 50
@export var min_room_size: int = 5
@export var max_room_size: int = 10
@export var max_rooms: int = 6

# Твои массивы координат из атласа
@export var tile_set: TileSet
@export var floor_atlas_coords: Array[Vector2i] = []
@export var wall_atlas_coords: Array[Vector2i] = []

@export var biome_monster_pool: BiomePool
