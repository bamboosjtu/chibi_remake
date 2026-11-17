extends SceneTree
class ProjectionProbe extends RefCounted:
	var world := RefCounted.new()
	var sim_tick := 0
	var units: Array = []
	var nav: Object
	var visibility: Object
	var player_owner := 0
var done := false
func _initialize() -> void:
	create_timer(120).timeout.connect(func():
		if not done: quit(1))
	run.call_deferred()

func run() -> void:
	var game: Node=root.get_node("Game");game.current_map="chibic1"
	var battle=load("res://main.tscn").instantiate();root.add_child(battle);battle.set_process(false)
	battle.view.event_view.restore_history();battle.view.flush_visuals()
	var reader: Node2D=battle.view.host
	var actor: Dictionary=battle.selected[0]
	var selected: Array=reader.selection_views()
	var all: Array=reader.unit_views()
	assert(_values(selected) and _values(all) and selected[0].uid==actor.uid)
	assert(not selected[0].has("target") and not selected[0].has("path") and not selected[0].has("gather_obj"))
	var detached: Dictionary=selected[0].duplicate(true);detached.hp=0;detached.officer.level=9
	assert(actor.hp!=0 and actor.officer.level!=9)
	var tier: int=actor.officer.get("tier",4)
	for category in range(1,5):
		actor.officer.tier=category
		assert(battle.commands.military.officer_rank_name(reader.selection_views()[0].officer)==battle.commands.military.officer_rank_name(actor.officer))
	actor.officer.tier=tier
	var builds: int=reader.projection_counters().unitBuilds
	for frame in range(3):
		await process_frame
		for repeat in range(20): assert(is_same(all,reader.unit_views()))
	assert(reader.projection_counters().unitBuilds==builds,"Unchanged render frames must reuse unit values")
	var hp: float=actor.hp;actor.hp-=1
	var changed: Array=reader.selection_views()
	assert(changed[0].hp==hp-1 and selected[0].hp==hp and not is_same(changed,selected))
	actor.hp=hp
	actor.hp-=2; battle.commands.world._place_unit(actor)
	var event_values: Array=reader.unit_views()
	assert(event_values.filter(func(unit):return unit.uid==actor.uid)[0].hp==hp-2)
	actor.hp=hp; battle.commands.world._place_unit(actor)
	var geometry: Array=reader.unit_views()
	battle.nav.tile_w=battle.nav.tile_w+1
	assert(not is_same(geometry,reader.unit_views()),"Navigation geometry is part of the projection identity")
	battle.nav.tile_w=battle.nav.tile_w-1
	battle.selected=[]
	assert(reader.selection_views().is_empty())
	battle.selected=[actor]
	assert(reader.selection_views()[0].uid==actor.uid)
	var tick: int=battle.sim_tick;battle.sim_tick+=1
	assert(not is_same(all,reader.unit_views()));battle.sim_tick=tick
	_projection_cost(battle)
	_work_and_worlds(game,battle,reader)
	battle.scene.ready_to_save=false
	var state: WeakRef=weakref(battle.state)
	battle.free()
	assert(state.get_ref()==null and _values(all) and _values(selected))
	print("UNIT READ MODELS PASS frozen selected-unit-production values / paused scalar invalidation / render cache reuse / UID command epoch / world rollback and replacement / retained projections release old worlds")
	done=true;quit()

func _projection_cost(battle: Node2D) -> void:
	var probe:=ProjectionProbe.new();probe.nav=battle.nav;probe.visibility=battle.visibility;probe.player_owner=battle.player_owner
	var source: Dictionary=battle.units.filter(func(unit):return int(unit.unit)==30)[0]
	for index in range(800):
		var unit: Dictionary=source.duplicate();unit.uid=index;probe.units.append(unit)
	var projection=load("res://app/read_models/unit_projection.gd").new()
	var samples:=[]
	for sample in range(10):
		probe.sim_tick+=1
		var begin:=Time.get_ticks_usec()
		var values: Array=projection.units(probe)
		var visible:=[]
		for index in range(24): visible.append(projection.visual(probe,index))
		samples.append((Time.get_ticks_usec()-begin)/1000.0)
		for value in visible: assert(_values(value))
		for frame in range(60): assert(is_same(values,projection.units(probe)))
	assert(projection.metrics.unitBuilds==10 and projection.metrics.spriteBuilds==1 and projection.metrics.visualBuilds==240)
	samples.sort()
	print("UNIT PROJECTION COST 800 roster + 24 visible / 10 updates / 600 unchanged-frame hits / static sprite copies=1 / medianMs=",samples[5]," p95Ms=",samples[9])

func _work_and_worlds(game: Node, battle: Node2D, reader: Node2D) -> void:
	var building: Dictionary=battle.units.filter(func(unit):return unit.is_building and unit.owner==battle.player_owner and int(unit.unit) in [0,1])[0]
	var uid:=int(building.uid)
	battle.gold=1000000; battle.wood=1000000; battle.food=1000000; battle.stone=1000000
	battle.selected=[building]
	assert(battle.commands.economy._queue_train(battle.player_owner,building,30))
	battle.view.update_panel()
	assert(_values(reader.training_views()) and _values(reader.building_work(uid)))
	assert(reader.training_views()[0].buildingUid==uid and reader.building_work(uid).busy)
	var action: Callable=battle.view.cmd_capsules[0].act
	var snapshot: Dictionary=game.snapshot(battle.units,battle.commands.world._resources(),battle.saver.save_extra())
	var transaction=load("res://app/saves/world_transaction.gd")
	var old_epoch: int=battle.world.get_instance_id()
	var old_world: WeakRef=weakref(battle.world)
	var old_state: WeakRef=weakref(battle.state)
	var retained: Array=reader.unit_views()
	transaction.force_view_failure_after_attach=true
	assert(not battle.saver.apply_snapshot(snapshot))
	transaction.force_view_failure_after_attach=false
	assert(battle.world.get_instance_id()==old_epoch and reader.unit_views()[0].world_id==old_epoch)
	assert(battle.saver.apply_snapshot(snapshot))
	assert(old_world.get_ref()==null and old_state.get_ref()==null)
	assert(is_same(reader,battle.view.host) and reader.unit_views()[0].world_id!=old_epoch and _values(retained))
	# A retained UI callback has the same UID but an obsolete world identity.
	action.call()
	assert(battle.player_commands.pump()==0 and battle.trainings.size()==1)
	battle.selected=[battle.units.filter(func(unit):return int(unit.uid)==uid)[0]]
	battle.view.update_panel()
	(battle.view.cmd_capsules[0].act as Callable).call()
	assert(battle.player_commands.pump()==1 and battle.trainings.is_empty())

func _values(value) -> bool:
	if value is Array:
		if not value.is_read_only(): return false
		for child in value:
			if not _values(child): return false
		return true
	if value is Dictionary:
		if not value.is_read_only(): return false
		for child in value.values():
			if not _values(child): return false
		return true
	return typeof(value) in [TYPE_NIL,TYPE_BOOL,TYPE_INT,TYPE_FLOAT,TYPE_STRING,TYPE_VECTOR2,TYPE_VECTOR2I]
