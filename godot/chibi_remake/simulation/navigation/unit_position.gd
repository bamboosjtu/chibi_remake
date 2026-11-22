extends RefCounted
## Navigation writes logical position and cell together where a move changes both.
static func place_pixels(unit: Dictionary, x: float, y: float) -> void:
	unit.ax = x
	unit.ay = y

static func place_cell(unit: Dictionary, x: int, y: int) -> void:
	unit.A = x
	unit.B = y
