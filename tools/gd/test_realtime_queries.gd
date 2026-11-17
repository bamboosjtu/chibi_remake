extends "test_contact_and_occupancy.gd"
const Ray=preload("res://simulation/navigation/grid_ray.gd")
func run() -> void:
	root.get_node("Game").current_map="chibic1"
	var scene=load("res://main.tscn").instantiate();root.add_child(scene);scene.set_process(false);scene.cli_mode=true
	template=scene.units.filter(func(u):return int(u.unit)==30)[0].duplicate(true);metadata=scene.map_data.units.duplicate(true)
	scene.scene.ready_to_save=false;scene.free()
	blank();rays();retries();sim.free();sim=null
	view_and_save()
	done=true;quit()
func rays() -> void:
	var rng:=RandomNumberGenerator.new();rng.seed=770511
	var pairs: Array=[]
	for i in range(200):pairs.append([Vector2(rng.randf_range(0,1847),rng.randf_range(0,499)),Vector2(rng.randf_range(0,1847),rng.randf_range(0,499))])
	for y in [0.0,5.5,16.5,22.0,27.5,445.5,456.5,499.0]:
		pairs.append([Vector2(0,y),Vector2(1847,y)]);pairs.append([Vector2(44,y),Vector2(88,y+11)])
	for pair in pairs:
		var a: Vector2=pair[0];var b: Vector2=pair[1];var covered: Dictionary={};var reversed: Dictionary={}
		for id in Ray.cells(a,b,44,40,40):covered[id]=true
		for id in Ray.cells(b,a,44,40,40):reversed[id]=true
		assert(covered==reversed,"A ray must have the same conservative cells in both directions")
		var samples:=maxi(1,ceili(a.distance_to(b)/1.0))
		for sample in range(samples+1):
			var p:=a.lerp(b,float(sample)/samples);var cell: Vector2i=sim.nav.cell_of_px(p.x,p.y)
			assert(covered.has(cell.x*40+cell.y),"Grid ray omitted a dense contact sample: "+str([a,b,p,cell]))
	# Actual collision still uses each layer and includes dynamic occupancy.
	var a: Vector2=sim.nav.anchor_of(10,10);var b: Vector2=sim.nav.anchor_of(10,12)
	assert(sim.nav.segment_clear(a,b));sim.nav.block(Vector2i(10,11));assert(not sim.nav.segment_clear(a,b))
	sim.nav.unblock(Vector2i(10,11));assert(sim.nav.segment_clear(a,b))
	print("REALTIME RAYS PASS dense reference / reverse / staggered edges / boundary clamp / dynamic blockers")
func retries() -> void:
	blank();var a:=make(1,3,32,Vector2i(10,10));var b:=make(2,2,32,Vector2i(10,20));install([a,b])
	for x in range(40):sim.nav.block(Vector2i(x,15))
	a.state="attack";a.target=b;a.repath=0;a.route_failures=0;a.blocked_n=0
	var initial: int=sim.nav.performance_counters().calls
	for tick in range(120):sim.commands.orders._step_unit_inner(a,sim.SIM_DT)
	var queries: int=sim.nav.performance_counters().calls-initial
	assert(queries>0 and queries<=64,"Failed paths must honor cooldown/backoff instead of querying every tick: "+str(queries))
	assert(a.route_failures==3 and b.hp==1000.)
	var calls: int=sim.nav.performance_counters().calls
	sim.commands.military._cancel_unit_command(a);assert(a.route_failures==0)
	a.state="attack";a.target=b;a.repath=0;sim.commands.orders._step_unit_inner(a,sim.SIM_DT)
	assert(sim.nav.performance_counters().calls>calls,"A new order can query immediately")
	for x in range(40):sim.nav.unblock(Vector2i(x,15))
	for tick in range(150):sim.commands.orders._step_unit_inner(a,sim.SIM_DT)
	assert(a.route_failures==0 and (not a.path.is_empty() or b.hp<1000.),"Opening a route must recover without discarding the attack order")
	print("REALTIME RETRIES PASS bounded failed queries / explicit order reset / topology recovery")
func view_and_save() -> void:
	var scene=load("res://main.tscn").instantiate();root.add_child(scene);scene.set_process(false);scene.cli_mode=true;scene.ai=null
	var unit: Dictionary=scene.selected[0];unit.route_failures=2;unit.repath=1.25
	assert(scene.commands.session._save_game())
	var snapshot: Dictionary=root.get_node("Game").load_save();var uid:=int(unit.uid)
	assert(snapshot.units.any(func(record):return int(record.uid)==uid and int(record.simulation.route_failures)==2))
	var summaries: Array=scene.commands.military.control_group_summaries()
	assert(summaries.is_read_only() and summaries.size()==10)
	for slot in range(1,11):
		assert(summaries[slot-1].is_read_only() and int(summaries[slot-1].count)==scene.commands.military.control_group_size(slot))
		var site: Dictionary=scene.commands.military.control_group_work_site(slot)
		assert(str(summaries[slot-1].workSiteName)==("" if site.is_empty() else str(site.name)))
	var before: Dictionary=scene.view.performance_counters()
	var notifications: Array=[]
	var observe:=func(action: String,_arguments: Array):notifications.append(action)
	scene.state.effects.visual_requested.connect(observe)
	for tick in range(5):scene.commands.world._sim_step(scene.SIM_DT)
	scene.state.effects.visual_requested.disconnect(observe)
	assert(notifications.count("world_dirty")==5 and not notifications.has("update_visual") and not notifications.has("place_unit"),"Each tick emits one world refresh rather than per-unit visual signals")
	assert(scene.view.performance_counters().syncCalls==before.syncCalls,"Logic ticks must not perform sprite synchronization")
	scene.view.flush_visuals()
	var calls: int=scene.view.performance_counters().syncCalls-before.syncCalls
	assert(calls>0 and calls<=scene.units.size(),"Five catch-up ticks synchronize each UID once")
	unit.ax+=100;scene.view.queue_visual(unit)
	assert(scene.saver.apply_snapshot(snapshot))
	var restored: Dictionary=scene.units.filter(func(u):return int(u.uid)==uid)[0]
	assert(not is_same(restored,unit) and restored.route_failures==2 and is_equal_approx(restored.repath,1.25))
	scene.view.flush_visuals()
	assert(is_equal_approx(scene.view.unit_nodes(restored).spr.position.x,float(restored.ax)-float(restored.w)*0.5),"Old queued unit references cannot repaint a restored world")
	var migration: Dictionary=snapshot.duplicate(true)
	migration.simulation.rulesRevision="unapproved-future-rules"
	assert(not scene.saver.apply_snapshot(migration),"Unknown rule changes still require explicit approval")
	var invalid: Dictionary=snapshot.duplicate(true);invalid.units[0].simulation.route_failures=4
	assert(not scene.saver.apply_snapshot(invalid))
	scene.scene.ready_to_save=false;scene.free()
	print("REALTIME VISUALS PASS five ticks one sync / current UID resolution / retry save continuity / exact current identity / unknown rules rejected / invalid retry state rejected")
