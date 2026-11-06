extends RefCounted
## movement: composed battle behavior.
const State = preload("res://simulation/battle_state.gd")
const Config = preload("res://simulation/battle_config.gd")
const Dependencies = preload("res://simulation/ports/movement_dependencies.gd")
var battle: State
var ports := Dependencies.new()

func _init(data: State) -> void:
	battle = data

func _cell_of_px(px: float, py: float) -> Vector2i:
	return battle.nav.cell_of_px(px, py)

func _anchor_of(a: int, b: int) -> Vector2:
	return battle.nav.anchor_of(a, b)

func _near_walkable(c: Vector2i) -> Vector2i:
	return battle.nav.near_walkable(c)

func _path_to(u: Dictionary, target_px: Vector2, exact: bool) -> Array:
	var layer := ports._nav_layer(u)
	var start_cell := ports._unit_cell(u)
	var target_cell := battle.nav.cell_of_px(target_px.x, target_px.y)
	var avoid: Array = []
	for other in battle.units:
		if other == null or not bool(other.get("alive", false)) or float(other.get("die_t", -1)) >= 0.0: continue
		if bool(other.get("is_building", false)) or bool(other.get("attached", false)) or int(other.get("site_inside_uid", -1)) >= 0: continue
		if int(other.get("uid", -1)) == int(u.get("uid", -1)): continue
		if ports._nav_layer(other) != layer: continue
		var oc := ports._unit_cell(other)
		# 只避让起点/终点附近的单位：远处单位既不影响本段路径，也会把 A* 临时挖出大量洞。
		if maxi(absi(oc.x - start_cell.x), absi(oc.y - start_cell.y)) > 12 \
				and maxi(absi(oc.x - target_cell.x), absi(oc.y - target_cell.y)) > 12:
			continue
		for raw in ports._footprint_cells(other):
			var fc: Vector2i = raw
			if maxi(absi(fc.x - start_cell.x), absi(fc.y - start_cell.y)) > 12 \
					and maxi(absi(fc.x - target_cell.x), absi(fc.y - target_cell.y)) > 12:
				continue
			avoid.append(fc)
	# R04：把单位占格档交给导航，A* 只规划整块身体放得下的锚点。
	var path := battle.nav.find_path_avoiding(Vector2(u.ax, u.ay), target_px, exact, avoid, layer, int(u.owner), int(u.get("unit", -1)))
	# 被其他单位围死时退回普通寻路；最终路点仍由 _follow 的叠格检查兜底。
	if path.is_empty():
		path = battle.nav.find_path(Vector2(u.ax, u.ay), target_px, exact, layer, int(u.owner), int(u.get("unit", -1)))
	return path

