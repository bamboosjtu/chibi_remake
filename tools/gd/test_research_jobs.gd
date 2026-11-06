extends SceneTree
var done := false
var b: Node2D
var game: Node

func _initialize() -> void:
	create_timer(60).timeout.connect(func():
		if not done: quit(1))
	run.call_deferred()

func spawn(kind: int, owner: int) -> Dictionary:
	assert(b.commands.world._spawn_unit(kind,owner,1000+20*b.units.size(),1600,true))
	return b.units.back()

func save() -> Dictionary:
	assert(game.save_game(b.units,b.commands.world._resources(),b.commands.session._save_extra()))
	return game.load_save()

func by_uid(uid: int) -> Dictionary:
	return b.units.filter(func(u):return int(u.uid)==uid)[0]

func run() -> void:
	game = root.get_node("Game"); game.current_map = "chibic6"
	b = load("res://main.tscn").instantiate(); root.add_child(b)
	b.set_process(false); b.cli_mode = true; b.ai = null
	b.gold=100000; b.wood=100000; b.stone=100000; b.food=100000
	var archer := spawn(4,b.player_owner); var armory := spawn(2,b.player_owner)
	var hq := spawn(0,b.player_owner); var hq_uid: int=hq.uid
	spawn(32,b.player_owner);spawn(32,b.player_owner)
	b.commands.technology._ai_side(b.player_owner).init[1]=4
	var archer_uid: int=archer.uid; var armory_uid: int=armory.uid
	b.selected=[archer]; assert(b.commands.technology._start_tech(3))
	var resources: Dictionary=b.commands.world._resources()
	assert(not b.commands.technology._start_tech(3) and not b.commands.economy._queue_train(b.player_owner,archer,45))
	assert(b.commands.world._resources()==resources and b.research_jobs.size()==1)
	b.selected=[armory]; assert(not b.commands.technology.tech_research_active() and b.commands.technology._start_tech(6))
	assert(b.research_jobs.size()==2)
	for step in range(199): b.commands.technology._process_tech(b.SIM_DT)
	assert(b.player_tech.bow==0 and b.player_tech.weapon==0)
	var saved := save()
	assert(saved.simulation.researchJobs.size()==2 and b.saver.apply_snapshot(saved))
	archer=by_uid(archer_uid); armory=by_uid(armory_uid)
	b.commands.technology._process_tech(b.SIM_DT)
	assert(b.player_tech.bow==1 and b.player_tech.weapon==1 and b.research_jobs.is_empty())
	hq=by_uid(hq_uid);b.selected=[hq]; assert(b.commands.economy._queue_train(b.player_owner,hq,30))
	resources=b.commands.world._resources()
	assert(not b.commands.technology._start_tech(0) and b.commands.world._resources()==resources and b.trainings.size()==1)
	assert(b.commands.economy._cancel_training(hq) and b.commands.technology._start_tech(0))
	assert(not b.commands.economy._queue_train(b.player_owner,hq,30))
	assert(b.commands.technology._cancel_tech()); b.selected=[archer]; assert(b.commands.technology._start_tech(4))
	b.selected=[armory]; assert(b.commands.technology._start_tech(9))
	var before: Dictionary=b.commands.world._resources(); var cost: Dictionary=b.commands.technology.tech_cost(9)
	assert(b.commands.technology._cancel_tech() and not b.commands.technology._cancel_tech())
	assert(b.gold==before.gold+floorf(cost.gold*0.75) and b.research_jobs.size()==1)
	b.selected=[archer]; assert(b.commands.technology.tech_research_active() and b.commands.technology.tech_research_name()==b.commands.technology.tech_row(4).name)
	print("RESEARCH CONCURRENCY PASS two buildings / same-building production lock / cancel selected only / 199tick save")
	# 引用、并发冲突、时间/费用错误须在交换世界前拒绝。
	var good := save()
	var cases: Array=[]
	for field in ["buildingUid","owner","tech","t"]:
		var invalid: Dictionary=good.duplicate(true)
		invalid.simulation.researchJobs[0][field]=-1; cases.append(invalid)
	var duplicate: Dictionary=good.duplicate(true)
	duplicate.simulation.researchJobs.append(duplicate.simulation.researchJobs[0].duplicate(true)); cases.append(duplicate)
	var production: Dictionary=good.duplicate(true)
	production.trainings=[{"buildingUid":archer_uid,"owner":b.player_owner,"unit":45,"t":100,"ticks":true,"cost":b.commands.economy.ai_unit_cost(45)}]; cases.append(production)
	var invalid_time: Dictionary=good.duplicate(true); invalid_time.simulation.researchJobs[0].t=200; cases.append(invalid_time)
	var invalid_cost: Dictionary=good.duplicate(true); invalid_cost.simulation.researchJobs[0].cost.gold=-1; cases.append(invalid_cost)
	for invalid in cases:
		var ids: Array=b.units.map(func(u):return int(u.uid))
		assert(not b.saver.apply_snapshot(invalid))
		assert(ids==b.units.map(func(u):return int(u.uid)) and b.research_jobs.size()==1)
	# 旧版单项研究不丢失已扣费用及进度；读入时清空读档前的并行任务。
	var legacy: Dictionary=good.duplicate(true); legacy.simulation.erase("researchJobs")
	legacy.simulation.techProgress={"tech":4,"t":199,"cost":b.commands.technology.tech_cost(4)}
	assert(b.saver.apply_snapshot(legacy) and b.research_jobs.is_empty())
	b.commands.technology._process_tech(b.SIM_DT); assert(b.player_tech.bow==2 and b.tech_progress.is_empty())
	print("RESEARCH SNAPSHOT PASS invalid atomic / job references / production conflicts / legacy single-job continuation")
	var bank := spawn(23,b.player_owner); var bank_uid: int=bank.uid
	b.selected=[bank]; before=b.commands.world._resources()
	assert(b.commands.technology._start_tech(12) and b.wood==before.wood-1000 and b.gold==before.gold)
	for step in range(199): b.commands.technology._process_tech(b.SIM_DT)
	assert(b.gold==before.gold)
	saved=save(); assert(b.saver.apply_snapshot(saved)); bank=by_uid(bank_uid); b.selected=[bank]
	b.commands.technology._process_tech(b.SIM_DT)
	assert(b.gold==before.gold+500 and b.research_jobs.is_empty())
	for step in range(10): b.commands.technology._process_tech(b.SIM_DT)
	assert(b.gold==before.gold+500)
	before=b.commands.world._resources(); assert(b.commands.technology._start_tech(12) and b.commands.technology._cancel_tech())
	assert(b.wood==before.wood-250 and b.gold==before.gold)
	var owner: int=b.commands.economy.ai_owners()[0]; var mill:=spawn(4,owner)
	b.economy.write(owner,{"gold":100000.0,"wood":100000.0,"stone":100000.0,"food":100000.0})
	assert(b.commands.technology._queue_research(owner,mill,3,true))
	assert(not b.commands.technology._queue_research(owner,bank,6,true))
	for step in range(200): b.commands.technology._process_tech(b.SIM_DT)
	assert(b.commands.technology._tech_for(owner).bow==1 and b.player_tech.bow==2)
	assert(b.commands.technology._queue_research(owner,mill,4,true))
	b.commands.military._kill(mill)
	assert(b.research_jobs.is_empty(),"dead building must release job reference before a paused save")
	saved=save(); assert(b.saver.apply_snapshot(saved))
	print("RESEARCH TRANSACTIONS PASS sale200tick / debit start / credit once / cancel75 / AI owner isolated")
	done=true; b.queue_free(); await process_frame; quit(0)
