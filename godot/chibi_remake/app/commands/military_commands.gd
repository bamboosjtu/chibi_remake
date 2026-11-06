extends "res://named_port.gd"
## military: explicit commands, validated once at the composition boundary.
const CONTRACTS := {"officer_pool": ["_officer_by_index", "_officer_pool_state", "_restore_officer_pool", "available_officers", "officer_in_use", "officers_for_selection"], "abilities": ["_duel_accept", "_duel_at", "_duel_begin", "_formation_target_cell", "_jimou_begin", "_jimou_cast_at", "_reset_jimou", "_resolve_duel", "_set_formation", "_spd_mult", "_stamina_of"], "command_groups": ["_cancel_unit_command", "_cmd_begin", "_cmd_disband", "_cmd_rest", "_cmd_watch", "_command_units", "_commander_for", "_construction_workers", "_enforce_team_limits", "_group_assign", "_group_recall", "_is_hero_unit", "_is_naval", "_nav_layer", "_return_selected_cargo", "_selected_construction_workers", "control_group_leader", "control_group_size", "control_group_work_site", "stop_selected"], "officer_teams": ["_assign_officer_to", "_form_hero_unit", "_grant_officer_exp", "_order_disband", "_order_form_up", "_order_join", "_process_officer_recovery", "_unassign_officer"], "combat": ["_apply_hit", "_clip_dir", "_clip_frame", "_damage", "_die_step", "_fire_attack", "_kill", "_nearest_enemy", "officer_rank_name"], "ai_orders": ["_l1_target", "_nearest_enemy_threat", "ai_focus_unit", "ai_order_assault", "ai_order_intercept", "ai_order_rally"]}
var _provider_officer_pool: WeakRef
var _provider_abilities: WeakRef
var _provider_command_groups: WeakRef
var _provider_officer_teams: WeakRef
var _provider_combat: WeakRef
var _provider_ai_orders: WeakRef

func _officer_by_index(idx: int) -> Dictionary:
	var provider = _require(_provider_officer_pool, "officer_pool")
	if provider == null: return {}
	return provider._officer_by_index(idx)

func _officer_pool_state() -> Dictionary:
	var provider = _require(_provider_officer_pool, "officer_pool")
	if provider == null: return {}
	return provider._officer_pool_state()

func _restore_officer_pool(state: Dictionary) -> void:
	var provider = _require(_provider_officer_pool, "officer_pool")
	if provider == null: return
	provider._restore_officer_pool(state)

func officer_in_use(idx: int) -> bool:
	var provider = _require(_provider_officer_pool, "officer_pool")
	if provider == null: return false
	return provider.officer_in_use(idx)

func available_officers(owner: int) -> Array:
	var provider = _require(_provider_officer_pool, "officer_pool")
	if provider == null: return []
	return provider.available_officers(owner)

func officers_for_selection(owner: int, sel: Array) -> Array:
	var provider = _require(_provider_officer_pool, "officer_pool")
	if provider == null: return []
	return provider.officers_for_selection(owner, sel)

func _reset_jimou() -> void:
	var provider = _require(_provider_abilities, "abilities")
	if provider == null: return
	provider._reset_jimou()

func _jimou_begin(idx: int) -> void:
	var provider = _require(_provider_abilities, "abilities")
	if provider == null: return
	provider._jimou_begin(idx)

func _jimou_cast_at(pos: Vector2) -> void:
	var provider = _require(_provider_abilities, "abilities")
	if provider == null: return
	provider._jimou_cast_at(pos)

func _set_formation(idx: int) -> void:
	var provider = _require(_provider_abilities, "abilities")
	if provider == null: return
	provider._set_formation(idx)

func _spd_mult(u: Dictionary) -> float:
	var provider = _require(_provider_abilities, "abilities")
	if provider == null: return 0.0
	return provider._spd_mult(u)

func _duel_begin() -> void:
	var provider = _require(_provider_abilities, "abilities")
	if provider == null: return
	provider._duel_begin()

func _stamina_of(u: Dictionary) -> float:
	var provider = _require(_provider_abilities, "abilities")
	if provider == null: return 0.0
	return provider._stamina_of(u)

func _duel_accept(hp_a: float, _st_a: float, hp_b: float, st_b: float) -> bool:
	var provider = _require(_provider_abilities, "abilities")
	if provider == null: return false
	return provider._duel_accept(hp_a, _st_a, hp_b, st_b)

func _duel_at(pos: Vector2) -> void:
	var provider = _require(_provider_abilities, "abilities")
	if provider == null: return
	provider._duel_at(pos)

