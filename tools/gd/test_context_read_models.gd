extends SceneTree
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
	var target: Dictionary=battle.units.filter(func(unit):return int(unit.owner)!=battle.player_owner and unit.alive)[0]
	var mask: Dictionary=reader.queries.map.visibility_view()
	var clock: Dictionary=reader.queries.status.clock_view()
	var options: Array=reader.queries.commands.build_options()
	assert(_values(mask) and _values(clock) and _values(options))
	var current: PackedByteArray=reader.queries.map.visibility_planes(mask.key).current
	var first: int=battle.visibility.current[0]
	current[0]=1-first
	assert(battle.visibility.current[0]==first)
	assert(reader.queries.map.visibility_planes(mask.key).current[0]==first)
	var detached: Dictionary=clock.duplicate(true);detached.labels[0]="changed";detached.speed_index=0
	assert(battle.clock.LABELS[0]!="changed" and battle.clock.speed_index==clock.speed_index)
	var counters: Dictionary=reader.queries.projection_counters()
	for frame in range(3):
		await process_frame
		for repeat in range(20):
			assert(is_same(mask,reader.queries.map.visibility_view()) and is_same(clock,reader.queries.status.clock_view()) and is_same(options,reader.queries.commands.build_options()))
	var after: Dictionary=reader.queries.projection_counters()
	assert(after.visibilityBuilds==counters.visibilityBuilds and after.clockBuilds==counters.clockBuilds and after.optionBuilds==counters.optionBuilds)
	battle.clock.set_speed(0)
	assert(reader.queries.status.clock_view().speed_index==0 and clock.speed_index==2)
	var gold: float=battle.build_types[0].get("gold",0)
	battle.build_types[0].gold=gold+1
	assert(reader.queries.commands.build_options()[0].gold==gold+1 and options[0].get("gold",0)==gold)
	battle.build_types[0].gold=gold
	battle.visibility.set_full_reveal(true)
	assert(not is_same(mask,reader.queries.map.visibility_view()))
	assert(battle.projectiles.launch(actor,target,"arrow"))
	assert(battle.fire_fields.ignite(Vector2(actor.ax,actor.ay)))
	var effects: Dictionary=reader.queries.status.effect_views()
	assert(_values(effects) and effects.projectiles.size()==1 and effects.fires.size()==1)
	assert(is_same(effects,reader.queries.status.effect_views()))
	var point: Vector2=effects.projectiles[0].point
	battle.projectiles.step();battle.fire_fields.step()
	var changed: Dictionary=reader.queries.status.effect_views()
	assert(not is_same(effects,changed) and changed.projectiles[0].point!=point and effects.fires[0].age==0 and changed.fires[0].age==1)
	battle.task_events.append({"id":123,"tick":0})
	assert(reader.queries.status.event_count()==1 and reader.queries.status.task_event_id(0)==123 and reader.queries.status.task_event_id(1)==-1)
	battle.terrain_changes["region/1/2"]=1
	assert(reader.queries.map.terrain_has_changes(["region/1/2"]) and not reader.queries.map.terrain_has_changes(["missing"]))
	_worlds(game,battle,reader)
	var world: WeakRef=weakref(battle.world);var vision: WeakRef=weakref(battle.visibility)
	battle.scene.ready_to_save=false;battle.free()
	assert(world.get_ref()==null and vision.get_ref()==null and _values(mask) and _values(effects))
	print("CONTEXT READ MODELS PASS frozen service values / mask buffer isolation / paused cache reuse / manual effects invalidation / queued command epochs / rollback and world exchange / old services released")
	done=true;quit()

func _worlds(game: Node, battle: Node2D, reader: Node2D) -> void:
	assert(reader.actions.submit_command("watch")>0)
	var retired_queue = battle.player_commands
	var retained: Dictionary = retired_queue.pending_commands()[0]
	var snapshot: Dictionary=game.snapshot(battle.units,battle.world.economy.player_resources(),battle.saver.save_extra())
	var before: Dictionary=reader.queries.map.visibility_view()
	var old_world: WeakRef=weakref(battle.world)
	var old_vision: WeakRef=weakref(battle.visibility)
	var old_clock: WeakRef=weakref(battle.clock)
	var transaction=load("res://app/saves/world_transaction.gd")
	transaction.force_view_failure_after_attach=true
	assert(not battle.saver.apply_snapshot(snapshot));transaction.force_view_failure_after_attach=false
	assert(reader.queries.map.visibility_view().key==before.key)
	assert(retired_queue.pending_commands() == [retained])
	assert(battle.saver.apply_snapshot(snapshot))
	battle.visibility.revision=int(before.key[2])
	var replacement: Dictionary=reader.queries.map.visibility_view()
	assert(replacement.key[0]!=before.key[0] and replacement.key[1]!=before.key[1] and replacement.key[2]==before.key[2])
	assert(not is_same(before,replacement) and is_same(reader,battle.view.host))
	assert(retained.world_id != battle.world.get_instance_id())
	assert(not retired_queue.has_pending() and not battle.player_commands.has_pending())
	assert(retired_queue.submit("stop", battle.selected) == 0)
	assert(old_world.get_ref()==null and old_vision.get_ref()==null and old_clock.get_ref()==null)

func _values(value) -> bool:
	if value is Array:
		if not value.is_read_only():return false
		for child in value:
			if not _values(child):return false
		return true
	if value is Dictionary:
		if not value.is_read_only():return false
		for child in value.values():
			if not _values(child):return false
		return true
	return typeof(value) in [TYPE_BOOL,TYPE_INT,TYPE_FLOAT,TYPE_STRING,TYPE_VECTOR2,TYPE_VECTOR2I]
