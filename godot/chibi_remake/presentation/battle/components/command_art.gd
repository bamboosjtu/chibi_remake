extends RefCounted
## command art: presentation component.
const UIState = preload("res://presentation/battle/components/battle_view_state.gd")
const Config = preload("res://simulation/battle_config.gd")
var _ui: UIState
var surface: Node2D
var ports = preload("res://presentation/battle/components/ports/command_art_dependencies.gd").new()
const Textures = preload("res://presentation/battle/runtime_textures.gd")

const CMD_HOT_NAMES = preload("res://simulation/battle_config.gd").JIMOU_NAMES

const CMD_FORM_NAMES = preload("res://simulation/battle_config.gd").FORM_NAMES

const CMD_PAGE := 6

func _init(data: UIState, node: Node2D) -> void:
	_ui = data
	surface = node

func _build_cmd_art() -> void:
	if _ui.art_panel != null:
		return
	_ui.art_atlas = Textures.load_texture("res://art/full/ui/cmd-icons-redraw-v3.png")
	if _ui.art_atlas == null:
		return
	_ui.art_panel = Control.new()
	_ui.art_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ui.ui_layer.add_child(_ui.art_panel)
	# 主组：3×3 固定格位（内容由 _apply_panel_type 按分型填）
	for i in range(9):
		_add_art_button(0, "", "", _on_panel_slot.bind(i))
	# 计谋子菜单（sub="hot"）9 项
	for i in range(CMD_HOT_NAMES.size()):
		_add_art_button(i, CMD_HOT_NAMES[i], "hot", _on_art_hot.bind(i))
	# 阵型子菜单（sub="form"）10 项
	for i in range(CMD_FORM_NAMES.size()):
		_add_art_button(9 + i, CMD_FORM_NAMES[i], "form", _on_art_form.bind(i))
	# Legacy handle/index stays hidden; ability menus dismiss on world clicks.
	_add_art_button(0, "返回", "back", _close_art_sub)
	_ui.art_back = _ui.art_buttons.back().btn
	_ui.art_back.texture = null
	var back_bg := ColorRect.new()
	back_bg.color = Color("28190f")
	back_bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	back_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ui.art_back.add_child(back_bg)
	var back_label := ports._mk_label(_ui.art_back, 14, _ui.c_gold, HORIZONTAL_ALIGNMENT_CENTER)
	back_label.text = "返回"
	back_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for page in ["form_next", "form_prev"]:
		_add_art_button(0, "下一页" if page == "form_next" else "上一页", page, _formation_page.bind(page == "form_next"))
		_ui.art_buttons.back().btn.texture = _ui.command_catalog.icon(123 if page == "form_next" else 124)
		_ui.art_buttons.back().btn.set_meta("source_frame", 123 if page == "form_next" else 124)
	# 组建入口：原版由"组建/生产"对话框（16140 → 0x11210）承担，
	# 本工程把它作为图标面板旁的小按钮保留（否则工人无法组建部队）。
	_ui.worker_button = ports._mk_button(_ui.ui_layer, 12)
	_ui.worker_button.text = ""
	_ui.worker_button.tooltip_text = "组建"
	_ui.worker_button.text = "组建"
	_ui.worker_button.icon = null
	_ui.worker_button.expand_icon = true
	_ui.worker_button.pressed.connect(ports._act_open_officer_pick)
	_ui.join_button = ports._mk_button(_ui.ui_layer,12)
	_ui.join_button.text="加入"
	_ui.join_button.pressed.connect(func():_ui.host._cmd_begin("join"))
	# 悬停提示
	_ui.art_tip = Label.new()
	_ui.art_tip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ui.art_tip.visible = false
	_ui.art_tip.add_theme_color_override("font_color", Color(1.0, 0.93, 0.62))
	_ui.art_tip.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
	_ui.art_tip.add_theme_constant_override("shadow_offset_x", 1)
	_ui.art_tip.add_theme_constant_override("shadow_offset_y", 1)
	_ui.art_panel.add_child(_ui.art_tip)

