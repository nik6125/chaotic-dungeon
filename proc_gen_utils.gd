extends Node

# Генерирует случайное число по Гауссу со средним значением (mean) и отклонением (deviation)
func rand_gaussian(mean: float, deviation: float = 1.0) -> float:
	var u1 = randf()
	var u2 = randf()
	# Преобразование Бокса-Мюллера
	while u1 <= 0.000001: u1 = randf() # Защита от нуля для логарифма
	
	var z0 = sqrt(-2.0 * log(u1)) * cos(2.0 * PI * u2)
	return z0 * deviation + mean

# Возвращает случайный целочисленный уровень сложности, ограниченный рамками
func get_gaussian_difficulty(target_diff: int, min_diff: int = 0, max_diff: int = 5) -> int:
	# Отклонение 1.0 означает, что ~68% врагов будут строго целевой сложности или +-1 уровень
	var float_diff = rand_gaussian(float(target_diff), 1.0)
	var int_diff = clampi(roundi(float_diff), min_diff, max_diff)
	return int_diff
