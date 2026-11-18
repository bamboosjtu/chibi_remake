extends "test_contact_and_occupancy.gd"
## Minimal state fixtures cover dispatch, prelude and the animation tail.
func run() -> void:
	root.get_node("Game").current_map="chibic1"
	var scene=load("res://main.tscn").instantiate();root.add_child(scene);scene.set_process(false)
	template=scene.units.filter(func(u):return int(u.unit)==30)[0].duplicate(true)
	metadata=scene.map_data.units.duplicate(true);scene.scene.ready_to_save=false;scene.free()
	for state in ["idle","attack","move","join","board","unload","gather","deliver","rest","repair","build","boarded","dead"]:
		blank()
		var unit:=make(1,3,30,Vector2i(10,10));install([unit])
		unit.state=state;unit.hold=true;unit.anim=0.0
		unit.attached=state=="boarded"
		unit.rest_t=int(preload("res://simulation/definitions/balance_rules.gd").work().restTicks)-1;unit.hp=999.0
		sim._modules.unit_actions._step_unit_inner(unit,sim.SIM_DT)
		var expected: String=state if state in ["idle","unload","boarded","dead"] else "idle"
		assert(unit.state==expected,"Dispatch failed for "+state)
		assert(is_equal_approx(unit.anim,0.0 if state=="boarded" else sim.SIM_DT),"Animation tail failed for "+state)
		if state=="rest": assert(unit.hp==1000.0 and unit.rest_t==0)
	# Delivery waits are the one active state that skips the shared animation tail.
	blank();var worker:=make(1,3,30,Vector2i(10,10));var depot:=make(2,3,10,Vector2i(11,10))
	depot.is_building=true;depot.w=44;depot.h=40;depot.occupied_cells=[Vector2i(11,10)]
	install([worker,depot]);worker.state="deliver";worker.carry_kind="food";worker.carry=10.0;worker.anim=2.0
	sim._modules.unit_actions._step_unit_inner(worker,sim.SIM_DT)
	assert(worker.delivery_ticks==1 and worker.anim==2.0 and worker.state=="deliver")
	# Confusion precedes order execution and animates exactly once.
	worker.state="move";worker.path=[Vector2(worker.ax+100,worker.ay)];worker.confused_t=4
	worker.effect_task=preload("res://simulation/systems/stratagem_rules.gd").CONFUSION
	var before:=Vector2(worker.ax,worker.ay)
	sim._modules.unit_actions._step_unit_inner(worker,sim.SIM_DT)
	assert(worker.state=="move" and Vector2(worker.ax,worker.ay)==before and is_equal_approx(worker.anim,2.0+sim.SIM_DT))
	sim.free();done=true
	print("UNIT ACTION STATES PASS 13 states / invalid orders / rest completion / delivery wait / confusion ordering / animation tail")
	quit()
