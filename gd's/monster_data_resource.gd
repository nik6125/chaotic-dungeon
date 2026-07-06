extends Resource
class_name MonsterData
const BASE_ENEMY_SCENE = preload("res://gd's/enemy.gd") # Укажите ваш точный путь к сцене базового врага

@export var monster_name: String = "Монстр"
# ВОТ СЮДА МЫ БУДЕМ ПЕРЕТАСКИВАТЬ ИКОНКУ:
@export var icon: Texture2D 

@export var challenge_rating: float = 1.0
@export var base_max_hp: int = 25
@export var base_attack_power: int = 6
@export var base_defense: int = 0
@export var base_regen: int = 0
@export var base_chaos: int = 30
