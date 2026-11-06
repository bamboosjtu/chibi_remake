extends SceneTree
func _initialize() -> void:run.call_deferred()
func run() -> void:
	var game:Node=root.get_node("Game")
	var unit_rules = preload("res://simulation/systems/unit_rules.gd")
	var catalog = JSON.parse_string(FileAccess.get_file_as_string("res://data/db/unit_definitions.json"))
	assert(unit_rules.valid_catalog(catalog, true))
	var malformed: Dictionary = catalog.duplicate(true)
	malformed.units["30"].hp = "invalid"
	assert(not unit_rules.valid_catalog(malformed, true))
	malformed = catalog.duplicate(true)
	malformed.units["30"].erase("category")
	assert(not unit_rules.valid_catalog(malformed, true))
	malformed = catalog.duplicate(true)
	malformed.units["30"].costs = [-1,0,0]
	assert(not unit_rules.valid_catalog(malformed, true))
	assert(game.verify_save_checksum({"v":7}))
	assert(not game.verify_save_checksum({"v":8}))
	game.current_map="chibil1"
	var b:Node=load("res://main.tscn").instantiate();root.add_child(b);b.set_process(false);b.cli_mode=true;b.ai=null
	b.view.event_view.restore_history()
	var visible:Dictionary=b.sec_visible.duplicate(true)
	b.control_groups.clear()
	for key in [KEY_1,KEY_2,KEY_3,KEY_4,KEY_5,KEY_6,KEY_7,KEY_8,KEY_9]:
		var event:=InputEventKey.new();event.keycode=key;event.pressed=true;b._unhandled_input(event)
	assert(b.sec_visible==visible)
	b.simulation_rng.randi()
	assert(game.save_game(b.units,b.commands.world._resources(),b.commands.session._save_extra()))
	var next:int=b.simulation_rng.randi()
	assert(b.saver.apply_snapshot(game.load_save()))
	assert(b.simulation_rng.randi()==next)
	var digest=preload("res://simulation/systems/state_digest.gd")
	var before:Dictionary=digest.sections(b, game);b.gold+=1
	var after:Dictionary=digest.sections(b, game)
	assert(before.world==after.world and before.economy!=after.economy and before.total!=after.total)
	var sample:AudioStreamWAV=b.sfx._load_wav("res://media/sfx/public-missing.wav")
	assert(sample!=null and sample.data.size()>1000)
	var music:AudioStreamWAV=preload("res://presentation/audio/generated_audio.gd").stream("public",true)
	assert(music.loop_mode==AudioStreamWAV.LOOP_FORWARD and music.get_length()>3.0)
	print("REVIEW CONTRACTS PASS empty groups / visibility / legacy checksum / v8 checksum / RNG continuity / economy digest / procedural audio")
	b.free();quit()
