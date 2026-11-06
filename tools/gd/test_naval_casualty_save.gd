extends SceneTree
## A ready naval slot must remain loadable after losses, including before the next AI think.
var done := false
var battle: Node2D
var game: Node

func _initialize() -> void:
	create_timer(120).timeout.connect(func():
		if not done: quit(1))
	run.call_deferred()

func roundtrip(label: String) -> bool:
	if not game.save_game(battle.units, battle.commands._resources(), battle.commands._save_extra()):
		printerr("NAVAL CASUALTY FAIL save ", label); return false
	var payload: Dictionary=game.load_save()
	var ids: Dictionary={}
	for unit in payload.units: ids[int(unit.uid)]=unit
	print("NAVAL CASUALTY VALIDATION ",label," naval=",battle.ai.naval.valid_snapshot(payload.simulation.ai.navalSlots,ids,payload.trainings,payload.nextUid)," land=",battle.ai.slots.valid_snapshot(payload.simulation.ai.trainingSlots,ids,payload.trainings,payload.nextUid))
	if not battle.saver.apply_snapshot(payload):
		printerr("NAVAL CASUALTY FAIL load ", label); return false
	return true

func run() -> void:
	game=root.get_node("Game");game.current_map="chibic13"
	battle=load("res://main.tscn").instantiate();root.add_child(battle)
	battle.set_process(false);battle.cli_mode=true
	var owner: int=battle.commands.ai_owners()[0]
	var members: Array=[]
	for i in range(8):
		var centre:=Vector2i(-1,-1)
		for index in range(battle.map_data.waterWalkable.size()):
			if int(battle.map_data.waterWalkable[index])!=1:continue
			var cell:=Vector2i(index/int(battle.map_data.cols),index%int(battle.map_data.cols))
			if battle.commands._unit_placement_free(cell,46,1):
				centre=cell;break
		assert(centre.x>=0,"Naval fixture requires free water")
		var anchor: Vector2=battle.nav.anchor_of(centre.x,centre.y)
		assert(battle.commands._spawn_unit(46,owner,anchor.x,anchor.y))
		members.append(int(battle.units.back().uid))
	var rec: Dictionary=battle.ai.naval.record(owner,0)
	rec.members=members;rec.flagship=members[0];rec.ready=true
	if not roundtrip("full slot"):
		done=true;quit(1);return
	var victim: Dictionary=battle.units.filter(func(u):return int(u.uid)==int(members[0]))[0]
	battle.commands._kill(victim)
	battle.ai.naval.refresh(owner)
	if not roundtrip("seven survivors after flagship death"):
		done=true;quit(1);return
	rec=battle.ai.naval.record(owner,0)
	assert(rec.members.size()==7 and not rec.ready and rec.flagship==members[1])
	# Saving immediately after a second casualty must not serialize stale membership.
	victim=battle.units.filter(func(u):return int(u.uid)==int(members[1]))[0]
	battle.commands._kill(victim)
	assert(roundtrip("six survivors before AI refresh"))
	rec=battle.ai.naval.record(owner,0)
	assert(rec.members.size()==6 and not rec.ready and rec.flagship==members[2])
	for uid in rec.members.duplicate():
		battle.commands._kill(battle.units.filter(func(u):return int(u.uid)==int(uid))[0])
	assert(roundtrip("complete loss before AI refresh"))
	rec=battle.ai.naval.record(owner,0)
	assert(rec.members.is_empty() and not rec.ready and int(rec.flagship)==-1)
	print("NAVAL CASUALTY SAVE PASS full8 / flagship loss / partial loss before think / total loss / snapshot roundtrip")
	done=true;battle.free();quit(0)
