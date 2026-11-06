extends "res://named_port.gd"
## combat: explicit callable dependencies; no battle scene reference.


func _cell_of_px(px: float, py: float) -> Vector2i:
	return _require(_provider_movement, "movement")._cell_of_px(px, py)

func _commander_for(u: Dictionary) -> Dictionary:
	return _require(_provider_command_groups, "command_groups")._commander_for(u)

func _fade_unit(u: Dictionary, alpha: float) -> void:
	_require(_provider_battle_simulation, "battle_simulation")._fade_unit(u, alpha)

func _finish_death(u: Dictionary) -> void:
	_require(_provider_battle_simulation, "battle_simulation")._finish_death(u)

func _footprint_cells(o: Dictionary) -> Array:
	return _require(_provider_interaction_paths, "interaction_paths")._footprint_cells(o)

func _grant_officer_exp(u: Dictionary, amount: float) -> void:
	_require(_provider_officer_teams, "officer_teams")._grant_officer_exp(u, amount)

func _index_ensure_current() -> void:
	_require(_provider_spatial_index, "spatial_index")._index_ensure_current()

func _index_forget(u: Dictionary) -> void:
	_require(_provider_spatial_index, "spatial_index")._index_forget(u)

func _nav_layer(u: Dictionary) -> int:
	return _require(_provider_command_groups, "command_groups")._nav_layer(u)

func _reset_jimou() -> void:
	_require(_provider_abilities, "abilities")._reset_jimou()

func _set_frame(u: Dictionary, f: int) -> void:
	_require(_provider_battle_simulation, "battle_simulation")._set_frame(u, f)

func _target_forget(u: Dictionary) -> void:
	_require(_provider_spatial_index, "spatial_index")._target_forget(u)

func _unassign_officer(u: Dictionary) -> void:
	_require(_provider_officer_teams, "officer_teams")._unassign_officer(u)

const CONTRACTS := {"abilities": ["_reset_jimou"], "battle_simulation": ["_fade_unit", "_finish_death", "_set_frame"], "command_groups": ["_commander_for", "_nav_layer"], "interaction_paths": ["_footprint_cells"], "movement": ["_cell_of_px"], "officer_teams": ["_grant_officer_exp", "_unassign_officer"], "spatial_index": ["_index_ensure_current", "_index_forget", "_target_forget"]}
var _provider_abilities: WeakRef
var _provider_battle_simulation: WeakRef
var _provider_command_groups: WeakRef
var _provider_interaction_paths: WeakRef
var _provider_movement: WeakRef
var _provider_officer_teams: WeakRef
var _provider_spatial_index: WeakRef

func connect_services(services: Dictionary) -> Array:
	var missing: Array = []
	_provider_abilities = weakref(services["abilities"]) if services.has("abilities") else null
	_provider_battle_simulation = weakref(services["battle_simulation"]) if services.has("battle_simulation") else null
	_provider_command_groups = weakref(services["command_groups"]) if services.has("command_groups") else null
	_provider_interaction_paths = weakref(services["interaction_paths"]) if services.has("interaction_paths") else null
	_provider_movement = weakref(services["movement"]) if services.has("movement") else null
	_provider_officer_teams = weakref(services["officer_teams"]) if services.has("officer_teams") else null
	_provider_spatial_index = weakref(services["spatial_index"]) if services.has("spatial_index") else null
	for provider in CONTRACTS:
		for method in CONTRACTS[provider]:
			if not services.has(provider) or not services[provider].has_method(method): missing.append({"provider":provider,"method":method})
	return missing

func disconnect_services() -> void:
	_provider_abilities = null
	_provider_battle_simulation = null
	_provider_command_groups = null
	_provider_interaction_paths = null
	_provider_movement = null
	_provider_officer_teams = null
	_provider_spatial_index = null
