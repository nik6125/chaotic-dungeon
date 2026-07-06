extends Control

# Твои старые UI ноды
@onready var item_list: ItemList = $MarginContainer/HBoxContainer/LeftPanel/ItemList
@onready var item_title: Label = $MarginContainer/HBoxContainer/RightPanel/ItemTitle
@onready var item_desc: RichTextLabel = $MarginContainer/HBoxContainer/RightPanel/ItemDesc

# Новая UI нода для надетого снаряжения (добавь её в Центральную панель)
@onready var equipped_list: ItemList = $MarginContainer/HBoxContainer/CenterPanel/EquippedList

@onready var player = get_parent().get_parent().get_node_or_null("Player")

# Перечисление и переменная для отслеживания фокуса
enum FocusZone { BACKPACK, EQUIPPED }
var current_focus: FocusZone = FocusZone.BACKPACK

# Карта индексов, чтобы знать, какая строчка в UI-списке экипировки какому слоту принадлежит
var equipped_mapping: Array[Dictionary] = []

func _ready() -> void:
	visible = false
	
	# Разрешаем фокус только при ручном вызове или клике
	item_list.focus_mode = Control.FOCUS_CLICK
	equipped_list.focus_mode = Control.FOCUS_CLICK
	
	# Подключаем сигналы для левой панели (Рюкзак)
	item_list.item_selected.connect(_on_item_selected)
	item_list.item_activated.connect(_on_item_list_item_activated)
	
	# Подключаем сигналы для центральной панели (Экипировка)
	equipped_list.item_selected.connect(_on_equipped_selected)
	equipped_list.item_activated.connect(_on_equipped_activated)

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_inventory"):
		toggle_inventory()
		get_viewport().set_input_as_handled()
		return
		
	if not visible: return
	
	# Переключение фокуса кнопками Влево / Вправо
	if event.is_action_pressed("ui_right") and current_focus == FocusZone.BACKPACK:
		current_focus = FocusZone.EQUIPPED
		_apply_visual_focus()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_left") and current_focus == FocusZone.EQUIPPED:
		current_focus = FocusZone.BACKPACK
		_apply_visual_focus()
		get_viewport().set_input_as_handled()

func toggle_inventory() -> void:
	# Если мы спокойно ходили по карте — открываем сумку
	if GlobalSignals.current_state == GlobalSignals.GameState.CONTROL_PLAYER:
		GlobalSignals.current_state = GlobalSignals.GameState.INVENTORY
		visible = true
		current_focus = FocusZone.BACKPACK
		update_inventory_ui()
		_apply_visual_focus()
		
	# Если мы уже сидели в инвентаре — закрываем его и возвращаем контроль игроку
	elif GlobalSignals.current_state == GlobalSignals.GameState.INVENTORY:
		GlobalSignals.current_state = GlobalSignals.GameState.CONTROL_PLAYER
		visible = false


# Управление тем, какой список сейчас активно выделен
func _apply_visual_focus() -> void:
	if current_focus == FocusZone.BACKPACK:
		# 1. Даем физический фокус левому списку
		item_list.grab_focus()
		
		# 2. Погасим выделение в центральном списке, чтобы оно не мозолило глаза
		equipped_list.deselect_all()
		
		# 3. Возвращаем или ставим выделение в левом списке
		if item_list.item_count > 0:
			var selected = item_list.get_selected_items()
			var idx = selected[0] if not selected.is_empty() else 0
			item_list.select(idx)
			_on_item_selected(idx)
	else:
		# 1. Даем физический фокус центральному списку
		equipped_list.grab_focus()
		
		# 2. Погасим выделение в левом списке рюкзака
		item_list.deselect_all()
		
		# 3. Возвращаем или ставим выделение в центральном списке
		if equipped_list.item_count > 0:
			var selected = equipped_list.get_selected_items()
			# Защита на случай, если там висит строка "Экипировка пуста", у которой нет mapping'а
			var idx = selected[0] if not selected.is_empty() else 0
			equipped_list.select(idx)
			_on_equipped_selected(idx)

