extends "res://named_port.gd"
## ai_economy: explicit callable dependencies; no battle scene reference.


func _ai_side(owner: int) -> Dictionary:
	var provider = _require(_provider_technology, "technology")
	if provider == null: return {}
	return provider._ai_side(owner)

func _building_work_busy(building: Dictionary) -> bool:
	var provider = _require(_provider_technology, "technology")
	if provider == null: return false
	return provider._building_work_busy(building)

func _combat_member_count(owner: int) -> int:
	var provider = _require(_provider_technology, "technology")
	if provider == null: return 0
	return provider._combat_member_count(owner)

func _commander_for(u: Dictionary) -> Dictionary:
	var provider = _require(_provider_command_groups, "command_groups")
	if provider == null: return {}
	return provider._commander_for(u)

func _construction_workers(commander: Dictionary) -> Array:
	var provider = _require(_provider_command_groups, "command_groups")
	if provider == null: return []
	return provider._construction_workers(commander)

func _queue_research(owner: int, building: Dictionary, idx: int, ai_dispatch := false) -> bool:
	var provider = _require(_provider_technology, "technology")
	if provider == null: return false
	return provider._queue_research(owner, building, idx, ai_dispatch)

func _queue_train(owner: int, building: Dictionary, uid: int) -> bool:
	var provider = _require(_provider_production, "production")
	if provider == null: return false
	return provider._queue_train(owner, building, uid)

func _tech_for(owner: int) -> Dictionary:
	var provider = _require(_provider_technology, "technology")
	if provider == null: return {}
	return provider._tech_for(owner)

func _tech_line_of(idx: int) -> String:
	var provider = _require(_provider_technology, "technology")
	if provider == null: return ""
	return provider._tech_line_of(idx)

func ai_tech_gate(owner: int) -> int:
	var provider = _require(_provider_technology, "technology")
	if provider == null: return 0
	return provider.ai_tech_gate(owner)

func building_block_reason(bid: int, owner: int = -1) -> String:
	var provider = _require(_provider_construction_orders, "construction_orders")
	if provider == null: return ""
	return provider.building_block_reason(bid, owner)

func train_types_for(bid: int, owner: int = -1) -> Array:
	var provider = _require(_provider_production, "production")
	if provider == null: return []
	return provider.train_types_for(bid, owner)

const CONTRACTS := {"command_groups": ["_commander_for", "_construction_workers"], "production": ["_queue_train", "train_types_for"], "technology": ["_ai_side", "_building_work_busy", "_combat_member_count", "_queue_research", "_tech_for", "_tech_line_of", "ai_tech_gate"], "construction_orders": ["building_block_reason"]}
var _provider_command_groups: WeakRef
var _provider_production: WeakRef
var _provider_technology: WeakRef
var _provider_construction_orders: WeakRef

func connect_services(services: Dictionary) -> Array:
	var missing: Array = []
	_provider_command_groups = weakref(services["command_groups"]) if services.get("command_groups") != null else null
	_provider_production = weakref(services["production"]) if services.get("production") != null else null
	_provider_technology = weakref(services["technology"]) if services.get("technology") != null else null
	_provider_construction_orders = weakref(services["construction_orders"]) if services.get("construction_orders") != null else null
	for provider in CONTRACTS:
		for method in CONTRACTS[provider]:
			if services.get(provider) == null or not services[provider].has_method(method): missing.append({"provider":provider,"method":method})
	return missing

func disconnect_services() -> void:
	_provider_command_groups = null
	_provider_production = null
	_provider_technology = null
	_provider_construction_orders = null
