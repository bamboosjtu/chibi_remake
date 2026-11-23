extends Node2D

func queue_world_visuals() -> void:
	unit_visuals.queue_world_visuals()
func queue_visual(uid: int) -> void:
	unit_visuals.queue_visual(uid)
func flush_visuals(interpolating := false) -> void:
	unit_visuals.flush_visuals(interpolating)
func performance_counters() -> Dictionary:
	var counters: Dictionary=unit_visuals.performance_counters()
	counters["fogMicroseconds"]=_ui.fog_sprite.upload_microseconds if _ui.fog_sprite!=null else 0
	counters["minimapMicroseconds"] = _ui.minimap.draw_microseconds if _ui.minimap != null else 0
	return counters

func prepare_opening_layers() -> void:
	world_layers.prepare_opening_layers()
## Composition root; presentation components own their specific behavior.
const GRID_FALLBACK := 8

var _ui = preload("res://presentation/battle/view/battle_view_state.gd").new()
var _world_nodes := preload("res://presentation/battle/world/world_nodes.gd").new(_ui)

func attach_loaded_world(rows: Array) -> bool:
	for row: Dictionary in rows:
		var unit: Dictionary = row.visual
		attach_unit(unit, row.sheet, int(unit.w), int(unit.h), float(unit.k))
	return _world_nodes.complete(rows.map(func(row): return row.visual))

func finish_loaded_world(rows: Array, ended: int) -> void:
	capture_motion()
	if _ui.event_view != null: _ui.event_view.restore_history()
	for row in rows: update_visual(row.visual)
	if _ui.completion != null:
		_ui.completion.reset(); _ui.end_label.hide()
		if ended != 0: show_end(ended)
	_ui.projectile_view.impacts.clear()
	if cmd_box_ready(): update_panel()

func apply_loaded_unit(unit: Dictionary) -> void:
	unit_visuals.apply_loaded_unit(unit)
var controller: Object
var unit_visuals: Object
var camera_controller: Object
var hud_build: Object
var hud_layout: Object
var world_layers: Object
var hud_input: Object
var selection_info: Object
var command_art: Object
var command_model: Object
var command_actions: Object
var legacy_layout: Object
var _disposed := false
var _fields: Dictionary = {}
var _api_missing: Array = []
var worker_button: Button:
	get: return _ui.worker_button
	set(value): _ui.worker_button = value
var classic_panel: Control:
	get: return _ui.classic_panel
	set(value): _ui.classic_panel = value
var briefing: CanvasLayer:
	get: return _ui.briefing
	set(value): _ui.briefing = value
var battle_menu: CanvasLayer:
	get: return _ui.battle_menu
	set(value): _ui.battle_menu = value
var projectile_view: Node2D:
	get: return _ui.projectile_view
	set(value): _ui.projectile_view = value
var construction_preview: Node2D:
	get: return _ui.construction_preview
	set(value): _ui.construction_preview = value
var resource_layer: Node2D:
	get: return _ui.resource_layer
	set(value): _ui.resource_layer = value
var host: Node2D:
	get: return _ui.host
	set(value): _ui.host = value
var cam: Camera2D:
	get: return _ui.cam
	set(value): _ui.cam = value
var info: Label:
	get: return _ui.info
	set(value): _ui.info = value
var panel_label: Label:
	get: return _ui.panel_label
	set(value): _ui.panel_label = value
var end_label: Label:
	get: return _ui.end_label
	set(value): _ui.end_label = value
var top_bar: ColorRect:
	get: return _ui.top_bar
	set(value): _ui.top_bar = value
var right_panel: ColorRect:
	get: return _ui.right_panel
	set(value): _ui.right_panel = value
var minimap: Control:
	get: return _ui.minimap
	set(value): _ui.minimap = value
var fog_sprite: Sprite2D:
	get: return _ui.fog_sprite
	set(value): _ui.fog_sprite = value
var cmd_hint: Label:
	get: return _ui.cmd_hint
	set(value): _ui.cmd_hint = value
var cmd_prev: Button:
	get: return _ui.cmd_prev
	set(value): _ui.cmd_prev = value
var cmd_next: Button:
	get: return _ui.cmd_next
	set(value): _ui.cmd_next = value
var back_button: Button:
	get: return _ui.back_button
	set(value): _ui.back_button = value
