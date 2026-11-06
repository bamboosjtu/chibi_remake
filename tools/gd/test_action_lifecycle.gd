extends SceneTree
## R07/R08 动作生命周期回归：
##   · 阵亡/失去武将身份/上船/读档后，待确认的计谋不能再结算；
## Queued confusion is covered by test_unit_research against research/magics.
var b: Node2D
var game: Node
var done := false

func _initialize() -> void:
	create_timer(120).timeout.connect(func():
		if not done: quit(1))
	run.call_deferred()

func run() -> void:
	game = root.get_node("Game")
	game.current_map = "chibic1"
	b = load("res://main.tscn").instantiate()
	root.add_child(b)
	b.set_process(false); b.cli_mode = true
	var hero: Dictionary = b.units.filter(func(u): return int(u.owner) == b.player_owner and not (u.get("officer", {}) as Dictionary).is_empty() and not u.is_building)[0]
	var worker: Dictionary = b.units.filter(func(u): return int(u.unit) == 30 and int(u.owner) == b.player_owner and not u.attached)[0]
	var hero_officer: Dictionary = (hero.get("officer", {}) as Dictionary).duplicate(true)
	hero.officer.level = 9; hero.mou = 1000.0
	b.selected = [hero]
	b.commands._jimou_begin(1)                       # 加速（消耗 100）
	assert(b.jimou_pending == 1 and is_same(b.jimou_caster, hero))
	b.commands._kill(hero, {})
	assert(b.jimou_pending == -1, "R07: 施法武将阵亡必须清理待确认施法")
	# 旧档/异常路径若仍留有引用，确认入口也必须拒绝，且不扣谋略、不给目标加速。
	b.jimou_pending = 1; b.jimou_caster = hero
	var target_pos := Vector2(worker.ax, worker.ay - worker.h * 0.5)
	b.commands._jimou_cast_at(target_pos)
	assert(worker.haste_t == 0 and hero.mou == 1000.0, "R07: 阵亡武将不能完成施法")
	# 活着但已失去武将身份（解除/解散后）同样拒绝。
	hero.die_t = -1.0; hero.alive = true; hero.officer = {}
	b.jimou_pending = 1; b.jimou_caster = hero
	b.commands._jimou_cast_at(target_pos)
	assert(worker.haste_t == 0, "R07: 无武将身份不能施法")
	b.commands._reset_jimou()
	# 恢复该武将，用同一实体继续验证“读档清理”和“合法施法仍工作”。
	hero.officer = hero_officer.duplicate(true)
	hero.officer.level = 9
	hero.alive = true; hero.die_t = -1.0; hero.state = "idle"; hero.mou = 1000.0
	# 读档清理：待确认施法属于旧世界，恢复后不得保留。
	var live_hero: Dictionary = hero
	b.selected = [live_hero]
	b.commands._jimou_begin(1)
	assert(b.jimou_pending == 1)
	assert(game.save_game(b.units, b.commands._resources(), b.commands._save_extra()))
	assert(b.saver.apply_snapshot(game.load_save()))
	assert(b.jimou_pending == -1 and b.jimou_caster.is_empty(), "R07: 读档必须清理待确认施法")
	# 合法施法仍工作：活着的武将确认后扣费并给目标加速。
	live_hero = b.units.filter(func(u): return int(u.owner) == b.player_owner and not (u.get("officer", {}) as Dictionary).is_empty() and not u.is_building)[0]
	live_hero.officer.level = 9; live_hero.mou = 1000.0
	var members: Array = b.units.filter(func(u): return int(u.owner) == b.player_owner and not u.is_building and u != live_hero and bool(u.get("alive", false)))
	assert(not members.is_empty(), "R07: 需要一名我方目标部队")
	var member: Dictionary = members[0]
	member.haste_t = 0
	# 目标放到施法者 10 格内（真实点击范围），避免开局队形过远干扰本项验证。
	member.ax = float(live_hero.ax) + 30.0; member.ay = float(live_hero.ay)
	member.A = int(live_hero.A); member.B = int(live_hero.B)
	b.commands._place_unit(member)
	b.selected = [live_hero]
	b.commands._jimou_begin(1)
	b.commands._jimou_cast_at(Vector2(member.ax, member.ay - member.h * 0.5))
	assert(member.haste_t > 0 and live_hero.mou == 900.0, "R07: 合法施法仍应结算")
	print("SPELL LIFECYCLE PASS dead identity / lost officer / load clears / normal cast")
	b.free()

	done = true
	await process_frame
	quit(0)
