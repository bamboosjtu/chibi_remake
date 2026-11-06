extends SceneTree
const AI=preload("res://simulation/systems/ai.gd")
const Technology=preload("res://simulation/systems/technology_state.gd")
var b: Node2D
var game: Node
var owner: int
var done:=false

func _initialize() -> void:
	create_timer(60).timeout.connect(func():
		if not done:quit(1))
	run.call_deferred()

func spawn(kind: int) -> Dictionary:
	assert(b.commands._spawn_unit(kind,owner,1000,1600,true))
	return b.units.back()

func funds() -> void:
	b.economy.write(owner,{"gold":100000.0,"wood":100000.0,"food":100000.0,"stone":100000.0})

func rec(slot: int) -> Dictionary:
	return b.ai.slots.record(owner,slot)

func dispatch(slot: int) -> void:
	assert(b.ai.slots.dispatch(owner,slot,b.ai.army_for(owner)))
	assert(rec(slot).pendingUid>=0 and rec(slot).pendingToken>0)

func finish() -> Dictionary:
	assert(b.trainings.size()==1)
	var order: Dictionary=b.trainings[0].duplicate()
	b.trainings[0].t=1
	b.commands._process_trainings(b.SIM_DT)
	assert(b.trainings.is_empty())
	var unit: Dictionary=b.units.back()
	b.ai.slots.completed(order,unit) # 重复回调不得增加到位数。
	return unit

func snapshot() -> Dictionary:
	assert(game.save_game(b.units,b.commands._resources(),b.commands._save_extra()))
	return game.load_save()

