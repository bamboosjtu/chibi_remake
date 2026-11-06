extends RefCounted
## command model: presentation component.
const UIState = preload("res://presentation/battle/components/battle_view_state.gd")
var _ui: UIState
var surface: Node2D
var ports = preload("res://presentation/battle/components/ports/command_model_dependencies.gd").new()
const CMD_PAGE := 6

func _init(data: UIState, node: Node2D) -> void:
	_ui = data
	surface = node

func update_panel() -> void:
	var sel: Array = _ui.host.selected
	if panel_kind()!="combat":_ui.art_sub=""
	if panel_kind()!="worker":_ui.build_menu=false
	ports._refresh_metrics()
	ports._refresh_banner()
	ports._refresh_sel_frame()
	ports._refresh_troop()
	_refresh_cmd_panel()
	_refresh_hotkeys()
	if _ui.minimap != null:
		_ui.minimap.queue_redraw()
	if _ui.ornament != null:
		_ui.ornament.queue_redraw()
	ports._rebuild_stats_text()
	if _ui.classic_panel != null:
		_ui.classic_panel.sync_selection()

func panel_kind() -> String:
	return str(_ui.host.selection_description().kind)

func _refresh_cmd_panel() -> void:
	if not cmd_box_ready():
		return
	var sel: Array = _ui.host.selected
	var specs: Array = []
	var hint: String = ""
	# 「选择将领」子面板：列出**尚未被占用**的武将（原版列表就是这个集合）
	if _ui.officer_pick and not sel.is_empty():
		# 候选 = 未被占用的 + **选中部队自己持有的**（可移出再指派，原版 CTRL_GROUP_Sub）。
		# 只用 available_officers 的话，名单分完之后这里永远是"没有可用的将领"。
		var avail: Array = _ui.host.officers_for_selection(_ui.host.player_owner, sel)
		if avail.is_empty():
			specs.append({
				"text": "没有可用的将领", "enabled": false,
				"tip": "名单上的武将都已被占用 —— 原版一个武将只能带一支部队。",
				"act": Callable(),
			})
		else:
			# REQ-005：不再 8 人封顶——完整名单进分页，全部可达
			for o in avail:
				specs.append({
					"text": str(o.get("name", "?")).replace(" ", ""),
					"enabled": true,
					"tip": "武力 %d · 智力 %d。带领选中的成员组建部队。" % [int(o.get("might", 0)), int(o.get("intellect", 0))],
					"act": ports._act_assign_officer.bind(int(o.get("index", -1))),
				})
		# 返回不再进清单——它是分页脚行的**固定按钮**（officer_pick 期间恒可见）
		hint = "选择将领 · 指派后该武将即被占用"
		_apply_cmd_specs(specs, hint)
		return
	# 建造清单与主命令共用格位；建筑缩略图来自已接入的高清帧。
	if _ui.build_menu and not sel.is_empty():
		var bts0: Array = _ui.host.build_types
		for bi in range(bts0.size()):
			var bopt0: Dictionary = bts0[bi]
			var reason: String = _ui.host.building_block_reason(int(bopt0.unit))
			var bok0: bool = ports._can_afford(bopt0) and reason == ""
			specs.append({
				"text": "建造 %s   %s" % [str(bopt0.get("name", "?")), ports._cost_text(bopt0)],
				"enabled": bok0,
				"tip": "%s · %s。选择后点击空地开始建造。%s" % [str(bopt0.name), ports._cost_text(bopt0), "" if bok0 else (reason if reason != "" else "资源不足。")],
				"icon": _ui.host.remaster_art.unit_icon(int(bopt0.unit)),
				"act": ports._act_build.bind(bi),
			})
		_apply_cmd_specs(specs, "建造：选择要盖的建筑，然后点地图上的空地")
		return
	if sel.is_empty():
		hint = "左键点兵 / 拖框选择我军\n右键地面：移动；右键敌方单位：攻击\n（选中后这里会出现行动按钮）"
	else:
		var site: Dictionary = ports._selected_site()
		var b: Dictionary = ports._selected_building()
		if not site.is_empty():
			# 工地（模式 0x13）：只显示进度与取消；生产/研究要等完工。
			var hp := float(site.get("hp", 0.0))
			var mx := maxf(1.0, float(site.get("maxhp", 1.0)))
			hint = "工地：%s  %d / %d（%d%%）\n选择带工人的武将队伍，右键工地继续施工" % [
				str(site.get("name", "?")), int(hp), int(mx), int(100.0 * hp / mx)]
			specs.append(_cancel_spec("取消建造", ports._act_cancel_site.bind(site)))
		elif not b.is_empty():
			var busy: bool = _ui.host._building_work_busy(b)
			if busy:
				_apply_cmd_specs([_cancel_work_spec(b)], "")
				return

			# 生产清单按**建筑类型**取（帅帐→工兵、兵营→对应兵种、船坞→运输船/水军）；
			# 原版没有生产项的建筑（粮仓/木材场/钱庄/箭楼…）返回空表。
			var tts: Array = _ui.host.train_types_for(int(b.unit))
			for i in range(tts.size()):
				var tt: Dictionary = tts[i]
				var ok: bool = ports._can_afford(tt) and not busy
				var training: Dictionary = {}
				for order in _ui.host.trainings:
					if order.b == b and int(order.unit) == int(tt.unit): training = order; break
				var progress := clampi(int(100.0 * (1.0 - float(training.get("t", 0)) / maxf(1.0, float(_ui.host.map_data.units[str(int(tt.unit))].hp)))), 0, 100)
				specs.append({
					"text": ("训练%s %d%%" % [str(tt.name), progress]) if not training.is_empty() else ("训练%s" % str(tt.name)),
					"icon": _ui.host.remaster_art.unit_icon(int(tt.unit)),
					"production": true,
					"progress_label": ("%d%%" % progress) if not training.is_empty() else "%d人" % int(_ui.host.map_data.units[str(int(tt.unit))].hp),
					"hover": "训练%s：%s%s" % [str(tt.name), ports._cost_text(tt), (" · %d%%" % progress) if not training.is_empty() else ""],
					"enabled": ok,
					"tip": "生产%s：%s\n快捷键 %d%s" % [str(tt.name), ports._cost_text(tt), i + 1, "；建筑工作中，请先取消或等待" if busy else ("" if ok else "；资源不足")],
					"act": ports._act_train.bind(i),
				})
			# 科技树（§11.3–§11.4）：建筑类型决定可研线（帅帐 0-2 / 弓兵所 3-5 /
			# 武器库 6-11 / 钱庄卖资源 12-17 / 车兵所 18-19 / 船坞 20-22）。
			_add_tech_specs(specs, int(b.unit))
			# 建造是**工兵的命令**（原版建造菜单 16139 在工人面板上）：这里不再放建造条目，
			# 选中工兵后用面板第 4 格「建造」下单（main._build_site_at → 工地 HP=0）。
		elif ports._mobile_count(sel) > 0:
			# 图标面板（原版 3×3）接管时这段文字会被 _refresh_cmd_art 隐藏；
			# 没有图集时它就是等价的可点击清单（同一批 main 命令入口）。
			if ports._worker_count(sel) > 0:
				specs.append({"text": "运输", "enabled": true, "tip": "点资源点：工人往返搬运（载重 200）。", "act": ports._act_transport})
				specs.append({"text": "建造", "enabled": not _ui.host._selected_construction_workers().is_empty(), "tip": "带工人的武将发起建造；工人到位后每4tick施工。", "act": ports._open_build_menu})
				specs.append({"text": "修理", "enabled": true, "tip": "点我方单位/建筑：+16 兵力，四资源各 −16。", "act": ports._act_repair})
			else:
				specs.append({"text": "警戒", "enabled": true, "tip": "取消当前命令、原地待命（不再自动索敌）。", "act": ports._act_watch})
				specs.append({"text": "列阵", "enabled": true, "tip": "十阵法：纯队形，无攻防加成。", "act": ports._act_form_menu})
				specs.append({"text": "计谋", "enabled": true, "tip": "九计谋：按等级解锁，消耗谋略值。", "act": ports._act_hot_menu})
				specs.append({"text": "单挑", "enabled": true, "tip": "点敌方武将部队（10 格内）。", "act": ports._act_duel})
			specs.append({"text": "移动", "enabled": true, "tip": "点地面移动（多选按阵法偏移展开）。", "act": ports._act_move})
			specs.append({"text": "攻击", "enabled": true, "tip": "点敌方单位。", "act": ports._act_attack})
			specs.append({"text": "休息", "enabled": true, "tip": "武将部队每 10 tick +1 兵力，满编结束。", "act": ports._act_rest})
			specs.append({"text": "解散部队", "enabled": true, "tip": "解除武将编组（无资源返还）。", "act": ports._act_disband})
			specs.append({"text": "上船", "enabled": true, "tip": "点自己的运输船（本关无水军则不可用）。", "act": ports._act_board})
		else:
			hint = "选中的对象没有可用命令"
	_apply_cmd_specs(specs, hint)

