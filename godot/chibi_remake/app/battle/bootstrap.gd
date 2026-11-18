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
const SaveSvc = preload("res://app/save_service.gd")    # ARCH-006：存档/读档编排
const View = preload("res://presentation/battle/battle_view.gd")        # ARCH-013：表现层（HUD/相机/单位外观/框选）

func _init(services: SceneServices, surface: Node2D) -> void:
	scene = services
	node = surface

func _ready() -> void:
	if not Game.startup_valid:
		node.set_process(false); return
	_initialize_session()
	battle.map_id = Game.current_map
	var args := OS.get_cmdline_user_args()
	var want_view := true
	for a in args:
		if a.begins_with("--map=") and not Game.startup_map_consumed:
			battle.map_id = a.substr(6).to_lower()
			Game.startup_map_consumed = true
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
	if "--load" in args and not Game.startup_load_consumed:
		Game.pending_load = true    # 供自动化验证读档路径（等价于点菜单的「读取进度」）
		Game.startup_load_consumed = true
	var opening := preload("res://app/battle/battle_opening.gd").new(node.world)
	var map_error := opening.prepare_map(battle.map_id)
	if not map_error.is_empty():
		ports._fatal(map_error)
		return
	Game.current_map = battle.map_id

	# R7：归属过滤键从数据里实际出现的归属建立，不再假设只有 0..4
	for ob in battle.map_data.get("objects", []):
		scene.sec_visible[int(ob.owner)] = true
	if scene.sec_visible.is_empty():
		for i in range(5):
			scene.sec_visible[i] = true

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
	if not opening.populate(not Game.pending_load):
		ports._fatal("地图实体已经初始化")
		return
	if scene.view!=null and DisplayServer.get_name()!="headless":battle.nav.warm_runtime_shapes()
	scene.saver = SaveSvc.new(node)  # ARCH-006：存档编排在 save_service.gd（与 ai.gd 同样的鸭子类型宿主）
	var had_pending_load := bool(Game.pending_load)
	if Game.pending_load:
		if not ports._apply_save():
			Game.pending_load = false
			Game.pending_load_slot = 0
			Game.last_load_error = scene.saver.last_load_error + " 原档已保留，请重新选择。"
			ports._schedule_failed_load_return()
			return
		Game.pending_load = false
		Game.pending_load_slot = 0
	# AI was initialized before snapshot restore. # ARCH-006：AI 逻辑在 ai.gd，main 只提供状态访问
	ports._build_ui()
	ports._setup_camera()
	scene.ready_to_save = true
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
		_run_smoke()
		return
	for argument in args:
		if argument.begins_with("--native-save="):
			await load("res://testing/native_save_acceptance.gd").new().run(node, argument.substr(14))
			return

	if "--demo" in args:
		ports._demo()
		return
	if "--diag-nav" in args:
		await node.get_tree().create_timer(0.5).timeout
		load("res://testing/navigation_checks.gd").new(node, null)._diag_nav()
		node.get_tree().quit(0)
		return
	if "--selftest" in args:
		await load("res://testing/battle_selftest.gd").new(node).run()
		return
	if "--screenshot" in args:
		await node.get_tree().create_timer(1.2).timeout
		await ports._screenshot()
		node.get_tree().quit()

func _initialize_session() -> void:
	node.get_window().title = "三国赤壁 · 高清重制"
	node.get_tree().set_auto_accept_quit(false)

func _run_smoke() -> void:
	var before: int=battle.sim_tick
	node.commands.world._sim_step(Config.SIM_DT)
	var valid: bool=battle.sim_tick==before+1 and battle.game_end==0
	ports._write_smoke(valid,"initialized and advanced one live tick" if valid else "initial simulation ended or did not advance")
	node.get_tree().quit(0 if valid else 1)
