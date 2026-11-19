extends "test_contact_and_occupancy.gd"
## Identical public-API workloads can run against a historical source checkout.
var results := {}
var rounds := 30
func run() -> void:
	root.get_node("Game").current_map="chibic1"
	var scene=load("res://main.tscn").instantiate();root.add_child(scene);scene.set_process(false)
	template=scene.units.filter(func(u):return int(u.unit)==30)[0].duplicate(true)
	leader_template=scene.selected[0].duplicate(true);metadata=scene.map_data.units.duplicate(true)
	scene.scene.ready_to_save=false;scene.free()
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--hot-rounds="): rounds=maxi(5,int(arg.get_slice("=",1)))
	resource_workload();ai_workload();blocked_workload();preview_workload()
	sim.free();sim=null;done=true
	print("HOT PATH BENCHMARK JSON: "+JSON.stringify(results))
	print("HOT PATH BENCHMARK PASS dense forest / AI construction / blocked destination / build placement")
	quit()

func measure(name: String, action: Callable) -> void:
	for warmup in range(3): action.call()
	var times := []
	for sample in range(rounds):
		var begin:=Time.get_ticks_usec();action.call();times.append(Time.get_ticks_usec()-begin)
	times.sort()
	results[name]={"samples":rounds,"medianMs":times[rounds/2]/1000.0,"p95Ms":times[ceili(rounds*0.95)-1]/1000.0,"maxMs":times.back()/1000.0}

func resource_workload() -> void:
	blank();var decor:=[]
	for x in range(7,37):
		for y in range(2,38): decor.append([x,y,0])
	sim.map_data.decor=decor;sim.world.harvest_orders._build_decor_targets()
	var workers:=[]
	for index in range(8): workers.append(make(index+1,3,30,Vector2i(3,10+index*2)))
	install(workers);sim.selected=workers.duplicate()
	var target: Dictionary=sim.decor_cells["24_20"]
	measure("forest8Workers",func(): assert(sim.world.harvest_orders._order_gather(target)==8))
	results.forest8Workers.cells=decor.size()
	results.forest8Workers.signature=workers.map(func(w):return {"source":w.gather_obj.uid,"path":w.path.map(func(p):return [p.x,p.y])})
	var point:=Vector2(target.ax,target.ay-30)
	measure("decorHit",func(): assert(sim.world.harvest_orders._resource_at(point).uid==target.uid))
	results.decorHit.sources=decor.size()

func ai_workload() -> void:
	blank();var units:=[]
	for index in range(300):
		var leader:=make(index*2+1,3,int(leader_template.unit),Vector2i(3,3))
		leader.officer=leader_template.officer.duplicate();leader.officer.index=index
		var member:=make(index*2+2,3,32,Vector2i(4,3));member.group_officer=index
		units.append(leader);units.append(member)
	install(units)
	var ai=load("res://simulation/systems/ai.gd").new(sim.world)
	measure("aiConstruction600",func():
		assert(sim.world.ai_economy.ai_construction_commander(3).is_empty())
		assert(ai._spare_construction_officer(3).is_empty()))
	results.aiConstruction600.units=units.size()

func blocked_workload() -> void:
	blank();var actor:=make(1,3,30,Vector2i(4,20));var blocker:=make(2,3,30,Vector2i(25,20));install([actor,blocker])
	for y in range(40): sim.nav.block(Vector2i(15,y))
	var goal: Vector2=sim.nav.anchor_of(25,20)
	var calls:=int(sim.nav.performance_counters().calls)
	measure("blockedDestination",func():
		actor.state="move";actor.path=[goal];actor.pi=0;actor.blocked_n=0;actor.erase("blocked_cursor");actor.erase("repath_to")
		assert(not sim.world.movement._follow(actor,sim.SIM_DT)))
	results.blockedDestination.queriesPerInvocation=(int(sim.nav.performance_counters().calls)-calls)/float(rounds+3)

func preview_workload() -> void:
	blank();var leader:=leader_template.duplicate(true);leader.uid=1;leader.owner=3;leader.state="idle";leader.target=null;leader.path=[]
	var at: Vector2=sim.nav.anchor_of(5,10);leader.ax=at.x;leader.ay=at.y;leader.A=5;leader.B=10
	var units: Array=[leader]
	for index in range(5):
		var worker:=make(index+2,3,30,Vector2i(6,10+index));worker.group_officer=int(leader.officer.index);units.append(worker)
	install(units);sim.selected=[leader];sim.build_types=[{"unit":11}]
	sim.gold=100000.;sim.food=100000.;sim.wood=100000.;sim.stone=100000.
	var point: Vector2=sim.nav.anchor_of(25,25)
	assert(sim.world.construction_orders.build_placement_at(point,{"unit":11}).valid)
	measure("buildPlacement",func(): assert(sim.world.construction_orders.build_placement_at(point,{"unit":11}).valid))
