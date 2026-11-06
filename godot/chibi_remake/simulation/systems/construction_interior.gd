extends RefCounted
## Workers and their commander leave the battlefield while working inside a site.
const Access = preload("res://simulation/ports/construction_interior_access.gd")
var host: Access
const FIELDS := ["site_inside_uid", "site_follow_uid", "site_entry_x", "site_entry_y", "site_exit_pending"]

func _init(battle: Object) -> void: host = battle.simulation_access("construction_interior") if battle.has_method("simulation_access") else battle

func site_for(uid: int) -> Dictionary:
	for site in host.units:
		if int(site.uid) == uid: return site
	return {}

func active(site: Dictionary) -> bool:
	return not site.is_empty() and bool(site.alive) and float(site.die_t) < 0 and bool(site.get("site", false))

func enter(unit: Dictionary, site: Dictionary) -> void:
	if host._is_worker_unit(unit) and int(unit.unit)!=30:return
	unit.site_entry_x = float(unit.ax); unit.site_entry_y = float(unit.ay)
	unit.site_inside_uid = int(site.uid); unit.site_follow_uid = -1; unit.site_exit_pending = false
	unit.ax = float(site.ax); unit.ay = float(site.ay); unit.A = int(site.A); unit.B = int(site.B)
	unit.path = []; unit.pi = 0; unit.hold = true
	if not host._is_worker_unit(unit): unit.state = "idle"
	host._place_unit(unit); host._update_visual(unit)

func leave(unit: Dictionary) -> bool:
	if int(unit.get("site_inside_uid", -1)) < 0: return true
	unit.site_exit_pending = true
	var origin := Vector2(float(unit.site_entry_x), float(unit.site_entry_y))
	var start: Vector2i = host.nav.cell_of_px(origin.x, origin.y)
	for r in range(0, 13):
		for dx in range(-r, r + 1):
			for dy in range(-r, r + 1):
				if r > 0 and maxi(absi(dx), absi(dy)) != r: continue
				var cell := start + Vector2i(dx, dy)
				if not host._unit_placement_free(cell, int(unit.unit), host._nav_layer(unit), int(unit.uid)): continue
				var point: Vector2 = host.nav.anchor_of(cell.x, cell.y)
				if cell != start and host.nav.find_path(origin, point, true, host._nav_layer(unit), int(unit.owner), int(unit.unit)).is_empty(): continue
				unit.site_inside_uid = -1; unit.site_follow_uid = -1; unit.site_exit_pending = false
				unit.ax = point.x; unit.ay = point.y; unit.A = cell.x; unit.B = cell.y
				host._place_unit(unit); host._update_visual(unit)
				return true
	return false

func order_commander(site: Dictionary, workers: Array) -> void:
	var done := {}
	for worker in workers:
		var commander: Dictionary = host._commander_for(worker)
		if commander.is_empty() or done.has(int(commander.uid)): continue
		done[int(commander.uid)] = true
		var path: Array = host._site_entry_path(commander, site)
		if path.is_empty(): continue
		host._cancel_unit_command(commander)
		commander.site_follow_uid = int(site.uid); commander.state = "move"
		commander.path = path; commander.pi = 0; commander.hold = true

## Returns true when construction owns this unit's current tick.
func step(unit: Dictionary) -> bool:
	var inside := int(unit.get("site_inside_uid", -1))
	if inside >= 0:
		var site := site_for(inside)
		if bool(unit.get("site_exit_pending", false)) or not active(site) \
				or (host._is_worker_unit(unit) and (str(unit.state) != "build" or not host._valid_build_worker(unit, site))) \
				or (not host._is_worker_unit(unit) and host._construction_workers(unit).is_empty()):
			return not leave(unit)
		if host._is_worker_unit(unit):
			unit.build_t = int(unit.get("build_t", 0)) + 1
			if int(unit.build_t) >= host.BUILD_STEP_TICKS:
				unit.build_t = 0; site.hp = float(site.hp) + host.BUILD_STEP_HP
			if float(site.hp) >= float(site.maxhp): host._complete_site(site)
		return true
	var follow := int(unit.get("site_follow_uid", -1))
	if follow < 0: return false
	var site := site_for(follow)
	if not active(site):
		host._cancel_unit_command(unit); return true
	if host._edge_cell_distance(unit, site) == host.EDGE_DISTANCE:
		enter(unit, site); return true
	if unit.path.is_empty(): unit.path = host._site_entry_path(unit, site); unit.pi = 0
	if not unit.path.is_empty(): host._follow(unit, host.SIM_DT)
	return true

func release_site(site: Dictionary) -> void:
	for unit in host.units:
		if int(unit.get("site_inside_uid", -1)) == int(site.uid) or int(unit.get("site_follow_uid", -1)) == int(site.uid):
			host._cancel_unit_command(unit)

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