func control_group_size(n: int) -> int:
	var provider = _require(_provider_command_groups, "command_groups")
	if provider == null: return 0
	return provider.control_group_size(n)

func control_group_work_site(n: int) -> Dictionary:
	var provider = _require(_provider_command_groups, "command_groups")
	if provider == null: return {}
	return provider.control_group_work_site(n)

func _group_assign(n: int) -> void:
	var provider = _require(_provider_command_groups, "command_groups")
	if provider == null: return
	provider._group_assign(n)

func _group_recall(n: int) -> bool:
	var provider = _require(_provider_command_groups, "command_groups")
	if provider == null: return false
	return provider._group_recall(n)

func control_group_leader(n: int) -> Dictionary:
	var provider = _require(_provider_command_groups, "command_groups")
	if provider == null: return {}
	return provider.control_group_leader(n)

func _cmd_watch() -> void:
	var provider = _require(_provider_command_groups, "command_groups")
	if provider == null: return
	provider._cmd_watch()

func _cancel_unit_command(u: Dictionary) -> void:
	var provider = _require(_provider_command_groups, "command_groups")
	if provider == null: return
	provider._cancel_unit_command(u)

func _cmd_rest() -> void:
	var provider = _require(_provider_command_groups, "command_groups")
	if provider == null: return
	provider._cmd_rest()

func _is_hero_unit(u: Dictionary) -> bool:
	var provider = _require(_provider_command_groups, "command_groups")
	if provider == null: return false
	return provider._is_hero_unit(u)

func _construction_workers(commander: Dictionary) -> Array:
	var provider = _require(_provider_command_groups, "command_groups")
	if provider == null: return []
	return provider._construction_workers(commander)

func _selected_construction_workers() -> Array:
	var provider = _require(_provider_command_groups, "command_groups")
	if provider == null: return []
	return provider._selected_construction_workers()

func _enforce_team_limits() -> void:
	var provider = _require(_provider_command_groups, "command_groups")
	if provider == null: return
	provider._enforce_team_limits()

func _is_naval(u: Dictionary) -> bool:
	var provider = _require(_provider_command_groups, "command_groups")
	if provider == null: return false
	return provider._is_naval(u)

func _nav_layer(u: Dictionary) -> int:
	var provider = _require(_provider_command_groups, "command_groups")
	if provider == null: return 0
	return provider._nav_layer(u)

func _cmd_begin(kind: String, data: Dictionary = {}) -> void:
	var provider = _require(_provider_command_groups, "command_groups")
	if provider == null: return
	provider._cmd_begin(kind, data)

func _cmd_disband() -> void:
	var provider = _require(_provider_command_groups, "command_groups")
	if provider == null: return
	provider._cmd_disband()

func _commander_for(u: Dictionary) -> Dictionary:
	var provider = _require(_provider_command_groups, "command_groups")
	if provider == null: return {}
	return provider._commander_for(u)

func _command_units() -> Array:
	var provider = _require(_provider_command_groups, "command_groups")
	if provider == null: return []
	return provider._command_units()

func _return_selected_cargo() -> void:
	var provider = _require(_provider_command_groups, "command_groups")
	if provider == null: return
	provider._return_selected_cargo()

func _grant_officer_exp(u: Dictionary, amount: float) -> void:
	var provider = _require(_provider_officer_teams, "officer_teams")
	if provider == null: return
	provider._grant_officer_exp(u, amount)

func stop_selected() -> void:
	var provider = _require(_provider_command_groups, "command_groups")
	if provider == null: return
	provider.stop_selected()

func _form_hero_unit(u: Dictionary, idx: int) -> bool:
	var provider = _require(_provider_officer_teams, "officer_teams")
	if provider == null: return false
	return provider._form_hero_unit(u, idx)

func _order_disband() -> int:
	var provider = _require(_provider_officer_teams, "officer_teams")
	if provider == null: return 0
	return provider._order_disband()

func _order_join(target: Dictionary) -> int:
	var provider = _require(_provider_officer_teams, "officer_teams")
	if provider == null: return 0
	return provider._order_join(target)

func _assign_officer_to(u: Dictionary, idx: int) -> bool:
	var provider = _require(_provider_officer_teams, "officer_teams")
	if provider == null: return false
	return provider._assign_officer_to(u, idx)

func _unassign_officer(u: Dictionary) -> void:
	var provider = _require(_provider_officer_teams, "officer_teams")
	if provider == null: return
	provider._unassign_officer(u)

func _order_form_up(officer_index: int) -> void:
	var provider = _require(_provider_officer_teams, "officer_teams")
	if provider == null: return
	provider._order_form_up(officer_index)

