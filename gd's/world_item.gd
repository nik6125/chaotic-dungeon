# WorldItem.gd
class_name WorldItem
extends  Node2D # Можно отнаследоваться прямо от Sprite2D, так как коллизии не нужны

# Здесь хранится сгенерированный кастомный ресурс со всеми статами
var item_data: ItemData

func _ready() -> void:
	# Отключаем размытие пикселей
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

## Функция инициализации, вызывается генератором при спавне
func initialize(data: ItemData) -> void:
	item_data = data
