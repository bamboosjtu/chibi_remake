extends "res://named_port.gd"
var _provider_cheat_rules: WeakRef
var _provider_duel_controller: WeakRef
var _provider_bootstrap: WeakRef
var _provider_cheat_controller: WeakRef
## Compatibility API for existing tools/UI; main.gd only composes and owns lifecycle.
## Each forwarder names its provider directly, so references remain inspectable.
var _provider_abilities: WeakRef
var _provider_ai_economy: WeakRef
var _provider_ai_orders: WeakRef
var _provider_battle_simulation: WeakRef
var _provider_campaign: WeakRef
var _provider_combat: WeakRef
var _provider_command_groups: WeakRef
var _provider_construction_orders: WeakRef
var _provider_entity_factory: WeakRef
var _provider_harvest_orders: WeakRef
var _provider_interaction_paths: WeakRef
var _provider_movement: WeakRef
var _provider_officer_pool: WeakRef
var _provider_officer_teams: WeakRef
var _provider_production: WeakRef
var _provider_selection: WeakRef
var _provider_spatial_index: WeakRef
var _provider_technology: WeakRef
var _provider_transport_orders: WeakRef
var _provider_unit_actions: WeakRef
var _provider_world_orders: WeakRef
var _provider_scene_controller: WeakRef
func _feedback(msg: String) -> void:
	_require(_provider_battle_simulation, "battle_simulation")._feedback(msg)
func _is_worker_unit(u: Dictionary) -> bool:
	return _require(_provider_technology, "technology")._is_worker_unit(u)
func _ai_side(owner: int) -> Dictionary:
	return _require(_provider_technology, "technology")._ai_side(owner)
func tech_row(idx: int) -> Dictionary:
	return _require(_provider_technology, "technology").tech_row(idx)
func tech_is_sell(idx: int) -> bool:
	return _require(_provider_technology, "technology").tech_is_sell(idx)
func _tech_line_of(idx: int) -> String:
	return _require(_provider_technology, "technology")._tech_line_of(idx)
func tech_is_next(idx: int) -> bool:
	return _require(_provider_technology, "technology").tech_is_next(idx)
func tech_rows_for_building(bid: int) -> Array:
	return _require(_provider_technology, "technology").tech_rows_for_building(bid)
func tech_cost(idx: int) -> Dictionary:
	return _require(_provider_technology, "technology").tech_cost(idx)
func tech_cost_text(idx: int) -> String:
	return _require(_provider_technology, "technology").tech_cost_text(idx)
func tech_effect_desc(idx: int) -> String:
	return _require(_provider_technology, "technology").tech_effect_desc(idx)
func tech_tip(idx: int) -> String:
	return _require(_provider_technology, "technology").tech_tip(idx)
func tech_block_reason(idx: int) -> String:
	return _require(_provider_technology, "technology").tech_block_reason(idx)
func tech_unlocked(idx: int) -> bool:
	return _require(_provider_technology, "technology").tech_unlocked(idx)
func _player_unit_count() -> int:
	return _require(_provider_technology, "technology")._player_unit_count()
func _research_for_building(building: Dictionary) -> Dictionary:
	return _require(_provider_technology, "technology")._research_for_building(building)
func _building_work_busy(building: Dictionary) -> bool:
	return _require(_provider_technology, "technology")._building_work_busy(building)
func _queue_research(owner: int, building: Dictionary, idx: int, ai_dispatch := false) -> bool:
	return _require(_provider_technology, "technology")._queue_research(owner, building, idx, ai_dispatch)
func _start_tech(idx: int) -> bool:
	return _require(_provider_technology, "technology")._start_tech(idx)
func _process_tech(_delta: float) -> void:
	_require(_provider_technology, "technology")._process_tech(_delta)
func _tech_for(owner: int) -> Dictionary:
	return _require(_provider_technology, "technology")._tech_for(owner)
func _apply_tech_effects(idx: int, owner := -1) -> void:
	_require(_provider_technology, "technology")._apply_tech_effects(idx, owner)
func _cancel_tech() -> bool:
	return _require(_provider_technology, "technology")._cancel_tech()
func tech_research_active() -> bool:
	return _require(_provider_technology, "technology").tech_research_active()
