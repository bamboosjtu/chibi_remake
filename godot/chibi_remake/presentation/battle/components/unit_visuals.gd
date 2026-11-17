extends RefCounted
const ViewMath = preload("res://presentation/battle/view_math.gd")
## unit visuals: presentation component.
const UIState = preload("res://presentation/battle/components/battle_view_state.gd")
var _ui: UIState
var surface: Node2D
var ports = preload("res://presentation/battle/components/ports/unit_visuals_dependencies.gd").new()
const Textures = preload("res://presentation/battle/runtime_textures.gd")
var pending_visuals := {}
var _world_dirty := false
var sync_calls := 0
var sync_microseconds := 0

func queue_visual(unit: Dictionary) -> void:
	pending_visuals[int(unit.uid)]=true

func queue_world_visuals() -> void:
	_world_dirty=true

func flush_visuals(interpolating := false) -> void:
	if not _world_dirty and pending_visuals.is_empty():return
	var begin:=Time.get_ticks_usec()
	# Resolve UIDs against the current world: queued old-world dictionaries must
	# never survive a load/rollback and overwrite the new presentation.
	var context:=_visual_context();context["interpolating"]=interpolating
	for unit in _ui.host.unit_views():
		if _world_dirty or pending_visuals.has(int(unit.uid)):
			update_visual(unit,context)
			# The following interpolation pass writes the final mobile transform.
			# Avoid dirtying that subtree at the current position first.
			if not interpolating or bool(unit.is_building):place_unit(unit)
			sync_calls+=1
	pending_visuals.clear();_world_dirty=false
	sync_microseconds+=Time.get_ticks_usec()-begin

func performance_counters() -> Dictionary:
	return {"syncCalls":sync_calls,"syncMicroseconds":sync_microseconds}

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
	unit_nodes(u).erase("health_ratio");unit_nodes(u).erase("draw_visible")
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
	_ui._motion_previous.erase(int(u.uid));_ui._gait_previous.erase(int(u.uid))

func place_unit(u: Dictionary) -> void:
	var s = unit_nodes(u).get("spr", null)
	if s != null:
		var point:=Vector2(float(u.ax) - float(u.w) * 0.5, float(u.ay) - float(u.h))
		if s.position!=point:s.position=point

func capture_motion() -> void:
	for unit: Dictionary in _ui.host.motion_views():
		var uid:=int(unit.uid)
		var nodes: Dictionary=_ui._nodes_by_uid.get(int(unit.uid),{})
		# Hidden units have no interpolated pixels; first reveal starts at the
		# current position, just as a newly attached/restored visual does.
		if not bool(unit.is_building) and nodes.get("spr")!=null and nodes.spr.visible:
			var point:=Vector2(float(unit.ax),float(unit.ay));var gait:=float(unit.get("walk_tick",0))
			if _ui._motion_previous.get(uid)!=point:_ui._motion_previous[uid]=point
			if _ui._gait_previous.get(uid)!=gait:_ui._gait_previous[uid]=gait
		else:
			_ui._motion_previous.erase(uid);_ui._gait_previous.erase(uid)

func interpolate_motion(alpha: float) -> void:
	var tile_width: float=_ui.host.tile_w;var half_height: float=_ui.host.tile_hh
	for row in _ui.host.unit_views():
		if bool(row.is_building) or not row.alive:continue
		var nodes:=unit_nodes(row)
		if nodes.get("spr")==null or not nodes.spr.visible:continue
		var unit: Dictionary=_ui.host.visual_unit(int(row.uid))
		if unit.is_empty():continue
		var current:=Vector2(float(unit.ax),float(unit.ay))
		var previous: Vector2=_ui._motion_previous.get(int(unit.uid),current)
		# Embarking, unloading and explicit relocation must snap, not slide through walls.
		var point:=previous.lerp(current,alpha) if previous.distance_squared_to(current)<tile_width*tile_width else current
		if nodes.get("spr")!=null:
			var sprite_point:=point-Vector2(float(unit.w)*0.5,float(unit.h))
			if nodes.spr.position!=sprite_point:nodes.spr.position=sprite_point
			if nodes.spr.z_index!=int(point.y):nodes.spr.z_index=int(point.y)
		if nodes.get("diamond")!=null:
			var diamond_point:=point-Vector2(0,half_height)
			if nodes.diamond.position!=diamond_point:nodes.diamond.position=diamond_point
			if nodes.diamond.z_index!=int(point.y)-1:nodes.diamond.z_index=int(point.y)-1
		if nodes.get("hbar")!=null:
			var bar_point:=point-Vector2(11,float(unit.h)+9)
			if nodes.hbar.position!=bar_point:nodes.hbar.position=bar_point
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

