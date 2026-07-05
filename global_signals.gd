extends Node

# Глобальные состояния игры
enum GameState { CONTROL_PLAYER, INVENTORY, LOOK_MODE }

# Текущее активное состояние. На старте игрок управляет персонажем.
var current_state: GameState = GameState.CONTROL_PLAYER

# Координаты виртуальной рамки для будущего режима осмотра
var look_cursor_pos: Vector2i = Vector2i.ZERO
