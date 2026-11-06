extends "res://named_port.gd"
## economy: explicit commands, validated once at the composition boundary.
const CONTRACTS := {"production": ["_army_count", "_cancel_training", "_commander_count", "_process_trainings", "_queue_train", "_start_train", "_train_list_for_selection", "train_types_for"], "construction_orders": ["_assign_build_worker", "_build_site_at", "_cancel_site", "_complete_site", "_do_repair", "_order_repair", "_place_building", "_process_sites", "_site_entry_path", "_start_build", "_valid_build_worker", "ai_place_building", "build_placement_at", "building_block_reason"], "harvest_orders": ["_begin_gather", "_build_decor_targets", "_deposit_carry", "_deposits_for", "_food_capacity", "_nearby_same_resource", "_nearest_deposit", "_nearest_harvest_by_path", "_nearest_resource", "_order_gather", "_order_gather_nearest", "_remove_decor", "_resource_at", "_selected_workers", "_yield_of"], "ai_economy": ["_ai_forming", "_ai_res_of", "_dock_can_launch", "ai_construction_commander", "ai_disband_slot", "ai_level", "ai_owners", "ai_queue_hq_upgrade", "ai_set_gold", "ai_unit_cost"]}
var _provider_production: WeakRef
var _provider_construction_orders: WeakRef
var _provider_harvest_orders: WeakRef
var _provider_ai_economy: WeakRef

func train_types_for(bid: int, owner: int = -1) -> Array:
	var provider = _require(_provider_production, "production")
	if provider == null: return []
	return provider.train_types_for(bid, owner)

func _train_list_for_selection() -> Array:
	var provider = _require(_provider_production, "production")
	if provider == null: return []
	return provider._train_list_for_selection()

func building_block_reason(bid: int, owner: int = -1) -> String:
	var provider = _require(_provider_construction_orders, "construction_orders")
	if provider == null: return ""
	return provider.building_block_reason(bid, owner)

func _yield_of(unit_id: int) -> String:
	var provider = _require(_provider_harvest_orders, "harvest_orders")
	if provider == null: return ""
	return provider._yield_of(unit_id)

func _build_decor_targets() -> void:
	var provider = _require(_provider_harvest_orders, "harvest_orders")
	if provider == null: return
	provider._build_decor_targets()

func _nearest_resource(pos: Vector2) -> Dictionary:
	var provider = _require(_provider_harvest_orders, "harvest_orders")
	if provider == null: return {}
	return provider._nearest_resource(pos)

func _nearest_deposit(owner: int, pos: Vector2) -> Dictionary:
	var provider = _require(_provider_harvest_orders, "harvest_orders")
	if provider == null: return {}
	return provider._nearest_deposit(owner, pos)

func _selected_workers() -> Array:
	var provider = _require(_provider_harvest_orders, "harvest_orders")
	if provider == null: return []
	return provider._selected_workers()

func _order_gather_nearest() -> int:
	var provider = _require(_provider_harvest_orders, "harvest_orders")
	if provider == null: return 0
	return provider._order_gather_nearest()

func _begin_gather(worker: Dictionary, obj: Dictionary, path: Array) -> void:
	var provider = _require(_provider_harvest_orders, "harvest_orders")
	if provider == null: return
	provider._begin_gather(worker, obj, path)

func _order_gather(target_obj: Dictionary) -> int:
	var provider = _require(_provider_harvest_orders, "harvest_orders")
	if provider == null: return 0
	return provider._order_gather(target_obj)

func _nearest_harvest_by_path(worker: Dictionary, kind: String, reserved: Dictionary = {}, exclude: Array = []) -> Dictionary:
	var provider = _require(_provider_harvest_orders, "harvest_orders")
	if provider == null: return {}
	return provider._nearest_harvest_by_path(worker, kind, reserved, exclude)

func _nearby_same_resource(origin_obj: Dictionary, worker: Dictionary, reserved: Dictionary) -> Dictionary:
	var provider = _require(_provider_harvest_orders, "harvest_orders")
	if provider == null: return {}
	return provider._nearby_same_resource(origin_obj, worker, reserved)

func _deposits_for(u: Dictionary, kind: String) -> Array:
	var provider = _require(_provider_harvest_orders, "harvest_orders")
	if provider == null: return []
	return provider._deposits_for(u, kind)

func _food_capacity(owner: int) -> float:
	var provider = _require(_provider_harvest_orders, "harvest_orders")
	if provider == null: return 0.0
	return provider._food_capacity(owner)

func _deposit_carry(u: Dictionary) -> bool:
	var provider = _require(_provider_harvest_orders, "harvest_orders")
	if provider == null: return false
	return provider._deposit_carry(u)

func _remove_decor(obj: Dictionary) -> void:
	var provider = _require(_provider_harvest_orders, "harvest_orders")
	if provider == null: return
	provider._remove_decor(obj)

func _order_repair(target: Dictionary) -> int:
	var provider = _require(_provider_construction_orders, "construction_orders")
	if provider == null: return 0
	return provider._order_repair(target)

func _do_repair(w: Dictionary, t: Dictionary) -> bool:
	var provider = _require(_provider_construction_orders, "construction_orders")
	if provider == null: return false
	return provider._do_repair(w, t)

func _site_entry_path(unit: Dictionary, site: Dictionary, future_cells: Array = []) -> Array:
	var provider = _require(_provider_construction_orders, "construction_orders")
	if provider == null: return []
	return provider._site_entry_path(unit, site, future_cells)

func build_placement_at(pos: Vector2, opt: Dictionary) -> Dictionary:
	var provider = _require(_provider_construction_orders, "construction_orders")
	if provider == null: return {}
	return provider.build_placement_at(pos, opt)

