extends SceneTree
## Real movement through both gate orientations, plus deterministic hostile and
## friendly-priority checks in a corridor with no alternate route.
var done := false

func _initialize() -> void:
	create_timer(75).timeout.connect(func():
		if not done: quit(1))
	_run.call_deferred()

func _run() -> void:
	root.get_node("Game").current_map = "chibil1"
	var battle: Node2D = load("res://main.tscn").instantiate()
	root.add_child(battle)
	battle.set_process(false)
	battle.cli_mode = true
	var worker: Dictionary = battle.units.filter(func(u): return int(u.unit) == 30 and int(u.owner) == int(battle.player_owner))[0]
	var actual_units: Array = battle.units
	assert(_verify_four_gate_openings(battle, actual_units))
	assert(_verify_worker_gate_routes(battle))
	if not _verify_east_gate_route(battle):
		quit(1)
		return
	var reports := []
	for orientation in [16, 17]:
		var gate: Dictionary = actual_units.filter(func(u): return int(u.unit) == orientation)[0]
		var walk: Array = []
		walk.resize(12 * 32)
		walk.fill(0)
		for y in range(32): walk[5 * 32 + y] = 1
		battle.nav.setup({"rows": 12, "cols": 32, "walkable": walk, "terrainWalkable": walk, "terrainW": 616, "terrainH": 512})
		var center: Vector2 = battle.nav.anchor_of(5, 16)
		gate.ax = center.x; gate.ay = center.y
		battle.cam.position = center
		battle.cam.force_update_scroll()
		gate.owner = battle.player_owner
		gate.alive = true; gate.die_t = -1.0
		battle.nav.register_gate(gate)
		battle.units = [gate, worker]
		assert(_verify_gate_resource(battle,gate,worker))
		var start: Vector2 = battle.nav.anchor_of(5, 3)
		var finish: Vector2 = battle.nav.anchor_of(5, 29)
		worker.ax = start.x; worker.ay = start.y
		worker.alive = true; worker.die_t = -1.0; worker.hold = true
		worker.owner = battle.player_owner
		battle.world.battle_simulation._update_gates()
		assert(not gate.gate_open)
		var friendly: Array = battle.world.movement._path_to(worker, finish, true)
		assert(not friendly.is_empty(), "friendly route plans through its own closed gate")
		assert(battle.nav.is_solid(Vector2i(5,16)), "planning must not leave the live gate open")
		var hostile: Dictionary = worker.duplicate()
		hostile.owner = 1 if int(worker.owner) != 1 else 3
		assert(battle.world.movement._path_to(hostile, finish, true).is_empty(), "enemy must not route through a closed gate")
		hostile.ax = center.x; hostile.ay = center.y - 44
		battle.units.append(hostile)
		battle.world.battle_simulation._update_gates()
		assert(not gate.gate_open, "enemy proximity must not open the gate")
		worker.state = "move"; worker.path = friendly; worker.pi = 0
		var opened := false
		var crossed := false
		var enemy_route: Array = []
		for tick in range(1200):
			battle.world.battle_simulation._update_gates()
			battle.world.unit_actions._step_unit(worker, battle.SIM_DT)
			if bool(gate.gate_open):
				opened = true
				assert(not battle.nav.is_solid(Vector2i(5,16)))
				battle.world.battle_simulation._update_visual(gate)
				if battle.view != null:
					assert(int(battle.view.unit_nodes(gate).frame) == 1, "open HD frame must match passability")
					assert(battle.view.unit_nodes(gate).gate_interior.visible, "static terrain wall must not fill the open arch")
				enemy_route = battle.world.movement._path_to(hostile, finish, true)
				assert(not enemy_route.is_empty(), "open gate admits units while friends have priority")
			if float(worker.ay) > center.y + 25: crossed = true
			if worker.state == "idle": break
		assert(opened and crossed and Vector2(worker.ax,worker.ay).distance_to(finish) < 8)
		battle.world.battle_simulation._update_gates()
		assert(not gate.gate_open, "close after the friendly column clears, even with an enemy nearby")
		battle.world.battle_simulation._update_visual(gate)
		if battle.view != null:
			assert(int(battle.view.unit_nodes(gate).frame) == 0, "closed HD frame must match collision")
			assert(not battle.view.unit_nodes(gate).gate_interior.visible)
		assert(battle.world.movement._path_to(hostile, finish, true).is_empty())
		hostile.path = enemy_route; hostile.pi = 0; hostile.state = "move"
		for tick in range(180):
			battle.world.unit_actions._step_unit(hostile, battle.SIM_DT)
			assert(float(hostile.ay) < center.y - 11, "closing gate invalidates an enemy's previously acquired route")
		# Stand inside the arch: an enemy must never force it shut on a friend.
		worker.ax = center.x; worker.ay = center.y
		battle.world.battle_simulation._update_gates()
		assert(gate.gate_open)
		battle.nav.rebuild_buildings([gate])
		battle.world.battle_simulation._update_gates()
		assert(gate.gate_open, "rebuild/load derives open state from current friendly presence")
		battle.nav.remove_gate(gate)
		assert(not battle.nav.is_solid(Vector2i(5,16)), "destroyed gate leaves a passage")
		print("GATE PASS orientation=", orientation, " friendly walk / enemy closure / friendly priority / HD open frame / rebuild / removal")
		reports.append({"orientation": orientation, "friendlyWalk": true, "enemyClosure": true, "friendlyPriority": true, "cachedEnemyRouteBlocked": true, "hdFramesMatchCollision": true, "rebuild": true, "removal": true})
	battle.units = actual_units
	battle.free()
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--gate-report="):
			var file := FileAccess.open(arg.substr(14), FileAccess.WRITE)
			assert(file != null)
			file.store_string(JSON.stringify({"pass": true, "cases": reports}, "  "))
	done = true
	quit()

