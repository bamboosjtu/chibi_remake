extends RefCounted
## Compatibility driver for the --selftest entry point.
var host: Node2D
var gathering: RefCounted
var groups: RefCounted
var technology: RefCounted
var navigation: RefCounted
var _test_pass = 0
var _test_fail = 0
var _test_skip = 0
var _test_failed_labels: Array = []

func _init(battle: Node2D) -> void:
	host = battle
	gathering = preload("res://testing/gathering_checks.gd").new(battle, self)
	groups = preload("res://testing/groups_checks.gd").new(battle, self)
	technology = preload("res://testing/technology_checks.gd").new(battle, self)
	navigation = preload("res://testing/navigation_checks.gd").new(battle, self)

func _check(cond: bool, label: String) -> bool:
	if cond:
		self._test_pass += 1
		print("  PASS  %s" % label)
	else:
		self._test_fail += 1
		self._test_failed_labels.append(label)
		printerr("  FAIL  %s" % label)
	return cond

## 前提不成立（本图没有资源点之类）—— 既不算通过也不算失败，但**会计数**，
## 这样"全跳过"和"全通过"在摘要里看得出来。

func _selftest_summary() -> void:
	print("SELFTEST: %d passed, %d failed, %d skipped" % [self._test_pass, self._test_fail, self._test_skip])
	if self._test_fail == 0:
		print("SELFTEST RESULT: PASS")
		host.get_tree().quit(0)
	else:
		printerr("SELFTEST RESULT: FAIL (%d) -> %s" % [self._test_fail, str(self._test_failed_labels)])
		host.get_tree().quit(1)

## 冒烟结论落盘（user://smoke.json）。构建脚本据此判断新包能不能真的载入关卡。

func _skip(label: String) -> void:
	self._test_skip += 1
	print("  SKIP  %s" % label)