func _apply_cmd_specs(specs: Array, hint: String) -> void:
	_ui.cmd_capsules = specs
	# 清单变化才回第一页：update_panel 以 10Hz 重放同一清单，不能每次把页码归零。
	# 签名 = 尺寸 + 首尾文本，足以识别列表身份变化（同名同尾的旧清单视为同一页序）。
	var sig := "%d|%s|%s" % [
		specs.size(),
		str((specs[0] as Dictionary).get("text", "")) if specs.size() > 0 else "",
		str((specs[specs.size() - 1] as Dictionary).get("text", "")) if specs.size() > 0 else ""]
	if sig != _ui.cmd_spec_sig:
		_ui.cmd_spec_sig = sig
		_ui.cmd_page = 0
	_ui.cmd_page_count = maxi(1, ceili(float(specs.size()) / float(CMD_PAGE)))
	_ui.cmd_page = mini(_ui.cmd_page, _ui.cmd_page_count - 1)
	_apply_cmd_page()
	# 分页按钮：多于六项才出现；两端在首页/末页禁用（几何永远在场，可见性才稳定）
	var paging := _ui.cmd_page_count > 1
	_ui.cmd_prev.visible = paging and _ui.cmd_prev != null
	_ui.cmd_next.visible = paging and _ui.cmd_next != null
	_ui.cmd_page_label.visible = paging and _ui.cmd_page_label != null and not _ui._topbar_original
	if paging and _ui.cmd_prev != null:
		_ui.cmd_prev.disabled = _ui.cmd_page == 0
		_ui.cmd_next.disabled = _ui.cmd_page == _ui.cmd_page_count - 1
		_ui.cmd_page_label.text = "%d/%d" % [_ui.cmd_page + 1, _ui.cmd_page_count]
	_ui.back_button.visible = (_ui.officer_pick or _ui.build_menu) and _ui.back_button != null
	_ui.cmd_hint.visible = specs.is_empty()
	if specs.is_empty():
		_ui.cmd_hint.text = hint
	_ui.cmd_title.text = "命令" if not specs.is_empty() else "提示"
	ports._refresh_cmd_art()

