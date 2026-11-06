extends RefCounted
## officer pool: composed battle behavior.
const State = preload("res://simulation/battle_state.gd")
const Config = preload("res://simulation/battle_config.gd")
const Dependencies = preload("res://simulation/ports/officer_pool_dependencies.gd")
var battle: State
var ports := Dependencies.new()

func _init(data: State) -> void:
	battle = data

func _officer_by_index(idx: int) -> Dictionary:
	for blk in battle._officer_pool:
		for o in (blk as Array):
			if int((o as Dictionary).get("index", -1)) == idx:
				return o
	return {}

func _sync_officer_to_pool(off: Dictionary) -> void:
	var idx := int(off.get("index", -1))
	if idx < 0:
		return
	for blk in battle._officer_pool:
		for o in (blk as Array):
			if int((o as Dictionary).get("index", -1)) == idx:
				(o as Dictionary)["exp"] = int(off.get("exp", 0))
				(o as Dictionary)["level"] = int(off.get("level", 0))
				return

func _officer_pool_state() -> Dictionary:
	var out := {}
	for u in battle.units:
		var off: Dictionary = u.get("officer", {})
		if off.is_empty():
			continue
		var idx := int(off.get("index", -1))
		if idx < 0:
			continue
		out[str(idx)] = {"exp": int(off.get("exp", 0)), "level": int(off.get("level", 0)), "hasExp": off.has("exp")}
	for blk in battle._officer_pool:
		for o in (blk as Array):
			var rec: Dictionary = o
			var idx := int(rec.get("index", -1))
			if idx < 0 or out.has(str(idx)):
				continue
			var exp := int(rec.get("exp", 0))
			var lv := int(rec.get("level", 0))
			out[str(idx)] = {"exp": exp, "level": lv, "hasExp": rec.has("exp")}
	return out

func _restore_officer_pool(state: Dictionary) -> void:
	for blk in battle._officer_pool:
		for o in (blk as Array):
			var rec: Dictionary = o
			var key := str(int(rec.get("index", -1)))
			var s: Dictionary = state.get(key, battle._officer_initial_state.get(key, {}))
			# 缺失记录回到本关初始成长，兼容没有武将池的旧档。
			rec["exp"] = int(s.get("exp", 0))
			# Missing experience and explicit zero behave alike in progression,
			# but their dictionary shapes differ in the canonical state digest.
			if not bool(s.get("hasExp", true)): rec.erase("exp")
			rec["level"] = int(s.get("level", 0))

func officer_in_use(idx: int) -> bool:
	for u in battle.units:
		if not u.alive or u.die_t >= 0.0:
			continue
		var o = u.get("officer", null)
		if (o is Dictionary) and int((o as Dictionary).get("index", -1)) == idx:
			return true
	return false

func available_officers(owner: int) -> Array:
	var out: Array = []
	var found_side := false
	for i in range(battle.scenario_sides.size()):
		var sd: Dictionary = battle.scenario_sides[i]
		if int(sd.get("owner", -1)) != owner:
			continue
		found_side = true
		var ranks: Array = sd.get("ranks", [])
		var roster: Array = sd.get("roster", [])
		for k in range(roster.size()):
			# 原版 DATA.EXP 装载器从 1 开始；稳定素材 index 从 0 开始。
			var idx := int(roster[k]) - 1
			if officer_in_use(idx):
				continue
			var o := _officer_by_index(idx)
			if o.is_empty():
				continue
			var c: Dictionary = (o as Dictionary).duplicate()
			if k < ranks.size():
				c["rank"] = int(ranks[k])
			out.append(c)
		break
	# 之前这里写成 "if out.is_empty(): 回退到阵营块" —— 于是**名单用完之后**
	# 会突然冒出整块 47 个武将（自检里 "可用 1 -> 47" 就是这么来的）。
	# 正确语义：**战役表点名了名单，名单就是全部可选项**；用完了就是用完了。
	# 只有**根本没有战役定义**时才回退到阵营块。
	if found_side:
		return out
	var bi: int = int(Config.OFFICER_BLOCK_FOR_OWNER.get(owner, -1))
	if bi >= 0 and bi < battle._officer_pool.size():
		for o in battle._officer_pool[bi]:
			var idx2 := int((o as Dictionary).get("index", -1))
			if idx2 >= 0 and not officer_in_use(idx2):
				out.append(o)
	return out

func _officer_held_only_by_selection(idx: int) -> bool:
	var held_outside := false
	for u in battle.units:
		if not u.alive or u.die_t >= 0.0:
			continue
		var o = u.get("officer", null)
		if not (o is Dictionary) or int((o as Dictionary).get("index", -1)) != idx:
			continue
		if not battle.selected.has(u):
			held_outside = true
			break
	return not held_outside

func officers_for_selection(owner: int, sel: Array) -> Array:
	var out: Array = available_officers(owner)
	var seen := {}
	for o in out:
		seen[int((o as Dictionary).get("index", -1))] = true
	for u in sel:
		var o = u.get("officer", null)
		if not (o is Dictionary) or (o as Dictionary).is_empty():
			continue
		var idx := int((o as Dictionary).get("index", -1))
		if idx >= 0 and not seen.has(idx):
			out.append(o)
			seen[idx] = true
	return out
