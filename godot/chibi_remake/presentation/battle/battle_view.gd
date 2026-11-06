extends Node2D
## Composition root; presentation components own their specific behavior.
const GRID_FALLBACK := 8

var _ui = preload("res://presentation/battle/components/battle_view_state.gd").new()
var _components: Dictionary = {}
var _fields: Dictionary = {}
var _api_conflicts: Array = []
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

func _init(battle: Node2D) -> void:
	var access := preload("res://presentation/battle/battle_access.gd").new(battle, battle.scene, battle.commands)
	battle.add_child(access)
	_ui.host = access
	_ui.projectile_view = preload("res://presentation/battle/projectile_view.gd").new(access)
	add_child(_ui.projectile_view)
	_ui.construction_preview = preload("res://presentation/battle/build_preview.gd").new(access)
	add_child(_ui.construction_preview)
	for property in _ui.get_property_list(): _fields[property.name] = true
	_components["controller"] = preload("res://presentation/battle/components/controller.gd").new(_ui, self)
	_components["unit_visuals"] = preload("res://presentation/battle/components/unit_visuals.gd").new(_ui, self)
	_components["camera_controller"] = preload("res://presentation/battle/components/camera_controller.gd").new(_ui, self)
	_components["hud_build"] = preload("res://presentation/battle/components/hud_build.gd").new(_ui, self)
	_components["hud_layout"] = preload("res://presentation/battle/components/hud_layout.gd").new(_ui, self)
	_components["world_layers"] = preload("res://presentation/battle/components/world_layers.gd").new(_ui, self)
	_components["hud_input"] = preload("res://presentation/battle/components/hud_input.gd").new(_ui, self)
	_components["selection_info"] = preload("res://presentation/battle/components/selection_info.gd").new(_ui, self)
	_components["command_art"] = preload("res://presentation/battle/components/command_art.gd").new(_ui, self)
	_components["command_model"] = preload("res://presentation/battle/components/command_model.gd").new(_ui, self)
	_components["command_actions"] = preload("res://presentation/battle/components/command_actions.gd").new(_ui, self)
	_components["legacy_layout"] = preload("res://presentation/battle/components/legacy_layout.gd").new(_ui, self)
	var report := preload("res://composition_contract.gd").wire(_components, "view")
	_api_missing = report.missing

func registry_abort() -> bool:
	return preload("res://composition_contract.gd").abort_if_broken("view", _api_conflicts, _api_missing)

func _get(key: StringName):
	if _fields.has(key): return _ui.get(key)
	return null

func _set(key: StringName, value) -> bool:
	if _fields.has(key): _ui.set(key, value); return true
	return false

func maybe_play_intro(md: Dictionary) -> void:
	_components["controller"].maybe_play_intro(md)
func _intro_finished() -> void:
	_components["controller"]._intro_finished()
func _ui_tex(name: String) -> Texture2D:
	return _components["hud_build"]._ui_tex(name)
func build_ui() -> void:
	_components["hud_build"].build_ui()
func _mk_panel(parent: Node, bg: Color, border: Color, bw: float) -> Panel:
	return _components["hud_build"]._mk_panel(parent, bg, border, bw)
func _mk_label(parent: Node, size: float, col: Color, align: HorizontalAlignment) -> Label:
	return _components["hud_build"]._mk_label(parent, size, col, align)
func _mk_button(parent: Node, size: float) -> Button:
	return _components["hud_build"]._mk_button(parent, size)
func _place_left(c: Control, x: float, y: float, w: float, h: float) -> void:
	_components["hud_layout"]._place_left(c, x, y, w, h)
func _pin_right(c: Control, dist_right: float, w: float, top: float, h: float) -> void:
	_components["hud_layout"]._pin_right(c, dist_right, w, top, h)
func _pin_bottom_right(c: Control, dist_right: float, w: float, h: float) -> void:
	_components["hud_layout"]._pin_bottom_right(c, dist_right, w, h)
func _res_icon_path(kind: String) -> String:
	return _components["controller"]._res_icon_path(kind)
func _build_top_bar(ui: CanvasLayer) -> void:
	_components["hud_build"]._build_top_bar(ui)
func _build_top_bar_original(ui: CanvasLayer, tl: Texture2D, tr: Texture2D, tile: Texture2D) -> void:
	_components["hud_build"]._build_top_bar_original(ui, tl, tr, tile)
