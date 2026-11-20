extends RefCounted
const ScenarioState = preload("res://simulation/scenario/scenario_state.gd")
const OfficerState = preload("res://simulation/officers/officer_state.gd")
const WorldInputs = preload("res://simulation/world/world_inputs.gd")
const CommandState = preload("res://simulation/commands/command_state.gd")
## Map preparation is shared by the live bootstrap and scene-free save candidates.
const World = preload("res://simulation/world/battle_world.gd")
const State = preload("res://simulation/state/battle_state.gd")
const Balance = preload("res://simulation/definitions/balance_rules.gd")
const Config = preload("res://simulation/definitions/battle_config.gd")
const Campaign = preload("res://app/campaign/campaign_session.gd")
var world: World
var battle: State

func _init(source: World) -> void:
	world = source
	battle = source.state

func prepare_map(map_id: String) -> String:
	var path := "res://data/%s.json" % map_id
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return "缺少 " + path
	var data = JSON.parse_string(file.get_as_text())
	if not Campaign.is_level_doc(data):
		return path + " 解析失败或关卡字段缺失"
	if not preload("res://simulation/definitions/unit_rules.gd").apply_definitions(data):
		return "单位定义或生产数据损坏"
	preload("res://simulation/definitions/building_rules.gd").apply_definitions(data)
	WorldInputs.set_map_id(battle, map_id)
	WorldInputs.set_map_data(battle, data)
	world.set_definition(data)
	_apply_scenario()
	world.prepare_map()
	return ""

func populate(opening_selection: bool) -> bool:
	if not world.seed_map_units(): return false
	world.spatial_index._rebuild_unit_index()
	world.nav.rebuild_buildings(battle.units)
	world.battle_simulation._update_gates()
	world.harvest_orders._build_decor_targets()
	world.movement._resolve_navigation_overlaps()
	_build_train_types()
	_build_build_types()
	_load_officers()
	_assign_officers()
	for unit in battle.units:
		if not unit.get("officer", {}).is_empty():
			OfficerState.set_team_kind(unit, world.command_rules.team_kind(unit))
	world.visibility.update(battle.units, battle.player_owner)
	if opening_selection: _select_opening_team()
	ScenarioState.set_terrain_base(battle, battle.map_data.get("terrainWalkable", battle.map_data.walkable).duplicate())
	return true

func _select_opening_team() -> void:
	for unit in battle.units:
		if int(unit.owner) != battle.player_owner or unit.get("officer", {}).is_empty(): continue
		CommandState.replace_selection(battle, [unit])
		for member in battle.units:
			if member.group_officer == int(unit.officer.index) and member.owner == battle.player_owner:
				CommandState.add_selection(battle, member)
		world.command_groups._group_assign(1)
		CommandState.replace_selection(battle, [unit])
		return

func _apply_scenario() -> void:
	var sc = battle.map_data.get("scenario", null)
	if not (sc is Dictionary) or not sc.has("sides"):
		push_warning("scenario: 本图未在 BATTLE.EXP 中定义 → 使用原型规则")
		return
	var sides: Array = sc.get("sides", [])
	if sides.is_empty():
		return
	ScenarioState.set_scenario_source(battle, "battle.exp")
	ScenarioState.set_scenario_mission(battle, int(sc.get("missionId", -1)))
	ScenarioState.set_scenario_avi(battle, str(sc.get("avi", "")))
	ScenarioState.set_scenario_sides(battle, sides)
	WorldInputs.set_player_owner(battle, int((sides[0] as Dictionary).get("owner", battle.player_owner)))
	var res: Array = (sides[0] as Dictionary).get("resources", [])
	if res.size() >= 4:
		world.economy.write_player_resources({"gold": res[0], "food": res[1], "wood": res[2], "stone": res[3]})
	print("scenario: mission %d  player=owner %d  sides=%s  res=%.0f/%.0f/%.0f/%.0f  avi=%s" % [
		battle.scenario_mission, battle.player_owner, str(sides.map(func(x): return int(x.owner))),
		battle.gold, battle.wood, battle.food, battle.stone, battle.scenario_avi])

func _build_train_types() -> void:
	var cnt := {}
	for u in battle.units:
		if u.owner == battle.player_owner and not u.is_building:
			cnt[u.unit] = int(cnt.get(u.unit, 0)) + 1
	var ids := cnt.keys()
	ids.sort_custom(func(a, b): return cnt[a] > cnt[b])
	for i in range(mini(2, ids.size())):
		var meta: Dictionary = battle.map_data.units.get(str(ids[i]), {})
		var c: Array = meta.get("costs", [])
		WorldInputs.append_to_train_types(battle, {
			"unit": int(ids[i]),
			"name": str(meta.get("name", "?")),
			# costs = DATA.EXP 的 3 个造价字段（+0x24/+0x28/+0x2c）。
			# 它们与 4 种资源的一一对应关系尚未定死（REMAKE-GAP #7），先按顺序填入。
			"gold": float(c[0]) if c.size() > 0 else 0.0,
			"wood": float(c[1]) if c.size() > 1 else 0.0,
			"food": float(c[2]) if c.size() > 2 else 0.0,
			"stone": 0.0,
		})
	print("train types: ", battle.train_types)

