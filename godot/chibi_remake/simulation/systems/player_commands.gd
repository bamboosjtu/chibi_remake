extends RefCounted
## Behavioral equivalent of the researched per-faction 64-slot task table.
## Eight named numeric fields are a remake protocol, not a claimed binary layout.
signal commands_applied
const CAPACITY := 64
const Access = preload("res://simulation/ports/player_commands_access.gd")
var host: Access
var queues := {}
var cursors := {}
var batches := {}
var sequence := 0
var executing := false
var history: Array = []

func _init(owner: Object) -> void: host = owner.simulation_access("player_commands") if owner.has_method("simulation_access") else owner

func submit(mode: int, action: Callable, target := Vector2.ZERO, target_uid := -1, parameter := 0) -> int:
	if executing:
		action.call(); return 0
	var actors: Array = host.selected.filter(func(u): return bool(u.get("alive",false)) and float(u.get("die_t",-1)) < 0 and int(u.owner)==int(host.player_owner))
	if mode in [5,10,11]:
		var leader:Dictionary=host.command_rules.selected_leader(actors)
		actors=[leader] if not leader.is_empty() else actors.slice(0,1)
	if actors.is_empty(): return 0
	sequence += 1
	var owner := int(host.player_owner)
	var queue: Array = queues.get(owner,[])
	var ids := []
	for unit in actors:
		if queue.size() >= CAPACITY: break
		var slot := int(cursors.get(owner,0))
		cursors[owner] = (slot+1)%CAPACITY
		var words := PackedInt64Array([owner,int(unit.uid),mode,roundi(target.x),roundi(target.y),target_uid,parameter,sequence])
		queue.append({"slot":slot,"words":words})
		ids.append(int(unit.uid))
	queues[owner] = queue
	if not ids.is_empty(): batches[sequence] = {"action":action,"uids":ids,"selection":host.selected.map(func(u):return int(u.uid)),"owner":owner,"pending":_pending()}
	if ids.size() < actors.size(): host._feedback("指令任务表已满，部分单位未接到指令")
	return ids.size()


func pump() -> int:
	if executing: return 0
	var ready: Dictionary = batches
	batches = {}
	for queue in queues.values():
		for entry in queue:
			history.append(entry.words)
		queue.clear()
	while history.size() > 128: history.pop_front()
	var count := 0
	executing = true
	for batch in ready.values():
		var selected_before: Array = host.selected.duplicate()
		var same_selection: bool = selected_before.map(func(u):return int(u.uid)) == batch.selection
		var actors: Array = []
		for uid in batch.uids:
			for unit in host.units:
				if int(unit.uid)==int(uid) and bool(unit.alive) and float(unit.die_t)<0 and int(unit.owner)==int(batch.owner): actors.append(unit);break
		if actors.is_empty(): continue
		var pending_before := _pending()
		var same_pending: bool = pending_before == batch.pending
		_restore_pending(batch.pending)
		host.selected = actors
		(batch.action as Callable).call()
		if not same_pending: _restore_pending(pending_before)
		# First-selected modes restrict execution, without shrinking the user's selection.
		var unchanged_actors: bool=host.selected.map(func(u):return int(u.uid)) == batch.uids
		if not same_selection or unchanged_actors: host.selected = selected_before.filter(func(u):return host.units.has(u) and bool(u.alive))
		count += 1
	executing = false
	if count > 0: commands_applied.emit()
	return count

func clear() -> void:
	queues.clear();batches.clear()

func _pending() -> Dictionary:
	return {"cmd":host.cmd_pending,"data":host.cmd_pending_data.duplicate(true),"jimou":host.jimou_pending,"caster":int(host.jimou_caster.get("uid",-1)),"duel":host.duel_pending}

func _restore_pending(value: Dictionary) -> void:
	host.cmd_pending=value.cmd;host.cmd_pending_data=value.data.duplicate(true)
	host.jimou_pending=value.jimou;host.duel_pending=value.duel;host.jimou_caster={}
	for unit in host.units:
		if int(unit.uid)==int(value.caster):host.jimou_caster=unit;break

var processing := true

func set_process(enabled: bool) -> void:
	processing = enabled

func is_processing() -> bool:
	return processing
