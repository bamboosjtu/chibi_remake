extends SceneTree
# REQ-005（review.md R-05）回归夹具：命令面板容量与分页。
#
# 验收：0/1/6/7/9/20 个动作全部可达、顺序稳定、可退出子菜单；键盘与鼠标调用**同一**命令。
# 运行：隔离 APPDATA + godot --headless --path godot/chibi_remake \
#   --script ../../tools/gd/test_cmd_paging.gd
# （**不要加 -- --noview** —— 命令面板属于视图；用真实 chibic1 战场承载，
# 任何 assert 失败都会中断；看门狗保证非零退出。

var _done := false
var _bumps := {}

func _initialize() -> void:
	create_timer(150.0).timeout.connect(func() -> void:
		if not _done:
			printerr("CMD-PAGE TIMEOUT: _run 未在时限内完成（断言失败即此表现）")
			quit(1))
	_run.call_deferred()

func _bump(i: int) -> void:
	_bumps[i] = int(_bumps.get(i, 0)) + 1

func _specs(n: int) -> Array:
	var out := []
	for i in range(n):
		out.append({
			"text": "动作 %d" % i, "enabled": true,
			"tip": "", "act": _bump.bind(i) as Callable,
		})
	return out

func _key(code: int) -> InputEventKey:
	var k := InputEventKey.new()
	k.keycode = code
	k.pressed = true
	return k

