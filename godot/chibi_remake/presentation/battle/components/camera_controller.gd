extends RefCounted
## camera controller: presentation component.
const UIState = preload("res://presentation/battle/components/battle_view_state.gd")
var _ui: UIState
var surface: Node2D
var ports = preload("res://presentation/battle/components/ports/camera_controller_dependencies.gd").new()
const HudMetrics = preload("res://presentation/hud/hud_metrics.gd")

const ZOOM_MIN := 0.5

const PAN_MAX := 1500.0

func _init(data: UIState, node: Node2D) -> void:
	_ui = data
	surface = node

func zoom_x() -> float:
	if _ui.cam != null:
		return _ui.cam.zoom.x
	var hc = _ui.host.cam
	if hc != null:
		return float(hc.zoom.x)
	return 1.0

func setup_camera() -> void:
	var md: Dictionary = _ui.host.map_data
	_ui.cam = Camera2D.new()
	surface.add_child(_ui.cam)
	_ui.cam.make_current()
	var cx: float = 0.0
	var cy: float = 0.0
	var n: int = 0
	var us: Array = _ui.host.units
	var mine: int = int(_ui.host.player_owner)
	for u in us:
		if int(u.owner) == mine and not bool(u.is_building) and bool(u.alive):
			cx += float(u.ax)
			cy += float(u.ay)
			n += 1
	if n > 0:
		_ui.cam.position = Vector2(cx / n, cy / n)
	else:
		_ui.cam.position = Vector2(float(md.terrainW) * 0.5, float(md.terrainH) * 0.5)
	_ui.cam.zoom = Vector2.ONE * _ui.ui_scale
	var opening_target := battle_rect().position + battle_rect().size * Vector2(0.625, 0.5)
	_ui.cam.position -= (opening_target - surface.get_viewport_rect().size * 0.5) / _ui.cam.zoom
	apply_cli_view()
	clamp_camera()              # 初始机位也保证在地图内（不变量：相机永远不在地图外）

## 原版不能缩放：这里只把相机回正到界面刻度。
func set_zoom() -> void:
	if _ui.cam == null:
		return
	var v: float = _ui.zoom_override if _ui.zoom_override > 0.0 else _ui.ui_scale
	_ui.cam.zoom = Vector2(v, v)
	clamp_camera()

func pan_by(pixels: Vector2) -> void:
	if _ui.cam == null:
		return
	_ui.cam.position -= pixels / _ui.cam.zoom
	clamp_camera()

func battle_rect() -> Rect2:
	var rect: Rect2 = _ui.hud_metrics.battle_rect
	if rect.size.x <= 0.0 or rect.size.y <= 0.0:
		return Rect2(Vector2.ZERO, surface.get_viewport_rect().size)
	return rect

func clamp_camera() -> void:
	if _ui.cam == null:
		return
	var md: Dictionary = _ui.host.map_data
	var mw: float = float(md.get("terrainW", 0.0))
	var mh: float = float(md.get("terrainH", 0.0))
	if mw <= 0.0 or mh <= 0.0:
		return
	# 可视范围 = 战场矩形 / 缩放；矩形未就绪时 battle_rect() 已退化为整视口（旧行为）
	var rect := battle_rect()
	var before: Vector2 = _ui.cam.position
	_ui.cam.position = HudMetrics.clamp_world_pos(
		_ui.cam.position, Vector2(mw, mh), rect, surface.get_viewport_rect().size, _ui.cam.zoom)
	# 便于取证：真的夹住了就打印一次（夹住之后位置不再变，所以不会刷屏）
	if before != _ui.cam.position:
		print("CAM: 夹边界 %s -> %s (地图 %.0fx%.0f 战场矩形 %s)" % [
			str(before), str(_ui.cam.position), mw, mh, str(rect)])

func apply_cli_view() -> void:
	if _ui.cam == null:
		return
	for a in OS.get_cmdline_user_args():
		var s: String = str(a)
		if s.begins_with("--zoom="):
			var z: float = float(s.substr(7))
			if z > 0.0:
				_ui.zoom_override = z          # 仅供验证/截图，不是玩法缩放
				set_zoom()
		elif s.begins_with("--focus-point="):
			var parts: PackedStringArray = s.substr(14).split(",")
			if parts.size() == 2:
				var aa: float = float(parts[0])
				var bb: float = float(parts[1])
				_ui.cam.position = Vector2(float(_ui.host.tile_w) * aa + float(_ui.host.tile_hw) * (int(bb) & 1) + float(_ui.host.tile_hw), float(_ui.host.tile_hh) * bb + float(_ui.host.tile_hh))
				clamp_camera()          # 焦点跳转也要夹，否则 --focus-point 能跳到地图外

func fit_view() -> void:
	if _ui.cam == null:
		return
	var vp: Vector2 = surface.get_viewport_rect().size
	var md: Dictionary = _ui.host.map_data
	var mw: float = float(md.terrainW)
	var mh: float = float(md.terrainH)
	if mw <= 0.0 or mh <= 0.0:
		return
	# 原版不能缩放：全景只把镜头移到地图中心，不改比例
	_ui.cam.position = Vector2(mw * 0.5, mh * 0.5)   # 全景必然是地图中心，本来就合法
	clamp_camera()

func edge_direction(mouse: Vector2) -> Vector2:
	var size:=surface.get_viewport_rect().size
	if not Rect2(Vector2.ZERO,size).has_point(mouse):return Vector2.ZERO
	var band:=maxf(1.0,_ui.ui_scale)
	return Vector2((-1 if mouse.x<band else (1 if mouse.x>=size.x-band else 0)),(-1 if mouse.y<band else (1 if mouse.y>=size.y-band else 0)))

func _minimap_navigate(screen_position: Vector2) -> void:
	if _ui.cam == null: return
	var world_size := Vector2(float(_ui.host.map_data.terrainW), float(_ui.host.map_data.terrainH))
	var k := minf(_ui.minimap.size.x / world_size.x, _ui.minimap.size.y / world_size.y)
	var origin := _ui.minimap.global_position + (_ui.minimap.size - world_size * k) * 0.5
	var target := (screen_position - origin) / k
	# 把点击位置放在战场中心，而非被 HUD 遮住的整窗中心。
	_ui.cam.position = target - (battle_rect().get_center() - surface.get_viewport_rect().size * 0.5) / _ui.cam.zoom
	clamp_camera()
	_ui.cam.force_update_scroll()
	_ui.minimap.queue_redraw()

func edge_scroll(delta: float) -> void:
	if bool(_ui.host.cli_mode) or _ui.host.cheat_input_open or _ui.cam == null: return
	if not surface.get_window().has_focus(): return
	scroll_from_pointer(surface.get_viewport().get_mouse_position(), delta)

func scroll_from_pointer(pointer: Vector2, delta: float) -> void:
	if _ui.cam == null or _ui.host.cheat_input_open: return
	var v := edge_direction(pointer)
	if Input.is_key_pressed(KEY_LEFT): v.x -= 1.0
	if Input.is_key_pressed(KEY_RIGHT): v.x += 1.0
	if Input.is_key_pressed(KEY_UP): v.y -= 1.0
	if Input.is_key_pressed(KEY_DOWN): v.y += 1.0
	if v != Vector2.ZERO:
		var speed := clampf(520.0 / maxf(_ui.cam.zoom.x, ZOOM_MIN), 0.0, PAN_MAX)
		_ui.cam.position += v.normalized() * speed * delta
		clamp_camera()
