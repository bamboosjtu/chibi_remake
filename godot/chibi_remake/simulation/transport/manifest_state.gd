extends RefCounted
## Unit carrier and passenger state.

static func set_carry_n(unit: Dictionary, value: Variant) -> void:
	unit.carry_n = value

static func set_carry_hp(unit: Dictionary, value: Variant) -> void:
	unit.carry_hp = value

static func set_loaded(unit: Dictionary, value: Variant) -> void:
	unit.loaded = value

static func set_aboard_uid(unit: Dictionary, value: Variant) -> void:
	unit.aboard_uid = value

static func set_board_target(unit: Dictionary, value: Variant) -> void:
	unit.board_target = value

static func set_unload_t(unit: Dictionary, value: Variant) -> void:
	unit.unload_t = value

static func set_unload_active(unit: Dictionary, value: Variant) -> void:
	unit.unload_active = value
