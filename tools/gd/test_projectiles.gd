extends SceneTree
var done := false
var b: Node2D
var game: Node
var enemy_owner: int

func _initialize() -> void:
	create_timer(60).timeout.connect(func():
		if not done: quit(1))
	run.call_deferred()

func spawn(kind: int, owner: int, point: Vector2) -> Dictionary:
	assert(b.commands.world._spawn_unit(kind,owner,point.x,point.y,true))
	return b.units.back()

func save() -> Dictionary:
	assert(game.save_game(b.units,b.commands.world._resources(),b.commands.session._save_extra()))
	return game.load_save()

func find(uid: int) -> Dictionary:
	return b.units.filter(func(u):return int(u.uid)==uid)[0]

func run() -> void:
	game=root.get_node("Game");game.current_map="chibil1"
	b=load("res://main.tscn").instantiate();root.add_child(b)
	b.set_process(false);b.cli_mode=true;b.ai=null
	enemy_owner=int(b.commands.economy.ai_owners()[0])
	# 隔离实际实体，防止原地图建筑占地掩盖固定格命中测试。
	while not b.units.is_empty():b.commands.world._free_unit_at(b.units.size()-1)
	var archer:=spawn(45,b.player_owner,Vector2(1000,1500))
	var target:=spawn(32,enemy_owner,Vector2(1160,1500))
	var archer_uid: int=archer.uid;var target_uid: int=target.uid
	target.hp=1000;target.maxhp=1000;target.base_maxhp=1000
	var damage: float=b.commands.military._damage(archer,target)
	b.commands.military._fire_attack(archer,target)
	assert(target.hp==1000 and b.projectiles.active.size()==1)
	for tick in range(9):b.projectiles.step()
	assert(b.projectiles.active[0].travel==144 and target.hp==1000)
	target.ax+=300;target.defence_b+=1000 # 飞行不追点，但命中仍锁定实体和发射时伤害。
	b.projectiles.step()
	assert(target.hp==1000-damage and b.projectiles.active.is_empty() and target.last_attacker_uid==archer.uid)
	print("PROJECTILE ARROW PASS speed16 / no launch damage / fixed flight / moving target locked / launch damage frozen")
	target.ax=1160;target.defence_b-=1000
	b.commands.military._fire_attack(archer,target)
	for tick in range(4):b.projectiles.step()
	var saved:=save();var before: float=target.hp
	assert(saved.simulation.projectiles[0].travel==64 and b.saver.apply_snapshot(saved))
	archer=find(archer_uid);target=find(target_uid)
	for tick in range(5):b.projectiles.step()
	assert(target.hp==before and b.projectiles.active[0].travel==144)
	b.projectiles.step();assert(target.hp==before-damage)
	var valid:=save()
	for change in [{"kind":"beam"},{"travel":999999.0},{"damage":-1},{"sourceUid":0.5},{"x":-1},{"a":999999}]:
		var bad: Dictionary=valid.duplicate(true)
		b.projectiles.launch(archer,target,"arrow")
		bad.simulation.projectiles=b.projectiles.snapshot();bad.simulation.projectiles[0].merge(change,true)
		assert(not b.saver.apply_snapshot(bad) and is_same(target,find(target_uid)))
		b.projectiles.active.clear()
	# 旧档无弹体字段，清空读档前的飞行效果，不伪造旧版即时攻击。
	var old: Dictionary=valid.duplicate(true);old.v=6;old.simulation.erase("projectiles")
	b.commands.military._fire_attack(archer,target);assert(b.saver.apply_snapshot(old) and b.projectiles.active.is_empty())
	archer=find(archer_uid);target=find(target_uid)
	print("PROJECTILE SAVE PASS midflight64 / arrival160 / invalid atomic / legacy clears stale flight")
	var cat:=spawn(34,b.player_owner,Vector2(1000,1500))
	target.ax=1160;target.ay=1500
	var cell: Vector2i=b.commands.orders._cell_of_px(target.ax,target.ay)
	var friendly:=spawn(32,b.player_owner,b.commands.orders._anchor_of_cell(cell))
	friendly.hp=1000;friendly.maxhp=1000;friendly.base_maxhp=1000;friendly.defence_b=7
	b.commands.military._fire_attack(cat,target);target.ax+=300
	for tick in range(19):b.projectiles.step()
	assert(friendly.hp==1000 and b.projectiles.active[0].travel==152)
	b.projectiles.step()
	assert(friendly.hp==857 and target.hp==before-damage,"stone damages current occupant, including friendly, with impact B defence")
	friendly.defence_b=10000;b.commands.military._fire_attack(cat,friendly)
	var steps:=ceili(b.projectiles.distance(b.projectiles.active[0])/8.0)
	for tick in range(maxi(1,steps)):b.projectiles.step()
	assert(friendly.hp==856,"landing damage has integer minimum one")
	print("PROJECTILE STONE PASS speed8 / fixed landing cell / moving target escapes / friendly occupant / B defence / minimum1")
	# 不存在的目标UID不能命中后生成的新对象；源阵亡不取消已发射箭矢。
	target.ax=1160;target.hp=100000;target.maxhp=100000;target.base_maxhp=100000
	b.commands.military._fire_attack(archer,target)
	b.commands.world._free_unit_at(b.units.find(target))
	var replacement:=spawn(32,enemy_owner,Vector2(1160,1500));var hp:float=replacement.hp
	for tick in range(10):b.projectiles.step()
	assert(replacement.hp==hp)
	b.commands.military._fire_attack(archer,replacement);b.commands.military._kill(archer);b.commands.world._free_unit_at(b.units.find(archer))
	for tick in range(10):b.projectiles.step()
	assert(replacement.hp<hp)
	archer=spawn(45,b.player_owner,Vector2(1000,1500));replacement.hp=100000
	for index in range(100):assert(b.projectiles.launch(archer,replacement,"arrow"))
	assert(not b.projectiles.launch(archer,replacement,"arrow") and b.projectiles.active.size()==100 and replacement.hp==100000)
	for tick in range(10):b.projectiles.step()
	assert(b.projectiles.active.is_empty() and replacement.hp==100000-100*b.commands.military._damage(archer,replacement))
	for tick in range(10):b.projectiles.step()
	assert(replacement.hp==100000-100*b.commands.military._damage(archer,replacement),"dropped 101st shot is never retried")
	print("PROJECTILE LIMIT PASS stale target UID / dead shooter / 100 slots / full drops shot and damage / no retry")
	for unit in b.units:b.commands.military._cancel_unit_command(unit);unit.hold=true
	replacement.hp=100000;replacement.maxhp=100000;replacement.base_maxhp=100000
	b.selected=[archer];assert(b.commands.orders._attack_selected(replacement)==1)
	b.game_end=0;b.sim_tick=0;b.sim_acc=0
	var initial:=save()
	for speed in range(4):
		for fps in [30,144]:
			assert(b.saver.apply_snapshot(initial));b.ai=null;b.commands.world.set_sim_speed(speed)
			var elapsed:=0.0;var duration:float=40*b.clock.period()
			while elapsed<duration-0.000000001:
				var frame:=minf(1.0/fps,duration-elapsed);b._process(frame);elapsed+=frame
			while b.sim_acc+0.000000001>=b.clock.period():b._process(0)
			assert(b.sim_tick==40 and b.projectiles.active.size()==1 and b.projectiles.active[0].travel==96)
			assert(find(int(replacement.uid)).hp==100000)
			for tick in range(10):b.commands.world._sim_step(b.SIM_DT)
			assert(b.projectiles.active.is_empty() and find(int(replacement.uid)).hp==100000-damage)
	print("PROJECTILE SPEED PASS four speeds x30-144fps / first34 launch / tick40 travel96 / one arrival by50")
	done=true;b.queue_free();await process_frame;quit(0)
