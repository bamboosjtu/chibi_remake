extends RefCounted
## 四资源唯一记账入口。玩家/AI使用同一校验、扣费和退款规则。
const KINDS := ["gold", "wood", "food", "stone"]
const Access = preload("res://simulation/ports/economy_access.gd")
var host: Access
func _init(h: Object) -> void: host = h.simulation_access("economy") if h.has_method("simulation_access") else h
func balance(owner: int) -> Dictionary:
	return host._resources() if owner == host.player_owner else host._ai_res_of(owner).duplicate()
func write(owner: int, value: Dictionary) -> void:
	if owner == host.player_owner:
		for kind in KINDS: host.set(kind, float(value.get(kind, 0)))
	else: host.ai_res[owner] = value
func can_pay(owner: int, cost: Dictionary) -> bool:
	var res := balance(owner)
	for kind in KINDS:
		var amount := float(cost.get(kind, 0))
		if not is_finite(amount) or amount < 0 or float(res.get(kind, 0)) < amount: return false
	return true
func pay(owner: int, cost: Dictionary) -> bool:
	if not can_pay(owner, cost): return false
	var res := balance(owner)
	for kind in KINDS: res[kind] = float(res.get(kind, 0)) - float(cost.get(kind, 0))
	write(owner, res)
	return true
func refund(owner: int, cost: Dictionary, percent := 75) -> void:
	var res := balance(owner)
	for kind in KINDS: res[kind] = float(res.get(kind, 0)) + floorf(float(cost.get(kind, 0)) * percent / 100.0)
	write(owner, res)
func deposit(worker: Dictionary) -> bool:
	var kind := str(worker.get("carry_kind", ""))
	var amount := float(worker.get("carry", 0))
	if not is_finite(amount) or amount <= 0 or amount > host.CARRY_CAPACITY or kind not in KINDS: return false
	var nearby := false
	for depot in host._deposits_for(worker, kind):
		if host._deposit_ready(worker, depot):
			nearby = true
			break
	if not nearby: return false
	var owner := int(worker.owner)
	var res := balance(owner)
	if kind == "food" and float(res.food) + amount > host._food_capacity(owner):
		if owner == host.player_owner: host._feedback("粮食已满（容量 %d），工人保留携带资源" % host._food_capacity(owner))
		return false
	res[kind] = float(res[kind]) + amount
	write(owner, res)
	worker.carry = 0.0; worker.carry_kind = ""; worker.gather_t = 0.0
	host._grant_officer_exp(worker,1)
	return true
