extends SceneTree
## 接入回归：检查全部高清帧及移除表现层前后的模拟状态一致性。

func _initialize() -> void:
	_run.call_deferred()

func _state(battle: Node2D) -> String:
	var records := []
	for u in battle.units:
		records.append([u.uid, u.unit, u.owner, u.ax, u.ay, u.hp, u.attack, u.defence, u.alive, u.state, u.get("officer", {}).get("index", -1)])
	return JSON.stringify([records, battle.gold, battle.wood, battle.food, battle.stone, battle.player_owner]).sha256_text()

func _run() -> void:
	var catalog = load("res://presentation/battle/art_catalog.gd").new()
	assert(catalog.menu_background() != null)
	var full = catalog._full_art
	assert(full._data.atlases.size() == 53, "27 类建筑与 26 类兵种全部接入")
	assert(full._data.officers.size() == 117)
	assert(full._data.terrain.size() == 14)
	for index in range(117):
		assert(catalog.officer_texture(index) != null, "portrait %d" % index)
	var source_frames := 0
	for id in full._data.atlases:
		var entry: Dictionary = full._data.atlases[id]
		for owner in range(5):
			var parent := Sprite2D.new()
			var skin: Sprite2D = catalog.create_unit_skin(parent, int(id), owner, Vector2i(int(entry.worldWidth) * 4, int(entry.worldHeight) * 4))
			assert(skin != null)
			for frame in range(int(entry.count)):
				var mapping: Dictionary = entry.frames[frame]
				var use_hd: bool = catalog.update_skin(skin, frame, int(id) <= 26, -1.0)
				assert(use_hd == not bool(mapping.get("original", false)))
				if use_hd and not bool(mapping.get("skip", false)):
					assert(skin.visible and skin.texture != null)
					assert(skin.region_rect.end.x <= skin.texture.get_width())
					assert(skin.region_rect.end.y <= skin.texture.get_height())
				elif bool(mapping.get("original", false)):
					assert(not skin.visible)
			parent.free()
		source_frames += int(entry.count)
	var reports := []
	for id in ["chibic1", "chibil1", "chibil8"]:
		root.get_node("Game").current_map = id
		var hashes := []
		var skins := 0
		seed(0)
		var battle: Node2D = load("res://main.tscn").instantiate()
		root.add_child(battle)
		battle.set_process(false)
		battle.cli_mode = true
		assert(battle.view != null)
		var before := _state(battle)
		for u in battle.units:
			if battle.view.unit_nodes(u).get("skin", null) != null:
				skins += 1
				battle.commands._set_frame(u, 0)
			assert(Vector2(u.ax, u.ay) == Vector2(battle.view.unit_nodes(u).spr.position.x + float(u.w) * 0.5, battle.view.unit_nodes(u).spr.position.y + float(u.h)))
		assert(_state(battle) == before)
		hashes.append(before)
		# Detaching all rendered nodes must preserve the same simulation state.
		battle.view.free()
		battle.view = null
		hashes.append(_state(battle))
		battle.free()
		assert(hashes[0] == hashes[1], "art changed simulation: " + id)
		assert(skins > 0)
		assert(not catalog.terrain_info(id).is_empty(), "HD map missing: " + id)
		reports.append({"map": id, "stateSha256": hashes[0], "skins": skins})
	var report_path := "res://art/production/runtime-report.json"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--art-report="):
			report_path = arg.substr(13)
	var file := FileAccess.open(report_path, FileAccess.WRITE)
	assert(file != null, report_path)
	file.store_string(JSON.stringify({"pass": true, "atlases": full._data.atlases.size(), "portraits": 117, "terrainGroups": 14, "sourceFramesCheckedAcrossFiveOwners": source_frames, "maps": reports}, "  "))
	print("FULL ART RUNTIME PASS ", reports)
	quit()
