extends SceneTree
## 重绘图块的离线装配。原 MED 层、坐标、透明覆盖保持不变。
var SOURCE := ""
var REFERENCES := ""
var OUTPUT := ""

func _initialize() -> void:
	_run.call_deferred()

func _json(path: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	assert(file != null, path)
	return JSON.parse_string(file.get_as_text())

func _png(path: String) -> Image:
	var value := Image.new()
	assert(value.load(ProjectSettings.globalize_path(path)) == OK, path)
	value.convert(Image.FORMAT_RGBA8)
	return value

func _run() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--source-root="): SOURCE = argument.substr(14).trim_suffix("/") + "/"
		if argument.begins_with("--output="): OUTPUT = argument.substr(9).trim_suffix("/") + "/"
	if SOURCE.is_empty() or OUTPUT.is_empty():
		printerr("Required --source-root and --output"); quit(1); return
	REFERENCES = SOURCE + "masks/"
	var index := _json(SOURCE + "index.json")
	var catalog := _json(SOURCE + "catalog.json")
	var contract := _json(SOURCE + "mapping.json")
	var scale := int(index.scale)
	var tiles := {}
	var coverage := {}
	for asset in catalog.assets:
		if str(asset.category) != "terrain":
			continue
		if not contract.terrain.has(str(int(asset.sourceId))):
			printerr("Terrain bake pending: ", asset.assetId)
			quit(2)
			return
		var image := _png(SOURCE + str(asset.paint))
		var mask := _png(REFERENCES + "terrain-%02d-source.png" % int(asset.sourceId))
		var columns := int(asset.columns)
		var rows := int(asset.rows)
		var width := int(asset.frameWidth)
		var height := int(asset.frameHeight)
		var covered := 0
		var holes := 0
		for row in range(rows):
			for column in range(columns):
				var frame := row * columns + column
				var mapping: Dictionary = contract.terrain[str(int(asset.sourceId))].frames[frame]
				if bool(mapping.get("skip", false)):
					continue
				var region: Array = mapping.region
				var original: Array = asset.frameBounds[frame]
				var paint := image.get_region(Rect2i(int(region[0]), int(region[1]), int(region[2]), int(region[3])))
				paint.resize(int(original[2]) * scale, int(original[3]) * scale, Image.INTERPOLATE_LANCZOS)
				var tile := Image.create(width * scale, height * scale, false, Image.FORMAT_RGBA8)
				tile.blit_rect(paint, Rect2i(Vector2i.ZERO, paint.get_size()), Vector2i(int(original[0]) * scale, int(original[1]) * scale))
				# 将原图透明覆盖作为地图几何掩码，避免生成的边缘改变道路/水岸。
				for y in range(height * scale):
					for x in range(width * scale):
						if mask.get_pixel(column * width + x / scale, row * height + y / scale).a < 0.5:
							var color := tile.get_pixel(x, y)
							color.a = 0.0
							tile.set_pixel(x, y, color)
						else:
							# 常规图集边缘扩展：让透明边缘的颜色延伸到原几何掩码边界。
							covered += 1
							var color := _edge_color(tile, x, y)
							if color.a < 0.98:
								holes += 1
							else:
								color.a = 1.0
								tile.set_pixel(x, y, color)
				tiles["%d/%d/%d" % [int(asset.sourceId), column, row]] = tile
		coverage[str(int(asset.sourceId))] = {"sourcePixels": covered, "unfilledPixels": holes, "fractionFilled": 1.0 - float(holes) / maxi(1, covered)}
		if int(asset.sourceId) < 6 and float(holes) / maxi(1, covered) > 0.001:
			printerr("Terrain coverage failed: ", asset.assetId, " ", coverage[str(int(asset.sourceId))])
			quit(1)
			return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT))
	var result := {"schemaVersion": 1, "maps": {}, "source": "unchanged MED layer contracts; individually redrawn LIB tiles"}
	if FileAccess.file_exists(OUTPUT + "manifest.json"):
		result = _json(OUTPUT + "manifest.json")
	var only_map := ""
	var selected: PackedStringArray = []
	var part := -1
	var parts := 1
	var skip_existing := false
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--map-list="): selected = arg.substr(11).split(",")
		if arg.begins_with("--bake-map="):
			only_map = arg.substr(11)
		elif arg.begins_with("--bake-part="):
			var split := arg.substr(12).split("/")
			part = int(split[0])
			parts = int(split[1])
		elif arg == "--skip-existing":
			skip_existing = true
	var ordinal := -1
	for id in index.maps:
		if not selected.is_empty() and not str(id) in selected: continue
		ordinal += 1
		if part >= 0 and ordinal % parts != part:
			continue
		if skip_existing and str(result.maps.get(str(id), {}).get("quality", "")) == "pass":
			continue
		if not only_map.is_empty() and str(id) != only_map:
			continue
		var map := _json(SOURCE + str(id) + ".json")
		var width := int(map.width) * scale
		var height := int(map.height) * scale
		var paths := []
		for quadrant in range(4):
			var x0 := (quadrant % 2) * (width / 2)
			var y0 := (quadrant / 2) * (height / 2)
			var canvas := Image.create(width / 2, height / 2, false, Image.FORMAT_RGBA8)
			canvas.fill(Color.BLACK)
			for layer in map.layers:
				for column in range(int(map.cols)):
					for row in range(int(map.rows)):
						var value := int(layer[row][column])
						if value == 65535:
							continue
						var ground := (value >> 8) & 15
						var key := "%d/%d/%d" % [ground, (value >> 4) & 15, value & 15]
						if not tiles.has(key):
							continue
						var tile: Image = tiles[key]
						var x := (44 * row + 22 * (column & 1)) * scale - x0
						var y := (11 * column - (int(index.grounds[ground].H) - 22)) * scale - y0
						if x >= canvas.get_width() or y >= canvas.get_height() or x + tile.get_width() <= 0 or y + tile.get_height() <= 0:
							continue
						canvas.blend_rect(tile, Rect2i(Vector2i.ZERO, tile.get_size()), Vector2i(x, y))
			var path := OUTPUT + str(id) + "_q%d.png" % quadrant
			assert(canvas.save_png(ProjectSettings.globalize_path(path)) == OK)
			paths.append(path)
		result.maps[str(id)] = {"terrainHD": paths, "terrainScale": scale, "worldWidth": int(map.width), "worldHeight": int(map.height), "sourceSha256": str(map.sourceSha256), "quality": "pass", "visualAcceptance": catalog.get("visualReviewPolicy", {}), "tileCoverage": coverage}
		var record := FileAccess.open(OUTPUT + str(id) + ".json", FileAccess.WRITE)
		record.store_string(JSON.stringify(result.maps[str(id)], "  "))
		record.close()
		var checkpoint := FileAccess.open(OUTPUT + ("manifest.json" if part < 0 else "manifest-part-%d.json" % part), FileAccess.WRITE)
		checkpoint.store_string(JSON.stringify(result, "  "))
		checkpoint.close()
		print("Redrawn tiles assembled: ", id)
	var file := FileAccess.open(OUTPUT + ("manifest.json" if part < 0 else "manifest-part-%d.json" % part), FileAccess.WRITE)
	file.store_string(JSON.stringify(result, "  "))
	quit()

func _edge_color(image: Image, x: int, y: int) -> Color:
	var original := image.get_pixel(x, y)
	if original.a >= 0.98:
		return original
	for radius in range(1, 13):
		for offset in [Vector2i(radius, 0), Vector2i(-radius, 0), Vector2i(0, radius), Vector2i(0, -radius), Vector2i(radius, radius), Vector2i(-radius, radius), Vector2i(radius, -radius), Vector2i(-radius, -radius)]:
			var px: int = x + offset.x
			var py: int = y + offset.y
			if px < 0 or py < 0 or px >= image.get_width() or py >= image.get_height():
				continue
			var color := image.get_pixel(px, py)
			if color.a >= 0.98:
				return color
	return original
