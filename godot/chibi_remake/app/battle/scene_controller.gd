extends RefCounted
## scene controller: composed battle behavior.
const State = preload("res://simulation/battle_state.gd")
const Config = preload("res://simulation/battle_config.gd")
const Dependencies = preload("res://app/battle/ports/scene_controller_dependencies.gd")
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
	return scene.view._sheet(p)

func _apply_save() -> bool:
	return scene.saver.apply()

func _save_extra() -> Dictionary:
	return scene.saver.save_extra()

func _save_game(slot := 0, title := "") -> bool:
	# Dispatch before taking any snapshot, so costs and production belong to the same battle.
	if battle.player_commands != null: battle.player_commands.pump()
	var extra := _save_extra()
	extra.saveName=title
	return Game.save_game(battle.units,ports._resources(),extra,slot)

func _return_to_menu_after_load_failure() -> void:
	if node.is_inside_tree():
		node.get_tree().change_scene_to_file("res://menu.tscn")

func _notification(what: int) -> void:
	if what != Node.NOTIFICATION_WM_CLOSE_REQUEST:
		return
	if scene.saver != null and battle.map_data.has("terrainW") and battle.game_end == 0 and not battle.units.is_empty():
		if scene.view != null and scene.view.battle_menu != null:
			scene.view.battle_menu.open()
			scene.view.battle_menu.quit_game()
			return
		if not _save_game():
			ports._feedback("保存失败，未退出，请重试")
			return
	node.get_tree().quit()

func _unhandled_input(event: InputEvent) -> void:
	if ports.handle_cheat_input(event):
		node.get_viewport().set_input_as_handled()
		return
	battle._input_command = true
	_battle_input(event)
	battle._input_command = false

func focus_group(n: int) -> bool:
	if not ports._group_recall(n):
		return false
	if battle.selected.is_empty():
		return true
	var leader: Dictionary = battle.selected[0]
	if scene.cam != null:
		scene.cam.position = Vector2(float(leader.ax), float(leader.ay))
		if scene.view != null:
			scene.view.clamp_camera()
	return true

func _battle_input(event: InputEvent) -> void:
	if scene.cam == null:
		return                      # B5：加载失败后不要在这里空指针
	if event is InputEventKey and event.pressed and not event.echo:
		battle.ev_count += 1
		# --- 编队（原版左侧 1..10 那条按钮就是干这个的）---
		# Ctrl+数字 = 编入该组；数字 = 呼出该组。
		var _numb := -1
		if event.keycode >= KEY_1 and event.keycode <= KEY_9:
			_numb = event.keycode - KEY_1 + 1
		if _numb > 0:
			if event.ctrl_pressed:
				ports._group_assign(_numb)
				return
			focus_group(_numb)
			return
		match event.keycode:
			KEY_B:
				scene.show_buildings = not scene.show_buildings
			KEY_U:
				scene.show_units = not scene.show_units
			KEY_F:
				_fit_view()
			KEY_F3:
				if event.ctrl_pressed: scene.show_debug = not scene.show_debug
			KEY_M:
				if scene.view != null: scene.view.battle_menu.open()
			KEY_F12:
				_screenshot()          # 协程，这里不 await（截图结果会自己打印）
			KEY_ESCAPE:
				# 战场 Esc = 打开暂停菜单（不直接退出）。退出走菜单里的“保存并退出”，
				# 关窗由 Node.NOTIFICATION_WM_CLOSE_REQUEST 先保存再退。
				if scene.view != null and scene.view.battle_menu != null:
					scene.view.battle_menu.open()
				elif scene.view == null:
					node.get_tree().quit()
	elif event is InputEventMouseButton:
		var mbe := event as InputEventMouseButton
		if mbe.pressed:
			battle.ev_count += 1
		# 原版不能缩放 —— 滚轮不再改变比例（镜头平移/中键拖拽保留）
		if mbe.pressed and mbe.button_index == MOUSE_BUTTON_WHEEL_UP:
			pass
		elif mbe.pressed and mbe.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			pass
		elif mbe.button_index == MOUSE_BUTTON_MIDDLE:
			battle.drag_pan = mbe.pressed
		elif mbe.button_index == MOUSE_BUTTON_LEFT:
			if mbe.pressed:
				battle.selecting = true
				battle.sel_start = node.get_canvas_transform().affine_inverse() * mbe.position
				battle.sel_end = battle.sel_start
			elif battle.selecting:
				battle.selecting = false
				_marquee_hide()
				var add := Input.is_key_pressed(KEY_SHIFT)
				var world_pos := node.get_canvas_transform().affine_inverse() * mbe.position
				var clicked := battle.sel_start.distance_to(world_pos) <= 7.0
				if clicked and ports.cmd_pending_kind() != "":
					# 原版模型：先点面板按钮、再点地图目标 —— 待选命令用**左键**落到目标上。
					ports._order_at(world_pos)
				elif not clicked:
					ports._select_box(_sel_rect(), add)
				else:
					# 选中工人队后直接左键资源也下采集令：资源点本来就不能被“选中”，
					# 不应当清空选择让玩家以为点击无效（右键仍然同样生效）。
					var rclick := ports._resource_at(world_pos)
					if rclick.is_empty() or bool(rclick.get("is_building",false)) or not battle.command_rules.allows_context(16138):
						ports._select_click(world_pos, add)
					else:
						battle.player_commands.submit(7,ports._order_gather.bind(rclick),world_pos,int(rclick.uid))
		elif mbe.button_index == MOUSE_BUTTON_RIGHT and mbe.pressed:
			ports._order_context(node.get_canvas_transform().affine_inverse() * mbe.position)
	elif event is InputEventMouseMotion:
		var mme := event as InputEventMouseMotion
		if battle.drag_pan:
			if not Input.is_mouse_button_pressed(MOUSE_BUTTON_MIDDLE):
				battle.drag_pan = false       # R6：中键在窗口外松开也不会卡住
			else:
				_pan_by(mme.relative)
		elif battle.selecting:
			battle.sel_end = node.get_canvas_transform().affine_inverse() * mme.position
			var r := _sel_rect()
			_marquee_update(r)

