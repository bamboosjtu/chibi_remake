extends SceneTree
## One integration check for the three newly supplied research datasets.
const Growth = preload("res://simulation/systems/officer_progression.gd")
const Combat = preload("res://simulation/systems/combat_rules.gd")
var b: Node2D
var done := false
func _initialize() -> void:
	create_timer(90).timeout.connect(func():
		if not done:quit(1))
	run.call_deferred()
func panel(selection: Array, kind: String, ids: Array) -> void:
	b.selected=selection;b.view.update_panel()
	var state: Dictionary=b.command_rules.describe()
	assert(state.kind==kind and state.ids==ids,"selection variants: "+kind+" "+str(state))
	assert(b.view._panel_specs().map(func(s):return s.id)==ids)
func run() -> void:
	root.get_node("Game").current_map="chibil1"
	b=load("res://main.tscn").instantiate();root.add_child(b)
	b.set_process(false);b.cli_mode=true;b.ai=null
	await process_frame;await process_frame
	b.view.event_view.restore_history();b.player_commands.set_process(false)
	var leader: Dictionary=b.selected[0]
	var workers: Array=b.units.filter(func(u):return u.alive and int(u.owner)==b.player_owner and int(u.unit)==30)
	var worker: Dictionary=workers[0]
	panel([leader],"worker",[16130,16131,16138,16139,16141,16134,16136,16142])
	assert(b.commands.military._command_units().size()==5 and b.commands.economy._selected_workers().size()==4)
	panel([worker],"worker_member",[16130,16136,16142,16146])
	assert(b.commands.military._command_units()==[worker] and b.commands.economy._selected_workers()==[worker])
	b.view.art_sub="hot";b.view.update_panel();assert(b.view.art_sub=="")
	var resource: Dictionary=b.decor_targets.filter(func(o):return int(o.phase)==0)[0]
	assert(b.commands.orders._context_mode(Vector2(resource.ax,resource.ay-30))==2,"member context cannot issue team gathering")
	panel([leader,worker],"worker",[16130,16131,16138,16139,16141,16134,16136,16142])
	assert(b.command_rules.allows_context(16138),"selected commander accepts context gathering for the whole group")
	panel([worker],"worker_member",[16130,16136,16142,16146])
	assert(not b.command_rules.allows_context(16138),"members alone retain their panel limits")
	worker.carry=20;worker.carry_kind="wood"
	panel([worker],"worker_member",[16130,16136,16142,16146])
	var old_wood: float=b.wood
	b.commands.military._return_selected_cargo()
	assert(worker.state=="deliver" and worker.carry==20 and b.wood==old_wood,"return is a delivery order, never instant credit")
	worker.carry=0;worker.carry_kind=""
	b.commands.military._cancel_unit_command(worker)
	assert(b.commands.military._order_disband()==1 and worker.group_officer==-1)
	assert(b.units.has(leader) and int(workers[1].group_officer)==int(leader.officer.index),"member disband only detaches that member")
	panel([worker],"ungrouped",[16130,16144,16145,16142])
	worker.group_officer=leader.officer.index
	assert(b.commands.world._spawn_unit(32,b.player_owner,600,2200,true))
	var soldier: Dictionary=b.units.back()
	panel([soldier],"ungrouped",[16130,16144,16145,16142])
	soldier.group_officer=leader.officer.index
	panel([soldier],"combat_member",[16130,16144,16145,16142])
	assert(b.command_rules.describe().disabled==[16144,16145])
	soldier.group_officer=-1
	var available: Array=b.commands.military.available_officers(b.player_owner)
	assert(not available.is_empty())
	b.commands.military._order_form_up(int(available[0].index))
	var combat_leader: Dictionary=b.selected[0]
	panel([combat_leader],"combat",[16130,16131,16132,16133,16135,16134,16136,16142,16137])
	panel([combat_leader,soldier],"combat",[16130,16131,16132,16133,16135,16134,16136,16142,16137])
	var ship: Dictionary=worker.duplicate();ship.unit=47;ship.officer={};ship.carry_n=0
	panel([ship],"transport",[16130,16143]);assert(b.command_rules.describe().disabled==[16143])
	ship.carry_n=1
	panel([ship],"transport",[16130,16143]);assert(b.command_rules.describe().disabled.is_empty())
	print("SELECTION RESEARCH PASS worker/combat leaders, bound/unbound members, mixed selection, cargo return, transport")
	# Actual slot recall must expose the same leader commands as single selection.
	b.selected=[leader];var leader_ids:Array=b.command_rules.describe().ids
	b.control_groups[7]=[int(workers[1].uid),int(leader.uid),int(worker.uid)]
	assert(b.commands.military._group_recall(7) and b.command_rules.describe().ids==leader_ids)
	var executed:Array=[]
	for mode in [5,10,11]:
		assert(b.player_commands.submit(mode,func():executed.append(int(b.selected[0].uid)))==1)
		b.player_commands.pump();assert(executed.back()==int(leader.uid))
	b.selected=[worker];assert(b.command_rules.describe().kind=="worker_member")
	b.selected=[leader,worker,soldier];assert(b.command_rules.describe().kind in ["combat_member","ungrouped"])
	print("TEAM SLOT COMMAND PASS member-first slot / commander panel / member-only limits / unrelated mixed selection")
	# Compare all 1,170 independently supplied hero/level records against the runtime formulas.
	# The assertion-enabled engine may run beside an exported pack; research
	# fixtures belong to this external test script's repository, not that engine.
	var fixture:String=get_script().resource_path.get_base_dir().path_join("../../research/exp_level/data/heroes.json").simplify_path()
	var heroes: Array=JSON.parse_string(FileAccess.get_file_as_string(fixture)).heroes
	assert(heroes.size()==117)
	for hero in heroes:
		for expected in hero.levels:
			var off: Dictionary={"tier":hero.category,"level":expected.level,"might":hero.wu}
			var unit: Dictionary={"unit":hero.typeId,"officer":off,"attack":hero.type.atkA,"attack_b":hero.type.atkB,"defence":hero.type.defA,"defence_b":hero.type.defB}
			assert(Growth.cell(off).rank==expected.rank and Combat.grade(off)==int(expected.grade))
			assert(b.commands.military._stamina_of(unit)==float(expected.duelStamina))
			assert(Combat.attack(unit)==float(expected.atkA) and Combat.attack(unit,true)==float(expected.atkB))
			assert(Combat.defence(unit)==float(expected.defA) and Combat.defence(unit,true)==float(expected.defB))
	var off: Dictionary={"level":0,"exp":199}
	assert(not Growth.award(off,-1) and off.exp==199)
	assert(Growth.award(off,1) and off.level==1 and off.exp==0)
	off={"level":0,"exp":0}
	assert(Growth.award(off,50000) and off.level==1 and off.exp==49800)
	assert(Growth.award(off,1) and off.level==2 and off.exp==49301,"one promotion per award with overflow retained")
	off={"level":9,"exp":27000};assert(not Growth.award(off,40) and off.exp==27040 and off.level==9)
	# Real kill attribution, successful/failed deposits, and deduplicated building completion.
	leader.officer.level=0;leader.officer.exp=0
	assert(b.commands.world._spawn_unit(32,b.player_owner+1,650,2200,true))
	var victim: Dictionary=b.units.back();victim.last_attacker_uid=worker.uid
	b.commands.military._kill(victim)
	var kill_xp: int=Growth.reward(32).killXp
	assert(int(leader.officer.exp)==kill_xp)
	b.commands.military._kill(victim,worker);assert(int(leader.officer.exp)==kill_xp,"death cannot reward twice")
	var hq: Dictionary=b.units.filter(func(u):return int(u.owner)==b.player_owner and int(u.unit)==0)[0]
	var edge: Vector2=b.commands.orders._edge_point(hq,Vector2(worker.ax,worker.ay),b.DEPOSIT_EDGE_PX)
	worker.ax=edge.x;worker.ay=edge.y;worker.carry=200;worker.carry_kind="wood"
	assert(b.commands.economy._deposit_carry(worker) and int(leader.officer.exp)==kill_xp+1)
	assert(not b.commands.economy._deposit_carry(worker) and int(leader.officer.exp)==kill_xp+1)
	worker.carry=200;worker.carry_kind="food";b.food=b.commands.economy._food_capacity(b.player_owner)
	assert(not b.commands.economy._deposit_carry(worker) and int(leader.officer.exp)==kill_xp+1)
	worker.carry=0;worker.carry_kind=""
	hq.site=true
	for member in workers:member.build_target=hq
	b.commands.economy._complete_site(hq)
	var build_total: int=kill_xp+1+int(Growth.reward(0).killXp)
	assert(int(leader.officer.exp)==build_total)
	b.commands.economy._complete_site(hq);assert(int(leader.officer.exp)==build_total)
	b.rules.apply_effect({"kind":"officer_experience","officer":int(leader.officer.index)+1})
	assert(int(leader.officer.exp)==build_total,"unresolved event parameters do not invent experience")
	leader.hp=333;leader.officer.exp=199
	var defence_before: float=Combat.defence(leader)
	b.rules.apply_effect({"kind":"officer_experience","officer":int(leader.officer.index)+1,"amount":1})
	assert(int(leader.officer.level)==1 and leader.officer.exp==0 and leader.hp==333 and Combat.defence(leader)==defence_before)
	panel([leader],"worker",[16130,16131,16138,16139,16141,16134,16136,16142])
	assert(b.view.classic_panel.values[2].text=="0/500")
	assert(b.commands.session._save_game())
	var saved: Dictionary=root.get_node("Game").load_save()
	assert(b.saver.apply_snapshot(saved))
	leader=b.units.filter(func(u):return int(u.get("officer",{}).get("index",-1))==42)[0]
	assert(leader.officer.level==1 and leader.officer.exp==0 and leader.hp==333 and leader.team_kind=="worker")
	b.selected=[leader];assert(b.commands.military._order_disband()==1)
	b.selected=b.units.filter(func(u):return int(u.owner)==b.player_owner and int(u.unit)==30)
	b.commands.military._order_form_up(42);leader=b.selected[0]
	assert(leader.officer.level==1 and leader.officer.exp==0,"disband and recruit retain officer growth")
	print("OFFICER RESEARCH PASS 1170 reference rows / one-level awards / overflow / cap / kill attribution / deposit / construction / event / no heal / save")
	var briefing=b.view.briefing
	assert(briefing.entries.size()==34)
	for chapter in root.get_node("Game").list_levels():assert(briefing.entries.has(chapter.id))
	# Every indexed chapter must have its own exact title and nonempty briefing.
	for id in briefing.entries:
		var entry: Dictionary=briefing.entries[id]
		assert(str(entry.title)!="" and str(entry.briefing)!="")
	assert(briefing.entries.chibil1.title=="二吕进犯")
	assert(briefing.entries.chibil1.briefing=="曹军距离新野不远，迅速组建一支部队，抵御曹军的进攻。")
	paused=false;briefing.open();assert(paused and briefing.is_open)
	var tick: int=b.sim_tick
	await process_frame;await process_frame
	assert(b.sim_tick==tick)
	var key:=InputEventKey.new();key.keycode=KEY_ENTER;key.pressed=true
	briefing._input(key);assert(not paused and not briefing.is_open)
	b.view.battle_menu.open();b.view.battle_menu.show_mission()
	assert(briefing.is_open and paused);briefing.close();assert(paused)
	b.view.battle_menu.close();assert(not paused)
	b.view.opening_pending=true;b.view._intro_finished()
	assert(briefing.is_open and paused,"movie completion opens the mission briefing")
	briefing.close()
	print("STARTUP RESEARCH PASS 34 texts / exact opening / paused mission / menu reopen / movie handoff")
	b.control_groups[9]=[int(leader.uid)]
	for member in b.units:
		if int(member.get("group_officer",-1))==int(leader.officer.index) and int(member.owner)==b.player_owner:b.control_groups[9].append(int(member.uid))
	b.commands.military._kill(leader)
	assert(leader.die_t==0 and b.commands.military.control_group_size(9)==0 and not b.commands.military._group_recall(9))
	print("DEAD TEAM SLOT PASS lethal tick releases automatic and member slots before corpse cleanup")
	b.free();done=true;quit()
