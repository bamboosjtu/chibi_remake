extends SceneTree
var done := false
var battle: Node2D
var layer: Node2D
var reader: Node2D
var game: Node
var viewport := Rect2(300,40,500,200)

func _initialize() -> void:
	create_timer(150).timeout.connect(func():
		if not done: quit(1))
	run.call_deferred()

func run() -> void:
	game=root.get_node("Game"); game.current_map="chibil1"
	battle=load("res://main.tscn").instantiate(); root.add_child(battle)
	battle.set_process(false); battle.cli_mode=true; battle.ai=null
	for unit in battle.units: battle.world.command_groups._cancel_unit_command(unit); unit.hold=true
	layer=battle.view.resource_layer; layer.set_process(false); reader=battle.view.host
	var definition: Dictionary = battle.map_data.duplicate(true)
	definition.decor=[[10,10,0],[12,10,2],[14,10,4],[45,45,0]]
	battle.map_data=definition
	battle.world.harvest_orders._build_decor_targets()
	layer.update_visible(viewport)
	assert(layer.projection.size()==3 and layer.active.size()==3)
	assert(layer.get_property_list().all(func(property): return str(property.name)!="entries"))
	assert(reader.queries.get_property_list().all(func(property): return str(property.name)!="decor_cells"))
	var retained: Array = layer.projection
	assert(_frozen_values_only(retained) and _frozen_values_only(layer.signature))
	for descriptor in retained:
		var keys: Array = descriptor.keys(); keys.sort()
		assert(keys==["anchor","index","phase"])
	var copy: Array = retained.duplicate(true); copy[0].phase=99; copy.clear()
	assert(layer.projection[0].phase==0 and battle.decor_cells["10_10"].phase==0)
	var before: String = game.save_checksum(battle.saver.continuation_snapshot(game))
	var builds: int = layer.projection_builds
	for frame in range(3):
		await process_frame
		for repeat in range(20): layer.update_visible(viewport)
	assert(layer.projection_builds==builds and is_same(layer.projection,retained))
	assert(game.save_checksum(battle.saver.continuation_snapshot(game))==before)
	_viewport_and_geometry()
	var healthy: Dictionary = game.snapshot(battle.units,battle.world.economy.player_resources(),battle.saver.save_extra())
	_phases()
	_manual_exchange_and_rollback()
	_transaction_rollback(healthy)
	_restore_new_world(healthy)
	battle.scene.ready_to_save=false
	var state: WeakRef = weakref(battle.state)
	battle.free()
	assert(state.get_ref()==null and _frozen_values_only(retained))
	print("RESOURCE READ MODEL PASS frozen visible descriptors / paused cache / phases / viewport / geometry / exchange and rollback / released worlds")
	done=true; quit()

func _viewport_and_geometry() -> void:
	var builds: int = layer.projection_builds
	var other := Rect2(1800,430,500,200)
	layer.update_visible(other)
	assert(layer.projection.size()==1 and layer.projection[0].index==3 and layer.active.size()==1)
	layer.update_visible(Rect2(-500,-500,10,10))
	assert(layer.projection.is_empty() and layer.active.is_empty())
	layer.update_visible(viewport)
	assert(layer.projection_builds==builds+3 and layer.active.size()==3)
	var sprite: Sprite2D = layer.active[0]
	var position: Vector2 = sprite.position
	var height: float = battle.nav.tile_hh
	battle.nav.tile_hh=height+1
	layer.update_visible(viewport)
	assert(is_same(sprite,layer.active[0]) and sprite.position!=position, "Same-phase sprites must follow new geometry")
	battle.nav.tile_hh=height; layer.update_visible(viewport)
	assert(layer.active[0].position==position)
	var cached: Array = layer.projection
	builds=layer.projection_builds
	battle.nav.block(Vector2i(1,1)); layer.update_visible(viewport)
	assert(layer.projection_builds==builds and is_same(cached,layer.projection), "Unrelated blocker revisions do not change resource visuals")
	battle.nav.unblock(Vector2i(1,1))

func _phases() -> void:
	var cached: Array = layer.projection
	var source: Dictionary = battle.decor_cells["10_10"]
	source.stock-=1 # Partial extraction does not change the visual phase/version.
	layer.update_visible(viewport)
	assert(is_same(cached,layer.projection))
	for fixture in [["10_10",0,1],["12_10",1,3],["14_10",2,5]]:
		var old: WeakRef = weakref(layer.active[int(fixture[1])])
		var revision: int = battle.resource_revision
		battle.world.harvest_orders._remove_decor(battle.decor_cells[fixture[0]])
		assert(battle.resource_revision>revision)
		layer.update_visible(viewport)
		assert(layer.projection[int(fixture[1])].phase==int(fixture[2]) and old.get_ref()==null)
		if int(fixture[2])==5:
			assert(not layer.active.has(2), "Empty ore phase is intentionally skipped by the atlas")
		else:
			assert(layer.active[int(fixture[1])].get_meta("phase")==int(fixture[2]))
	assert(cached[0].phase==0 and cached[1].phase==2 and cached[2].phase==4)

