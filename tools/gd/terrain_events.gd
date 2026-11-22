extends SceneTree
func _initialize() -> void:
	_run.call_deferred()
func _json(path: String) -> Dictionary:
	return JSON.parse_string(FileAccess.open(path, FileAccess.READ).get_as_text())
func _run() -> void:
	var contract := _json("res://art/full/manifest.json")
	var catalog := _json("res://art/production/catalog.json")
	var index := _json("res://../../_work/full-art-map-source/index.json")
	var tiles := {}
	for asset in catalog.assets:
		if str(asset.category) != "terrain":
			continue
		var image := Image.new()
		assert(image.load(ProjectSettings.globalize_path("res://" + str(asset.target).trim_prefix("godot/chibi_remake/"))) == OK)
		image.convert(Image.FORMAT_RGBA8)
		var mask := Image.new()
		assert(mask.load(ProjectSettings.globalize_path("res://art/production/references/terrain-%02d-source.png" % int(asset.sourceId))) == OK)
		for i in range(int(asset.sourceFrameCount)):
			var mapping: Dictionary = contract.terrain[str(int(asset.sourceId))].frames[i]
			if mapping.get("skip", false):
				continue
			var r: Array = mapping.region
			var b: Array = asset.frameBounds[i]
			var paint := image.get_region(Rect2i(r[0], r[1], r[2], r[3]))
			paint.resize(int(b[2]) * 4, int(b[3]) * 4, Image.INTERPOLATE_LANCZOS)
			var tile := Image.create(int(asset.frameWidth) * 4, int(asset.frameHeight) * 4, false, Image.FORMAT_RGBA8)
			tile.blit_rect(paint, Rect2i(Vector2i.ZERO, paint.get_size()), Vector2i(int(b[0]) * 4, int(b[1]) * 4))
			for y in range(tile.get_height()):
				for x in range(tile.get_width()):
					if mask.get_pixel((i % int(asset.columns)) * int(asset.frameWidth) + x / 4, (i / int(asset.columns)) * int(asset.frameHeight) + y / 4).a < 0.5:
						var c := tile.get_pixel(x, y); c.a = 0; tile.set_pixel(x, y, c)
			tiles["%d/%d/%d" % [int(asset.sourceId), i % int(asset.columns), i / int(asset.columns)]] = tile
	var rules := _json("res://data/db/scenario_rules.json")
	var records := {}
	var dir := "res://art/full/terrain_events/"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir))
	for id in index.maps:
		var level := _json("res://data/%s.json" % id)
		var source := _json("res://../../_work/full-art-map-source/%s.json" % id)
		var stages: Array = rules.missions.get(str(int(level.get("scenario", {}).get("missionId", -1))), {}).get("stages", [])
		# Exported scenario may call this field 'id'; source mission is matched below.
		if stages.is_empty():
			stages = rules.missions.get(str(int(level.get("scenario", {}).get("id", -1))), {}).get("stages", [])
		for stage in stages:
			for effect in stage.get("effects", []):
				if str(effect.kind) != "clear_tiles":
					continue
				var keys := []
				var box := Rect2i()
				for cell in effect.cells:
					var a := int(cell[0]); var b := int(cell[1]); var v := int(source.layers[int(effect.layer)][a][b])
					if v == 65535:
						continue
					var ground := (v >> 8) & 15
					var r := Rect2i(44 * a + 22 * (b & 1), 11 * b - (int(index.grounds[ground].H) - 22), 44, int(index.grounds[ground].H))
					box = r if box.size == Vector2i.ZERO else box.merge(r)
					source.layers[int(effect.layer)][a][b] = 65535
					keys.append("%d/%d/%d" % [int(effect.layer), a, b])
				if keys.is_empty():
					continue
				var canvas := Image.create(box.size.x * 4, box.size.y * 4, false, Image.FORMAT_RGBA8)
				canvas.fill(Color.BLACK)
				for layer in source.layers:
					for a in range(int(source.rows)):
						for b in range(int(source.cols)):
							var v := int(layer[a][b])
							if v == 65535:
								continue
							var ground := (v >> 8) & 15
							var key := "%d/%d/%d" % [ground, (v >> 4) & 15, v & 15]
							if not tiles.has(key):
								continue
							var tile: Image = tiles[key]
							var pos := Vector2i((44 * a + 22 * (b & 1) - box.position.x) * 4, (11 * b - (int(index.grounds[ground].H) - 22) - box.position.y) * 4)
							if Rect2i(pos, tile.get_size()).intersects(Rect2i(Vector2i.ZERO, canvas.get_size())):
								canvas.blend_rect(tile, Rect2i(Vector2i.ZERO, tile.get_size()), pos)
				var texture := dir + str(id) + ".png"
				assert(canvas.save_png(ProjectSettings.globalize_path(texture)) == OK)
				records[str(id)] = {"keys": keys, "texture": texture, "position": [box.position.x, box.position.y], "scale": 4}
	var out := FileAccess.open(dir + "manifest.json", FileAccess.WRITE)
	out.store_string(JSON.stringify(records))
	print("Terrain event patches: ", records.keys())
	quit()
