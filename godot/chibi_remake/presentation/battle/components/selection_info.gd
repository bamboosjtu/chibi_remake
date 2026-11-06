extends RefCounted
const ViewMath = preload("res://presentation/battle/view_math.gd")
## selection info: presentation component.
const UIState = preload("res://presentation/battle/components/battle_view_state.gd")
var _ui: UIState
var surface: Node2D
var ports = preload("res://presentation/battle/components/ports/selection_info_dependencies.gd").new()
func _init(data: UIState, node: Node2D) -> void:
	_ui = data
	surface = node

func update_hud_text() -> void:
	if _ui.info == null:
		return
	ports._refresh_metrics()
	_refresh_res_slots()
	var sel: Array = _ui.host.selected
	var fb: String = str(_ui.host.feedback_text)
	# 原版左下角只显示一句状态（「训练完成」）。有反馈就显示反馈，没有就显示悬停信息。
	var l1: String = fb if fb != "" else str(_ui.host.hover_text)
	if fb == "" and not _ui.host.show_debug: l1 = ""
	_ui.info.text = l1
	_ui.info.visible = l1 != "" and _ui._art_hover_name == ""
	var md: Dictionary = _ui.host.map_data
	var l2: String = "三国赤壁 — %s \"%s\"   第 %d 关   我军 归属%d   我军 %d · 敌军 %d · 已选 %d" % [
		str(_ui.host.map_id).to_upper(), str(md.get("name", "")), int(_ui.host.scenario_mission),
		int(_ui.host.player_owner), int(_ui.host.cnt_player), int(_ui.host.cnt_enemy), sel.size()]
	# ARCH-011：工程信息（map id / 帧率 / 事件数 / 武将策略）默认不展示，Ctrl+F3 打开
	if bool(_ui.host.show_debug):
		l2 += "   [调试] mission=%d 敌军建筑=%d zoom=%.2f tick=%d events=%d officer=%s src=%s" % [
			int(_ui.host.scenario_mission), int(_ui.host.cnt_enemy_buildings),
			ports.zoom_x(), int(_ui.host.sim_tick), int(_ui.host.ev_count), str(_ui.host.officer_policy), str(_ui.host.scenario_source)]
	_ui.status_sub.text = l2
	_ui.status_sub.visible = bool(_ui.host.show_debug)
	ports._layout_status_labels(surface.get_viewport_rect().size, _ui.ui_scale)

func _refresh_res_slots() -> void:
	var vals: Array = [float(_ui.host.gold), float(_ui.host.food), float(_ui.host.wood), float(_ui.host.stone)]
	for i in range(_ui.res_slots.size()):
		var e: Dictionary = _ui.res_slots[i]
		var l: Label = e.value
		l.text = "%.0f" % float(vals[i])

func _officer_selection() -> Dictionary:
	for u in _ui.host.selected:
		if bool(u.get("alive", false)) and not bool(u.is_building) and not (u.get("officer", {}) as Dictionary).is_empty():
			return u
	return {}

func _refresh_banner() -> void:
	if _ui.banner == null:
		return
	var sel: Array = _ui.host.selected
	if sel.is_empty():
		_ui.banner.visible = false
		return
	_ui.banner.visible = true
	if sel.size() == 1:
		_ui.banner_label.text = str((sel[0] as Dictionary).name)
	else:
		_ui.banner_label.text = "已选 %d 个单位" % sel.size()

func _unit_icon(u: Dictionary) -> Texture2D:
	var skin: Sprite2D = ports.unit_nodes(u).get("skin", null)
	if skin != null and skin.visible and skin.texture != null:
		var hd := AtlasTexture.new()
		hd.atlas = skin.texture
		hd.region = skin.region_rect
		return hd
	var path: String = str(_ui.host.commands.world._sheet_ref_for(int(u.unit), int(u.owner)))
	if path == "" or not ResourceLoader.exists("res://" + path):
		return null
	var tex: Texture2D = ports._sheet(path)
	if tex == null:
		return null
	var f: int = 0
	if bool(u.is_building):
		f = int(u.get("build_frame", 0))
	var at := AtlasTexture.new()
	at.atlas = tex
	at.region = ViewMath.frame_rect(u, f)
	return at