func _manual_exchange_and_rollback() -> void:
	var snapshot: Dictionary = game.snapshot(battle.units,battle.world.economy.player_resources(),battle.saver.save_extra())
	snapshot.simulation.decorResources["10_10"].stock=200
	var validator = load("res://app/saves/snapshot_validator.gd").new(battle,battle.saver.content_revision,battle.saver._valid_cost,battle.saver._valid_integer)
	var plan: Dictionary = validator.prepare(snapshot,snapshot.units); assert(not plan.is_empty())
	var candidate = load("res://app/saves/candidate_world.gd").new()
	assert(candidate.prepare(battle.world,battle.world.definition) and candidate.saver.restore_candidate(snapshot,snapshot.units,plan))
	var old_key: Array = layer.signature
	candidate.state.resource_revision=int(old_key[2]); candidate.world.nav.geometry_revision=int(old_key[3])
	var previous: RefCounted = battle.exchange_world(candidate.world)
	var key: Array = reader.queries.map.resource_layer_key(viewport)
	assert(key.slice(2)==old_key.slice(2) and key[0]!=old_key[0] and key[1]!=old_key[1])
	layer.update_visible(viewport)
	var rejected_projection: Array = layer.projection
	assert(rejected_projection[0].phase==0 and layer.active[0].get_meta("phase")==0)
	var rejected_world: WeakRef = weakref(candidate.world)
	var rejected_nav: WeakRef = weakref(candidate.world.nav)
	var discarded: RefCounted = battle.exchange_world(previous)
	previous=null
	layer.update_visible(viewport)
	assert(layer.projection[0].phase==1 and layer.active[0].get_meta("phase")==1)
	candidate.dispose(); candidate=null; discarded=null
	assert(rejected_world.get_ref()==null and rejected_nav.get_ref()==null and _frozen_values_only(rejected_projection))

func _transaction_rollback(snapshot: Dictionary) -> void:
	var transaction = load("res://app/saves/world_transaction.gd")
	var model: Array = layer.projection
	var state_id: int = battle.state.get_instance_id()
	var before: String = game.save_checksum(battle.saver.continuation_snapshot(game))
	transaction.force_view_failure_after_attach=true
	assert(not battle.saver.apply_snapshot(snapshot))
	transaction.force_view_failure_after_attach=false
	layer.update_visible(viewport)
	assert(battle.state.get_instance_id()==state_id and is_same(model,layer.projection))
	assert(game.save_checksum(battle.saver.continuation_snapshot(game))==before)

func _restore_new_world(snapshot: Dictionary) -> void:
	var original: Vector2 = layer.projection[0].anchor
	battle.map_data.decor[0][0]+=1; battle.resource_revision+=1
	layer.update_visible(viewport)
	assert(layer.projection[0].anchor!=original, "Fixture changes the old map's decor array")
	assert(layer.projection[0].phase==0)
	var sprite_id: int = layer.active[0].get_instance_id()
	var old_position: Vector2 = layer.active[0].position
	var retained: Array = layer.projection
	var old_key: Array = layer.signature
	var old_world: WeakRef = weakref(battle.world)
	var old_nav: WeakRef = weakref(battle.nav)
	var builds: int = layer.projection_builds
	assert(battle.saver.apply_snapshot(snapshot))
	battle.resource_revision=int(old_key[2]); battle.nav.geometry_revision=int(old_key[3])
	var key: Array = reader.queries.map.resource_layer_key(viewport)
	assert(key.slice(2)==old_key.slice(2) and key[0]!=old_key[0] and key[1]!=old_key[1])
	layer.update_visible(viewport)
	assert(layer.projection_builds==builds+1 and not is_same(layer.projection,retained))
	assert(layer.projection[0].anchor==original and layer.projection[0].phase==0 and layer.active.size()==3)
	assert(layer.active[0].get_instance_id()==sprite_id and layer.active[0].position!=old_position, "Same-phase sprites must be repositioned across worlds")
	assert(is_same(reader,battle.view.host) and old_world.get_ref()==null and old_nav.get_ref()==null)
	assert(_frozen_values_only(retained) and _frozen_values_only(layer.projection))

func _frozen_values_only(value) -> bool:
	if value is Array:
		if not value.is_read_only(): return false
		for child in value:
			if not _frozen_values_only(child): return false
		return true
	if value is Dictionary:
		if not value.is_read_only(): return false
		for child in value.values():
			if not _frozen_values_only(child): return false
		return true
	return typeof(value) in [TYPE_INT,TYPE_VECTOR2,TYPE_RECT2]