func tech_research_name() -> String:
	return _require(_provider_technology, "technology").tech_research_name()
func tech_research_remaining() -> int:
	return _require(_provider_technology, "technology").tech_research_remaining()
func _is_melee_unit(u: Dictionary) -> bool:
	return _require(_provider_technology, "technology")._is_melee_unit(u)
func _apply_tech_bonuses(u: Dictionary) -> void:
	_require(_provider_technology, "technology")._apply_tech_bonuses(u)
func _combat_tech_category(unit_id: int) -> int:
	return _require(_provider_technology, "technology")._combat_tech_category(unit_id)
func _combat_tech_value(key: String, first_row: int, category: int, owner := -1) -> float:
	return _require(_provider_technology, "technology")._combat_tech_value(key, first_row, category, owner)
func _officer_by_index(idx: int) -> Dictionary:
	return _require(_provider_officer_pool, "officer_pool")._officer_by_index(idx)
func _officer_pool_state() -> Dictionary:
	return _require(_provider_officer_pool, "officer_pool")._officer_pool_state()
func _restore_officer_pool(state: Dictionary) -> void:
	_require(_provider_officer_pool, "officer_pool")._restore_officer_pool(state)
func officer_in_use(idx: int) -> bool:
	return _require(_provider_officer_pool, "officer_pool").officer_in_use(idx)
func available_officers(owner: int) -> Array:
	return _require(_provider_officer_pool, "officer_pool").available_officers(owner)
func officers_for_selection(owner: int, sel: Array) -> Array:
	return _require(_provider_officer_pool, "officer_pool").officers_for_selection(owner, sel)
func _resources() -> Dictionary:
	return _require(_provider_battle_simulation, "battle_simulation")._resources()
func _sheet(p: String) -> Texture2D:
	return _require(_provider_scene_controller, "scene_controller")._sheet(p)
func _cell_of_px(px: float, py: float) -> Vector2i:
	return _require(_provider_movement, "movement")._cell_of_px(px, py)
func _anchor_of(a: int, b: int) -> Vector2:
	return _require(_provider_movement, "movement")._anchor_of(a, b)
func _near_walkable(c: Vector2i) -> Vector2i:
	return _require(_provider_movement, "movement")._near_walkable(c)
func _path_to(u: Dictionary, target_px: Vector2, exact: bool) -> Array:
	return _require(_provider_movement, "movement")._path_to(u, target_px, exact)
func train_types_for(bid: int, owner: int = -1) -> Array:
	return _require(_provider_production, "production").train_types_for(bid, owner)
func _train_list_for_selection() -> Array:
	return _require(_provider_production, "production")._train_list_for_selection()
func _sheet_ref_for(unit_id: int, owner: int) -> String:
	return _require(_provider_entity_factory, "entity_factory")._sheet_ref_for(unit_id, owner)
func _spawn_unit(unit_id: int, owner: int, ax: float, ay: float, restoring := false) -> bool:
	return _require(_provider_entity_factory, "entity_factory")._spawn_unit(unit_id, owner, ax, ay, restoring)
func building_block_reason(bid: int, owner: int = -1) -> String:
	return _require(_provider_construction_orders, "construction_orders").building_block_reason(bid, owner)
func cmd_pending_kind() -> String:
	return _require(_provider_world_orders, "world_orders").cmd_pending_kind()
func _clear_pending() -> void:
	_require(_provider_world_orders, "world_orders")._clear_pending()
func _yield_of(unit_id: int) -> String:
	return _require(_provider_harvest_orders, "harvest_orders")._yield_of(unit_id)
func _build_decor_targets() -> void:
	_require(_provider_harvest_orders, "harvest_orders")._build_decor_targets()
func _dist_to_obj(u: Dictionary, o: Dictionary) -> float:
	return _require(_provider_interaction_paths, "interaction_paths")._dist_to_obj(u, o)
func _footprint_cells(o: Dictionary) -> Array:
	return _require(_provider_interaction_paths, "interaction_paths")._footprint_cells(o)
func _edge_cell_distance(u: Dictionary, o: Dictionary) -> int:
	return _require(_provider_interaction_paths, "interaction_paths")._edge_cell_distance(u, o)