func _verify_worker_gate_routes(battle: Node2D) -> bool:
	var nav = battle.nav
	var approaches := {
		Vector2i(13, 173): [Vector2i(11, 169), Vector2i(15, 177)],
		Vector2i(32, 175): [Vector2i(33, 168), Vector2i(32, 182)],
		Vector2i(33, 213): [Vector2i(32, 207), Vector2i(37, 215)],
		Vector2i(13, 214): [Vector2i(14, 208), Vector2i(10, 215)],
	}
	for gate in nav.gates:
		var cell := Vector2i(gate.A, gate.B)
		var module: Node2D = battle.view.unit_nodes(gate).gate_module
		var aperture: PackedVector2Array = module.aperture
		var front := module.to_global((aperture[2] + aperture[3]) * 0.5)
		var slope: float = module.slope(int(gate.unit))
		var width: float = aperture[1].x - aperture[0].x
		var passage: Dictionary = nav.grid.gate_passage(cell)
		assert(passage.has("cells") and is_equal_approx(float(passage.width), width))
		for pair in passage.cells:
			var anchor: Vector2 = nav.anchor_of(pair[0], pair[1])
			assert(absf(_door_axis(anchor - front, slope)) < width * 0.5,
				"Every freed cell must centre on the rendered doorway: %s %s" % [cell, pair])
		var start: Vector2i = approaches[cell][0]
		var goal: Vector2i = approaches[cell][1]
		var spawn: Vector2 = nav.anchor_of(start.x, start.y)
		assert(battle.world.entity_factory._spawn_unit(30, int(gate.owner), spawn.x, spawn.y, true))
		var worker: Dictionary = battle.units.back()
		battle.selected = [worker]
		for destination in [goal, start]:
			var target: Vector2 = nav.anchor_of(destination.x, destination.y)
			assert(battle.world.world_orders.submit_point_order(target, true) == 1)
			assert(battle.world.player_commands.apply_tick(battle.sim_tick + 1) == 1)
			var crossed := false
			for tick in range(450):
				battle.world.battle_simulation._update_gates()
				battle.world.unit_actions._step_unit(worker, battle.SIM_DT)
				var point := Vector2(worker.ax, worker.ay)
				var foot: Vector2i = nav.cell_of_px(point.x, point.y)
				assert(not nav.is_solid(foot), "Worker entered a solid wall cell at %s" % foot)
				if nav.gate_cells.get(nav._id(foot), []).has(gate):
					assert(gate.gate_open and absf(_door_axis(point - front, slope)) < width * 0.5)
					crossed = true
				if worker.state == "idle": break
			assert(crossed and Vector2(worker.ax, worker.ay).distance_to(target) < 1.0,
				"Gate %s must reach %s (crossed=%s, stopped at %s)" % [cell, destination, crossed, Vector2(worker.ax, worker.ay)])
		battle.world.battle_simulation._free_unit_at(battle.units.size()-1)
	battle.selected = []
	print("LIU WORKER GATES PASS four rendered apertures / both directions / solid curtain")
	return true

