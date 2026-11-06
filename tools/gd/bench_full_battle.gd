extends SceneTree
## Full-battle benchmark: real scenario, AI, combat, projectiles, economy,
## rendering and terrain streaming. Run through tools/bench_full_battle.ps1 so
## the host can also record the process peak working set.

const Config = preload("res://simulation/battle_config.gd")
const COMBAT_TYPES := [29, 31, 33, 35]
var done := false
var map_id := "chibic17"
var target_units := 800
var ticks := 600
var frames := 300
var engage := 240
var use_ai := true
var use_view := true
var output_path := "user://full-battle-bench.json"

func _initialize() -> void:
	create_timer(600).timeout.connect(func():
		if not done: quit(2))
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--bench-map="): map_id = arg.substr(12)
		elif arg.begins_with("--bench-units="): target_units = maxi(50, int(arg.substr(14)))
		elif arg.begins_with("--bench-ticks="): ticks = maxi(60, int(arg.substr(14)))
		elif arg.begins_with("--bench-frames="): frames = maxi(30, int(arg.substr(15)))
		elif arg.begins_with("--bench-engage="): engage = maxi(0, int(arg.substr(15)))
		elif arg == "--bench-no-ai": use_ai = false
		elif arg == "--bench-no-view": use_view = false
		elif arg.begins_with("--bench-output="): output_path = arg.substr(15)
	run.call_deferred()

func _mobile_count(battle: Node2D) -> int:
	var count := 0
	for unit in battle.units:
		if bool(unit.get("alive", false)) and not bool(unit.get("is_building", false)) and int(unit.get("unit", 0)) >= 27:
			count += 1
	return count

func _fill(battle: Node2D) -> int:
	var owners: Array = [int(battle.player_owner)]
	for owner in battle._modules["ai_economy"].ai_owners():
		if int(owner) != int(battle.player_owner) and not owners.has(int(owner)): owners.append(int(owner))
	for unit in battle.units:
		var owner := int(unit.get("owner", 0))
		if owner > 0 and not owners.has(owner): owners.append(owner)
	for owner in [1, 2, 3, 4]:
		if not owners.has(owner): owners.append(owner)
	var terrain_w := float(battle.map_data.get("terrainW", 4000))
	var terrain_h := float(battle.map_data.get("terrainH", 3000))
	var rng := RandomNumberGenerator.new()
	rng.seed = 20261031
	var spawned := 0
	var attempts := 0
	while _mobile_count(battle) < target_units and attempts < target_units * 200:
		attempts += 1
		var owner: int = int(owners[attempts % owners.size()])
		var unit_id: int = int(COMBAT_TYPES[attempts % COMBAT_TYPES.size()])
		var ax := rng.randf_range(120.0, terrain_w - 120.0)
		var ay := rng.randf_range(120.0, terrain_h - 120.0)
		if battle.commands.world._spawn_unit(unit_id, owner, ax, ay, false):
			spawned += 1
	# Give a bounded share of the troops an enemy so pathfinding, attacks and
	# projectiles run, while the rest stay as AI reserve.
	var engaging := 0
	for unit in battle.units:
		if engaging >= engage: break
		if not bool(unit.get("alive", false)) or bool(unit.get("is_building", false)): continue
		if int(unit.get("unit", 0)) in COMBAT_TYPES and str(unit.get("state", "")) in ["idle", ""]:
			var enemy: Dictionary = battle.commands.military._nearest_enemy(unit, 100000.0)
			if not enemy.is_empty():
				unit.target = enemy
				unit.state = "attack"
				engaging += 1
	return spawned

func _percentile(sorted_values: Array, percentile: float) -> float:
	if sorted_values.is_empty(): return 0.0
	var index := clampi(int(roundf(percentile * float(sorted_values.size() - 1))), 0, sorted_values.size() - 1)
	return float(sorted_values[index])

func run() -> void:
	if DisplayServer.get_name() != "headless":
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	root.size = Vector2i(1920, 1080)
	root.get_node("Game").current_map = map_id
	var battle: Node2D = load("res://main.tscn").instantiate()
	root.add_child(battle)
	battle.cli_mode = true
	await process_frame
	await process_frame
	for i in range(30): await process_frame
	battle.set_process(false)
	if not use_ai:
		battle.ai = null
	if not use_view:
		battle.view.queue_free()
		battle.view = null
	var spawned := _fill(battle)
	var measured_units := _mobile_count(battle)
	for i in range(60): battle.commands.world._sim_step(Config.SIM_DT)
	var times: Array = []
	for i in range(ticks):
		if i % 10 == 0: await process_frame
		var begin := Time.get_ticks_usec()
		battle.commands.world._sim_step(Config.SIM_DT)
		times.append(float(Time.get_ticks_usec() - begin) / 1000.0)
	var sorted := times.duplicate()
	sorted.sort()
	var total := 0.0
	for value in times: total += value
	var average := total / float(times.size())
	var report := {
		"map": map_id,
		"cpu": OS.get_processor_name(),
		"gpu": RenderingServer.get_video_adapter_name(),
		"unitsTarget": target_units,
		"unitsMeasured": measured_units,
		"spawned": spawned,
		"engaged": engage,
		"ticks": ticks,
		"logicAverageMs": average,
		"logicP50Ms": _percentile(sorted, 0.50),
		"logicP95Ms": _percentile(sorted, 0.95),
		"logicP99Ms": _percentile(sorted, 0.99),
		"logicMaxMs": float(sorted[sorted.size() - 1]),
		"logicBudgetMs": 1000.0 / 30.0,
	}
	# Rendering phase: let the real frame loop drive the same battle.
	battle.set_process(true)
	for i in range(30): await process_frame
	var frame_begin := Time.get_ticks_usec()
	for i in range(frames): await process_frame
	var seconds := float(Time.get_ticks_usec() - frame_begin) / 1000000.0
	report["frames"] = frames
	report["fps"] = float(frames) / maxf(seconds, 0.001)
	report["memoryStaticBytes"] = Performance.get_monitor(Performance.MEMORY_STATIC)
	report["memoryStaticMaxBytes"] = Performance.get_monitor(Performance.MEMORY_STATIC_MAX)
	report["videoMemoryBytes"] = Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED)
	report["renderObjects"] = Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME)
	var file := FileAccess.open(output_path, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(report, "  "))
		file.close()
	print("FULL BATTLE BENCH ", JSON.stringify(report))
	done = true
	quit()