func _edge_neighbors(o: Dictionary, exclude_uid := -1, require_free := false, owner := -1) -> Array:
	return _require(_provider_interaction_paths, "interaction_paths")._edge_neighbors(o, exclude_uid, require_free, owner)
func _edge_interaction_path(u: Dictionary, o: Dictionary, reserved := {}, max_body := -1.0) -> Array:
	return _require(_provider_interaction_paths, "interaction_paths")._edge_interaction_path(u, o, reserved, max_body)
func _edge_interaction_choice(u: Dictionary, o: Dictionary, reserved := {}, max_body := -1.0) -> Dictionary:
	return _require(_provider_interaction_paths, "interaction_paths")._edge_interaction_choice(u, o, reserved, max_body)
func _resource_patch_cells(target: Dictionary) -> Array:
	return _require(_provider_interaction_paths, "interaction_paths")._resource_patch_cells(target)
func _resource_patch_interaction_choice(u: Dictionary, target: Dictionary, reserved := {}, known_cells: Array = []) -> Dictionary:
	return _require(_provider_interaction_paths, "interaction_paths")._resource_patch_interaction_choice(u, target, reserved, known_cells)
func _edge_point(o: Dictionary, from_px := Vector2.ZERO, max_body := -1.0, exclude_uid := -1) -> Vector2:
	return _require(_provider_interaction_paths, "interaction_paths")._edge_point(o, from_px, max_body, exclude_uid)
func _unit_cell(u: Dictionary) -> Vector2i:
	return _require(_provider_spatial_index, "spatial_index")._unit_cell(u)
func _cell_unit(cell: Vector2i, exclude_uid := -1, layer := -1) -> Dictionary:
	return _require(_provider_spatial_index, "spatial_index")._cell_unit(cell, exclude_uid, layer)
func _index_eligible(u: Dictionary) -> bool:
	return _require(_provider_spatial_index, "spatial_index")._index_eligible(u)
func _index_sync(u: Dictionary) -> void:
	_require(_provider_spatial_index, "spatial_index")._index_sync(u)
func _rebuild_unit_index() -> void:
	_require(_provider_spatial_index, "spatial_index")._rebuild_unit_index()
func _unit_placement_free(anchor: Vector2i, unit_id: int, layer := 0, exclude_uid := -1) -> bool:
	return _require(_provider_spatial_index, "spatial_index")._unit_placement_free(anchor, unit_id, layer, exclude_uid)
func _free_unit_cell(cell: Vector2i, layer := 0, exclude_uid := -1, unit_id := -1, max_radius := 12) -> Vector2i:
	return _require(_provider_spatial_index, "spatial_index")._free_unit_cell(cell, layer, exclude_uid, unit_id, max_radius)
func _nearest_resource(pos: Vector2) -> Dictionary:
	return _require(_provider_harvest_orders, "harvest_orders")._nearest_resource(pos)
func _nearest_deposit(owner: int, pos: Vector2) -> Dictionary:
	return _require(_provider_harvest_orders, "harvest_orders")._nearest_deposit(owner, pos)
func _selected_workers() -> Array:
	return _require(_provider_harvest_orders, "harvest_orders")._selected_workers()
func _order_gather_nearest() -> int:
	return _require(_provider_harvest_orders, "harvest_orders")._order_gather_nearest()
func _begin_gather(worker: Dictionary, obj: Dictionary, path: Array) -> void:
	_require(_provider_harvest_orders, "harvest_orders")._begin_gather(worker, obj, path)
func _order_gather(target_obj: Dictionary) -> int:
	return _require(_provider_harvest_orders, "harvest_orders")._order_gather(target_obj)
func _nearest_harvest_by_path(worker: Dictionary, kind: String, reserved: Dictionary = {}, exclude: Array = []) -> Dictionary:
	return _require(_provider_harvest_orders, "harvest_orders")._nearest_harvest_by_path(worker, kind, reserved, exclude)
func _nearby_same_resource(origin_obj: Dictionary, worker: Dictionary, reserved: Dictionary) -> Dictionary:
	return _require(_provider_harvest_orders, "harvest_orders")._nearby_same_resource(origin_obj, worker, reserved)
func _deposits_for(u: Dictionary, kind: String) -> Array:
	return _require(_provider_harvest_orders, "harvest_orders")._deposits_for(u, kind)
