extends RefCounted
## ai economy: composed battle behavior.
const State = preload("res://simulation/battle_state.gd")
const Dependencies = preload("res://simulation/ports/ai_economy_dependencies.gd")
var battle: State
var ports := Dependencies.new()

func _init(data: State) -> void:
	battle = data

func ai_owners() -> Array:
	var out: Array = []
	if battle.scenario_sides.size() > 1:
		for i in range(1, battle.scenario_sides.size()):
			out.append(int((battle.scenario_sides[i] as Dictionary).get("owner", -1)))
	else:
		for x in battle.units:
			var o := int(x.owner)
			if o != battle.player_owner and o != 0 and not out.has(o):
				out.append(o)
	return out

func _ai_res_of(owner: int) -> Dictionary:
	if not battle.ai_res.has(owner):
		var sd := ports._ai_side(owner)
		var r: Array = sd.get("resources", [])
		battle.ai_res[owner] = {
			"gold": float(r[0]) if r.size() > 0 else 1000.0,
			"wood": float(r[2]) if r.size() > 2 else 500.0,
			"food": float(r[1]) if r.size() > 1 else 500.0,
			"stone": float(r[3]) if r.size() > 3 else 200.0,
		}
	return battle.ai_res[owner]

func ai_building_kinds(owner: int) -> Array:
	var out: Array = []
	for u in battle.units:
		if u.is_building and int(u.owner) == owner and u.alive and u.die_t < 0 and not bool(u.get("site", false)):
			var k: int = int(u.unit) - (int(u.unit) % 2)
			if not out.has(k):
				out.append(k)
	return out

func ai_construction_kinds(owner: int) -> Array:
	var kinds := []
	for unit in battle.units:
		if unit.alive and unit.die_t < 0 and unit.is_building and unit.owner == owner and unit.get("site", false):
			var kind := int(unit.unit) - int(unit.unit) % 2
			if kind not in kinds: kinds.append(kind)
	return kinds

func ai_worker_count(owner: int) -> int:
	var n := 0
	for u in battle.units:
		if bool(u.get("alive", false)) and float(u.get("die_t", -1)) < 0.0 and not bool(u.get("is_building", false)) and int(u.get("owner", -1)) == owner and int(u.get("unit", -1)) == 30:
			n += 1
	return n

func ai_construction_commander(owner: int) -> Dictionary:
	for commander in battle.units:
		if int(commander.owner) != owner or str(commander.state) != "idle": continue
		var workers := ports._construction_workers(commander)
		if not workers.is_empty() and workers.all(func(worker): return str(worker.state) == "idle"):
			return commander
	return {}

func _working_construction_team(unit: Dictionary) -> bool:
	var commander := ports._commander_for(unit)
	return ports._construction_workers(commander).any(func(worker): return worker.state == "build" and worker.get("build_target") is Dictionary)

func ai_group_of(u: Dictionary) -> int:
	var officer: Dictionary = u.get("officer", {})
	if not officer.is_empty():
		return int(officer.get("index", -1))
	return int(u.get("group_officer", -1))

func ai_can_build(owner: int, building_type: int) -> bool:
	var frame: Dictionary = battle.map_data.units.get(str(int(building_type)), {})
	if frame.is_empty():
		return false
	return ports.building_block_reason(building_type, owner) == "" and ai_can_afford(owner, ai_unit_cost(building_type))

func _dock_can_launch(point: Vector2) -> bool:
	if not battle.nav.has_water: return false
	var water_cell := battle.nav.near_walkable(battle.nav.cell_of_px(point.x,point.y),1)
	return not battle.nav.is_solid(water_cell,1)

func ai_gold(owner: int) -> float:
	if owner == battle.player_owner:
		return battle.gold
	return float(_ai_res_of(owner).get("gold", 0.0))

func ai_set_gold(owner: int, v: float) -> void:
	if owner == battle.player_owner:
		battle.gold = v
	else:
		_ai_res_of(owner)["gold"] = v

func ai_gift(owner: int, wood: float, food: float, stone: float) -> void:
	if owner == battle.player_owner:
		return
	var r := _ai_res_of(owner)
	r["wood"] = float(r.get("wood", 0.0)) + wood
	r["food"] = float(r.get("food", 0.0)) + food
	r["stone"] = float(r.get("stone", 0.0)) + stone

func ai_behavior(owner: int) -> int:
	var init: Array = ports._ai_side(owner).get("init",[])
	return int(init[0]) if not init.is_empty() else 0

func ai_research_building(owner: int, idx: int) -> Dictionary:
	var kinds: Array
	match ports._tech_line_of(idx):
		"hq": kinds = [0,1]
		"bow": kinds = [4,5]
		"weapon","armor": kinds = [2,3]
		"catapult": kinds = [8,9]
		"ship": kinds = [20]
		_: return {}
	for building in battle.units:
		if int(building.owner) == owner and building.alive and building.die_t < 0 and kinds.has(int(building.unit)) and not ports._building_work_busy(building): return building
	return {}

func ai_queue_hq_upgrade(owner: int) -> bool:
	var level := ai_level(owner)
	if level >= 3 or ports.ai_tech_gate(owner) < level+2: return false
	var kinds := ai_building_kinds(owner)
	if level <= 1 and (not kinds.has(4) or not kinds.has(2)): return false
	if level == 1 and (not kinds.has(8) or not kinds.has(6)): return false
	if ports._combat_member_count(owner) < level+2: return false
	var state := ports._tech_for(owner)
	if level == 2 and (int(state.get("bow",0)) < 2 or int(state.get("weapon",0)) < 2): return false
	var building := ai_research_building(owner,level)
	return not building.is_empty() and ports._queue_research(owner,building,level,true)

func ai_level(owner: int) -> int:
	if owner == battle.player_owner: return int(battle.player_tech.get("level", 0))
	return int(ports._tech_for(owner).get("level", 0))

func _naval_research_gate(_owner: int) -> bool:
	return false

func ai_force_units(owner: int) -> int:
	# 原版进攻闸门数的是玩家存活**单位记录**（建筑也计入），不是只数战斗兵。
	var n := 0
	for u in battle.units:
		if int(u.owner) == owner and bool(u.get("alive", false)) and float(u.get("die_t", -1)) < 0.0:
			n += 1
	return n

func ai_production_building(owner: int, requested_unit := -1) -> Dictionary:
	for u in battle.units:
		if u.is_building and int(u.owner) == owner and u.alive and u.die_t < 0 and not bool(u.get("site", false)):
			if requested_unit >= 0:
				if ports._building_work_busy(u): continue
				if not ports.train_types_for(int(u.unit), owner).any(func(opt): return int(opt.unit) == requested_unit): continue
			return u
	return {}

func ai_unit_cost(unit_id: int) -> Dictionary:
	var meta: Dictionary = battle.map_data.units.get(str(unit_id), {})
	var costs: Array = meta.get("costs", [0,0,0])
	return {"gold": float(costs[0]), "wood": float(costs[1]), "food": float(costs[2]), "stone": float(meta.get("costStone", 0))}

func ai_can_afford(owner: int, cost: Dictionary) -> bool:
	return battle.economy.can_pay(owner, cost)

func ai_enqueue_train(owner: int, b: Dictionary, unit_id: int, _cost: Dictionary) -> bool:
	return ports._queue_train(owner, b, unit_id)

func ai_disband_slot(owner: int, slot: int) -> void:
	if battle.ai != null and owner != battle.player_owner and slot>=0 and slot<4:
		battle.ai.slots.disband(owner,slot)

func _ai_forming(u: Dictionary) -> bool:
	return battle.ai != null and battle.ai.slots.forming(u)