func _refresh_sel_frame() -> void:
	if _ui.classic_panel != null:
		_ui.sel_frame.hide()
		return
	if _ui.sel_frame == null:
		return
	var sel: Array = _ui.host.selected
	if sel.is_empty():
		_ui.sel_portrait.texture = null
		_ui.sel_name.text = "—— 未选择 ——"
		_ui.sel_rank.text = "左键点兵 / 拖框选择我军"
		_ui.hp_bg.visible = false
		return
	var u: Dictionary = sel[0]
	_ui.sel_portrait.texture = _unit_icon(u)
	var selected_skin: Sprite2D = ports.unit_nodes(u).get("skin", null)
	_ui.sel_portrait.material = selected_skin.material if selected_skin != null and selected_skin.visible else null
	_ui.hp_bg.visible = true
	var hp: float = 0.0
	var mx: float = 0.0
	for x in sel:
		hp += float(x.hp)
		mx += maxf(1.0, float(x.maxhp))
	if sel.size() == 1:
		_ui.sel_name.text = str(u.name)
		var off: Dictionary = u.get("officer", {})
		if not off.is_empty():
			var lv := int(off.get("level", 0))
			var need := 0
			if lv >= 0 and lv < int(_ui.host.EXP_LEVELS.size()): need = int(_ui.host.EXP_LEVELS[lv])
			_ui.sel_rank.text = "归属 %s   %s   经验 %d/%d" % [str(off.get("name", "?")), str(_ui.host.commands.military.officer_rank_name(off)), int(off.get("exp", 0)), need]
		else:
			_ui.sel_rank.text = "%s   #%d" % ["建筑" if bool(u.is_building) else "部队", int(u.unit)]
	else:
		var d: Dictionary = _dominant(sel)
		_ui.sel_name.text = "%s ×%d" % [str((d.sample as Dictionary).name) if not d.is_empty() else "混编", sel.size()]
		_ui.sel_rank.text = "共 %d 个单位" % sel.size()
	# 头像框下沿那条绿条 = 真实 HP（原版同位置也有一条绿条）
	var r: float = clampf(hp / maxf(1.0, mx), 0.0, 1.0)
	_ui.hp_fill.size = Vector2(maxf(1.0, _ui.hp_bg.size.x * r - 2.0), maxf(1.0, _ui.hp_bg.size.y - 2.0))
	_ui.hp_fill.color = Color(1.0 - r * 0.75, 0.25 + r * 0.65, 0.12)

func _refresh_troop() -> void:
	if _ui.classic_panel != null:
		_ui.troop_frame.hide()
		return
	if _ui.troop_frame == null:
		return
	var sel: Array = _ui.host.selected
	if sel.is_empty():
		_ui.troop_frame.visible = false        # 未选择时不显示空框（空的金框看着像坏掉的占位）
		_ui.troop_icon.texture = null
		_ui.troop_icon.visible = false
		_ui.officer_portrait.show_officer({})
		_ui.troop_label.text = ""
		return
	_ui.troop_frame.visible = true
	if sel.size() == 1:
		var u: Dictionary = sel[0]
		_ui.officer_portrait.show_officer(u.get("officer", {}))
		if _ui.officer_portrait.visible:
			_ui.troop_icon.texture = null
			_ui.troop_icon.visible = false
			_ui.troop_label.text = "%s\n武力 %.0f   智力 %.0f" % [
				str(u.get("officer", {}).get("name", "?")),
				float(u.get("officer_might", 0)), float(u.get("officer_intellect", 0))]
		else:
			_ui.troop_icon.texture = _unit_icon(u)
			var troop_skin: Sprite2D = ports.unit_nodes(u).get("skin", null)
			_ui.troop_icon.material = troop_skin.material if troop_skin != null and troop_skin.visible else null
			_ui.troop_icon.visible = true
			_ui.troop_label.text = "%s\nHP %.0f / %.0f   兵力 %d" % [str(u.name), float(u.hp), float(u.maxhp), 1]
		return
	_ui.officer_portrait.show_officer({})
	var d: Dictionary = _dominant(sel)
	if d.is_empty():
		_ui.troop_icon.texture = null
		_ui.troop_icon.visible = false
		_ui.troop_label.text = ""
		return
	_ui.troop_icon.texture = _unit_icon(d.sample)
	var dominant_skin: Sprite2D = (d.sample as Dictionary).get("skin", null)
	_ui.troop_icon.material = dominant_skin.material if dominant_skin != null and dominant_skin.visible else null
	_ui.troop_icon.visible = true
	_ui.troop_label.text = "%s ×%d\n共 %d 个单位" % [str((d.sample as Dictionary).name), int(d.n), sel.size()]

