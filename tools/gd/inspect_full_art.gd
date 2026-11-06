extends SceneTree
## 非破坏性结构验收：读取 PNG alpha，记录每格内容框；不重采样或改写生成图。
const CATALOG := "res://art/production/catalog.json"
const DELIVERY_DIR := "res://art/production/deliveries"
const OUTPUT := "res://art/full/manifest.json"

func _initialize() -> void:
	_run.call_deferred()

func _read_json(path: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var data = JSON.parse_string(file.get_as_text())
	file.close()
	return data if data is Dictionary else {}

func _bounds(data: PackedByteArray, width: int, area: Rect2i) -> Rect2i:
	var left := area.end.x
	var top := area.end.y
	var right := area.position.x - 1
	var bottom := area.position.y - 1
	for y in range(area.position.y, area.end.y):
		for x in range(area.position.x, area.end.x):
			if data[(y * width + x) * 4 + 3] >= 128:
				left = mini(left, x)
				top = mini(top, y)
				right = maxi(right, x)
				bottom = maxi(bottom, y)
	return Rect2i(left, top, maxi(0, right - left + 1), maxi(0, bottom - top + 1))

func _run() -> void:
	var catalog := _read_json(CATALOG)
	assert(not catalog.is_empty())
	var selected := PackedStringArray()
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--assets="): selected = arg.substr(9).split(",", false)
	var manifest := {"schemaVersion": 1, "atlases": {}, "officers": {}, "terrain": {}, "backgrounds": {}}
	if not selected.is_empty(): manifest = _read_json(OUTPUT).duplicate(true)
	manifest["teamMasks"] = _read_json(OUTPUT).get("teamMasks", {})
	manifest["runtimeAssets"] = _read_json(OUTPUT).get("runtimeAssets", {})
	var validated := 0
	var failures := []
	var pages_by_parent := {}
	var primary_by_id := {}
	for asset in catalog.assets:
		primary_by_id[str(asset.assetId)] = asset
	for asset in catalog.assets + catalog.get("pages", []):
		if not selected.is_empty() and str(asset.assetId) not in selected and str(asset.get("parentAssetId", "")) not in selected: continue
		if str(asset.category) == "units" and not asset.get("pages", []).is_empty():
			continue
		var delivery_path := DELIVERY_DIR + "/" + str(asset.assetId) + ".json"
		var delivery := _read_json(delivery_path)
		if delivery.is_empty() or str(delivery.get("texture", "")) != str(asset.target):
			continue
		var resource_path := "res://" + str(asset.target).trim_prefix("godot/chibi_remake/")
		var image := Image.new()
		if image.load(ProjectSettings.globalize_path(resource_path)) != OK:
			failures.append(str(asset.assetId) + ": unreadable PNG")
			continue
		var category := str(asset.category)
		var visual_status := str(delivery.get("validation", {}).get("visual", "pending"))
		if str(delivery.get("userAcceptance", {}).get("reviewer", "")) == "user":
			visual_status = "pass"
		if category == "officers" or category == "backgrounds":
			manifest[category][str(int(asset.sourceId)) if category == "officers" else str(asset.assetId)] = {"texture": resource_path, "name": str(asset.name)}
			validated += 1
			delivery["validation"] = {"structure": "pass", "visual": visual_status}
		else:
			if image.detect_alpha() == Image.ALPHA_NONE:
				failures.append(str(asset.assetId) + ": no alpha")
				continue
			image.convert(Image.FORMAT_RGBA8)
			var bytes := image.get_data()
			var cols := int(asset.columns)
			var rows := int(asset.rows)
			var render_cols := int(asset.get("renderColumns", cols))
			var render_rows := int(asset.get("renderRows", rows))
			var frame_map: Array = asset.get("renderFrameMap", [])
			var count := int(asset.get("sourceFrameCount", cols * rows))
			var skipped := {}
			var original_frames := {}
			for original_frame in asset.get("originalFrames", []):
				original_frames[int(original_frame)] = true
			var atlas_rect := Rect2(0, 0, image.get_width(), image.get_height())
			if category == "terrain":
				# 生成器可能把超宽图集放进有留白的画布。先对齐原版非空总范围。
				var old_union := Rect2()
				var first := true
				var source_bounds: Array = asset.get("frameBounds", [])
				for i in range(source_bounds.size()):
					if not source_bounds[i] is Array:
						continue
					var b: Array = source_bounds[i]
					var box := Rect2(float(b[0]) + (i % cols) * int(asset.frameWidth), float(b[1]) + (i / cols) * int(asset.frameHeight), float(b[2]), float(b[3]))
					old_union = box if first else old_union.merge(box)
					first = false
				var new_union := _atlas_bounds(bytes, image.get_width(), image.get_height())
				if not first and old_union.size.x > 0 and old_union.size.y > 0:
					var ratio := Vector2(new_union.size) / old_union.size
					atlas_rect = Rect2(Vector2(new_union.position) - old_union.position * ratio, Vector2(cols * int(asset.frameWidth), rows * int(asset.frameHeight)) * ratio)
			for item in asset.get("nonvisualFrames", []):
				skipped[int(item.frame)] = true
			var frames := []
			var missing := []
			for frame in range(count):
				var overrides: Dictionary = asset.get("frameOverrides", {})
				if overrides.has(str(frame)):
					frames.append(overrides[str(frame)].duplicate(true))
					continue
				if original_frames.has(frame):
					frames.append({"original": true})
					continue
				if skipped.has(frame):
					frames.append({"skip": true})
					continue
				var packed_frame := int(frame_map[frame]) if frame < frame_map.size() else frame
				assert(packed_frame >= 0 and packed_frame < render_cols * render_rows, "Invalid visual frame layout")
				var cx := packed_frame % render_cols
				var cy := packed_frame / render_cols
				var x0 := clampi(int(round(atlas_rect.position.x + float(cx) * atlas_rect.size.x / render_cols)), 0, image.get_width())
				var y0 := clampi(int(round(atlas_rect.position.y + float(cy) * atlas_rect.size.y / render_rows)), 0, image.get_height())
				var x1 := clampi(int(round(atlas_rect.position.x + float(cx + 1) * atlas_rect.size.x / render_cols)), 0, image.get_width())
				var y1 := clampi(int(round(atlas_rect.position.y + float(cy + 1) * atlas_rect.size.y / render_rows)), 0, image.get_height())
				var area := Rect2i(x0, y0, x1 - x0, y1 - y0)
				var box := _bounds(bytes, image.get_width(), area)
				if box.size.x <= 0 or box.size.y <= 0:
					missing.append(frame)
					frames.append({"skip": true})
					continue
				var old_bounds = asset.get("frameBounds", [])
				var original_box := Rect2(0, 0, float(asset.frameWidth), float(asset.frameHeight))
				if frame < old_bounds.size() and old_bounds[frame] is Array:
					var old: Array = old_bounds[frame]
					original_box = Rect2(float(old[0]), float(old[1]), float(old[2]), float(old[3]))
				var fit := minf(original_box.size.x / box.size.x, original_box.size.y / box.size.y)
				var draw_size := Vector2(box.size) * fit
				var draw_position := original_box.position + Vector2((original_box.size.x - draw_size.x) * 0.5, original_box.size.y - draw_size.y)
				frames.append({"region": [box.position.x, box.position.y, box.size.x, box.size.y], "draw": [draw_position.x, draw_position.y, draw_size.x, draw_size.y]})
			if not missing.is_empty():
				failures.append(str(asset.assetId) + ": missing source visual cells " + str(missing))
				delivery["validation"] = {"structure": "fail", "missingFrames": missing, "visual": "pending"}
			else:
				var key := str(int(asset.sourceId))
				var entry := {"texture": resource_path, "columns": cols, "rows": rows, "count": count, "frames": frames, "worldWidth": int(asset.frameWidth), "worldHeight": int(asset.frameHeight), "name": str(asset.name), "teamTintable": bool(asset.get("teamTintable", true))}
				if category == "unit-pages":
					var parent_id := str(asset.parentAssetId)
					if not pages_by_parent.has(parent_id):
						pages_by_parent[parent_id] = []
					pages_by_parent[parent_id].append({"start": int(asset.startFrame), "entry": entry, "assetId": str(asset.assetId)})
				else:
					manifest["terrain" if category == "terrain" else "atlases"][key] = entry
				validated += 1
				delivery["validation"] = {"structure": "pass", "visual": visual_status, "visualFrameCount": count - skipped.size(), "excludedSourceLabelsOrBlanks": skipped.size()}
		var output := FileAccess.open(delivery_path, FileAccess.WRITE)
		output.store_string(JSON.stringify(delivery, "  "))
		output.close()
	# 只有全部页齐备才替换一个兵种，避免新旧帧混杂或缺失动作。
	for parent_id in pages_by_parent:
		var parent: Dictionary = primary_by_id[parent_id]
		var pages: Array = pages_by_parent[parent_id]
		if pages.size() != parent.get("pages", []).size():
			continue
		var all_frames := []
		all_frames.resize(int(parent.sourceFrameCount))
		for page in pages:
			var entry: Dictionary = page.entry
			for frame in range(entry.frames.size()):
				var mapping: Dictionary = entry.frames[frame].duplicate()
				if not mapping.has("texture"):
					mapping["texture"] = str(entry.texture)
				all_frames[int(page.start) + frame] = mapping
		if all_frames.has(null):
			failures.append(str(parent_id) + ": incomplete page frame mapping")
			continue
		manifest.atlases[str(int(parent.sourceId))] = {"texture": str(pages[0].entry.texture), "count": int(parent.sourceFrameCount), "frames": all_frames, "worldWidth": int(parent.frameWidth), "worldHeight": int(parent.frameHeight), "name": str(parent.name), "pageCount": pages.size(), "teamTintable": bool(parent.get("teamTintable", true))}
	for asset in catalog.assets:
		if str(asset.category) == "units" and asset.get("aliasSourceId") != null:
			var source_key := str(int(asset.aliasSourceId))
			if manifest.atlases.has(source_key):
				var alias: Dictionary = manifest.atlases[source_key].duplicate(true)
				alias["name"] = str(asset.name)
				alias["aliasSourceId"] = int(asset.aliasSourceId)
				manifest.atlases[str(int(asset.sourceId))] = alias
	var file := FileAccess.open(OUTPUT, FileAccess.WRITE)
	file.store_string(JSON.stringify(manifest, "  "))
	file.close()
	var report := FileAccess.open("res://art/production/structure-report.json", FileAccess.WRITE)
	report.store_string(JSON.stringify({"validated": validated, "failures": failures}, "  "))
	report.close()
	print("FULL ART STRUCTURE: validated=", validated, " failures=", failures)
	quit(0 if failures.is_empty() else 1)

func _atlas_bounds(data: PackedByteArray, width: int, height: int) -> Rect2i:
	# 少量散落的半透明边缘像素不能决定图集整体的格位。
	var row_counts := PackedInt32Array()
	var col_counts := PackedInt32Array()
	row_counts.resize(height)
	col_counts.resize(width)
	for y in range(height):
		for x in range(width):
			if data[(y * width + x) * 4 + 3] >= 128:
				row_counts[y] += 1
				col_counts[x] += 1
	var top := height
	var bottom := -1
	var left := width
	var right := -1
	for y in range(height):
		if row_counts[y] >= maxi(3, int(width * 0.004)):
			top = mini(top, y)
			bottom = maxi(bottom, y)
	for x in range(width):
		if col_counts[x] >= maxi(3, int(height * 0.004)):
			left = mini(left, x)
			right = maxi(right, x)
	return Rect2i(left, top, maxi(0, right - left + 1), maxi(0, bottom - top + 1))
