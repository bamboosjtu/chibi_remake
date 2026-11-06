extends "res://named_port.gd"
## entity_factory: explicit callable dependencies; no battle scene reference.


func _apply_tech_bonuses(u: Dictionary) -> void:
	_require(_provider_technology, "technology")._apply_tech_bonuses(u)

func _army_count(owner: int) -> int:
	return _require(_provider_production, "production")._army_count(owner)

func _free_unit_cell(cell: Vector2i, layer := 0, exclude_uid := -1, unit_id := -1, max_radius := 12) -> Vector2i:
	return _require(_provider_spatial_index, "spatial_index")._free_unit_cell(cell, layer, exclude_uid, unit_id, max_radius)

func _index_remember(u: Dictionary) -> void:
	_require(_provider_spatial_index, "spatial_index")._index_remember(u)

func _nav_layer(u: Dictionary) -> int:
	return _require(_provider_command_groups, "command_groups")._nav_layer(u)

func _place_unit(u: Dictionary) -> void:
	_require(_provider_battle_simulation, "battle_simulation")._place_unit(u)

func _sheet_ref_for(unit_id: int, owner: int) -> String:
	return _require(_provider_entity_factory, "entity_factory")._sheet_ref_for(unit_id, owner)

func _target_sync(u: Dictionary) -> void:
	_require(_provider_spatial_index, "spatial_index")._target_sync(u)

const CONTRACTS := {"battle_simulation": ["_place_unit"], "command_groups": ["_nav_layer"], "entity_factory": ["_sheet_ref_for"], "production": ["_army_count"], "spatial_index": ["_free_unit_cell", "_index_remember", "_target_sync"], "technology": ["_apply_tech_bonuses"]}
var _provider_battle_simulation: WeakRef
var _provider_command_groups: WeakRef
var _provider_entity_factory: WeakRef
var _provider_production: WeakRef
var _provider_spatial_index: WeakRef
var _provider_technology: WeakRef

func connect_services(services: Dictionary) -> Array:
	var missing: Array = []
	_provider_battle_simulation = weakref(services["battle_simulation"]) if services.has("battle_simulation") else null
	_provider_command_groups = weakref(services["command_groups"]) if services.has("command_groups") else null
	_provider_entity_factory = weakref(services["entity_factory"]) if services.has("entity_factory") else null
	_provider_production = weakref(services["production"]) if services.has("production") else null
	_provider_spatial_index = weakref(services["spatial_index"]) if services.has("spatial_index") else null
	_provider_technology = weakref(services["technology"]) if services.has("technology") else null
	for provider in CONTRACTS:
		for method in CONTRACTS[provider]:
			if not services.has(provider) or not services[provider].has_method(method): missing.append({"provider":provider,"method":method})
	return missing

func disconnect_services() -> void:
	_provider_battle_simulation = null
	_provider_command_groups = null
	_provider_entity_factory = null
	_provider_production = null
	_provider_spatial_index = null
	_provider_technology = null