func _command_icon(cell: int) -> Texture2D:
	var frame := cell+98 if cell<9 else (cell+104 if cell<19 else cell+135)
	return _ui.command_catalog.icon(frame)

func _set_art_state(index: int, state: int) -> void:
	if index<0 or index>=_ui.art_buttons.size(): return
	var entry: Dictionary=_ui.art_buttons[index]
	var button: TextureRect=entry.btn
	if bool(button.get_meta("cmd_disabled",false)): return
	var frame := int(button.get_meta("source_frame",0))
	if frame>0:button.texture=_ui.command_catalog.icon(frame,state)
	button.modulate=[Color.WHITE,Color(0.68,0.68,0.68),Color(1.18,1.12,1.04)][clampi(state,0,2)]
	button.set_meta("visual_state",state)

func _add_art_button(cell: int, name: String, sub: String, act: Callable) -> void:
	var tr := TextureRect.new()
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.texture = _command_icon(cell)
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tr.set_meta("cmd_name", name)
	tr.set_meta("source_frame",cell+98 if cell<9 else (cell+104 if cell<19 else cell+135))
	_ui.art_panel.add_child(tr)
	_ui.art_buttons.append({"btn": tr, "sub": sub, "idx": _ui.art_buttons.size()})
	_ui.art_actions.append(act)

func _panel_specs() -> Array:
	var selection: Dictionary=_ui.host.selection_description()
	var specs:=[]
	for id in selection.ids:
		var spec: Dictionary=_ui.command_catalog.spec(int(id))
		spec.disabled=int(id) in selection.disabled
		specs.append(spec)
	return specs

func _unlocked_indices(formation: bool) -> Array:
	var level := -1
	for unit in _ui.host.selected:
		if not bool(unit.get("alive", false)) or float(unit.get("die_t", -1)) >= 0.0:
			continue
		if int(unit.get("owner", -1)) != int(_ui.host.player_owner) or bool(unit.get("attached", false)) or bool(unit.get("is_building", false)):
			continue
		var officer: Dictionary = unit.get("officer", {})
		if not officer.is_empty():
			level = clampi(int(officer.get("level", 0)), 0, 9)
			break
	if level < 0:
		return []
	var masks: Array = Config.FORM_LV_MASK if formation else Config.JIMOU_LV_MASK
	var mask := int(masks[level])
	var out: Array = []
	for index in range(CMD_FORM_NAMES.size() if formation else CMD_HOT_NAMES.size()):
		if (mask & (1 << index)) != 0:
			out.append(index)
	return out

func _jimou_indices() -> Array:
	return _unlocked_indices(false)

func _formation_page(next: bool) -> void:
	_ui.art_sub = "form_more" if next and _unlocked_indices(true).has(9) else "form"
	_refresh_cmd_art()

func _apply_panel_type() -> void:
	var kind := ports.panel_kind()
	var specs: Array = _panel_specs()
	# 签名 = 分型 + 第 8/9 格命令 + 下船可用性（载员变化时也要换图）。
	var sig := kind + "|" + JSON.stringify(specs)
	if sig == _ui._panel_sig:
		return
	_ui._panel_sig = sig
	for i in range(9):
		var tr: TextureRect = _ui.art_buttons[i].btn
		if i >= specs.size():
			tr.texture = null
			tr.set_meta("cmd_name", "")
			tr.set_meta("cmd_disabled", true)
			tr.modulate = Color(1, 1, 1, 0.4)
			continue
		var sp: Dictionary = specs[i]
		var disabled := bool(sp.get("disabled", false))
		if str(sp.get("n", "")) == "":
			tr.texture = null
			tr.set_meta("cmd_name", "")
			tr.set_meta("cmd_disabled", true)
			tr.modulate = Color(1, 1, 1, 0.4)
			continue
		tr.set_meta("source_frame",int(sp.f))
		tr.set_meta("command_id",int(sp.get("id",0)))
		tr.texture = _ui.command_catalog.icon(int(sp.f))
		tr.set_meta("cmd_name", str(sp.n))
		tr.set_meta("cmd_disabled", disabled)
		tr.modulate = Color(1, 1, 1, 0.4 if disabled else 1.0)

