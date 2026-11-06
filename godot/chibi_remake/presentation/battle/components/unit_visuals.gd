extends RefCounted
const ViewMath = preload("res://presentation/battle/view_math.gd")
## unit visuals: presentation component.
const UIState = preload("res://presentation/battle/components/battle_view_state.gd")
var _ui: UIState
var surface: Node2D
var ports = preload("res://presentation/battle/components/ports/unit_visuals_dependencies.gd").new()
const Textures = preload("res://presentation/battle/runtime_textures.gd")

const FRAME_TICKS = preload("res://simulation/definitions/action_visual.gd").FRAME_TICKS # Presentation sampling; simulation owns gait state.

func _init(data: UIState, node: Node2D) -> void:
	_ui = data
	surface = node

func _sheet(p: String) -> Texture2D:
	if not _ui.sheet_tex.has(p):
		# REQ-007：按路径前缀声明三态——art/full 是正式高清（缺失=错误），
		# sprites 是显式原图回退（缺失=警告）。日志与失败清单由 loader 统一给。
		var declared := "formal" if p.begins_with("art/full") else "original"
		_ui.sheet_tex[p] = Textures.load_texture(p, ResourceLoader.CACHE_MODE_REUSE, declared)
	return _ui.sheet_tex[p]

func attach_unit(u: Dictionary, ob: Dictionary, w: int, h: int, k: float) -> void:
	var ax: float = float(u.ax)
	var ay: float = float(u.ay)
	var spr := Sprite2D.new()
	# 正式高清覆盖的帧不上传旧的整张 4× 图集（工人原表单张即约 32 MiB）。
	# 未重绘兵种和明确的 original 回退帧才装载原图。
	unit_nodes(u)["source_sheet"] = str(ob.sheet)
	spr.region_enabled = true
	spr.centered = false
	spr.region_rect = Rect2(0, 0, w * k, h * k)
	spr.scale = Vector2(1.0 / k, 1.0 / k)
	spr.position = Vector2(ax - w * 0.5, ay - h)
	surface.add_child(spr)
	unit_nodes(u)["spr"] = spr
	var color_slot := 0 if int(ob.owner) == int(_ui.host.player_owner) else int(ob.owner)
	unit_nodes(u)["skin"] = _ui.host.remaster_art.create_unit_skin(spr, int(ob.unit), color_slot, Vector2i(int(w * k), int(h * k)))
	if int(u.unit) in [16,17] and unit_nodes(u).skin != null:
		var offset: Vector2 = _ui.host.remaster_art.gate_wall_offset(str(_ui.host.map_id),Vector2i(int(u.A),int(u.B)))
		var foundation: float = _ui.host.remaster_art.gate_foundation_drop(str(_ui.host.map_id),Vector2i(int(u.A),int(u.B)))
		var module = load("res://presentation/battle/gate_module.gd").new(int(u.unit),unit_nodes(u).skin.texture,unit_nodes(u).skin.material,foundation)
		module.scale = Vector2(k,k)
		module.position = offset*k
		spr.add_child(module)
		unit_nodes(u)["gate_module"] = module
		unit_nodes(u)["gate_interior"] = module.recess
		unit_nodes(u).skin.visible = false
	if unit_nodes(u).skin == null:
		spr.texture = _sheet(str(ob.sheet))
		# 早期单张建筑替换需要原图内容框，完整图集路径不需要。
		unit_nodes(u)["skin"] = _ui.host.remaster_art.create_unit_skin(spr, int(ob.unit), color_slot, Vector2i(int(w * k), int(h * k)))
	var dia := Line2D.new()
	dia.width = 1.6
	dia.default_color = Color(0.2, 1.0, 0.2, 0.9)
	dia.points = PackedVector2Array([
		Vector2(0, -11), Vector2(22, 0), Vector2(0, 11), Vector2(-22, 0), Vector2(0, -11)])
	dia.position = Vector2(ax, ay - float(_ui.host.tile_hh))
	dia.z_index = 4000
	dia.visible = false
	surface.add_child(dia)
	unit_nodes(u)["diamond"] = dia
	var bar := ColorRect.new()
	bar.color = Color(0, 0, 0, 0.65)
	bar.size = Vector2(22, 4)
	bar.visible = false
	bar.z_index = 4000
	surface.add_child(bar)
	var fill := ColorRect.new()
	fill.color = Color(0.2, 0.9, 0.2, 0.95)
	fill.size = Vector2(20, 2)
	fill.position = Vector2(1, 1)
	bar.add_child(fill)
	unit_nodes(u)["hbar"] = bar
	unit_nodes(u)["hfill"] = fill

func free_unit(u: Dictionary) -> void:
	for key in ["spr", "diamond", "hbar"]:
		var n = unit_nodes(u).get(key, null)
		if n != null and is_instance_valid(n):
			n.queue_free()

