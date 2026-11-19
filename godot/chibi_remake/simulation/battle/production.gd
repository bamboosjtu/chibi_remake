extends Object
const EffectsRuntime = preload("res://simulation/battle_effects.gd")
var _effects: EffectsRuntime
var _economy: RefCounted
var _ai: RefCounted
const Roles = preload("res://simulation/definitions/unit_roles.gd")
const Balance = preload("res://simulation/definitions/balance_rules.gd")
## production: composed battle behavior.
const State = preload("res://simulation/battle_state.gd")
const Config = preload("res://simulation/battle_config.gd")
var battle: State
var _dep_ai_economy: Object
var _dep_campaign: Object
var _dep_entity_factory: Object
var _dep_technology: Object

func _init(data: State) -> void:
	battle = data

func train_types_for(bid: int, owner: int = -1) -> Array:
	if owner < 0: owner = battle.player_owner
	var ids: Array = Config.PRODUCE_BY_BUILDING.get(bid, [])
	var out: Array = []
	var tier := _training_tier(owner)
	for position in range(ids.size()):
		if _required_training_tier(bid, position) > tier: continue
		var uid := int(ids[position])
		var meta := _trainable_meta(uid, owner)
		if meta.is_empty(): continue
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

func find_training_building(owner: int, unit_id: int) -> Dictionary:
	var roster_owner := owner if owner >= 0 else battle.player_owner
	if _trainable_meta(unit_id, roster_owner).is_empty(): return {}
	var tier := -1
	for building: Dictionary in battle.units:
		if not building.is_building or int(building.owner) != owner or not building.alive \
				or building.die_t >= 0 or building.get("site", false):
			continue
		var bid := int(building.unit)
		var ids: Array = Config.PRODUCE_BY_BUILDING.get(bid, [])
		var position := ids.find(unit_id)
		if position < 0: continue
		var required_tier := _required_training_tier(bid, position)
		if required_tier > 0:
			if tier < 0: tier = _training_tier(roster_owner)
			if required_tier > tier: continue
		if not _dep_technology._building_work_busy(building):
			return building
	return {}

func _training_tier(owner: int) -> int:
	# 生产等级取已建成且存活的大本营的升级状态，详见 research/buildings 的 A-01。
	var has_hq := battle.units.any(func(u):
		return u.alive and u.die_t < 0 and int(u.owner) == owner and int(u.unit) in [0, 1] and not u.get("site", false))
	return clampi(_dep_ai_economy.ai_level(owner), 0, 3) if has_hq else 0

func _required_training_tier(bid: int, position: int) -> int:
	return 0 if bid in [0, 1, 8, 9] else position

func _trainable_meta(uid: int, owner: int) -> Dictionary:
	var meta: Dictionary = battle.map_data.units.get(str(uid), {})
	return meta if not meta.is_empty() and _dep_entity_factory._sheet_ref_for(uid, owner) != "" else {}

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
	if not building.alive or building.die_t >= 0 or building.get("site", false) or int(building.owner) != owner: return false
	var bid := int(building.unit)
	var ids: Array = Config.PRODUCE_BY_BUILDING.get(bid, [])
	var position := ids.find(uid)
	if position < 0: return false
	var required_tier := _required_training_tier(bid, position)
	var roster_owner := owner if owner >= 0 else battle.player_owner
	if required_tier > 0 and required_tier > _training_tier(roster_owner): return false
	var meta := _trainable_meta(uid, roster_owner)
	if meta.is_empty(): return false
	if _dep_technology._building_work_busy(building): return false
	if owner != battle.player_owner and (uid == 46 or Roles.is_transport(uid)) and battle.trainings.any(func(tr):return int(tr.get("owner",tr.b.owner))==owner and (int(tr.unit) == 46 or Roles.is_transport(int(tr.unit)))): return false
	var reserved := battle.trainings.filter(func(tr): return int(tr.get("owner", tr.b.owner)) == owner).size()
	if _army_count(owner) + reserved >= Balance.army_cap(): return false
	var cost: Dictionary = _dep_ai_economy.ai_unit_cost(uid)
	if not _economy.pay(owner, cost): return false
	var hp := int(meta.hp)
	battle.trainings.append({"b": building, "unit": uid, "t": float(hp), "cost": cost, "owner": owner, "ticks": true})
	return true

func _start_train(opt: Dictionary) -> void:
	_order_train(int(opt.unit), battle.selected)

func _order_train(unit_id: int, actors: Array) -> bool:
	if battle.game_end != 0: return false
	for building in actors:
		if building.is_building and int(building.owner) == battle.player_owner:
			if _queue_train(battle.player_owner, building, unit_id): return true
			_effects.feedback("无法生产：检查建筑、科技、资源、生产进度与单位上限")
			return false
	_effects.feedback("先选中已建成的生产建筑")
	return false

func cancel_destroyed_building(building: Dictionary) -> void:
	# A destroyed building releases its work and reservations without refunding costs.
	for order in battle.trainings.duplicate():
		if not is_same(order.b, building): continue
		if _ai != null:
			_ai.slots.cancelled(order)
			_ai.naval.cancelled(order)
		battle.trainings.erase(order)

func _cancel_training(building: Dictionary) -> bool:
	for i in range(battle.trainings.size()):
		if battle.trainings[i].b == building:
			var tr: Dictionary = battle.trainings[i]
			_economy.refund(int(tr.get("owner", building.owner)), tr.get("cost", {}))
			if _ai != null: _ai.slots.cancelled(tr); _ai.naval.cancelled(tr)
			battle.trainings.remove_at(i)
			return true
	return false

func _process_trainings(_delta: float) -> void:
	for i in range(battle.trainings.size()-1, -1, -1):
		var tr: Dictionary = battle.trainings[i]
		if not bool(tr.b.alive) or tr.b.die_t >= 0:
			if _ai != null: _ai.slots.cancelled(tr); _ai.naval.cancelled(tr)
			battle.trainings.remove_at(i) # 建筑被毁不是玩家取消，不退款。
			continue
		tr.t = maxf(0.0, float(tr.t)-1.0)
		if tr.t > 0: continue
		var b: Dictionary = tr.b
		var owner := int(tr.get("owner", b.owner))
		# 出口堵塞时保留完成的生产单，下个tick重试；不重复扣费或退款。
		if _dep_entity_factory._spawn_unit(int(tr.unit), owner, float(b.ax), float(b.ay)):
			if _ai != null: _ai.slots.completed(tr,battle.units.back()); _ai.naval.completed(tr,battle.units.back())
			battle.trainings.remove_at(i)
			if owner == battle.player_owner: _effects.feedback("训练完成：%s" % _dep_campaign._unit_name(int(tr.unit)))

func bind_dependencies(world: Object) -> void:
	_dep_ai_economy = world.ai_economy
	_dep_campaign = world.campaign
	_dep_entity_factory = world.entity_factory
	_dep_technology = world.technology
	_economy = world.economy
	_effects = world.effects
