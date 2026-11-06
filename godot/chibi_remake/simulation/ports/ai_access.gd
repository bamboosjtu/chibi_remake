extends "res://named_port.gd"
## ai: only the state and commands required by this system.
const State = preload("res://simulation/battle_state.gd")
const Config = preload("res://simulation/battle_config.gd")
var _state: WeakRef
var battle: State:
	get: return _state.get_ref()

func _init(data: State) -> void:
	_state = weakref(data)


var map_id:
	get: return battle.map_id
	set(value): battle.map_id = value

var player_owner:
	get: return battle.player_owner
	set(value): battle.player_owner = value

var scenario_mission:
	get: return battle.scenario_mission
	set(value): battle.scenario_mission = value

var trainings:
	get: return battle.trainings
	set(value): battle.trainings = value

var units:
	get: return battle.units
	set(value): battle.units = value

func _cancel_training(building: Dictionary) -> bool:
	return _require(_provider_production, "production")._cancel_training(building)

func _cancel_unit_command(u: Dictionary) -> void:
	_require(_provider_command_groups, "command_groups")._cancel_unit_command(u)

func _construction_workers(commander: Dictionary) -> Array:
	return _require(_provider_command_groups, "command_groups")._construction_workers(commander)

func _hostile_owners(a: int, b: int) -> bool:
	return _require(_provider_combat, "combat")._hostile_owners(a, b)

func _is_hero_unit(u: Dictionary) -> bool:
	return _require(_provider_command_groups, "command_groups")._is_hero_unit(u)

func _naval_research_gate(_owner: int) -> bool:
	return _require(_provider_ai_economy, "ai_economy")._naval_research_gate(_owner)

func _path_to(u: Dictionary, target_px: Vector2, exact: bool) -> Array:
	return _require(_provider_movement, "movement")._path_to(u, target_px, exact)

func _queue_research(owner: int, building: Dictionary, idx: int, ai_dispatch := false) -> bool:
	return _require(_provider_technology, "technology")._queue_research(owner, building, idx, ai_dispatch)

func _queue_train(owner: int, building: Dictionary, uid: int) -> bool:
	return _require(_provider_production, "production")._queue_train(owner, building, uid)

func _tech_line_of(idx: int) -> String:
	return _require(_provider_technology, "technology")._tech_line_of(idx)

func _tech_line_pos(idx: int) -> int:
	return _require(_provider_technology, "technology")._tech_line_pos(idx)

func _tech_line_progress(line: String, owner := -1) -> int:
	return _require(_provider_technology, "technology")._tech_line_progress(line, owner)

func ai_behavior(owner: int) -> int:
	return _require(_provider_ai_economy, "ai_economy").ai_behavior(owner)

func ai_building_kinds(owner: int) -> Array:
	return _require(_provider_ai_economy, "ai_economy").ai_building_kinds(owner)

func ai_can_afford(owner: int, cost: Dictionary) -> bool:
	return _require(_provider_ai_economy, "ai_economy").ai_can_afford(owner, cost)

func ai_can_build(owner: int, building_type: int) -> bool:
	return _require(_provider_ai_economy, "ai_economy").ai_can_build(owner, building_type)

func ai_construction_commander(owner: int) -> Dictionary:
	return _require(_provider_ai_economy, "ai_economy").ai_construction_commander(owner)

func ai_construction_kinds(owner: int) -> Array:
	return _require(_provider_ai_economy, "ai_economy").ai_construction_kinds(owner)

func ai_enqueue_train(owner: int, b: Dictionary, unit_id: int, _cost: Dictionary) -> bool:
	return _require(_provider_ai_economy, "ai_economy").ai_enqueue_train(owner, b, unit_id, _cost)

func ai_focus_unit(owner: int) -> Dictionary:
	return _require(_provider_ai_orders, "ai_orders").ai_focus_unit(owner)

func ai_force_units(owner: int) -> int:
	return _require(_provider_ai_economy, "ai_economy").ai_force_units(owner)

func ai_gift(owner: int, wood: float, food: float, stone: float) -> void:
	_require(_provider_ai_economy, "ai_economy").ai_gift(owner, wood, food, stone)

func ai_gold(owner: int) -> float:
	return _require(_provider_ai_economy, "ai_economy").ai_gold(owner)

func ai_group_of(u: Dictionary) -> int:
	return _require(_provider_ai_economy, "ai_economy").ai_group_of(u)

func ai_level(owner: int) -> int:
	return _require(_provider_ai_economy, "ai_economy").ai_level(owner)

