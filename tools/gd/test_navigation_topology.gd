extends SceneTree
func _initialize() -> void:
	var nav = load("res://simulation/navigation/nav.gd").new()
	var walk: Array = []; walk.resize(144); walk.fill(1)
	nav.setup({"rows":12,"cols":12,"tileW":44,"terrainW":550,"terrainH":160,"walkable":walk,"terrainWalkable":walk})
	nav.block(Vector2i(5,5))
	for shape in [1,2,3]:
		var actual: AStar2D = nav.paths._shape_graph(0,shape)
		var reference := AStar2D.new()
		for a in range(12):
			for b in range(12):
				var cell := Vector2i(a,b)
				reference.add_point(nav.grid._id(cell),nav.anchor_of(a,b))
		for a in range(12):
			for b in range(12):
				var cell := Vector2i(a,b)
				for next in nav.neighbors(cell):
					if not reference.are_points_connected(nav.grid._id(cell),nav.grid._id(next)): reference.connect_points(nav.grid._id(cell),nav.grid._id(next))
		for a in range(12):
			for b in range(12):
				var cell := Vector2i(a,b)
				reference.set_point_disabled(nav.grid._id(cell),not nav.paths._anchor_fits(cell,0,shape))
		for id in reference.get_point_ids(): assert(actual.get_point_connections(id) == reference.get_point_connections(id),"Connection order changed")
		for start in range(0,144,13):
			for finish in range(0,144,17):
				if reference.is_point_disabled(start) or reference.is_point_disabled(finish): continue
				assert(actual.get_id_path(start,finish) == reference.get_id_path(start,finish),"A* tie breaking changed")
	print("NAVIGATION TOPOLOGY PASS original connections / insertion order / footprint paths and tie breaking")
	quit()