func _cancel_spec(title: String, action: Callable) -> Dictionary:
	return {"text":title, "icon":_ui.command_catalog.icon(170), "icon_command":true,
		"enabled":true, "tip":title + "，返还已付费用的75%", "act":action}

func _cancel_work_spec(building: Dictionary) -> Dictionary:
	if _ui.host.trainings.any(func(tr): return tr.b == building):
		return _cancel_spec("取消生产", ports._act_cancel_train.bind(building))
	return _cancel_spec("取消出售" if int(building.unit) == 23 else "取消研究", ports._act_cancel_research)

func _apply_cmd_page() -> void:
	if _ui.cmd_buttons.is_empty():
		return
	var start := _ui.cmd_page * CMD_PAGE
	var end: int = mini((_ui.cmd_page + 1) * CMD_PAGE, _ui.cmd_capsules.size())
	for i in range(_ui.cmd_buttons.size()):
		var btn: Button = _ui.cmd_buttons[i]
		var idx: int = start + i
		if idx >= end:
			btn.visible = false
			_ui.cmd_actions[i] = Callable()
			_ui.cmd_view[i] = false
			continue
		var sp: Dictionary = _ui.cmd_capsules[idx]
		btn.text = str(sp.text)
		btn.icon = sp.get("icon", null)
		btn.expand_icon = true
		_ui.command_catalog.decorate_sale(btn, bool(sp.get("sale", false)))
		btn.add_theme_constant_override("icon_max_width", int(28 * _ui.ui_scale))
		var production := bool(sp.get("production", false))
		var progress_badge := btn.get_node_or_null("ProductionProgress") as Label
		if progress_badge != null: progress_badge.hide()
		var icon_command := bool(sp.get("icon_command", false))
		if _ui.build_menu or production or icon_command:
			var slot: Control = _ui.art_buttons[i].btn
			ports._place_left(btn, slot.position.x, slot.position.y, slot.size.x, slot.size.y)
			btn.text = ""
			btn.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
			btn.add_theme_constant_override("icon_max_width", int(slot.size.x - 4 * _ui.ui_scale))
			if icon_command and str(sp.get("badge", "")) != "":
				if progress_badge == null:
					progress_badge = ports._mk_label(btn, 9, _ui.c_gold, HORIZONTAL_ALIGNMENT_CENTER)
					progress_badge.name = "ProductionProgress"
				progress_badge.text = str(sp.badge)
				progress_badge.position = Vector2(0, slot.size.y - 12 * _ui.ui_scale)
				progress_badge.size = Vector2(slot.size.x, 12 * _ui.ui_scale)
				progress_badge.add_theme_font_size_override("font_size", maxi(8, int(9 * _ui.ui_scale)))
				progress_badge.show()
			if production:
				btn.add_theme_color_override("icon_disabled_color", Color.WHITE)
				if progress_badge == null:
					progress_badge = ports._mk_label(btn, 9, _ui.c_gold, HORIZONTAL_ALIGNMENT_CENTER)
					progress_badge.name = "ProductionProgress"
				progress_badge.text = str(sp.get("progress_label", ""))
				progress_badge.position = Vector2(0, slot.size.y - 12 * _ui.ui_scale)
				progress_badge.size = Vector2(slot.size.x, 12 * _ui.ui_scale)
				progress_badge.add_theme_font_size_override("font_size", maxi(8, int(9 * _ui.ui_scale)))
				progress_badge.show()
		else:
			var vp := surface.get_viewport_rect().size
			var s := _ui.ui_scale
			var x := vp.x - 138 * s
			ports._place_left(btn, x + (i % 2) * 67 * s, vp.y - 153.5 * s + (i / 2) * 28 * s, 65 * s, 26 * s)
			btn.icon_alignment = HORIZONTAL_ALIGNMENT_LEFT
		btn.disabled = not bool(sp.enabled)
		btn.set_meta("build_hint", str(sp.get("hover", sp.tip if _ui.build_menu or icon_command else "")))
		btn.tooltip_text = "" if _ui.build_menu or icon_command else str(sp.tip)
		btn.visible = true
		if bool(sp.enabled):
			_ui.cmd_actions[i] = sp.act
		else:
			_ui.cmd_actions[i] = Callable()
		_ui.cmd_view[i] = true

