extends SceneTree
## CONF-20: verify the actual occupied union is a square, not just its painted hull.
const NINE := [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 20, 22, 23]
const FOUR := [10, 11, 12, 13, 14, 15, 16, 17, 24, 25]

func _initialize() -> void:
	create_timer(30).timeout.connect(func(): quit(1))
	var nav = load("res://simulation/navigation/nav.gd").new()
	var walk: Array = []; walk.resize(40 * 80); walk.fill(1)
	nav.setup({"rows":40,"cols":80,"terrainW":1848,"terrainH":1000,"tileW":44,"walkable":walk,"terrainWalkable":walk,"units":{}})
	for uid in range(27):
		for y in [30, 31]:
			var p: Vector2 = nav.anchor_of(20, y)
			var cells: Array = nav.building_footprint(uid, p, 9999)
			var count := 9 if uid in NINE else (4 if uid in FOUR else 1)
			assert(cells.size() == count, "original footprint class must determine size")
			assert(cells == nav.building_footprint(uid, p, 1), "sprite size cannot change collision")
			var hull: PackedVector2Array = nav.footprint_outline(cells)
			assert(hull.size() == 4, "square footprint has exactly four corners")
			var area := 0.0; var length := -1.0
			for i in range(4):
				var a := hull[i]; var b := hull[(i + 1) % 4]; var edge := b - a
				assert(is_equal_approx(absf(edge.y / edge.x), 0.5), "boundary must follow an isometric axis")
				var world_length := Vector2(edge.x, edge.y * 2).length()
				if length < 0: length = world_length
				assert(is_equal_approx(world_length, length), "all four sides must be equal in world space")
				area += a.cross(b)
			assert(is_equal_approx(absf(area) * 0.5, count * 44.0 * 11.0), "painted square cannot conceal holes or unoccupied notches")
			nav.occupy(cells, 1)
			for cell in cells: assert(nav.is_solid(cell))
			nav.occupy(cells, -1)
			for cell in cells: assert(not nav.is_solid(cell))
			# Gates retain their independent wall-aperture control, tested separately.
			if uid not in [16, 17]:
				var building := {"unit":uid,"is_building":true,"alive":true,"ax":p.x,"ay":p.y,"w":9999.0}
				nav.rebuild_buildings([building])
				assert(building.occupied_cells == cells, "map/load rebuild must match placement exactly")
				nav.occupy(cells, -1)
	assert(nav.building_footprint(0, nav.anchor_of(0, 0), 144).is_empty(), "square cannot be clipped at map edge")
	print("BUILDING SQUARE PASS all27 types x two parities / original1-4-9 cells / four equal sides / exact occupied area / rebuild / map edge")
	quit()
