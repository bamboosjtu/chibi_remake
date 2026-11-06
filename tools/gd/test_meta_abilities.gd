extends SceneTree
const Config = preload("res://simulation/battle_config.gd")
var b: Node2D
var game: Node
var officer: Dictionary
var template: Dictionary

func _initialize() -> void:
	run.call_deferred()

func fixture() -> void:
	if b != null: b.free()
	game.current_map = "chibil1"
	b = load("res://main.tscn").instantiate()
	root.add_child(b)
	b.set_process(false)
	b.cli_mode = true
	b.ai = null
	if template.is_empty():
		template = b.map_data.units.duplicate(true)
		officer = b.selected[0].officer.duplicate(true)
	while not b.units.is_empty(): b.commands._free_unit_at(b.units.size()-1)
	var land: Array = []
	land.resize(60*120); land.fill(1)
	b.map_data = {"rows":60,"cols":120,"tileW":44,"terrainW":2684,"terrainH":2684,"walkable":land,"terrainWalkable":land.duplicate(),"units":template.duplicate(true),"objects":[],"decor":[],"navigation":{}}
	b.terrain_base = land.duplicate()
	b.nav.setup(b.map_data)
	b.visibility.setup(Vector2(2684,2684))
	b.decor_targets.clear(); b.decor_cells.clear(); b.trainings.clear(); b.selected=[]
	b.gold=10000; b.wood=10000; b.food=10000; b.stone=10000

func spawn(kind: int, cell: Vector2i, owner := 2) -> Dictionary:
	var point: Vector2 = b.nav.anchor_of(cell.x,cell.y)
	assert(b.commands._spawn_unit(kind,owner,point.x,point.y,true))
	return b.units.back()

func hero(cell: Vector2i, index := 42) -> Dictionary:
	var unit := spawn(29,cell)
	var data := officer.duplicate(true)
	data.index=index; data.level=9
	b.commands._attach_officer(unit,data)
	unit.mou=1000
	return unit

func key(code: int, unicode := 0, control := false) -> void:
	var event := InputEventKey.new()
	event.keycode=code; event.unicode=unicode; event.ctrl_pressed=control; event.pressed=true
	root.push_input(event)
	event=event.duplicate(); event.pressed=false
	root.push_input(event)

func type_text(value: String) -> void:
	for character in value: key(character.to_upper().unicode_at(0),character.unicode_at(0))

func snapshot() -> Dictionary:
	assert(game.save_game(b.units,b.commands._resources(),b.commands._save_extra()))
	return game.load_save()

func reference(name: String, file: String) -> Dictionary:
	var directory: String = get_script().resource_path.get_base_dir().path_join("../../research/%s/data/%s.json" % [name,file]).simplify_path()
	return JSON.parse_string(FileAccess.get_file_as_string(directory))

func catalog_contract() -> void:
	var meta := reference("meta","cheats")
	assert(meta.activation.code=="eternal" and meta.activation.requiredPrefix=="etern" and int(meta.activation.matchLength)==5)
	var magics := reference("magics","magics")
	assert(magics.skills.size()==9)
	for skill in magics.skills:
		assert(Config.JIMOU_NAMES[int(skill.order)]==str(skill.name))
		assert(Config.JIMOU_COST[int(skill.order)]==int(skill.cost))
	for level in range(10):
		var mask := int(Config.JIMOU_LV_MASK[mini(level,Config.JIMOU_LV_MASK.size()-1)])
		assert(mask==([0,1,385,449,457,463,495,511,511,511][level]))
	var formations := reference("formation","formations")
	assert(formations.formations.size()==10)
	for row in formations.formations:
		var index := int(row.index)-1
		assert(Config.FORM_NAMES[index]==str(row.name))
		for slot in range(15):
			assert(Config.FORM_OFFSETS[index][slot]==[int(row.slots[slot][0]),int(row.slots[slot][1])])
	print("RESEARCH CATALOG PASS nine skills / costs / unlocks / ten complete15-slot formations")