func _follow(u: Dictionary, delta: float) -> bool:
	if u.path.is_empty():
		return true
	if int(u.pi) < 0 or int(u.pi) >= u.path.size():
		u.path.clear(); u.pi = 0
		return true
	# REQ-003：世界在路径生成后会变化（建筑落成/拆除、地形事件、门被毁）——
	# 提交位移前校验**当前段**仍通行（segment_clear_from 跳过自己脚下的格）。
	# 被堵：清路、停下，返回 **false**（≠"走完了"）——move 分支靠这个保住订单，
	# 下一 tick 按新世界重寻路；攻击/采集/运货分支本来就会在路径为空时自愈重寻路。
	var cur_wp: Vector2 = u.path[u.pi]
	var final_waypoint: bool = int(u.pi) >= u.path.size() - 1
	# 单位不能叠格：只在**最后一个路点**（真正落脚点）检查占用。
	# 中途格允许穿过，否则前面的单位会把整条路堵死（实测采集工人 100 秒原地不动）。
	var next_cell := battle.nav.cell_of_px(cur_wp.x, cur_wp.y)
	if final_waypoint and not ports._unit_placement_free(next_cell, int(u.get("unit", -1)), ports._nav_layer(u), int(u.uid)):
		# R14：终点被占时不能悄然丢单。行军改停到附近合法空格；其余状态保持原命令，
		# 由各自分支在下一 tick 重新找落脚点。
		return _replan_blocked_destination(u, cur_wp)
	var layer := ports._nav_layer(u)
	var unit_cls := preload("res://simulation/systems/unit_footprint.gd").class_of(int(u.get("unit", -1)))
	var position:=Vector2(float(u.ax),float(u.ay))
	var probe:=position.move_toward(cur_wp,Config.SPEED*ports._spd_mult(u)*delta)
	var segment_ok := battle.nav.segment_clear_from(position, probe, layer) if unit_cls <= 0 \
			else battle.nav.body_segment_clear_from(position, probe, layer, unit_cls)
	if not segment_ok:
		# 等距格心之间的直线可能从第三个格角擦过；A* 只保证“相邻格连通”，
		# 不保证像素采样不碰角。单格单位在目标格本身可走时放行；多格单位
		# 的整块扫掠失败一律按动态阻挡处理（R04：身体不得穿越非法占格）。
		var target_cell := battle.nav.cell_of_px(probe.x, probe.y)
		if unit_cls > 0 or battle.nav.is_solid(target_cell, layer):
			var dest: Vector2 = u.path[u.path.size() - 1]   # 最后一个路点 = 本单目的地
			u.path = []
			u.pi = 0
			u["repath"] = 0.8
			u["blocked_n"] = int(u.get("blocked_n", 0)) + 1
			if u.state == "move" and int(u["blocked_n"]) <= 2:
				u["repath_to"] = dest    # 停下并请求重寻路；连续 3 次被堵（见下）才弃单
			return false
	var remaining: float=Config.SPEED*ports._spd_mult(u)*delta
	# Spend the complete tick distance, including across short/duplicate waypoints.
	# The old 6px early arrival discarded distance and paused at every grid corner.
	while not u.path.is_empty() and remaining>0.00001:
		var waypoint: Vector2=u.path[u.pi]
		var offset:=waypoint-Vector2(float(u.ax),float(u.ay))
		var distance:=offset.length()
		if distance>0.00001:
			var step:=minf(remaining,distance)
			var point:=Vector2(float(u.ax),float(u.ay))+offset*(step/distance)
			u.ax=point.x;u.ay=point.y
			var cell:=battle.nav.cell_of_px(u.ax,u.ay);u.A=cell.x;u.B=cell.y
			u.dir=int(round(offset.angle()/(PI/4.0)))&7
			u.moved=true;u.blocked_n=0
			remaining-=step;ports._place_unit(u)
			if step<distance-0.00001:return false
		u.pi+=1
		if u.pi>=u.path.size():
			u.path=[];u.pi=0;return true
		# Validate the next segment before crossing a corner within this tick.
		var next: Vector2=u.path[u.pi]
		if int(u.pi)==u.path.size()-1 and not ports._unit_placement_free(battle.nav.cell_of_px(next.x,next.y),int(u.unit),layer,int(u.uid)):
			return _replan_blocked_destination(u,next)
		position=Vector2(float(u.ax),float(u.ay))
		probe=position.move_toward(next,remaining)
		var clear: bool=battle.nav.segment_clear_from(position,probe,layer) if unit_cls<=0 else battle.nav.body_segment_clear_from(position,probe,layer,unit_cls)
		if not clear:return false
	return false