func apply_loaded_unit(unit: Dictionary) -> void:
	var nodes := unit_nodes(unit)
	if nodes.get("spr") != null:
		nodes.spr.visible = unit.alive
		nodes.spr.modulate = Color(1,1,1,maxf(0.0,1.0-maxf(0.0,float(unit.die_t))*0.55))
	if not unit.alive and nodes.get("hbar") != null: nodes.hbar.visible = false

func fade_unit(u: Dictionary, alpha: float) -> void:
	var s = unit_nodes(u).get("spr", null)
	if s != null:
		s.modulate = Color(1, 1, 1, alpha)

func set_unit_attached(u: Dictionary, attached: bool) -> void:
	unit_nodes(u).erase("draw_visible")
	var s = unit_nodes(u).get("spr", null)
	if s != null:
		s.visible = not attached
	var d = unit_nodes(u).get("diamond", null)
	if d != null:
		d.visible = false if attached else d.visible
	var hb = unit_nodes(u).get("hbar", null)
	if hb != null and attached:
		hb.visible = false

func _visual_context() -> Dictionary:
	var selected: Dictionary={}
	for unit in _ui.host.selection_views():selected[int(unit.uid)]=true
	var camera=_ui.host.cam;var area:=Rect2();var has_camera: bool=camera!=null
	if has_camera:
		var size: Vector2=surface.get_viewport_rect().size/camera.zoom
		area=Rect2(camera.position-size*0.5,size).grow(128)
	return {"selected":selected,"player":int(_ui.host.player_owner),"buildings":bool(_ui.host.show_buildings),"units":bool(_ui.host.show_units),"sides":_ui.host.sec_visible,"visibility":_ui.host.visibility,"camera":has_camera,"area":area,"halfHeight":float(_ui.host.tile_hh)}

func update_visual(u: Dictionary, context: Dictionary={}) -> void:
	if context.is_empty():context=_visual_context()
	var nodes:=unit_nodes(u)
	var vis: bool
	if bool(u.is_building):
		vis = context.buildings and bool(context.sides.get(u.owner,true))
	else:
		vis = context.units and bool(context.sides.get(u.owner,true))
		# 装载中的单位（模式 0xC）不在图上：由运输船携带，不画精灵/选中框/血条。
		if bool(u.get("attached", false)) or int(u.get("site_inside_uid", -1)) >= 0:
			vis = false
	if int(u.owner)!=int(context.player):
		vis=vis and context.visibility.is_visible(Vector2(u.ax,u.ay))
	if vis and not bool(u.is_building) and context.camera:
		vis=(context.area as Rect2).has_point(Vector2(float(u.ax),float(u.ay)-float(u.h)*0.5))
	if not vis:
		if bool(nodes.get("draw_visible",true)):
			for key in ["spr","diamond","hbar"]:
				if nodes.get(key)!=null:nodes[key].visible=false
		nodes["draw_visible"]=false
		return # Invisible geometry/poses are sampled when the unit becomes visible.
	u = _ui.host.visual_unit(int(u.uid))
	if u.is_empty(): return
	nodes["draw_visible"]=true

	var spr = nodes.get("spr", null)
	if spr != null:
		spr.visible = vis
		if spr.z_index!=int(u.ay):spr.z_index=int(u.ay) # 按底边排序：单位与建筑统一
	var dia = nodes.get("diamond", null)
	if dia != null:
		dia.visible = vis and context.selected.has(int(u.uid))
		var outline_point:=Vector2(float(u.ax), float(u.ay) - float(context.halfHeight))
		if not bool(u.is_building) and dia.position!=outline_point:dia.position=outline_point
		if dia.z_index!=int(u.ay)-1:dia.z_index=int(u.ay)-1
		if bool(u.is_building):
			dia.z_index=int(u.ay)-1 # Ground outline is occluded by the building itself.
			var cells: Array=u.get("occupied_cells",[])
			if dia.position!=Vector2.ZERO:dia.position=Vector2.ZERO
			if cells!=dia.get_meta("footprint",[]):
				var outline := PackedVector2Array(u.footprint_outline)
				dia.points=outline;dia.set_meta("footprint",cells.duplicate())
	if not bool(u.is_building) and not vis:
		if nodes.get("hbar")!=null:nodes.hbar.visible=false
		return # Fogged/offscreen units must not load unseen HD animation pages.
	if float(u.get("die_t",-1)) >= 0:
		var rule = preload("res://simulation/definitions/death_visual.gd")
		var frame: int = rule.frame(u,float(u.die_t))
		if frame >= 0: set_frame(u,frame)
		else: hide_unit(u)
		fade_unit(u,rule.alpha(u,float(u.die_t)))
		if nodes.get("hbar") != null: nodes.hbar.hide()
		if nodes.get("diamond") != null: nodes.diamond.hide()
		return
	if bool(u.is_building):
		set_frame(u, (1 if bool(u.get("gate_open", false)) else 0) if int(u.unit) in [16, 17] and not bool(u.get("site", false)) else int(u.get("build_frame", 0)))
		if nodes.has("gate_module"):
			nodes.skin.visible = false
			nodes.gate_module.visible = not bool(u.get("site",false))
			nodes.gate_module.update_open(bool(u.get("gate_open",false)))
			nodes.gate_interior.visible = bool(u.get("gate_open",false)) and not bool(u.get("site",false))
	elif not bool(u.get("moved",false)) or not bool(context.get("interpolating",false)):
		_apply_mobile_pose(u)
	var hurt: bool = float(u.hp) < float(u.maxhp) - 0.5
	var bar = nodes.get("hbar", null)
	if bar != null:
		bar.visible = vis and hurt
		if hurt:
			var bar_point:=Vector2(float(u.ax) - 11, float(u.ay) - float(u.h) - 9)
			if not context.get("interpolating",false) or bool(u.is_building):
				if bar.position!=bar_point:bar.position=bar_point
			var r: float = clampf(float(u.hp) / float(u.maxhp), 0.0, 1.0)
			var fill = nodes.get("hfill", null)
			if fill != null and nodes.get("health_ratio")!=r:
				fill.size = Vector2(20.0 * r, 2)
				fill.color = Color(1.0 - r * 0.8, r * 0.9 + 0.1, 0.15)
				nodes["health_ratio"]=r

