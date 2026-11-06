extends SceneTree
const AI = preload("res://simulation/systems/ai.gd")
const Technology = preload("res://simulation/systems/technology_state.gd")
var b: Node2D
var owner: int
var done := false

func _initialize() -> void:
	create_timer(60).timeout.connect(func():
		if not done: quit(1))
	run.call_deferred()

func spawn(kind: int) -> Dictionary:
	assert(b.commands.world._spawn_unit(kind,owner,1000+b.units.size()*20,1600,true))
	return b.units.back()

func reset(gate: int, behavior := 0) -> void:
	b.research_jobs.clear(); b.trainings.clear()
	b.army_tech[owner]=Technology.initial()
	b.commands.technology._ai_side(owner).init=[behavior,gate]
	b.economy.write(owner,{"gold":100000.0,"wood":100000.0,"food":100000.0,"stone":100000.0})
	b.ai=AI.new(b)

func finish() -> void:
	for step in range(200): b.commands.technology._process_tech(b.SIM_DT)

func run() -> void:
	root.get_node("Game").current_map="chibic6"
	b=load("res://main.tscn").instantiate();root.add_child(b)
	b.set_process(false);b.cli_mode=true
	owner=int(b.commands.economy.ai_owners()[0])
	# 隔离本测试的建筑，避免已有多个同类建筑使忙碌测试选到另一个空闲建筑。
	for unit in b.units:
		if int(unit.owner)==owner: unit.owner=0
	var hq:=spawn(0);var mill:=spawn(4);var armory:=spawn(2);var vehicle:=spawn(8);spawn(6)
	for step in range(4): spawn(32)
	# AI 施工群目标 5 名工人；本测试聚焦研究，先补满避免自动补工占用 HQ 训练锁。
	for step in range(5): spawn(30)
	reset(1)
	assert(not b.ai._research_plan(owner) and not b.commands.economy.ai_queue_hq_upgrade(owner))
	for gate in [3,4]:
		reset(gate,2)
		assert(not b.ai._research_plan(owner))
	reset(2)
	for expected in [3,6,9]:
		assert(b.ai._research_plan(owner) and b.research_jobs.size()==1)
		assert(int(b.research_jobs[0].tech)==expected)
		finish()
	assert(not b.ai._research_plan(owner))
	assert(b.commands.technology._tech_for(owner).bow==1 and b.commands.technology._tech_for(owner).weapon==1 and b.commands.technology._tech_for(owner).armor==1)
	for gate in [3,4]:
		reset(gate)
		var order: Array=[]
		while b.ai._research_plan(owner):
			assert(b.research_jobs.size()==1);order.append(int(b.research_jobs[0].tech));finish()
		assert(order==([3,6,18,4,9,19,7,10] if gate==3 else [3,6,18,4,9,19,5,7,10,8,11]),str(order))
		assert(order.all(func(idx):return idx<20),"unconfirmed dock gates must not be guessed")
	print("AI RESEARCH ORDER PASS gates1-4 / behavior2 blocked / ordinary chains / catapult / no guessed naval gate")
	reset(3)
	assert(b.commands.technology._queue_research(owner,mill,3,true))
	assert(b.ai._research_plan(owner) and b.research_jobs.size()==2)
	assert(b.research_jobs[1].tech==6 and not b.commands.technology._queue_research(owner,mill,3,true))
	var jobs: int=b.research_jobs.size();var funds: Dictionary=b.economy.balance(owner).duplicate()
	# 下一轮可派车兵所；忙碌木材场/武器库均不会被抢占。
	assert(b.ai._research_plan(owner) and b.research_jobs.size()==jobs+1)
	assert(b.research_jobs[2].tech==18 and b.economy.balance(owner).gold<funds.gold)
	var ai_saved: Dictionary=b.ai.snapshot()
	b.ai=AI.new(b);b.ai.restore(ai_saved)
	assert(b.ai.snapshot()==ai_saved)
	reset(2)
	b.ai._plan[owner]=20; b.ai._think[owner]=40
	b.ai.tick(); assert(b.research_jobs.is_empty())
	b.ai._think[owner]=40; b.ai.tick()
	# HQ属于经济计划；该轮普通计划仍最多派一道（弓3）。
	assert(b.research_jobs.size()==2 and b.research_jobs.any(func(job):return job.tech==0) and b.research_jobs.any(func(job):return job.tech==3))
	print("AI RESEARCH CLOCK PASS 22think boundary / one normal dispatch / independent HQ / busy skip / cursor snapshot")
	reset(4)
	# 未完工的前置不算就绪；生产占用帅帐也不能被升级抢占。
	mill.site=true;assert(not b.commands.economy.ai_queue_hq_upgrade(owner));mill.site=false
	assert(b.commands.economy._queue_train(owner,hq,30) and not b.commands.economy.ai_queue_hq_upgrade(owner))
	assert(b.commands.economy._cancel_training(hq) and b.commands.economy.ai_queue_hq_upgrade(owner));finish()
	assert(b.commands.economy.ai_level(owner)==1)
	vehicle.site=true;assert(not b.commands.economy.ai_queue_hq_upgrade(owner));vehicle.site=false
	assert(b.commands.economy.ai_queue_hq_upgrade(owner));finish();assert(b.commands.economy.ai_level(owner)==2)
	assert(not b.commands.economy.ai_queue_hq_upgrade(owner))
	b.commands.technology._tech_for(owner).bow=2;b.commands.technology._tech_for(owner).weapon=2
	b.economy.write(owner,{"gold":0.0,"wood":100000.0,"food":100000.0,"stone":100000.0})
	assert(not b.commands.economy.ai_queue_hq_upgrade(owner))
	b.commands.economy.ai_set_gold(owner,20000)
	assert(b.commands.economy.ai_queue_hq_upgrade(owner));finish();assert(b.commands.economy.ai_level(owner)==3)
	assert(not b.commands.economy.ai_queue_hq_upgrade(owner) and b.player_tech.level==0)
	print("AI HQ PASS gate / completed prerequisites / combat members / production lock / funds / own effects only")
	# 可用槽表覆盖全部分档，执行器尚待补充流水线/计数口径。
	assert(AI.available_slots(0,1,0,0,9999,17).is_empty())
	assert(AI.available_slots(0,1,0,0,10000,17)==[0])
	assert(AI.available_slots(0,2,0,0,20000,1)==[0])
	assert(AI.available_slots(0,2,1,0,0,1)==[0,1,2])
	assert(AI.available_slots(0,3,2,2,20000,1)==[0,1,2])
	assert(AI.available_slots(0,4,3,2,20000,1)==[0,1,2])
	assert(AI.available_slots(1,3,0,0,0,1)==[0,3])
	assert(AI.available_slots(1,4,0,0,0,1)==[3])
	assert(AI.available_slots(2,1,0,0,20000,0).is_empty())
	assert(AI.available_slots(2,1,0,0,0,1).is_empty())
	assert(AI.available_slots(2,4,0,0,0,1)==[0])
	reset(1,2); b.commands.technology._tech_for(owner).level=3
	b.ai._train(owner);assert(b.trainings.is_empty())
	print("AI TRAIN GATES PASS two scheduler gates separated / C1 wealthy slot0 / L1 none / behavior filter")
	reset(1)
	assert(b.ai.army_for(owner)==[45,32,36])
	b.commands.technology._tech_for(owner).level=1;assert(b.ai.army_for(owner)==[39,38,37])
	spawn(14)
	for building in b.units:
		if int(building.owner)==owner and int(building.unit) in [6,8]:building.site=true
	b.economy.write(owner,{"gold":20000.0,"wood":0.0,"food":0.0,"stone":0.0})
	var player_funds: Dictionary=b.commands.world._resources()
	b.ai._train(owner)
	assert(b.economy.balance(owner)=={"gold":20000.0,"wood":1000.0,"food":1500.0,"stone":1000.0})
	assert(b.trainings.is_empty() and b.commands.world._resources()==player_funds)
	b.ai._train(owner)
	assert(b.trainings.size()==1 and b.trainings[0].unit==39)
	print("AI SUPPLY PASS food1500-wood1000-iron1000 / player unchanged / retry normal cost / level100-200 roster")
	done=true;b.queue_free();await process_frame;quit(0)