func _close_art_sub() -> void:
	_ui.art_sub = ""
	_ui.build_menu = false
	ports._refresh_cmd_panel()

func _layout_cmd_art() -> void:
	_build_cmd_art()
	if _ui.art_panel == null:
		return
	_apply_panel_type()
	var vp: Vector2 = surface.get_viewport_rect().size
	var s: float = _ui.ui_scale
	var gap: float = 2.0 * s
	var cell: float = (132.0 * s - 2.0 * gap) / 3.0
	var base_x: float = vp.x - 138.0 * s
	var bottom_y: float = vp.y - _ui.hud_metrics.bottom_inset - 6.0 * s
	var auxiliary := false # Independent workers use the original four icon commands.
	var auxiliary_y := bottom_y-20*s
	if auxiliary:bottom_y-=22*s
	if _ui.classic_panel != null:
		var top_y: float = _ui.classic_panel.position.y + _ui.classic_panel.size.y + 4.0 * s
		cell = minf(cell, maxf(8.0 * s, (bottom_y - top_y - 2.0 * gap) / 3.0))
	base_x += (132.0 * s - (3.0 * cell + 2.0 * gap)) * 0.5
	var base_y: float = bottom_y - (3.0 * cell + 2.0 * gap)
	for e in _ui.art_buttons:
		var tr: TextureRect = e.btn
		var sub: String = str(e.sub)
		var idx: int = int(e.idx)
		tr.size = Vector2(cell, cell)
		if sub == "":
			tr.position = Vector2(base_x + (idx % 3) * (cell + gap), base_y + (floori(float(idx) / 3.0)) * (cell + gap))
		elif sub == "back":
			tr.hide()
		else:
			# Locked commands retain their original grid cells. The last two
			# formations occupy cells 0/1 on page two; arrows occupy cell 8.
			var k: int = idx - (9 if sub == "hot" else 18)
			if sub in ["form_next", "form_prev"]: k = 8
			elif sub == "form" and k >= 8: k -= 8
			tr.position = Vector2(base_x + (k % 3) * (cell + gap), base_y + floori(float(k) / 3.0) * (cell + gap))
		tr.visible = _art_visible(sub)
	if _ui.worker_button != null:
		_ui.worker_button.visible=auxiliary
		_ui.join_button.visible=auxiliary
		_ui.worker_button.position=Vector2(vp.x-138*s,auxiliary_y)
		_ui.join_button.position=Vector2(vp.x-71*s,auxiliary_y)
		_ui.worker_button.size=Vector2(65,20)*s
		_ui.join_button.size=Vector2(65,20)*s
	if _ui.art_tip != null:
		# 原版将命令名显示在左下状态栏；避免悬停提示盖住武将属性。
		_ui.art_tip.position = _ui.info.position
		_ui.art_tip.add_theme_font_size_override("font_size", maxi(9, int(12 * s)))

func _art_visible(sub: String) -> bool:
	if _ui.art_panel == null:
		return false
	if ports.panel_kind() == "" or _ui.officer_pick or _ui.build_menu:
		return false
	if sub == "":
		return _ui.art_sub == ""
	if sub == "back": return false
	if sub == "form": return _ui.art_sub.begins_with("form")
	if sub == "form_next": return _ui.art_sub == "form" and _unlocked_indices(true).has(9)
	if sub == "form_prev": return _ui.art_sub == "form_more"
	return _ui.art_sub == sub

func art_panel_active() -> bool:
	return _ui.art_panel != null and not _ui.officer_pick and not _ui.build_menu and ports.panel_kind() != ""

