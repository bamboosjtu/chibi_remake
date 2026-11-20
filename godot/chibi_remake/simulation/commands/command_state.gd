extends RefCounted
## Mutations shared by the selection and pending-command entry points.
static func replace_selection(battle: Object, selection: Array) -> void:
	battle.selected = selection

static func add_selection(battle: Object, unit: Dictionary) -> void:
	battle.selected.append(unit)

static func forget_selection(battle: Object, unit: Dictionary) -> void:
	battle.selected.erase(unit)

static func set_duel_pending(battle: Object, value: Variant) -> void:
	battle.duel_pending = value

static func set_cmd_pending(battle: Object, value: Variant) -> void:
	battle.cmd_pending = value

static func set_cmd_pending_data(battle: Object, value: Variant) -> void:
	battle.cmd_pending_data = value

static func set_jimou_pending(battle: Object, value: Variant) -> void:
	battle.jimou_pending = value

static func set_jimou_caster(battle: Object, value: Variant) -> void:
	battle.jimou_caster = value

static func set_hold(unit: Dictionary, value: Variant) -> void:
	unit.hold = value

static func set_control_groups_entry(battle: Object, index: int, value: Variant) -> void:
	battle.control_groups[index] = value

static func erase_from_control_groups(battle: Object, value: Variant) -> void:
	battle.control_groups.erase(value)