func _door_axis(offset: Vector2, slope: float) -> float:
	return (offset.x + offset.y / slope) * 0.5

func _verify_east_gate_route(battle: Node2D) -> bool:
	var nav = battle.nav
	var gate: Dictionary = battle.units.filter(func(u): return int(u.unit) == 16 and int(u.A) == 32 and int(u.B) == 175)[0]
	var owner := int(gate.owner)
	var mouth := [Vector2i(32,173), Vector2i(32,174), Vector2i(32,175), Vector2i(33,176), Vector2i(32,177)]
	var wall := [Vector2i(32,172), Vector2i(31,173), Vector2i(33,177), Vector2i(33,178)]
	var center: Vector2 = nav.anchor_of(32,175)
	var outside: Vector2 = nav.anchor_of(33,168)
	var inside: Vector2 = nav.anchor_of(32,182)
	nav.set_gate_open(gate, false)
	for cell in mouth:
		assert(nav.is_solid(cell), "closed east gate must cover the widened passage")
	assert(nav.find_path(outside, inside, true, 0, 3, 37).is_empty(), "hostile four-cell cavalry cannot plan through the closed gate")
	nav.set_gate_open(gate, true)
	for cell in mouth:
		assert(not nav.is_solid(cell), "the widened east passage must open")
	for cell in wall:
		assert(nav.is_solid(cell), "the next wall cells must still block movement")
	nav.set_gate_open(gate, false)
	var wall_normal := Vector2(-0.5, 1)
	var wall_axis := Vector2(1, 0.5)
	for unit in [30,36,37,40]:
		assert(battle.world.entity_factory._spawn_unit(unit, owner, outside.x, outside.y, true))
		var moving: Dictionary = battle.units.back()
		for target in [inside, outside]:
			battle.selected = [moving]
			assert(battle.world.world_orders.submit_point_order(target, true) == 1)
			assert(battle.world.player_commands.apply_tick(battle.sim_tick + 1) == 1)
			var route_end: Vector2 = moving.path.back()
			var opened := false
			var crossings := 0
			var previous := Vector2(float(moving.ax), float(moving.ay))
			for tick in range(600):
				battle.world.battle_simulation._update_gates()
				opened = opened or bool(gate.gate_open)
				battle.world.unit_actions._step_unit(moving, battle.SIM_DT)
				var point := Vector2(float(moving.ax), float(moving.ay))
				var a := (previous-center).dot(wall_normal)
				var b := (point-center).dot(wall_normal)
				if (a < 0 and b >= 0) or (a > 0 and b <= 0):
					var offset := (previous.lerp(point, a/(a-b))-center).dot(wall_axis)/wall_axis.length_squared()
					assert(absf(offset) < 33 and bool(gate.gate_open), "the unit must cross at the open east aperture")
					crossings += 1
				previous = point
				if moving.state == "idle": break
			assert(opened and crossings == 1 and previous.distance_to(route_end) < 8 and previous.distance_to(target) < 25, "unit %d failed at %s, commanded %s, route end %s, crossings %d, state %s" % [unit, previous, target, route_end, crossings, moving.state])
			battle.world.battle_simulation._update_gates()
			assert(not gate.gate_open, "the east gate closes once the passage has cleared")
		battle.world.battle_simulation._free_unit_at(battle.units.size()-1)
	battle.selected = []
	print("EAST GATE PASS real map / sealed walls / actual player orders / single-cell units and cavalry 200/500 in both directions")
	return true

