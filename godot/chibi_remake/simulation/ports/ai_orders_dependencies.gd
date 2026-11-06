extends "res://named_port.gd"
## ai_orders: explicit callable dependencies; no battle scene reference.


func _ai_forming(u: Dictionary) -> bool:
	return _require(_provider_ai_economy, "ai_economy")._ai_forming(u)

func _cancel_unit_command(u: Dictionary) -> void:
	_require(_provider_command_groups, "command_groups")._cancel_unit_command(u)

func _hostile_owners(a: int, b: int) -> bool:
	return _require(_provider_combat, "combat")._hostile_owners(a, b)

func _path_to(u: Dictionary, target_px: Vector2, exact: bool) -> Array:
	return _require(_provider_movement, "movement")._path_to(u, target_px, exact)

func _working_construction_team(unit: Dictionary) -> bool:
	return _require(_provider_ai_economy, "ai_economy")._working_construction_team(unit)

func _yield_of(unit_id: int) -> String:
	return _require(_provider_harvest_orders, "harvest_orders")._yield_of(unit_id)

func ai_group_of(u: Dictionary) -> int:
	return _require(_provider_ai_economy, "ai_economy").ai_group_of(u)

func ai_production_building(owner: int, requested_unit := -1) -> Dictionary:
	return _require(_provider_ai_economy, "ai_economy").ai_production_building(owner, requested_unit)

const CONTRACTS := {"ai_economy": ["_ai_forming", "_working_construction_team", "ai_group_of", "ai_production_building"], "combat": ["_hostile_owners"], "command_groups": ["_cancel_unit_command"], "harvest_orders": ["_yield_of"], "movement": ["_path_to"]}
var _provider_ai_economy: WeakRef
var _provider_combat: WeakRef
var _provider_command_groups: WeakRef
var _provider_harvest_orders: WeakRef
var _provider_movement: WeakRef

func connect_services(services: Dictionary) -> Array:
	var missing: Array = []
	_provider_ai_economy = weakref(services["ai_economy"]) if services.has("ai_economy") else null
	_provider_combat = weakref(services["combat"]) if services.has("combat") else null
	_provider_command_groups = weakref(services["command_groups"]) if services.has("command_groups") else null
	_provider_harvest_orders = weakref(services["harvest_orders"]) if services.has("harvest_orders") else null
	_provider_movement = weakref(services["movement"]) if services.has("movement") else null
	for provider in CONTRACTS:
		for method in CONTRACTS[provider]:
			if not services.has(provider) or not services[provider].has_method(method): missing.append({"provider":provider,"method":method})
	return missing

func disconnect_services() -> void:
	_provider_ai_economy = null
	_provider_combat = null
	_provider_command_groups = null
	_provider_harvest_orders = null
	_provider_movement = null
