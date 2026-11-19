extends SceneTree
const LevelCatalog = preload("res://app/level_catalog.gd")
const Campaign = preload("res://app/campaign_session.gd")
const Storage = preload("res://app/user_storage.gd")
func _initialize() -> void: run.call_deferred()
func run() -> void:
	_catalog_and_transitions()
	_paths()
	_snapshot()
	print("APP BOUNDARIES PASS indexed catalog once / frozen metadata / failed and successful navigation / error preservation / portable normalization / read-only canonical transport snapshot")
	quit()

func _catalog_and_transitions() -> void:
	var raw: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/db/level_index.json"))
	var reads := [0]
	var catalog := LevelCatalog.new(func(): reads[0] += 1; return raw)
	var rows := catalog.levels(); var name: String = rows[0].name
	raw.levels[0].name = "changed source"
	for repeat in range(50):
		assert(is_same(rows,catalog.levels()) and catalog.next_level("chibil7a").map == "chibil7b")
	assert(reads[0] == 1 and rows.is_read_only() and rows[0].is_read_only() and rows[0].name == name)
	var broken := LevelCatalog.new(func(): return {"levels":[]})
	assert(not broken.initialize().is_empty() and broken.levels().is_read_only() and broken.read_count == 1)
	var campaign := Campaign.new(); campaign.catalog = catalog
	campaign.current_map = "chibil1"; campaign.pending_load = true; campaign.pending_load_slot = 7; campaign.last_load_error = "prior error"
	var invoked := [0]
	var failure := func():
		invoked[0] += 1
		assert(campaign.current_map == "chibil2" and campaign.pending_load_slot == 3)
		return ERR_CANT_CREATE
	assert(campaign.transition("chibil2",failure,3) == ERR_CANT_CREATE)
	assert(invoked[0] == 1 and campaign.current_map == "chibil1" and campaign.pending_load and campaign.pending_load_slot == 7 and campaign.last_load_error == "prior error")
	assert(campaign.transition("unknown",failure) == ERR_INVALID_PARAMETER and invoked[0] == 1)
	assert(campaign.transition("chibil2",func(): return OK) == OK)
	assert(campaign.current_map == "chibil2" and not campaign.pending_load and campaign.pending_load_slot == 0)
	campaign.pending_load = true; campaign.pending_load_slot = 2; campaign.last_load_error = "load failure"
	assert(campaign.leave(func(): return ERR_CANT_CREATE) == ERR_CANT_CREATE and campaign.pending_load_slot == 2)
	assert(campaign.leave(func(): return OK) == OK and not campaign.pending_load and campaign.last_load_error == "load failure")

func _paths() -> void:
	for value in ["", "../saves", "child/../saves", "C:", "C:/", "C:relative", "//server/share", "res://data", "user://saves", "C:/file:stream", "bad?path"]:
		assert(not Storage.resolve_portable_root(value,"C:/game").valid,value)
	assert(Storage.resolve_portable_root("userdata/./saves/","C:/game").root == "C:/game/userdata/saves")
	assert(Storage.resolve_portable_root("D:\\private\\saves","C:/game").root == "D:/private/saves")
	assert(Storage.resolve_portable_root("/tmp/saves","/opt/game").root == "/tmp/saves")
	assert(Storage.resolve_portable_root("saves","/opt/game").root == "/opt/game/saves")

func _snapshot() -> void:
	var game: Node = root.get_node("Game"); game.current_map = "chibic1"
	var battle: Node2D = load("res://main.tscn").instantiate(); root.add_child(battle); battle.set_process(false)
	var source: Dictionary = battle.units.filter(func(u): return int(u.unit) == 30)[0]
	var ship: Dictionary = source.duplicate(true); ship.uid = 1000; ship.unit = 47
	ship.carry_n = 99; ship.carry_hp = 999.; ship.loaded = false; ship.group_officer = -1
	var passenger: Dictionary = source.duplicate(true); passenger.uid = 1001
	passenger.attached = true; passenger.aboard_uid = 1000; passenger.hp = 200.; passenger.state = "boarded"
	var corpse: Dictionary = passenger.duplicate(true); corpse.uid = 1002; corpse.die_t = 0.; corpse.state = "dead"
	battle.units = [ship,passenger,corpse]; battle.next_uid = 1003; battle.selected = []
	var before: Array = battle.units.duplicate(true)
	var extra: Dictionary = battle.saver.save_extra()
	assert(battle.units == before,"Preparing save extras is a query")
	var saved: Dictionary = game.snapshot(battle.units,battle.world.economy.player_resources(),extra)
	assert(battle.units == before,"Canonical serialization cannot repair the live world")
	var fields: Dictionary = saved.units[0].simulation
	assert(fields.carry_n == 1 and fields.carry_hp == 200. and fields.loaded)
	assert(saved.units[2].simulation.aboard_uid == -1 and corpse.aboard_uid == 1000)
	assert(game.is_valid_save(saved),"The projected manifest remains a valid current archive")
	battle.scene.ready_to_save = false; battle.free()
