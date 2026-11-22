extends RefCounted
const UnitLifecycle = preload("res://simulation/units/unit_lifecycle.gd")
const UnitMotion = preload("res://simulation/movement/unit_motion.gd")
const UnitPath = preload("res://simulation/movement/unit_path.gd")
var _economy: RefCounted
const Balance = preload("res://simulation/definitions/balance_rules.gd")
const Config = preload("res://simulation/definitions/battle_config.gd")
## 用户确认：每格树/粮200；采尽保留残迹，自动寻找附近同类资源。
## 自动转采按实际路径长度选最近。换粮田时也搜索原粮田附近的地块。
const ROUTE_RETRY_SECONDS := 1.0
var _effects: RefCounted
var _state: RefCounted
var _dep_combat: Object
var _dep_harvest_orders: Object
var _dep_interaction_paths: Object
var _dep_movement: Object
func _init(h: Object) -> void:
	_state = h.state
	_effects = h.effects
	_dep_combat = h.combat
	_dep_harvest_orders = h.harvest_orders
	_dep_interaction_paths = h.interaction_paths
	_dep_movement = h.movement

func next_target(worker: Dictionary, previous: Dictionary) -> bool:
	# 身上有货：任何“找下一个采集点”的路径都必须先回运，不能把货卡在 idle。
	if float(worker.get("carry", 0.0)) > 0.0:
		worker.state = "deliver"; UnitPath.set_points(worker, []); UnitPath.reset_cursor(worker); worker.gather_obj = previous
		return true
	# 敌方粮仓抽空后不自动改抢另一个粮仓；用户的自动转采只覆盖有限资源点。
	if int(previous.get("unit",-1)) in [10,11]:
		worker.state = "idle"; UnitPath.set_points(worker, []); worker.gather_obj = null
		return false
	var kind: String = _dep_harvest_orders._yield_of(int(previous.get("unit", -1)))
	var found: Dictionary = {}
	var previous_field := Vector2.INF
	if bool(previous.get("decor", false)):
		found = _dep_harvest_orders._clicked_harvest_patch(previous, worker, {})
		if kind == "food": previous_field = Vector2(previous.ax, previous.ay)
	if found.is_empty():
		found = _dep_harvest_orders._nearest_harvest_by_path(worker, kind, {}, [previous], previous_field)
	if found.is_empty():
		worker.state = "idle"; UnitPath.set_points(worker, []); worker.gather_obj = null
		if int(worker.owner) == _state.player_owner: _effects.feedback("附近没有可达的同类资源")
		return false
	_dep_harvest_orders._begin_gather(worker, found.object, found.path)
	return true

func resume_after_deposit(worker: Dictionary, previous: Dictionary) -> bool:
	if bool(previous.get("alive", false)) and float(previous.get("die_t", -1)) < 0.0:
		# Keep the assigned source and resolve its approach in the gather state.
		_dep_harvest_orders._begin_gather(worker, previous, [])
		return true
	return next_target(worker, previous)

func extract(worker: Dictionary, target: Dictionary) -> void:
	# 接近完成后按逻辑tick计时；每4tick轮询，100tick装货。
	worker.gather_ticks = int(worker.get("gather_ticks", 0)) + 1
	worker.gather_t = float(worker.gather_ticks) * _state.SIM_DT # 旧存档/状态栏兼容字段。
	var rule := Balance.harvest()
	if int(worker.gather_ticks) < int(rule.periodTicks) or int(worker.gather_ticks) % int(rule.pollTicks) != 0: return
	var kind: String = _dep_harvest_orders._yield_of(int(target.unit))
	var granary := int(target.unit) in [10,11] and not bool(target.get("decor", false))
	var stock := float(target.get("stock", 0))
	if granary: stock = float(_economy.balance(int(target.owner)).food)
	var amount := minf(float(rule.extractAmount), maxf(0, stock))
	if amount > 0:
		if granary:
			var pool: Dictionary = _economy.balance(int(target.owner))
			pool.food = stock - amount
			_economy.write(int(target.owner), pool)
		else: target.stock = stock - amount
		worker.carry = amount; worker.carry_kind = kind
		worker.state = "deliver"; UnitPath.set_points(worker, []); UnitPath.reset_cursor(worker)
		worker.gather_ticks = 0; worker.gather_t = 0.0
	if stock - amount <= 0:
		if bool(target.get("decor", false)): _dep_harvest_orders._remove_decor(target)
		elif target.die_t < 0:
			UnitLifecycle.set_hp(target, 0.0)
			_dep_combat._kill(target, {})
	if amount <= 0:
		# 目标已空但工人身上还有货：必须先回运，不能原地转 idle 把货扣在手里。
		if float(worker.get("carry", 0.0)) > 0.0:
			worker.state = "deliver"; UnitPath.set_points(worker, []); UnitPath.reset_cursor(worker)
		else:
			next_target(worker, target)

