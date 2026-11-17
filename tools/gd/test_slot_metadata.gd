extends SceneTree
class CountingReader extends RefCounted:
	var reads := 0
	var repository: RefCounted
	func read_slot(slot: int) -> Dictionary:
		reads += 1
		return repository.read_slot(slot)
func _initialize() -> void:
	run.call_deferred()
func run() -> void:
	var game=load("res://app/game.gd").new()
	var reader:=CountingReader.new();reader.repository=game.repository
	game.repository.changed.disconnect(game.slot_catalog.invalidate)
	game.slot_catalog=preload("res://app/saves/slot_catalog.gd").new(reader.read_slot,game.save_slot_path,game.SAVE_SLOTS)
	game.repository.changed.connect(game.slot_catalog.invalidate)
	game.SAVE_PATH = OS.get_environment("LOCALAPPDATA").path_join("metadata-fixture/save.json")
	var store = preload("res://app/json_store.gd")
	assert(store.commit(game.save_slot_path(20),fixture(game, "first"),game.is_valid_save))
	assert(game.has_save())
	var initial: int = reader.reads
	assert(initial == 21)
	for i in range(10): assert(game.has_save())
	game.save_slots()
	assert(reader.reads == initial,"Unchanged slots must not repeat JSON parsing or payload validation")
	assert(store.commit(game.save_slot_path(20),fixture(game, "externally changed longer title"),game.is_valid_save))
	assert(game.save_slots()[20].name == "externally changed longer title" and reader.reads == initial+1)
	var broken := FileAccess.open(game.save_slot_path(20),FileAccess.WRITE); broken.store_string("broken"); broken.close()
	assert(game.has_save() and game.save_slots()[20].name == "first","Backup fallback must invalidate metadata")
	broken = FileAccess.open(game.save_slot_path(20)+".bak",FileAccess.WRITE); broken.store_string("also broken"); broken.close()
	assert(not game.has_save())
	game.free()
	print("SLOT METADATA PASS no repeat JSON/validation work / external replacement / backup fallback / corruption invalidation")
	quit()

func fixture(game: Node, title: String) -> String:
	var data := {"v":3,"map":"chibil1","saveName":title,"units":[{"uid":0,"unit":32,"owner":2,"x":100,"y":100,"hp":100}]}
	data.checksum = game.save_checksum(data)
	return JSON.stringify(data)
