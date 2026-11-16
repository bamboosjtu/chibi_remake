extends SceneTree
class Reads extends RefCounted:
	var count := 0
	var repository: RefCounted
	func load_slot(slot: int) -> Dictionary:
		count += 1
		return repository.load_slot(slot)

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	var game: Node = root.get_node("Game")
	var valid := func(data: Dictionary): return data.has("probe")
	var repository = load("res://app/saves/save_repository.gd").new(valid,valid)
	repository.path=game.SAVE_PATH.get_base_dir().path_join("services/save.json")
	repository.storage.pinned=true
	assert(repository.begin_save(2,0) and repository.commit(repository.slot_path(2),'{"probe":1,"saveName":"one"}'))
	var reads := Reads.new(); reads.repository=repository
	var catalog = load("res://app/saves/slot_catalog.gd").new(reads.load_slot,repository.slot_path,20)
	repository.changed.connect(catalog.invalidate)
	assert(catalog.has_save() and catalog.entries()[2].valid)
	var count := reads.count
	assert(catalog.has_save() and reads.count==count)
	var detached: Dictionary = catalog.info(2); detached.name="mutated"
	assert(catalog.info(2).name=="one")
	assert(repository.commit(repository.slot_path(2),'{"probe":1,"saveName":"two"}'))
	assert(catalog.info(2).name=="two", "Repository writes invalidate even same-size metadata")
	assert(not repository.begin_save(21,0) and not repository.last_error.is_empty())
	assert(not repository.begin_save(2,1) and repository.last_error.code==ERR_BUSY)
	repository.force_failure=true
	assert(not repository.begin_save(2,0) and repository.load_slot(2).probe==1)
	catalog.invalidate(); catalog.entries(); assert(reads.count>count)
	var campaign = load("res://app/campaign_session.gd").new()
	campaign.pending_load=true; campaign.pending_load_slot=9
	var next: Dictionary = campaign.next_level("chibil1")
	assert(not next.is_empty() and campaign.advance("chibil1"))
	assert(campaign.current_map==next.map and not campaign.pending_load and campaign.pending_load_slot==0)
	assert(campaign.list_levels().size()==34)
	assert(game.current_map=="chibic1", "An independent campaign service must not mutate the autoload")
	print("APP SERVICES PASS independent repository / injected slot reader / protected writes / independent campaign session")
	quit()