# Полное обновление всего интерфейса инвентаря
func update_inventory_ui() -> void:
	item_list.clear()
	equipped_list.clear()
	equipped_mapping.clear()
	
	if not player: return
	
	# 1. Заполняем РЮКЗАК (Левая панель)
	for item in player.inventory_list:
		item_list.add_item(item.name)
		
	# 2. Заполняем КУКЛУ СНАРЯЖЕНИЯ (Центральная панель)
	_add_slot_to_list("Оружие", "equipped_weapon")
	_add_slot_to_list("Шлем", "equipped_helmet")
	_add_slot_to_list("Нагрудник", "equipped_chest")
	_add_slot_to_list("Штаны", "equipped_legs")
	_add_slot_to_list("Перчатки", "equipped_arms")
	
	# Добавляем бесконечные кольца
	for i in range(player.equipped_rings.size()):
		var ring = player.equipped_rings[i]
		equipped_list.add_item("[Кольцо]: " + ring.name)
		equipped_mapping.append({
			"type": "ring",
			"index": i,
			"item": ring
		})
		
	if equipped_list.item_count == 0:
		equipped_list.add_item("Экипировка пуста")
		
	# Сбрасываем или восстанавливаем выбор строк
	_refresh_selection_after_update()

# Вспомогательный метод для красивого добавления фиксированных слотов
func _add_slot_to_list(slot_label: String, variable_name: String) -> void:
	var item = player.get(variable_name)
	if item != null:
		equipped_list.add_item("[" + slot_label + "]: " + item.name)
		equipped_mapping.append({
			"type": "slot",
			"slot_name": variable_name,
			"item": item
		})

# Корректно восстанавливает индекс курсора после того, как списки перерисовались
func _refresh_selection_after_update() -> void:
	if current_focus == FocusZone.BACKPACK:
		if item_list.item_count > 0:
			item_list.select(0)
			_on_item_selected(0)
		else:
			item_title.text = ""
			item_desc.text = ""
	else:
		if not equipped_mapping.is_empty() and equipped_list.item_count > 0:
			equipped_list.select(0)
			_on_equipped_selected(0)
		else:
			item_title.text = "Пусто"
			item_desc.text = "В этом слоте ничего нет."

# --- ЛОГИКА ОБНОВЛЕНИЯ ОПИСАНИЙ (ПРАВАЯ ПАНЕЛЬ) ---

# Выбор предмета в рюкзаке
func _on_item_selected(index: int) -> void:
	if not player or player.inventory_list.is_empty() or index >= player.inventory_list.size(): return
	var selected_item = player.inventory_list[index]
	
	var equipped_item: ItemData = null
	
	# Если предмет — НЕ кольцо, то ищем надетый аналог для сравнения
	if selected_item.slot_type != ItemData.SlotType.RING:
		equipped_item = _get_equipped_item_by_slot(selected_item.slot_type)
	
	# Для колец сюда автоматически уйдет null, и статы выведутся чистыми, без скобок дельты
	_show_description(selected_item, equipped_item)


# Выбор предмета в надетом снаряжении
func _on_equipped_selected(index: int) -> void:
	if equipped_mapping.is_empty() or index >= equipped_mapping.size():
		item_title.text = "Слот пуст"
		item_desc.text = ""
		return
	_show_description(equipped_mapping[index]["item"], null)


func _show_description(item: ItemData, compare_item: ItemData = null) -> void:
	item_title.text = item.name
	var description_text = ""
	
	# Проверяем, передали ли нам реальный объект для сравнения
	var is_comparing = (compare_item != null)
	
	description_text += _build_stat_line("Защита", item.bonus_defence, compare_item.bonus_defence if is_comparing else 0, is_comparing)
	description_text += _build_stat_line("Урон", item.bonus_damage, compare_item.bonus_damage if is_comparing else 0, is_comparing)
	description_text += _build_stat_line("Здоровье", item.bonus_hp, compare_item.bonus_hp if is_comparing else 0, is_comparing)
	description_text += _build_stat_line("Регенерация", item.bonus_regen, compare_item.bonus_regen if is_comparing else 0, is_comparing)
	item_desc.text = description_text


# Вспомогательный метод сборки строки для одного стата
func _build_stat_line(stat_name: String, new_val: int, old_val: int, is_comparing: bool) -> String:
	# Если стата нет ни на новой, ни на старой шмотке — пропускаем строку полностью
	if new_val == 0 and old_val == 0:
		return ""
		
	# Выводим базовый стат просто числом, без лишних плюсов перед цифрой или нулём
	var line = stat_name + ": " + str(new_val)
	
	# Если включен режим сравнения, считаем разницу
	if is_comparing:
		var diff = new_val - old_val
		if diff > 0:
			line += " (+" + str(diff) + ")"
		elif diff < 0:
			line += " (" + str(diff) + ")" # Минус автоматически прилетит из числа
		else:
			line += " (=)"
			
	return line + "\n"