var event_view: CanvasLayer:
	get: return _ui.event_view
	set(value): _ui.event_view = value
var completion: CanvasLayer:
	get: return _ui.completion
	set(value): _ui.completion = value
var status_sub: Label:
	get: return _ui.status_sub
	set(value): _ui.status_sub = value
var top_right_tex: TextureRect:
	get: return _ui.top_right_tex
	set(value): _ui.top_right_tex = value
var banner_tex: TextureRect:
	get: return _ui.banner_tex
	set(value): _ui.banner_tex = value
var panel_bg_tex: TextureRect:
	get: return _ui.panel_bg_tex
	set(value): _ui.panel_bg_tex = value
var bottom_tex: TextureRect:
	get: return _ui.bottom_tex
	set(value): _ui.bottom_tex = value
var art_back: TextureRect:
	get: return _ui.art_back
	set(value): _ui.art_back = value

func _init(access: Node2D) -> void:
	_ui.host = access
	_ui.projectile_view = preload("res://presentation/battle/effects/projectile_view.gd").new(access)
	add_child(_ui.projectile_view)
	_ui.construction_preview = preload("res://presentation/battle/world/build_preview.gd").new(access)
	add_child(_ui.construction_preview)
	for field in _ui.PROXY_FIELDS: _fields[field] = true
	controller = preload("res://presentation/battle/view/controller.gd").new(_ui, self)
	unit_visuals = preload("res://presentation/battle/units/unit_visuals.gd").new(_ui, self)
	camera_controller = preload("res://presentation/battle/camera/camera_controller.gd").new(_ui, self)
	hud_build = preload("res://presentation/battle/hud/hud_build.gd").new(_ui, self)
	hud_layout = preload("res://presentation/battle/hud/hud_layout.gd").new(_ui, self)
	world_layers = preload("res://presentation/battle/world/world_layers.gd").new(_ui, self)
	hud_input = preload("res://presentation/battle/input/hud_input.gd").new(_ui, self)
	selection_info = preload("res://presentation/battle/units/selection_info.gd").new(_ui, self)
	command_art = preload("res://presentation/battle/command/command_art.gd").new(_ui, self)
	command_model = preload("res://presentation/battle/command/command_model.gd").new(_ui, self)
	command_actions = preload("res://presentation/battle/command/command_actions.gd").new(_ui, self)
	legacy_layout = preload("res://presentation/battle/view/legacy_layout.gd").new(_ui, self)
	var components := _owned_components()
	for component in components.values():
		if component != null and component.has_method("bind_dependencies"): component.bind_dependencies(self)
	var report := preload("res://composition_contract.gd").wire(components, "view")
	_api_missing = report.missing

func contract_abort() -> bool:
	return preload("res://composition_contract.gd").abort_if_broken("view", _api_missing)

func _get(key: StringName):
	if _fields.has(key): return _ui.get(key)
	preload("res://property_contract.gd").reject(self,key)
	return null

func _set(key: StringName, value) -> bool:
	if _fields.has(key): _ui.set(key, value); return true
	preload("res://property_contract.gd").reject(self,key)
	return false

func maybe_play_intro(avi: String) -> void:
	controller.maybe_play_intro(avi)
func build_ui() -> void:
	hud_build.build_ui()
func zoom_x() -> float:
	return camera_controller.zoom_x()
func update_hud_text() -> void:
	selection_info.update_hud_text()
func show_end(kind: int) -> void:
	controller.show_end(kind)
func update_panel() -> void:
	command_model.update_panel()
func panel_kind() -> String:
	return command_model.panel_kind()
func art_panel_active() -> bool:
	return command_art.art_panel_active()
func _process(_delta: float) -> void:
	flush_visuals()
	hud_input._process(_delta)
func draw_hover_at(mp: Vector2) -> void:
	hud_input.draw_hover_at(mp)
func _input(event: InputEvent) -> void:
	hud_input._input(event)
func cmd_box_ready() -> bool:
	return command_model.cmd_box_ready()
func update_hover() -> void:
	selection_info.update_hover()
func setup_camera() -> void:
	camera_controller.setup_camera()
func set_zoom() -> void:
	camera_controller.set_zoom()
func pan_by(pixels: Vector2) -> void:
	camera_controller.pan_by(pixels)
