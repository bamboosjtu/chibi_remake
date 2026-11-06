extends "res://named_port.gd"
## production: explicit callable dependencies; no battle scene reference.


func _building_work_busy(building: Dictionary) -> bool:
	return _require(_provider_technology, "technology")._building_work_busy(building)

func _feedback(msg: String) -> void:
	_require(_provider_battle_simulation, "battle_simulation")._feedback(msg)

func _sheet_ref_for(unit_id: int, owner: int) -> String:
	return _require(_provider_entity_factory, "entity_factory")._sheet_ref_for(unit_id, owner)

func _spawn_unit(unit_id: int, owner: int, ax: float, ay: float, restoring := false) -> bool:
	return _require(_provider_entity_factory, "entity_factory")._spawn_unit(unit_id, owner, ax, ay, restoring)

func _unit_name(unit_id: int) -> String:
	return _require(_provider_campaign, "campaign")._unit_name(unit_id)

func ai_level(owner: int) -> int:
	return _require(_provider_ai_economy, "ai_economy").ai_level(owner)

func ai_unit_cost(unit_id: int) -> Dictionary:
	return _require(_provider_ai_economy, "ai_economy").ai_unit_cost(unit_id)

const CONTRACTS := {"ai_economy": ["ai_level", "ai_unit_cost"], "battle_simulation": ["_feedback"], "campaign": ["_unit_name"], "entity_factory": ["_sheet_ref_for", "_spawn_unit"], "technology": ["_building_work_busy"]}
var _provider_ai_economy: WeakRef
var _provider_battle_simulation: WeakRef
var _provider_campaign: WeakRef
var _provider_entity_factory: WeakRef
var _provider_technology: WeakRef

func connect_services(services: Dictionary) -> Array:
	var missing: Array = []
	_provider_ai_economy = weakref(services["ai_economy"]) if services.has("ai_economy") else null
	_provider_battle_simulation = weakref(services["battle_simulation"]) if services.has("battle_simulation") else null
	_provider_campaign = weakref(services["campaign"]) if services.has("campaign") else null
	_provider_entity_factory = weakref(services["entity_factory"]) if services.has("entity_factory") else null
	_provider_technology = weakref(services["technology"]) if services.has("technology") else null
	for provider in CONTRACTS:
		for method in CONTRACTS[provider]:
			if not services.has(provider) or not services[provider].has_method(method): missing.append({"provider":provider,"method":method})
	return missing

func disconnect_services() -> void:
	_provider_ai_economy = null
	_provider_battle_simulation = null
	_provider_campaign = null
	_provider_entity_factory = null
	_provider_technology = null
