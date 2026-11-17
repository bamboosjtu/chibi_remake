extends SceneTree
func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	var game: Node=root.get_node("Game")
	var battle=load("res://main.tscn").instantiate();root.add_child(battle);battle.set_process(false)
	var current: Dictionary=game.snapshot(battle.units,battle.commands.world._resources(),battle.saver.save_extra())
	assert(int(current.v)==9 and game.is_valid_save(current))
	assert(not battle.saver.has_method("restore_legacy") and not preload("res://app/saves/rules_identity.gd").new().has_method("approved_migration"))
	var identity: int=battle.state.get_instance_id()
	var before: String=game.save_checksum(battle.saver.continuation_snapshot(game))
	var stock_presence: Dictionary={}
	for unit in battle.units: stock_presence[int(unit.uid)] = unit.has("stock")
	for version in range(1,9):
		var retired: Dictionary=current.duplicate(true);retired.v=version
		retired.erase("checksum");retired.checksum=game.save_checksum(retired)
		assert(not game.is_valid_save(retired) and not game.can_rotate_save(retired))
		assert(not battle.saver.apply_snapshot(retired))
		assert(battle.state.get_instance_id()==identity and game.save_checksum(battle.saver.continuation_snapshot(game))==before)
	for field in ["rulesRevision","contentRevision"]:
		var invalid: Dictionary=current.duplicate(true);invalid.simulation[field]="retired-or-unknown"
		assert(not battle.saver.apply_snapshot(invalid))
		invalid.simulation.erase(field);assert(not battle.saver.apply_snapshot(invalid))
	var unverified: Dictionary=current.duplicate(true);unverified.erase("checksum")
	assert(not game.is_valid_save(unverified))
	assert(battle.commands.world._spawn_unit(32,battle.player_owner,1500,1500,true))
	assert(battle.saver.apply_snapshot(current))
	for unit in battle.units: assert(unit.has("stock")==stock_presence[int(unit.uid)],"Optional resource capability must preserve presence")
	assert(game.save_checksum(battle.saver.continuation_snapshot(game))==before)
	battle.scene.ready_to_save=false;battle.free()
	print("CURRENT FORMAT PASS v9 only / retired versions rejected / exact rule and map identity / checksum required / isolated replacement")
	quit()