func battle_rect() -> Rect2:
	return camera_controller.battle_rect()
func clamp_camera() -> void:
	camera_controller.clamp_camera()
func apply_cli_view() -> void:
	camera_controller.apply_cli_view()
func fit_view() -> void:
	camera_controller.fit_view()
func edge_direction(mouse: Vector2) -> Vector2:
	return camera_controller.edge_direction(mouse)
func edge_scroll(delta: float) -> void:
	camera_controller.edge_scroll(delta)
func scroll_from_pointer(pointer: Vector2, delta: float) -> void:
	camera_controller.scroll_from_pointer(pointer, delta)
func build_terrain() -> void:
	world_layers.build_terrain()

func stage_world_view(preview: Node2D, rows: Array, map_id: String, cross_map: bool) -> Dictionary:
	var map_plan: Dictionary = world_layers.terrain_plan(map_id) if cross_map else {}
	if cross_map and map_plan.is_empty(): return {}
	var token := {"old_nodes": _world_nodes.begin()}
	var stable_host: Node2D = _ui.host
	_ui.host = preview
	var complete := attach_loaded_world(rows)
	if complete and cross_map:
		complete = _stage_terrain_exchange(token, map_id, map_plan)
	_ui.host = stable_host
	if is_instance_valid(token.get("terrain")): token.terrain.host = stable_host
	token.nodes = _world_nodes.begin()
	_world_nodes.activate(token.old_nodes)
	if not complete:
		rollback_world_view(token)
		return {}
	return token

func _stage_terrain_exchange(token: Dictionary, map_id: String, plan: Dictionary) -> bool:
	if _ui.minimap != null:
		token.minimap = _ui.minimap.prepare_map_texture(map_id)
		if token.minimap == null: return false
	token.old_camera = _ui.cam
	if _ui.cam != null:
		token.old_position = _ui.cam.position
		token.old_zoom = _ui.cam.zoom
	token.old_zoom_override = _ui.zoom_override
	setup_camera()
	token.camera = _ui.cam
	token.position = _ui.cam.position
	token.zoom = _ui.cam.zoom
	token.zoom_override = _ui.zoom_override
	token.terrain = world_layers.stage_terrain(map_id, plan, DisplayServer.get_name() != "headless", _ui.cam)
	_restore_world_camera(token)
	if token.terrain == null: return false
	token.terrain.hide()
	token.old_terrain = world_layers.terrain
	return true

func _restore_world_camera(token: Dictionary) -> void:
	_ui.cam = token.old_camera
	_ui.zoom_override = token.old_zoom_override
	if _ui.cam != null:
		_ui.cam.position = token.old_position
		_ui.cam.zoom = token.old_zoom
		_ui.cam.force_update_scroll()
	else:
		token.camera.enabled = false

func apply_world_view_nodes(token: Dictionary) -> bool:
	if not token.has("nodes"): return false
	_world_nodes.activate(token.nodes)
	token.nodes_applied = true
	return true

func apply_world_view_terrain(token: Dictionary) -> bool:
	if not is_instance_valid(token.get("terrain")): return false
	world_layers.terrain = token.terrain
	token.terrain.show()
	_ui.cam = token.camera
	_ui.zoom_override = token.zoom_override
	if token.old_camera == null:
		_ui.cam.enabled = true
		_ui.cam.make_current()
	_ui.cam.position = token.position
	_ui.cam.zoom = token.zoom
	_ui.cam.force_update_scroll()
	token.terrain_applied = true
	return true

func rollback_world_view(token: Dictionary) -> void:
	if token.is_empty(): return
	if token.get("nodes_applied", false): _world_nodes.activate(token.old_nodes)
	_world_nodes.commit(token.nodes)
	if token.get("terrain_applied", false):
		world_layers.terrain = token.old_terrain
		_restore_world_camera(token)
	if token.has("camera") and token.old_camera == null: token.camera.queue_free()
	if is_instance_valid(token.get("terrain")):
		token.terrain.hide()
		token.terrain.queue_free()
	token.clear()

func release_previous_world_view(token: Dictionary) -> void:
	_world_nodes.commit(token.old_nodes)
	if is_instance_valid(token.get("old_terrain")):
		token.old_terrain.hide()
		token.old_terrain.queue_free()

