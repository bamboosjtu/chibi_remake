extends RefCounted
## bootstrap: composed battle behavior.
const State = preload("res://simulation/battle_state.gd")
const Config = preload("res://simulation/battle_config.gd")
const Dependencies = preload("res://app/battle/ports/bootstrap_dependencies.gd")
var battle: State:
	get: return node.state
var ports := Dependencies.new()
const SceneServices = preload("res://app/battle_scene_state.gd")
var scene: SceneServices
var node: Node2D
const RemasterArt = preload("res://presentation/battle/art_catalog.gd")
const SaveSvc = preload("res://app/save_service.gd")    # ARCH-006：存档/读档编排
const View = preload("res://presentation/battle/battle_view.gd")        # ARCH-013：表现层（HUD/相机/单位外观/框选）

func _init(data: State, services: SceneServices, surface: Node2D) -> void:
	scene = services
	node = surface

func _ready() -> void:
	battle.command_rules=preload("res://simulation/systems/command_rules.gd").new(node)
	battle.player_commands = preload("res://simulation/systems/player_commands.gd").new(node)
	var command_pump := preload("res://app/command_pump.gd").new(node)
	node.add_child(command_pump)
	battle.player_commands.commands_applied.connect(func():
		if scene.view != null:scene.view.update_panel())
	node.get_window().title = "三国赤壁 · 高清重制"
	node.get_tree().set_auto_accept_quit(false)
	battle.map_id = Game.current_map
	var args := OS.get_cmdline_user_args()
	var want_view := true
	for a in args:
		if a.begins_with("--map="):
			battle.map_id = a.substr(6).to_lower()
		elif a.begins_with("--simtest="):
			battle.simtest_seconds = maxf(0.1, float(a.substr(10)))
			# ARCH-013 验收：模拟必须能**没有任何渲染节点**地跑完 → 默认不建表现层
			want_view = false
		elif a == "--noview":
			want_view = false
		elif a == "--view":
			want_view = true
	if "--demo" in args or "--selftest" in args:
		seed(0)                 # R4：回归测试要可复现
	if "--demo" in args or "--selftest" in args or "--screenshot" in args:
		# 自动化模式：_edge_scroll 会因鼠标停在窗口边缘而持续平移相机，
		# 导致同一条命令每次截到不同位置。测试模式下直接关掉。
		battle.cli_mode = true
	if "--load" in args:
		Game.pending_load = true    # 供自动化验证读档路径（等价于点菜单的「读取进度」）

	var f := FileAccess.open("res://data/%s.json" % battle.map_id, FileAccess.READ)
	if f == null:
		ports._fatal("缺少 data/%s.json\n\n请先导出关卡数据：\nnode tools/godot_export.mjs godot/chibi_remake --map %s" % [battle.map_id, battle.map_id.to_upper()])
		return
	battle.map_data = JSON.parse_string(f.get_as_text())
	if battle.map_data == null or not (battle.map_data is Dictionary):
		ports._fatal("data/%s.json 解析失败（文件损坏？）" % battle.map_id)
		return

	if not preload("res://simulation/systems/unit_rules.gd").apply_definitions(battle.map_data):
		ports._fatal("单位定义或生产数据损坏")
		return
	preload("res://simulation/systems/building_rules.gd").apply_definitions(battle.map_data)
	node.world.set_definition(battle.map_data)

	Game.current_map = battle.map_id
	_apply_scenario()          # ARCH-007：玩家归属/初始资源来自 BATTLE.EXP
	battle.nav.setup(battle.map_data)        # ARCH-006：瓦片尺寸 + A* 网格都归 nav.gd 管（原来在 _build_astar）
	battle.visibility.setup(Vector2(float(battle.map_data.terrainW), float(battle.map_data.terrainH)))

	# R7：归属过滤键从数据里实际出现的归属建立，不再假设只有 0..4
	for ob in battle.map_data.get("objects", []):
		battle.sec_visible[int(ob.owner)] = true
	if battle.sec_visible.is_empty():
		for i in range(5):
			battle.sec_visible[i] = true

	# ARCH-013：表现层（HUD/相机/单位外观/框选）在 battle_view.gd 里。
	# ⚠️ 必须在这里就先建好：地形、单位、HUD 的节点都挂在它下面。
	# --simtest / --noview 下**一个渲染节点都不建** —— 那样跑出来的状态摘要才叫纯模拟。
	if want_view:
		scene.view = View.new(node)
		node.add_child(scene.view)

	scene.sfx = preload("res://presentation/audio/sfx.gd").new()
	node.add_child(scene.sfx)
	scene.bgm = preload("res://presentation/audio/bgm.gd").new()
	node.add_child(scene.bgm)
	scene.bgm.play("res://media/music/record01.ogg")
	ports._build_terrain()
	_build_units()
	ports._rebuild_unit_index()          # R13：开局一次建索引
	battle.nav.rebuild_buildings(battle.units)
	ports._update_gates()
	ports._build_decor_targets()
	ports._resolve_navigation_overlaps()
	_build_train_types()
	_build_build_types()
	_load_officers()
	_assign_officers()
	for unit in battle.units:
		if not unit.get("officer",{}).is_empty():unit.team_kind=battle.command_rules.team_kind(unit)
	battle.visibility.update(battle.units, battle.player_owner)
	# 新战场先选中已组建的我方部队，让人物和指令在开局即可见；不改编制。
	if not Game.pending_load:
		for u in battle.units:
			if int(u.owner) == battle.player_owner and not u.get("officer", {}).is_empty():
				battle.selected = [u]
				for member in battle.units:
					if member.group_officer == int(u.officer.index) and member.owner == battle.player_owner: battle.selected.append(member)
				break
		# 开局第一支队伍占据编队 1；左缘 1 号格与数字键 1 直接呼出。
		if not battle.selected.is_empty():
			ports._group_assign(1)
			battle.selected=[battle.selected[0]]
	battle.rules = preload("res://simulation/systems/scenario_rules.gd").new(node)
	battle.terrain_base = battle.map_data.get("terrainWalkable", battle.map_data.walkable).duplicate()
	battle.ai = preload("res://simulation/systems/ai.gd").new(node)
	scene.saver = SaveSvc.new(node)  # ARCH-006：存档编排在 save_service.gd（与 ai.gd 同样的鸭子类型宿主）
	var had_pending_load := bool(Game.pending_load)
	if Game.pending_load:
		if not ports._apply_save():
			Game.pending_load = false
			Game.last_load_error = "存档无法恢复：内容版本不匹配或文件已损坏。原档已保留，请回到主菜单重新选择。"
			node.call_deferred("_return_to_menu_after_load_failure")
			return
		Game.pending_load = false
		Game.pending_load_slot = 0
	# AI was initialized before snapshot restore. # ARCH-006：AI 逻辑在 ai.gd，main 只提供状态访问
	ports._build_ui()
	ports._setup_camera()
	if scene.view != null:
		scene.view.completion = preload("res://presentation/hud/battle_completion.gd").new(scene.view.host)
		scene.view.add_child(scene.view.completion)
		if battle.game_end != 0: ports._show_end(battle.game_end)
	# 章节开场过场：读档进入、测试模式与 --no-intro 时跳过（battle_view 内再判一次参数）。
	if scene.view != null and not had_pending_load:
		scene.view.maybe_play_intro(battle.map_data)

	print("Chibi RTS: %s terrain %dx%d units=%d player=%d" % [battle.map_id, int(battle.map_data.terrainW), int(battle.map_data.terrainH), battle.units.size(), battle.player_owner])

	# ARCH-013 验收证据：没有表现层时，场景树里不该有任何渲染节点（CanvasItem）
	var render_nodes := 0
	for n in node.find_children("*", "", true, false):
		if n is CanvasItem:
			render_nodes += 1
	print("ARCH-013: view=%s  CanvasItem节点=%d  units=%d" % [str(scene.view != null), render_nodes, battle.units.size()])

	# ARCH-012：导出的 exe 是 GUI 子系统，父进程拿不到 stdout，
	# 所以冒烟测试把结论写进文件，构建脚本检查文件而不是控制台输出。
	if "--smoketest" in args:
		ports._write_smoke(true, "loaded")
		node.get_tree().quit()
		return
	for argument in args:
		if argument.begins_with("--native-save="):
			await preload("res://testing/native_save_acceptance.gd").new().run(node, argument.substr(14))
			return

	if "--demo" in args:
		ports._demo()
		return
	if "--diag-nav" in args:
		await node.get_tree().create_timer(0.5).timeout
		preload("res://testing/navigation_checks.gd").new(node, null)._diag_nav()
		node.get_tree().quit(0)
		return
	if "--selftest" in args:
		await preload("res://testing/battle_selftest.gd").new(node).run()
		return
	if "--screenshot" in args:
		await node.get_tree().create_timer(1.2).timeout
		await ports._screenshot()
		node.get_tree().quit()