func run() -> void:
	game=root.get_node("Game");game.current_map="chibic1"
	b=load("res://main.tscn").instantiate();root.add_child(b)
	b.set_process(false);b.cli_mode=true;owner=int(b.commands.ai_owners()[0])
	while not b.units.is_empty():b.commands._free_unit_at(b.units.size()-1)
	var arch:=spawn(14);spawn(14);var inf:=spawn(12);spawn(6);spawn(8);spawn(20)
	b.nav.rebuild_buildings(b.units)
	b.ai=AI.new(b);b.army_tech[owner]=Technology.initial();b.commands._ai_side(owner).init=[0,1];funds()
	b.gold=9999
	for tick in range(40):b.ai.tick()
	assert(b.trainings.is_empty());b.ai.tick();assert(b.trainings.is_empty())
	b.gold=10000
	for tick in range(40):b.ai.tick()
	assert(b.trainings.is_empty());b.ai.tick()
	assert(b.trainings.size()==1 and b.trainings[0].unit==45 and rec(0).members.is_empty())
	assert(not b.ai.slots.dispatch(owner,3,b.ai.army_for(owner)),"one archery line even with two buildings")
	var paid: Dictionary=b.economy.balance(owner).duplicate()
	var disabled:=[]
	for id in b.nav.astar.get_point_ids():
		if not b.nav.astar.is_point_disabled(id):disabled.append(id);b.nav.astar.set_point_disabled(id)
	b.trainings[0].t=1
	for tick in range(3):b.commands._process_trainings(b.SIM_DT)
	assert(b.trainings.size()==1 and b.trainings[0].t==0 and rec(0).members.is_empty())
	assert(b.economy.balance(owner)==paid and rec(0).pendingUid==arch.uid)
	for id in disabled:b.nav.astar.set_point_disabled(id,false)
	var first:=finish();assert(rec(0).members==[first.uid] and not rec(0).ready)
	assert(b.commands._ai_forming(first) and first.officer.is_empty())
	b.commands.ai_order_rally(owner);b.commands.ai_order_assault(owner);b.commands.ai_order_intercept(owner,first,99999)
	assert(first.state=="idle","partial slot protected from generic orders")
	for i in range(2):dispatch(0);assert(b.trainings[0].unit==45);finish()
	dispatch(0)
	var saved:=snapshot();var before: Dictionary=b.ai.snapshot()
	assert(b.saver.apply_snapshot(saved) and b.ai.snapshot()==before)
	assert(rec(0).members.size()==3 and b.trainings.size()==1 and b.trainings[0].aiToken==rec(0).pendingToken)
	finish();assert(rec(0).members.size()==4)
	for i in range(4):dispatch(0);assert(b.trainings[0].unit==32);finish()
	assert(rec(0).ready and rec(0).members.size()==8 and not b.ai.slots.dispatch(owner,0,b.ai.army_for(owner)))
	print("AI SLOT PIPELINE PASS C1 threshold / 41tick / completed count / blocked exit retry / duplicate callback / 4arch4inf / partial protection / pending save")
	var full:=snapshot()
	assert(b.saver.apply_snapshot(full))
	# 未满编时已有成员全死、后半段步兵仍在造：预约仍属本批，保持兵种相位。
	b.commands.ai_disband_slot(owner,0)
	for i in range(4):dispatch(0);finish()
	dispatch(0);assert(b.trainings[0].unit==32)
	for unit in b.units.filter(func(u):return rec(0).members.has(int(u.uid))):b.commands._kill(unit)
	b.ai.slots.refresh(owner)
	assert(rec(0).members.size()==4 and rec(0).pendingUid>=0)
	var pending_loss:=snapshot();assert(b.saver.apply_snapshot(pending_loss))
	finish();assert(rec(0).members.size()==5)
	var arrived_loss:=snapshot();assert(b.saver.apply_snapshot(arrived_loss))
	assert(b.saver.apply_snapshot(full))
	var survivors: Array=b.units.filter(func(u):return rec(0).members.has(int(u.uid)))
	for unit in survivors:unit.state="attack"
	b.ai.slots.refresh(owner)
	assert(rec(0).ready and not b.ai.slots.dispatch(owner,0,b.ai.army_for(owner)),"assault must not reset full slot")
	for i in range(7):b.commands._kill(survivors[i])
	b.ai.slots.refresh(owner)
	assert(rec(0).ready and rec(0).members.size()==8 and not b.ai.slots.dispatch(owner,0,b.ai.army_for(owner)))
	b.commands._kill(survivors[7]);b.ai.slots.refresh(owner)
	assert(rec(0).members.is_empty() and not rec(0).ready)
	dispatch(0);var member:=finish()
	var member_uid: int=member.uid;var hp: float=member.hp
	b.commands.ai_disband_slot(owner,0)
	assert(member.alive and member.uid==member_uid and member.hp==hp and not b.commands._ai_forming(member))
	dispatch(0);var order: Dictionary=b.trainings[0].duplicate();var balance: Dictionary=b.economy.balance(owner).duplicate()
	assert(b.commands._cancel_training(order.b) and rec(0).pendingUid==-1)
	assert(b.economy.balance(owner).gold==balance.gold+float(order.cost.gold)*0.75)
	dispatch(0);order=b.trainings[0].duplicate();b.commands._kill(order.b)
	assert(b.trainings.is_empty() and rec(0).pendingUid==-1)
	var loss_saved:=snapshot();assert(b.saver.apply_snapshot(loss_saved))
	# 出生历史保留已清理的尸体UID；整队消失才能清空本批。
	assert(b.saver.apply_snapshot(full))
	var old_uid: int=rec(0).members[0]
	b.commands._kill(b.units.filter(func(u):return int(u.uid)==old_uid)[0])
	for i in range(b.units.size()-1,-1,-1):
		if int(b.units[i].uid)==old_uid:b.commands._free_unit_at(i)
	var pruned:=snapshot();assert(b.saver.apply_snapshot(pruned) and rec(0).members.size()==8)
	print("AI SLOT LIFECYCLE PASS no assault refill / partial casualties retained / whole dead reset / disband preserves / cancel75 / building loss / pruned UID")
	# 原子预检：坏关联不交换世界、选择或资金。
	var intact:=snapshot();var identity: Dictionary=b.units[0];b.selected=[identity]
	for mode in [0,1,2,3,4]:
		var invalid: Dictionary=intact.duplicate(true)
		var slot: Dictionary=invalid.simulation.ai.trainingSlots.records["%d/0"%owner]
		match mode:
			0:slot.members[1]=slot.members[0]
			1:slot.ready=false
			2:slot.pendingUid=inf.uid;slot.pendingToken=1
			3:slot.members[0]=-1
			4:invalid.trainings.append({"buildingUid":inf.uid,"unit":32,"owner":owner,"t":1,"ticks":true,"cost":{},"aiSlot":0,"aiToken":99})
		assert(not b.saver.apply_snapshot(invalid) and is_same(b.units[0],identity) and b.selected==[identity])
	var legacy: Dictionary=intact.duplicate(true);legacy.v=6;legacy.simulation.ai.erase("trainingSlots")
	assert(b.saver.apply_snapshot(legacy) and b.ai.slots.records.is_empty())
	# 骑兵5、车2+步6；升级后才换成200人，不依赖玩家开放表。
	b.commands._tech_for(owner).level=1;funds()
	assert(not b.ai.slots.dispatch(owner,1,b.ai.army_for(owner)), "upgraded training needs a completed HQ")
	spawn(0);b.nav.rebuild_buildings(b.units)
	for i in range(5):dispatch(1);assert(b.trainings[0].unit==37);finish()
	assert(rec(1).ready and rec(1).members.size()==5)
	for i in range(8):dispatch(2);assert(b.trainings[0].unit==(34 if i<2 else 38));finish()
	assert(rec(2).ready and rec(2).members.size()==8)
	assert(b.commands.train_types_for(8)[0].unit==34 and not b.commands.train_types_for(20).is_empty())
	assert(b.commands.train_types_for(8,owner).map(func(x):return int(x.unit))==[34])
	b.free();game.current_map="chibic13"
	b=load("res://main.tscn").instantiate();root.add_child(b)
	b.set_process(false);b.cli_mode=true;owner=int(b.commands.ai_owners()[0]);funds()
	assert(b.commands.train_types_for(20,owner).map(func(x):return int(x.unit))==[46])
	spawn(0);b.commands._tech_for(owner).level=1;b.nav.rebuild_buildings(b.units)
	assert(b.commands.train_types_for(20,owner).slice(0,2).map(func(x):return int(x.unit))==[46,47])
	# 水军调度阈值暂未确认，但用户允许AI已有船坞接受正常付费生产。
	var dock:=spawn(20)
	var second_dock:=spawn(20)
	for kind in [46,47]:
		assert(b.commands._queue_train(owner,dock,kind))
		assert(not b.commands._queue_train(owner,second_dock,kind),"AI ship production global one-order lock")
		assert(b.commands._cancel_training(dock))
	print("AI SLOT SAVE PASS atomic malformed / v6 reset / cavalry5 / cat2inf6 / HQ200 gate / AI existing vehicle-dock / player list preserved")
	# R16：水军槽快照必须与陆军槽对等校验；坏档在交换世界前拒绝。
	var payload: Dictionary=snapshot()
	var payload_ids:={}
	for record in payload.units:payload_ids[int(record.uid)]=record
	var next_uid:=int(payload.nextUid)
	var blank: Dictionary=payload.simulation.ai.duplicate(true)
	blank.navalSlots={}
	assert(b.ai.valid_snapshot(blank,payload_ids,payload.trainings,next_uid),"R16: 空水军槽合法")
	var empty_slot: Dictionary=blank.duplicate(true)
	empty_slot.navalSlots={"serial":0,"records":{"%d/0"%owner:{"members":[],"pending":false,"token":0,"ready":false,"flagship":-1}}}
	assert(b.ai.valid_snapshot(empty_slot,payload_ids,payload.trainings,next_uid),"R16: 空槽记录合法")
	var wrong_kind: int=-1
	for record in payload.units:
		if int(record.owner)==owner and int(record.unit)!=46 and not bool(record.building):
			wrong_kind=int(record.uid);break
	assert(wrong_kind>=0)
	for mode in range(12):
		var value: Dictionary=empty_slot.duplicate(true)
		var slot: Dictionary=value.navalSlots.records["%d/0"%owner]
		match mode:
			0:value.navalSlots.serial=-1
			1:value.navalSlots.records={"999/99":{"members":[],"pending":false,"token":0,"ready":false,"flagship":-1}}
			2:slot.members="invalid"
			3:value.navalSlots.records={"%d/2"%owner:{"members":[],"pending":false,"token":0,"ready":false,"flagship":-1}}
			4:slot.members=[wrong_kind]
			5:slot.members=[wrong_kind,wrong_kind]
			6:slot.ready=true
			7:slot.flagship=wrong_kind
			8:slot.pending=true
			9:slot.pending=true;slot.token=9;value.navalSlots.serial=1
			10:slot.pending=true;slot.token=1;value.navalSlots.serial=1
			11:slot.members=[-1]
		assert(not b.ai.valid_snapshot(value,payload_ids,payload.trainings,next_uid),"R16: 非法水军槽必须拒绝 mode=%d"%mode)
	var naval_identity: Dictionary=b.units[0];b.selected=[naval_identity]
	var invalid_payload: Dictionary=payload.duplicate(true)
	invalid_payload.simulation.ai.navalSlots={"serial":-1,"records":{"999/99":{"members":"invalid"}}}
	assert(not b.saver.apply_snapshot(invalid_payload) and is_same(b.units[0],naval_identity) and b.selected==[naval_identity],"R16: 坏水军槽不能交换世界")
	print("AI NAVAL SLOT PASS empty/records structural / owner-slot / member UID-kind / flagship / pending-token-order / malformed snapshot rejected")
	done=true;b.queue_free();await process_frame;quit(0)

