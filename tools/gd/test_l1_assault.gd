extends SceneTree
## L1: one-based HQ gate, 71 thoughts, slot order; no invented one-group exception.
func _initialize() -> void:
	create_timer(60).timeout.connect(func(): quit(1))
	_run.call_deferred()
func _run() -> void:
	root.get_node("Game").current_map = "chibil1"
	var b = load("res://main.tscn").instantiate(); root.add_child(b)
	b.set_process(false); b.cli_mode = true
	var owner := int(b.world.ai_economy.ai_owners()[0])
	assert(owner != b.player_owner)
	var hq: Dictionary = b.units.filter(func(u): return int(u.owner) == b.player_owner and int(u.unit) == 0)[0]
	assert(b.world.ai_orders._l1_target(b.player_owner).uid == hq.uid, "L1 槽位目标应为帅帐，不是大旗")
	b.economy.write(b.player_owner, {"gold": 2000.0, "wood": 1000.0, "food": 1000.0, "stone": 0.0})
	b.ai._assault[owner] = 70
	b.ai._assault_maybe(owner)
	assert(b.ai._assault[owner] == 70, "第70次思考只累计，不检查")
	b.ai._assault[owner] = 71
	b.ai._assault_maybe(owner)
	assert(b.ai._assault[owner] == 0, "第71次思考重置计数")
	assert(b.units.all(func(u): return int(u.owner) != owner or u.state != "attack"), "opening gold must not release the L1 assault")
	b.economy.write(b.player_owner, {"gold": 14999.0, "wood": 1000.0, "food": 1000.0, "stone": 0.0})
	b.ai._assault[owner] = 71
	b.ai._assault_maybe(owner)
	assert(b.units.all(func(u): return int(u.owner) != owner or u.state != "attack"), "14999 gold must still hold the L1 assault")
	b.economy.write(b.player_owner, {"gold": 15000.0, "wood": 1000.0, "food": 1000.0, "stone": 0.0})
	b.ai._assault[owner] = 71
	b.ai._assault_maybe(owner)
	var attackers: Array = b.units.filter(func(u): return int(u.owner) == owner and u.state == "attack")
	assert(not attackers.is_empty(), "L1 assault may start at 15000 gold on the next check")
	assert(attackers.all(func(u): return u.target == hq), "目标应固定为帅帐")
	assert(attackers.size() == 19 and attackers.all(func(u): return u.officer.is_empty()), "both opening groups send their ordinary troops; the officers have no dock or transport target")
	print("L1 ASSAULT PASS slot-order HQ / 71-check / one-based gate / shared groups")
	b.free(); quit(0)
