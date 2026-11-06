extends "res://named_port.gd"
## ai_orders: explicit callable dependencies; no battle scene reference.


func _ai_forming(u: Dictionary) -> bool:
	var provider = _require(_provider_ai_economy, "ai_economy")
	if provider == null: return false
	return provider._ai_forming(u)

func _cancel_unit_command(u: Dictionary) -> void:
	var provider = _require(_provider_command_groups, "command_groups")
	if provider == null: return
	provider._cancel_unit_command(u)

func _hostile_owners(a: int, b: int) -> bool:
	var provider = _require(_provider_combat, "combat")
	if provider == null: return false
	return provider._hostile_owners(a, b)

func _path_to(u: Dictionary, target_px: Vector2, exact: bool) -> Array:
	var provider = _require(_provider_movement, "movement")
	if provider == null: return []
	return provider._path_to(u, target_px, exact)

func _working_construction_team(unit: Dictionary) -> bool:
	var provider = _require(_provider_ai_economy, "ai_economy")
	if provider == null: return false
	return provider._working_construction_team(unit)

func _yield_of(unit_id: int) -> String:
	var provider = _require(_provider_harvest_orders, "harvest_orders")
	if provider == null: return ""
	return provider._yield_of(unit_id)

func ai_group_of(u: Dictionary) -> int:
	var provider = _require(_provider_ai_economy, "ai_economy")
	if provider == null: return 0
	return provider.ai_group_of(u)

func ai_production_building(owner: int, requested_unit := -1) -> Dictionary:
	var provider = _require(_provider_ai_economy, "ai_economy")
	if provider == null: return {}
	return provider.ai_production_building(owner, requested_unit)

const CONTRACTS := {"ai_economy": ["_ai_forming", "_working_construction_team", "ai_group_of", "ai_production_building"], "combat": ["_hostile_owners"], "command_groups": ["_cancel_unit_command"], "harvest_orders": ["_yield_of"], "movement": ["_path_to"]}
var _provider_ai_economy: WeakRef
var _provider_combat: WeakRef
var _provider_command_groups: WeakRef
var _provider_harvest_orders: WeakRef
var _provider_movement: WeakRef

func connect_services(services: Dictionary) -> Array:
	var missing: Array = []
	_provider_ai_economy = weakref(services["ai_economy"]) if services.get("ai_economy") != null else null
	_provider_combat = weakref(services["combat"]) if services.get("combat") != null else null
	_provider_command_groups = weakref(services["command_groups"]) if services.get("command_groups") != null else null
	_provider_harvest_orders = weakref(services["harvest_orders"]) if services.get("harvest_orders") != null else null
	_provider_movement = weakref(services["movement"]) if services.get("movement") != null else null
	for provider in CONTRACTS:
		for method in CONTRACTS[provider]:
			if services.get(provider) == null or not services[provider].has_method(method): missing.append({"provider":provider,"method":method})
	return missing

func disconnect_services() -> void:
	_provider_ai_economy = null
	_provider_combat = null
	_provider_command_groups = null
	_provider_harvest_orders = null
	_provider_movement = null