func _sel_rect() -> Rect2:
	return Rect2(battle.sel_start, battle.sel_end - battle.sel_start).abs()

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
	_view_frame(delta)
	# 模拟层：固定步长推进（ARCH-010）
	battle.sim_acc = battle.sim_acc + delta if battle.game_end == 0 else 0.0
	var steps := 0
	var period: float = battle.clock.period()
	var target_tick := ceili(battle.simtest_seconds * Config.SIM_HZ) if battle.simtest_seconds > 0.0 else -1
	while battle.game_end == 0 and battle.sim_acc + 0.000000001 >= period and steps < Config.SIM_MAX_CATCHUP and (target_tick < 0 or battle.sim_tick < target_tick):
		battle.sim_acc = maxf(0.0,battle.sim_acc-period)
		steps += 1
		ports._sim_step(Config.SIM_DT)
	# 达到每帧预算后保留欠下的tick，下一帧继续；不能丢弃计时导致低帧率少结算。
	if target_tick >= 0 and (battle.sim_tick >= target_tick or battle.game_end != 0):
		print("SIMTEST: %.1fs tick=%d digest=%d" % [battle.simtest_seconds, battle.sim_tick, ports._state_digest()])
		# The digest module stays free of the scene tree; the app layer supplies
		# the hasher it needs.
		print("SIMULATION DIGESTS: ", JSON.stringify(preload("res://simulation/systems/state_digest.gd").sections(node, node.get_node("/root/Game"))))
		node.get_tree().quit()
		return
	scene.hud_acc += delta
	if scene.hud_acc >= 1.0 / Config.HUD_HZ:      # R1：文字刷新限频
		scene.hud_acc = 0.0
		if battle.feedback_text != "" and battle.feedback_until == 0:
			# 旧实现：只有 _feedback() 设过 feedback_until 的提示才活得过下一帧；
			# 直接赋值（"没有走得到的资源点"/"没有资源点"/"组建完成" 等）会在这里被
			# **立刻清掉** —— 用户实测"点击采集无反应"（提示其实赋了值，只是从未显示）。
			battle.feedback_until = Time.get_ticks_msec() + 2500
		elif battle.feedback_text != "" and Time.get_ticks_msec() > battle.feedback_until:
			battle.feedback_text = ""
		_view_hud()
	if scene.view!=null:scene.view.interpolate_motion(clampf(battle.sim_acc/period,0.0,1.0))

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
			var e = ports._nearest_enemy(u, 99999.0)
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