# Находит надетый предмет, переводя Enum выбранной вещи в строку slot_name из маппинга
func _get_equipped_item_by_slot(slot_to_find: int) -> ItemData:
	# Словарь-переводчик: связываем ваш Enum с именами слотов из консоли
	var enum_to_string_name = {
		ItemData.SlotType.WEAPON: "equipped_weapon", # Допишите ваше точное имя для оружия, если оно есть
		ItemData.SlotType.HELMET: "equipped_helmet", # Допишите имя для шлема
		ItemData.SlotType.CHEST: "equipped_chest",
		ItemData.SlotType.LEGS: "equipped_legs",     # Допишите имя для штанов
		ItemData.SlotType.ARMS: "equipped_arms",
		ItemData.SlotType.RING: "equipped_ring"      # Допишите имя для кольца
	}
	
	# Получаем строковое имя слота для искомого предмета
	var target_string_name = enum_to_string_name.get(slot_to_find, "")
	if target_string_name == "":
		return null
		
	# Ищем нужный слот в маппинге снаряжения
	for slot_data in equipped_mapping:
		if slot_data.get("slot_name") == target_string_name:
			return slot_data.get("item") as ItemData
			
	return null





# --- ЛОГИКА НАЖАТИЯ ENTER (НАДЕТЬ / СНЯТЬ) ---

# Нажатие Enter в РЮКЗАКЕ (твоя старая функция + фикс багов)
func _on_item_list_item_activated(index: int) -> void:
	if not player or index >= player.inventory_list.size(): return
	var item = player.inventory_list[index] 
	use_item(item, index)

func use_item(item: ItemData, index: int) -> void:
	if not player: return
	var item_equipped: bool = false
	
	match item.slot_type:
		ItemData.SlotType.HELMET:
			if player.equipped_helmet != null:
				player.inventory_list.append(player.equipped_helmet)
			player.equipped_helmet = item
			item_equipped = true
		ItemData.SlotType.CHEST:
			if player.equipped_chest != null:
				player.inventory_list.append(player.equipped_chest)
			player.equipped_chest = item
			item_equipped = true
		ItemData.SlotType.LEGS:
			if player.equipped_legs != null:
				player.inventory_list.append(player.equipped_legs)
			player.equipped_legs = item
			item_equipped = true
		ItemData.SlotType.ARMS:
			if player.equipped_arms != null:
				player.inventory_list.append(player.equipped_arms)
			player.equipped_arms = item
			item_equipped = true
		ItemData.SlotType.WEAPON:
			if player.equipped_weapon != null:
				player.inventory_list.append(player.equipped_weapon)
			player.equipped_weapon = item
			item_equipped = true
		ItemData.SlotType.RING:
			player.equipped_rings.append(item)
			item_equipped = true

	if item_equipped:
		player.inventory_list.remove_at(index)
		player.update_all_total_stats()
		_finalize_action()

# Нажатие Enter в ЭКИПИРОВКЕ -> СНИМАЕМ предмет
func _on_equipped_activated(index: int) -> void:
	if not player or equipped_mapping.is_empty() or index >= equipped_mapping.size(): return
	
	var data = equipped_mapping[index]
	
	if data["type"] == "slot":
		var slot_var = data["slot_name"]
		var item = player.get(slot_var)
		if item:
			player.inventory_list.append(item)
			player.set(slot_var, null) # Освобождаем слот у игрока
			
	elif data["type"] == "ring":
		var ring_idx = data["index"]
		var ring_item = player.equipped_rings[ring_idx]
		player.inventory_list.append(ring_item)
		player.equipped_rings.remove_at(ring_idx) # Вытаскиваем конкретное кольцо из массива
		
	_finalize_action()

# Очистка, обновление UI и вызов рефреша главной сцены
func _finalize_action() -> void:
	update_inventory_ui()
	_apply_visual_focus()
	
	var game_node = get_parent().get_parent()
	if game_node.has_method("refresh_ui"):
		game_node.refresh_ui()
