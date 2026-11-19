extends Object
var view_microseconds := 0
var hud_microseconds := 0
var interpolation_microseconds := 0
## scene controller: composed battle behavior.
const State = preload("res://simulation/battle_state.gd")
const Config = preload("res://simulation/battle_config.gd")
var battle: State:
	get: return node.state
var _dep_battle_simulation: Object
var _dep_cheat_controller: Object
var _dep_combat: Object
var _dep_command_groups: Object
var _dep_harvest_orders: Object
var _dep_selection: Object
var _dep_world_orders: Object
const SceneServices = preload("res://app/battle_scene_state.gd")
var scene: SceneServices
var node: Node2D
const View = preload("res://presentation/battle/battle_view.gd")        # ARCH-013：表现层（HUD/相机/单位外观/框选）

func _init(services: SceneServices, surface: Node2D) -> void:
	scene = services
	node = surface







func _write_smoke(ok: bool, why: String) -> void:
	var f := FileAccess.open("user://smoke.json", FileAccess.WRITE)
	if f == null:
		push_warning("smoke: 无法写入 user://smoke.json")
		return
	f.store_string(JSON.stringify({
		"ok": ok, "why": why, "map": battle.map_id,
		"units": battle.units.size(), "mission": battle.scenario_mission,
		"player": battle.player_owner, "scenarioSource": battle.scenario_source,
		"officerPolicy": battle.officer_policy,
	}))
	f.close()

func _fatal(msg: String) -> void:
	# B5：加载失败时给出可读的错误界面，而不是白屏 + 之后空指针崩溃
	push_error(msg)
	_write_smoke(false, msg)
	var layer := CanvasLayer.new()
	node.add_child(layer)
	var bg := ColorRect.new()
	bg.color = Color(0.10, 0.02, 0.02, 1.0)
	bg.size = Vector2(1600, 900)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(bg)
	var lb := Label.new()
	lb.position = Vector2(60, 60)
	lb.add_theme_font_size_override("font_size", 26)
	lb.add_theme_color_override("font_color", Color(1.0, 0.8, 0.6))
	lb.text = "加载失败\n\n" + msg
	lb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(lb)
	scene.cam = Camera2D.new()        # 让 _input/_process 的 null 保护有对象可依，避免再崩
	node.add_child(scene.cam)
	scene.cam.make_current()
	# CLI 场景下让错误界面也能被截图，便于自动化验证
	if "--screenshot" in OS.get_cmdline_user_args():
		await node.get_tree().create_timer(0.6).timeout
		await _screenshot()
		node.get_tree().quit()
	elif "--smoketest" in OS.get_cmdline_user_args():
		node.get_tree().quit()      # 冒烟测试：结论已落盘(ok=false)，立即退出而不是干等

func _build_terrain() -> void:
	# ARCH-013：地形是纯 Sprite2D 工厂，归 battle_view.gd
	if scene.view != null:
		scene.view.build_terrain()

func _sheet(p: String) -> Texture2D:
	if scene.view == null:
		return null
	return scene.view.unit_visuals._sheet(p)

func _apply_save() -> bool:
	return scene.saver.apply()

func _save_extra() -> Dictionary:
	return scene.saver.save_extra()


func _return_to_menu_after_load_failure() -> void:
	if node.is_inside_tree():
		Game.return_to_menu()

func _schedule_failed_load_return() -> void:
	scene.ready_to_save = false
	node.set_process(false)
	node.set_process_unhandled_input(false)
	_return_to_menu_after_load_failure.call_deferred()


func _notification(what: int) -> void:
	if what != Node.NOTIFICATION_WM_CLOSE_REQUEST:
		return
	if scene.ready_to_save and scene.saver != null:
		if scene.view != null and scene.view.battle_menu != null:
			await scene.view.battle_menu.open()
			scene.view.battle_menu.quit_game()
			return
		if not await node.session_actions.wait_command_boundary(): return
		if not node.session_actions.save_game():
			node.world.effects.feedback("保存失败，未退出，请重试")
			return
	node.get_tree().quit()