func ai_order_assault(owner: int, skip_groups: Array = []) -> void:
	_require(_provider_ai_orders, "ai_orders").ai_order_assault(owner, skip_groups)

func ai_order_assault_l1(owner: int, skip_groups: Array = []) -> void:
	_require(_provider_ai_orders, "ai_orders").ai_order_assault_l1(owner, skip_groups)

func ai_order_intercept(owner: int, focus: Dictionary, radius: float, skip_groups: Array = []) -> void:
	_require(_provider_ai_orders, "ai_orders").ai_order_intercept(owner, focus, radius, skip_groups)

func ai_order_rally(owner: int, skip_groups: Array = []) -> void:
	_require(_provider_ai_orders, "ai_orders").ai_order_rally(owner, skip_groups)

func ai_owners() -> Array:
	return _require(_provider_ai_economy, "ai_economy").ai_owners()

func ai_place_building(owner: int, building_type: int, commander: Dictionary = {}) -> bool:
	return _require(_provider_construction_orders, "construction_orders").ai_place_building(owner, building_type, commander)

func ai_production_building(owner: int, requested_unit := -1) -> Dictionary:
	return _require(_provider_ai_economy, "ai_economy").ai_production_building(owner, requested_unit)

func ai_queue_hq_upgrade(owner: int) -> bool:
	return _require(_provider_ai_economy, "ai_economy").ai_queue_hq_upgrade(owner)

func ai_research_building(owner: int, idx: int) -> Dictionary:
	return _require(_provider_ai_economy, "ai_economy").ai_research_building(owner, idx)

func ai_set_gold(owner: int, v: float) -> void:
	_require(_provider_ai_economy, "ai_economy").ai_set_gold(owner, v)

func ai_tech_gate(owner: int) -> int:
	return _require(_provider_technology, "technology").ai_tech_gate(owner)

func ai_unit_cost(unit_id: int) -> Dictionary:
	return _require(_provider_ai_economy, "ai_economy").ai_unit_cost(unit_id)

func ai_worker_count(owner: int) -> int:
	return _require(_provider_ai_economy, "ai_economy").ai_worker_count(owner)

const CONTRACTS := {"ai_economy": ["_naval_research_gate", "ai_behavior", "ai_building_kinds", "ai_can_afford", "ai_can_build", "ai_construction_commander", "ai_construction_kinds", "ai_enqueue_train", "ai_force_units", "ai_gift", "ai_gold", "ai_group_of", "ai_level", "ai_owners", "ai_production_building", "ai_queue_hq_upgrade", "ai_research_building", "ai_set_gold", "ai_unit_cost", "ai_worker_count"], "ai_orders": ["ai_focus_unit", "ai_order_assault", "ai_order_assault_l1", "ai_order_intercept", "ai_order_rally"], "combat": ["_hostile_owners"], "command_groups": ["_cancel_unit_command", "_construction_workers", "_is_hero_unit"], "construction_orders": ["ai_place_building"], "movement": ["_path_to"], "production": ["_cancel_training", "_queue_train"], "technology": ["_queue_research", "_tech_line_of", "_tech_line_pos", "_tech_line_progress", "ai_tech_gate"]}
var _provider_ai_economy: WeakRef
var _provider_ai_orders: WeakRef
var _provider_combat: WeakRef
var _provider_command_groups: WeakRef
var _provider_construction_orders: WeakRef
var _provider_movement: WeakRef
var _provider_production: WeakRef
var _provider_technology: WeakRef

func connect_services(services: Dictionary) -> Array:
	var missing: Array = []
	_provider_ai_economy = weakref(services["ai_economy"]) if services.has("ai_economy") else null
	_provider_ai_orders = weakref(services["ai_orders"]) if services.has("ai_orders") else null
	_provider_combat = weakref(services["combat"]) if services.has("combat") else null
	_provider_command_groups = weakref(services["command_groups"]) if services.has("command_groups") else null
	_provider_construction_orders = weakref(services["construction_orders"]) if services.has("construction_orders") else null
	_provider_movement = weakref(services["movement"]) if services.has("movement") else null
	_provider_production = weakref(services["production"]) if services.has("production") else null
	_provider_technology = weakref(services["technology"]) if services.has("technology") else null
	for provider in CONTRACTS:
		for method in CONTRACTS[provider]:
			if not services.has(provider) or not services[provider].has_method(method): missing.append({"provider":provider,"method":method})
	return missing

func disconnect_services() -> void:
	_provider_ai_economy = null
	_provider_ai_orders = null
	_provider_combat = null
	_provider_command_groups = null
	_provider_construction_orders = null
	_provider_movement = null
	_provider_production = null
	_provider_technology = null