func _food_capacity(owner: int) -> float:
	return _require(_provider_harvest_orders, "harvest_orders")._food_capacity(owner)
func _deposit_carry(u: Dictionary) -> bool:
	return _require(_provider_harvest_orders, "harvest_orders")._deposit_carry(u)
func _remove_decor(obj: Dictionary) -> void:
	_require(_provider_harvest_orders, "harvest_orders")._remove_decor(obj)
func _reset_jimou() -> void:
	_require(_provider_abilities, "abilities")._reset_jimou()
func _jimou_begin(idx: int) -> void:
	_require(_provider_abilities, "abilities")._jimou_begin(idx)
func _jimou_cast_at(pos: Vector2) -> void:
	_require(_provider_abilities, "abilities")._jimou_cast_at(pos)
func _set_formation(idx: int) -> void:
	_require(_provider_abilities, "abilities")._set_formation(idx)
func _spd_mult(u: Dictionary) -> float:
	return _require(_provider_abilities, "abilities")._spd_mult(u)
func _duel_begin() -> void:
	_require(_provider_abilities, "abilities")._duel_begin()
func _stamina_of(u: Dictionary) -> float:
	return _require(_provider_abilities, "abilities")._stamina_of(u)
func _duel_accept(hp_a: float, _st_a: float, hp_b: float, st_b: float) -> bool:
	return _require(_provider_abilities, "abilities")._duel_accept(hp_a, _st_a, hp_b, st_b)
func _duel_at(pos: Vector2) -> void:
	_require(_provider_abilities, "abilities")._duel_at(pos)
func control_group_size(n: int) -> int:
	return _require(_provider_command_groups, "command_groups").control_group_size(n)
func control_group_work_site(n: int) -> Dictionary:
	return _require(_provider_command_groups, "command_groups").control_group_work_site(n)
func _group_assign(n: int) -> void:
	_require(_provider_command_groups, "command_groups")._group_assign(n)
func _group_recall(n: int) -> bool:
	return _require(_provider_command_groups, "command_groups")._group_recall(n)
func focus_group(n: int) -> bool:
	return _require(_provider_scene_controller, "scene_controller").focus_group(n)
func control_group_leader(n: int) -> Dictionary:
	return _require(_provider_command_groups, "command_groups").control_group_leader(n)
func _cmd_watch() -> void:
	_require(_provider_command_groups, "command_groups")._cmd_watch()
func _cancel_unit_command(u: Dictionary) -> void:
	_require(_provider_command_groups, "command_groups")._cancel_unit_command(u)
func _cmd_rest() -> void:
	_require(_provider_command_groups, "command_groups")._cmd_rest()
func _is_hero_unit(u: Dictionary) -> bool:
	return _require(_provider_command_groups, "command_groups")._is_hero_unit(u)
func _construction_workers(commander: Dictionary) -> Array:
	return _require(_provider_command_groups, "command_groups")._construction_workers(commander)
func _selected_construction_workers() -> Array:
	return _require(_provider_command_groups, "command_groups")._selected_construction_workers()
func _enforce_team_limits() -> void:
	_require(_provider_command_groups, "command_groups")._enforce_team_limits()
func _is_naval(u: Dictionary) -> bool:
	return _require(_provider_command_groups, "command_groups")._is_naval(u)
func _nav_layer(u: Dictionary) -> int:
	return _require(_provider_command_groups, "command_groups")._nav_layer(u)
func _cmd_begin(kind: String, data: Dictionary = {}) -> void:
	_require(_provider_command_groups, "command_groups")._cmd_begin(kind, data)
func _cmd_disband() -> void:
	_require(_provider_command_groups, "command_groups")._cmd_disband()
func _order_repair(target: Dictionary) -> int:
	return _require(_provider_construction_orders, "construction_orders")._order_repair(target)
func _do_repair(w: Dictionary, t: Dictionary) -> bool:
	return _require(_provider_construction_orders, "construction_orders")._do_repair(w, t)
func _site_entry_path(unit: Dictionary, site: Dictionary, future_cells: Array = []) -> Array:
	return _require(_provider_construction_orders, "construction_orders")._site_entry_path(unit, site, future_cells)
