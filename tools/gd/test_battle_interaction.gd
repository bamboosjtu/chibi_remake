extends SceneTree
## 引擎输入级交互回归：命令面板分型（工人组/战斗组）、运输命令、解散、分页组建、
## 小地图点击+拖动、边缘滚屏、资源条与头像对齐。
## 运行方式（verify_candidate.ps1 用打包后的 PCK 跑一遍）：
##   godot --headless --main-pack ChibiRTS.pck --script tools/gd/test_battle_interaction.gd
const Metrics = preload("res://presentation/hud/hud_metrics.gd")
var finished := false
var battle: Node2D
func _initialize() -> void:
	create_timer(60).timeout.connect(func():
		if not finished: quit(1))
	_run.call_deferred()
func _click(point: Vector2) -> void:
	var scale_factor := root.get_final_transform().get_scale()
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.position = point * scale_factor; event.global_position = event.position
		event.button_index = MOUSE_BUTTON_LEFT; event.pressed = pressed
		root.push_input(event, false)
	battle.player_commands.pump()
	battle.view.update_panel()
func _run() -> void:
	root.get_node("Game").current_map = "chibil1"
	battle = load("res://main.tscn").instantiate()
	root.add_child(battle)
	battle.set_process(false); battle.cli_mode = true
	await process_frame; await process_frame
	var view: Node2D = battle.view
	# 四资源采用不相等余额，避免开局数值和图标同时错位却互相掩盖。
	var funds: Dictionary = battle.commands._resources().duplicate()
	battle.gold = 701; battle.food = 702; battle.wood = 703; battle.stone = 704
	view._refresh_res_slots()
	var resource_kinds := ["gold", "food", "wood", "stone"]
	for i in range(4):
		var slot: Dictionary = view.res_slots[i]
		assert(slot.kind == resource_kinds[i] and slot.value.text == str(701 + i))
		var icon: AtlasTexture = slot.icon.texture
		assert(icon.region.position == Vector2(i % 2, i / 2) * icon.region.size)
	battle.gold = funds.gold; battle.food = funds.food; battle.wood = funds.wood; battle.stone = funds.stone
	view._refresh_res_slots()
	print("RESOURCE HUD PASS gold-food-wood-iron / distinct balances / correct atlas quadrants")
	view.event_view.restore_history()
	view.update_panel()
	var hq: Dictionary=battle.units.filter(func(u):return u.owner==battle.player_owner and int(u.unit)==0)[0]
	var captain: Dictionary=battle.selected[0]
	var worker_unit: Dictionary=battle.units.filter(func(u):return int(u.unit)==30 and int(u.owner)==battle.player_owner)[0]
	battle.selected=[hq];battle.commands._update_visual(hq)
	view.update_panel()
	assert(view.classic_panel.portrait.stretch_mode==TextureRect.STRETCH_KEEP_ASPECT_CENTERED,"building portrait shows the complete structure")
	var outline: PackedVector2Array=battle.view.unit_nodes(hq).diamond.points
	var box:=Rect2(outline[0],Vector2.ZERO)
	for point in outline:box=box.expand(point)
	assert(battle.view.unit_nodes(hq).diamond.visible and outline[0]==outline[-1] and box.size.x>=3*44 and box.size.y>=3*22,"headquarters selection follows its 3x3 footprint")
	assert(battle.view.unit_nodes(worker_unit).diamond.points[1].x==22,"unit selection retains its unit footprint")
	battle.selected=[worker_unit]
	print("BUILDING SELECTION PASS footprint-sized outline / closed ground boundary / unchanged unit selection")
	# ---- 工人组面板 + 运输命令（原版 3×3 第 3 格 = 帧 162「运输」）----
	var workers: Array = []
	for u in battle.units:
		if int(u.unit) == 30 and not u.is_building and int(u.owner)==battle.player_owner:
			workers.append(u)
	assert(workers.size() == 4)
	battle.selected = [captain]
	view.update_panel()
	assert(view.panel_kind() == "worker", "选工人队将领本体显示八项指令")
	assert(view.art_buttons[2].btn.visible, "工人组第 3 格（运输）可见")
	_click(view.art_buttons[2].btn.get_global_rect().get_center())
	assert(battle.commands.cmd_pending_kind() == "transport", "点「运输」进入选资源点状态")
	battle.commands._clear_pending()
	battle.commands._order_gather_nearest()
	assert(workers.filter(func(w): return w.state == "gather").size() == 4, "运输命令让 4 名工人进入采集")
	# ---- 战斗组面板 + 解散（第 7 格 = 帧 160「解散」）----
	var hero: Dictionary = {}
	for u in battle.units:
		if int(u.owner) == int(battle.player_owner) and not u.is_building \
				and not (u.get("officer", {}) as Dictionary).is_empty():
			hero = u
			break
	assert(not hero.is_empty(), "开局应有带将部队")
	var hero_idx := int((hero.get("officer", {}) as Dictionary).get("index", -1))
	var hero_name := str((hero.get("officer", {}) as Dictionary).get("name", "")).replace(" ", "")
	var old_uid: int = hero.uid
	battle.selected = [hero]
	view.update_panel()
	assert(view.panel_kind() == "worker", "将领带工人时按麾下成员分型")
	assert(view.art_buttons[6].btn.visible, "战斗组第 7 格（解散）可见")
	_click(view.art_buttons[6].btn.get_global_rect().get_center())
	assert(battle.selected.is_empty(), "解散清空选择（原版模式 6）")
	assert(not battle.commands.officer_in_use(hero_idx), "解散后武将释放")
	for unit in battle.units: assert(unit.uid != old_uid, "将本体已移除")
	for worker in workers: assert(worker.state == "gather", "解散不影响工人的工作命令")
	# ---- 组建：工人组旁的「组建」入口 → 分页名单 → 该武将 ----
	battle.selected = workers.duplicate()
	view.update_panel()
	assert(view._panel_specs().map(func(sp):return sp.cmd)==["move","form","join","board"])
	var form_btn: Control = view.art_buttons[1].btn
	assert(form_btn.visible and not view.worker_button.visible, "独立工人显示原版四项高清命令")
	_click(form_btn.get_global_rect().get_center())
	assert(view.officer_pick and view.cmd_page_count >= 1)
	var officer_button: Button = null
	for page in range(view.cmd_page_count):
		for button in view.cmd_buttons:
			if button.visible and hero_name in button.text:
				officer_button = button
				break
		if officer_button != null:
			break
		_click(view.cmd_next.get_global_rect().get_center())
	assert(officer_button != null, "分页名单里能找到该武将")
	_click(officer_button.get_global_rect().get_center())
	assert(battle.selected.size() == 1 and battle.selected[0].officer.index == hero_idx)
	assert(battle.units.filter(func(u):return int(u.get("group_officer",-1))==hero_idx).size()==4)
	assert(not view.worker_button.visible and not view.officer_pick, "带将队伍不再显示组建入口")
	assert(view.panel_kind() == "worker")
	var panel_count := 0
	for entry in view.art_buttons:
		if entry.btn.visible: panel_count += 1
	assert(panel_count == 8, "重新组建的工人队显示八项原版命令")
	# ---- 点击小地图南端：战场下缘应抵达整图下缘，且不触发地图框选 ----
	var mini: Control = view.minimap
	var map_size := Vector2(float(battle.map_data.terrainW), float(battle.map_data.terrainH))
	var ratio := minf(mini.size.x / map_size.x, mini.size.y / map_size.y)
	var off := (mini.size - map_size * ratio) * 0.5
	_click(mini.global_position + off + Vector2(map_size.x * 0.5, map_size.y - 1) * ratio)
	var visible_world := Metrics.visible_world_rect(battle.cam.position, view.battle_rect(), view.get_viewport_rect().size, battle.cam.zoom)
	assert(is_equal_approx(visible_world.end.y, map_size.y))
	assert(not battle.selecting and not view._minimap_drag and battle.selected.size() == 1)
	# ---- 拖动小地图到北端：须跟随鼠标且在松开后结束捕获 ----
	var scale_factor := root.get_final_transform().get_scale()
	var press := InputEventMouseButton.new()
	press.position = mini.get_global_rect().get_center() * scale_factor
	press.global_position = press.position; press.button_index = MOUSE_BUTTON_LEFT; press.pressed = true
	root.push_input(press, false)
	var motion := InputEventMouseMotion.new()
	motion.position = (mini.global_position + off + Vector2(map_size.x * 0.5, 1) * ratio) * scale_factor
	motion.global_position = motion.position; root.push_input(motion, false)
	press.pressed = false; press.position = motion.position; press.global_position = press.position
	root.push_input(press, false)
	visible_world = Metrics.visible_world_rect(battle.cam.position, view.battle_rect(), view.get_viewport_rect().size, battle.cam.zoom)
	assert(is_zero_approx(visible_world.position.y) and not view._minimap_drag)
	assert(view.edge_direction(Vector2(500, view.get_viewport_rect().size.y - 1)).y > 0, "bottom frame must still scroll")
	assert(view.edge_direction(Vector2(500, 1)).y < 0, "top frame must still scroll")
	assert(view.edge_direction(Vector2(1, 500)).x < 0, "left frame must still scroll")
	assert(view.edge_direction(mini.get_global_rect().get_center()) == Vector2.ZERO)
	var before_scroll: Vector2 = battle.cam.position
	# headless 不维护真实桌面指针：给共享滚屏入口视口坐标，检查完整移动和贴边。
	view.scroll_from_pointer(Vector2(500, view.get_viewport_rect().size.y - 1), 0.5)
	assert(battle.cam.position.y > before_scroll.y, "bottom frame scroll must move camera")
	for slot in view.res_slots:
		assert(slot.panel.get_global_rect().encloses(slot.icon.get_global_rect()))
		assert(slot.panel.get_global_rect().encloses(slot.value.get_global_rect()))
	assert(view.classic_panel.portrait_frame.get_global_rect().encloses(view.classic_panel.portrait.get_global_rect()))
	assert(not view.bottom_tex.visible and not view.panel_bg_tex.visible)
	battle.free()
	root.get_node("Game").current_map = "chibic1"
	battle = load("res://main.tscn").instantiate()
	root.add_child(battle)
	battle.set_process(false); battle.cli_mode = true
	await process_frame; await process_frame
	view = battle.view
	assert(battle.commands._spawn_unit(32, battle.player_owner, 600.0, 2200.0, true), "创建真实步兵测试队伍")
	var fighters: Array = battle.units.filter(func(u): return u.alive and not u.is_building and int(u.owner) == int(battle.player_owner) and int(u.unit) == 32)
	assert(not fighters.is_empty())
	battle.selected = [fighters[0]]
	assert(battle.view.panel_kind()=="ungrouped")
	var available: Array=battle.commands.available_officers(battle.player_owner)
	assert(not available.is_empty())
	battle.commands._order_form_up(int(available[0].index))
	view.update_panel()
	assert(view.panel_kind() == "combat")
	var names: Array = []
	for i in range(9):
		assert(view.art_buttons[i].btn.visible)
		names.append(view.art_buttons[i].btn.get_meta("cmd_name"))
	assert(names == ["移动", "攻击", "警戒", "列阵", "计谋", "休息", "解散", "上船", "单挑"])
	_click(view.art_buttons[3].btn.get_global_rect().get_center())
	assert(view.art_sub == "form", "真实作战组能进入列阵子菜单")
	view._close_art_sub()
	_click(view.art_buttons[4].btn.get_global_rect().get_center())
	assert(view.art_sub == "hot", "真实作战组能进入计谋子菜单")
	print("INTERACTION PASS engine input: worker eight/combat nine, formation+strategy, transport, disband, paginated regroup, minimap click+drag, edge frame, aligned resources+portrait")
	view._close_art_sub()
	# 车兵所同时有生产与研究；弓术已移回木材场，不能再用弓兵所夹具。
	assert(battle.commands._spawn_unit(8,battle.player_owner,600,2200,true))
	var school: Dictionary=battle.units.back()
	battle.gold=100000;battle.wood=100000;battle.food=100000;battle.stone=100000
	battle.selected=[school];assert(battle.commands._start_tech(18));view.update_panel()
	assert(view.cmd_capsules.size()==1 and not view.cmd_capsules.any(func(spec):return bool(spec.get("production",false))))
	assert(not view.cmd_capsules.any(func(spec):return spec.text.begins_with("取消生产")))
	assert(view.cmd_capsules.any(func(spec):return spec.text.begins_with("取消研究") and spec.enabled))
	assert(view.hot_buttons[0].btn.disabled)
	for tick in range(100): battle.commands._process_tech(battle.SIM_DT)
	view.update_panel()
	assert(view.classic_panel.progress_bar.visible and view.classic_panel.progress_bar.value==50)
	assert(view.classic_panel.work_icon.visible)
	assert(battle.commands._cancel_tech() and battle.commands._queue_train(battle.player_owner,school,34));view.update_panel()
	assert(view.cmd_capsules.any(func(spec):return spec.text.begins_with("取消生产") and spec.enabled))
	assert(not view.cmd_capsules.any(func(spec):return spec.text.begins_with("取消研究")))
	assert(view.cmd_capsules.size()==1 and not view.cmd_capsules.any(func(spec):return spec.text==battle.commands.tech_row(18).name))
	print("BUILDING WORK HUD PASS training and research disabled while busy / matching cancel only / hotkey agrees")
	battle.free(); finished = true; quit()
