extends RefCounted
const CommandState = preload("res://simulation/commands/command_state.gd")
const UnitPosition = preload("res://simulation/navigation/unit_position.gd")
const UnitPath = preload("res://simulation/movement/unit_path.gd")
const NavRuntime = preload("res://simulation/navigation/nav.gd")
var _nav: NavRuntime
const Balance = preload("res://simulation/definitions/balance_rules.gd")
## Workers and their commander leave the battlefield while working inside a site.
var _state: RefCounted
var _dep_battle_simulation: Object
var _dep_command_groups: Object
var _dep_construction_orders: Object
var _dep_interaction_paths: Object
var _dep_movement: Object
var _dep_spatial_index: Object
var _dep_technology: Object
const FIELDS := ["site_inside_uid", "site_follow_uid", "site_entry_x", "site_entry_y", "site_exit_pending"]

func _init(battle: Object) -> void:
	_state = battle.state
	_dep_battle_simulation = battle.battle_simulation
	_dep_command_groups = battle.command_groups
	_dep_construction_orders = battle.construction_orders
	_dep_interaction_paths = battle.interaction_paths
	_dep_movement = battle.movement
	_dep_spatial_index = battle.spatial_index
	_dep_technology = battle.technology

func site_for(uid: int) -> Dictionary:
	for site in _state.units:
		if int(site.uid) == uid: return site
	return {}

func active(site: Dictionary) -> bool:
	return not site.is_empty() and bool(site.alive) and float(site.die_t) < 0 and bool(site.get("site", false))

func enter(unit: Dictionary, site: Dictionary) -> void:
	if _dep_technology._is_harvester_unit(unit) and int(unit.unit)!=30:return
	unit.site_entry_x = float(unit.ax); unit.site_entry_y = float(unit.ay)
	unit.site_inside_uid = int(site.uid); unit.site_follow_uid = -1; unit.site_exit_pending = false
	UnitPosition.place_pixels(unit, float(site.ax), float(site.ay)); UnitPosition.place_cell(unit, int(site.A), int(site.B))
	UnitPath.set_points(unit, []); UnitPath.reset_cursor(unit); CommandState.set_hold(unit, true)
	if not _dep_technology._is_harvester_unit(unit): unit.state = "idle"
	_dep_battle_simulation._place_unit(unit); _dep_battle_simulation._update_visual(unit)

func leave(unit: Dictionary) -> bool:
	if int(unit.get("site_inside_uid", -1)) < 0: return true
	unit.site_exit_pending = true
	var origin := Vector2(float(unit.site_entry_x), float(unit.site_entry_y))
	var start: Vector2i = _nav.cell_of_px(origin.x, origin.y)
	for r in range(0, 13):
		for dx in range(-r, r + 1):
			for dy in range(-r, r + 1):
				if r > 0 and maxi(absi(dx), absi(dy)) != r: continue
				var cell := start + Vector2i(dx, dy)
				if not _dep_spatial_index._unit_placement_free(cell, int(unit.unit), _dep_command_groups._nav_layer(unit), int(unit.uid)): continue
				var point: Vector2 = _nav.anchor_of(cell.x, cell.y)
				if cell != start and _nav.find_path(origin, point, true, _dep_command_groups._nav_layer(unit), int(unit.owner), int(unit.unit)).is_empty(): continue
				unit.site_inside_uid = -1; unit.site_follow_uid = -1; unit.site_exit_pending = false
				UnitPosition.place_pixels(unit, point.x, point.y); UnitPosition.place_cell(unit, cell.x, cell.y)
				_dep_battle_simulation._place_unit(unit); _dep_battle_simulation._update_visual(unit)
				return true
	return false

func order_commander(site: Dictionary, workers: Array) -> void:
	var done := {}
	for worker in workers:
		var commander: Dictionary = _dep_command_groups._commander_for(worker)
		if commander.is_empty() or done.has(int(commander.uid)): continue
		done[int(commander.uid)] = true
		var path: Array = _dep_construction_orders._site_entry_path(commander, site)
		if path.is_empty(): continue
		_dep_command_groups._cancel_unit_command(commander)
		commander.site_follow_uid = int(site.uid); commander.state = "move"
		UnitPath.set_points(commander, path); UnitPath.reset_cursor(commander); CommandState.set_hold(commander, true)

## Returns true when construction owns this unit's current tick.
func step(unit: Dictionary) -> bool:
	var inside := int(unit.get("site_inside_uid", -1))
	if inside >= 0:
		var site := site_for(inside)
		if bool(unit.get("site_exit_pending", false)) or not active(site) \
				or (_dep_technology._is_harvester_unit(unit) and (str(unit.state) != "build" or not _dep_construction_orders._valid_build_worker(unit, site))) \
				or (not _dep_technology._is_harvester_unit(unit) and _dep_command_groups._construction_workers(unit).is_empty()):
			return not leave(unit)
		if _dep_technology._is_harvester_unit(unit):
			unit.build_t = int(unit.get("build_t", 0)) + 1
			if int(unit.build_t) >= int(Balance.work().buildTicks):
				unit.build_t = 0; site.hp = float(site.hp) + float(Balance.work().buildHp)
			if float(site.hp) >= float(site.maxhp): _dep_construction_orders._complete_site(site)
		return true
	var follow := int(unit.get("site_follow_uid", -1))
	if follow < 0: return false
	var site := site_for(follow)
	if not active(site):
		_dep_command_groups._cancel_unit_command(unit); return true
	if _dep_interaction_paths._edge_cell_distance(unit, site) == _state.EDGE_DISTANCE:
		enter(unit, site); return true
	if unit.path.is_empty(): UnitPath.set_points(unit, _dep_construction_orders._site_entry_path(unit, site)); UnitPath.reset_cursor(unit)
	if not unit.path.is_empty(): _dep_movement._follow(unit, _state.SIM_DT)
	return true

func release_site(site: Dictionary) -> void:
	for unit in _state.units:
		if int(unit.get("site_inside_uid", -1)) == int(site.uid) or int(unit.get("site_follow_uid", -1)) == int(site.uid):
			_dep_command_groups._cancel_unit_command(unit)

func valid_snapshot(ids: Dictionary) -> bool:
	for uid in ids:
		var unit: Dictionary = ids[uid]; var state: Dictionary = unit.simulation
		for field in ["site_inside_uid", "site_follow_uid"]:
			var value = state.get(field, -1)
			if value == null: value = -1
			if not (value is int or value is float) or not is_finite(float(value)) or float(value) != floorf(float(value)) or float(value) < -1: return false
		var inside := int(state.get("site_inside_uid", -1)) if state.get("site_inside_uid") != null else -1
		var follow := int(state.get("site_follow_uid", -1)) if state.get("site_follow_uid") != null else -1
		if inside >= 0 and follow >= 0: return false
		if inside >= 0 or follow >= 0:
			if bool(unit.building) or bool(state.get("attached", false)): return false
			var target := inside if inside >= 0 else follow
			if ids.has(target):
				if not bool(ids[target].building) or int(ids[target].owner) != int(unit.owner): return false
			elif not bool(state.get("site_exit_pending", false)): return false
		for field in ["site_entry_x", "site_entry_y"]:
			var value = state.get(field, 0.0)
			if value == null: value = 0.0
			if not (value is int or value is float) or not is_finite(float(value)) or float(value) < 0: return false
		if state.has("site_exit_pending") and state.site_exit_pending != null and not state.site_exit_pending is bool: return false
	return true

func bind_dependencies(world: Object) -> void:
	_nav = world.nav
