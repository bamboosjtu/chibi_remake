extends RefCounted
const Balance = preload("res://simulation/definitions/balance_rules.gd")
## 四资源唯一记账入口。玩家/AI使用同一校验、扣费和退款规则。
const KINDS := ["gold", "wood", "food", "stone"]
var _state: RefCounted
var _dep_ai_economy: Object
var _effects: RefCounted
var _dep_harvest_orders: Object
var _dep_interaction_paths: Object
var _dep_officer_teams: Object
func _init(h: Object) -> void:
	_state = h.state
	_dep_ai_economy = h.ai_economy
	_effects = h.effects
	_dep_harvest_orders = h.harvest_orders
	_dep_interaction_paths = h.interaction_paths
	_dep_officer_teams = h.officer_teams
func balance(owner: int) -> Dictionary:
	return player_resources() if owner == _state.player_owner else _dep_ai_economy._ai_res_of(owner).duplicate()
func write(owner: int, value: Dictionary) -> void:
	if owner == _state.player_owner:
		write_player_resources(value)
	elif not balance(owner).is_empty(): _dep_ai_economy.replace_balance(owner, value)
func write_player_resources(value: Dictionary) -> void:
	_state.gold = float(value.get("gold", 0))
	_state.wood = float(value.get("wood", 0))
	_state.food = float(value.get("food", 0))
	_state.stone = float(value.get("stone", 0))

func can_pay(owner: int, cost: Dictionary) -> bool:
	var res := balance(owner)
	if res.is_empty(): return false
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
	if not is_finite(amount) or amount <= 0 or amount > float(Balance.harvest().carryCapacity) or kind not in KINDS: return false
	var nearby := false
	for depot in _dep_harvest_orders._deposits_for(worker, kind):
		if _dep_interaction_paths._deposit_ready(worker, depot):
			nearby = true
			break
	if not nearby: return false
	var owner := int(worker.owner)
	var res := balance(owner)
	if kind == "food" and float(res.food) + amount > _dep_harvest_orders._food_capacity(owner):
		if owner == _state.player_owner: _effects.feedback("粮食已满（容量 %d），工人保留携带资源" % _dep_harvest_orders._food_capacity(owner))
		return false
	res[kind] = float(res[kind]) + amount
	write(owner, res)
	worker.carry = 0.0; worker.carry_kind = ""; worker.gather_t = 0.0
	_dep_officer_teams._grant_officer_exp(worker,1)
	return true

func player_resources() -> Dictionary:
	return {"gold":_state.gold, "wood":_state.wood, "food":_state.food, "stone":_state.stone}
