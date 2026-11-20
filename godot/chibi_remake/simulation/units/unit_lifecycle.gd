extends RefCounted
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
	battle._foot_cache.erase(int(u.get("uid", -1)))
	if effects != null:
		effects.visual("free_unit", [u])
	battle.selected.erase(u)
	battle.units.remove_at(i)
	battle._index_units_size = battle.units.size()