func _assign_build_worker(worker: Dictionary, site: Dictionary) -> bool:
	var provider = _require(_provider_construction_orders, "construction_orders")
	if provider == null: return false
	return provider._assign_build_worker(worker, site)

func _valid_build_worker(worker: Dictionary, site: Dictionary) -> bool:
	var provider = _require(_provider_construction_orders, "construction_orders")
	if provider == null: return false
	return provider._valid_build_worker(worker, site)

func _build_site_at(pos: Vector2, opt: Dictionary) -> bool:
	var provider = _require(_provider_construction_orders, "construction_orders")
	if provider == null: return false
	return provider._build_site_at(pos, opt)

func _complete_site(site: Dictionary) -> void:
	var provider = _require(_provider_construction_orders, "construction_orders")
	if provider == null: return
	provider._complete_site(site)

func _start_build(opt: Dictionary) -> void:
	var provider = _require(_provider_construction_orders, "construction_orders")
	if provider == null: return
	provider._start_build(opt)

func _army_count(owner: int) -> int:
	var provider = _require(_provider_production, "production")
	if provider == null: return 0
	return provider._army_count(owner)

func _commander_count(owner: int) -> int:
	var provider = _require(_provider_production, "production")
	if provider == null: return 0
	return provider._commander_count(owner)

func _queue_train(owner: int, building: Dictionary, uid: int) -> bool:
	var provider = _require(_provider_production, "production")
	if provider == null: return false
	return provider._queue_train(owner, building, uid)

func _start_train(opt: Dictionary) -> void:
	var provider = _require(_provider_production, "production")
	if provider == null: return
	provider._start_train(opt)

func _cancel_training(building: Dictionary) -> bool:
	var provider = _require(_provider_production, "production")
	if provider == null: return false
	return provider._cancel_training(building)

func _cancel_site(site: Dictionary) -> bool:
	var provider = _require(_provider_construction_orders, "construction_orders")
	if provider == null: return false
	return provider._cancel_site(site)

func _process_trainings(_delta: float) -> void:
	var provider = _require(_provider_production, "production")
	if provider == null: return
	provider._process_trainings(_delta)

func _process_sites(_delta: float) -> void:
	var provider = _require(_provider_construction_orders, "construction_orders")
	if provider == null: return
	provider._process_sites(_delta)

func ai_owners() -> Array:
	var provider = _require(_provider_ai_economy, "ai_economy")
	if provider == null: return []
	return provider.ai_owners()

func _ai_res_of(owner: int) -> Dictionary:
	var provider = _require(_provider_ai_economy, "ai_economy")
	if provider == null: return {}
	return provider._ai_res_of(owner)

func ai_construction_commander(owner: int) -> Dictionary:
	var provider = _require(_provider_ai_economy, "ai_economy")
	if provider == null: return {}
	return provider.ai_construction_commander(owner)

func _dock_can_launch(point: Vector2) -> bool:
	var provider = _require(_provider_ai_economy, "ai_economy")
	if provider == null: return false
	return provider._dock_can_launch(point)

func _place_building(owner: int, building_type: int, near_px: Vector2, as_site := false, access_workers: Array = [], exact_anchor := false) -> Dictionary:
	var provider = _require(_provider_construction_orders, "construction_orders")
	if provider == null: return {}
	return provider._place_building(owner, building_type, near_px, as_site, access_workers, exact_anchor)

func ai_place_building(owner: int, building_type: int, commander: Dictionary = {}) -> bool:
	var provider = _require(_provider_construction_orders, "construction_orders")
	if provider == null: return false
	return provider.ai_place_building(owner, building_type, commander)

func ai_set_gold(owner: int, v: float) -> void:
	var provider = _require(_provider_ai_economy, "ai_economy")
	if provider == null: return
	provider.ai_set_gold(owner, v)

func ai_queue_hq_upgrade(owner: int) -> bool:
	var provider = _require(_provider_ai_economy, "ai_economy")
	if provider == null: return false
	return provider.ai_queue_hq_upgrade(owner)

func ai_level(owner: int) -> int:
	var provider = _require(_provider_ai_economy, "ai_economy")
	if provider == null: return 0
	return provider.ai_level(owner)

func ai_unit_cost(unit_id: int) -> Dictionary:
	var provider = _require(_provider_ai_economy, "ai_economy")
	if provider == null: return {}
	return provider.ai_unit_cost(unit_id)

func ai_disband_slot(owner: int, slot: int) -> void:
	var provider = _require(_provider_ai_economy, "ai_economy")
	if provider == null: return
	provider.ai_disband_slot(owner, slot)

func _ai_forming(u: Dictionary) -> bool:
	var provider = _require(_provider_ai_economy, "ai_economy")
	if provider == null: return false
	return provider._ai_forming(u)

func _resource_at(pos: Vector2) -> Dictionary:
	var provider = _require(_provider_harvest_orders, "harvest_orders")
	if provider == null: return {}
	return provider._resource_at(pos)

func connect_services(services: Dictionary) -> Array:
	_provider_production = weakref(services["production"]) if services.get("production") != null else null
	_provider_construction_orders = weakref(services["construction_orders"]) if services.get("construction_orders") != null else null
	_provider_harvest_orders = weakref(services["harvest_orders"]) if services.get("harvest_orders") != null else null
	_provider_ai_economy = weakref(services["ai_economy"]) if services.get("ai_economy") != null else null
	return validate_services(services, CONTRACTS)

func disconnect_services() -> void:
	_provider_production = null
	_provider_construction_orders = null
	_provider_harvest_orders = null
	_provider_ai_economy = null