func finish_world_view(token: Dictionary, rows: Array, ended: int) -> void:
	if token.get("terrain_applied", false):
		marquee_hide()
		if token.has("minimap"): _ui.minimap.apply_map_texture(token.minimap)
	token.clear()
	finish_loaded_world(rows, ended)

func request_window_close() -> bool:
	if _ui.battle_menu == null: return false
	await _ui.battle_menu.open()
	_ui.battle_menu.quit_game()
	return true
func attach_unit(u: Dictionary, sheet: String, w: int, h: int, k: float) -> void:
	unit_visuals.attach_unit(u, sheet, w, h, k)
func free_unit(u: Dictionary) -> void:
	unit_visuals.free_unit(u)
func place_unit(u: Dictionary) -> void:
	host.queries.unit.invalidate_unit_views()
	unit_visuals.place_unit(u)
func capture_motion() -> void:
	host.queries.unit.invalidate_unit_views()
	unit_visuals.capture_motion()
func interpolate_motion(alpha: float) -> void:
	unit_visuals.interpolate_motion(alpha)
func hide_unit(u: Dictionary) -> void:
	unit_visuals.hide_unit(u)
func fade_unit(u: Dictionary, alpha: float) -> void:
	unit_visuals.fade_unit(u, alpha)
func set_unit_attached(u: Dictionary, attached: bool) -> void:
	unit_visuals.set_unit_attached(u, attached)
func update_visual(u: Dictionary) -> void:
	host.queries.unit.invalidate_unit_views()
	unit_visuals.update_visual(u)

func domain_changed() -> void:
	host.queries.unit.invalidate_unit_views()
func mobile_pose(u: Dictionary, gait_tick := -1.0) -> Dictionary:
	return unit_visuals.mobile_pose(u, gait_tick)
func set_frame(u: Dictionary, f: int) -> void:
	unit_visuals.set_frame(u, f)
func build_marquee() -> void:
	world_layers.build_marquee()
func marquee_hide() -> void:
	world_layers.marquee_hide()
func marquee_update(r: Rect2) -> void:
	world_layers.marquee_update(r)
func unit_nodes(u: Dictionary) -> Dictionary:
	return unit_visuals.unit_nodes(u)

static func screenshot(node: Node) -> void:
	if DisplayServer.get_name() == "headless":
		print("screenshot skipped (headless)")
		return
	await RenderingServer.frame_post_draw
	var vp_tex: ViewportTexture = node.get_viewport().get_texture()
	if vp_tex == null:
		print("screenshot skipped (no viewport texture)")
		return
	var img: Image = vp_tex.get_image()
	if img == null:
		print("screenshot skipped (no image)")
		return
	img.save_png("user://chibi_shot.png")
	print("screenshot saved: ", OS.get_user_data_dir(), "/chibi_shot.png")

# ------------------------------------------------- unit nodes & frames (A/B) ----

static func frame_rect(u: Dictionary, f: int) -> Rect2:
	return preload("res://presentation/battle/camera/view_math.gd").frame_rect(u,f)
static func clip_dir(u: Dictionary, clip: String, dir: int) -> Array:
	return preload("res://presentation/battle/camera/view_math.gd").clip_dir(u,clip,dir)
static func clip_frame(u: Dictionary, clip: String, dir: int, step: int) -> int:
	return preload("res://presentation/battle/camera/view_math.gd").clip_frame(u,clip,dir,step)

# ------------------------------------------------- selection marquee (E) ----

func _dispose_components() -> void:
	if _disposed: return
	_disposed = true
	for component in _owned_components().values():
		if is_instance_valid(component): component.free()
	for property in _ui.get_property_list():
		var value = _ui.get(property.name)
		if value is Array or value is Dictionary: value.clear()

func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE and not _disposed: _dispose_components()

func _owned_components() -> Dictionary:
	var components := {
		"controller": controller,
		"unit_visuals": unit_visuals,
		"camera_controller": camera_controller,
		"hud_build": hud_build,
		"hud_layout": hud_layout,
		"world_layers": world_layers,
		"hud_input": hud_input,
		"selection_info": selection_info,
		"command_art": command_art,
		"command_model": command_model,
		"command_actions": command_actions,
		"legacy_layout": legacy_layout,
	}
	return components