func _unhandled_input(event: InputEvent) -> void:
	if _dep_cheat_controller.handle_cheat_input(event):
		node.get_viewport().set_input_as_handled()
		return
	if not node.session_actions.waiting_for_commands: _battle_input(event)


func _battle_input(event: InputEvent) -> void:
	if scene.cam == null:
		return                      # B5：加载失败后不要在这里空指针
	if event is InputEventKey or event is InputEventJoypadButton:
		_battle_action(event)
	elif event is InputEventMouseButton:
		var mbe := event as InputEventMouseButton
		if mbe.pressed:
			scene.ev_count += 1
		# 原版不能缩放 —— 滚轮不再改变比例（镜头平移/中键拖拽保留）
		if mbe.pressed and mbe.button_index == MOUSE_BUTTON_WHEEL_UP:
			pass
		elif mbe.pressed and mbe.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			pass
		elif mbe.button_index == MOUSE_BUTTON_MIDDLE:
			scene.drag_pan = mbe.pressed
		elif mbe.button_index == MOUSE_BUTTON_LEFT:
			if mbe.pressed:
				scene.selecting = true
				scene.sel_start = node.get_canvas_transform().affine_inverse() * mbe.position
				scene.sel_end = scene.sel_start
			elif scene.selecting:
				scene.selecting = false
				_marquee_hide()
				var add := Input.is_key_pressed(KEY_SHIFT)
				var world_pos := node.get_canvas_transform().affine_inverse() * mbe.position
				var clicked := scene.sel_start.distance_to(world_pos) <= 7.0
				if clicked and _dep_world_orders.cmd_pending_kind() != "":
					# 原版模型：先点面板按钮、再点地图目标 —— 待选命令用**左键**落到目标上。
					node.actions.submit_point_order(world_pos, false)
				elif not clicked:
					_dep_selection._select_box(_sel_rect(), add)
					_view_hud()
				else:
					# 选中工人队后直接左键资源也下采集令：资源点本来就不能被“选中”，
					# 不应当清空选择让玩家以为点击无效（右键仍然同样生效）。
					var rclick = _dep_harvest_orders._resource_at(world_pos)
					if rclick.is_empty() or bool(rclick.get("is_building",false)) or not node.world.command_rules.allows_context(16138):
						node.actions.select_at(world_pos, add)
					else:
						node.world.player_commands.submit("gather", battle.selected, world_pos, int(rclick.uid), -1, str(rclick.get("cell", "")))
		elif mbe.button_index == MOUSE_BUTTON_RIGHT and mbe.pressed:
			node.actions.submit_point_order(node.get_canvas_transform().affine_inverse() * mbe.position, true)
	elif event is InputEventMouseMotion:
		var mme := event as InputEventMouseMotion
		if scene.drag_pan:
			if not Input.is_mouse_button_pressed(MOUSE_BUTTON_MIDDLE):
				scene.drag_pan = false       # R6：中键在窗口外松开也不会卡住
			else:
				_pan_by(mme.relative)
		elif scene.selecting:
			scene.sel_end = node.get_canvas_transform().affine_inverse() * mme.position
			var r := _sel_rect()
			_marquee_update(r)

