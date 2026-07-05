class_name ItemData extends Resource

# Перечисления типов, чтобы игра понимала, куда этот предмет можно надеть
enum SlotType { INVENTORY, WEAPON, HELMET, CHEST, LEGS, ARMS, RING }

@export var name: String = "Неизвестный предмет"
@export var slot_type: SlotType = SlotType.INVENTORY

# Динамические характеристики, которые будут генерироваться процедурно
@export var bonus_damage: int = 0
@export var bonus_defence: int = 0
@export var bonus_regen: int = 0
@export var bonus_hp: int = 0

# Текстура предмета для отображения в инвентаре и на полу
@export var texture_coord: Vector2i = Vector2i(0, 0) # Координаты в общем атласе лута
