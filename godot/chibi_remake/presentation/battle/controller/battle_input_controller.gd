extends RefCounted
## Battle input policy. The scene root injects this controller so App keeps only
## scene lifecycle and save orchestration; all key/mouse translation lives here.

var scene: Object
var node: Node2D
var screenshotter: Callable
var _dep_cheat_controller: Object
var _dep_harvest_orders: Object
var _dep_selection: Object
var _dep_world_orders: Object

func _init(services: Object, surface: Node2D, shot: Callable = Callable()) -> void:
	scene = services
	node = surface
	screenshotter = shot

func bind_dependencies(scene_root: Object) -> void:
	_dep_cheat_controller = scene_root.cheat_controller
	_dep_harvest_orders = scene_root.world.harvest_orders
	_dep_selection = scene_root.world.selection
	_dep_world_orders = scene_root.world.world_orders

func _unhandled_input(event: InputEvent) -> void:
	if _dep_cheat_controller != null and _dep_cheat_controller.handle_cheat_input(event):
		node.get_viewport().set_input_as_handled()
		return
	if not node.session_actions.waiting_for_commands:
		_battle_input(event)

func _battle_input(event: InputEvent) -> void:
	if scene.cam == null:
		return
	if event is InputEventKey or event is InputEventJoypadButton:
		_battle_action(event)
	elif event is InputEventMouseButton:
		var mbe := event as InputEventMouseButton
		if mbe.pressed:
			scene.ev_count += 1
		# 原版不能缩放：滚轮不再改变比例，镜头平移/中键拖拽保留。
		if mbe.button_index == MOUSE_BUTTON_MIDDLE:
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
				var clicked: bool = scene.sel_start.distance_to(world_pos) <= 7.0
				if clicked and _dep_world_orders.cmd_pending_kind() != "":
					# 原版模型：先点面板按钮、再点地图目标，待选命令用左键落到目标上。
					node.actions.submit_point_order(world_pos, false)
				elif not clicked:
					_dep_selection._select_box(_sel_rect(), add)
					_view_hud()
				else:
					# 工人队左键资源也可下采集令；资源本身不可选中，不能清空选择。
					var rclick = _dep_harvest_orders._resource_at(world_pos)
					if rclick.is_empty() or bool(rclick.get("is_building", false)) or not node.actions.allows_context(16138):
						node.actions.select_at(world_pos, add)
					else:
						node.actions.gather_at(rclick, world_pos)
		elif mbe.button_index == MOUSE_BUTTON_RIGHT and mbe.pressed:
			node.actions.submit_point_order(node.get_canvas_transform().affine_inverse() * mbe.position, true)
	elif event is InputEventMouseMotion:
		var mme := event as InputEventMouseMotion
		if scene.drag_pan:
			if not Input.is_mouse_button_pressed(MOUSE_BUTTON_MIDDLE):
				scene.drag_pan = false
			else:
				_pan_by(mme.relative)
		elif scene.selecting:
			scene.sel_end = node.get_canvas_transform().affine_inverse() * mme.position
			_marquee_update(_sel_rect())

func _battle_action(event: InputEvent) -> void:
	if not event.is_pressed() or event.is_echo():
		return
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
		if _dep_world_orders.cmd_pending_kind().is_empty():
			node.actions.select_at(point, false)
		else:
			node.actions.submit_point_order(point, false)
	elif event is InputEventKey:
		if event.keycode == KEY_F3 and event.ctrl_pressed:
			scene.show_debug = not scene.show_debug
		elif event.keycode == KEY_F12:
			_screenshot()

func _sel_rect() -> Rect2:
	return Rect2(scene.sel_start, scene.sel_end - scene.sel_start).abs()

func _pan_by(pixels: Vector2) -> void:
	if scene.view != null:
		scene.view.pan_by(pixels)

func _marquee_hide() -> void:
	if scene.view != null:
		scene.view.marquee_hide()

func _marquee_update(r: Rect2) -> void:
	if scene.view != null:
		scene.view.marquee_update(r)

func _view_hud() -> void:
	if scene.view != null:
		scene.view.update_hud_text()
		scene.view.update_panel()

func _fit_view() -> void:
	if scene.view != null:
		scene.view.fit_view()

func _screenshot() -> void:
	if screenshotter.is_valid():
		await screenshotter.call(node)
	else:
		printerr("screenshot hook is not configured")
