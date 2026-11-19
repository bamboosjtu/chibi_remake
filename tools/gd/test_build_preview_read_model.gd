extends SceneTree
var done := false
var battle: Node2D
var game: Node

func _initialize() -> void:
	create_timer(120).timeout.connect(func():
		if not done: quit(1))
	run.call_deferred()

func run() -> void:
	game=root.get_node("Game"); game.current_map="chibil1"
	battle=load("res://main.tscn").instantiate(); root.add_child(battle)
	battle.set_process(false); battle.cli_mode=true; battle.ai=null
	for unit in battle.units: battle.world.command_groups._cancel_unit_command(unit); unit.hold=true
	var captain: Dictionary = battle.selected[0]
	var uid := int(captain.uid)
	var option: Dictionary = battle.build_types.filter(func(value): return int(value.unit)==10)[0]
	var point := _valid_point(captain,option)
	var preview: Node2D = battle.view.construction_preview; preview.set_process(false)
	var reader: Node2D = battle.view.host
	battle.world.command_groups._cmd_begin("build",option)
	var before: String = game.save_checksum(battle.saver.continuation_snapshot(game))
	preview.update_at(point)
	var model: Dictionary = preview.placement
	assert(model.valid and model.is_read_only() and model.cells.is_read_only() and model.cell_polygons.is_read_only())
	var keys := model.keys(); keys.sort()
	assert(keys==["anchor","cell_polygons","cells","outline","reason","sprite_k","unit","unit_size","valid"])
	assert(_frozen_values_only(model) and _frozen_values_only(preview.signature))
	_isolated_values(model)
	var builds: int = preview.projection_builds
	for frame in range(3):
		await process_frame
		for repeat in range(20): preview.update_at(point)
	assert(preview.projection_builds==builds and is_same(preview.placement,model), "Unchanged paused frames must reuse the bounded projection")
	assert(game.save_checksum(battle.saver.continuation_snapshot(game))==before, "Read queries must not change persisted simulation")
	_invalidations(preview,point,captain)
	_world_exchange(preview,reader,point,uid,option)
	battle.scene.ready_to_save=false
	var state: WeakRef = weakref(battle.state)
	battle.free()
	assert(state.get_ref()==null and _frozen_values_only(model), "Retained projections must not retain closed worlds")
	print("BUILD PREVIEW READ MODEL PASS frozen bounded values / paused cache reuse / invalidation / rollback / replacement-world collision / lifecycle")
	done=true; quit()

func _valid_point(captain: Dictionary, option: Dictionary) -> Vector2:
	var origin: Vector2i = battle.world.spatial_index._unit_cell(captain)
	for radius in range(3,20):
		for dx in range(-radius,radius+1):
			for dy in range(-radius,radius+1):
				if maxi(absi(dx),absi(dy))!=radius: continue
				var point: Vector2 = battle.nav.anchor_of(origin.x+dx,origin.y+dy)
				if battle.world.construction_orders.build_placement_at(point,option).valid: return point
	assert(false,"Fixture needs reachable placement")
	return Vector2.ZERO

func _isolated_values(model: Dictionary) -> void:
	var first: Vector2 = model.outline[0]
	assert(model.outline.is_read_only() and model.cell_polygons[0].is_read_only())
	var outline: Array = model.outline.duplicate(); outline[0]+=Vector2(99,99)
	assert(model.outline[0]==first)
	var polygon: Array = model.cell_polygons[0].duplicate()
	var corner: Vector2 = polygon[0]; polygon[0]+=Vector2(77,77)
	assert(model.cell_polygons[0][0]==corner)
	var copy := model.duplicate(true); copy.cells.clear(); copy.reason="mutated"
	assert(not model.cells.is_empty() and model.reason!="mutated")
	var size: Vector2 = model.unit_size; size.x+=100
	assert(model.unit_size.x!=size.x)

func _invalidations(preview: Node2D, point: Vector2, captain: Dictionary) -> void:
	var gold: float = battle.gold
	var builds: int = preview.projection_builds
	battle.gold=0; preview.update_at(point)
	assert(not preview.placement.valid and preview.projection_builds==builds+1)
	battle.gold=gold; battle.selected=[]; preview.update_at(point)
	assert(not preview.placement.valid)
	battle.selected=[captain]; preview.update_at(point); assert(preview.placement.valid)
	var height: float = battle.nav.tile_hh
	builds=preview.projection_builds
	battle.nav.tile_hh=height+1; preview.update_at(point)
	assert(preview.projection_builds==builds+1)
	battle.nav.tile_hh=height; preview.update_at(point)
	preview.update_at(point,false)
	assert(not preview.visible and preview.placement.is_empty())
	preview.update_at(point); assert(preview.visible)

func _world_exchange(preview: Node2D, reader: Node2D, point: Vector2, uid: int, option: Dictionary) -> void:
	var snapshot: Dictionary = game.snapshot(battle.units,battle.world.economy.player_resources(),battle.saver.save_extra())
	var transaction = load("res://app/saves/world_transaction.gd")
	var model: Dictionary = preview.placement
	var state_id: int = battle.state.get_instance_id()
	transaction.force_view_failure_after_attach=true
	assert(not battle.saver.apply_snapshot(snapshot))
	transaction.force_view_failure_after_attach=false
	preview.update_at(point)
	assert(battle.state.get_instance_id()==state_id and is_same(preview.placement,model), "Rollback must keep the live read model")
	var original_bounds: Vector2 = reader.queries.camera_bounds()
	battle.map_data.terrainW+=100
	assert(reader.queries.camera_bounds().x==original_bounds.x+100)
	var old_world: WeakRef = weakref(battle.world)
	var old_nav: WeakRef = weakref(battle.nav)
	var old_key: Array = preview.signature
	var builds: int = preview.projection_builds
	assert(battle.saver.apply_snapshot(snapshot))
	assert(old_world.get_ref()==null and old_nav.get_ref()==null)
	assert(is_same(reader,battle.view.host) and reader.queries.camera_bounds()==original_bounds)
	# Re-arm before any inactive preview frame, and force every non-identity key equal.
	battle.selected=[battle.units.filter(func(unit): return int(unit.uid)==uid)[0]]
	battle.world.command_groups._cmd_begin("build",option)
	battle.nav.version=int(old_key[5])
	var key: Array = reader.queries.construction_preview_key(point)
	assert(key.slice(2)==old_key.slice(2) and key[0]!=old_key[0] and key[1]!=old_key[1])
	preview.update_at(point)
	assert(preview.projection_builds==builds+1 and not is_same(preview.placement,model))
	assert(preview.placement.valid and _frozen_values_only(preview.placement))
	battle.world.world_orders._clear_pending(); preview.update_at(point)
	assert(not preview.visible and preview.placement.is_empty())

func _frozen_values_only(value) -> bool:
	if value is Dictionary:
		if not value.is_read_only(): return false
		for child in value.values():
			if not _frozen_values_only(child): return false
		return true
	if value is Array:
		if not value.is_read_only(): return false
		for child in value:
			if not _frozen_values_only(child): return false
		return true
	return typeof(value) in [TYPE_NIL,TYPE_BOOL,TYPE_INT,TYPE_FLOAT,TYPE_STRING,TYPE_VECTOR2,TYPE_VECTOR2I,TYPE_VECTOR3]
