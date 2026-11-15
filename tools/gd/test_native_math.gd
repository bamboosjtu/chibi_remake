extends SceneTree
const K=preload("res://simulation/native/math_kernel.gd")
const S=preload("res://simulation/systems/stratagem_rules.gd")
const L=preload("res://simulation/systems/locomotion.gd")
const T=preload("res://simulation/systems/tick_timers.gd")
const A=preload("res://simulation/systems/action_clock.gd")
func _initialize():run.call_deferred()
func run():
	var kernel:=K.get_kernel()
	if kernel==null:
		assert(OS.get_name()!="Windows","Windows math kernel missing")
		print("NATIVE MATH FALLBACK PASS");quit();return
	var rng:=RandomNumberGenerator.new();rng.seed=55138
	for case in range(2000):
		var u: Dictionary={"is_building":case%9==0,"attached":case%17==0,"site_inside_uid":5 if case%19==0 else -1,"dir":rng.randi_range(0,7),"moved":case%2==0,"state":["idle","attack","repair","move"][case%4],"walk_tick":case,"move_facing":rng.randi_range(0,7),"turn_tick":case%5,"move_started":case%3==0,"move_turning":case%5==0,"effect_task":[0,27,28][case%3],"effect_tasks":[27,28] if case%7==0 else [],"action_kind":"attack" if case%4==0 else "","action_target_uid":1,"action_wait":case%25,"action_phase":case%7,"action_started":case%3==0,"rate":[0,1,50,100,225,500,1000,1800][case%8],"clips":{"walk":[[0,1,2,3],[0,1],[],[0,1,2,3,4,5,6,7,8]]},"ax":rng.randf_range(-400,400),"ay":rng.randf_range(-400,400),"uid":1}
		for field in T.STATUS_KEYS:u[field]=rng.randi_range(0,5) if case%3==0 else 0
		var a:=u.duplicate(true);var b:=u.duplicate(true)
		S.begin_update_script(a);kernel.begin_status(b);assert(a==b,"begin status "+str(case))
		L.step_script(a);T.step_statuses_script(a);kernel.finish_unit(b);assert(a==b,"finish "+str(case))
		var target: Dictionary={"uid":case%4,"ax":rng.randf_range(-400,400),"ay":rng.randf_range(-400,400)}
		for tick in range(8):
			var expected:=A.prepare_attack_script(a,target,1,44,case%9==0)
			var actual: int=kernel.prepare_attack(b,target,1,44,case%9==0)
			if expected!=actual or a!=b:
				print("MISMATCH ",case," ",tick," ",expected," ",actual," ",JSON.stringify(a)," ",JSON.stringify(b))
				assert(false,"native attack mismatch")
	visibility_equivalence()
	print("NATIVE MATH PASS 2000 seeded fixtures / 16000 attack updates / queues / timers / locomotion / exact field equality")
	quit()

func visibility_equivalence() -> void:
	var View=preload("res://simulation/systems/battle_visibility.gd")
	var actual:=View.new();var expected:=View.new()
	actual.setup(Vector2(1600,1000));expected.setup(Vector2(1600,1000))
	var rng:=RandomNumberGenerator.new();rng.seed=100723
	var units: Array=[]
	for i in range(45):
		units.append({"uid":i,"owner":1 if i%3 else 2,"alive":true,"die_t":-1.,"attached":false,"is_building":i%5==0,"site":i%10==0,"unit":30,"ax":rng.randf_range(-50,1650),"ay":rng.randf_range(-50,1050),"vision":i%12,"farsight_t":0})
	for tick in range(160):
		for i in range(units.size()):
			var unit: Dictionary=units[i]
			unit.ax+=rng.randf_range(-11,11);unit.ay+=rng.randf_range(-8,8)
			unit.attached=(tick+i)%19==0;unit.site=(tick+i)%11==0
			unit.alive=(tick+i)%17!=0;unit.die_t=0.1 if (tick+i)%23==0 else -1.
			unit.farsight_t=10 if (tick+i)%7==0 else 0
		if tick%25==0:
			actual.set_full_reveal(not actual.full_reveal);expected.set_full_reveal(not expected.full_reveal)
		var inputs: Array=[] if tick%31==0 else units
		actual.update(inputs,1);expected.update_script(inputs,1)
		assert(actual.current==expected.current and actual.explored==expected.explored and actual.reveals==expected.reveals,"visibility arrays at "+str(tick))
		assert(actual.revision==expected.revision and actual._sources==expected._sources,"visibility sources/revision at "+str(tick))
	print("NATIVE VISIBILITY PASS 160 seeded updates / buildings / sites / death / passengers / overlap / full reveal / source removal")
