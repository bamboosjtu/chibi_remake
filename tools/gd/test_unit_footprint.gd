extends SceneTree
## CONF-20 占格回归：档 1=4 格、档 3=16 格、y 奇偶表、出生/防叠。
var finished := false

func _initialize() -> void:
	create_timer(60).timeout.connect(func(): if not finished: quit(1))
	_run.call_deferred()

func _run() -> void:
	var game = root.get_node("Game"); game.current_map = "chibic1"
	var b: Node2D = load("res://main.tscn").instantiate(); root.add_child(b)
	b.set_process(false); b.cli_mode = true
	var UF = load("res://simulation/systems/unit_footprint.gd")
	assert(UF.class_of(30) == 0 and UF.class_of(34) == 1 and UF.class_of(49) == 3)
	var even4: Array = UF.shape(34, Vector2i(10, 20))
	var odd4: Array = UF.shape(34, Vector2i(10, 21))
	assert(even4.size() == 4 and odd4.size() == 4)
	assert(even4[0] == Vector2i(10, 20) and even4[1] == Vector2i(9, 19))
	assert(odd4[1] == Vector2i(10, 20) and odd4[2] == Vector2i(11, 20))
	assert(UF.shape(49, Vector2i(10, 20)).size() == 16)
	assert(UF.shape(30, Vector2i(10, 20)) == [Vector2i(10, 20)])

	# 4 格单位出生时不得与已有单位占格重叠。
	var worker: Dictionary = b.units.filter(func(u): return u.alive and int(u.owner) == b.player_owner and int(u.unit) == 30)[0]
	var wc: Vector2i = b.commands._unit_cell(worker)
	var start: Vector2i = b.commands._free_unit_cell(wc, 0, -1, 34)
	assert(start.x >= 0 and not b.commands._unit_placement_free(wc, 34, 0, -1))
	assert(b.commands._unit_placement_free(start, 34, 0, -1))
	var p: Vector2 = b.nav.anchor_of(start.x, start.y)
	assert(b.commands._spawn_unit(34, b.player_owner, p.x, p.y, false))
	var tank: Dictionary = b.units.back()
	var cells: Array = b.commands._footprint_cells(tank)
	assert(cells.size() == 4, "车兵应为 4 格占位")
	for c in cells:
		assert(b.commands._unit_placement_free(c, 34, 0, int(tank.uid)) or c == start)
	print("UNIT FOOTPRINT PASS class0/1/3, parity, spawn placement")
	b.free(); finished = true; quit(0)