func _build_right_panel(ui: CanvasLayer) -> void:
	_components["hud_build"]._build_right_panel(ui)
func _build_hot_strip(ui: CanvasLayer) -> void:
	_components["hud_build"]._build_hot_strip(ui)
func _build_status(ui: CanvasLayer) -> void:
	_components["hud_build"]._build_status(ui)
func _build_ornament(ui: CanvasLayer) -> void:
	_components["hud_build"]._build_ornament(ui)
func _apply_metrics() -> void:
	_components["hud_layout"]._apply_metrics()
func _decorate_frame(panel: Panel, border: float) -> void:
	_components["hud_layout"]._decorate_frame(panel, border)
func _apply_metrics_original(vp: Vector2, s: float) -> void:
	_components["legacy_layout"]._apply_metrics_original(vp, s)
func _layout_status_labels(vp: Vector2, s: float) -> void:
	_components["hud_layout"]._layout_status_labels(vp, s)
func _refresh_metrics() -> void:
	_components["hud_layout"]._refresh_metrics()
func _draw_ornament() -> void:
	_components["hud_layout"]._draw_ornament()
func zoom_x() -> float:
	return _components["camera_controller"].zoom_x()
func update_hud_text() -> void:
	_components["selection_info"].update_hud_text()
func _refresh_res_slots() -> void:
	_components["selection_info"]._refresh_res_slots()
func show_end(kind: int) -> void:
	_components["controller"].show_end(kind)
func update_panel() -> void:
	_components["command_model"].update_panel()
func panel_kind() -> String:
	return _components["command_model"].panel_kind()
func _officer_selection() -> Dictionary:
	return _components["selection_info"]._officer_selection()
func _build_cmd_art() -> void:
	_components["command_art"]._build_cmd_art()
func _command_icon(cell: int) -> Texture2D:
	return _components["command_art"]._command_icon(cell)
func _set_art_state(index: int, state: int) -> void:
	_components["command_art"]._set_art_state(index, state)
func _add_art_button(cell: int, name: String, sub: String, act: Callable) -> void:
	_components["command_art"]._add_art_button(cell, name, sub, act)
func _panel_specs() -> Array:
	return _components["command_art"]._panel_specs()
func _apply_panel_type() -> void:
	_components["command_art"]._apply_panel_type()
func _close_art_sub() -> void:
	_components["command_art"]._close_art_sub()
func _layout_cmd_art() -> void:
	_components["command_art"]._layout_cmd_art()
func _art_visible(sub: String) -> bool:
	return _components["command_art"]._art_visible(sub)
func art_panel_active() -> bool:
	return _components["command_art"].art_panel_active()
func _refresh_cmd_art() -> void:
	_components["command_art"]._refresh_cmd_art()
func _on_panel_slot(i: int) -> void:
	_components["command_art"]._on_panel_slot(i)
func _open_build_menu() -> void:
	_components["command_art"]._open_build_menu()
func _process(_delta: float) -> void:
	_components["hud_input"]._process(_delta)
func draw_hover_at(mp: Vector2) -> void:
	_components["hud_input"].draw_hover_at(mp)
func _on_art_hot(i: int) -> void:
	_components["command_art"]._on_art_hot(i)
func _on_art_form(i: int) -> void:
	_components["command_art"]._on_art_form(i)
func _input(event: InputEvent) -> void:
	_components["hud_input"]._input(event)
func _hud_canvas_pos(win_pos: Vector2) -> Vector2:
	return _components["hud_input"]._hud_canvas_pos(win_pos)
func _handle_cmd_key(k: InputEventKey) -> bool:
	return _components["command_art"]._handle_cmd_key(k)
func _hud_button_at(win_pos: Vector2) -> Dictionary:
	return _components["hud_input"]._hud_button_at(win_pos)
func _hud_panel_at(win_pos: Vector2) -> bool:
	return _components["hud_input"]._hud_panel_at(win_pos)
func _refresh_banner() -> void:
	_components["selection_info"]._refresh_banner()
func _unit_icon(u: Dictionary) -> Texture2D:
	return _components["selection_info"]._unit_icon(u)
func _refresh_sel_frame() -> void:
	_components["selection_info"]._refresh_sel_frame()
func _refresh_troop() -> void:
	_components["selection_info"]._refresh_troop()
func _dominant(sel: Array) -> Dictionary:
	return _components["selection_info"]._dominant(sel)
func _act_assign_officer(idx: int) -> void:
	_components["selection_info"]._act_assign_officer(idx)
