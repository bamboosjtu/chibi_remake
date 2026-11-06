extends SceneTree
## 开局编队1 / 主将阵亡自动解散。
func _initialize() -> void:
	create_timer(60).timeout.connect(func(): quit(1))
	_run.call_deferred()
func _run() -> void:
	root.get_node("Game").current_map = "chibic1"
	var b = load("res://main.tscn").instantiate(); root.add_child(b)
	b.set_process(false); b.cli_mode = true
	assert(b.commands.military.control_group_size(1) > 1, "开局第一支队伍应占据编队1")
	b.selected.clear()
	assert(b.commands.military._group_recall(1) and not b.selected.is_empty(), "数字1应呼出编队1")
	var hero: Dictionary = b.selected.filter(func(u): return not (u.get("officer", {}) as Dictionary).is_empty())[0]
	var idx := int(hero.officer.index)
	var lv0 := int(hero.officer.get("level", 0))
	hero.officer.exp = int(b.EXP_LEVELS[lv0]) - 1
	b.commands.military._grant_officer_exp(hero, 1)
	assert(int(hero.officer.get("level", 0)) == mini(9, lv0 + 1), "经验达到阈值应升官职")
	var members: Array = b.units.filter(func(u): return int(u.get("group_officer", -1)) == idx)
	assert(not members.is_empty())
	# A manual group containing only members must be freed as well. Mixed groups
	# retain unrelated survivors rather than being erased wholesale.
	var unrelated:Dictionary=b.units.filter(func(u):return int(u.owner)==b.player_owner and u.is_building)[0]
	b.control_groups[2]=members.map(func(u):return int(u.uid))
	b.control_groups[3]=[int(hero.uid),int(unrelated.uid)]
	b.commands.military._kill(hero)
	assert(hero.die_t==0 and hero.alive,"check actual lethal-hit tick, before death animation ends")
	assert(b.commands.military.control_group_size(1)==0 and b.commands.military.control_group_size(2)==0 and not b.commands.military._group_recall(1))
	assert(b.control_groups[3]==[int(unrelated.uid)])
	b.view.update_hud_text()
	var game:Node=root.get_node("Game")
	assert(game.save_game(b.units,b.commands.world._resources(),b.commands.session._save_extra()))
	assert(b.saver.apply_snapshot(game.load_save()))
	assert(b.commands.military.control_group_size(1)==0 and b.commands.military.control_group_size(2)==0)
	hero=b.units.filter(func(u):return int(u.uid)==int(hero.uid))[0]
	members=b.units.filter(func(u):return int(u.owner)==b.player_owner and not u.is_building and u.uid!=hero.uid)
	b.commands.world._finish_death(hero)
	assert((hero.get("officer", {}) as Dictionary).is_empty(), "主将阵亡应解除武将")
	for m in members:
		assert(int(m.get("group_officer", -1)) == -1, "成员应自动退群")
	print("TEAM LIFECYCLE PASS group1 initial / recall / actual kill / immediate slot release / member-only slot / mixed group retained / dying snapshot / auto-dissolve")
	b.free(); quit(0)
