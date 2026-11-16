extends "test_contact_and_occupancy.gd"
const Roster = preload("res://simulation/queries/construction_roster.gd")
const Schema = preload("res://simulation/definitions/unit_schema.gd")
func run() -> void:
	root.get_node("Game").current_map="chibic1"
	var scene=load("res://main.tscn").instantiate();root.add_child(scene);scene.set_process(false)
	template=scene.units.filter(func(u):return int(u.unit)==30)[0].duplicate(true)
	leader_template=scene.selected[0].duplicate(true);metadata=scene.map_data.units.duplicate(true)
	scene.scene.ready_to_save=false;scene.free()
	resource_contract();roster_contract();blocked_contract();actual_map_contract()
	sim.free();done=true
	print("HOT PATH CONTRACTS PASS resource cache invalidation / scoped navigation restoration / decision roster / blocked budget continuation / rollback and old-world release / chibil8")
	quit()

func resource_contract() -> void:
	blank();sim.map_data.decor=[[14,20,0],[15,20,0],[16,20,0]]
	sim.commands.economy._build_decor_targets()
	var actor:=make(1,3,30,Vector2i(10,20));install([actor])
	var paths=sim._modules.interaction_paths;var index=paths.resource_index
	var target: Dictionary=sim.decor_cells["14_20"]
	var other_kind: Dictionary=target.duplicate();other_kind.unit=102
	assert(paths._resource_patch_cells(other_kind).is_empty())
	var cells: Array=paths._resource_patch_cells(target)
	assert(cells==[Vector2i(14,20),Vector2i(15,20),Vector2i(16,20)] and cells.is_read_only())
	for repeat in range(30): assert(is_same(cells,paths._resource_patch_cells(target)))
	assert(index.metrics.patchBuilds==2 and index.metrics.patchHits==30,"Different resource kinds cannot share a root cache entry")
	var point:=Vector2(target.ax,target.ay-30)
	assert(sim.commands.economy._resource_at(point).uid==target.uid)
	for repeat in range(30): sim.commands.economy._resource_at(point)
	assert(sim._modules.harvest_orders.resource_index.metrics.hitBuilds==1)
	sim.commands.economy._remove_decor(sim.decor_cells["15_20"])
	assert(paths._resource_patch_cells(target)==[Vector2i(14,20)],"Depletion splits a cached patch")
	sim.commands.economy._remove_decor(target)
	assert(sim.commands.economy._resource_at(point).is_empty(),"Depleted decor must leave the hit index")
	var builds: int=index.metrics.patchBuilds
	sim.nav.tile_w=45;paths._resource_patch_cells(target)
	assert(index.metrics.patchBuilds==builds+1,"Geometry changes invalidate cell projections")
	# Force rejection of every candidate; temporary avoid flags must still unwind.
	var nav=sim.nav;var origin: Vector2=nav.anchor_of(4,4);var avoided:=Vector2i(12,12)
	var before: bool=nav.state.astar.is_point_disabled(nav._id(avoided))
	var accepts:=func(_path): return false
	assert(nav.paths.first_path_avoiding(origin,[nav.anchor_of(10,10),nav.anchor_of(11,11)],[avoided],Vector2i(-1,-1),0,3,30,accepts).is_empty())
	assert(nav.state.astar.is_point_disabled(nav._id(avoided))==before)
	assert(nav.performance_counters().avoidScopes>0 and nav.performance_counters().avoidWrites>0)
	# Keeping a value index alive must not keep the disposed world's state alive.
	paths=null
	var state: WeakRef=weakref(sim.state);sim.free();sim=null
	assert(state.get_ref()==null and cells.size()==3)

func roster_contract() -> void:
	blank();var leader:=leader_template.duplicate(true);leader.uid=1;leader.owner=3
	var worker:=make(2,3,30,Vector2i(10,10));worker.group_officer=int(leader.officer.index)
	install([leader,worker]);var roster:=Roster.new(sim.units)
	assert(roster.scanned==2 and roster.construction_workers(leader)==[worker])
	assert(roster.construction_workers(leader.duplicate(true)).is_empty(),"Equal clones are not roster members")
	worker.unit=32
	assert(sim.commands.military._construction_workers(leader).is_empty())
	worker.unit=30;worker.owner=2
	assert(sim.commands.military._construction_workers(leader).is_empty())
	worker.owner=3;worker.attached=true
	assert(sim.commands.military._construction_workers(leader).is_empty())
	worker.attached=false;worker.alive=false
	assert(sim.commands.military._construction_workers(leader).is_empty())

