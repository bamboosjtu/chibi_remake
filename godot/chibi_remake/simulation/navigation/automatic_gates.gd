extends RefCounted
## One source of truth for gate visuals and collision. Friendly presence takes
## priority over enemies. The clearance zone covers both sides of a marching
## column; state is derived from positions so snapshot restores are deterministic.

func update(nav, units: Array) -> void:
	for gate in nav.gates.duplicate():
		if not bool(gate.alive) or float(gate.get("die_t", -1.0)) >= 0.0:
			nav.remove_gate(gate)
			continue
		var opened := false
		if not bool(gate.get("site", false)):
			var rx: float = nav.tile_w * 2.5
			var ry: float = nav.tile_hh * 8.0
			for unit in units:
				if bool(unit.is_building) or not bool(unit.alive) or float(unit.get("die_t", -1.0)) >= 0.0:
					continue
				if int(unit.owner) != int(gate.owner) or bool(unit.get("attached", false)) or int(unit.get("site_inside_uid", -1)) >= 0:
					continue
				var dx: float = (float(unit.ax) - float(gate.ax)) / rx
				var dy: float = (float(unit.ay) - float(gate.ay)) / ry
				var in_mouth: bool = absf(float(unit.ax)-float(gate.ax)) <= nav.tile_w*0.65 and absf(float(unit.ay)-float(gate.ay)) <= nav.tile_hh*2
				if in_mouth or (dx * dx + dy * dy <= 1.0 and _route_uses_gate(nav,gate,unit)):
					opened = true
					break
		nav.set_gate_open(gate, opened)

func _route_uses_gate(nav, gate: Dictionary, unit: Dictionary) -> bool:
	var path: Array = unit.get("path",[])
	var first := maxi(0,int(unit.get("pi",0)))
	for index in range(first,mini(path.size(),first+16)):
		var point: Vector2 = path[index]
		var cell: Vector2i = nav.cell_of_px(point.x,point.y)
		var id: int = nav._id(cell)
		if nav.gate_cells.get(id,[]).has(gate): return true
	return false
