extends SceneTree
var b: Node2D
var game: Node
var done:=false
const MAPS:=["chibic10","chibic11","chibic12","chibic13","chibic16","chibic17","chibil10","chibil11","chibil12","chibil13","chibil16"]

func _initialize() -> void:
	create_timer(180).timeout.connect(func():
		if not done:quit(1))
	run.call_deferred()

func open_battle(map_id: String) -> void:
	if b!=null:b.free()
	game.current_map=map_id
	b=load("res://main.tscn").instantiate();root.add_child(b)
	b.set_process(false);b.cli_mode=true;b.ai=null
	while not b.units.is_empty():b.commands._free_unit_at(b.units.size()-1)
	b.nav.rebuild_buildings(b.units)

func spawn(kind: int, point: Vector2, owner: int=-1) -> Dictionary:
	assert(b.commands._spawn_unit(kind,b.player_owner if owner<0 else owner,point.x,point.y,true))
	return b.units.back()

func connected_land(start:Vector2i,limit:int) -> Array:
	var cells:Array=[start];var seen:Dictionary={start:true};var cursor:=0
	while cursor<cells.size() and cells.size()<limit:
		var cell:Vector2i=cells[cursor];cursor+=1
		for neighbor in b.nav.neighbors(cell):
			if seen.has(neighbor):continue
			seen[neighbor]=true
			if not b.nav.is_water(neighbor) and not b.nav.is_solid(neighbor,0):cells.append(neighbor)
	return cells

func shore_pair() -> Array:
	for a in range(4,int(b.map_data.rows)-4):
		for row in range(9,int(b.map_data.cols)-9):
			var sea:=Vector2i(a,row)
			if not b.nav.is_water(sea) or not b.commands._unit_placement_free(sea,47,1):continue
			var point:Vector2=b.nav.anchor_of(sea.x,sea.y)
			var probe:Dictionary={"unit":47,"ax":point.x,"ay":point.y,"is_building":false}
			var anchors:Array=b.transports.coastal_anchors(probe,30)
			if anchors.size()>=3 and connected_land(anchors[0],40).size()>=40:return [sea,anchors[0]]
	assert(false,"expected navigable whole-body coastline with land slots")
	return []

func snapshot() -> Dictionary:
	assert(game.save_game(b.units,b.commands._resources(),b.commands._save_extra()))
	return game.load_save()

func find(uid: int) -> Dictionary:
	return b.units.filter(func(u):return int(u.uid)==uid)[0]

func click(point: Vector2) -> void:
	var scale_factor: Vector2=root.get_final_transform().get_scale()
	for pressed in [true,false]:
		var event:=InputEventMouseButton.new()
		event.position=point*scale_factor;event.global_position=event.position
		event.button_index=MOUSE_BUTTON_LEFT;event.pressed=pressed
		root.push_input(event,false)
	b.view.update_panel()

func landing_cells(ship: Dictionary) -> Array:
	return b.transports.coastal_anchors(ship,30)

# Passengers must walk clear of the finite adjacent shore before others can land.
func clear_landed(people:Array,removed:=-1) -> void:
	for uid in people:
		if uid==removed:continue
		var person:Dictionary=find(uid)
		if person.attached or person.die_t>=0:continue
		var vessel:Dictionary=b.units.filter(func(u):return int(u.unit)==47 and bool(u.alive) and float(u.die_t)<0)[0]
		if not b.transports.adjacent(person,vessel):continue
		var route:Array=[]
		for cell in connected_land(b.commands._unit_cell(person),256):
			if b.transports.edge_distance_at(cell,int(person.unit),vessel)<=2 or not b.commands._unit_placement_free(cell,int(person.unit),0,int(person.uid)):continue
			route=b.commands._path_to(person,b.nav.anchor_of(cell.x,cell.y),false)
			if not route.is_empty():break
		assert(not route.is_empty(),"coast must connect to inland destination")
		person.path=route;person.pi=0;person.state="move"
		for tick in range(400):
			b.commands._step_unit(person,b.SIM_DT)
			if person.state=="idle":break

