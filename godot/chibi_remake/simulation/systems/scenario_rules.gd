extends RefCounted
const Access = preload("res://simulation/ports/scenario_rules_access.gd")
var host: Access
var missions := {}
func _init(h: Object) -> void:
	host = h.simulation_access("scenario_rules") if h.has_method("simulation_access") else h
	var f := FileAccess.open("res://data/db/scenario_rules.json", FileAccess.READ)
	if f != null:
		missions = JSON.parse_string(f.get_as_text()).get("missions", {})

func tick() -> int:
	for stage in missions.get(str(host.scenario_mission), {}).get("stages", []):
		var key := "%d/%s" % [int(host.scenario_mission), str(stage.id)]
		if host.task_latches.get(key, false):
			continue
		var ready := true
		for prerequisite in stage.get("requires", []):
			ready = ready and bool(host.task_latches.get("%d/%s" % [int(host.scenario_mission), str(prerequisite)], false))
		if not ready or not condition(stage.condition):
			continue
		host.task_latches[key] = true
		for effect in stage.get("effects", []):
			apply_effect(effect)
		if bool(stage.get("win", false)):
			host.objective_done = true
			return 1
		if bool(stage.get("yield", false)):
			return 0
	return 1 if host.objective_done else 0

## 参战方列表按序号取归属（0 基）。越界/未定义返回 -1。
func side_owner(index: int) -> int:
	if index < 0 or index >= host.scenario_sides.size(): return -1
	return int((host.scenario_sides[index] as Dictionary).get("owner", -1))

## 该参战方是否已无任何存活实体（含建筑；淡出中的尸体不算存活）。
func side_cleared(index: int) -> bool:
	var owner := side_owner(index)
	if owner < 0: return false
	for u in host.units:
		if int(u.get("owner", -1)) != owner: continue
		if bool(u.get("alive", false)) and float(u.get("die_t", -1)) < 0.0:
			return false
	return true

func side_matches(u: Dictionary, side: String) -> bool:
	return int(u.owner) == int(host.player_owner) if side == "player" else int(u.owner) != int(host.player_owner) and int(u.owner) != 0

func candidates(side: String) -> Array:
	var out := []
	for u in host.units:
		if u.alive and u.die_t < 0.0 and side_matches(u, side):
			out.append(u)
	return out

func condition(c: Dictionary) -> bool:
	if str(c.kind) == "all":
		for child in c.conditions:
			if not condition(child):
				return false
		return true
	# R12 任务 29：参战方列表按序号取第 3 方；“单位清空”按该方**全部存活实体**
	# （机动单位 + 建筑）计数，与默认歼灭规则的实体范围一致。
	if str(c.kind) == "side_cleared":
		return side_cleared(int(c.get("sideIndex", -1)))
	for u in candidates(str(c.get("side", "player"))):
		var officer := int(u.get("officer", {}).get("index", -1)) + 1
		match str(c.kind):
			"officer_in_rect", "unit_in_rect":
				var r: Array = c.rect
				if (str(c.kind) == "unit_in_rect" or officer == int(c.officer)) and int(u.A) >= int(r[0]) and int(u.A) <= int(r[1]) and int(u.B) >= int(r[2]) and int(u.B) <= int(r[3]):
					return true
			"officers_near":
				if officer != int(c.officer):
					continue
				for other in candidates(str(c.otherSide)):
					if int(other.get("officer", {}).get("index", -1)) + 1 == int(c.otherOfficer) and abs(int(u.A) - int(other.A)) < int(c.radius) and abs(int(u.B) - int(other.B)) < int(c.radius):
						return true
			"unit_type_present":
				if int(u.unit) == int(c.unit):
					return true
			"enemy_mobile_present":
				for enemy in candidates("enemy"):
					if not enemy.is_building:
						return true
	return false

func apply_effect(effect: Dictionary) -> void:
	match str(effect.kind):
		"officer_experience":
			var amount=effect.get("amount",host.map_data.get("scenario",{}).get(str(effect.get("experienceParameter","eventExperience"))))
			if amount==null:return # Unresolved research parameters are never replaced by invented XP.
			for u in candidates(str(effect.get("side","player"))):
				if int(u.get("officer",{}).get("index",-1))+1==int(effect.get("officer",-1)):host._grant_officer_exp(u,float(amount))
		"status_delta":
			for u in candidates(str(effect.side)):
				u["status_173"] = (int(u.get("status_173", 70)) + int(effect.amount)) & 255
		"event":
			host.task_events.append({"id": int(effect.id), "tick": int(host.sim_tick)})
		"clear_tiles":
			for cell in effect.cells:
				host.terrain_changes["%d/%d/%d" % [int(effect.layer), int(cell[0]), int(cell[1])]] = 65535
				var c := Vector2i(int(cell[0]), int(cell[1]))
				if host.map_data.has("terrainWalkable"):
					host.map_data.terrainWalkable[c.x * int(host.map_data.cols) + c.y] = 1
				host.nav.unblock(c)
		"enemy_order":
			for enemy in candidates("enemy"):
				if enemy.is_building:
					continue
				var target: Vector2 = host.nav.anchor_of(int(effect.target[0]), int(effect.target[1]))
				enemy.path = host.nav.find_path(Vector2(enemy.ax, enemy.ay), target, false, host._nav_layer(enemy), int(enemy.get("owner", -1)), int(enemy.get("unit", -1)))
				enemy.pi = 0
				enemy.state = "move" if not enemy.path.is_empty() else "idle"
				# DAT_0048534c initial value is 100 in the PE data section.
				var amount: int = int(host.map_data.get("scenario", {}).get(str(effect.experienceParameter), 100))
				var id: int = int(enemy.get("officer", {}).get("index", -1))
				if id >= 0:
					host.officer_progress[id] = (int(host.officer_progress.get(id, 0)) + amount) & 255
					enemy["event_experience"] = host.officer_progress[id]