func console_and_levels() -> void:
	fixture()
	var leader := hero(Vector2i(30,40))
	b.selected=[leader]
	var start_gold: float=b.gold
	key(KEY_F9); assert(b.gold==start_gold and not b.cheats_enabled)
	key(KEY_ENTER); assert(b.cheat_input_open)
	var sequence: int=b.player_commands.sequence
	type_text("ETERNAL"); assert(not b.cheats_enabled)
	key(KEY_ESCAPE); assert(not b.cheat_input_open)
	key(KEY_ENTER); type_text("eeternal"); assert(not b.cheats_enabled,"mismatch must not retry its current character")
	key(KEY_ENTER); key(KEY_ENTER)
	type_text("eter"); assert(not b.cheats_enabled)
	type_text("n"); assert(b.cheats_enabled,"fifth matching character toggles immediately")
	type_text("al"); key(KEY_F9); assert(b.gold==start_gold,"console must consume function keys")
	key(KEY_ENTER); assert(not b.cheat_input_open and b.player_commands.sequence==sequence)
	key(KEY_F9); key(KEY_F9)
	assert(b.gold==start_gold+20000 and b.food==30000 and b.wood==30000 and b.stone==30000)
	var exp: int=int(leader.officer.get("exp",0))
	key(KEY_F4); assert(leader.officer.level==9)
	for i in range(12): key(KEY_F3)
	assert(leader.officer.level==0 and int(leader.officer.get("exp",0))==exp and not b.show_debug)
	key(KEY_F3,0,true); assert(b.show_debug)
	key(KEY_F4); assert(leader.officer.level==1 and b.commands._officer_by_index(42).level==1)
	key(KEY_F5); assert(b.feedback_text.contains("F5"))
	var before: Dictionary=b.commands._resources(); key(KEY_F10); assert(b.commands._resources()==before)
	key(KEY_ENTER); type_text("eternal"); key(KEY_ENTER); assert(not b.cheats_enabled)
	key(KEY_F4); assert(leader.officer.level==1)
	key(KEY_ENTER); type_text("eternaleternal"); assert(b.cheats_enabled,"completed matches still require a mismatch before a new sequence")
	key(KEY_ENTER); key(KEY_ENTER); type_text("eternal"); key(KEY_ENTER); assert(not b.cheats_enabled)
	var levels: Array=[{"map":"a1","campaign":"a"},{"map":"a2","campaign":"a"},{"map":"a3","campaign":"a"},{"map":"b1","campaign":"b"}]
	assert(b.commands._cheat_adjacent_level(levels,"a2",-1)=="a1")
	assert(b.commands._cheat_adjacent_level(levels,"a2",1)=="a3")
	assert(b.commands._cheat_adjacent_level(levels,"a1",-1)=="" and b.commands._cheat_adjacent_level(levels,"a3",1)=="")
	print("META INPUT PASS real viewport input / exact matcher / fifth-char toggle / no command leakage / gated keys / levels0-9 noXP / CtrlF3 / campaign bounds")

func building_shortcut() -> void:
	fixture()
	var leader := hero(Vector2i(28,45))
	var worker := spawn(30,Vector2i(28,47)); worker.group_officer=42
	leader.team_kind="worker"; b.selected=[leader]; b.cheats_enabled=true
	var option: Dictionary=b.build_types.filter(func(o):return int(o.unit)==12)[0]
	assert(b.commands.building_block_reason(12)!="")
	key(KEY_F6)
	assert(b.commands.building_block_reason(12)=="" and b.commands.building_block_reason(12,3)!="")
	assert(b.commands.building_block_reason(999)!="")
	var point: Vector2=b.nav.anchor_of(34,45)
	b.gold=0
	assert(not b.commands._build_site_at(point,option) and b.units.size()==2)
	b.gold=10000
	var before: Dictionary=b.commands._resources()
	assert(b.commands._build_site_at(point,option))
	var cost: Dictionary=b.commands.ai_unit_cost(12)
	for resource in ["gold","wood","food","stone"]: assert(b.commands._resources()[resource]==before[resource]-float(cost.get(resource,0)))
	assert(not b.commands.build_placement_at(point,option).valid,"F6 must preserve occupied-footprint checks")
	key(KEY_F6); assert(b.commands.building_block_reason(12)!="")
	print("META BUILD PASS own prerequisites only / invalid types rejected / insufficient funds / actual payment / occupied footprint remains blocked")

