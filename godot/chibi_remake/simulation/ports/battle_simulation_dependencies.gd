extends "res://named_port.gd"
## battle_simulation: explicit callable dependencies; no battle scene reference.


func _check_end() -> void:
	var provider = _require(_provider_campaign, "campaign")
	if provider == null: return
	provider._check_end()

func _die_step(u: Dictionary, delta: float) -> void:
	var provider = _require(_provider_combat, "combat")
	if provider == null: return
	provider._die_step(u, delta)

func _index_forget(u: Dictionary) -> void:
	var provider = _require(_provider_spatial_index, "spatial_index")
	if provider == null: return
	provider._index_forget(u)

func _index_sync(u: Dictionary) -> void:
	var provider = _require(_provider_spatial_index, "spatial_index")
	if provider == null: return
	provider._index_sync(u)

func _process_officer_recovery() -> void:
	var provider = _require(_provider_officer_teams, "officer_teams")
	if provider == null: return
	provider._process_officer_recovery()

func _process_sites(_delta: float) -> void:
	var provider = _require(_provider_construction_orders, "construction_orders")
	if provider == null: return
	provider._process_sites(_delta)

func _process_tech(_delta: float) -> void:
	var provider = _require(_provider_technology, "technology")
	if provider == null: return
	provider._process_tech(_delta)

func _process_trainings(_delta: float) -> void:
	var provider = _require(_provider_production, "production")
	if provider == null: return
	provider._process_trainings(_delta)

func _step_unit(u: Dictionary, delta: float) -> void:
	var provider = _require(_provider_unit_actions, "unit_actions")
	if provider == null: return
	provider._step_unit(u, delta)

func _target_forget(u: Dictionary) -> void:
	var provider = _require(_provider_spatial_index, "spatial_index")
	if provider == null: return
	provider._target_forget(u)

func _target_sync(u: Dictionary) -> void:
	var provider = _require(_provider_spatial_index, "spatial_index")
	if provider == null: return
	provider._target_sync(u)

func _unassign_officer(u: Dictionary) -> void:
	var provider = _require(_provider_officer_teams, "officer_teams")
	if provider == null: return
	provider._unassign_officer(u)

func _step_auto_control() -> void:
	var provider = _require(_provider_cheat_rules, "cheat_rules")
	if provider == null: return
	provider._step_auto_control()

const CONTRACTS := {"campaign": ["_check_end"], "cheat_rules": ["_step_auto_control"], "combat": ["_die_step"], "construction_orders": ["_process_sites"], "officer_teams": ["_process_officer_recovery", "_unassign_officer"], "production": ["_process_trainings"], "spatial_index": ["_index_forget", "_index_sync", "_target_forget", "_target_sync"], "technology": ["_process_tech"], "unit_actions": ["_step_unit"]}
var _provider_campaign: WeakRef
var _provider_cheat_rules: WeakRef
var _provider_combat: WeakRef
var _provider_construction_orders: WeakRef
var _provider_officer_teams: WeakRef
var _provider_production: WeakRef
var _provider_spatial_index: WeakRef
var _provider_technology: WeakRef
var _provider_unit_actions: WeakRef

func connect_services(services: Dictionary) -> Array:
	var missing: Array = []
	_provider_campaign = weakref(services["campaign"]) if services.get("campaign") != null else null
	_provider_cheat_rules = weakref(services["cheat_rules"]) if services.get("cheat_rules") != null else null
	_provider_combat = weakref(services["combat"]) if services.get("combat") != null else null
	_provider_construction_orders = weakref(services["construction_orders"]) if services.get("construction_orders") != null else null
	_provider_officer_teams = weakref(services["officer_teams"]) if services.get("officer_teams") != null else null
	_provider_production = weakref(services["production"]) if services.get("production") != null else null
	_provider_spatial_index = weakref(services["spatial_index"]) if services.get("spatial_index") != null else null
	_provider_technology = weakref(services["technology"]) if services.get("technology") != null else null
	_provider_unit_actions = weakref(services["unit_actions"]) if services.get("unit_actions") != null else null
	for provider in CONTRACTS:
		for method in CONTRACTS[provider]:
			if services.get(provider) == null or not services[provider].has_method(method): missing.append({"provider":provider,"method":method})
	return missing

func disconnect_services() -> void:
	_provider_campaign = null
	_provider_cheat_rules = null
	_provider_combat = null
	_provider_construction_orders = null
	_provider_officer_teams = null
	_provider_production = null
	_provider_spatial_index = null
	_provider_technology = null
	_provider_unit_actions = null