func _replan_blocked_destination(u: Dictionary, dest_px: Vector2) -> bool:
	var state := str(u.get("state", ""))
	var layer := ports._nav_layer(u)
	var uid := int(u.get("uid", -1))
	var unit_id := int(u.get("unit", -1))
	if state == "move":
		var dest_cell := battle.nav.cell_of_px(dest_px.x, dest_px.y)
		for r in range(1, 4):
			for dx in range(-r, r + 1):
				for dy in range(-r, r + 1):
					if maxi(absi(dx), absi(dy)) != r:
						continue
					var c := Vector2i(clampi(dest_cell.x + dx, 0, int(battle.map_data.rows) - 1),
						clampi(dest_cell.y + dy, 0, int(battle.map_data.cols) - 1))
					if c == dest_cell or not ports._unit_placement_free(c, unit_id, layer, uid):
						continue
					var p := battle.nav.anchor_of(c.x, c.y)
					var path := _path_to(u, p, true)
					if path.is_empty():
						continue
					u.path = path
					u.pi = 0
					u["blocked_n"] = 0
					u.erase("repath_to")
					return false
		u.path = []
		u.pi = 0
		u["blocked_n"] = int(u.get("blocked_n", 0)) + 1
		if int(u["blocked_n"]) >= 8:
			u.state = "idle"
			u.erase("repath_to")
			ports._feedback("目的地被占用，部队已停下")
		else:
			u["repath_to"] = dest_px
		return false
	# 采集/交付/施工/攻击等：落脚点由各自分支下一 tick 重新计算。
	u.path = []
	u.pi = 0
	u["blocked_n"] = int(u.get("blocked_n", 0)) + 1
	return false

func _resolve_navigation_overlaps() -> void:
	# 旧关卡的单格建筑占用可能与新的地面占地重叠，统一迁移到最近合法锚点。
	# 水军按**水面层**判合法（船本来就停在水上，用陆地层会把它们全搬到岸上）。
	# 读档恢复必须保持存档位置：这里只处理**锚点**被占地压住的情况（旧档把工人/
	# 单位包进建筑）。整块身体的合法性由寻路/移动提交（R04）保证，不在读档时改写坐标。
	for u in battle.units:
		if u.is_building or not u.alive or float(u.get("die_t", -1)) >= 0.0 or int(u.get("site_inside_uid", -1)) >= 0:
			continue
		var layer := ports._nav_layer(u)
		var cell := battle.nav.cell_of_px(u.ax, u.ay)
		if not battle.nav.is_solid(cell, layer):
			continue
		var safe := battle.nav.near_walkable(cell, layer)
		if battle.nav.is_solid(safe, layer):
			continue
		var point := battle.nav.anchor_of(safe.x, safe.y)
		u.ax = point.x; u.ay = point.y; u.A = safe.x; u.B = safe.y
		ports._place_unit(u)

func _march_destination(unit: Dictionary, target: Vector2, reserved: Dictionary) -> Vector2:
	var origin:=battle.nav.cell_of_px(target.x,target.y)
	for radius in range(7):
		for dx in range(-radius,radius+1):
			for dy in range(-radius,radius+1):
				if maxi(absi(dx),absi(dy))!=radius:continue
				var cell:=origin+Vector2i(dx,dy)
				if not ports._unit_placement_free(cell,int(unit.unit),ports._nav_layer(unit),int(unit.uid)):continue
				var cells:=preload("res://simulation/systems/unit_footprint.gd").shape(int(unit.unit),cell)
				if cells.any(func(c):return reserved.has(c)):continue
				for c in cells:reserved[c]=true
				return target if radius==0 else battle.nav.anchor_of(cell.x,cell.y)
	return target

func _anchor_of_cell(cell: Vector2i) -> Vector2:
	return _anchor_of(clampi(cell.x, 0, int(battle.map_data.rows) - 1), clampi(cell.y, 0, int(battle.map_data.cols) - 1))

func _move_unit_to_cell(u: Dictionary, cell: Vector2i) -> bool:
	var c := Vector2i(clampi(cell.x, 0, int(battle.map_data.rows) - 1), clampi(cell.y, 0, int(battle.map_data.cols) - 1))
	var path := _path_to(u, _anchor_of_cell(c), true)
	if path.is_empty():
		var near := battle.nav.near_walkable(c)
		if not battle.nav.is_solid(near):
			path = _path_to(u, _anchor_of_cell(near), true)
	if path.is_empty():
		return false
	ports._cancel_unit_command(u)
	u["hold"] = false
	u["state"] = "move"
	u["path"] = path
	u["pi"] = 0
	return true