func build_placement_at(pos: Vector2, opt: Dictionary) -> Dictionary:
	return _require(_provider_construction_orders, "construction_orders").build_placement_at(pos, opt)
func _assign_build_worker(worker: Dictionary, site: Dictionary) -> bool:
	return _require(_provider_construction_orders, "construction_orders")._assign_build_worker(worker, site)
func _valid_build_worker(worker: Dictionary, site: Dictionary) -> bool:
	return _require(_provider_construction_orders, "construction_orders")._valid_build_worker(worker, site)
func _build_site_at(pos: Vector2, opt: Dictionary) -> bool:
	return _require(_provider_construction_orders, "construction_orders")._build_site_at(pos, opt)
func _complete_site(site: Dictionary) -> void:
	_require(_provider_construction_orders, "construction_orders")._complete_site(site)
func _commander_for(u: Dictionary) -> Dictionary:
	return _require(_provider_command_groups, "command_groups")._commander_for(u)
func _command_units() -> Array:
	return _require(_provider_command_groups, "command_groups")._command_units()
func _return_selected_cargo() -> void:
	_require(_provider_command_groups, "command_groups")._return_selected_cargo()
func _grant_officer_exp(u: Dictionary, amount: float) -> void:
	_require(_provider_officer_teams, "officer_teams")._grant_officer_exp(u, amount)
func stop_selected() -> void:
	_require(_provider_command_groups, "command_groups").stop_selected()
func _start_build(opt: Dictionary) -> void:
	_require(_provider_construction_orders, "construction_orders")._start_build(opt)
func _army_count(owner: int) -> int:
	return _require(_provider_production, "production")._army_count(owner)
func _commander_count(owner: int) -> int:
	return _require(_provider_production, "production")._commander_count(owner)
func _queue_train(owner: int, building: Dictionary, uid: int) -> bool:
	return _require(_provider_production, "production")._queue_train(owner, building, uid)
func _start_train(opt: Dictionary) -> void:
	_require(_provider_production, "production")._start_train(opt)
func _cancel_training(building: Dictionary) -> bool:
	return _require(_provider_production, "production")._cancel_training(building)
func _cancel_site(site: Dictionary) -> bool:
	return _require(_provider_construction_orders, "construction_orders")._cancel_site(site)
func _process_trainings(_delta: float) -> void:
	_require(_provider_production, "production")._process_trainings(_delta)
func _apply_save() -> bool:
	return _require(_provider_scene_controller, "scene_controller")._apply_save()
func _save_extra() -> Dictionary:
	return _require(_provider_scene_controller, "scene_controller")._save_extra()
func _save_game(slot := 0, title := "") -> bool:
	return _require(_provider_scene_controller, "scene_controller")._save_game(slot, title)
func _form_hero_unit(u: Dictionary, idx: int) -> bool:
	return _require(_provider_officer_teams, "officer_teams")._form_hero_unit(u, idx)
func _order_disband() -> int:
	return _require(_provider_officer_teams, "officer_teams")._order_disband()
func _order_join(target: Dictionary) -> int:
	return _require(_provider_officer_teams, "officer_teams")._order_join(target)
func _assign_officer_to(u: Dictionary, idx: int) -> bool:
	return _require(_provider_officer_teams, "officer_teams")._assign_officer_to(u, idx)
func _unassign_officer(u: Dictionary) -> void:
	_require(_provider_officer_teams, "officer_teams")._unassign_officer(u)
func _order_form_up(officer_index: int) -> void:
	_require(_provider_officer_teams, "officer_teams")._order_form_up(officer_index)
func _attach_officer(u: Dictionary, o: Dictionary) -> void:
	_require(_provider_entity_factory, "entity_factory")._attach_officer(u, o)
func set_sim_speed(index: int) -> bool:
	return _require(_provider_battle_simulation, "battle_simulation").set_sim_speed(index)
func _view_hud() -> void:
	_require(_provider_scene_controller, "scene_controller")._view_hud()
func _show_end(kind: int) -> void:
	_require(_provider_campaign, "campaign")._show_end(kind)
func _place_unit(u: Dictionary) -> void:
	_require(_provider_battle_simulation, "battle_simulation")._place_unit(u)