func _on_cmd_page(dir: int) -> bool:
	if _ui.cmd_buttons.is_empty() or _ui.cmd_page_count <= 1:
		return false
	var np := _ui.cmd_page + dir
	if np < 0 or np >= _ui.cmd_page_count:
		return false
	_ui.cmd_page = np
	_apply_cmd_page()
	_ui.cmd_prev.disabled = _ui.cmd_page == 0
	_ui.cmd_next.disabled = _ui.cmd_page == _ui.cmd_page_count - 1
	if _ui.cmd_page_label != null and not _ui._topbar_original:
		_ui.cmd_page_label.text = "%d/%d" % [_ui.cmd_page + 1, _ui.cmd_page_count]
	return true

func cmd_box_ready() -> bool:
	return _ui.cmd_hint != null and _ui.cmd_buttons.size() > 0

func _refresh_hotkeys() -> void:
	var b: Dictionary = ports._selected_building()
	var tts: Array = _ui.host.train_types_for(int(b.unit)) if not b.is_empty() else []
	for i in range(_ui.hot_buttons.size()):
		var e: Dictionary = _ui.hot_buttons[i]
		var btn: Button = e.btn
		var pip: ColorRect = e.pip
		var act: Callable = Callable()
		var tip: String = ""
		var usable: bool = false
		# 编队优先：原版左缘 1..10 就是编队热键（main 已实现 Ctrl+数字 编入 / 数字 呼出）。
		# **组为空时才回退到生产热键** —— 与 main 的按键回退规则完全一致，
		# 否则同一个数字键在 HUD 上和键盘上会有两种含义。
		var gsz: int = int(_ui.host.control_group_size(i + 1))
		var working_site: Dictionary = _ui.host.control_group_work_site(i + 1)
		var work_badge: Label = e.work_badge
		work_badge.visible = not working_site.is_empty()
		work_badge.position = Vector2(14, 12) * _ui.ui_scale
		work_badge.add_theme_font_size_override("font_size", maxi(8, int(7 * _ui.ui_scale)))
		# 选中建筑且该格有生产项时，1/2 优先生产；无建筑时才让编队占位。
		if gsz > 0 and (not working_site.is_empty() or b.is_empty() or i >= tts.size()):
			act = ports._act_group.bind(i + 1)
			usable = true
			tip = "呼出编队 %d（%d 个单位）· Ctrl+%d 把当前选择编入" % [i + 1, gsz, i + 1]
			if not working_site.is_empty(): tip += "\n正在建造%s（队伍在建筑内）" % str(working_site.name)
		elif i < tts.size():
			var tt: Dictionary = tts[i]
			if b.is_empty():
				tip = "先选中我方建筑才能生产（同按键 %d）" % (i + 1)
			else:
				act = ports._act_train.bind(i)
				var busy: bool = _ui.host._building_work_busy(b)
				usable = ports._can_afford(tt) and not busy
				tip = "生产 %s（%s）%s" % [str(tt.name), ports._cost_text(tt), " —— 建筑工作中" if busy else ("" if usable else " —— 资源不足")]
		else:
			tip = "编队 %d 为空 —— 选中部队后按 Ctrl+%d 编入" % [i + 1, i + 1]
		_ui.hot_actions[i] = act
		btn.disabled = not (act.is_valid() and usable)
		btn.tooltip_text = tip
		var sb: StyleBoxFlat = btn.get_theme_stylebox("normal") as StyleBoxFlat
		if sb != null:
			if _ui._topbar_original:
				# 原版素材模式：可用=红底 #F30000，不可用=灰底 #828282（真机取色）
				sb.bg_color = Color(0.952, 0.0, 0.0) if (act.is_valid() and usable) else Color(0.51, 0.51, 0.51)
				sb.border_color = Color(0.62, 0.62, 0.62)
			elif act.is_valid() and usable:
				sb.bg_color = _ui.c_red            # 可用 = 红底（原版选中态就是红底）
			elif act.is_valid():
				sb.bg_color = Color(0.30, 0.14, 0.12)
			else:
				sb.bg_color = _ui.c_btn
		pip.color = _ui.c_ok if (act.is_valid() and usable) else _ui.c_no
		if _ui._topbar_original:
			pip.visible = false