func _run() -> void:
	var game := root.get_node("Game")
	game.current_map = "chibic1"
	var battle: Node2D = load("res://main.tscn").instantiate()
	root.add_child(battle)
	battle.set_process(false)
	await process_frame
	await process_frame
	var view = battle.view
	assert(view != null)
	# 选一名**无武将**的移动单位：图像技能面板只在选中携带武将的部队时接管文字面板
	var soldier: Dictionary = {}
	for u in battle.units:
		if not u.is_building and u.alive and int(u.owner) == int(battle.player_owner) and (u.get("officer", {}) as Dictionary).is_empty():
			soldier = u
			break
	assert(not soldier.is_empty(), "夹具需要一名无武将单位")
	# 机动单位现在统一使用图像面板；文字分页用于建筑生产/建造与挑将。
	var building: Dictionary = {}
	for u in battle.units:
		if u.alive and u.is_building and int(u.owner) == int(battle.player_owner):
			building = u
			break
	assert(not building.is_empty())
	battle.selected = [building]

	# ---- 0 个动作：全槽隐藏，提示可见 ----
	view._apply_cmd_specs([], "点兵提示")
	for b in view.cmd_buttons:
		assert(not b.visible, "0 动作时槽不应显示")
	assert(view.cmd_hint.text == "点兵提示" and not view.cmd_prev.visible and not view.back_button.visible)
	print("CMD-PAGE PASS: 0 actions -> hint only")

	# ---- 1 个与 6 个动作：单页全显，分页器不出现 ----
	view._apply_cmd_specs(_specs(1), "")
	_check_single_page(view, 1)
	view._apply_cmd_specs(_specs(6), "")
	_check_single_page(view, 6)
	print("CMD-PAGE PASS: 1/6 actions single page")

	# ---- 超六动作：页数向上取整；全部动作可达、顺序稳定；往返翻页无漂移 ----
	for n in [7, 9, 20]:
		_bumps.clear()               # 计数按本轮 n 独立（各轮动作空间同名同键）
		view._apply_cmd_specs(_specs(n), "")
		var pages: int = view.cmd_page_count
		assert(pages == ceili(float(n) / 6.0), "页数=%d n=%d" % [pages, n])
		assert(view.cmd_prev.visible and view.cmd_next.visible, "翻页器应出现")
		var seen := {}
		for p in range(pages):
			view.cmd_page = p
			view._apply_cmd_page()
			for i in range(view.cmd_buttons.size()):
				var idx: int = p * 6 + i
				if idx >= n:
					assert(not (view.cmd_buttons[i] as Button).visible, "越界槽应隐藏")
					continue
				var btn: Button = view.cmd_buttons[i]
				assert(btn.visible and btn.text == "动作 %d" % idx, "第 %d 页槽 %d 文本漂移" % [p + 1, i])
				view._on_cmd(i)               # 鼠标点击路径（槽位 → 动作）
				seen[idx] = true
		assert(seen.size() == n, "有动作不可达：%d/%d" % [seen.size(), n])
		for k in seen:
			assert(int(_bumps.get(int(k), 0)) == 1, "动作被重复或漏触发：%d" % int(k))
		# 往返：从首页翻下再翻回，内容稳定；首页再向上翻 = 不消费
		view.cmd_page = 0
		view._apply_cmd_page()
		assert(view._on_cmd_page(1) == true)
		assert(view._on_cmd_page(-1) == true)
		assert((view.cmd_buttons[0] as Button).text == "动作 0", "回首页内容漂移")
		assert(view._on_cmd_page(-1) == false, "首页再向上翻不应消费")
	print("CMD-PAGE PASS: 7/9/20 paged, all reachable, order stable, round-trip clean")

	# ---- 10Hz 刷新不把页码打回去（同一清单重放保持页位）----
	view._apply_cmd_specs(_specs(20), "")
	view._on_cmd_page(1)
	view._apply_cmd_specs(_specs(20), "")
	assert(view.cmd_page == 1, "同一清单重放不应归零页码")
	print("CMD-PAGE PASS: repeated refresh keeps page")

	# ---- 键盘与鼠标同一路径：PageUp/PageDown 翻页、子菜单编号直达同一个 _on_cmd ----
	_bumps.clear()
	view._apply_cmd_specs(_specs(9), "")
	assert(view._handle_cmd_key(_key(KEY_PAGEDOWN)) == true)
	assert(view.cmd_page == 1)
	assert(view._handle_cmd_key(_key(KEY_PAGEUP)) == true)
	assert(view.cmd_page == 0)
	assert(view._handle_cmd_key(_key(KEY_PAGEUP)) == false, "首页 PageUp 不应消费")
	# 子菜单（选择将领）：返回为**固定按钮**；数字直达；Esc 关闭
	view.officer_pick = true
	view._apply_cmd_specs(_specs(9), "")
	assert(view.back_button.visible, "子菜单期间返回按钮恒可见")
	assert(view._handle_cmd_key(_key(KEY_3)) == true)
	assert(int(_bumps.get(2, 0)) == 1, "键盘 3 应触发当前页第 3 个动作（同一 _on_cmd）")
	assert(view._handle_cmd_key(_key(KEY_ESCAPE)) == true)
	assert(not view.officer_pick, "Esc 应关闭子菜单")
	assert(not view.back_button.visible, "子菜单关闭后返回按钮隐藏")
	print("CMD-PAGE PASS: PageUp/PageDown, digit direct call, fixed back entry")

	# ---- 携带武将 + 非挑人：图像面板接管时整行脚行隐藏 ----
	var commander: Dictionary = {}
	for u in battle.units:
		if not u.is_building and u.alive and int(u.owner) == int(battle.player_owner) and not (u.get("officer", {}) as Dictionary).is_empty():
			commander = u
			break
	assert(not commander.is_empty(), "夹具需要一名带武将单位")
	battle.selected = [commander]
	view._apply_cmd_specs(_specs(9), "")
	assert(not view.cmd_prev.visible and not view.back_button.visible, "图像面板接管时脚行应隐藏")
	print("CMD-PAGE PASS: officer art panel takes over hides footer")

	# ---- 真实 picking 路径：_refresh_cmd_panel 的挑选子面板分页可通 ----
	battle.selected = [soldier]
	view.officer_pick = true
	view._refresh_cmd_panel()
	var pspecs: Array = view.cmd_capsules
	assert(pspecs.size() >= 2, "挑人清单为空")
	assert(view.back_button.visible, "挑人态返回按钮恒可见")
	var ppages: int = view.cmd_page_count
	for p in range(ppages):
		view.cmd_page = p
		view._apply_cmd_page()
		for i in range(view.cmd_buttons.size()):
			var idx: int = p * 6 + i
			if idx >= pspecs.size():
				assert(not (view.cmd_buttons[i] as Button).visible)
			else:
				assert((view.cmd_buttons[i] as Button).visible)
	view._act_close_officer_pick()
	assert(not view.officer_pick and not view.back_button.visible)
	print("CMD-PAGE PASS: real officer_pick list pages through and closes")

	battle.free()
	_done = true
	quit()

func _check_single_page(view, n: int) -> void:
	assert(view.cmd_page_count == 1 and not view.cmd_prev.visible and not view.cmd_next.visible)
	var shown := 0
	for i in range(view.cmd_buttons.size()):
		var b: Button = view.cmd_buttons[i]
		if i < n:
			assert(b.visible and b.text == "动作 %d" % i)
			shown += 1
		else:
			assert(not b.visible)
	assert(shown == n)
