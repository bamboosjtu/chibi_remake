extends RefCounted
const IndexState = preload("res://simulation/navigation/index_state.gd")
const CommandState = preload("res://simulation/commands/command_state.gd")
## Per-unit lifecycle and idle-state actions. Tick coordination lives in world/unit_tick_coordinator.gd.
const Balance = preload("res://simulation/definitions/balance_rules.gd")

func _step_rest(u: Dictionary, delta: float) -> void:
	# 休息（模式 4，FUN_004602e0）：每 REST_TICKS 个逻辑 tick HP +1，满编即结束。
	if float(u.hp) >= float(u.maxhp) - 0.001:
		u.state = "idle"; u.rest_t = 0
	else:
		u.rest_t = int(u.get("rest_t", 0)) + 1
		if int(u.rest_t) >= int(Balance.work().restTicks):
			u.rest_t = 0
			u.hp = minf(float(u.maxhp), float(u.hp) + float(Balance.work().restHp))
		if float(u.hp) >= float(u.maxhp):
			u.state = "idle"; u.rest_t = 0

static func initialize_record(unit: Dictionary, apply_technology: Callable) -> void:
	preload("res://simulation/movement/locomotion.gd").ensure(unit)
	apply_technology.call(unit)

static func remove_at(battle: Object, i: int, nav: Object, spatial_index: Object, effects: Object) -> void:
	if i < 0 or i >= battle.units.size(): return
	var u: Dictionary = battle.units[i]
	if u.has("occupied_cells"):
		nav.occupy(u.occupied_cells, -1)
	spatial_index._index_forget(u)
	spatial_index._target_forget(u)
	IndexState.erase_from_foot_cache(battle, int(u.get("uid", -1)))
	if effects != null:
		effects.visual("free_unit", [u])
	CommandState.forget_selection(battle, u)
	battle.units.remove_at(i)
	IndexState.set_index_units_size(battle, battle.units.size())

static func set_hp(unit: Dictionary, value: Variant) -> void:
	unit.hp = value

static func set_formation(unit: Dictionary, value: Variant) -> void:
	unit.formation = value

static func set_fo_x(unit: Dictionary, value: Variant) -> void:
	unit.fo_x = value

static func set_fo_y(unit: Dictionary, value: Variant) -> void:
	unit.fo_y = value

static func subtract_from_hp(unit: Dictionary, value: Variant) -> void:
	unit.hp -= value

static func set_die_t(unit: Dictionary, value: Variant) -> void:
	unit.die_t = value

static func add_to_die_t(unit: Dictionary, value: Variant) -> void:
	unit.die_t += value

static func set_rest_t(unit: Dictionary, value: Variant) -> void:
	unit.rest_t = value

static func append_to_units(battle: Object, value: Variant) -> void:
	battle.units.append(value)

static func set_base_maxhp(unit: Dictionary, value: Variant) -> void:
	unit.base_maxhp = value

static func set_maxhp(unit: Dictionary, value: Variant) -> void:
	unit.maxhp = value

static func set_alive(unit: Dictionary, value: Variant) -> void:
	unit.alive = value

static func set_mou(unit: Dictionary, value: Variant) -> void:
	unit.mou = value

static func set_event_experience(unit: Dictionary, value: Variant) -> void:
	unit.event_experience = value

static func set_map_index(unit: Dictionary, value: Variant) -> void:
	unit.map_index = value