func _battle_action(event: InputEvent) -> void:
	if not event.is_pressed() or event.is_echo(): return
	scene.ev_count += 1
	for group in range(1, 10):
		if event.is_action_pressed("battle_assign_group_%d" % group, false, true):
			node.actions.submit_command("assign_group", -1, group)
			return
		if event.is_action_pressed("battle_group_%d" % group, false, true):
			node.actions.focus_group(group)
			return
	if event.is_action_pressed("battle_toggle_buildings"):
		scene.show_buildings = not scene.show_buildings
	elif event.is_action_pressed("battle_toggle_units"):
		scene.show_units = not scene.show_units
	elif event.is_action_pressed("battle_overview"):
		_fit_view()
	elif event.is_action_pressed("battle_pause") or event.is_action_pressed("battle_cancel"):
		if scene.view != null and scene.view.battle_menu != null:
			scene.view.battle_menu.open()
		elif event.is_action_pressed("battle_cancel"):
			node.get_tree().quit()
	elif event.is_action_pressed("battle_confirm"):
		var point := node.get_canvas_transform().affine_inverse() * node.get_viewport_rect().get_center()
		if _dep_world_orders.cmd_pending_kind().is_empty(): node.actions.select_at(point, false)
		else: node.actions.submit_point_order(point, false)
	elif event is InputEventKey:
		if event.keycode == KEY_F3 and event.ctrl_pressed: scene.show_debug = not scene.show_debug
		elif event.keycode == KEY_F12: _screenshot()

func _sel_rect() -> Rect2:
	return Rect2(scene.sel_start, scene.sel_end - scene.sel_start).abs()

func _pan_by(pixels: Vector2) -> void:
	if scene.view != null:
		scene.view.pan_by(pixels)

func _edge_scroll(delta: float) -> void:
	if scene.view != null:
		scene.view.edge_scroll(delta)

func _build_ui() -> void:
	# ARCH-013：HUD 全部交给 battle_view.gd（同名转发，调用点不变）
	if scene.view == null:
		return
	scene.view.build_ui()
	_build_marquee()

func _build_marquee() -> void:
	if scene.view != null:
		scene.view.build_marquee()

func _process(delta: float) -> void:
	# ARCH-013：原来是 `cam == null or info == null` 就 return —— 那样"没有渲染节点"
	# 的模拟（--simtest / --noview）会一步都不推进。现在模拟只依赖模拟数据本身。
	if not battle.map_data.has("terrainW"):
		return
	# 表现层：相机与鼠标反馈用真实 delta（与模拟解耦）
	var view_begin:=Time.get_ticks_usec()
	_view_frame(delta)
	view_microseconds+=Time.get_ticks_usec()-view_begin
	# 模拟层：固定步长推进（ARCH-010）
	battle.sim_acc = battle.sim_acc + delta if battle.game_end == 0 else 0.0
	var steps := 0
	var period: float = node.world.clock.period()
	var target_tick := ceili(battle.simtest_seconds * Config.SIM_HZ) if battle.simtest_seconds > 0.0 else -1
	while battle.game_end == 0 and not node.get_tree().paused and battle.sim_acc + 0.000000001 >= period and steps < Config.SIM_MAX_CATCHUP and (target_tick < 0 or battle.sim_tick < target_tick):
		battle.sim_acc = maxf(0.0,battle.sim_acc-period)
		steps += 1
		_dep_battle_simulation._sim_step(Config.SIM_DT)
	# 达到每帧预算后保留欠下的tick，下一帧继续；不能丢弃计时导致低帧率少结算。
	if target_tick >= 0 and (battle.sim_tick >= target_tick or battle.game_end != 0):
		print("SIMTEST: %.1fs tick=%d digest=%d" % [battle.simtest_seconds, battle.sim_tick, _dep_battle_simulation._state_digest()])
		# The digest module stays free of the scene tree; the app layer supplies
		# the hasher it needs.
		print("SIMULATION DIGESTS: ", JSON.stringify(preload("res://simulation/systems/state_digest.gd").sections(node, node.get_node("/root/Game"))))
		print("SIMULATION FULL DIGEST: ", Game.save_checksum(scene.saver.continuation_snapshot(Game)))
		node.get_tree().quit()
		return
	scene.hud_acc += delta
	if scene.hud_acc >= 1.0 / Config.HUD_HZ:      # R1：文字刷新限频
		scene.hud_acc = 0.0
		if scene.feedback_text != "" and (scene.feedback_until == 0 or scene.feedback_observed != scene.feedback_text):
			scene.feedback_observed = scene.feedback_text
			# 旧实现：只有 _feedback() 设过 feedback_until 的提示才活得过下一帧；
			# 直接赋值（"没有走得到的资源点"/"没有资源点"/"组建完成" 等）会在这里被
			# **立刻清掉** —— 用户实测"点击采集无反应"（提示其实赋了值，只是从未显示）。
			scene.feedback_until = Time.get_ticks_msec() + 2500
		elif scene.feedback_text != "" and Time.get_ticks_msec() > scene.feedback_until:
			scene.feedback_text = ""
		var hud_begin:=Time.get_ticks_usec()
		_view_hud()
		hud_microseconds+=Time.get_ticks_usec()-hud_begin
	if scene.view!=null:
		scene.view.flush_visuals(true)
		var interpolate_begin:=Time.get_ticks_usec()
		scene.view.interpolate_motion(clampf(battle.sim_acc/period,0.0,1.0))
		interpolation_microseconds+=Time.get_ticks_usec()-interpolate_begin

