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
	var actual_nav = battle.nav
	var actual_units: Array = battle.units
	assert(_verify_four_gate_openings(battle, actual_units))
	var reports := []
	for orientation in [16, 17]:
		var gate: Dictionary = actual_units.filter(func(u): return int(u.unit) == orientation)[0]
		var walk: Array = []
		walk.resize(12 * 32)
		walk.fill(0)
		for y in range(32): walk[5 * 32 + y] = 1
		battle.nav = load("res://simulation/navigation/nav.gd").new()
		battle.nav.setup({"rows": 12, "cols": 32, "walkable": walk, "terrainWalkable": walk, "terrainW": 616, "terrainH": 512})
		var center: Vector2 = battle.nav.anchor_of(5, 16)
		gate.ax = center.x; gate.ay = center.y
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
		battle.commands.world._update_gates()
		assert(not gate.gate_open)
		var friendly: Array = battle.commands.orders._path_to(worker, finish, true)
		assert(not friendly.is_empty(), "friendly route plans through its own closed gate")
		assert(battle.nav.is_solid(Vector2i(5,16)), "planning must not leave the live gate open")
		var hostile: Dictionary = worker.duplicate()
		hostile.owner = 1 if int(worker.owner) != 1 else 3
		assert(battle.commands.orders._path_to(hostile, finish, true).is_empty(), "enemy must not route through a closed gate")
		hostile.ax = center.x; hostile.ay = center.y - 44
		battle.units.append(hostile)
		battle.commands.world._update_gates()
		assert(not gate.gate_open, "enemy proximity must not open the gate")
		worker.state = "move"; worker.path = friendly; worker.pi = 0
		var opened := false
		var crossed := false
		var enemy_route: Array = []
		for tick in range(1200):
			battle.commands.world._update_gates()
			battle.commands.orders._step_unit(worker, battle.SIM_DT)
			if bool(gate.gate_open):
				opened = true
				assert(not battle.nav.is_solid(Vector2i(5,16)))
				battle.commands.world._update_visual(gate)
				if battle.view != null:
					assert(int(battle.view.unit_nodes(gate).frame) == 1, "open HD frame must match passability")
					assert(battle.view.unit_nodes(gate).gate_interior.visible, "static terrain wall must not fill the open arch")
				enemy_route = battle.commands.orders._path_to(hostile, finish, true)
				assert(not enemy_route.is_empty(), "open gate admits units while friends have priority")
			if float(worker.ay) > center.y + 25: crossed = true
			if worker.state == "idle": break
		assert(opened and crossed and Vector2(worker.ax,worker.ay).distance_to(finish) < 8)
		battle.commands.world._update_gates()
		assert(not gate.gate_open, "close after the friendly column clears, even with an enemy nearby")
		battle.commands.world._update_visual(gate)
		if battle.view != null:
			assert(int(battle.view.unit_nodes(gate).frame) == 0, "closed HD frame must match collision")
			assert(not battle.view.unit_nodes(gate).gate_interior.visible)
		assert(battle.commands.orders._path_to(hostile, finish, true).is_empty())
		hostile.path = enemy_route; hostile.pi = 0; hostile.state = "move"
		for tick in range(180):
			battle.commands.orders._step_unit(hostile, battle.SIM_DT)
			assert(float(hostile.ay) < center.y - 11, "closing gate invalidates an enemy's previously acquired route")
		# Stand inside the arch: an enemy must never force it shut on a friend.
		worker.ax = center.x; worker.ay = center.y
		battle.commands.world._update_gates()
		assert(gate.gate_open)
		battle.nav.rebuild_buildings([gate])
		battle.commands.world._update_gates()
		assert(gate.gate_open, "rebuild/load derives open state from current friendly presence")
		battle.nav.remove_gate(gate)
		assert(not battle.nav.is_solid(Vector2i(5,16)), "destroyed gate leaves a passage")
		print("GATE PASS orientation=", orientation, " friendly walk / enemy closure / friendly priority / HD open frame / rebuild / removal")
		reports.append({"orientation": orientation, "friendlyWalk": true, "enemyClosure": true, "friendlyPriority": true, "cachedEnemyRouteBlocked": true, "hdFramesMatchCollision": true, "rebuild": true, "removal": true})
	battle.nav = actual_nav
	battle.units = actual_units
	battle.free()
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--gate-report="):
			var file := FileAccess.open(arg.substr(14), FileAccess.WRITE)
			assert(file != null)
			file.store_string(JSON.stringify({"pass": true, "cases": reports}, "  "))
	done = true
	quit()

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
		assert(box.size.x <= 44 and box.size.y <= 67,"door width and height fit the original wall opening")
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
	battle.commands.world._update_gates()
	assert(not gate.gate_open)
	var choice: Dictionary = battle.commands.orders._edge_interaction_choice(worker,crop)
	assert(not choice.is_empty(),"closed friendly gate must not reject the only resource edge before A* runs")
	assert(not gate.gate_open,"planning a harvest never changes the live gate state")
	var hostile: Dictionary=worker.duplicate();hostile.owner=1
	assert(battle.commands.orders._edge_interaction_choice(hostile,crop).is_empty(),"enemy gate remains blocked for resource orders")
	battle.commands.economy._begin_gather(worker,crop,choice.path)
	for tick in range(800):
		battle.commands.world._update_gates();battle.commands.orders._step_unit(worker,battle.SIM_DT)
		if float(worker.carry)>0:break
	assert(is_equal_approx(float(worker.carry),200.0),"worker must actually pass the gate and load the resource")
	worker.carry=0.0;worker.path=[];worker.state="idle"
	# Nearby idle units outside the mouth must not leave a permanent tunnel.
	worker.ax=float(gate.ax)+66;worker.ay=float(gate.ay)-33
	battle.commands.world._update_gates()
	assert(not gate.gate_open,"idle troops beside a gate leave its purple leaves closed")
	battle.decor_cells=saved_cells
	print("GATE RESOURCE PASS friendly edge / hostile blocked / actual cargo / idle closure")
	return true
