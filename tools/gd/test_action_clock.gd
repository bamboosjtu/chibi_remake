extends SceneTree
const Clock = preload("res://simulation/systems/action_clock.gd")
var done := false
var b: Node2D
var game: Node

func _initialize() -> void:
	create_timer(60).timeout.connect(func():
		if not done: quit(1))
	run.call_deferred()

func sample(rate: int, length: int) -> Dictionary:
	var frames: Array=[]
	for i in range(length): frames.append(i)
	return {"rate":rate,"clips":{"walk":[frames]},"dir":0}

func save() -> Dictionary:
	assert(game.save_game(b.units,b.commands.world._resources(),b.commands.session._save_extra()))
	return game.load_save()

func find(uid: int) -> Dictionary:
	return b.units.filter(func(u):return int(u.uid)==uid)[0]

func run() -> void:
	for length in [0,1,2,3,4]:
		var u:=sample(30,length)
		var hits: Array=[]
		for tick in range(1,111):
			if Clock.step(u,"attack",1): hits.append(tick)
		assert(hits.is_empty() if length<3 else hits==([34,69,104] if length==3 else [34,70,106]),str(hits))
	var fast:=sample(30,3);fast.haste_t=800
	var slow:=sample(31,3);slow.slow_t=800
	assert(Clock.period(fast)==16 and Clock.period(slow)==66)
	for tick in range(1,18): assert(Clock.step(fast,"attack",1)==(tick==17))
	var tower:=sample(25,0)
	for tick in range(1,81): assert(Clock.step(tower,"attack",1,true)==(tick in [40,80]))
	Clock.step(fast,"attack",2);assert(fast.action_wait==1 and fast.action_phase==0)
	print("ACTION CLOCK PASS floor1000-rate / first34 / continuing phase / Nbelow3 / haste-slow / tower / target replacement")
	game=root.get_node("Game");game.current_map="chibil1"
	b=load("res://main.tscn").instantiate();root.add_child(b)
	b.set_process(false);b.cli_mode=true;b.ai=null
	for unit in b.units: b.commands.military._cancel_unit_command(unit)
	var workers: Array=b.units.filter(func(u):return u.owner==b.player_owner and int(u.unit)==30)
	var worker: Dictionary=workers[0];var target: Dictionary=workers[1]
	worker.group_officer=-1;worker.ax=target.ax;worker.ay=target.ay
	var worker_uid: int=worker.uid;var target_uid: int=target.uid
	b.gold=1000;b.food=1000;b.wood=1000;b.stone=1000
	target.hp=target.maxhp-40;b.selected=[worker];assert(b.commands.economy._order_repair(target)==1)
	for tick in range(9): b.commands.orders._step_unit(worker,b.SIM_DT)
	assert(target.hp==target.maxhp-40 and worker.action_wait==9)
	var saved:=save();assert(saved.v==game.SAVE_VERSION and b.saver.apply_snapshot(saved))
	worker=find(worker_uid);target=find(target_uid)
	b.commands.orders._step_unit(worker,0.001);assert(target.hp==target.maxhp-40 and worker.action_phase==1)
	b.commands.orders._step_unit(worker,0.1);assert(target.hp==target.maxhp-24 and worker.action_phase==2 and worker.state=="repair")
	for tick in range(28): b.commands.orders._step_unit(worker,b.SIM_DT)
	assert(target.hp==target.maxhp and worker.state=="idle" and b.gold==952 and b.food==952 and b.wood==952 and b.stone==952)
	for tick in range(50): b.commands.orders._step_unit(worker,b.SIM_DT)
	assert(b.gold==952,"full target cannot cause extra repair payments")
	print("ACTION REPAIR PASS first11 / continuous14tick / save9 / capped40HP for48 resources / idle at full")
	# 四资源不足的任一种都结束订单，不继续等待或反复扣款。
	for kind in ["gold","wood","food","stone"]:
		var funds: Dictionary={"gold":100.0,"wood":100.0,"food":100.0,"stone":100.0};funds[kind]=15.0
		b.economy.write(b.player_owner,funds);target.hp=target.maxhp-20;b.selected=[worker]
		assert(b.commands.economy._order_repair(target)==1)
		for tick in range(11):b.commands.orders._step_unit(worker,b.SIM_DT)
		assert(worker.state=="idle" and target.hp==target.maxhp-20 and b.commands.world._resources()==funds,str([kind,worker.state,target.hp,target.maxhp,b.commands.world._resources(),funds]))
	b.selected=[worker];b.commands.economy._order_repair(target)
	for tick in range(9):b.commands.orders._step_unit(worker,b.SIM_DT)
	b.selected=[worker];b.commands.orders._move_selected_to(Vector2(worker.ax,worker.ay))
	assert(worker.action_wait==0 and worker.action_phase==0 and not worker.action_started and worker.repair_target==null)
	print("ACTION REPAIR STOP PASS four resource shortages / no debit / immediate new move resets phase")
	assert(b.commands.world._spawn_unit(32,b.player_owner,worker.ax,worker.ay,true))
	var attacker: Dictionary=b.units.back()
	var enemy: Dictionary=b.units.filter(func(u):return u.owner!=0 and u.owner!=b.player_owner and not u.is_building)[0]
	enemy.ax=attacker.ax+22;enemy.ay=attacker.ay;enemy.hp=1000;enemy.maxhp=1000;enemy.base_maxhp=1000
	b.selected=[attacker];assert(b.commands.orders._attack_selected(enemy)==1)
	for tick in range(10):b.commands.orders._step_unit(attacker,b.SIM_DT)
	assert(enemy.hp==1000 and attacker.action_phase==1)
	b.commands.orders._step_unit(attacker,b.SIM_DT)
	assert(enemy.hp==1000-b.commands.military._damage(attacker,enemy) and enemy.last_attacker_uid==attacker.uid)
	b.commands.military._cancel_unit_command(attacker);attacker.state="attack";attacker.target=enemy
	enemy.ax+=600
	for tick in range(11):b.commands.orders._step_unit(attacker,b.SIM_DT)
	assert(attacker.state=="attack" and is_same(attacker.target,enemy) and attacker.action_wait==0 and not attacker.action_started)
	print("ACTION ATTACK PASS real infantry first11 / last attacker / out-of-range fire resets same-target wait")
	# 新计时非法值在交换世界前拒绝；旧版缺字段从动作首tick开始。
	b.commands.military._cancel_unit_command(worker);saved=save()
	for field in ["action_wait","action_phase","action_target_uid"]:
		var bad: Dictionary=saved.duplicate(true);bad.units[0].simulation[field]=0.5
		assert(not b.saver.apply_snapshot(bad))
	for change in [{"action_wait":1001},{"action_phase":24},{"action_started":1},{"action_kind":"gather"}]:
		var bad: Dictionary=saved.duplicate(true)
		bad.units[0].simulation.merge(change,true);assert(not b.saver.apply_snapshot(bad))
	var legacy: Dictionary=saved.duplicate(true);legacy.v=6
	for rec in legacy.units:
		for field in Clock.FIELDS:rec.simulation.erase(field)
	assert(b.saver.apply_snapshot(legacy))
	assert(b.units.all(func(u):return u.action_wait==0 and u.action_phase==0 and not u.action_started))
	print("ACTION SAVE PASS v%d / invalid atomic / v6 missing clock initializes cleanly"%game.SAVE_VERSION)
	done=true;b.queue_free();await process_frame;quit(0)
