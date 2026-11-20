extends RefCounted
## Target, morale and computed combat modifiers.

static func set_target(unit: Dictionary, value: Variant) -> void:
	unit.target = value

static func set_status_173(unit: Dictionary, value: Variant) -> void:
	unit.status_173 = value

static func set_attack_bonus(unit: Dictionary, value: Variant) -> void:
	unit.attack_bonus = value

static func set_attack_b_bonus(unit: Dictionary, value: Variant) -> void:
	unit.attack_b_bonus = value

static func set_defence_bonus(unit: Dictionary, value: Variant) -> void:
	unit.defence_bonus = value

static func set_defence_b_bonus(unit: Dictionary, value: Variant) -> void:
	unit.defence_b_bonus = value