func _refresh_cmd_art() -> void:
	if _ui.art_panel == null and not ResourceLoader.exists("res://art/full/ui/cmd-icons-redraw-v3.png"):
		return
	if _ui.art_sub == "form_more" and not _unlocked_indices(true).has(9): _ui.art_sub = "form"
	_layout_cmd_art()
	if _ui.art_panel == null:
		return
	_apply_panel_type()
	var active := art_panel_active()
	var active_specs: Array=_panel_specs()
	var jimou_indices: Array = _jimou_indices()
	if _ui.art_sub != "": active_specs = _submenu_specs()
	_ui.command_panel=_ui.command_catalog.configure(active_specs if active else _ui.cmd_capsules.slice(_ui.cmd_page*CMD_PAGE,(_ui.cmd_page+1)*CMD_PAGE))
	var specs_now: Array = _panel_specs()
	for e in _ui.art_buttons:
		var tr2: TextureRect = e.btn
		if str(e.sub) == "" and (int(e.idx) >= specs_now.size() or str(specs_now[int(e.idx)].get("n",""))==""):
			tr2.visible = false                  # 工人组第 9 格为空（原版就是空位）
			continue
		tr2.visible = active and _art_visible(str(e.sub))
		if str(e.sub) == "hot":
			tr2.visible = tr2.visible and jimou_indices.has(int(e.idx) - 9)
		elif str(e.sub) == "form":
			var index: int = int(e.idx) - 18
			tr2.visible = tr2.visible and _unlocked_indices(true).has(index) and ((index >= 8) == (_ui.art_sub == "form_more"))
	if active:
		for button in _ui.cmd_buttons:
			button.hide()
		# REQ-005：图像面板整体接管时，文字面板的分页/返回脚行一并隐藏，
		# 等下一次 _apply_cmd_specs 按当前状态重新给出可见性。
		if _ui.cmd_prev != null:
			_ui.cmd_prev.hide()
		if _ui.cmd_next != null:
			_ui.cmd_next.hide()
		if _ui.cmd_page_label != null:
			_ui.cmd_page_label.hide()
		if _ui.back_button != null:
			_ui.back_button.hide()

func _submenu_specs() -> Array:
	var specs: Array = []
	for slot in range(9): specs.append({"id":0,"n":"","disabled":true})
	if _ui.art_sub == "hot":
		for i in _jimou_indices(): specs[i] = {"id":16210+i,"n":CMD_HOT_NAMES[i]}
	else:
		for i in _unlocked_indices(true):
			if (i >= 8) == (_ui.art_sub == "form_more"):
				specs[i - 8 if i >= 8 else i] = {"id":16190+i,"n":CMD_FORM_NAMES[i]}
		if _ui.art_sub == "form_more": specs[8] = {"id":16200,"n":"上一页"}
		elif _unlocked_indices(true).has(9): specs[8] = {"id":16201,"n":"下一页"}
	return specs

func _on_panel_slot(i: int) -> void:
	var specs: Array = _panel_specs()
	if i < 0 or i >= specs.size():
		return
	if i < _ui.art_buttons.size() and bool(_ui.art_buttons[i].btn.get_meta("cmd_disabled", false)):
		return
	match str(specs[i].cmd):
		"attack": _ui.host._cmd_begin("attack")
		"move": _ui.host._cmd_begin("move")
		"transport": _ui.host._cmd_begin("transport")
		"build": _open_build_menu()
		"repair": _ui.host._cmd_begin("repair")
		"rest": ports._act_rest()
		"disband":
			ports._act_disband()
			_ui.art_sub = ""
			ports.update_panel()
		"board": _ui.host._cmd_begin("board")
		"unload": _ui.host._cmd_begin("unload")
		"form": ports._act_open_officer_pick()
		"join": _ui.host._cmd_begin("join")
		"return": _ui.host.player_commands.submit(25,_ui.host._return_selected_cargo)
		"watch": ports._act_watch()
		"formation":
			_ui.art_sub = "" if _ui.art_sub == "form" else "form"
			_refresh_cmd_art()
		"jimou":
			_ui.art_sub = "" if _ui.art_sub == "hot" else "hot"
			_refresh_cmd_art()
		"duel":
			_ui.host._duel_begin()
			_ui.art_sub = ""
			_refresh_cmd_art()

