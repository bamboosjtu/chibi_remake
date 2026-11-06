extends "res://named_port.gd"
## orders: explicit commands, validated once at the composition boundary.
const CONTRACTS := {"movement": ["_anchor_of", "_anchor_of_cell", "_cell_of_px", "_follow", "_near_walkable", "_path_to", "_resolve_navigation_overlaps"], "world_orders": ["_attack_selected", "_clear_pending", "_context_mode", "_move_selected_to", "_order_at", "_order_context", "_resolve_pending", "_selected_has_nonworker_attacker", "cmd_pending_kind"], "interaction_paths": ["_dist_to_obj", "_edge_cell_distance", "_edge_interaction_choice", "_edge_interaction_path", "_edge_neighbors", "_edge_point", "_footprint_cells", "_resource_patch_cells", "_resource_patch_interaction_choice"], "unit_actions": ["_step_unit", "_step_unit_inner"], "selection": ["_attack_target_at", "_enemy_at", "_hover_unit", "_own_object_at", "_player_at", "_select_click"], "transport_orders": ["_attach_to_ship", "_order_board", "_order_unload"]}
var _provider_movement: WeakRef
var _provider_world_orders: WeakRef
var _provider_interaction_paths: WeakRef
var _provider_unit_actions: WeakRef
var _provider_selection: WeakRef
var _provider_transport_orders: WeakRef

func _cell_of_px(px: float, py: float) -> Vector2i:
	var provider = _require(_provider_movement, "movement")
	if provider == null: return Vector2i.ZERO
	return provider._cell_of_px(px, py)

func _anchor_of(a: int, b: int) -> Vector2:
	var provider = _require(_provider_movement, "movement")
	if provider == null: return Vector2.ZERO
	return provider._anchor_of(a, b)

func _near_walkable(c: Vector2i) -> Vector2i:
	var provider = _require(_provider_movement, "movement")
	if provider == null: return Vector2i.ZERO
	return provider._near_walkable(c)

func _path_to(u: Dictionary, target_px: Vector2, exact: bool) -> Array:
	var provider = _require(_provider_movement, "movement")
	if provider == null: return []
	return provider._path_to(u, target_px, exact)

func cmd_pending_kind() -> String:
	var provider = _require(_provider_world_orders, "world_orders")
	if provider == null: return ""
	return provider.cmd_pending_kind()

func _clear_pending() -> void:
	var provider = _require(_provider_world_orders, "world_orders")
	if provider == null: return
	provider._clear_pending()

func _dist_to_obj(u: Dictionary, o: Dictionary) -> float:
	var provider = _require(_provider_interaction_paths, "interaction_paths")
	if provider == null: return 0.0
	return provider._dist_to_obj(u, o)

func _footprint_cells(o: Dictionary) -> Array:
	var provider = _require(_provider_interaction_paths, "interaction_paths")
	if provider == null: return []
	return provider._footprint_cells(o)

func _edge_cell_distance(u: Dictionary, o: Dictionary) -> int:
	var provider = _require(_provider_interaction_paths, "interaction_paths")
	if provider == null: return 0
	return provider._edge_cell_distance(u, o)

func _edge_neighbors(o: Dictionary, exclude_uid := -1, require_free := false, owner := -1) -> Array:
	var provider = _require(_provider_interaction_paths, "interaction_paths")
	if provider == null: return []
	return provider._edge_neighbors(o, exclude_uid, require_free, owner)

func _edge_interaction_path(u: Dictionary, o: Dictionary, reserved := {}, max_body := -1.0) -> Array:
	var provider = _require(_provider_interaction_paths, "interaction_paths")
	if provider == null: return []
	return provider._edge_interaction_path(u, o, reserved, max_body)

func _edge_interaction_choice(u: Dictionary, o: Dictionary, reserved := {}, max_body := -1.0) -> Dictionary:
	var provider = _require(_provider_interaction_paths, "interaction_paths")
	if provider == null: return {}
	return provider._edge_interaction_choice(u, o, reserved, max_body)

func _resource_patch_cells(target: Dictionary) -> Array:
	var provider = _require(_provider_interaction_paths, "interaction_paths")
	if provider == null: return []
	return provider._resource_patch_cells(target)

func _resource_patch_interaction_choice(u: Dictionary, target: Dictionary, reserved := {}, known_cells: Array = []) -> Dictionary:
	var provider = _require(_provider_interaction_paths, "interaction_paths")
	if provider == null: return {}
	return provider._resource_patch_interaction_choice(u, target, reserved, known_cells)

func _edge_point(o: Dictionary, from_px := Vector2.ZERO, max_body := -1.0, exclude_uid := -1) -> Vector2:
	var provider = _require(_provider_interaction_paths, "interaction_paths")
	if provider == null: return Vector2.ZERO
	return provider._edge_point(o, from_px, max_body, exclude_uid)

