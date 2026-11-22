extends "test_contact_and_occupancy.gd"
const K=preload("res://simulation/native/math_kernel.gd")
const A=preload("res://simulation/movement/action_clock.gd")
func run():
	var kernel:=K.get_kernel()
	if kernel==null:print("NATIVE GEOMETRY FALLBACK PASS");done=true;quit();return
	root.get_node("Game").current_map="chibic1"
	var scene=load("res://main.tscn").instantiate();root.add_child(scene);scene.set_process(false)
	template=scene.units.filter(func(u):return int(u.unit)==30)[0].duplicate(true);metadata=scene.map_data.units.duplicate(true);scene.scene.ready_to_save=false;scene.free()
	blank();var rng:=RandomNumberGenerator.new();rng.seed=778351
	for i in range(180):sim.nav.block(Vector2i(rng.randi_range(0,39),rng.randi_range(0,39)))
	for case in range(800):
		var kind: int=[32,37,49,1,11][case%5]
		var a:=make(1,3,kind,Vector2i(rng.randi_range(0,39),rng.randi_range(0,39)))
		var b:=make(2,2,[32,37,1,11][case%4],Vector2i(rng.randi_range(0,39),rng.randi_range(0,39)))
		b.is_building=int(b.unit)<27;a.is_building=kind<27
		if case%4==0:b.ax=a.ax+rng.randf_range(-80,80);b.ay=a.ay+rng.randf_range(-30,30)
		install([a,b]);var native_actor:=a.duplicate(true)
		var flags:=A.prepare_attack_script(a,b,1,44,false);var reached: bool=(flags&2)!=0
		if not reached:
			var ac: Vector2i=sim.world.spatial_index._unit_cell(a);var bc: Vector2i=sim.world.spatial_index._unit_cell(b)
			reached=maxi(absi(ac.x-bc.x),absi(ac.y-bc.y))<=2
		reached=reached and sim.world.combat._melee_line_clear(a,b)
		var expected: int=(flags&1)|(2 if reached else 0)
		var actual: int=kernel.prepare_combat(native_actor,b,1,44,false,sim.nav.native_query_context())
		assert(actual==expected and a==native_actor,"native contact "+str(case))
		assert(kernel.overlaps(a,sim.state._cell_index,sim.nav.native_query_context())==sim.world.spatial_index._unit_overlaps_other_script(a),"native overlap "+str(case))
		if case<100:
			var cell: Vector2i=sim.world.spatial_index._unit_cell(a)
			K.force_script=true;var oracle: Vector2i=sim.world.spatial_index._connected_separation_cell_script(a,cell,case%2==0);K.force_script=false
			var selected: Vector2i=sim.world.spatial_index._connected_separation_cell(a,cell,case%2==0)
			assert(selected==oracle,"native separation "+str(case)+str([selected,oracle]))
	var context: Dictionary=sim.nav.native_query_context()
	var previous: WeakRef=weakref(context.nativeQuery)
	sim.nav.version+=1
	sim.nav.native_query_context()
	context={}
	assert(previous.get_ref()==null,"navigation revision retained old query data")
	context=sim.nav.native_query_context();previous=weakref(context.nativeQuery);context={}
	sim.free()
	assert(previous.get_ref()==null,"math provider retained a released world's navigation")
	done=true;print("NATIVE GEOMETRY PASS 800 contact and overlap / 100 ordered separation / blocks / multi-cell / map edges");quit()
