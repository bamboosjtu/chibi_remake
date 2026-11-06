extends SceneTree
## Remove only the low, projecting platform connected to an actual gate.
## Original terrain atlases and baked chunks remain untouched. Each RGBA patch
## has coverage solely inside that platform's original MED geometry mask.
const SOURCE := "res://../../_work/full-art-map-source/"
const ART := "res://art/full/"
const REFERENCES := "res://art/production/references/"
var tiles := {}
var masks := {}
var grounds: Array

func _initialize() -> void: run.call_deferred()

func _json(path: String) -> Dictionary:
	var file := FileAccess.open(path,FileAccess.READ)
	assert(file != null,path)
	return JSON.parse_string(file.get_as_text())

func _image(path: String) -> Image:
	var image := Image.load_from_file(ProjectSettings.globalize_path(path))
	assert(image != null,path)
	image.convert(Image.FORMAT_RGBA8)
	return image

func run() -> void:
	var index := _json(SOURCE+"index.json")
	grounds = index.grounds
	_prepare_tiles()
	var manifest := {"schemaVersion":1,"source":"gate platform components only; baseline MED layers and original geometry masks","maps":{}}
	var count := 0
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(ART+"gate_terrain"))
	for map_id in index.maps:
		if "--chibil1-only" in OS.get_cmdline_user_args() and map_id != "chibil1": continue
		var level := _json("res://data/%s.json" % map_id)
		var gates: Array = level.objects.filter(func(u): return int(u.unit) in [16,17])
		if gates.is_empty(): continue
		var map := _json(SOURCE+str(map_id)+".json")
		var cells := {}
		for layer in map.layers:
			for a in range(int(map.rows)):
				for b in range(int(map.cols)):
					var value := int(layer[a][b])
					if value != 65535 and ((value>>8)&15) == 9: cells[Vector2i(a,b)] = value
		var patches := []
		for gate in gates:
			var cell := Vector2i(int(gate.A),int(gate.B))
			assert(cells.has(cell),"Gate must identify its own platform: %s/%s" % [map_id,cell])
			var component := {cell:cells[cell]}
			var pending := [cell]
			while not pending.is_empty():
				var next: Vector2i = pending.pop_back()
				for da in [-1,0,1]:
					for db in [-1,0,1]:
						var neighbor := next+Vector2i(da,db)
						if cells.has(neighbor) and not component.has(neighbor):
							component[neighbor] = cells[neighbor]; pending.append(neighbor)
			assert(component.size() <= 20,"Refuse to replace a non-gate wall component")
			patches.append(_patch(str(map_id),map,cell,int(gate.unit),component))
			count += 1
		manifest.maps[map_id] = patches
		print("GATE TERRAIN PATCH ",map_id," ",patches.size()," gate platforms only")
	var file := FileAccess.open(ART+"gate_terrain/manifest.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(manifest,"  "))
	print("GATE TERRAIN PASS ",count," local patches; no original terrain files modified")
	quit()

func _position(cell: Vector2i, ground: int) -> Vector2i:
	return Vector2i(44*cell.x+22*(cell.y&1),11*cell.y-(int(grounds[ground].H)-22))*4

func _patch(map_id: String, map: Dictionary, gate: Vector2i, unit_id: int, component: Dictionary) -> Dictionary:
	var corrections := _straight_connections(map,gate,unit_id,component)
	var area := Rect2i(_position(gate,9),Vector2i(176,200))
	for cell in component: area = area.merge(Rect2i(_position(cell,9),Vector2i(176,200)))
	for cell in corrections: area = area.merge(Rect2i(_position(cell,6),Vector2i(176,308)))
	var canvas := Image.create(area.size.x,area.size.y,false,Image.FORMAT_RGBA8)
	var road := Image.create(area.size.x,area.size.y,false,Image.FORMAT_RGBA8)
	var wall_mask := Image.create(area.size.x,area.size.y,false,Image.FORMAT_RGBA8)
	canvas.fill(Color.BLACK)
	road.fill(Color.BLACK)
	for layer_index in range(map.layers.size()):
		var layer: Array = map.layers[layer_index]
		for b in range(int(map.cols)):
			for a in range(int(map.rows)):
				var value := int(layer[a][b])
				if layer_index == 1 and corrections.has(Vector2i(a,b)): value = corrections[Vector2i(a,b)]
				if value == 65535: continue
				var ground := (value>>8)&15
				if ground == 9 and component.has(Vector2i(a,b)): continue
				var key := "%d/%d/%d" % [ground,(value>>4)&15,value&15]
				if not tiles.has(key): continue
				var image: Image = tiles[key]
				var point := _position(Vector2i(a,b),ground)-area.position
				if not Rect2i(point,image.get_size()).intersects(Rect2i(Vector2i.ZERO,area.size)): continue
				canvas.blend_rect(image,Rect2i(Vector2i.ZERO,image.get_size()),point)
				if ground not in [6,9]: road.blend_rect(image,Rect2i(Vector2i.ZERO,image.get_size()),point)
				if ground == 6: wall_mask.blend_rect(image,Rect2i(Vector2i.ZERO,image.get_size()),point)
	var mask := Image.create(area.size.x,area.size.y,false,Image.FORMAT_RGBA8)
	for cell in component:
		var value: int = component[cell]
		var image: Image = masks["9/%d/%d" % [(value>>4)&15,value&15]]
		mask.blend_rect(image,Rect2i(Vector2i.ZERO,image.get_size()),_position(cell,9)-area.position)
	for cell in corrections:
		for value in [int(map.layers[1][cell.x][cell.y]),int(corrections[cell])]:
			if value == 65535: continue
			var key := "6/%d/%d" % [(value>>4)&15,value&15]
			var image: Image = masks[key]
			mask.blend_rect(image,Rect2i(Vector2i.ZERO,image.get_size()),_position(cell,6)-area.position)
	var covered := 0
	for y in range(area.size.y):
		for x in range(area.size.x):
			var color := canvas.get_pixel(x,y)
			color.a = 1.0 if mask.get_pixel(x,y).a > 0.5 else 0.0
			if color.a > 0: covered += 1
			canvas.set_pixel(x,y,color)
	var path := ART+"gate_terrain/%s-%d-%d.png" % [map_id,gate.x,gate.y]
	assert(canvas.save_png(ProjectSettings.globalize_path(path)) == OK)
	var road_path := ART+"gate_terrain/%s-%d-%d-road.png" % [map_id,gate.x,gate.y]
	assert(road.save_png(ProjectSettings.globalize_path(road_path)) == OK)
	var architecture = preload("res://presentation/battle/gate_module.gd")
	var anchor := Vector2(44*gate.x+22*(gate.y&1)+22,11*gate.y+22)
	var top: Vector2 = anchor-Vector2(44,88)+architecture.base_origin(unit_id)+Vector2(architecture.LEGACY_WIDTH*0.5,architecture.LEGACY_WIDTH*0.5*architecture.slope(unit_id))
	var footing: float = top.y+architecture.HEIGHT+architecture.FOOT_DEPTH
	var wall_floor: float = -INF
	for x in range(maxi(0,roundi((top.x-22)*4)-area.position.x),mini(area.size.x,roundi((top.x+22)*4)-area.position.x)):
		for y in range(area.size.y-1,-1,-1):
			if wall_mask.get_pixel(x,y).a > 0.5:
				var wx := (x+area.position.x)/4.0
				wall_floor = maxf(wall_floor,(y+area.position.y)/4.0-architecture.slope(unit_id)*(wx-top.x))
				break
	var drop := clampf(roundf(wall_floor-footing),-44,44)
	print("GATE FOOTING ",map_id," ",gate," extension=",drop)
	return {"cell":[gate.x,gate.y],"texture":path,"roadTexture":road_path,"position":[area.position.x/4.0,area.position.y/4.0],"scale":4,"platformTiles":component.size(),"connectorTiles":corrections.size(),"coveredPixels":covered,"foundationDrop":drop}

func _straight_connections(map: Dictionary, gate: Vector2i, unit_id: int, component: Dictionary) -> Dictionary:
	var sign_b := 1 if unit_id == 16 else -1
	var constants := []
	var layer: Array = map.layers[1]
	for offset in [-8,-7,-6,6,7,8]:
		var b: int = gate.y+int(offset)
		if b < 0 or b >= int(map.cols): continue
		var expected := gate.x+int(roundf(sign_b*offset*0.5))
		var best := INF
		var intercept := 0
		for a in range(maxi(0,expected-3),mini(int(map.rows)-1,expected+4)):
			if (int(layer[a][b])&4095) != 0x620 or (int(layer[a+1][b])&4095) != 0x620: continue
			if absf(a-expected) >= best: continue
			best = absf(a-expected)
			intercept = 2*a-sign_b*b+(b&1)
		if best != INF: constants.append(intercept)
	if constants.is_empty(): return {}
	constants.sort()
	var intercept: int = constants[constants.size()/2]
	var first := gate.y
	var last := gate.y
	for cell in component:
		first = mini(first,cell.y); last = maxi(last,cell.y)
	var result := {}
	for b in range(first,last+1):
		var a0 := int(floorf((sign_b*b+intercept)/2.0))
		for a in range(maxi(0,a0-1),mini(int(map.rows),a0+3)):
			var value := int(layer[a][b])
			var ground := (value>>8)&15
			if value != 65535 and ground != 6: continue
			var wanted := 0xf620 if a in [a0,a0+1] else 65535
			if value != wanted: result[Vector2i(a,b)] = wanted
	return result

func _prepare_tiles() -> void:
	var catalog := _json("res://art/production/catalog.json")
	var contract := _json(ART+"manifest.json")
	for asset in catalog.assets:
		if str(asset.category) != "terrain": continue
		var ground := int(asset.sourceId)
		var entry: Dictionary = contract.terrain[str(ground)]
		var source := _image(entry.texture)
		var reference := _image(REFERENCES+"terrain-%02d-source.png" % ground)
		var w := int(asset.frameWidth)
		var h := int(asset.frameHeight)
		for frame in range(entry.frames.size()):
			var mapping: Dictionary = entry.frames[frame]
			if bool(mapping.get("skip",false)): continue
			var column: int = frame%int(asset.columns)
			var row: int = frame/int(asset.columns)
			var r: Array = mapping.region
			var original: Array = asset.frameBounds[frame]
			var paint := source.get_region(Rect2i(r[0],r[1],r[2],r[3]))
			paint.resize(int(original[2])*4,int(original[3])*4,Image.INTERPOLATE_LANCZOS)
			var tile := Image.create(w*4,h*4,false,Image.FORMAT_RGBA8)
			tile.blit_rect(paint,Rect2i(Vector2i.ZERO,paint.get_size()),Vector2i(int(original[0])*4,int(original[1])*4))
			var mask := Image.create(w*4,h*4,false,Image.FORMAT_RGBA8)
			for y in range(h*4):
				for x in range(w*4):
					if reference.get_pixel(column*w+x/4,row*h+y/4).a < 0.5:
						var color := tile.get_pixel(x,y); color.a = 0; tile.set_pixel(x,y,color)
					else:
						mask.set_pixel(x,y,Color.WHITE)
						var color := _edge_color(tile,x,y)
						if color.a >= 0.98: color.a = 1; tile.set_pixel(x,y,color)
			var key := "%d/%d/%d" % [ground,column,row]
			tiles[key] = tile
			if ground in [6,9]: masks[key] = mask

func _edge_color(image: Image, x: int, y: int) -> Color:
	var original := image.get_pixel(x,y)
	if original.a >= 0.98: return original
	for radius in range(1,13):
		for offset in [Vector2i(radius,0),Vector2i(-radius,0),Vector2i(0,radius),Vector2i(0,-radius),Vector2i(radius,radius),Vector2i(-radius,radius),Vector2i(radius,-radius),Vector2i(-radius,-radius)]:
			var point: Vector2i = Vector2i(x,y)+offset
			if point.x < 0 or point.y < 0 or point.x >= image.get_width() or point.y >= image.get_height(): continue
			var color := image.get_pixelv(point)
			if color.a >= 0.98: return color
	return original
