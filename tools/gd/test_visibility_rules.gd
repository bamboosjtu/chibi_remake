extends SceneTree
const Visibility = preload("res://simulation/systems/battle_visibility.gd")
const Timers = preload("res://simulation/systems/tick_timers.gd")
var done := false

func _initialize() -> void:
	create_timer(60).timeout.connect(func():
		if not done: quit(1))
	run.call_deferred()

func source(uid: int, vision := 4) -> Dictionary:
	return {"uid":uid,"alive":true,"die_t":-1,"owner":1,"unit":30,"is_building":false,"attached":false,"ax":1000.0,"ay":600.0,"vision":vision,"farsight_t":0}

func run() -> void:
	var fog := Visibility.new()
	fog.setup(Vector2(2200,1200))
	var first := source(1)
	var second := source(2)
	fog.update([first,second],1)
	var center := floori(first.ay / fog.CELL.y) * fog.width + floori(first.ax / fog.CELL.x)
	assert(fog.current[center] == 1 and fog.reveals[center] == 2)
	var revision: int = fog.revision
	fog.update([first,second],1)
	assert(fog.revision == revision and fog.reveals[center] == 2)
	first.alive = false; fog.update([first,second],1)
	assert(fog.current[center] == 1 and fog.reveals[center] == 1)
	second.attached = true; fog.update([first,second],1)
	assert(fog.current[center] == 0 and fog.reveals[center] == 0 and fog.explored[center] == 1)
	for step in range(30):
		second.attached = false; second.ax += 11
		fog.update([second],1)
		second.attached = true; fog.update([second],1)
	assert(fog.reveals.count(0) == fog.reveals.size(), "moving/removing reveal sources must not leak counts")
	print("VISIBILITY OVERLAP PASS overlapping sources / remove one / no passenger reveal / incremental movement")
	first = source(1)
	var far_point := Vector2(first.ax + 8 * 44, first.ay)
	fog.setup(Vector2(2200,1200)); fog.update([first],1)
	assert(not fog.is_visible(far_point))
	first.farsight_t = 1; fog.update([first],1)
	assert(fog.is_visible(far_point))
	first.farsight_t = 0; fog.update([first],1)
	assert(not fog.is_visible(far_point))
	var encoded: String = fog.snapshot()
	var restored := Visibility.new(); restored.setup(Vector2(2200,1200))
	assert(restored.valid_snapshot(encoded))
	restored.restore(encoded,[first],1)
	assert(restored.explored == fog.explored and restored.current == fog.current and restored.reveals == fog.reveals)
	first.vision = 14; fog.update([first],1)
	var outer := Vector2(first.ax + 12 * 44, first.ay)
	assert(fog.is_visible(outer))
	first.farsight_t = 800; fog.update([first],1)
	assert(Visibility.effective_vision(first) == 10 and not fog.is_visible(outer), "far sight replaces radius with ten")
	print("VISIBILITY FARSIGHT PASS fixed10 / expiry memory / snapshot cache rebuilt / larger base radius replaced")
	root.get_node("Game").current_map = "chibil1"
	var b: Node2D = load("res://main.tscn").instantiate(); root.add_child(b)
	b.set_process(false); b.cli_mode = true; b.ai = null
	var hero: Dictionary = b.units.filter(func(u):return u.owner == b.player_owner and b.commands._is_hero_unit(u))[0]
	var enemy: Dictionary = b.units.filter(func(u):return u.owner != 0 and u.owner != b.player_owner and not u.is_building)[0]
	for unit in b.units: b.commands._cancel_unit_command(unit)
	for key in Timers.STATUS_KEYS: hero[key] = 1
	hero.attached = true; hero.state = "move"; hero.path = [Vector2(hero.ax+44,hero.ay)]
	var before := Vector2(hero.ax,hero.ay)
	b.commands._step_unit(hero,b.SIM_DT)
	assert(Timers.STATUS_KEYS.all(func(key):return hero[key] == 0))
	assert(hero.state == "move" and hero.path.size() == 1 and Vector2(hero.ax,hero.ay) == before)
	hero.attached = false; b.commands._cancel_unit_command(hero); hero.hold=true; enemy.hold=true
	enemy.ax = hero.ax + 44; enemy.ay = hero.ay
	var hp: float = hero.hp; var enemy_hp: float = enemy.hp
	for step in range(120):
		b.commands._step_unit(hero,b.SIM_DT); b.commands._step_unit(enemy,b.SIM_DT)
	assert(hero.state == "idle" and enemy.state == "idle" and hero.hp == hp and enemy.hp == enemy_hp)
	hero.state = "attack"; hero.target = enemy; hero.cool = 0
	for step in range(300):
		b.commands._step_unit(hero,b.SIM_DT)
		if enemy.hp < enemy_hp: break
	assert(enemy.hp < enemy_hp and enemy.state == "idle", "explicit attack works without implicit retaliation")
	# 避免其他原有关卡单位影响最近目标，使用隔离世界验证双向箭楼与AI互不射击。
	b.units = [hero,enemy]
	assert(b.commands._spawn_unit(18,b.player_owner,hero.ax,hero.ay,true))
	var tower: Dictionary = b.units.back()
	b.visibility.update(b.units,b.player_owner)
	b.commands._step_unit(tower,b.SIM_DT)
	assert(tower.state == "attack" and is_same(tower.target,enemy))
	enemy.ax = tower.ax + float(tower.atk_range) * b.tile_w + 100
	var tower_pos := Vector2(tower.ax,tower.ay)
	b.commands._step_unit(tower,b.SIM_DT)
	assert(tower.state == "idle" and Vector2(tower.ax,tower.ay) == tower_pos)
	tower.owner = enemy.owner; enemy.ax = tower.ax+44; enemy.owner = 4
	hero.attached = true; b.commands._step_unit(tower,b.SIM_DT)
	assert(tower.state == "idle", "AI towers must not fire on other AI factions")
	hero.attached = false; hero.ax = tower.ax+44; b.commands._step_unit(tower,b.SIM_DT)
	assert(tower.state == "attack" and is_same(tower.target,hero))
	print("VISIBILITY EXECUTION PASS passenger timers / hold preserves idle / explicit attack / towers both sides / no AI-versus-AI / stationary")
	done = true; b.queue_free(); await process_frame; quit(0)