func blocked_contract() -> void:
	blank();var actor:=make(1,3,30,Vector2i(4,20));var blocker:=make(2,3,30,Vector2i(25,20));install([actor,blocker])
	sim.next_uid=3
	for y in range(40): sim.nav.block(Vector2i(15,y))
	var goal: Vector2=sim.nav.anchor_of(25,20)
	actor.state="move";actor.path=[goal];actor.pi=0
	var nav=sim.nav;var before:=int(nav.performance_counters().calls)
	sim.commands.orders._follow(actor,sim.SIM_DT)
	assert(int(nav.performance_counters().calls)-before<=12 and int(actor.blocked_cursor)==6)
	var saved: Dictionary=Schema.snapshot_scalars(actor)
	var clone:=actor.duplicate(true);clone.erase("blocked_cursor");Schema.restore_scalars(saved,clone)
	assert(clone.blocked_cursor==actor.blocked_cursor and Schema.valid_snapshot(saved))
	var movement=sim._modules.movement
	for attempt in range(7):
		before=int(nav.performance_counters().calls)
		movement._replan_blocked_destination(actor,goal)
		assert(int(nav.performance_counters().calls)-before<=12)
		movement._replan_blocked_destination(clone,goal)
		assert(actor.get("blocked_cursor",0)==clone.get("blocked_cursor",0) and actor.path==clone.path)
	assert(not actor.has("blocked_cursor") and actor.path.is_empty() and int(actor.blocked_n)==1)
	# Once a blocker leaves, normal movement clears the suspended search state.
	actor.path=[goal];actor.pi=0;actor.blocked_cursor=6
	blocker.attached=true;sim.commands.world._place_unit(blocker)
	for y in range(40): sim.nav.unblock(Vector2i(15,y))
	sim.commands.orders._follow(actor,sim.SIM_DT)
	assert(not actor.has("blocked_cursor") and actor.moved)
	blocker.attached=false
	var point: Vector2=sim.nav.anchor_of(30,30)
	blocker.ax=point.x;blocker.ay=point.y;blocker.A=30;blocker.B=30
	sim.commands.world._place_unit(blocker)
	movement=null
	world_exchange_contract(actor)

func world_exchange_contract(actor: Dictionary) -> void:
	var game: Node=root.get_node("Game")
	sim.saver=load("res://app/save_service.gd").new(sim)
	var data: Dictionary=sim.map_data.duplicate(true)
	data.decor=[[14,20,0],[15,20,0]]
	sim.map_data=data;sim.nav.setup(sim.map_data);sim.commands.economy._build_decor_targets()
	var index=sim._modules.interaction_paths.resource_index
	var cells: Array=sim.commands.orders._resource_patch_cells(sim.decor_cells["14_20"])
	var revision: int=sim.resource_revision
	assert(cells.size()==2)
	actor.blocked_cursor=6
	var snapshot: Dictionary=game.snapshot(sim.units,sim.commands.world._resources(),sim.saver.save_extra())
	var old_state: WeakRef=weakref(sim.state)
	var old_world: WeakRef=weakref(sim.world)
	var transaction=load("res://app/saves/world_transaction.gd")
	transaction.force_view_failure=true
	assert(not sim.saver.apply_snapshot(snapshot) and old_state.get_ref()==sim.state and actor.blocked_cursor==6)
	assert(is_same(cells,sim.commands.orders._resource_patch_cells(sim.decor_cells["14_20"])))
	transaction.force_view_failure=false
	assert(sim.saver.apply_snapshot(snapshot))
	assert(old_world.get_ref()==null and old_state.get_ref()==null)
	assert(sim.units[0].blocked_cursor==6)
	sim.resource_revision=revision
	assert(not is_same(index,sim._modules.interaction_paths.resource_index))
	assert(sim.commands.orders._resource_patch_cells(sim.decor_cells["14_20"]).size()==2)
	sim.commands.economy._remove_decor(sim.decor_cells["15_20"])
	assert(sim.commands.orders._resource_patch_cells(sim.decor_cells["14_20"]).size()==1 and cells.size()==2)
	var previous: Dictionary=snapshot.duplicate(true)
	previous.simulation.rulesRevision="fc1e06331f3969e92e529186f38cf2ddaf84abcf0f1a4a5368ea3e850873b6d6"
	for record in previous.units: record.simulation.erase("blocked_cursor")
	assert(sim.saver.apply_snapshot(previous),"Pinned v3 saves must explicitly adopt bounded repathing")
	assert(int(sim.units[0].get("blocked_cursor",0))==0)
	previous.simulation.rulesRevision="unreviewed-rules"
	assert(not sim.saver.apply_snapshot(previous))

func actual_map_contract() -> void:
	blank();sim.map_data=JSON.parse_string(FileAccess.get_file_as_string("res://data/chibil8.json"))
	sim.nav.setup(sim.map_data);sim.commands.economy._build_decor_targets()
	var checked: Dictionary={};var largest:=0
	for target: Dictionary in sim.decor_targets:
		if not target.alive or int(target.unit) not in [100,102] or checked.has(target.cell): continue
		var cells: Array=sim.commands.orders._resource_patch_cells(target)
		largest=maxi(largest,cells.size())
		for cell: Vector2i in cells: checked["%d_%d"%[cell.x,cell.y]]=true
	assert(sim.decor_targets.size()==10736 and largest==1240)