func _finish_death(u: Dictionary) -> void:
	_require(_provider_battle_simulation, "battle_simulation")._finish_death(u)
func _update_gates() -> void:
	_require(_provider_battle_simulation, "battle_simulation")._update_gates()
func _sim_step(dt: float) -> void:
	_require(_provider_battle_simulation, "battle_simulation")._sim_step(dt)
func _process_sites(_delta: float) -> void:
	_require(_provider_construction_orders, "construction_orders")._process_sites(_delta)
func _process_officer_recovery() -> void:
	_require(_provider_officer_teams, "officer_teams")._process_officer_recovery()
func _state_digest() -> int:
	return _require(_provider_battle_simulation, "battle_simulation")._state_digest()
func _prune_dead() -> void:
	_require(_provider_battle_simulation, "battle_simulation")._prune_dead()
func _free_unit_at(i: int) -> void:
	_require(_provider_battle_simulation, "battle_simulation")._free_unit_at(i)
func _step_unit(u: Dictionary, delta: float) -> void:
	_require(_provider_unit_actions, "unit_actions")._step_unit(u, delta)
func _separate_unit(u: Dictionary) -> void:
	_require(_provider_spatial_index, "spatial_index")._separate_unit(u)
func _step_unit_inner(u: Dictionary, delta: float) -> void:
	_require(_provider_unit_actions, "unit_actions")._step_unit_inner(u, delta)
func _damage(a: Dictionary, d: Dictionary) -> float:
	return _require(_provider_combat, "combat")._damage(a, d)
func _fire_attack(attacker: Dictionary, target: Dictionary) -> void:
	_require(_provider_combat, "combat")._fire_attack(attacker, target)
func _follow(u: Dictionary, delta: float) -> bool:
	return _require(_provider_movement, "movement")._follow(u, delta)
func _resolve_navigation_overlaps() -> void:
	_require(_provider_movement, "movement")._resolve_navigation_overlaps()
func _nearest_enemy(u: Dictionary, max_d: float) -> Dictionary:
	return _require(_provider_combat, "combat")._nearest_enemy(u, max_d)
func officer_rank_name(off: Dictionary) -> String:
	return _require(_provider_combat, "combat").officer_rank_name(off)
func _kill(u: Dictionary, by: Dictionary = {}) -> void:
	_require(_provider_combat, "combat")._kill(u, by)
func _die_step(u: Dictionary, delta: float) -> void:
	_require(_provider_combat, "combat")._die_step(u, delta)
func _clip_dir(u: Dictionary, clip: String, dir: int) -> Array:
	return _require(_provider_combat, "combat")._clip_dir(u, clip, dir)
func _clip_frame(u: Dictionary, clip: String, dir: int, step: int) -> int:
	return _require(_provider_combat, "combat")._clip_frame(u, clip, dir, step)
func _update_visual(u: Dictionary) -> void:
	_require(_provider_battle_simulation, "battle_simulation")._update_visual(u)
func _set_frame(u: Dictionary, f: int) -> void:
	_require(_provider_battle_simulation, "battle_simulation")._set_frame(u, f)
func ai_owners() -> Array:
	return _require(_provider_ai_economy, "ai_economy").ai_owners()
func _ai_res_of(owner: int) -> Dictionary:
	return _require(_provider_ai_economy, "ai_economy")._ai_res_of(owner)
func ai_construction_commander(owner: int) -> Dictionary:
	return _require(_provider_ai_economy, "ai_economy").ai_construction_commander(owner)
func _dock_can_launch(point: Vector2) -> bool:
	return _require(_provider_ai_economy, "ai_economy")._dock_can_launch(point)
func _place_building(owner: int, building_type: int, near_px: Vector2, as_site := false, access_workers: Array = [], exact_anchor := false) -> Dictionary:
	return _require(_provider_construction_orders, "construction_orders")._place_building(owner, building_type, near_px, as_site, access_workers, exact_anchor)
func ai_place_building(owner: int, building_type: int, commander: Dictionary = {}) -> bool:
	return _require(_provider_construction_orders, "construction_orders").ai_place_building(owner, building_type, commander)
func ai_set_gold(owner: int, v: float) -> void:
	_require(_provider_ai_economy, "ai_economy").ai_set_gold(owner, v)
