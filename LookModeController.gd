extends CanvasLayer # Меняем тип на CanvasLayer, чтобы он сам был слоем интерфейса
class_name LookModeController

@export var tile_map: TileMapLayer
@export var player: Node2D

# Внутренние ссылки на свой собственный UI, который лежит внутри этой же сцены
@onready var item_title: Label = $Panel/ItemTitle # Поправь пути на свои внутренние ноды
@onready var item_desc: RichTextLabel = $Panel/ItemDesc

func _ready() -> void:
	# На старте игры полностью скрываем весь наш слой с экрана и усыпляем логику
	deactivate()

# Метод включается из Game.gd
func activate() -> void:
	visible = true # Показываем панель осмотра на экране
	set_process_unhandled_input(true) # Включаем обработку стрелочек
	
	# Считаем позицию из физических координат игрока
	GlobalSignals.look_cursor_pos = Vector2i(player.position / 16)
	
	# Запускаем полет камеры и сканирование первой клетки
	_move_camera_and_scan()

# Метод выключается из Game.gd
func deactivate() -> void:
	visible = false # Полностью прячем панель осмотра
	set_process_unhandled_input(false) # Усыпляем кнопки
	
	# Возвращаем камеру обратно на игрока
	var camera = get_viewport().get_camera_2d()
	if camera:
		camera.global_position = player.global_position

func _unhandled_input(event: InputEvent) -> void:
	var move_dir = Vector2i.ZERO
	if event.is_action_pressed("ui_right"): move_dir.x = 1
	elif event.is_action_pressed("ui_left"): move_dir.x = -1
	elif event.is_action_pressed("ui_down"): move_dir.y = 1
	elif event.is_action_pressed("ui_up"): move_dir.y = -1
	
	if move_dir != Vector2i.ZERO:
		GlobalSignals.look_cursor_pos += move_dir
		_move_camera_and_scan()

func _move_camera_and_scan() -> void:
	var camera = get_viewport().get_camera_2d()
	if camera:
		camera.global_position = Vector2(GlobalSignals.look_cursor_pos * 16)
	_scan_current_cell()

func _scan_current_cell() -> void:
	print("ЛУТ НА КАРТЕ: ", get_parent().get("items_on_floor"))
	var target_pos = GlobalSignals.look_cursor_pos
	
	# --- 1. ВРАГ ---
	var enemies = get_parent().get("enemies_list")
	var found_enemy = null
	if enemies:
		for enemy in enemies:
			if is_instance_valid(enemy) and enemy.get("grid_pos") == target_pos:
				found_enemy = enemy
				break
	if found_enemy:
		item_title.text = "[ ОСМОТР: ВРАГ ]"
		item_desc.text = "Здоровье: %d / %d\nЗащита: %d\nУрон: %d\nРеген: %d\nХаос: %d" % [
			found_enemy.current_hp, found_enemy.max_hp,
			found_enemy.defense, found_enemy.attack_power,
			found_enemy.regen, found_enemy.chaos
		]
		return

	# --- 2. ЛУТ НА ПОЛУ ---
	# Вытягиваем ваш реальный словарь из game.gd по его точному имени
	var items_dict = get_parent().get("active_items_on_map") 
	
	if items_dict and items_dict.has(target_pos):
		var floor_item = items_dict[target_pos]
		
		# Проверяем, что объект живой и у него есть данные предмета
		if is_instance_valid(floor_item) and floor_item.get("item_data"):
			var data = floor_item.item_data
			item_title.text = "[ НА ПОЛУ ]: " + data.name
			
			var description_text = ""
			if data.bonus_defence > 0: description_text += "Защита: " + str(data.bonus_defence) + "\n"
			if data.bonus_damage > 0:  description_text += "Урон: " + str(data.bonus_damage) + "\n"
			if data.bonus_hp > 0:      description_text += "Здоровье: " + str(data.bonus_hp) + "\n"
			if data.bonus_regen > 0:   description_text += "Регенерация: " + str(data.bonus_regen) + "\n"
			item_desc.text = description_text
			return


	# --- 3. ПУСТО ---
	item_title.text = "[ ОСМОТР ]"
	item_desc.text = "Координаты клетки: " + str(target_pos) + "\nЗдесь ничего нет."
