extends RefCounted
## Player gold and collection progress.

static func set_gold(battle: Object, value: Variant) -> void:
	battle.gold = value

static func set_gather_obj(unit: Dictionary, value: Variant) -> void:
	unit.gather_obj = value

static func set_gather_t(unit: Dictionary, value: Variant) -> void:
	unit.gather_t = value

static func set_gather_ticks(unit: Dictionary, value: Variant) -> void:
	unit.gather_ticks = value

static func set_delivery_ticks(unit: Dictionary, value: Variant) -> void:
	unit.delivery_ticks = value