func _act_open_officer_pick() -> void:
	_components["selection_info"]._act_open_officer_pick()
func _act_close_officer_pick() -> void:
	_components["selection_info"]._act_close_officer_pick()
func _refresh_cmd_panel() -> void:
	_components["command_model"]._refresh_cmd_panel()
func _apply_cmd_specs(specs: Array, hint: String) -> void:
	_components["command_model"]._apply_cmd_specs(specs, hint)
func _apply_cmd_page() -> void:
	_components["command_model"]._apply_cmd_page()
func _on_cmd_page(dir: int) -> bool:
	return _components["command_model"]._on_cmd_page(dir)
func cmd_box_ready() -> bool:
	return _components["command_model"].cmd_box_ready()
func _refresh_hotkeys() -> void:
	_components["command_model"]._refresh_hotkeys()
func _order_stop(_hold: bool) -> void:
	_components["command_actions"]._order_stop(_hold)
func _act_build(idx: int) -> void:
	_components["command_actions"]._act_build(idx)
func _act_cancel_site(site: Dictionary) -> void:
	_components["command_actions"]._act_cancel_site(site)
func _act_cancel_train(building: Dictionary) -> void:
	_components["command_actions"]._act_cancel_train(building)
func _act_train(i: int) -> void:
	_components["command_actions"]._act_train(i)
func _act_research(idx: int) -> void:
	_components["command_actions"]._act_research(idx)
func _act_cancel_research() -> void:
	_components["command_actions"]._act_cancel_research()
func _add_tech_specs(specs: Array, bid: int) -> void:
	_components["command_model"]._add_tech_specs(specs, bid)
func _act_group(n: int) -> void:
	_components["command_actions"]._act_group(n)
func _act_move() -> void:
	_components["command_actions"]._act_move()
func _act_attack() -> void:
	_components["command_actions"]._act_attack()
func _act_transport() -> void:
	_components["command_actions"]._act_transport()
func _act_repair() -> void:
	_components["command_actions"]._act_repair()
func _act_board() -> void:
	_components["command_actions"]._act_board()
func _act_watch() -> void:
	_components["command_actions"]._act_watch()
func _act_rest() -> void:
	_components["command_actions"]._act_rest()
func _act_disband() -> void:
	_components["command_actions"]._act_disband()
func _act_duel() -> void:
	_components["command_actions"]._act_duel()
func _act_form_menu() -> void:
	_components["command_actions"]._act_form_menu()
func _act_hot_menu() -> void:
	_components["command_actions"]._act_hot_menu()
func _on_cmd(i: int) -> void:
	_components["command_actions"]._on_cmd(i)
func _on_hotkey(i: int) -> void:
	_components["command_actions"]._on_hotkey(i)
func _selected_building() -> Dictionary:
	return _components["selection_info"]._selected_building()
func _selected_site() -> Dictionary:
	return _components["selection_info"]._selected_site()
func _worker_count(sel: Array) -> int:
	return _components["selection_info"]._worker_count(sel)
func _mobile_count(sel: Array) -> int:
	return _components["selection_info"]._mobile_count(sel)
func _can_afford(tt: Dictionary) -> bool:
	return _components["selection_info"]._can_afford(tt)
func _cost_text(tt: Dictionary) -> String:
	return _components["selection_info"]._cost_text(tt)
func _rebuild_stats_text() -> void:
	_components["selection_info"]._rebuild_stats_text()
func _hud_select_hook(want_building: bool) -> void:
	await _components["hud_input"]._hud_select_hook(want_building)
func _send_click(canvas_pos: Vector2) -> void:
	_components["hud_input"]._send_click(canvas_pos)
func _hud_click_hook(idx: int, hot: bool) -> void:
	await _components["hud_input"]._hud_click_hook(idx, hot)
func _on_click_probe() -> void:
	_components["hud_input"]._on_click_probe()
func _sel_state_text() -> String:
	return _components["selection_info"]._sel_state_text()
func update_hover() -> void:
	_components["selection_info"].update_hover()
func setup_camera() -> void:
	_components["camera_controller"].setup_camera()
func set_zoom() -> void:
	_components["camera_controller"].set_zoom()
func pan_by(pixels: Vector2) -> void:
	_components["camera_controller"].pan_by(pixels)
func battle_rect() -> Rect2:
	return _components["camera_controller"].battle_rect()
func clamp_camera() -> void:
	_components["camera_controller"].clamp_camera()