func _build_build_types() -> void:
	WorldInputs.clear_build_types(battle)
	var variant := 0 if str(battle.map_data.get("scenario", {}).get("avi", "")).to_lower().begins_with("liu") else 1
	for u in battle.units:
		if u.owner == battle.player_owner and int(u.unit) in [0, 1]:
			variant = int(u.unit)
			break
	# 第一期菜单依研究顺序；第二页保留已支持的防御，并开放车兵所/船坞。
	for kind in [0,10,4,2,23,12,6,14,8,18,26,20]:
		var bid: int = kind + variant if kind < 16 or kind == 18 else kind
		var meta: Dictionary = battle.map_data.units.get(str(bid), {})
		if meta.is_empty() or world.entity_factory._sheet_ref_for(bid, battle.player_owner) == "": continue
		var costs: Array = meta.get("costs", [0, 0, 0])
		WorldInputs.append_to_build_types(battle, {"unit": bid, "name": str(meta.get("name", "?")), "gold": float(costs[0]), "wood": float(costs[1]), "food": float(costs[2]), "stone": float(meta.get("costStone", 0))})
	print("build types: ", battle.build_types)

func _load_officers() -> void:
	OfficerState.set_officer_pool(battle, preload("res://app/battle/startup/opening_officers.gd").pool(battle.scenario_sides))
	OfficerState.set_officer_initial_state(battle, world.officer_pool._officer_pool_state())
	print("officers loaded: 117 in %d blocks" % battle._officer_pool.size())

func _assign_officers() -> void:
	var by_owner := {}
	for u in battle.units:
		if u.is_building:
			continue
		if not by_owner.has(u.owner):
			by_owner[u.owner] = []
		by_owner[u.owner].append(u)

	# --- 1) 战役表点名的武将 ---
	for si in range(battle.scenario_sides.size()):
		var side: Dictionary = battle.scenario_sides[si]
		var owner := int(side.get("owner", -1))
		if not by_owner.has(owner):
			continue
		var roster: Array = side.get("roster", [])
		var ranks: Array = side.get("ranks", [])
		if roster.is_empty():
			continue
		var officers: Array = []
		for k in range(roster.size()):
			var o: Dictionary = world.officer_pool._officer_by_index(int(roster[k]) - 1)
			if o.is_empty():
				continue
			var c: Dictionary = (o as Dictionary).duplicate()
			if k < ranks.size():
				c["rank"] = int(ranks[k])
			c["from"] = "battle.exp"
			officers.append(c)
		if officers.is_empty():
			continue
		# MED 尾部保存原版将领编号：同一编号的士兵属于同一队。
		# 不能把战役「可用名单」首位当开局将领（刘备第一关实际为 43=徐庶）。
		var us: Array = by_owner[owner]
		var formed := {}
		for soldier in us:
			var native_id := int(soldier.get("tail_value", 0))
			var officer_id := native_id - 1
			if native_id <= 0 or native_id > 117 or formed.has(officer_id):
				continue
			var initial: Dictionary = world.officer_pool._officer_by_index(officer_id)
			if initial.is_empty(): continue
			var hero_type := int(initial.get("heroType", -1))
			if hero_type < 0: continue
			# FUN_0045d810 → FUN_00442e40 另申请将领槽；保留四名工人。
			# The first member supplies the spawn anchor, not an occupied final cell.
			# Normal placement checks the whole footprint and registers the chosen cell.
			if world.entity_factory._spawn_unit(hero_type, owner, float(soldier.ax), float(soldier.ay)):
				var hero: Dictionary = battle.units.back()
				world.entity_factory._attach_officer(hero, initial.duplicate())
				formed[officer_id] = true
		var member_counts := {}
		for soldier in us:
			var native_id := int(soldier.get("tail_value", 0))
			var index := native_id - 1
			if formed.has(index) and int(member_counts.get(index, 0)) < Balance.team_max_members():
				soldier["group_officer"] = index
				member_counts[index] = int(member_counts.get(index, 0)) + 1
		print("officers: MED 开局编制 %d 队；战役可用名单 %d 人" % [formed.size(), officers.size()])
		OfficerState.set_officer_policy(battle, "battle.exp")
		by_owner.erase(owner)

	# --- 2) 未被战役表覆盖的归属：原型启发式（显式标注） ---
	for owner in by_owner.keys():
		var bi: int = int(Config.OFFICER_BLOCK_FOR_OWNER.get(int(owner), -1))
		if bi < 0 or bi >= battle._officer_pool.size():
			continue
		var roster2: Array = (battle._officer_pool[bi] as Array).duplicate()
		if roster2.is_empty():
			continue
		roster2.sort_custom(func(a, b): return int(a.might) > int(b.might))
		var us2: Array = by_owner[owner]
		for i in range(mini(us2.size(), roster2.size())):
			var o2: Dictionary = (roster2[i] as Dictionary).duplicate()
			o2["from"] = "prototype"
			world.entity_factory._attach_officer(us2[i], o2)
		if battle.officer_policy == "none":
			OfficerState.set_officer_policy(battle, "prototype")
	print("officers assigned (policy=%s): %s" % [battle.officer_policy, str(by_owner.keys())])