func _process_officer_recovery() -> void:
	var provider = _require(_provider_officer_teams, "officer_teams")
	if provider == null: return
	provider._process_officer_recovery()

func _damage(a: Dictionary, d: Dictionary) -> float:
	var provider = _require(_provider_combat, "combat")
	if provider == null: return 0.0
	return provider._damage(a, d)

func _fire_attack(attacker: Dictionary, target: Dictionary) -> void:
	var provider = _require(_provider_combat, "combat")
	if provider == null: return
	provider._fire_attack(attacker, target)

func _nearest_enemy(u: Dictionary, max_d: float) -> Dictionary:
	var provider = _require(_provider_combat, "combat")
	if provider == null: return {}
	return provider._nearest_enemy(u, max_d)

func officer_rank_name(off: Dictionary) -> String:
	var provider = _require(_provider_combat, "combat")
	if provider == null: return ""
	return provider.officer_rank_name(off)

func _kill(u: Dictionary, by: Dictionary = {}) -> void:
	var provider = _require(_provider_combat, "combat")
	if provider == null: return
	provider._kill(u, by)

func _die_step(u: Dictionary, delta: float) -> void:
	var provider = _require(_provider_combat, "combat")
	if provider == null: return
	provider._die_step(u, delta)

func _clip_dir(u: Dictionary, clip: String, dir: int) -> Array:
	var provider = _require(_provider_combat, "combat")
	if provider == null: return []
	return provider._clip_dir(u, clip, dir)

func _clip_frame(u: Dictionary, clip: String, dir: int, step: int) -> int:
	var provider = _require(_provider_combat, "combat")
	if provider == null: return 0
	return provider._clip_frame(u, clip, dir, step)

func ai_order_rally(owner: int, skip_groups: Array = []) -> void:
	var provider = _require(_provider_ai_orders, "ai_orders")
	if provider == null: return
	provider.ai_order_rally(owner, skip_groups)

func _l1_target(player: int) -> Dictionary:
	var provider = _require(_provider_ai_orders, "ai_orders")
	if provider == null: return {}
	return provider._l1_target(player)

func ai_order_assault(owner: int, skip_groups: Array = []) -> void:
	var provider = _require(_provider_ai_orders, "ai_orders")
	if provider == null: return
	provider.ai_order_assault(owner, skip_groups)

func ai_order_intercept(owner: int, focus: Dictionary, radius: float, skip_groups: Array = []) -> void:
	var provider = _require(_provider_ai_orders, "ai_orders")
	if provider == null: return
	provider.ai_order_intercept(owner, focus, radius, skip_groups)

func ai_focus_unit(owner: int) -> Dictionary:
	var provider = _require(_provider_ai_orders, "ai_orders")
	if provider == null: return {}
	return provider.ai_focus_unit(owner)

func _nearest_enemy_threat(u: Dictionary) -> Dictionary:
	var provider = _require(_provider_ai_orders, "ai_orders")
	if provider == null: return {}
	return provider._nearest_enemy_threat(u)

func _resolve_duel(ticket: int) -> void:
	var provider = _require(_provider_abilities, "abilities")
	if provider == null: return
	provider._resolve_duel(ticket)

func _formation_target_cell(u: Dictionary, cell: Vector2i) -> Vector2i:
	var provider = _require(_provider_abilities, "abilities")
	if provider == null: return Vector2i.ZERO
	return provider._formation_target_cell(u, cell)

func _apply_hit(target: Dictionary, damage: float, source_uid: int) -> void:
	var provider = _require(_provider_combat, "combat")
	if provider == null: return
	provider._apply_hit(target, damage, source_uid)

func connect_services(services: Dictionary) -> Array:
	_provider_officer_pool = weakref(services["officer_pool"]) if services.get("officer_pool") != null else null
	_provider_abilities = weakref(services["abilities"]) if services.get("abilities") != null else null
	_provider_command_groups = weakref(services["command_groups"]) if services.get("command_groups") != null else null
	_provider_officer_teams = weakref(services["officer_teams"]) if services.get("officer_teams") != null else null
	_provider_combat = weakref(services["combat"]) if services.get("combat") != null else null
	_provider_ai_orders = weakref(services["ai_orders"]) if services.get("ai_orders") != null else null
	return validate_services(services, CONTRACTS)

func disconnect_services() -> void:
	_provider_officer_pool = null
	_provider_abilities = null
	_provider_command_groups = null
	_provider_officer_teams = null
	_provider_combat = null
	_provider_ai_orders = null
