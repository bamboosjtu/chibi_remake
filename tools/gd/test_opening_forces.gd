extends SceneTree
var done := false
func _initialize() -> void:
	create_timer(180).timeout.connect(func():
		if not done: quit(1))
	run.call_deferred()

func run() -> void:
	var fixture_path := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--opening-fixture="): fixture_path = arg.substr(18)
	assert(not fixture_path.is_empty(), "Generate fixture from docs/reference/level-openings.md using tools/test_opening_forces.mjs")
	var fixture: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(fixture_path))
	assert(fixture.chapters.size() == 34 and fixture.fullTeams == 18)
	var sides := 0
	var full_teams := 0
	for chapter in fixture.chapters:
		root.get_node("Game").current_map = chapter.id
		var battle: Node2D = load("res://main.tscn").instantiate(); root.add_child(battle)
		battle.set_process(false); battle.cli_mode = true; battle.ai = null
		assert(battle.player_owner == chapter.sides[0].owner and battle.scenario_avi == chapter.avi)
		for side in chapter.sides:
			sides += 1
			var balance: Dictionary = battle.commands.world._resources() if side.player else battle.commands.economy._ai_res_of(int(side.owner))
			for kind in ["gold", "food", "wood", "stone"]: assert(balance[kind] == side.resources[kind], str(chapter.id)+" resource "+kind)
			var leaders: Array = battle.units.filter(func(u): return int(u.owner) == int(side.owner) and not u.get("officer", {}).is_empty())
			var expected_leaders := 0
			for officer in side.officers:
				var expected_count := 0
				for count in officer.troops.values(): expected_count += int(count)
				var model: Dictionary = battle.commands.military._officer_by_index(int(officer.id) - 1)
				assert(not model.is_empty() and int(model.might) == int(officer.might) and int(model.intellect) == int(officer.intellect))
				var level := maxi(0, int(officer.rank) - 1) if officer.rank != null else 0
				if int(officer.id) <= 33 and level == 0: level = 5
				assert(int(model.get("level", 0)) == level, str(chapter.id)+" grade of "+str(officer.name))
				var matches: Array = leaders.filter(func(u): return int(u.officer.index) == int(officer.id) - 1)
				if expected_count == 0:
					assert(matches.is_empty(), "Roster-only officer must not spawn")
					continue
				expected_leaders += 1
				assert(matches.size() == 1)
				var leader: Dictionary = matches[0]
				assert(int(leader.officer.level) == level and int(leader.status_173) == 70 and leader.hp == model.hp)
				var members: Array = battle.units.filter(func(u): return int(u.owner) == int(side.owner) and int(u.get("group_officer", -1)) == int(officer.id) - 1)
				assert(members.size() == expected_count, str(chapter.id)+" full membership of "+str(officer.name))
				for type in officer.troops:
					assert(members.filter(func(u): return int(u.unit) == int(type)).size() == int(officer.troops[type]))
				assert(Vector2(leader.ax,leader.ay).is_equal_approx(Vector2(members[0].ax,members[0].ay)), "Commander starts at first subordinate")
				if expected_count == 15: full_teams += 1
			assert(leaders.size() == expected_leaders)
		print("OPENING CHAPTER PASS ",chapter.id)
		battle.free()
	assert(sides == 73 and full_teams == 18)
	print("OPENING WORLD PASS 34 maps /73 sides /18 full15-member teams / first-subordinate position / resources / rank-defaults / roster-only absent")
	done = true; quit()
