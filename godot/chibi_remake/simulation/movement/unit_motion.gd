extends RefCounted
## Route progress and unit animation clocks.

static func set_repath(unit: Dictionary, value: Variant) -> void:
	unit.repath = value

static func set_route_failures(unit: Dictionary, value: Variant) -> void:
	unit.route_failures = value

static func subtract_from_repath(unit: Dictionary, value: Variant) -> void:
	unit.repath -= value

static func add_to_anim(unit: Dictionary, value: Variant) -> void:
	unit.anim += value

static func set_cool(unit: Dictionary, value: Variant) -> void:
	unit.cool = value

static func set_blocked_n(unit: Dictionary, value: Variant) -> void:
	unit.blocked_n = value

static func set_anim(unit: Dictionary, value: Variant) -> void:
	unit.anim = value

static func set_dir(unit: Dictionary, value: Variant) -> void:
	unit.dir = value

static func set_moved(unit: Dictionary, value: Variant) -> void:
	unit.moved = value
