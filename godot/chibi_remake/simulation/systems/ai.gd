extends RefCounted
## Stable AI facade: deterministic schedule and snapshot lifecycle.
const Settings = preload("res://simulation/systems/ai_config.gd")
const THINK_PERIOD = Settings.THINK_PERIOD
const BUILD_PLAN_PERIOD = Settings.BUILD_PLAN_PERIOD
const BUILD_STATE_PERIOD = Settings.BUILD_STATE_PERIOD
const INTERCEPT_PERIOD = Settings.INTERCEPT_PERIOD
const ASSAULT_PERIOD = Settings.ASSAULT_PERIOD
const ASSAULT_PERIOD_URGENT = Settings.ASSAULT_PERIOD_URGENT
const AI_MONEY = Settings.AI_MONEY
const GIFT_WOOD = Settings.GIFT_WOOD
const GIFT_FOOD = Settings.GIFT_FOOD
const GIFT_STONE = Settings.GIFT_STONE
const HUMAN_GOLD_FOR_ASSAULT = Settings.HUMAN_GOLD_FOR_ASSAULT
const ARMY_BY_TIER = Settings.ARMY_BY_TIER
const HUMAN_WEAK_UNITS = Settings.HUMAN_WEAK_UNITS
const INTERCEPT_RADIUS = Settings.INTERCEPT_RADIUS
const Access = Settings.Access
const PLAN_TO_BUILDING = Settings.PLAN_TO_BUILDING
const PLAN_PAIR = Settings.PLAN_PAIR
const BUILD_PRIORITY_KINDS = Settings.BUILD_PRIORITY_KINDS

var _ai_state = preload("res://simulation/systems/ai_state.gd").new()
var decisions = preload("res://simulation/systems/ai_decisions.gd").new(_ai_state)
var _fields: Dictionary = {}

func army_for(owner: int) -> Array:
	return decisions.army_for(owner)
func _init(h: Object) -> void:
	for field in _ai_state.PROXY_FIELDS: _fields[field] = true
	_ai_state.host = h.simulation_access("ai") if h.has_method("simulation_access") else h
	_ai_state.slots = preload("res://simulation/systems/ai_training_slots.gd").new(_ai_state.host)
	_ai_state.naval = preload("res://simulation/systems/ai_naval_slots.gd").new(_ai_state.host)

func snapshot() -> Dictionary:
	return {"think": _ai_state._think.duplicate(), "planClock": _ai_state._plan.duplicate(), "buildClock": _ai_state._build_clock.duplicate(), "assault": _ai_state._assault.duplicate(), "assaultPeriod": _ai_state._assault_period.duplicate(), "intercept": _ai_state._intercept.duplicate(), "plan": _ai_state.plan.duplicate(), "researchCursor":_ai_state._research_cursor.duplicate(), "retreat":_ai_state._retreat.duplicate(true), "retreatClock":_ai_state._retreat_clock.duplicate(), "retreatPoints":_ai_state._retreat_points.duplicate(true), "trainingSlots":_ai_state.slots.snapshot(), "navalSlots":_ai_state.naval.snapshot()}

func restore(value: Dictionary) -> void:
	_ai_state.slots.restore(value.get("trainingSlots",{}))
	_ai_state.naval.restore(value.get("navalSlots",{}))
	for pair in [["think", _ai_state._think], ["planClock", _ai_state._plan], ["buildClock", _ai_state._build_clock], ["assault", _ai_state._assault], ["assaultPeriod", _ai_state._assault_period], ["intercept", _ai_state._intercept], ["plan", _ai_state.plan], ["researchCursor",_ai_state._research_cursor], ["retreatClock",_ai_state._retreat_clock]]:
		var table: Dictionary = pair[1]
		table.clear()
		for key in value.get(pair[0], {}):
			table[int(key)] = int(value[pair[0]][key])
	# R10：撤退状态按群保存：owner -> {group: 1}。旧档的 owner->1 只表示
	# “该势力曾经在撤退”，无法定位到群，按空闲时自动恢复处理（下一次检查会结束它）。
	_ai_state._retreat.clear()
	var retreat_value = value.get("retreat", {})
	if retreat_value is Dictionary:
		for key in retreat_value:
			var entry = retreat_value[key]
			var groups := {}
			if entry is Dictionary:
				for group in entry:
					groups[int(group)] = 1
			elif _ai_state.slots.integer(entry) and int(entry) != 0:
				groups = {}          # 旧档迁移：不知道是哪个群，不假装仍在撤退
			_ai_state._retreat[int(key)] = groups
	_ai_state._retreat_points.clear()
	for key in value.get("retreatPoints",{}): _ai_state._retreat_points[int(key)] = value.retreatPoints[key].duplicate()

