extends RefCounted
const CommandState = preload("res://simulation/commands/command_state.gd")

var _waiters := 0
var waiting_for_commands: bool:
	get: return _waiters > 0
var _battle: Node

func _init(battle: Node) -> void:
	_battle = battle

static func save_slots() -> Array:
	return Game.save_slots()

static func damaged_files() -> Dictionary:
	return Game.repository.damaged_files()

static func remove_damaged_files(reviewed: PackedStringArray) -> int:
	return Game.repository.remove_damaged_files(reviewed)

func wait_command_boundary() -> bool:
	if not is_instance_valid(_battle) or not _battle.is_inside_tree(): return false
	var epoch: int = _battle.world.get_instance_id()
	_waiters += 1
	var tree := _battle.get_tree()
	while is_instance_valid(_battle) and epoch == _battle.world.get_instance_id() and _battle.world.player_commands.has_pending() and _battle.state.game_end == 0 and _battle.is_processing() and not tree.paused:
		await tree.process_frame
	_waiters -= 1
	return is_instance_valid(_battle) and epoch == _battle.world.get_instance_id()

func save_game(slot := 0, title := "") -> bool:
	if not _battle.scene.ready_to_save:
		Game.last_save_error = {"stage":"battle not initialized", "code":ERR_UNCONFIGURED}
		return false
	var unregistered := preload("res://simulation/state/battle_state_fields.gd").omissions(_battle.state)
	if not unregistered.is_empty():
		Game.last_save_error = {"stage":"snapshot world fields", "code":ERR_INVALID_DATA, "slot":slot, "fields":unregistered}
		return false
	if _battle.world.player_commands.has_pending():
		Game.last_save_error = {"stage":"指令尚未结算，请返回战场后重试", "code":ERR_BUSY, "slot":slot}
		return false
	var extra: Dictionary = _battle.scene.saver.save_extra()
	extra.saveName=title
	return Game.save_game(_battle.state.units,_battle.world.economy.player_resources(),extra,slot)

func load_slot(slot: int) -> Dictionary:
	var loaded: Dictionary = Game.repository.read_slot(slot)
	var data: Dictionary = loaded.data
	var map_id := str(data.get("map",""))
	if data.is_empty() or not Game.campaign.catalog.contains(map_id):
		return {"ok":false,"error":"所选进度无法读取，原有记录已保留。"}
	var cross_map := map_id != str(_battle.state.map_id)
	var selection: Array = _battle.state.selected.map(func(unit): return int(unit.uid))
	if not Game.campaign.restore_battle(map_id, _battle.scene.saver.apply_loaded.bind(loaded, cross_map)):
		return {"ok":false,"error":_battle.scene.saver.last_load_error}
	if not cross_map:
		for unit in _battle.state.units:
			if int(unit.uid) in selection: CommandState.add_selection(_battle.state, unit)
	return {"ok":true,"cross_map":cross_map,"source":_battle.scene.saver.last_load_source}

static func pause(owner: Node, reason: String) -> int:
	return Game.pauses.acquire(owner, reason)

static func resume(token: int) -> void:
	Game.pauses.release(token)

static func owns_pause(token: int) -> bool:
	return Game.pauses.is_top(token)

static func has_save() -> bool:
	return Game.has_save()

static func open_saved_battle(slot: int) -> Error:
	var entry: Dictionary = Game.slot_catalog.info(slot)
	if not entry.valid: return ERR_FILE_CORRUPT
	if not Game.campaign.catalog.contains(entry.map): return ERR_DOES_NOT_EXIST
	return Game.change_battle(entry.map, slot)