func _open_build_menu() -> void:
	if _ui.host._selected_construction_workers().is_empty():
		_ui.host._feedback("建造由麾下带工人的武将发起；独立工人请先组建队伍")
		return
	if _ui.host.build_types.is_empty():
		_ui.host._feedback("本关没有可建造的建筑")
		return
	_ui.build_menu = true
	_ui.art_sub = ""
	ports._refresh_cmd_panel()

func _on_art_hot(i: int) -> void:
	if not _jimou_indices().has(i):
		return
	_ui.host._jimou_begin(i)
	_ui.art_sub = ""
	_refresh_cmd_art()

func _on_art_form(i: int) -> void:
	if not _unlocked_indices(true).has(i): return
	_ui.host.player_commands.submit(10,_ui.host._set_formation.bind(i),Vector2.ZERO,-1,i)
	_ui.art_sub = ""
	_refresh_cmd_art()

func _handle_cmd_key(k: InputEventKey) -> bool:
	if k.echo:return false
	if not k.pressed:
		if _ui._hot_pressed>=0 and _ui._hot_keycode==k.keycode:
			_set_art_state(_ui._hot_pressed,0);_ui._hot_pressed=-1;_ui._hot_keycode=0;return true
		return false
	if k.keycode == KEY_PAGEUP:
		if _ui.art_sub == "form_more": _formation_page(false); return true
		return ports._on_cmd_page(-1)
	if k.keycode == KEY_PAGEDOWN:
		if _ui.art_sub == "form" and _unlocked_indices(true).has(9): _formation_page(true); return true
		return ports._on_cmd_page(1)
	if _ui.officer_pick:
		if k.keycode == KEY_ESCAPE:
			ports._act_close_officer_pick()
			return true
		if k.keycode >= KEY_1 and k.keycode <= KEY_6:
			var slot := int(k.keycode) - int(KEY_1)
			var idx := _ui.cmd_page * CMD_PAGE + slot
			if idx < _ui.cmd_capsules.size() and bool((_ui.cmd_capsules[idx] as Dictionary).get("enabled", false)):
				ports._on_cmd(slot)          # 与按钮同一路径：槽位动作 + 页内偏移
				return true
	var hot_slot: int=_ui.command_catalog.hotkeys.find(OS.get_keycode_string(k.keycode))
	if art_panel_active() and hot_slot>=0:
		var button_index: int=hot_slot+(9 if _ui.art_sub=="hot" else (18 if _ui.art_sub=="form" else 0))
		if _ui.art_sub == "form" and hot_slot == 8: button_index = 29
		elif _ui.art_sub == "form_more": button_index = 30 if hot_slot == 8 else (26 + hot_slot if hot_slot < 2 else -1)
		if button_index<0 or button_index>=_ui.art_buttons.size() or not _ui.art_buttons[button_index].btn.visible or bool(_ui.art_buttons[button_index].btn.get_meta("cmd_disabled",false)):return false
		_ui._hot_pressed=button_index
		_ui._hot_keycode=k.keycode
		if _ui.art_sub=="hot":_on_art_hot(hot_slot)
		elif button_index >= 29: _formation_page(button_index == 29)
		elif _ui.art_sub.begins_with("form"):_on_art_form(button_index - 18)
		else:
			var specs: Array=_panel_specs()
			if hot_slot>=specs.size() or str(specs[hot_slot].get("cmd",""))=="" or bool(specs[hot_slot].get("disabled",false)):return false
			_on_panel_slot(hot_slot)
		_set_art_state(button_index,1)
		if _ui.host.sfx!=null:_ui.host.sfx.play("click.wav")
		return true
	return false