## 位移同步（main._follow 每步调用）
	_ui._nodes_by_uid.erase(int(u.uid))

func place_unit(u: Dictionary) -> void:
	var s = unit_nodes(u).get("spr", null)
	if s != null:
		s.position = Vector2(float(u.ax) - float(u.w) * 0.5, float(u.ay) - float(u.h))

func capture_motion() -> void:
	_ui._motion_previous.clear()
	_ui._gait_previous.clear()
	for unit in _ui.host.units:
		if not bool(unit.is_building):
			_ui._motion_previous[int(unit.uid)]=Vector2(float(unit.ax),float(unit.ay))
			_ui._gait_previous[int(unit.uid)]=float(unit.get("walk_tick",0))

func interpolate_motion(alpha: float) -> void:
	for unit in _ui.host.units:
		if bool(unit.is_building) or not unit.alive:continue
		if unit_nodes(unit).get("spr")==null or not unit_nodes(unit).spr.visible:continue
		var current:=Vector2(float(unit.ax),float(unit.ay))
		var previous: Vector2=_ui._motion_previous.get(int(unit.uid),current)
		# Embarking, unloading and explicit relocation must snap, not slide through walls.
		var point:=previous.lerp(current,alpha) if previous.distance_squared_to(current)<_ui.host.tile_w*_ui.host.tile_w else current
		if unit_nodes(unit).get("spr")!=null:
			unit_nodes(unit).spr.position=point-Vector2(float(unit.w)*0.5,float(unit.h));unit_nodes(unit).spr.z_index=int(point.y)
		if unit_nodes(unit).get("diamond")!=null:
			unit_nodes(unit).diamond.position=point-Vector2(0,float(_ui.host.tile_hh));unit_nodes(unit).diamond.z_index=int(point.y)-1
		if unit_nodes(unit).get("hbar")!=null:unit_nodes(unit).hbar.position=point-Vector2(11,float(unit.h)+9)
		if float(unit.get("die_t",-1)) < 0 and bool(unit.get("moved",false)):
			var now:float=float(unit.get("walk_tick",0))
			var before:float=_ui._gait_previous.get(int(unit.uid),now)
			_apply_mobile_pose(unit,lerpf(before,now,alpha))

func hide_unit(u: Dictionary) -> void:
	var s = unit_nodes(u).get("spr", null)
	if s != null:
		s.visible = false
	var b = unit_nodes(u).get("hbar", null)
	if b != null:
		b.visible = false

func fade_unit(u: Dictionary, alpha: float) -> void:
	var s = unit_nodes(u).get("spr", null)
	if s != null:
		s.modulate = Color(1, 1, 1, alpha)

func set_unit_attached(u: Dictionary, attached: bool) -> void:
	var s = unit_nodes(u).get("spr", null)
	if s != null:
		s.visible = not attached
	var d = unit_nodes(u).get("diamond", null)
	if d != null:
		d.visible = false if attached else d.visible
	var hb = unit_nodes(u).get("hbar", null)
	if hb != null and attached:
		hb.visible = false