func valid_snapshot(value: Variant, ids: Dictionary, orders: Array, next_uid: int) -> bool:
	if not value is Dictionary: return false
	if not _valid_retreat(value): return false
	for field in ["think","planClock","buildClock","assault","assaultPeriod","intercept","plan","researchCursor","retreat"]:
		if not value.get(field,{}) is Dictionary: return false
		for key in value.get(field,{}):
			if not str(key).is_valid_int(): return false
			var entry = value[field][key]
			if field == "retreat" and entry is Dictionary:
				# 新格式：群号 -> 1；群号必须是合法整数。
				for group in entry:
					if not str(group).is_valid_int() or not _ai_state.slots.integer(entry[group]): return false
				continue
			if not _ai_state.slots.integer(entry): return false
	if not _ai_state.slots.valid_snapshot(value.get("trainingSlots",{}),ids,orders,next_uid): return false
	# R16：水军槽与陆军槽对等校验，坏档不能进入恢复/调度。
	return _ai_state.naval.valid_snapshot(value.get("navalSlots",{}),ids,orders,next_uid)

func _valid_retreat(value: Dictionary) -> bool:
	if not value.get("retreatClock",{}) is Dictionary or not value.get("retreatPoints",{}) is Dictionary: return false
	for key in value.get("retreatClock",{}):
		var count = value.retreatClock[key]
		if not str(key).is_valid_int() or not _ai_state.slots.integer(count) or int(count)<0 or int(count)>=Settings.RETREAT_PERIOD: return false
	for key in value.get("retreatPoints",{}):
		var point = value.retreatPoints[key]
		if not str(key).is_valid_int() or not point is Array or point.size()!=2: return false
		for axis in point:
			if not (axis is int or axis is float) or not is_finite(float(axis)) or float(axis)<0: return false
	return true

func set_retreat_point(owner: int, point: Vector2) -> bool:
	if owner not in _ai_state.host.ai_owners() or not point.is_finite() or point.x<0 or point.y<0: return false
	_ai_state._retreat_points[owner] = [point.x,point.y]
	return true

## 每逻辑 tick 调一次（由 main.gd::_sim_step 驱动）

func tick() -> void:
	for o in _ai_state.host.ai_owners():
		var owner := int(o)
		_ai_state._build_clock[owner] = int(_ai_state._build_clock.get(owner, 0)) + 1
		if int(_ai_state._build_clock[owner]) >= BUILD_STATE_PERIOD:
			_ai_state._build_clock[owner] = 0
			if int(_ai_state.host.ai_behavior(owner)) in [0, 1]:
				decisions._worker_step(owner)
				decisions._build_step(owner)
		_ai_state._think[owner] = int(_ai_state._think.get(owner, 0)) + 1
		if int(_ai_state._think[owner]) < THINK_PERIOD:
			continue
		_ai_state._think[owner] = 0
		decisions._think_once(owner)

## 一次完整决策（对应 FUN_00472230 的调用序列）

func _think_once(owner: int) -> void:
	decisions._think_once(owner)
func _train(owner: int) -> void:
	decisions._train(owner)
func _slot_train(owner: int) -> void:
	decisions._slot_train(owner)
func _research_plan(owner: int) -> bool:
	return decisions._research_plan(owner)
func _assault_maybe(owner: int, skip_groups: Array = []) -> void:
	decisions._assault_maybe(owner, skip_groups)
func _intercept_near(owner: int, skip_groups: Array = []) -> void:
	decisions._intercept_near(owner, skip_groups)
func _rally(owner: int, skip_groups: Array = []) -> void:
	decisions._rally(owner, skip_groups)
func _refresh_plan(owner: int) -> void:
	decisions._refresh_plan(owner)
func _worker_step(owner: int) -> void:
	decisions._worker_step(owner)
func _maintain_construction_team(owner: int) -> Dictionary:
	return decisions._maintain_construction_team(owner)
func _spare_construction_officer(owner: int) -> Dictionary:
	return decisions._spare_construction_officer(owner)
func _officer_groups(owner: int) -> Dictionary:
	return decisions._officer_groups(owner)
func _retreat_step(owner: int) -> Dictionary:
	return decisions._retreat_step(owner)
func _living_attacker(anchor: Dictionary, owner: int) -> Dictionary:
	return decisions._living_attacker(anchor, owner)
func _build_step(owner: int) -> void:
	decisions._build_step(owner)

func _get(key: StringName):
	if _fields.has(key): return _ai_state.get(key)
	preload("res://property_contract.gd").reject(self,key)
	return null

func _set(key: StringName, value) -> bool:
	if _fields.has(key): _ai_state.set(key, value); return true
	preload("res://property_contract.gd").reject(self,key)
	return false

static func available_slots(behavior: int, gate: int, level: int, human_level: int, human_gold: float, mission: int) -> Array:
	return preload("res://simulation/systems/ai_decisions.gd").available_slots(behavior, gate, level, human_level, human_gold, mission)

static func naval_slots(behavior: int, gate: int) -> Array:
	return preload("res://simulation/systems/ai_decisions.gd").naval_slots(behavior, gate)

static func plan_item_for(kind: int, owner: int) -> int:
	return preload("res://simulation/systems/ai_decisions.gd").plan_item_for(kind, owner)
