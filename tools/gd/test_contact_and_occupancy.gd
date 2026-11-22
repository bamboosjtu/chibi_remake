extends SceneTree
var done := false
var sim
var template: Dictionary
var metadata: Dictionary
var leader_template: Dictionary
func _initialize() -> void:
	create_timer(120).timeout.connect(func():
		if not done:quit(1))
	run.call_deferred()
func blank() -> void:
	if sim!=null:sim.free()
	sim=load("res://main.gd").new();var walk: Array=[];walk.resize(1600);walk.fill(1)
	sim.map_data={"rows":40,"cols":40,"terrainW":1848,"terrainH":500,"tileW":44,"walkable":walk,"terrainWalkable":walk.duplicate(),"units":metadata.duplicate(true)}
	sim.nav.setup(sim.map_data);sim.visibility.setup(Vector2(1848,500));sim.visibility.set_full_reveal(true);sim.player_owner=3
	sim.units=[];sim.ai=null
func make(uid: int, owner: int, kind: int, cell: Vector2i) -> Dictionary:
	var unit:=template.duplicate(true);unit.uid=uid;unit.owner=owner;unit.unit=kind;unit.is_building=false;unit.officer={};unit.group_officer=-1
	unit.state="idle";unit.target=null;unit.path=[];unit.hp=1000.;unit.maxhp=1000.;unit.attack=20.;unit.attack_b=20.;unit.defence=0.;unit.defence_b=0.
	unit.atk_range=1.;unit.rate=1000;unit.alive=true;unit.die_t=-1.;unit.action_wait=0;unit.action_started=false;unit.action_phase=0
	var point: Vector2=sim.nav.anchor_of(cell.x,cell.y);unit.ax=point.x;unit.ay=point.y;unit.A=cell.x;unit.B=cell.y
	return unit
func install(units: Array) -> void:
	sim.units=units;sim.world.spatial_index._rebuild_unit_index();sim.visibility.update(units,3)
func fight(a: Dictionary, b: Dictionary, ticks: int=8) -> void:
	a.state="attack";a.target=b
	for i in range(ticks):sim.projectiles.step();sim.world.unit_actions._step_unit_inner(a,sim.SIM_DT)
func run() -> void:
	root.get_node("Game").current_map="chibic1"
	var scene=load("res://main.tscn").instantiate();root.add_child(scene);scene.set_process(false)
	template=scene.units.filter(func(u):return int(u.unit)==30)[0].duplicate(true)
	leader_template=scene.selected[0].duplicate(true);metadata=scene.map_data.units.duplicate(true);scene.scene.ready_to_save=false;scene.free()
	for delta in [Vector2i(0,-2),Vector2i(0,-1),Vector2i(1,0),Vector2i(0,1),Vector2i(0,2),Vector2i(-1,1),Vector2i(-1,0),Vector2i(-1,-1),Vector2i(2,0),Vector2i(-2,0),Vector2i(1,2),Vector2i(1,-2),Vector2i(-1,2),Vector2i(-1,-2)]:
		blank();var a:=make(1,3,32,Vector2i(10,10));var b:=make(2,2,32,Vector2i(10,10)+delta);install([a,b]);fight(a,b)
		assert(b.hp<1000.,"Open melee direction "+str(delta))
	for dy in [-2,2]:
		blank();var a:=make(1,3,32,Vector2i(10,10));var b:=make(2,2,32,Vector2i(10,10+dy))
		for x in range(40):sim.nav.block(Vector2i(x,10+dy/2))
		install([a,b]);fight(a,b);assert(b.hp==1000.,"Normal-range contact through wall")
		sim.nav.unblock(Vector2i(10,10+dy/2));fight(a,b,16);assert(b.hp<1000.,"A passable wall opening restores contact")
	blank();var a:=make(1,3,32,Vector2i(10,10));var b:=make(2,2,32,Vector2i(10,14))
	var cells: Array=sim.nav.building_footprint(1,sim.nav.anchor_of(11,13),144)
	sim.nav.occupy(cells,1);install([a,b])
	assert(not sim.world.combat._melee_line_clear(a,b),"Building fixture must obstruct the initial ray")
	for i in range(8):
		var blocked: bool=not sim.world.combat._melee_line_clear(a,b);var hp: float=b.hp
		fight(a,b,1)
		if blocked:assert(b.hp==hp,"A melee strike cannot cross the building; walking around it remains legal")
	sim.nav.occupy(cells,-1);fight(a,b,16);assert(b.hp<1000.)
	blank();a=make(1,3,45,Vector2i(10,10));b=make(2,2,32,Vector2i(10,14));a.atk_range=6
	for x in range(40):sim.nav.block(Vector2i(x,12))
	install([a,b]);fight(a,b,60);assert(b.hp<1000.,"Ranged projectiles keep their over-wall rule")
	print("CONTACT PASS eight normal directions / reachable compensation / normal-range walls / opening / closed building / ranged over wall")
	occupancy();sim.free();done=true;quit()
func occupancy() -> void:
	blank();var leader:=leader_template.duplicate(true);leader.uid=1;leader.owner=3
	var point: Vector2=sim.nav.anchor_of(8,10);leader.ax=point.x;leader.ay=point.y;leader.A=8;leader.B=10
	var worker:=make(2,3,30,Vector2i(9,10));worker.group_officer=int(leader.officer.index)
	var passenger:=make(3,3,32,Vector2i(20,20));var ship:=make(4,3,47,Vector2i(22,20))
	install([leader,worker,passenger,ship]);sim.selected=[leader];sim.build_types=[{"unit":11}]
	sim.gold=100000.;sim.food=100000.;sim.wood=100000.;sim.stone=100000.
	var site_point: Vector2=sim.nav.anchor_of(20,20)
	assert(not sim.world.construction_orders.build_placement_at(site_point,{"unit":11}).valid)
	assert(sim.world.transport_orders._attach_to_ship(passenger,ship),"Actual boarding transition")
	assert(sim.world.spatial_index._cell_unit(Vector2i(20,20),-1,0).is_empty())
	assert(sim.world.construction_orders.build_placement_at(site_point,{"unit":11}).valid)
	var site: Dictionary=sim.world.construction_orders._place_building(3,11,site_point,true,[],true)
	assert(not site.is_empty(),"Commit uses the same occupancy query as preview")
	assert(sim.world.transport_orders._order_unload(ship)==1)
	for tick in range(4):sim.world.unit_actions._step_unit(ship,sim.SIM_DT)
	assert(not passenger.attached)
	var landed: Vector2i=sim.nav.cell_of_px(passenger.ax,passenger.ay)
	assert(sim.world.spatial_index._cell_unit(landed,-1,0).uid==passenger.uid)
	sim.world.combat._kill(passenger)
	assert(sim.world.spatial_index._cell_unit(landed,-1,0).is_empty())
	worker.state="build";worker.build_target=site;sim.construction.enter(worker,site)
	assert(not sim.world.spatial_index._index_eligible(worker))
	assert(sim.construction.leave(worker) and sim.world.spatial_index._index_eligible(worker))
	print("OCCUPANCY PASS boarded unit absent / preview=commit / disembark reindexes / death removes / site enter-leave contract")
