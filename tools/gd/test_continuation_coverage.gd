extends SceneTree
var done := false
const POINTS := [0,31,120,450,900,1800]
func _initialize() -> void:
	create_timer(600).timeout.connect(func():
		if not done: quit(1))
	run.call_deferred()
func digest(battle,game: Node) -> String:
	return game.save_checksum(battle.saver.continuation_snapshot(game))
func run() -> void:
	root.size = Vector2i(1920,1080)
	var game: Node = root.get_node("Game")
	var maps := ["chibic1"]
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--coverage-map="): maps = [arg.substr(15)]
	for map_id in maps:
		game.current_map = map_id
		var battle = load("res://main.tscn").instantiate()
		root.add_child(battle); battle.set_process(false)
		for point in POINTS:
			while battle.sim_tick < point and battle.game_end == 0: battle.commands.world._sim_step(battle.SIM_DT)
			var state: Dictionary = game.snapshot(battle.units,battle.commands.world._resources(),battle.commands.session._save_extra())
			var before_payload: Dictionary = battle.saver.continuation_snapshot(game)
			var before: String = game.save_checksum(before_payload)
			for tick in range(7): battle.commands.world._sim_step(battle.SIM_DT)
			var continued := digest(battle,game)
			assert(battle.saver.apply_snapshot(state),map_id+" restore at "+str(point))
			if digest(battle,game) != before:
				var trace := FileAccess.open(OS.get_environment("LOCALAPPDATA").path_join("continuation-mismatch.json"),FileAccess.WRITE)
				trace.store_string(JSON.stringify({"before":before_payload,"after":battle.saver.continuation_snapshot(game)})); trace.close()
				assert(false,map_id+" complete restore at "+str(point))
			for tick in range(7): battle.commands.world._sim_step(battle.SIM_DT)
			assert(digest(battle,game) == continued,map_id+" AI continuation at "+str(point))
			print("CONTINUATION CHECKPOINT ",map_id," ",point," tick=",battle.sim_tick)
		var base := digest(battle,game)
		var unit: Dictionary = battle.units[0]
		for field in ["stock","rest_t","gather_ticks","delivery_ticks","unload_t","site_inside_uid","tech_hp_bonus","aboard_uid","blocked_n"]:
			var present := unit.has(field)
			var old = unit.get(field)
			unit[field] = int(old if old != null else 0) + 1
			assert(digest(battle,game) != base,"Digest omitted "+field)
			if present: unit[field] = old
			else: unit.erase(field)
		var original_x: float = unit.ax
		unit.ax += 0.125
		assert(digest(battle,game) != base,"Digest omitted subpixel position")
		unit.ax = original_x
		var groups: Dictionary = battle.control_groups.duplicate(true)
		battle.control_groups[9] = [int(unit.uid)]
		assert(digest(battle,game) != base,"Digest omitted control groups")
		battle.control_groups = groups
		battle.visibility.explored[0] ^= 1
		assert(digest(battle,game) != base,"Digest omitted exploration")
		battle.visibility.explored[0] ^= 1
		assert(digest(battle,game) == base)
		print("CONTINUATION COVERAGE MAP PASS ",map_id," six checkpoints through 60s / complete fields and caches")
		battle.free()
	print("CONTINUATION COVERAGE PASS six AI restore-and-resume checkpoints / omitted-field mutation checks")
	done = true; quit()