func _dominant(sel: Array) -> Dictionary:
	var counts: Dictionary = {}
	var sample: Dictionary = {}
	var best: int = 0
	var best_id: int = -1
	for u in sel:
		var k: int = int(u.unit)
		counts[k] = int(counts.get(k, 0)) + 1
		if not sample.has(k):
			sample[k] = u
		if int(counts[k]) > best:
			best = int(counts[k])
			best_id = k
	if best_id < 0:
		return {}
	return {"unit": best_id, "n": best, "sample": sample[best_id]}

func _act_assign_officer(idx: int) -> void:
	_ui.host.player_commands.submit(14,_ui.host.commands.military._order_form_up.bind(idx),Vector2.ZERO,-1,idx)
	_ui.officer_pick = false
	ports._refresh_cmd_panel()

func _act_open_officer_pick() -> void:
	_ui.officer_pick = true
	ports._refresh_cmd_panel()

func _act_close_officer_pick() -> void:
	_ui.officer_pick = false
	_ui.build_menu = false
	ports._refresh_cmd_panel()

func _selected_building() -> Dictionary:
	for u in _ui.host.selected:
		if bool(u.is_building) and int(u.owner) == int(_ui.host.player_owner) and bool(u.alive) \
				and not bool(u.get("site", false)):
			return u
	return {}

func _selected_site() -> Dictionary:
	for u in _ui.host.selected:
		if bool(u.is_building) and int(u.owner) == int(_ui.host.player_owner) and bool(u.alive) and bool(u.get("site", false)):
			return u
	return {}

func _worker_count(sel: Array) -> int:
	var n := 0
	for u in sel:
		if not u.is_building and u.alive and int(u.unit) == 30:
			n += 1
	return n

func _mobile_count(sel: Array) -> int:
	var n: int = 0
	for u in sel:
		if not bool(u.is_building) and bool(u.alive):
			n += 1
	return n

func _can_afford(tt: Dictionary) -> bool:
	return float(_ui.host.gold) >= float(tt.get("gold", 0)) and float(_ui.host.wood) >= float(tt.get("wood", 0)) \
		and float(_ui.host.food) >= float(tt.get("food", 0)) and float(_ui.host.stone) >= float(tt.get("stone", 0))

func _cost_text(tt: Dictionary) -> String:
	var keys: Array = ["gold", "food", "wood", "stone"]
	var names: Array = ["金", "粮", "木", "铁"]
	var parts: PackedStringArray = PackedStringArray()
	for i in range(4):
		var v: float = float(tt.get(str(keys[i]), 0))
		if v > 0.0:
			parts.append("%s%.0f" % [str(names[i]), v])
	return " ".join(parts) if parts.size() > 0 else "免费"

