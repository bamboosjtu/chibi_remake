extends SceneTree
## R03 回归：运输船的持续卸载状态（unload_active）与每 4 tick 的相位（unload_t）
## 必须进入存档；同一快照继续 N tick 与不读档继续 N tick 的载员/位置一致。
var b: Node2D
var game: Node
var done := false

func _initialize() -> void:
	create_timer(90).timeout.connect(func():
		if not done: quit(1))
	run.call_deferred()

func spawn(kind: int, point: Vector2) -> Dictionary:
	assert(b.commands._spawn_unit(kind, b.player_owner, point.x, point.y, true))
	return b.units.back()

func find(uid: int) -> Dictionary:
	var found: Array = b.units.filter(func(u): return int(u.uid) == uid)
	assert(found.size() == 1)
	return found[0]

func connected_land(start:Vector2i,limit:int) -> Array:
	var cells:Array=[start];var seen:Dictionary={start:true};var cursor:=0
	while cursor<cells.size() and cells.size()<limit:
		var cell:Vector2i=cells[cursor];cursor+=1
		for neighbor in b.nav.neighbors(cell):
			if seen.has(neighbor):continue
			seen[neighbor]=true
			if not b.nav.is_water(neighbor) and not b.nav.is_solid(neighbor,0):cells.append(neighbor)
	return cells

func shore_pair() -> Array:
	for a in range(4,int(b.map_data.rows)-4):
		for row in range(9,int(b.map_data.cols)-9):
			var sea:=Vector2i(a,row)
			if not b.nav.is_water(sea) or not b.commands._unit_placement_free(sea,47,1):continue
			var point:Vector2=b.nav.anchor_of(sea.x,sea.y)
			var probe:Dictionary={"unit":47,"ax":point.x,"ay":point.y,"is_building":false}
			var anchors:Array=b.transports.coastal_anchors(probe,30)
			if anchors.size()>=3 and connected_land(anchors[0],40).size()>=40:return [sea,anchors[0]]
	assert(false,"expected navigable whole-body coastline with land slots")
	return []

func snapshot() -> Dictionary:
	assert(game.save_game(b.units, b.commands._resources(), b.commands._save_extra()))
	return game.load_save()

## 用 uid 记录整场（船 + 载员）的可比较状态。
func capture(uids: Array) -> Dictionary:
	var out := {}
	for uid in uids:
		var unit := find(int(uid))
		out[int(uid)] = {
			"cell": [int(unit.A), int(unit.B)],
			"state": str(unit.state),
			"attached": bool(unit.get("attached", false)),
			"carry": int(unit.get("carry_n", 0)),
			"unload_active": bool(unit.get("unload_active", false)),
			"unload_t": int(unit.get("unload_t", 0)),
		}
	return out

func run() -> void:
	game = root.get_node("Game")
	game.current_map = "chibic13"
	b = load("res://main.tscn").instantiate()
	root.add_child(b)
	b.set_process(false)
	b.cli_mode = true
	b.ai = null
	while not b.units.is_empty():
		b.commands._free_unit_at(b.units.size() - 1)
	b.nav.rebuild_buildings(b.units)

	var pair := shore_pair()
	var sea: Vector2i = pair[0]
	var land: Vector2i = pair[1]
	var ship := spawn(47, b.nav.anchor_of(sea.x, sea.y))
	var ship_uid := int(ship.uid)
	var people: Array = []
	for i in range(2):
		var worker := spawn(30, b.nav.anchor_of(land.x, land.y))
		people.append(int(worker.uid))
		assert(b.commands._attach_to_ship(worker, ship))
	assert(int(ship.carry_n) == 2 and ship.loaded)
	assert(b.commands._order_unload(ship, b.nav.anchor_of(land.x, land.y)) == 1)
	for tick in range(3):
		b.commands._step_unit(ship, b.SIM_DT)
	assert(int(ship.unload_t) == 3 and int(ship.carry_n) == 2, "夹具：tick 3 尚未落位")
	# 运输船可接收新命令（state=move）后继续卸载；这正是评审复现的字段组合。
	ship.state = "move"
	ship.path = []
	ship.pi = 0
	var payload := snapshot()
	assert(int(payload.v) == 8)
	var ship_record: Dictionary = payload.units.filter(func(u): return int(u.uid) == ship_uid)[0]
	assert(ship_record.simulation.get("unload_active") == true, "R03: unload_active 必须入档")
	assert(int(ship_record.simulation.get("unload_t", -1)) == 3, "R03: unload_t 相位必须入档")

	var watched: Array = [ship_uid] + people
	# A：不读档，继续 13 tick。
	for tick in range(13):
		b.commands._step_unit(ship, b.SIM_DT)
	var without_load := capture(watched)

	# B：恢复同一快照后继续 13 tick。
	assert(b.saver.apply_snapshot(payload), "R03: 合法卸载快照必须可恢复")
	ship = find(ship_uid)
	assert(str(ship.state) == "move", "R03: 读档保留当前命令")
	assert(bool(ship.get("unload_active", false)), "R03: 读档保留持续卸载标志")
	assert(int(ship.get("unload_t", -1)) == 3, "R03: 读档保留卸载相位")
	for tick in range(13):
		b.commands._step_unit(ship, b.SIM_DT)
	var after_load := capture(watched)
	assert(after_load == without_load, "R03: 读档前后继续相同 tick 必须得到相同载员与位置\nA=%s\nB=%s" % [str(without_load), str(after_load)])
	assert(int(find(ship_uid).carry_n) == 0, "R03: 两名载员都应在 16 tick 内落位")

	# 坏结构必须在交换世界前拒绝：非船拥有卸载状态、负相位、非布尔标志。
	var identity: Dictionary = b.units[0]
	for mode in range(3):
		var invalid := payload.duplicate(true)
		var record: Dictionary = invalid.units.filter(func(u): return int(u.uid) == people[0])[0]
		match mode:
			0: record.simulation.unload_active = true
			1:
				var vessel: Dictionary = invalid.units.filter(func(u): return int(u.uid) == ship_uid)[0]
				vessel.simulation.unload_t = -2
			2:
				var vessel: Dictionary = invalid.units.filter(func(u): return int(u.uid) == ship_uid)[0]
				vessel.simulation.unload_active = "yes"
		assert(not b.saver.apply_snapshot(invalid), "R03: 非法卸载状态必须拒绝 mode=%d" % mode)
		assert(b.units.size() > 0 and is_same(b.units[0], identity), "R03: 拒绝坏档时不能交换世界")
	print("UNLOAD STATE PASS active+phase saved / new move order keeps unloading / identical continuation / malformed snapshots rejected")
	done = true
	b.queue_free()
	await process_frame
	quit(0)
