extends SceneTree
class CountingGame extends "res://app/game.gd":
	var reads := 0
	func load_save(slot := 0) -> Dictionary:
		reads += 1
		return super.load_save(slot)
func _initialize() -> void:
	run.call_deferred()
func run() -> void:
	var game := CountingGame.new()
	game.SAVE_PATH = OS.get_environment("LOCALAPPDATA").path_join("metadata-fixture/save.json")
	var store = preload("res://app/json_store.gd")
	assert(store.commit(game.save_slot_path(20),'{"v":7,"map":"chibil1","saveName":"first"}',game.verify_save_checksum))
	assert(game.has_save())
	var initial := game.reads
	assert(initial == 21)
	for i in range(10): assert(game.has_save())
	game.save_slots()
	assert(game.reads == initial,"Unchanged slots must not be parsed/hashed again")
	assert(store.commit(game.save_slot_path(20),'{"v":7,"map":"chibil1","saveName":"externally changed longer title"}',game.verify_save_checksum))
	assert(game.save_slots()[20].name == "externally changed longer title" and game.reads == initial+1)
	var broken := FileAccess.open(game.save_slot_path(20),FileAccess.WRITE); broken.store_string("broken"); broken.close()
	assert(game.has_save() and game.save_slots()[20].name == "first","Backup fallback must invalidate metadata")
	broken = FileAccess.open(game.save_slot_path(20)+".bak",FileAccess.WRITE); broken.store_string("also broken"); broken.close()
	assert(not game.has_save())
	game.free()
	print("SLOT METADATA PASS no repeat JSON/hash work / external replacement / backup fallback / corruption invalidation")
	quit()