func _step_unit(u: Dictionary, delta: float) -> void:
	var provider = _require(_provider_unit_actions, "unit_actions")
	if provider == null: return
	provider._step_unit(u, delta)

func _step_unit_inner(u: Dictionary, delta: float) -> void:
	var provider = _require(_provider_unit_actions, "unit_actions")
	if provider == null: return
	provider._step_unit_inner(u, delta)

func _follow(u: Dictionary, delta: float) -> bool:
	var provider = _require(_provider_movement, "movement")
	if provider == null: return false
	return provider._follow(u, delta)

func _resolve_navigation_overlaps() -> void:
	var provider = _require(_provider_movement, "movement")
	if provider == null: return
	provider._resolve_navigation_overlaps()

func _order_context(pos: Vector2) -> void:
	var provider = _require(_provider_world_orders, "world_orders")
	if provider == null: return
	provider._order_context(pos)

func _order_at(pos: Vector2) -> void:
	var provider = _require(_provider_world_orders, "world_orders")
	if provider == null: return
	provider._order_at(pos)

func _resolve_pending(pos: Vector2) -> void:
	var provider = _require(_provider_world_orders, "world_orders")
	if provider == null: return
	provider._resolve_pending(pos)

func _selected_has_nonworker_attacker() -> bool:
	var provider = _require(_provider_world_orders, "world_orders")
	if provider == null: return false
	return provider._selected_has_nonworker_attacker()

func _attack_selected(tgt: Dictionary) -> int:
	var provider = _require(_provider_world_orders, "world_orders")
	if provider == null: return 0
	return provider._attack_selected(tgt)

func _move_selected_to(pos: Vector2) -> void:
	var provider = _require(_provider_world_orders, "world_orders")
	if provider == null: return
	provider._move_selected_to(pos)

func _anchor_of_cell(cell: Vector2i) -> Vector2:
	var provider = _require(_provider_movement, "movement")
	if provider == null: return Vector2.ZERO
	return provider._anchor_of_cell(cell)

func _own_object_at(pos: Vector2) -> Dictionary:
	var provider = _require(_provider_selection, "selection")
	if provider == null: return {}
	return provider._own_object_at(pos)

func _order_board(ship: Dictionary) -> int:
	var provider = _require(_provider_transport_orders, "transport_orders")
	if provider == null: return 0
	return provider._order_board(ship)

func _attach_to_ship(u: Dictionary, ship: Dictionary) -> bool:
	var provider = _require(_provider_transport_orders, "transport_orders")
	if provider == null: return false
	return provider._attach_to_ship(u, ship)

func _order_unload(ship: Dictionary, _pos:=Vector2.ZERO) -> int:
	var provider = _require(_provider_transport_orders, "transport_orders")
	if provider == null: return 0
	return provider._order_unload(ship, _pos)

func _attack_target_at(pos: Vector2) -> Dictionary:
	var provider = _require(_provider_selection, "selection")
	if provider == null: return {}
	return provider._attack_target_at(pos)

func _enemy_at(pos: Vector2) -> Dictionary:
	var provider = _require(_provider_selection, "selection")
	if provider == null: return {}
	return provider._enemy_at(pos)

func _player_at(pos: Vector2) -> Dictionary:
	var provider = _require(_provider_selection, "selection")
	if provider == null: return {}
	return provider._player_at(pos)

func _select_click(pos: Vector2, add: bool) -> void:
	var provider = _require(_provider_selection, "selection")
	if provider == null: return
	provider._select_click(pos, add)

func _hover_unit(pos: Vector2) -> Dictionary:
	var provider = _require(_provider_selection, "selection")
	if provider == null: return {}
	return provider._hover_unit(pos)

func _context_mode(pos: Vector2, use_pending := true) -> int:
	var provider = _require(_provider_world_orders, "world_orders")
	if provider == null: return 0
	return provider._context_mode(pos, use_pending)

func connect_services(services: Dictionary) -> Array:
	_provider_movement = weakref(services["movement"]) if services.get("movement") != null else null
	_provider_world_orders = weakref(services["world_orders"]) if services.get("world_orders") != null else null
	_provider_interaction_paths = weakref(services["interaction_paths"]) if services.get("interaction_paths") != null else null
	_provider_unit_actions = weakref(services["unit_actions"]) if services.get("unit_actions") != null else null
	_provider_selection = weakref(services["selection"]) if services.get("selection") != null else null
	_provider_transport_orders = weakref(services["transport_orders"]) if services.get("transport_orders") != null else null
	return validate_services(services, CONTRACTS)

func disconnect_services() -> void:
	_provider_movement = null
	_provider_world_orders = null
	_provider_interaction_paths = null
	_provider_unit_actions = null
	_provider_selection = null
	_provider_transport_orders = null