func damage_fog_and_autoplay() -> void:
	fixture()
	var leader := hero(Vector2i(25,40))
	var enemy := spawn(32,Vector2i(40,75),3)
	var idle := spawn(32,Vector2i(28,40))
	var held := spawn(32,Vector2i(29,40)); held.hold=true
	var busy := spawn(32,Vector2i(30,40)); busy.state="move"
	var worker := spawn(30,Vector2i(31,40))
	b.selected=[leader]
	b.cam.position=Vector2.ZERO; key(KEY_P)
	assert(not b.cheats_enabled and b.cam.position!=Vector2.ZERO,"P must work without enabling cheats")
	b.cheats_enabled=true
	b.visibility.update(b.units,b.player_owner)
	var outside := Vector2(enemy.ax,enemy.ay)
	assert(not b.visibility.is_visible(outside))
	var explored: String=b.visibility.snapshot()
	key(KEY_F8); assert(b.visibility.is_visible(outside))
	b.visibility.update(b.units,b.player_owner)
	assert(b.visibility.snapshot()==explored,"map reveal must not permanently explore the map")
	key(KEY_F8); assert(not b.visibility.is_visible(outside))
	key(KEY_F7)
	var hp: float=leader.hp
	b.commands._apply_hit(leader,9999,int(enemy.uid)); assert(leader.hp==hp and leader.alive)
	assert(b.fire_fields.ignite(Vector2(leader.ax,leader.ay)))
	for i in range(5): b.fire_fields.step()
	assert(leader.hp==hp)
	leader.burn_t=1.0; leader.burn_dps=300
	b.commands._step_unit(leader,b.SIM_DT); assert(leader.hp==hp and leader.burn_t<1)
	var enemy_hp: float=enemy.hp
	b.commands._apply_hit(enemy,10,int(leader.uid)); assert(enemy.hp==enemy_hp-10)
	key(KEY_F7); b.commands._apply_hit(leader,10,int(enemy.uid)); assert(leader.hp==hp-10)
	key(KEY_F2); b.sim_tick=41
	b.commands._step_auto_control(); assert(idle.state=="idle","autoplay must respect fog")
	key(KEY_F8); b.commands._step_auto_control()
	assert(idle.state=="attack" and is_same(idle.target,enemy))
	assert(held.state=="idle" and busy.state=="move" and worker.state=="idle")
	print("META RULES PASS reversible fog / no exploration pollution / melee-projectile-fire shared immunity / legacy burn / only own side / idle combat delegation")

func save_controls() -> void:
	var stored := snapshot()
	assert(stored.simulation.autoControl==true and not stored.simulation.has("cheatsEnabled"))
	key(KEY_ENTER); type_text("eter"); assert(b.cheat_input_open)
	var invalid := stored.duplicate(true); invalid.simulation.autoControl="yes"
	var state_id: int=b.state.get_instance_id()
	var old_units: Array=b.units.duplicate()
	assert(not b.saver.apply_snapshot(invalid) and b.units==old_units and b.cheat_input_open)
	b.auto_control=false
	assert(b.saver.apply_snapshot(stored) and b.auto_control and not b.cheat_input_open)
	assert(b.state.get_instance_id()!=state_id and b.visibility.full_reveal and b.cheat_invulnerable==false)
	var legacy := stored.duplicate(true); legacy.simulation.erase("autoControl")
	assert(b.saver.apply_snapshot(legacy) and not b.auto_control)
	assert(not b.commands._save_extra().simulation.has("autoControl"))
	var v3 := stored.duplicate(true); v3.v=3
	b.auto_control=true; key(KEY_ENTER)
	assert(b.cheat_input_open and b.saver.apply_snapshot(v3))
	assert(not b.auto_control and not b.cheat_input_open,"successful legacy loads also reset unsaved delegation and close input")
	print("META SAVE PASS auto flag continuation / optional legacy field / invalid type atomic / session toggles preserved / console closes on commit")