func run() -> void:
	await host.get_tree().create_timer(0.6).timeout
	var z0 = host.cam.zoom.x          # 原版不能缩放 —— 下面会验证它**不会**变
	var mb = InputEventMouseButton.new()
	mb.button_index = MOUSE_BUTTON_WHEEL_UP
	mb.pressed = true
	Input.parse_input_event(mb)
	await host.get_tree().process_frame
	var z1 = host.cam.zoom.x
	var k = InputEventKey.new()
	k.keycode = KEY_U
	k.pressed = true
	Input.parse_input_event(k)
	await host.get_tree().process_frame
	var n_pl = 0
	var en = 0
	for u in host.units:
		if u.is_building or not u.alive:
			continue
		if u.owner == host.player_owner:
			n_pl += 1
		elif u.owner != 0:
			en += 1
	print("SELFTEST: zoom %.3f->%.3f units_visible=%s 我军=%d 敌军=%d events=%d" % [z0, z1, str(host.show_units), n_pl, en, host.ev_count])
	self._check(is_equal_approx(z0, z1), "zoom 不受滚轮影响（原版不能缩放）")
	self._check(n_pl > 0, "我军有机动单位")
	# 原版不能缩放：滚轮**不应**改变比例（以前这里只打印，根本没比较）
	# B4 断言：建筑也必须有非零深度、选中框与血条桩
	var bldg: Dictionary = {}
	for u in host.units:
		if u.is_building and u.owner == host.player_owner and u.alive:
			bldg = u
			break
	if not bldg.is_empty():
		host.show_buildings = true
		host.selected = [bldg]
		host.commands._update_visual(bldg)
		print("SELFTEST building: unit=%d z_index=%d (ay=%d) diamond=%s hbar=%s grid=%d count=%d" % [
			int(bldg.unit), int(host.view.unit_nodes(bldg).spr.z_index), int(bldg.ay), str(host.view.unit_nodes(bldg).diamond.visible),
			str(host.view.unit_nodes(bldg).hbar != null), int(bldg.grid), int(bldg.count)])
		self._check(int(host.view.unit_nodes(bldg).spr.z_index) > 0, "建筑有非零深度（B4）")
		self._check(host.view.unit_nodes(bldg).hbar != null, "建筑有血条节点（B4）")
		self._check(int(bldg.grid) > 0 and int(bldg.count) > 0, "建筑图集有网格与帧数")
		host.selected.clear()
	# B1 断言：选中**能生产**的建筑后生产按钮 必须真的排队生产
	# （原版只有帅帐/兵营/船坞产兵；粮仓/城门/箭楼没有生产项，那就跳过这条）。
	var train_bldg: Dictionary = {}
	for u in host.units:
		if bool(u.is_building) and int(u.owner) == host.player_owner and bool(u.alive) and not bool(u.get("site", false)):
			if not host.commands.train_types_for(int(u.unit)).is_empty():
				train_bldg = u
				break
	if train_bldg.is_empty():
		self._skip("生产按钮 生产（B1）：本图我方没有可生产的建筑")
	var before_train = host.trainings.size()
	host.selected = [train_bldg] if not train_bldg.is_empty() else []
	if not host.commands._train_list_for_selection().is_empty():host.commands._start_train(host.commands._train_list_for_selection()[0])
	await host.get_tree().process_frame
	# process_frame is emitted before node processing; allow the queued command's frame pump to run.
	await host.get_tree().process_frame
	print("SELFTEST train: queued %d -> %d (生产按钮 生效=%s)" % [before_train, host.trainings.size(), str(host.trainings.size() > before_train)])
	if bldg.is_empty():
		self._skip("生产按钮 生产（B1）：本图我方没有建筑，前提不成立")
	else:
		self._check(host.trainings.size() > before_train, "选中建筑后生产按钮 真的排队生产（B1）")
	host.selected.clear()
	# 武将 + 真实伤害公式断言（FUN_0041fe90）
	var sample: Dictionary = {}
	for u in host.units:
		if not u.is_building and u.owner == host.player_owner and u.alive:
			sample = u
			break
	var foe: Dictionary = {}
	for u in host.units:
		if not u.is_building and u.owner != host.player_owner and u.owner != 0 and u.alive:
			foe = u
			break
	if not sample.is_empty():
		var off: Dictionary = sample.get("officer", {})
		print("SELFTEST officer: 「%s」武力=%.0f 智力=%.0f | 兵种=%s id=%d uid=%d mapobj=%s HP=%.0f 攻击=%.0f 防御=%.0f 射程=%.0f 视野=%.0f" % [
			str(off.get("name", "无")), float(sample.get("officer_might", 0)), float(sample.get("officer_intellect", 0)),
			str(sample.name), int(sample.unit), int(sample.uid), str(sample.map_object),
			float(sample.maxhp), float(sample.attack), float(sample.defence),
			float(sample.atk_range), float(sample.vision)])
		if not foe.is_empty():
			print("SELFTEST damage: %s(攻%.0f) → %s(武%.0f × mitig%.0f / 100) = %.1f" % [
				str(sample.name), float(sample.attack), str(foe.name),
				float(foe.get("officer_might", 0)), float(foe.get("mitig", 0)), host.commands._damage(sample, foe)])

	# --- ARCH-005：关卡注册表不得收录数据库文件或坏 JSON ---
	var lv = Game.list_levels()
	var lvnames = []
	for l in lv:
		lvnames.append(str(l.id))
	print("SELFTEST levels: %s  count=%d  officers_listed=%s" % [str(lvnames), lv.size(), str("officers" in lvnames)])
	self._check(lv.size() == 34, "关卡数 == 34（34 张 .MED 全部导出）")

	# --- ARCH-003：不可达命令必须失败（返回 0 段）并给出反馈，不能编一条直线 ---
	var probe: Dictionary = {}
	for u in host.units:
		# 用**陆军**探针：水战图上的船走水面层，用封闭陆地块测它没有意义。
		if not u.is_building and u.owner == host.player_owner and u.alive and not host.commands._is_naval(u):
			probe = u
			break
	if not probe.is_empty():
		# 注意：_cell_of_px 会 clamp，所以"场外坐标"其实总可达 —— 那样测不出问题。
		# 真正的不可达要自己造：把目标周围 13×13 全标实心，超过 _near_walkable 的 5 圈搜索半径。
		var src = host.commands._near_walkable(host.commands._cell_of_px(probe.ax, probe.ay))
		var mr = int(host.map_data.rows)
		var mc = int(host.map_data.cols)
		# 封闭块是 ±6 格：目标格必须离地图边缘 ≥7 格，否则"封块"被裁掉、旁边留出可走格，
		# 不可达就不成立了（大图/水战图的边缘会踩到）。
		var tgt_cell = Vector2i(clampi(src.x, 7, mr - 8), clampi(src.y + 24, 7, mc - 8))
		# 城门格会被友军规划临时打开，封闭块必须避开城门，否则“不可达”前提不成立。
		for attempt in range(12):
			if not self.navigation._selftest_gate_near(tgt_cell, 7):
				break
			tgt_cell = Vector2i(clampi(tgt_cell.x + 11, 7, mr - 8),
				clampi(tgt_cell.y + 11, 7, mc - 8))
		var touched = []
		for dx in range(-6, 7):
			for dy in range(-6, 7):
				var q = Vector2i(clampi(tgt_cell.x + dx, 0, mr - 1), clampi(tgt_cell.y + dy, 0, mc - 1))
				# 只跳过**地形本身**就不可走的格；被单位/建筑临时占用的格也要封，
				# 否则占用者走开后会在封闭块上留洞，near_walkable 能从洞里“逃出去”。
				if host.nav._grid(0).is_point_disabled(host.nav._id(q)) or host.nav.blocked_cells.has(host.nav._id(q)):
					continue
				host.nav.block(q)
				touched.append(q)
		var tp = host.commands._anchor_of(tgt_cell.x, tgt_cell.y)
		var bad = host.commands._path_to(probe, tp, true)
		host.feedback_text = ""
		host.selected = [probe]
		host.commands._order_at(tp)
		print("SELFTEST path: 封闭目标段数=%d (0=正确拒绝)  反馈=\"%s\"  状态=%s  src=%s tgt=%s rows=%d cols=%d tgt_solid=%s to_cell=%s near=%s near_solid=%s touched=%d" % [
			bad.size(), host.feedback_text, str(probe.state), str(src), str(tgt_cell),
			int(host.map_data.rows), int(host.map_data.cols), str(host.nav.is_solid(tgt_cell)),
			str(host.nav.cell_of_px(tp.x, tp.y)), str(host.nav.near_walkable(host.nav.cell_of_px(tp.x, tp.y))),
			str(host.nav.is_solid(host.nav.near_walkable(host.nav.cell_of_px(tp.x, tp.y)))), touched.size()])
		self._check(bad.size() == 0, "封闭目标：不可达时 _path_to 返回空（ARCH-003）")
		host.selected.clear()
		for q in touched:
			host.nav.unblock(q)

	# --- ARCH-001/002：阵亡并被清理的地图对象不得复活；uid / nextUid 守恒 ---
	var victim: Dictionary = {}
	for u in host.units:
		if bool(u.get("map_object", false)) and not u.is_building and u.owner != host.player_owner and u.alive:
			victim = u
			break
	if not victim.is_empty():
		var vuid = int(victim.uid)
		victim.alive = false
		victim.die_t = 99.0
		host.commands._prune_dead()
		var n_before = host.units.size()
		var saved_ok = host.commands._save_game()
		var next_before = host.next_uid
		host.commands._apply_save()
		var resurrected = false
		for u in host.units:
			if int(u.uid) == vuid:
				resurrected = true
		print("SELFTEST tombstone: saved=%s units %d->%d  victim uid %d resurrected=%s  nextUid %d->%d" % [
			str(saved_ok), n_before, host.units.size(), vuid, str(resurrected), next_before, host.next_uid])
		self._check(not resurrected, "阵亡单位读档后不复活（ARCH-001）")
		self._check(int(host.next_uid) == int(next_before), "nextUid 从存档恢复（ARCH-002）")
	host.commands._save_game()
	print("SELFTEST: save written, has_save=%s" % str(Game.has_save()))
	# --- #5：原版胜负判定（单位 **与建筑** 都要清空；资源 1 为 0 也判负）---
	if host.scenario_mission in host.SPECIAL_OBJECTIVE_MISSIONS:
		print("SELFTEST endrule: mission %d 是特殊关，跳过默认判定断言" % host.scenario_mission)
	else:
		var enemies = []
		var mine_all = []
		var my_buildings = 0
		for u in host.units:
			if u.owner == host.player_owner:
				mine_all.append(u)
				if u.is_building:
					my_buildings += 1
			elif u.owner != 0:
				enemies.append(u)
		# 前提检查：默认失败规则是「(单位全灭 或 资源为0) **且 建筑为0**」。
		# 我方本来就没有建筑的图（如 chibil8）上，这条断言的前提不成立 —— 跳过而不是误报。
		if my_buildings == 0:
			print("SELFTEST endrule: 该图我方无建筑（默认失败规则前提不成立）—— 跳过")
			host.game_end = 0
		else:
			# 专属出口（如任务 29 的 third-side-cleared）也会写 objective_done；
			# 这里逐项重置脚本目标状态，确保测的是**默认**歼灭规则，而不是上一次的结果。
			host.game_end = 0
			for u in enemies:
				u.alive = false
			host.objective_done = false
			host.task_latches.clear()
			host.commands._check_end()
			var e_win = host.game_end
			for u in enemies:
				u.alive = true
			host.game_end = 0
			for u in mine_all:
				if not u.is_building:
					u.alive = false
			host.objective_done = false
			host.task_latches.clear()
			host.commands._check_end()
			var e_units_only = host.game_end
			for u in mine_all:
				u.alive = false
			host.objective_done = false
			host.task_latches.clear()
			host.commands._check_end()
			print("SELFTEST endrule: 敌军全灭=%d(应1)  只死我单位=%d(应0,建筑还在)  我单位+建筑全灭=%d(应2)" % [e_win, e_units_only, host.game_end])
			self._check(e_win == 1, "敌军单位+建筑全灭 → 胜利")
			self._check(e_units_only == 0, "只死单位（建筑还在）→ 尚未失败")
			self._check(host.game_end == 2, "单位+建筑全灭 → 失败")
			for u in mine_all:
				u.alive = true
			host.game_end = 0
			self.technology._selftest_build()
	self.groups._selftest_group()
	self.groups._selftest_ctrlgroup()
	self.gathering._selftest_gather()
	self.technology._selftest_tech()
	self.navigation._selftest_naval()

	# --- 脚本目标正向验证（CB.EXE FUN_00404800）---
	# 把「达成即胜」那条目标要求的武将挪进矩形，应当判**胜利**。
	if host.commands._objective_kind() == "scripted":
		var winst: Dictionary = {}
		for st in host.SCRIPTED_OBJECTIVES.get(host.scenario_mission, []):
			if bool((st as Dictionary).get("win", false)):
				winst = st
				break
		if winst.is_empty():
			print("SELFTEST objective: 本关脚本目标没有 win 段 —— 跳过")
		else:
			var want: int = int(winst.get("officer", -1))
			var rr: Array = winst.get("rect", [])
			var moved = 0
			for u in host.units:
				if not u.alive or int(u.owner) != host.player_owner:
					continue
				var oo = u.get("officer", null)
				if want < 0:
					continue
				if (oo is Dictionary) and int((oo as Dictionary).get("index", -1)) == want:
					print("SELFTEST objective: 武将 index=%d 当前 A=%d B=%d，目标矩形=%s" % [
						want, int(u.A), int(u.B), str(rr)])
					u.A = int((int(rr[0]) + int(rr[1])) / 2)
					u.B = int((int(rr[2]) + int(rr[3])) / 2)
					moved += 1
					break
			host.game_end = 0
			host.objective_done = false
			host.commands._check_end()
			if moved == 0:
				print("SELFTEST objective: **该图我方没有武将 index=%d** —— 无法验证" % want)
			else:
				print("SELFTEST objective: 移入矩形后 game_end=%d(应1=胜利)  objective_done=%s" % [
					host.game_end, str(host.objective_done)])
				self._check(host.game_end == 1, "脚本目标：武将进入矩形 → 胜利（FUN_00404800）")
			host.game_end = 0
			host.objective_done = false

	await host.commands._screenshot()
	self._selftest_summary()      # 按失败数决定退出码（不再是永远退出 0）
	return