func _apply_scenario() -> void:
	var sc = battle.map_data.get("scenario", null)
	if not (sc is Dictionary) or not sc.has("sides"):
		push_warning("scenario: 本图未在 BATTLE.EXP 中定义 → 使用原型规则")
		return
	var sides: Array = sc.get("sides", [])
	if sides.is_empty():
		return
	battle.scenario_source = "battle.exp"
	battle.scenario_mission = int(sc.get("missionId", -1))
	battle.scenario_avi = str(sc.get("avi", ""))
	battle.scenario_sides = sides
	battle.player_owner = int((sides[0] as Dictionary).get("owner", battle.player_owner))
	var res: Array = (sides[0] as Dictionary).get("resources", [])
	if res.size() >= 4:
		battle.gold = float(res[0]); battle.food = float(res[1]); battle.wood = float(res[2]); battle.stone = float(res[3])
	print("scenario: mission %d  player=owner %d  sides=%s  res=%.0f/%.0f/%.0f/%.0f  avi=%s" % [
		battle.scenario_mission, battle.player_owner, str(sides.map(func(x): return int(x.owner))),
		battle.gold, battle.wood, battle.food, battle.stone, battle.scenario_avi])

func _build_units() -> void:
	var idx := 0
	for ob in battle.map_data.objects:
		var u := ports._make_unit(ob, true)
		u["map_index"] = idx          # 地图对象在 objects 里的序号，存档配对用
		idx += 1
		battle.units.append(u)

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
		battle.train_types.append({
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
	battle.build_types.clear()
	var variant := 0 if str(battle.map_data.get("scenario", {}).get("avi", "")).to_lower().begins_with("liu") else 1
	for u in battle.units:
		if u.owner == battle.player_owner and int(u.unit) in [0, 1]:
			variant = int(u.unit)
			break
	# 第一期菜单依研究顺序；第二页保留已支持的防御，并开放车兵所/船坞。
	for kind in [0,10,4,2,23,12,6,14,8,18,26,20]:
		var bid: int = kind + variant if kind < 16 or kind == 18 else kind
		var meta: Dictionary = battle.map_data.units.get(str(bid), {})
		if meta.is_empty() or ports._sheet_ref_for(bid, battle.player_owner) == "": continue
		var costs: Array = meta.get("costs", [0, 0, 0])
		battle.build_types.append({"unit": bid, "name": str(meta.get("name", "?")), "gold": float(costs[0]), "wood": float(costs[1]), "food": float(costs[2]), "stone": float(meta.get("costStone", 0))})
	print("build types: ", battle.build_types)

func _load_officers() -> void:
	var f := FileAccess.open("res://data/db/officers.json", FileAccess.READ)
	if f == null:
		push_warning("data/db/officers.json 缺失 —— 武将不会参与战斗")
		return
	var d = JSON.parse_string(f.get_as_text())
	f.close()
	if not (d is Dictionary) or not d.has("blocks"):
		push_warning("data/db/officers.json 解析失败")
		return
	for blk in d.blocks:
		battle._officer_pool[int(blk.get("faction", 0)) - 1] = blk.get("officers", [])
	var n := 0
	for arr in battle._officer_pool:
		n += (arr as Array).size()
	# OPENING-FORCES：档次0保留默认；正档次转换为等级，前33将的零等级默认5。
	for side in battle.scenario_sides:
		var roster: Array = side.get("roster", [])
		var ranks: Array = side.get("ranks", [])
		for i in range(mini(roster.size(), ranks.size())):
			var officer := ports._officer_by_index(int(roster[i]) - 1)
			if not officer.is_empty() and int(ranks[i]) > 0:
				officer.level = clampi(int(ranks[i]) - 1, 0, 9)
	for block in battle._officer_pool:
		for officer in block:
			if int(officer.index) < 33 and int(officer.get("level", 0)) == 0: officer.level = 5
	battle._officer_initial_state = ports._officer_pool_state()
	print("officers loaded: %d in %d blocks" % [n, battle._officer_pool.size()])

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
			var o := ports._officer_by_index(int(roster[k]) - 1)
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
			var initial := ports._officer_by_index(officer_id)
			if initial.is_empty(): continue
			var hero_type := int(initial.get("heroType", -1))
			if hero_type < 0: continue
			# FUN_0045d810 → FUN_00442e40 另申请将领槽；保留四名工人。
			if ports._spawn_unit(hero_type, owner, float(soldier.ax), float(soldier.ay), true):
				var hero: Dictionary = battle.units.back()
				ports._attach_officer(hero, initial.duplicate())
				hero.A = soldier.A; hero.B = soldier.B
				formed[officer_id] = true
		var member_counts := {}
		for soldier in us:
			var native_id := int(soldier.get("tail_value", 0))
			var index := native_id - 1
			if formed.has(index) and int(member_counts.get(index, 0)) < Config.TEAM_MAX_MEMBERS:
				soldier["group_officer"] = index
				member_counts[index] = int(member_counts.get(index, 0)) + 1
		print("officers: MED 开局编制 %d 队；战役可用名单 %d 人" % [formed.size(), officers.size()])
		battle.officer_policy = "battle.exp"
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
			ports._attach_officer(us2[i], o2)
		if battle.officer_policy == "none":
			battle.officer_policy = "prototype"
	print("officers assigned (policy=%s): %s" % [battle.officer_policy, str(by_owner.keys())])