func run() -> void:
	game=root.get_node("Game")
	open_battle("chibic13")
	var pair:=shore_pair();var sea: Vector2i=pair[0];var land: Vector2i=pair[1]
	var ship:=spawn(47,b.nav.anchor_of(sea.x,sea.y));var ship_uid: int=ship.uid
	var point: Vector2=b.nav.anchor_of(land.x,land.y)
	var people:=[]
	for i in range(17):
		var unit:=spawn(30,point);unit.carry=50+i;unit.carry_kind="wood"
		people.append(int(unit.uid))
	b.selected=people.slice(0,16).map(func(uid):return find(uid));b.commands._group_assign(1)
	for i in range(16):
		var unit:=find(people[i]);b.selected=[unit]
		assert(b.commands._order_board(ship)==1);b.commands._step_unit(unit,b.SIM_DT)
		assert(unit.attached and unit.state=="boarded" and unit.aboard_uid==ship.uid and b.selected.is_empty())
		assert(unit.path.is_empty() and unit.board_target==null and unit.repair_target==null and unit.gather_obj==null)
		assert(unit.carry==50+i and unit.carry_kind=="wood")
	assert(ship.carry_n==16 and ship.carry_hp==1600 and ship.loaded)
	assert(b.commands.control_group_size(1)==0 and not b.commands._group_recall(1))
	var stored_member: Dictionary=find(people[0]);b.selected=[stored_member];b.commands._cmd_watch();b.commands._cmd_rest()
	assert(stored_member.state=="boarded" and stored_member.attached)
	var extra:=find(people[16]);b.selected=[extra]
	assert(b.commands._order_board(ship)==0 and not b.commands._attach_to_ship(extra,ship))
	assert(not b.commands._attach_to_ship(find(people[0]),ship) and ship.carry_n==16)
	var foreign:=spawn(47,b.nav.anchor_of(sea.x,sea.y),int(b.commands.ai_owners()[0]))
	assert(b.commands._order_board(foreign)==0 and not b.commands._attach_to_ship(extra,foreign))
	var stale: Dictionary=ship.duplicate();assert(b.commands._order_board(stale)==0)
	foreign.die_t=0;assert(b.commands._order_board(foreign)==0) # 保持死亡，避免占着 sea 格阻止后续船停靠
	var aboard:=snapshot();assert(aboard.v==8 and b.saver.apply_snapshot(aboard))
	ship=find(ship_uid)
	assert(ship.carry_n==16 and ship.carry_hp==1600)
	if b.view!=null:
		for uid in people.slice(0,16):
			var hidden:=find(uid)
			assert(not b.view.unit_nodes(hidden).spr.visible and not b.view.unit_nodes(hidden).hbar.visible and not b.view.unit_nodes(hidden).diamond.visible,"loaded save hides passengers while paused")
		b.selected=[ship];b.view.update_panel()
		assert(b.view.classic_panel.values[2].text=="16/16" and b.view.classic_panel.values[3].text=="1600")
		var viewport_size: Vector2=root.get_visible_rect().size
		b.cam.position=Vector2(ship.ax,ship.ay)-(b.view.battle_rect().get_center()-viewport_size*0.5)/b.cam.zoom
		b.cam.force_update_scroll();await process_frame;await process_frame
		var unload_buttons:Array=b.view.art_buttons.filter(func(slot):return slot.btn.get_meta("cmd_name")=="下船")
		assert(unload_buttons.size()==1)
		click(unload_buttons[0].btn.get_global_rect().get_center())
		b.player_commands.pump()
		assert(b.cmd_pending=="" and ship.unload_active)
		for tick in range(64):
			b.commands._step_unit(ship,b.SIM_DT)
			if tick%4==3:clear_landed(people)
		b.view.update_hud_text()
		assert(ship.carry_n==0)
		assert(b.saver.apply_snapshot(aboard));ship=find(ship_uid)
		print("TRANSPORT UI PASS actual icon without ground click /16-0 capacity / cargo HP panel / paused hidden passengers")
	# 载员状态在船内继续流逝，自己的命令/动画不推进。
	var passenger:=find(people[0]);passenger.haste_t=2;var before: Vector2=Vector2(passenger.ax,passenger.ay)
	for tick in range(2):b.commands._step_unit(passenger,b.SIM_DT)
	assert(passenger.haste_t==0 and Vector2(passenger.ax,passenger.ay)==before and passenger.attached)
	print("TRANSPORT BOARD PASS actual order /16 capacity / duplicate-foreign-stale-dying rejected / cargo preserved / selection removed / status ticks / loaded save")
	var ai_owner: int=b.commands.ai_owners()[0]
	ship.owner=ai_owner
	for uid in people.slice(0,16):find(uid).owner=ai_owner
	b.commands.ai_order_assault(ai_owner);b.commands.ai_order_intercept(ai_owner,extra,99999);b.commands.ai_order_rally(ai_owner)
	assert(people.slice(0,16).all(func(uid):return find(uid).state=="boarded" and find(uid).attached))
	assert(not b.commands.ai_focus_unit(ai_owner).get("attached",false))
	assert(not b.commands._nearest_enemy_threat(extra).get("attached",false))
	assert(b.saver.apply_snapshot(snapshot()))
	assert(b.saver.apply_snapshot(aboard));ship=find(ship_uid);extra=find(people[16])
	print("TRANSPORT AI PASS carried units excluded from assault-intercept-rally / focus and threats / manifest remains valid")
	# 船走水层；混选陆军不复用船的水路。
	b.selected=[ship,extra];b.commands._move_selected_to(b.nav.anchor_of(sea.x,sea.y))
	for u in [ship,extra]:
		for waypoint in u.path:assert(not b.nav.is_solid(b.nav.cell_of_px(waypoint.x,waypoint.y),b.commands._nav_layer(u)))
	b.commands._cancel_unit_command(extra)
	var destination:=Vector2i(-1,-1)
	for cell in b.nav.neighbors(sea):
		if b.nav.is_water(cell) and not b.nav.is_solid(cell,1):destination=cell;break
	assert(destination.x>=0)
	b.selected=[ship];b.commands._move_selected_to(b.nav.anchor_of(destination.x,destination.y))
	for tick in range(80):
		b.commands._step_unit(ship,b.SIM_DT)
		assert(b.nav.is_water(b.nav.cell_of_px(ship.ax,ship.ay)))
		if ship.state=="idle":break
	assert(ship.state=="idle" and ship.carry_n==16)
	# 正常新命令可替换，装载清单与货物仍在。
	b.selected=[ship];b.commands._move_selected_to(b.nav.anchor_of(sea.x,sea.y))
	for tick in range(80):
		b.commands._step_unit(ship,b.SIM_DT)
		if ship.state=="idle":break
	# R04：运输船是 4 格占位，目标水面格若让船体压岸，只能停在最近的合法水面。
	var returned: Vector2i=b.nav.cell_of_px(ship.ax,ship.ay)
	assert(b.nav.is_water(returned) and not b.nav.is_solid(returned,1),"船停靠在水面")
	assert(maxi(absi(returned.x-sea.x),absi(returned.y-sea.y))<=2,"船应停在目标水面附近 %s vs %s" % [returned,sea])
	# 只有一个空位，其他陆地用真实存活单位占住；占用状态能够随存档恢复。
	var cells:=landing_cells(ship);assert(cells.size()>1)
	var blockers:=[]
	for cell in cells:
		if cell==land:continue
		var blocker:=spawn(32,b.nav.anchor_of(cell.x,cell.y));blockers.append(int(blocker.uid))
	# 岸边第17名工人占着唯一格，全部失败；移开它后逐tick只允许一人落位。
	assert(b.commands._order_unload(ship,point)==1 and ship.state=="unload" and ship.carry_n==16)
	var blocked:=snapshot();assert(b.saver.apply_snapshot(blocked))
	ship=find(ship_uid);extra=find(people[16])
	b.commands._step_unit(ship,b.SIM_DT);assert(ship.carry_n==16 and ship.state=="unload")
	b.selected=[ship];b.commands._move_selected_to(b.nav.anchor_of(destination.x,destination.y))
	assert(ship.state=="move" and ship.carry_n==16)
	b.commands._cmd_watch();b.commands._step_unit(ship,b.SIM_DT)
	assert(ship.state=="idle" and ship.carry_n==16,"new move-watch preserves unload state and passengers")
	assert(b.commands._order_unload(ship,point)==1 and ship.unload_active)
	var removed: int=extra.uid;b.commands._free_unit_at(b.units.find(extra))
	for tick in range(8): b.commands._step_unit(ship,b.SIM_DT)
	assert(ship.carry_n==15 and ship.unload_active)
	var first_landed: Dictionary={}
	for uid in people:
		if uid==removed:continue
		var unit:=find(uid)
		if not unit.attached:first_landed=unit
	assert(not first_landed.is_empty() and b.nav.cell_of_px(first_landed.ax,first_landed.ay)==land)
	b.commands._step_unit(ship,b.SIM_DT);assert(ship.carry_n==15,"no two passengers on same landing cell")
	var partial:=snapshot();assert(b.saver.apply_snapshot(partial))
	ship=find(ship_uid)
	for uid in blockers:b.commands._free_unit_at(b.units.find(find(uid)))
	for tick in range(64):
		b.commands._step_unit(ship,b.SIM_DT)
		if tick%4==3:clear_landed(people,removed)
	assert(ship.carry_n==0 and ship.carry_hp==0 and not ship.loaded and ship.state=="idle")
	assert(b.commands.control_group_size(1)==16)
	var used:={}
	for uid in people:
		if uid==removed:continue
		var unit:=find(uid);var cell: Vector2i=b.nav.cell_of_px(unit.ax,unit.ay)
		assert(not unit.attached and unit.aboard_uid==-1 and not b.nav.is_water(cell) and not b.nav.is_solid(cell,0) and not used.has(cell),"landed uid=%s cell=%s water=%s solid=%s duplicate=%s state=%s"%[uid,cell,b.nav.is_water(cell),b.nav.is_solid(cell,0),used.has(cell),unit.state])
		assert(unit.carry==50+people.find(uid));used[cell]=true
	print("TRANSPORT LAND PASS water-layer sailing / mixed selection / occupied coast / pending unload save / retry / partial save /16 unique land cells / cargo retained")
	# 坏载员图必须在交换世界前拒绝；旧版汇总字段漂移可由真实关联修复。
	assert(b.saver.apply_snapshot(aboard));ship=find(ship_uid)
	var identity: Dictionary=b.units[0];b.selected=[identity]
	for mode in range(9):
		var invalid: Dictionary=aboard.duplicate(true)
		var unit: Dictionary=invalid.units.filter(func(u):return int(u.uid)==int(people[0]))[0]
		var vessel: Dictionary=invalid.units.filter(func(u):return int(u.uid)==ship_uid)[0]
		match mode:
			0:unit.simulation.aboard_uid=999999
			1:unit.simulation.aboard_uid=people[1]
			2:unit.owner+=1
			3:unit.unit=47
			4:unit.simulation.attached="yes"
			5:vessel.simulation.carry_n=15
			6:vessel.simulation.carry_hp=0
			7:vessel.simulation.loaded=false
			8:unit.simulation.aboard_uid=-1
		assert(not b.saver.apply_snapshot(invalid) and is_same(b.units[0],identity) and b.selected==[identity])
	var old: Dictionary=aboard.duplicate(true);old.v=7
	var vessel: Dictionary=old.units.filter(func(u):return int(u.uid)==ship_uid)[0]
	vessel.simulation.carry_n=0;vessel.simulation.carry_hp=999;vessel.simulation.loaded=false
	var legacy_passenger: Dictionary=old.units.filter(func(u):return int(u.uid)==int(people[0]))[0]
	legacy_passenger.state="attack";legacy_passenger.simulation.path=[[1,2]];legacy_passenger.simulation.targetUid=ship_uid
	assert(b.saver.apply_snapshot(old));ship=find(ship_uid)
	assert(ship.carry_n==16 and ship.carry_hp==1600 and ship.loaded)
	assert(find(people[0]).state=="boarded" and find(people[0]).path.is_empty() and find(people[0]).target==null)
	# 载员受全军升级影响时汇总同步；单个载员死亡和整船沉没都不能留下活体孤儿。
	b.commands._apply_tech_effects(0,b.player_owner)
	var upgraded:=snapshot();assert(b.saver.apply_snapshot(upgraded));ship=find(ship_uid)
	assert(ship.carry_hp==1600)
	b.commands._kill(find(people[0]));assert(ship.carry_n==15 and ship.carry_hp==1500)
	assert(b.saver.apply_snapshot(snapshot()));ship=find(ship_uid)
	# R01：科技升级的普通部队当前 HP 高于基础上限，这是合法状态；登船/船内升级/受伤都要能读档。
	var troop_cell: Vector2i=b.transports.landing_cell(ship,{})
	assert(troop_cell.x>=0,"R01: 需要船边可落位格")
	var troop:=spawn(32,b.nav.anchor_of(troop_cell.x,troop_cell.y))
	var troop_uid:=int(troop.uid)
	b.commands._apply_tech_effects(1,b.player_owner) # 大本营再升一级：升二级已让新兵携带 +400，本级再 +400
	assert(troop.hp==float(troop.maxhp)+800.0 and troop.tech_hp_bonus==800 and troop.hp>troop.maxhp)
	troop.hp=300.0 # 升级后受伤再登船
	assert(b.commands._attach_to_ship(troop,ship) and ship.carry_n==16)
	var upgraded_boarding:=snapshot()
	assert(b.saver.apply_snapshot(upgraded_boarding),"R01: 升级后登船的快照必须可恢复")
	troop=find(troop_uid);ship=find(ship_uid)
	assert(troop.attached and troop.hp==300.0 and troop.maxhp==100.0 and troop.tech_hp_bonus==800.0)
	# 船内升级（大本营升四级，科技等级再 +1）后仍可存读。
	b.commands._apply_tech_effects(2,b.player_owner)
	assert(troop.hp==700.0 and troop.tech_hp_bonus==1200.0 and troop.hp>troop.maxhp)
	assert(b.saver.apply_snapshot(snapshot()),"R01: 船内升级后的快照必须可恢复")
	troop=find(troop_uid);ship=find(ship_uid)
	assert(troop.attached and troop.hp==700.0 and troop.tech_hp_bonus==1200.0)
	var invalid_hp: Dictionary=snapshot()
	var bad: Dictionary=invalid_hp.units.filter(func(u):return int(u.uid)==troop_uid)[0]
	bad.hp=99999.0;bad.simulation.tech_hp_bonus=0.0
	assert(not b.saver.apply_snapshot(invalid_hp),"R01: 超出基础上限+科技加成的 HP 必须拒绝")
	# 未升级部队（对照组）同样能登船读档。
	b.commands._kill(find(troop_uid));assert(ship.carry_n==15)
	var plain:=spawn(32,b.nav.anchor_of(troop_cell.x,troop_cell.y))
	var plain_uid:=int(plain.uid)
	assert(b.commands._attach_to_ship(plain,ship) and ship.carry_n==16)
	assert(b.saver.apply_snapshot(snapshot()));ship=find(ship_uid);plain=find(plain_uid)
	assert(plain.attached and plain.hp==plain.maxhp+1200.0) # 对照：新兵同样带满科技当前 HP
	b.commands._kill(plain);assert(ship.carry_n==15)
	print("TRANSPORT TECH-HP PASS upgraded hp>maxhp boards / damaged / in-cargo upgrade / inflight HP rejected")
	ship.carry_n=0;ship.carry_hp=0 # 旧派生计数即使漂移，沉船也按真实关联清理。
	b.commands._kill(ship)
	assert(ship.carry_n==0 and ship.carry_hp==0 and not ship.loaded)
	assert(people.slice(0,16).all(func(uid):return find(uid).die_t>=0 and find(uid).attached and find(uid).aboard_uid==-1))
	# 先清船尸体再保存，仍可恢复全部隐藏的死亡载员且不复活。
	b.commands._free_unit_at(b.units.find(ship))
	var sunk:=snapshot();assert(b.saver.apply_snapshot(sunk))
	assert(people.slice(0,16).all(func(uid):return find(uid).die_t>=0 or not find(uid).alive))
	print("TRANSPORT SNAPSHOT PASS v8 manifest atomic / legacy v7 summary rebuilt / HQ HP sync / passenger death / sink all / ship removed / no resurrection")
	# 所有11张有初始水军的地图都跑岸边装载/卸载与存读，不将单图测试称为全水战通关。
	for map_id in MAPS:
		open_battle(map_id);pair=shore_pair();sea=pair[0];land=pair[1]
		ship=spawn(47,b.nav.anchor_of(sea.x,sea.y));ship_uid=int(ship.uid)
		var unit:=spawn(32,b.nav.anchor_of(land.x,land.y));var uid: int=unit.uid
		b.selected=[unit];assert(b.commands._order_board(ship)==1);b.commands._step_unit(unit,b.SIM_DT)
		assert(unit.attached and b.saver.apply_snapshot(snapshot()))
		ship=find(ship_uid);unit=find(uid)
		assert(b.commands._order_unload(ship,b.nav.anchor_of(land.x,land.y))==1)
		for tick in range(4): b.commands._step_unit(ship,b.SIM_DT)
		assert(not unit.attached)
		print("TRANSPORT MAP PASS ",map_id)
	print("TRANSPORT WORLDS PASS 11 naval maps / actual coastline / board / loaded snapshot / unique landing")
	done=true;b.queue_free();await process_frame;quit(0)