func bind_dependencies(world: Object) -> void:
	_economy = world.economy


func step_gather(u: Dictionary, delta: float) -> void:
	var obj = u.get("gather_obj", null)
	if not (obj is Dictionary) or obj.is_empty():
		u.state = "idle"; UnitPath.set_points(u, [])
	elif not bool(obj.get("alive", false)) or float(obj.get("die_t", -1)) >= 0:
		next_target(u, obj)
	elif _dep_interaction_paths._edge_cell_distance(u, obj) != Config.EDGE_DISTANCE:
		if u.path.is_empty():
			if _retry_pending(u, delta): return
			var choice: Dictionary = _dep_harvest_orders._harvest_interaction_choice(u, obj)
			if choice.is_empty() and bool(obj.get("decor", false)):
				choice = _dep_harvest_orders._clicked_harvest_patch(obj, u, {})
			if choice.is_empty():
				UnitMotion.set_repath(u, ROUTE_RETRY_SECONDS)
				return
			if not is_same(u.gather_obj, choice.object):
				u.gather_ticks = 0
				u.gather_t = 0.0
			u.gather_obj = choice.object
			UnitPath.set_points(u, choice.path)
			UnitPath.reset_cursor(u)
		_dep_movement._follow(u, delta)
	else:
		UnitPath.set_points(u, [])
		extract(u, obj)

func step_deliver(u: Dictionary, delta: float) -> bool:
	if u.path.is_empty() and _retry_pending(u, delta): return false
	var deposits: Array = _dep_harvest_orders._deposits_for(u, str(u.get("carry_kind", "")))
	var arrived: Dictionary = {}
	for building in deposits:
		if _dep_interaction_paths._deposit_ready(u, building):
			arrived = building; break
	if not arrived.is_empty():
		u.delivery_ticks = int(u.get("delivery_ticks", 0)) + 1
		if int(u.delivery_ticks) % 4 != 0: return false
		if _dep_harvest_orders._deposit_carry(u):
			UnitPath.set_points(u, []); UnitPath.reset_cursor(u)
			# 卸货后继续玩家指定的资源，不暗中改采其他种类。
			if u.gather_obj is Dictionary: resume_after_deposit(u, u.gather_obj)
			else: u.state = "idle"
		else:
			UnitPath.set_points(u, []); UnitPath.reset_cursor(u)
			UnitMotion.set_repath(u, ROUTE_RETRY_SECONDS)
	else:
		if u.path.is_empty():
			for building in deposits:
				UnitPath.set_points(u, _dep_interaction_paths._edge_interaction_path(u, building, {}, Config.DEPOSIT_EDGE_PX)); UnitPath.reset_cursor(u)
				if not u.path.is_empty(): break
		if u.path.is_empty():
			if deposits.is_empty():
				u.state = "idle"; _effects.feedback("没有可到达的卸货建筑，工人保留携带资源")
			else:
				UnitMotion.set_repath(u, ROUTE_RETRY_SECONDS)
		else: _dep_movement._follow(u, delta)
	return true

func _retry_pending(worker: Dictionary, delta: float) -> bool:
	var remaining := float(worker.get("repath", 0))
	if remaining <= 0.0: return false
	UnitMotion.set_repath(worker, maxf(0.0, remaining - delta))
	return float(worker.repath) > 0.0
