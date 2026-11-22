extends SceneTree
var done := false
func _initialize() -> void:
	create_timer(90).timeout.connect(func():
		if not done: quit(1))
	run.call_deferred()

func run() -> void:
	var game: Node = root.get_node("Game")
	var battle = load("res://main.tscn").instantiate(); root.add_child(battle); battle.set_process(false)
	var last: Dictionary = battle.units.back()
	battle.selected=[last]
	var ids: Array = battle.units.map(func(unit): return int(unit.uid))
	var cells: Dictionary = battle.state._cell_index_cells.duplicate(true)
	var occupancy: Dictionary = battle.nav.state.occupancy.duplicate()
	var before: String = game.save_checksum(battle.saver.continuation_snapshot(game))
	for index in [-1,-battle.units.size()-1,battle.units.size(),2147483647]:
		battle.world.battle_simulation._free_unit_at(index)
		assert(battle.units.map(func(unit): return int(unit.uid))==ids and is_same(battle.selected[0],last))
		assert(battle.state._cell_index_cells==cells and battle.nav.state.occupancy==occupancy)
		assert(game.save_checksum(battle.saver.continuation_snapshot(game))==before)
	var leader: Dictionary = battle.units.filter(func(unit): return int(unit.owner)==battle.player_owner and not unit.officer.is_empty())[0]
	var clone: Dictionary = leader.duplicate(true)
	battle.selected=[clone]
	assert(battle.world.officer_teams._order_disband()==0, "An equal dictionary is not a world member")
	assert(leader.alive and game.save_checksum(battle.saver.continuation_snapshot(game))==before)
	var count: int = battle.units.size()
	var position: int = battle.units.find_custom(func(unit): return is_same(unit,leader))
	battle.world.battle_simulation._free_unit_at(position)
	assert(battle.units.size()==count-1)
	before=game.save_checksum(battle.saver.continuation_snapshot(game))
	battle.selected=[leader]
	assert(battle.world.officer_teams._order_disband()==0, "Already-removed leader must not delete another entity")
	assert(battle.units.size()==count-1 and game.save_checksum(battle.saver.continuation_snapshot(game))==before)
	battle.scene.ready_to_save=false; battle.free()
	print("INVALID UNIT REMOVAL PASS negative/high indices atomic / clone rejected / removed target harmless")
	done=true; quit()