func _rebuild_stats_text() -> void:
	if _ui.classic_panel != null:
		_ui.panel_label.hide()
		_ui.cmd_title.hide()
		_ui.cmd_hint.hide()
		return
	if _ui.panel_label == null:
		return
	var sel: Array = _ui.host.selected
	var lines: PackedStringArray = PackedStringArray()
	if sel.is_empty():
		lines.append("左键 选兵/框选 · Shift 加选 · 右键 移动/攻击")
		lines.append("1/2 生产(需选中我方建筑) · 5-9 归属显示")
		lines.append("边缘/方向键 平移 · F 镜头归中（原版不能缩放）")
		lines.append("M 暂停菜单 · F11/F12 截图 · Enter 信息输入")
	else:
		if sel.size() == 1:
			var u: Dictionary = sel[0]
			if bool(u.is_building):
				var trs: Array = _ui.host.trainings
				if trs.is_empty():
					lines.append("生产队列：空")
				for tr in trs:
					lines.append("生产中 %s  余 %.1fs" % [str(_ui.host.commands.world._unit_name(int(tr.unit))), float(tr.t) * _ui.host.clock.period()])
			else:
				# 与原版面板同序：攻击力 / 防御力 / 射程 / 视野（均取自 DATA.EXP）
				lines.append("攻击力 %.0f    防御力 %.0f" % [float(u.attack), float(u.defence)])
				lines.append("射程 %.0f      视野 %.0f" % [float(u.atk_range), float(u.vision)])
			lines.append("HP %.0f / %.0f" % [float(u.hp), float(u.maxhp)])
			var off: Dictionary = u.get("officer", {})
			if not off.is_empty():
				# 原版 boot_010 的武将面板是「经验 / 谋略 / 士气 / 粮数」。
				#   谋略 = 武将智力（DATA.EXP +0x16，有据）
				#   经验 = 武将等级（+0x18，装载时 -1）
				#   粮数 = 身上背的货（运输实现后才有意义）
				#   **士气本模拟没有建模** —— 明说，不编一个数字出来。
				lines.append("经验 %d   谋略 %.0f" % [int(off.get("level", 0)), float(u.get("officer_intellect", 0))])
				lines.append("粮数 %.0f   士气（未建模）" % float(u.get("carry", 0.0)))
			var ca: Vector2i = _ui.host.commands.orders._cell_of_px(float(u.ax), float(u.ay))
			lines.append("位置 A=%d B=%d   状态 %s" % [ca.x, ca.y, str(u.state)])
			lines.append("uid %d   归属 %d" % [int(u.uid), int(u.owner)])
		else:
			lines.append("已选择 %d 个单位" % sel.size())
			var groups: Dictionary = {}
			var order: Array = []
			for u in sel:
				var k: int = int(u.unit)
				if not groups.has(k):
					groups[k] = {"name": str(u.name), "n": 0, "hp": 0.0, "max": 0.0}
					order.append(k)
				groups[k].n += 1
				groups[k].hp += float(u.hp)
				groups[k].max += float(u.maxhp)
			var shown: int = 0
			for k in order:
				if shown >= 8:
					lines.append("  ……")
					break
				var g: Dictionary = groups[k]
				lines.append("  %s ×%d   %.0f/%.0f" % [str(g.name), int(g.n), float(g.hp), float(g.max)])
				shown += 1
			lines.append("[5-9] 归属显示   [B] 建筑   [U] 部队")
	_ui.panel_label.text = "\n".join(lines)

func _sel_state_text() -> String:
	var parts: PackedStringArray = PackedStringArray()
	for u in _ui.host.selected:
		parts.append("%s:%s/%d" % [str(u.name), str(u.state), (u.path as Array).size()])
	return ",".join(parts) if parts.size() > 0 else "-"

func update_hover() -> void:
	var hu: Dictionary = _ui.host.commands.orders._hover_unit(surface.get_global_mouse_position())
	_ui.host.hover_text = ""
	if _ui.host.show_debug and not hu.is_empty():
		_ui.host.hover_text = "%s  hp %.0f/%.0f  owner %d" % [str(hu.name), float(hu.hp), float(hu.maxhp), int(hu.owner)]