func ai_queue_hq_upgrade(owner: int) -> bool:
	return _require(_provider_ai_economy, "ai_economy").ai_queue_hq_upgrade(owner)
func ai_level(owner: int) -> int:
	return _require(_provider_ai_economy, "ai_economy").ai_level(owner)
func ai_unit_cost(unit_id: int) -> Dictionary:
	return _require(_provider_ai_economy, "ai_economy").ai_unit_cost(unit_id)
func ai_disband_slot(owner: int, slot: int) -> void:
	_require(_provider_ai_economy, "ai_economy").ai_disband_slot(owner, slot)
func _ai_forming(u: Dictionary) -> bool:
	return _require(_provider_ai_economy, "ai_economy")._ai_forming(u)
func ai_order_rally(owner: int, skip_groups: Array = []) -> void:
	_require(_provider_ai_orders, "ai_orders").ai_order_rally(owner, skip_groups)
func _l1_target(player: int) -> Dictionary:
	return _require(_provider_ai_orders, "ai_orders")._l1_target(player)
func ai_order_assault(owner: int, skip_groups: Array = []) -> void:
	_require(_provider_ai_orders, "ai_orders").ai_order_assault(owner, skip_groups)
func ai_order_intercept(owner: int, focus: Dictionary, radius: float, skip_groups: Array = []) -> void:
	_require(_provider_ai_orders, "ai_orders").ai_order_intercept(owner, focus, radius, skip_groups)
func ai_focus_unit(owner: int) -> Dictionary:
	return _require(_provider_ai_orders, "ai_orders").ai_focus_unit(owner)
func _nearest_enemy_threat(u: Dictionary) -> Dictionary:
	return _require(_provider_ai_orders, "ai_orders")._nearest_enemy_threat(u)
func _resource_at(pos: Vector2) -> Dictionary:
	return _require(_provider_harvest_orders, "harvest_orders")._resource_at(pos)
func _order_context(pos: Vector2) -> void:
	_require(_provider_world_orders, "world_orders")._order_context(pos)
func _order_at(pos: Vector2) -> void:
	_require(_provider_world_orders, "world_orders")._order_at(pos)
func _resolve_pending(pos: Vector2) -> void:
	_require(_provider_world_orders, "world_orders")._resolve_pending(pos)
func _selected_has_nonworker_attacker() -> bool:
	return _require(_provider_world_orders, "world_orders")._selected_has_nonworker_attacker()
func _attack_selected(tgt: Dictionary) -> int:
	return _require(_provider_world_orders, "world_orders")._attack_selected(tgt)
func _move_selected_to(pos: Vector2) -> void:
	_require(_provider_world_orders, "world_orders")._move_selected_to(pos)
func _anchor_of_cell(cell: Vector2i) -> Vector2:
	return _require(_provider_movement, "movement")._anchor_of_cell(cell)
func _own_object_at(pos: Vector2) -> Dictionary:
	return _require(_provider_selection, "selection")._own_object_at(pos)
func _order_board(ship: Dictionary) -> int:
	return _require(_provider_transport_orders, "transport_orders")._order_board(ship)
func _attach_to_ship(u: Dictionary, ship: Dictionary) -> bool:
	return _require(_provider_transport_orders, "transport_orders")._attach_to_ship(u, ship)
func _order_unload(ship: Dictionary, _pos:=Vector2.ZERO) -> int:
	return _require(_provider_transport_orders, "transport_orders")._order_unload(ship, _pos)
func _attack_target_at(pos: Vector2) -> Dictionary:
	return _require(_provider_selection, "selection")._attack_target_at(pos)
func _enemy_at(pos: Vector2) -> Dictionary:
	return _require(_provider_selection, "selection")._enemy_at(pos)
func _player_at(pos: Vector2) -> Dictionary:
	return _require(_provider_selection, "selection")._player_at(pos)
func _select_click(pos: Vector2, add: bool) -> void:
	_require(_provider_selection, "selection")._select_click(pos, add)
func _force_counts(owner: int) -> Dictionary:
	return _require(_provider_campaign, "campaign")._force_counts(owner)
func _objective_kind() -> String:
	return _require(_provider_campaign, "campaign")._objective_kind()
