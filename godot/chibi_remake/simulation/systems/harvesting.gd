extends RefCounted
## 用户确认：每格树/粮200；采尽保留残迹，自动寻找附近同类资源。
## R15：自动转采以**工人当前位置**为心、**有效视野**为半径收集候选，按**实际路径长度**
## 选最近，同距按格坐标先 y 后 x 稳定排序；不再按旧资源位置或直线距离。
const Access = preload("res://simulation/ports/harvesting_access.gd")
var host: Access
func _init(h: Object) -> void: host = h.simulation_access("harvesting") if h.has_method("simulation_access") else h

func next_target(worker: Dictionary, previous: Dictionary) -> bool:
	# 身上有货：任何“找下一个采集点”的路径都必须先回运，不能把货卡在 idle。
	if float(worker.get("carry", 0.0)) > 0.0:
		worker.state = "deliver"; worker.path = []; worker.pi = 0; worker.gather_obj = previous
		return true
	# 敌方粮仓抽空后不自动改抢另一个粮仓；用户的自动转采只覆盖有限资源点。
	if int(previous.get("unit",-1)) in [10,11]:
		worker.state = "idle"; worker.path = []; worker.gather_obj = null
		return false
	var kind: String = host._yield_of(int(previous.get("unit", -1)))
	var found: Dictionary = host._nearest_harvest_by_path(worker, kind)
	if found.is_empty():
		worker.state = "idle"; worker.path = []; worker.gather_obj = null
		if int(worker.owner) == host.player_owner: host._feedback("附近没有可达的同类资源")
		return false
	host._begin_gather(worker, found.object, found.path)
	return true

## Returning to a distant depot must not erase an explicitly assigned field.
## Search the original connected patch (including harvested remnants) first;
## the vision rule still governs switching to an unrelated resource patch.
func resume_after_deposit(worker: Dictionary, previous: Dictionary) -> bool:
	if bool(previous.get("decor", false)):
		var found: Dictionary = host._clicked_harvest_patch(previous, worker, {})
		if bool(previous.get("alive", false)):
			found = host._edge_interaction_choice(worker, previous)
		if not found.is_empty():
			host._begin_gather(worker, found.object, found.path)
			return true
	elif bool(previous.get("alive", false)):
		# A surviving mine/house/granary remains the assigned task, regardless
		# of how far the depot is. The gather state replans its real edge path.
		host._begin_gather(worker, previous, [])
		return true
	return next_target(worker, previous)

func extract(worker: Dictionary, target: Dictionary) -> void:
	# 接近完成后按逻辑tick计时；每4tick轮询，100tick装货。
	worker.gather_ticks = int(worker.get("gather_ticks", 0)) + 1
	worker.gather_t = float(worker.gather_ticks) * host.SIM_DT # 旧存档/状态栏兼容字段。
	if int(worker.gather_ticks) < 100 or int(worker.gather_ticks) % 4 != 0: return
	var kind: String = host._yield_of(int(target.unit))
	var granary := int(target.unit) in [10,11] and not bool(target.get("decor", false))
	var stock := float(target.get("stock", 0))
	if granary: stock = float(host.economy.balance(int(target.owner)).food)
	var amount := minf(host.CARRY_CAPACITY, maxf(0, stock))
	if amount > 0:
		if granary:
			var pool: Dictionary = host.economy.balance(int(target.owner))
			pool.food = stock - amount
			host.economy.write(int(target.owner), pool)
		else: target.stock = stock - amount
		worker.carry = amount; worker.carry_kind = kind
		worker.state = "deliver"; worker.path = []; worker.pi = 0
		worker.gather_ticks = 0; worker.gather_t = 0.0
	if stock - amount <= 0:
		if bool(target.get("decor", false)): host._remove_decor(target)
		elif target.die_t < 0:
			target.hp = 0.0
			host._kill(target, {})
	if amount <= 0:
		# 目标已空但工人身上还有货：必须先回运，不能原地转 idle 把货扣在手里。
		if float(worker.get("carry", 0.0)) > 0.0:
			worker.state = "deliver"; worker.path = []; worker.pi = 0
		else:
			next_target(worker, target)
