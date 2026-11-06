extends SceneTree
## L1：槽位目标=帅帐；71次思考首次检查；玩家金<15000按兵不动；单群接令。
func _initialize() -> void:
	create_timer(60).timeout.connect(func(): quit(1))
	_run.call_deferred()
func _run() -> void:
	root.get_node("Game").current_map = "chibil1"
	var b = load("res://main.tscn").instantiate(); root.add_child(b)
	b.set_process(false); b.cli_mode = true
	var owner := int(b.commands.ai_owners()[0])
	assert(owner != b.player_owner)
	var hq: Dictionary = b.units.filter(func(u): return int(u.owner) == b.player_owner and int(u.unit) == 0)[0]
	assert(b.commands._l1_target(b.player_owner).uid == hq.uid, "L1 槽位目标应为帅帐，不是大旗")
	b.economy.write(b.player_owner, {"gold": 2000.0, "wood": 1000.0, "food": 1000.0, "stone": 0.0})
	b.ai._assault[owner] = 70
	b.ai._assault_maybe(owner)
	assert(b.ai._assault[owner] == 70, "第70次思考只累计，不检查")
	b.ai._assault[owner] = 71
	b.ai._assault_maybe(owner)
	assert(b.ai._assault[owner] == 0, "第71次思考重置计数")
	assert(b.units.filter(func(u): return int(u.owner) == owner and u.state == "attack").is_empty(), "金2000不应出击")
	b.economy.write(b.player_owner, {"gold": 15000.0, "wood": 1000.0, "food": 1000.0, "stone": 0.0})
	b.ai._assault[owner] = 71
	b.ai._assault_maybe(owner)
	var attackers: Array = b.units.filter(func(u): return int(u.owner) == owner and u.state == "attack")
	assert(not attackers.is_empty(), "玩家金15000后应出击")
	assert(attackers.all(func(u): return u.target == hq), "目标应固定为帅帐")
	assert(attackers.size() < b.units.filter(func(u): return int(u.owner) == owner and not u.is_building and bool(u.get("alive", false))).size(), "一次只派一个群，不是全军")
	print("L1 ASSAULT PASS slot-order HQ / 71-check / gold gate / one group")
	b.free(); quit(0)