func teams_and_formations() -> void:
	fixture()
	var leader := hero(Vector2i(28,45))
	var members: Array=[]
	for i in range(16):
		var member := spawn(32,Vector2i(32+i%4,45+i*2)); member.group_officer=42; members.append(member)
	var unrelated := spawn(32,Vector2i(40,40))
	var foreign := spawn(32,Vector2i(41,40),3); foreign.group_officer=42
	var attached := spawn(32,Vector2i(42,40)); attached.group_officer=42; attached.attached=true
	var dying := spawn(32,Vector2i(43,40)); dying.group_officer=42; dying.die_t=0
	var inside := spawn(30,Vector2i(44,40)); inside.group_officer=42; inside.site_inside_uid=999
	var expected: Array=[leader]; expected.append_array(members.slice(0,14))
	assert(b.stratagems.target_team(members.back())==expected)
	assert(b.stratagems.target_team(members.back().duplicate(true)).is_empty(),"stale copied entities must be rejected")
	b.selected=[leader,unrelated,foreign,attached,dying,inside]
	var before: Array=[leader.hp,leader.attack,leader.defence,leader.status_173]
	var origin: Vector2i=b.commands._cell_of_px(leader.ax,leader.ay)
	b.commands._set_formation(0)
	assert(leader.fo_x==0 and leader.fo_y==-4 and leader.state=="move")
	assert(b.nav.cell_of_px(leader.path.back().x,leader.path.back().y)==origin+Vector2i(0,-4))
	for i in range(expected.size()):
		assert(expected[i].formation==0 and [int(expected[i].fo_x),int(expected[i].fo_y)]==Config.FORM_OFFSETS[0][i])
	for excluded in [members[14],members[15],unrelated,foreign,attached,dying,inside]: assert(excluded.formation==-1)
	assert([leader.hp,leader.attack,leader.defence,leader.status_173]==before)
	assert(b.commands._formation_target_cell(leader,Vector2i(-100,-100))==Vector2i(3,3))
	assert(b.commands._formation_target_cell(leader,Vector2i(1000,1000))==Vector2i(56,117))
	b.selected=[unrelated]; b.commands._set_formation(2); assert(unrelated.formation==-1)
	b.selected=[leader]; b.game_end=1; b.commands._set_formation(1); assert(leader.formation==0)
	print("FORMATION TEAM PASS canonical commander-first15 / stable clicked-member order / foreign-stale-dead-aboard-interior rejected / immediate leader offset / bounds / no stats / no arbitrary selection")

func farsight_refresh() -> void:
	fixture()
	var caster := hero(Vector2i(28,45))
	caster.vision=1
	b.selected=[caster]
	b.visibility.update(b.units,b.player_owner)
	var remote := Vector2(caster.ax+220,caster.ay)
	assert(not b.visibility.is_visible(remote))
	b.commands._jimou_begin(3)
	b.commands._jimou_cast_at(Vector2(caster.ax,caster.ay-float(caster.h)*0.5))
	assert(caster.farsight_t==800 and caster.mou==900 and b.visibility.is_visible(remote))
	caster.farsight_t=1; caster.hold=true
	b.commands._step_unit(caster,b.SIM_DT); b.visibility.update(b.units,b.player_owner)
	assert(caster.farsight_t==0 and not b.visibility.is_visible(remote))
	assert(b.visibility.effective_vision(caster)==1)
	print("STRATAGEM VISIBILITY PASS immediate cast reveal /800 unit updates / restore base vision / explored memory")

func campaign_keys() -> void:
	fixture()
	current_scene=b
	var previous_id: int=b.get_instance_id()
	key(KEY_BRACKETRIGHT)
	await process_frame
	assert(b.get_instance_id()==previous_id and b.map_id=="chibil1","chapter keys require cheats")
	b.cheats_enabled=true; game.pending_load=true; game.pending_load_slot=1
	key(KEY_BRACKETRIGHT)
	await process_frame; await process_frame; await process_frame
	b=current_scene
	assert(b!=null and b.map_id=="chibil2" and game.current_map=="chibil2")
	assert(not game.pending_load and game.pending_load_slot==0 and not paused)
	assert(not b.cheats_enabled and not b.auto_control and not b.cheat_reveal and b.game_end==0)
	b.set_process(false); b.cli_mode=true; b.cheats_enabled=true
	key(KEY_BRACKETLEFT)
	await process_frame; await process_frame; await process_frame
	b=current_scene
	assert(b!=null and b.map_id=="chibil1")
	b.set_process(false); b.cli_mode=true; b.cheats_enabled=true
	previous_id=b.get_instance_id(); key(KEY_BRACKETLEFT)
	await process_frame
	assert(b.get_instance_id()==previous_id and b.feedback_text.contains("上一关"))
	print("META CAMPAIGN PASS actual bracket scene switch / fresh defaults / pending load cleared / previous chapter / first chapter stays")

func run() -> void:
	game=root.get_node("Game")
	catalog_contract()
	console_and_levels()
	building_shortcut()
	damage_fog_and_autoplay()
	save_controls()
	teams_and_formations()
	farsight_refresh()
	await campaign_keys()
	b.free()
	quit()
