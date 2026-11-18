extends RefCounted
const Roles = preload("res://simulation/definitions/unit_roles.gd")
const Balance = preload("res://simulation/definitions/balance_rules.gd")
## production: composed battle behavior.
const State = preload("res://simulation/battle_state.gd")
const Config = preload("res://simulation/battle_config.gd")
const REQUIRED_SERVICES := {"ai_economy": ["ai_level", "ai_unit_cost"], "battle_simulation": ["_feedback"], "campaign": ["_unit_name"], "entity_factory": ["_sheet_ref_for", "_spawn_unit"], "technology": ["_building_work_busy"]}
var battle: State
var ports := preload("res://simulation/service_dependencies.gd").new(REQUIRED_SERVICES)

func _init(data: State) -> void:
	battle = data

func train_types_for(bid: int, owner: int = -1) -> Array:
	var services := ports.acquire(["ai_economy", "entity_factory"])
	if services.is_empty(): return []
	if owner < 0: owner = battle.player_owner
	var ids: Array = Config.PRODUCE_BY_BUILDING.get(int(bid), [])
	var out: Array = []
	# research/buildings README 的 A-01 更正：生产等级由已建成大本营
	# 的升级状态派生（FUN_0046C710），不能使用关卡 init[0]。
	var has_hq := battle.units.any(func(u):return u.alive and u.die_t<0 and int(u.owner)==owner and int(u.unit) in [0,1] and not u.get("site",false))
	var tier := clampi(services.ai_economy.ai_level(owner),0,3) if has_hq else 0
	for position in range(ids.size()):
		var id_v = ids[position]
		if bid not in [0,1,8,9] and position > tier: continue
		var uid := int(id_v)
		var meta: Dictionary = battle.map_data.units.get(str(uid), {})
		if meta.is_empty():
			continue
		if services.entity_factory._sheet_ref_for(uid, owner) == "":
			continue                                  # 本图没有该兵种美术 → 不可生产
		var c: Array = meta.get("costs", [])
		out.append({
			"unit": uid,
			"name": str(meta.get("name", "?")) if uid == 30 else "%d人%s" % [int(meta.hp), str(meta.get("name", "?"))],
			"gold": float(c[0]) if c.size() > 0 else 0.0,
			"wood": float(c[1]) if c.size() > 1 else 0.0,
			"food": float(c[2]) if c.size() > 2 else 0.0,
			"stone": float(meta.get("costStone", 0.0)),
		})
	return out

func _train_list_for_selection() -> Array:
	for u in battle.selected:
		if bool(u.get("alive", false)) and bool(u.is_building) and int(u.get("owner", -1)) == battle.player_owner \
				and not bool(u.get("site", false)):
			return train_types_for(int(u.unit))
	return []

func _army_count(owner: int) -> int:
	return battle.units.filter(func(u): return u.alive and u.die_t < 0 and int(u.owner) == owner).size()

func _commander_count(owner: int) -> int:
	return battle.units.filter(func(u): return u.alive and u.die_t < 0 and int(u.owner) == owner and not u.get("officer", {}).is_empty()).size()

func _queue_train(owner: int, building: Dictionary, uid: int) -> bool:
	var services := ports.acquire(["technology", "ai_economy"])
	if services.is_empty(): return false
	if not building.alive or building.die_t >= 0 or building.get("site", false) or int(building.owner) != owner: return false
	var roster := train_types_for(int(building.unit), owner)
	if not roster.any(func(opt): return int(opt.unit) == uid): return false
	if services.technology._building_work_busy(building): return false
	if owner != battle.player_owner and (uid == 46 or Roles.is_transport(uid)) and battle.trainings.any(func(tr):return int(tr.get("owner",tr.b.owner))==owner and (int(tr.unit) == 46 or Roles.is_transport(int(tr.unit)))): return false
	var reserved := battle.trainings.filter(func(tr): return int(tr.get("owner", tr.b.owner)) == owner).size()
	if _army_count(owner) + reserved >= Balance.army_cap(): return false
	var cost: Dictionary = services.ai_economy.ai_unit_cost(uid)
	if not battle.economy.pay(owner, cost): return false
	var hp := int(battle.map_data.units[str(uid)].hp)
	battle.trainings.append({"b": building, "unit": uid, "t": float(hp), "cost": cost, "owner": owner, "ticks": true})
	return true

func _start_train(opt: Dictionary) -> void:
	_order_train(int(opt.unit), battle.selected)

func _order_train(unit_id: int, actors: Array) -> bool:
	var services := ports.acquire(["battle_simulation"])
	if services.is_empty(): return false
	if battle.game_end != 0: return false
	for building in actors:
		if building.is_building and int(building.owner) == battle.player_owner:
			if _queue_train(battle.player_owner, building, unit_id): return true
			services.battle_simulation._feedback("无法生产：检查建筑、科技、资源、生产进度与单位上限")
			return false
	services.battle_simulation._feedback("先选中已建成的生产建筑")
	return false

func cancel_destroyed_building(building: Dictionary) -> void:
	# A destroyed building releases its work and reservations without refunding costs.
	for order in battle.trainings.duplicate():
		if not is_same(order.b, building): continue
		if battle.ai != null:
			battle.ai.slots.cancelled(order)
			battle.ai.naval.cancelled(order)
		battle.trainings.erase(order)

func _cancel_training(building: Dictionary) -> bool:
	for i in range(battle.trainings.size()):
		if battle.trainings[i].b == building:
			var tr: Dictionary = battle.trainings[i]
			battle.economy.refund(int(tr.get("owner", building.owner)), tr.get("cost", {}))
			if battle.ai != null: battle.ai.slots.cancelled(tr); battle.ai.naval.cancelled(tr)
			battle.trainings.remove_at(i)
			return true
	return false

func _process_trainings(_delta: float) -> void:
	var services := ports.acquire(["entity_factory", "battle_simulation", "campaign"])
	if services.is_empty(): return
	for i in range(battle.trainings.size()-1, -1, -1):
		var tr: Dictionary = battle.trainings[i]
		if not bool(tr.b.alive) or tr.b.die_t >= 0:
			if battle.ai != null: battle.ai.slots.cancelled(tr); battle.ai.naval.cancelled(tr)
			battle.trainings.remove_at(i) # 建筑被毁不是玩家取消，不退款。
			continue
		tr.t = maxf(0.0, float(tr.t)-1.0)
		if tr.t > 0: continue
		var b: Dictionary = tr.b
		var owner := int(tr.get("owner", b.owner))
		# 出口堵塞时保留完成的生产单，下个tick重试；不重复扣费或退款。
		if services.entity_factory._spawn_unit(int(tr.unit), owner, float(b.ax), float(b.ay)):
			if battle.ai != null: battle.ai.slots.completed(tr,battle.units.back()); battle.ai.naval.completed(tr,battle.units.back())
			battle.trainings.remove_at(i)
			if owner == battle.player_owner: services.battle_simulation._feedback("训练完成：%s" % services.campaign._unit_name(int(tr.unit)))