func _add_tech_specs(specs: Array, bid: int) -> void:
	var active: bool = bool(_ui.host.tech_research_active())
	var ids: Array = _ui.host.tech_rows_for_building(bid)
	for id_v in ids:
		var idx := int(id_v)
		var row: Dictionary = _ui.host.tech_row(idx)
		var sell: bool = bool(_ui.host.tech_is_sell(idx))
		var next: bool = bool(_ui.host.tech_is_next(idx))
		var unlocked: bool = bool(_ui.host.tech_unlocked(idx))
		var cost: Dictionary = _ui.host.tech_cost(idx)
		var affordable: bool = ports._can_afford(cost)
		var busy: bool = not ports._selected_building().is_empty() and _ui.host._building_work_busy(ports._selected_building())
		var ok: bool = next and unlocked and affordable and not busy
		var tip: String = "%s。%s" % [str(_ui.host.tech_effect_desc(idx)), str(_ui.host.tech_tip(idx))]
		if not unlocked or not next:
			tip += " —— " + str(_ui.host.tech_block_reason(idx))
		elif busy:
			tip += " —— 该建筑正在工作（完成或取消后才能再开始）"
		elif not affordable:
			tip += " —— 资源不足"
		var verb := "出售" if sell else "研究"
		specs.append({
			# 标签只放名字（面板两列窄按钮；"研究 大本营一级"会被截断）。动词与成本进悬停提示。
			"text": str(row.get("name", "?")),
			"icon": _ui.command_catalog.work_icon(row) if sell else null,
			"icon_command": sell,
			"sale": sell,
			"badge": ("5000" if idx >= 15 else "1000") if sell else "",
			"enabled": ok,
			"tip": "%s %s\n费用：%s%s" % [verb, tip, str(_ui.host.tech_cost_text(idx)), "" if ok else "\n（当前不可用）"],
			"act": ports._act_research.bind(idx),
		})
	# 原版取消入口 16025 → 模式 0x18，按 75% 返还（§11.3 第 4 条）。
	if active:
		specs.append({
			"text": "取消研究",
			"enabled": true,
			"tip": "取消「%s」，返还已扣费用的 75%%（整除）。剩余 %d tick。" % [
				str(_ui.host.tech_research_name()), int(_ui.host.tech_research_remaining())],
			"act": ports._act_cancel_research,
		})