func apply_cli_view() -> void:
	_components["camera_controller"].apply_cli_view()
func fit_view() -> void:
	_components["camera_controller"].fit_view()
func edge_direction(mouse: Vector2) -> Vector2:
	return _components["camera_controller"].edge_direction(mouse)
func _minimap_navigate(screen_position: Vector2) -> void:
	_components["camera_controller"]._minimap_navigate(screen_position)
func edge_scroll(delta: float) -> void:
	_components["camera_controller"].edge_scroll(delta)
func scroll_from_pointer(pointer: Vector2, delta: float) -> void:
	_components["camera_controller"].scroll_from_pointer(pointer, delta)
func _sheet(p: String) -> Texture2D:
	return _components["unit_visuals"]._sheet(p)
func build_terrain() -> void:
	_components["world_layers"].build_terrain()
func attach_unit(u: Dictionary, ob: Dictionary, w: int, h: int, k: float) -> void:
	_components["unit_visuals"].attach_unit(u, ob, w, h, k)
func free_unit(u: Dictionary) -> void:
	_components["unit_visuals"].free_unit(u)
func place_unit(u: Dictionary) -> void:
	_components["unit_visuals"].place_unit(u)
func capture_motion() -> void:
	_components["unit_visuals"].capture_motion()
func interpolate_motion(alpha: float) -> void:
	_components["unit_visuals"].interpolate_motion(alpha)
func hide_unit(u: Dictionary) -> void:
	_components["unit_visuals"].hide_unit(u)
func fade_unit(u: Dictionary, alpha: float) -> void:
	_components["unit_visuals"].fade_unit(u, alpha)
func set_unit_attached(u: Dictionary, attached: bool) -> void:
	_components["unit_visuals"].set_unit_attached(u, attached)
func update_visual(u: Dictionary) -> void:
	_components["unit_visuals"].update_visual(u)
func mobile_pose(u: Dictionary, gait_tick := -1.0) -> Dictionary:
	return _components["unit_visuals"].mobile_pose(u, gait_tick)
func _apply_mobile_pose(u: Dictionary, gait_tick := -1.0) -> void:
	_components["unit_visuals"]._apply_mobile_pose(u, gait_tick)
func set_frame(u: Dictionary, f: int) -> void:
	_components["unit_visuals"].set_frame(u, f)
func build_marquee() -> void:
	_components["world_layers"].build_marquee()
func marquee_hide() -> void:
	_components["world_layers"].marquee_hide()
func marquee_update(r: Rect2) -> void:
	_components["world_layers"].marquee_update(r)
func unit_nodes(u: Dictionary) -> Dictionary:
	return _components["unit_visuals"].unit_nodes(u)

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
	var k: float = float(u.get("k", 1.0))
	var w: float = float(u.w)
	var h: float = float(u.h)
	var grid: int = maxi(1, int(u.get("grid", GRID_FALLBACK)))
	return Rect2((f % grid) * w * k, (f / grid) * h * k, w * k, h * k)

## 某剪辑某朝向的帧序列（无数据返回空数组）。静态：死亡时序在 main._die_step 里要用它，
## 而模拟必须能没有 view 实例地跑完。

static func clip_dir(u: Dictionary, clip: String, dir: int) -> Array:
	var clips = u.get("clips", null)
	if not (clips is Dictionary) or not clips.has(clip):
		return []
	var d = clips[clip]
	if not (d is Array) or d.is_empty():
		return []
	var list = d[dir % d.size()]
	return list if list is Array else []

## 取一帧；无数据返回 -1（调用方回退）

static func clip_frame(u: Dictionary, clip: String, dir: int, step: int) -> int:
	var list: Array = clip_dir(u, clip, dir)
	return -1 if list.is_empty() else int(list[step % list.size()])

# ------------------------------------------------- selection marquee (E) ----

func _exit_tree() -> void:
	for component in _components.values(): component.ports.disconnect_services()
	_components.clear()
	for property in _ui.get_property_list():
		var value = _ui.get(property.name)
		if value is Array or value is Dictionary: value.clear()

func rekey_unit(unit: Dictionary, new_uid: int) -> void:
	var old_uid := int(unit.uid)
	if old_uid == new_uid or not _ui._nodes_by_uid.has(old_uid): return
	_ui._nodes_by_uid[new_uid] = _ui._nodes_by_uid[old_uid]
	_ui._nodes_by_uid.erase(old_uid)