func _water_cell_count() -> int:
	return _require(_provider_campaign, "campaign")._water_cell_count()
func _check_end() -> void:
	_require(_provider_campaign, "campaign")._check_end()
func _unit_name(unit_id: int) -> String:
	return _require(_provider_campaign, "campaign")._unit_name(unit_id)
func _hover_unit(pos: Vector2) -> Dictionary:
	return _require(_provider_selection, "selection")._hover_unit(pos)
func _screenshot() -> void:
	await _require(_provider_scene_controller, "scene_controller")._screenshot()
func _context_mode(pos: Vector2, use_pending := true) -> int:
	return _require(_provider_world_orders, "world_orders")._context_mode(pos, use_pending)

func connect_services(services: Dictionary) -> void:
	_provider_cheat_rules = weakref(services["cheat_rules"])
	_provider_duel_controller = weakref(services["duel_controller"])
	_provider_bootstrap = weakref(services["bootstrap"])
	_provider_cheat_controller = weakref(services["cheat_controller"])
	_provider_abilities = weakref(services["abilities"])
	_provider_ai_economy = weakref(services["ai_economy"])
	_provider_ai_orders = weakref(services["ai_orders"])
	_provider_battle_simulation = weakref(services["battle_simulation"])
	_provider_campaign = weakref(services["campaign"])
	_provider_combat = weakref(services["combat"])
	_provider_command_groups = weakref(services["command_groups"])
	_provider_construction_orders = weakref(services["construction_orders"])
	_provider_entity_factory = weakref(services["entity_factory"])
	_provider_harvest_orders = weakref(services["harvest_orders"])
	_provider_interaction_paths = weakref(services["interaction_paths"])
	_provider_movement = weakref(services["movement"])
	_provider_officer_pool = weakref(services["officer_pool"])
	_provider_officer_teams = weakref(services["officer_teams"])
	_provider_production = weakref(services["production"])
	_provider_selection = weakref(services["selection"])
	_provider_spatial_index = weakref(services["spatial_index"])
	_provider_technology = weakref(services["technology"])
	_provider_transport_orders = weakref(services["transport_orders"])
	_provider_unit_actions = weakref(services["unit_actions"])
	_provider_world_orders = weakref(services["world_orders"])
	_provider_scene_controller = weakref(services["scene_controller"])

func disconnect_services() -> void:
	_provider_cheat_rules = null
	_provider_duel_controller = null
	_provider_bootstrap = null
	_provider_cheat_controller = null
	_provider_abilities = null
	_provider_ai_economy = null
	_provider_ai_orders = null
	_provider_battle_simulation = null
	_provider_campaign = null
	_provider_combat = null
	_provider_command_groups = null
	_provider_construction_orders = null
	_provider_entity_factory = null
	_provider_harvest_orders = null
	_provider_interaction_paths = null
	_provider_movement = null
	_provider_officer_pool = null
	_provider_officer_teams = null
	_provider_production = null
	_provider_selection = null
	_provider_spatial_index = null
	_provider_technology = null
	_provider_transport_orders = null
	_provider_unit_actions = null
	_provider_world_orders = null
	_provider_scene_controller = null

func _set_cheat_input(opened: bool) -> void:
	_require(_provider_cheat_controller, "cheat_controller")._set_cheat_input(opened)


func handle_cheat_input(event: InputEvent) -> bool:
	return _require(_provider_cheat_controller, "cheat_controller").handle_cheat_input(event)

func _resolve_duel(ticket: int) -> void:
	_require(_provider_abilities, "abilities")._resolve_duel(ticket)

func _formation_target_cell(u: Dictionary, cell: Vector2i) -> Vector2i:
	return _require(_provider_abilities, "abilities")._formation_target_cell(u, cell)

func _step_auto_control() -> void:
	_require(_provider_cheat_rules, "cheat_rules")._step_auto_control()

func _apply_hit(target: Dictionary, damage: float, source_uid: int) -> void:
	_require(_provider_combat, "combat")._apply_hit(target, damage, source_uid)

func _cheat_adjacent_level(levels: Array, current: String, direction: int) -> String:
	return _require(_provider_cheat_controller, "cheat_controller")._cheat_adjacent_level(levels, current, direction)
