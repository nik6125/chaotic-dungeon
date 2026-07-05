extends Control

# Берем ссылки на текстовые метки (проверь, чтобы пути совпали с твоим деревом сцен!)
@onready var label_hp: Label = $HBoxContainer/SidePanel/VBoxContainer/HP
@onready var label_damage: Label = $HBoxContainer/SidePanel/VBoxContainer/Damage
@onready var label_defence: Label = $HBoxContainer/SidePanel/VBoxContainer/Defence
@onready var label_regen: Label = $HBoxContainer/SidePanel/VBoxContainer/Regen
@onready var label_level: Label = $HBoxContainer/SidePanel/VBoxContainer/Level
@onready var label_chaos: Label = $HBoxContainer/SidePanel/VBoxContainer/Chaos
# Функция, которая будет переписывать текст на актуальные статы игрока
func update_player_stats(hp: int, max_hp: int, dmg: int, def: int, reg: int, chaos: int, max_chaos: int) -> void:
	label_hp.text = "HP: " + str(hp) + " / " + str(max_hp)
	label_damage.text = "Damage: " + str(dmg)
	label_defence.text = "Defence: " + str(def)
	label_regen.text = "Regen: " + str(reg)
	label_chaos.text = "Chaos: " + str(chaos) + " / " + str(max_chaos)
func update_dungeon_stats(level: int) -> void:
	label_level.text = "Dungeon Level: " + str(level)