const POSE_CLIPS := ["turn","act1","act2","act3","walk"]
const CARRY_POSE_CLIPS := {"wood":1,"stone":2,"gold":2,"food":3}
func mobile_pose(u: Dictionary, gait_tick := -1.0) -> Dictionary:
	var pose:=_pose_components(u,gait_tick)
	return {"clip":POSE_CLIPS[pose.x],"direction":pose.y,"step":pose.z}

func _pose_components(u: Dictionary, gait_tick: float) -> Vector3i:
	var moving := bool(u.get("moved",false))
	var action := not moving and str(u.state) in ["attack","repair"]
	var carrying := int(u.unit)==30 and float(u.get("carry",0))>0 and not action
	var direction := ViewMath.sprite_direction(int(u.get("move_facing",u.dir)))
	# Historical clip labels are misleading: turn is the gait row; walk is the
	# combat action row (the general visibly swings his weapon in those frames).
	var clip := 0
	var step := 0
	if moving:
		step = floori((float(u.get("walk_tick", 0)) if gait_tick<0 else gait_tick)/FRAME_TICKS)
	if carrying:
		clip=int(CARRY_POSE_CLIPS.get(str(u.get("carry_kind","")),2))
		if not moving:step=0
	if action:
		clip=4;step=int(u.get("action_phase",0));direction=ViewMath.sprite_direction(int(u.dir))
	return Vector3i(clip,direction,step)

func _apply_mobile_pose(u: Dictionary, gait_tick := -1.0) -> void:
	var pose:=_pose_components(u,gait_tick)
	var frame:=ViewMath.clip_frame(u,str(POSE_CLIPS[pose.x]),pose.y,pose.z)
	if frame<0:frame=ViewMath.clip_frame(u,"turn",pose.y,0)
	if frame<0:frame=ViewMath.clip_frame(u,"walk",pose.y,0)
	set_frame(u,frame if frame>=0 else 0)

func set_frame(u: Dictionary, f: int) -> void:
	var nodes:=unit_nodes(u)
	if f < 0 or int(u.count) <= 0:
		return
	f = f % int(u.count)               # R8：夹取，避免 count<8 时取到填充格
	if nodes.has("frame") and int(nodes.frame)==f:return
	var spr = nodes.get("spr", null)
	var skin: Sprite2D = nodes.get("skin", null)
	if skin != null:
		# 完整图集逐帧切换；早期单帧重绘仍只覆盖完成态。
		var use_skin: bool = bool(_ui.host.remaster_art.update_skin(skin, f, bool(u.is_building), float(u.die_t)))
		if spr != null:
			spr.self_modulate = Color(1, 1, 1, 0 if use_skin else 1)
			if not use_skin and spr.texture == null:
				spr.texture = _sheet(str(nodes.source_sheet))
	nodes["frame"] = f
	if spr != null:
		spr.region_rect = ViewMath.frame_rect(u, f)

func unit_nodes(u: Dictionary) -> Dictionary:
	var uid := int(u.uid)
	if not _ui._nodes_by_uid.has(uid): _ui._nodes_by_uid[uid] = {}
	return _ui._nodes_by_uid[uid]