func _verify_four_gate_openings(battle: Node2D, units: Array) -> bool:
	var found := {16: 0, 17: 0}
	for raw in units:
		var gate: Dictionary = raw
		var id := int(gate.unit)
		if id not in [16, 17]: continue
		found[id] = int(found[id]) + 1
		assert(battle.view.unit_nodes(gate).has("gate_module") and not battle.view.unit_nodes(gate).skin.visible,"only the replacement door module is drawn, not a second wall")
		var module: Node2D = battle.view.unit_nodes(gate).gate_module
		var expected_drop := 25.0 if int(gate.B)<200 else -19.0
		assert(is_equal_approx(module.foundation_drop,expected_drop),"east/south must meet the wall; west/north retain their existing registration")
		module.update_open(true)
		assert(not module.panel.visible and module.recess.visible,"open gate exposes a recessed passage instead of another painted door")
		assert(module.passage_height(0) >= 45 and module.passage_height(0) <= 50,"opening is lower and stays inside the original wall height")
		module.update_open(false)
		assert(module.panel.polygon.size() == 4)
		assert(module.aperture[1].x-module.aperture[0].x >= 32,"door opening is at least 20% wider than the old 26.7-pixel door")
		assert(module.depth_vector(id).length() >= 30,"door has full wall depth")
		var box := Rect2(module.panel.polygon[0],Vector2.ZERO)
		for point in module.panel.polygon: box = box.expand(point)
		var east := int(gate.A) == 32 and int(gate.B) == 175
		var expected: float = 66.0 if east else module.WIDTH
		assert(is_equal_approx(box.size.x, expected), "only the east door is widened")
		assert(is_equal_approx(box.size.y-expected*absf(module.slope(id)), module.PASSAGE_HEIGHT), "the doorway keeps the original passage height")
		var offset: Vector2 = battle.remaster_art.gate_wall_offset(str(battle.map_id),Vector2i(gate.A,gate.B))
		assert(module.position.is_equal_approx(offset*(battle.view.unit_nodes(gate).skin as Sprite2D).get_meta("parent_scale")),"registration reaches the door module")
	assert(int(found[16]) == 2 and int(found[17]) == 2, "the map has four openings across both wall diagonals")
	print("GATE ART PASS four ChibiL1 openings / thick embedded double gate / preserved terrain wall / closed wood and recessed open passage / per-wall registration")
	return true

func _verify_gate_resource(battle: Node2D, gate: Dictionary, worker: Dictionary) -> bool:
	var saved_cells: Dictionary = battle.decor_cells
	var start: Vector2 = battle.nav.anchor_of(5,3)
	worker.ax=start.x;worker.ay=start.y;worker.owner=battle.player_owner;worker.carry=0.0
	worker.path=[];worker.state="idle"
	var point: Vector2 = battle.nav.anchor_of(5,18)
	var crop := {"ax":point.x,"ay":point.y,"unit":102,"decor":true,"alive":true,"uid":-99999,"owner":0,"die_t":-1.0,"w":44,"h":60,"stock":200.0,"phase":2}
	battle.decor_cells={"5_18":crop}
	battle.world.battle_simulation._update_gates()
	assert(not gate.gate_open)
	var choice: Dictionary = battle.world.harvest_orders._harvest_interaction_choice(worker,crop)
	assert(not choice.is_empty(),"closed friendly gate must not reject the only resource edge before A* runs")
	assert(not gate.gate_open,"planning a harvest never changes the live gate state")
	var hostile: Dictionary=worker.duplicate();hostile.owner=1
	assert(battle.world.harvest_orders._harvest_interaction_choice(hostile,crop).is_empty(),"enemy gate remains blocked for resource orders")
	battle.world.harvest_orders._begin_gather(worker,crop,choice.path)
	for tick in range(800):
		battle.world.battle_simulation._update_gates();battle.world.unit_actions._step_unit(worker,battle.SIM_DT)
		if float(worker.carry)>0:break
	assert(is_equal_approx(float(worker.carry),200.0),"worker must actually pass the gate and load the resource")
	worker.carry=0.0;worker.path=[];worker.state="idle"
	# Nearby idle units outside the mouth must not leave a permanent tunnel.
	worker.ax=float(gate.ax)+66;worker.ay=float(gate.ay)-33
	battle.world.battle_simulation._update_gates()
	assert(not gate.gate_open,"idle troops beside a gate leave its purple leaves closed")
	battle.decor_cells=saved_cells
	print("GATE RESOURCE PASS friendly edge / hostile blocked / actual cargo / idle closure")
	return true