func _view_frame(delta: float) -> void:
	_edge_scroll(delta)              # 相机滚屏（转发到 battle_view）
	_update_hover()

func _view_hud() -> void:
	if scene.view == null:
		return
	scene.view.update_hud_text()
	scene.view.update_panel()

func _marquee_hide() -> void:
	if scene.view != null:
		scene.view.marquee_hide()

func _marquee_update(r: Rect2) -> void:
	if scene.view != null:
		scene.view.marquee_update(r)

func _update_hover() -> void:
	# ARCH-013：悬停文字由表现层写回 main.hover_text（命中测试仍留在 main._hover_unit）
	if scene.view != null:
		scene.view.update_hover()

func _setup_camera() -> void:
	if scene.view == null:
		return
	scene.view.setup_camera()
	scene.cam = scene.view.cam

func _fit_view() -> void:
	if scene.view != null:
		scene.view.fit_view()

func _screenshot() -> void:
	await View.screenshot(node)

func _demo() -> void:
	await node.get_tree().create_timer(0.4).timeout
	var n := 0
	for u in battle.units:
		if u.owner == battle.player_owner and not u.is_building and u.alive:
			var e = _dep_combat._nearest_enemy(u, 99999.0)
			if not e.is_empty():
				u.state = "attack"
				u.target = e
				u.repath = 0.0
				n += 1
	print("DEMO: ordered %d units to attack" % n)
	var t := 0.0
	while t < 60.0:
		await node.get_tree().create_timer(0.5).timeout
		t += 0.5
		var pa := 0
		var ea := 0
		var ph := 0.0
		var eh := 0.0
		for u in battle.units:
			if u.is_building or not u.alive or u.die_t >= 0.0:
				continue
			if u.owner == battle.player_owner:
				pa += 1
				ph += u.hp
			elif u.owner != 0:
				ea += 1
				eh += u.hp
		if int(t * 2.0) % 10 == 0:
			print("DEMO t=%.1f  我军 alive=%d hp=%.0f | 敌军 alive=%d hp=%.0f" % [t, pa, ph, ea, eh])
		# 原版判定还要看建筑与资源，所以这里必须用 game_end 而不是"某一方单位清零"
		if t > 2.0 and battle.game_end != 0:
			break
	print("DEMO DONE t=%.1f" % t)
	node.get_tree().quit()

func bind_dependencies(scene_root: Object) -> void:
	_dep_battle_simulation = scene_root.world.battle_simulation
	_dep_cheat_controller = scene_root.cheat_controller
	_dep_combat = scene_root.world.combat
	_dep_command_groups = scene_root.world.command_groups
	_dep_harvest_orders = scene_root.world.harvest_orders
	_dep_selection = scene_root.world.selection
	_dep_world_orders = scene_root.world.world_orders