func update_visual(u: Dictionary) -> void:
	var vis: bool
	if bool(u.is_building):
		vis = bool(_ui.host.show_buildings) and bool(_ui.host.sec_visible.get(u.owner, true))
	else:
		vis = bool(_ui.host.show_units) and bool(_ui.host.sec_visible.get(u.owner, true))
		# 装载中的单位（模式 0xC）不在图上：由运输船携带，不画精灵/选中框/血条。
		if bool(u.get("attached", false)) or int(u.get("site_inside_uid", -1)) >= 0:
			vis = false
	if int(u.owner) != int(_ui.host.player_owner):
		vis = vis and _ui.host.visibility.is_visible(Vector2(u.ax, u.ay))
	if vis and not bool(u.is_building) and _ui.host.cam!=null:
		var size: Vector2=surface.get_viewport_rect().size/_ui.host.cam.zoom
		var area:=Rect2(_ui.host.cam.position-size*0.5,size).grow(128)
		vis=area.has_point(Vector2(float(u.ax),float(u.ay)-float(u.h)*0.5))
	var sel: Array = _ui.host.selected
	var spr = unit_nodes(u).get("spr", null)
	if spr != null:
		spr.visible = vis
		spr.z_index = int(u.ay)          # 按底边排序：单位与建筑统一
	var dia = unit_nodes(u).get("diamond", null)
	if dia != null:
		dia.visible = vis and (u in sel)
		dia.position = Vector2(float(u.ax), float(u.ay) - float(_ui.host.tile_hh))
		dia.z_index=int(u.ay)-1
		if bool(u.is_building):
			dia.z_index=int(u.ay)-1 # Ground outline is occluded by the building itself.
			var cells: Array=u.get("occupied_cells",[])
			if cells.is_empty():cells=_ui.host.nav.building_footprint(int(u.unit),Vector2(u.ax,u.ay),float(u.w))
			dia.position=Vector2.ZERO
			if cells!=dia.get_meta("footprint",[]):
				var outline: PackedVector2Array=_ui.host.nav.footprint_outline(cells)
				if not outline.is_empty():outline.append(outline[0])
				dia.points=outline;dia.set_meta("footprint",cells.duplicate())
	if not bool(u.is_building) and not vis:
		if unit_nodes(u).get("hbar")!=null:unit_nodes(u).hbar.visible=false
		return # Fogged/offscreen units must not load unseen HD animation pages.
	if bool(u.is_building):
		set_frame(u, (1 if bool(u.get("gate_open", false)) else 0) if int(u.unit) in [16, 17] and not bool(u.get("site", false)) else int(u.get("build_frame", 0)))
		if unit_nodes(u).has("gate_module"):
			unit_nodes(u).skin.visible = false
			unit_nodes(u).gate_module.visible = not bool(u.get("site",false))
			unit_nodes(u).gate_module.update_open(bool(u.get("gate_open",false)))
			unit_nodes(u).gate_interior.visible = bool(u.get("gate_open",false)) and not bool(u.get("site",false))
	else:
		_apply_mobile_pose(u)
	var hurt: bool = float(u.hp) < float(u.maxhp) - 0.5
	var bar = unit_nodes(u).get("hbar", null)
	if bar != null:
		bar.visible = vis and hurt
		if hurt:
			bar.position = Vector2(float(u.ax) - 11, float(u.ay) - float(u.h) - 9)
			var r: float = clampf(float(u.hp) / float(u.maxhp), 0.0, 1.0)
			var fill = unit_nodes(u).get("hfill", null)
			if fill != null:
				fill.size = Vector2(20.0 * r, 2)
				fill.color = Color(1.0 - r * 0.8, r * 0.9 + 0.1, 0.15)

func mobile_pose(u: Dictionary, gait_tick := -1.0) -> Dictionary:
	var moving := bool(u.get("moved",false))
	var action := not moving and str(u.state) in ["attack","repair"]
	var carrying := int(u.unit)==30 and float(u.get("carry",0))>0 and not action
	var direction := ViewMath.sprite_direction(int(u.get("move_facing",u.dir)))
	# Historical clip labels are misleading: turn is the gait row; walk is the
	# combat action row (the general visibly swings his weapon in those frames).
	var clip := "turn"
	var step := 0
	if moving:
		step = floori((float(u.get("walk_tick", 0)) if gait_tick<0 else gait_tick)/FRAME_TICKS)
	if carrying:
		clip={"wood":"act1","stone":"act2","gold":"act2","food":"act3"}.get(str(u.get("carry_kind","")),"act2")
		if not moving:step=0
	if action:
		clip=_ui.host.ActionClock.clip_name(u);step=int(u.get("action_phase",0));direction=ViewMath.sprite_direction(int(u.dir))
	return {"clip":clip,"direction":direction,"step":step}

func _apply_mobile_pose(u: Dictionary, gait_tick := -1.0) -> void:
	var pose:=mobile_pose(u,gait_tick)
	var frame:=ViewMath.clip_frame(u,str(pose.clip),int(pose.direction),int(pose.step))
	if frame<0:frame=ViewMath.clip_frame(u,"turn",int(pose.direction),0)
	if frame<0:frame=ViewMath.clip_frame(u,"walk",int(pose.direction),0)
	set_frame(u,frame if frame>=0 else 0)

func set_frame(u: Dictionary, f: int) -> void:
	if f < 0 or int(u.count) <= 0:
		return
	f = f % int(u.count)               # R8：夹取，避免 count<8 时取到填充格
	if unit_nodes(u).has("frame") and int(unit_nodes(u).frame)==f:return
	var spr = unit_nodes(u).get("spr", null)
	var skin: Sprite2D = unit_nodes(u).get("skin", null)
	if skin != null:
		# 完整图集逐帧切换；早期单帧重绘仍只覆盖完成态。
		var use_skin: bool = bool(_ui.host.remaster_art.update_skin(skin, f, bool(u.is_building), float(u.die_t)))
		if spr != null:
			spr.self_modulate = Color(1, 1, 1, 0 if use_skin else 1)
			if not use_skin and spr.texture == null:
				spr.texture = _sheet(str(unit_nodes(u).source_sheet))
	unit_nodes(u)["frame"] = f
	if spr != null:
		spr.region_rect = ViewMath.frame_rect(u, f)

func unit_nodes(u: Dictionary) -> Dictionary:
	var uid := int(u.uid)
	if not _ui._nodes_by_uid.has(uid): _ui._nodes_by_uid[uid] = {}
	return _ui._nodes_by_uid[uid]
