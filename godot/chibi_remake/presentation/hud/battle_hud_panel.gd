extends Control
## 原版右侧信息区：人物像、竖排姓名、经验／谋略／士气／粮数。
var host: Node2D
var view: Node2D
var portrait: TextureRect
var name_label: Label
var rank_label: Label
var detail: Label
var values: Array[Label] = []
var captions: Array[Label] = []
var row_frames: Array[Panel] = []
var backdrop: Panel
var portrait_frame: Panel
var work_icon: TextureRect
var progress_bar: ProgressBar
var work_badge: Label

func _init(h: Node2D, v: Node2D) -> void:
	host = h; view = v
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _ready() -> void:
	backdrop = _frame(Color(0.06, 0.02, 0.01, 0.88))
	portrait_frame = _frame(Color("080707"))
	portrait = TextureRect.new()
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	portrait.clip_contents = true
	portrait.position = Vector2(2, 2); portrait.size = Vector2(59, 74)
	portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(portrait)
	name_label = _label(Vector2(67, 2), Vector2(70, 76), 14)
	rank_label = _label(Vector2.ZERO,Vector2.ONE,9)
	detail = _label(Vector2(0, 81), Vector2(141, 18), 12)
	for i in range(6):
		row_frames.append(_frame(Color(0.06, 0.02, 0.01, 0.82)))
		captions.append(_label(Vector2.ZERO, Vector2.ONE, 12))
		var label := _label(Vector2.ZERO, Vector2.ONE, 12)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		values.append(label)
	work_icon = TextureRect.new()
	work_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	work_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	work_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(work_icon)
	work_badge = _label(Vector2.ZERO, Vector2.ONE, 9)
	progress_bar = ProgressBar.new()
	progress_bar.show_percentage = false
	progress_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for key in ["background", "fill"]:
		var style := StyleBoxFlat.new()
		style.bg_color = Color("00852b") if key == "fill" else Color("211b13")
		style.border_color = Color("b18b41")
		style.set_border_width_all(1)
		progress_bar.add_theme_stylebox_override(key, style)
	add_child(progress_bar)

func _frame(color: Color) -> Panel:
	var panel := Panel.new()
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.border_color = Color("b18b41")
	style.set_border_width_all(1)
	panel.add_theme_stylebox_override("panel", style)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(panel)
	return panel

func _label(pos: Vector2, dimensions: Vector2, font_size: int) -> Label:
	var label := Label.new()
	label.position = pos; label.size = dimensions
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", Color("f2df9a"))
	label.clip_text = true
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(label)
	return label

func set_ui_scale(s: float) -> void:
	scale = Vector2.ONE
	size = Vector2(132, 174) * s
	backdrop.size = size
	portrait_frame.position = Vector2(4, 4) * s
	portrait_frame.size = Vector2(58, 65) * s
	view._decorate_frame(backdrop, 3 * s)
	view._decorate_frame(portrait_frame, 2 * s)
	portrait.position = Vector2(6, 6) * s; portrait.size = Vector2(54, 61) * s
	name_label.position = Vector2(72, 7) * s; name_label.size = Vector2(54, 48) * s
	rank_label.position=Vector2(69,55)*s;rank_label.size=Vector2(61,15)*s
	rank_label.add_theme_font_size_override("font_size",maxi(9,int(9*s)))
	name_label.add_theme_font_size_override("font_size", maxi(9, int(14 * s)))
	detail.hide()
	work_icon.position = Vector2(5, 113) * s
	work_icon.size = Vector2(36, 36) * s
	work_badge.position = Vector2(5, 139) * s
	work_badge.size = Vector2(36, 12) * s
	work_badge.add_theme_font_size_override("font_size", maxi(8, int(9 * s)))
	progress_bar.position = Vector2(4, 154) * s
	progress_bar.size = Vector2(124, 10) * s
	for i in range(values.size()):
		row_frames[i].position = Vector2(0, 72 + i * 16.5) * s
		row_frames[i].size = Vector2(132, 16.5) * s
		captions[i].position = Vector2(7, 72 + i * 16.5) * s
		captions[i].size = Vector2(48, 16.5) * s
		values[i].position = Vector2(57, 72 + i * 16.5) * s
		values[i].size = Vector2(65, 16.5) * s
		values[i].add_theme_font_size_override("font_size", maxi(9, int(12 * s)))
		captions[i].add_theme_font_size_override("font_size", maxi(9, int(12 * s)))

func sync_selection() -> void:
	var selection: Array = host.selected
	visible = not selection.is_empty()
	if not visible: return
	var u: Dictionary = selection[0]
	var leader: Dictionary = view._officer_selection()
	if not leader.is_empty(): u = leader
	var officer: Dictionary = u.get("officer", {})
	work_icon.hide()
	work_icon.material = null
	view.command_catalog.decorate_sale(work_icon, false)
	work_badge.hide()
	progress_bar.hide()
	for row in row_frames: row.show()
	for label in captions: label.show()
	for label in values: label.show()
	rank_label.visible=not officer.is_empty()
	if not officer.is_empty():
		rank_label.text=host.commands.officer_rank_name(officer)
		rank_label.tooltip_text="%d级 · %s" % [int(officer.level),rank_label.text]
	portrait.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED if bool(u.is_building) else TextureRect.STRETCH_KEEP_ASPECT_COVERED
	if officer.is_empty():
		portrait.texture = view._unit_icon(u)
		portrait.material = view.unit_nodes(u).get("skin").material if view.unit_nodes(u).get("skin") != null else null
		name_label.text = str(u.name)
		detail.text = "已选 %d 个单位" % selection.size()
	else:
		portrait.texture = host.remaster_art.officer_texture(int(officer.index))
		portrait.material = null
		var letters := str(officer.get("name", "")).replace(" ", "")
		name_label.text = "\n".join(letters.split(""))
		detail.text = "官职 %s" % str(host.commands.officer_rank_name(officer))
	var soldiers := 0
	if not officer.is_empty():
		for member in host.units:
			if member.alive and member.owner == u.owner and int(member.get("group_officer", -1)) == int(officer.index):
				soldiers += int(member.hp)
	var titles := ["武力", "智力", "经验", "谋略", "士气", "兵数"]
	var data := [str(int(u.get("officer_might", 0))), str(int(u.get("officer_intellect", 0))),
		host.Progression.progress_text(officer), str(int(u.get("mou", 0))), str(int(u.get("status_173", 70))), str(soldiers)]
	if officer.is_empty():
		titles = ["归属", "攻击力", "防御力", "射程", "视野", "携带"]
		var carry := 0
		for member in selection: carry += int(member.get("carry", 0))
		var commander := "—"
		for member in host.units:
			if member.alive and int(member.owner) == int(u.owner) and int(member.get("officer", {}).get("index", -2)) == int(u.get("group_officer", -1)):
				commander = str(member.officer.get("name", "")).replace(" ", "")
				break
		data = [commander, str(int(u.attack)), str(int(u.defence)), str(int(u.atk_range)), str(int(u.vision)), str(carry)]
	if bool(u.is_building):
		_sync_building(u)
		return
	elif int(u.unit)==47:
		titles=["生命","状态","载员","载员兵力","视野","装卸"]
		var status: String="卸载中" if str(u.state)=="unload" else ("航行中" if str(u.state)=="move" else "待命")
		data=["%d/%d"%[int(u.hp),int(u.maxhp)],status,"%d/16"%int(u.carry_n),str(int(u.carry_hp)),str(int(u.vision)),"载有部队" if int(u.carry_n)>0 else "空载"]
	for i in range(6):
		captions[i].text = titles[i]
		values[i].text = data[i]

func _sync_building(u: Dictionary) -> void:
	if int(u.unit) in [22,24,25]:
		var titles := ["生命", "归属", "资源", "存量", "工作", "视野"]
		var data := ["%d/%d" % [int(u.hp),int(u.maxhp)], "中立" if int(u.owner)==0 else ("我方" if int(u.owner)==host.player_owner else "敌方"), "金币" if int(u.unit) in [24,25] else "铁矿", str(int(u.get("stock",0))), "可采集" if float(u.get("stock",0))>0 else "已采空", str(int(u.vision))]
		for i in range(6):
			captions[i].text = titles[i]
			values[i].text = data[i]
	else:
		_sync_building_work(u)

func _sync_building_work(u: Dictionary) -> void:
	for row in row_frames: row.hide()
	for label in captions: label.hide()
	for label in values: label.hide()
	var site: bool = u.get("site", false)
	rank_label.visible = not site
	var level := clampi(int(host.commands.ai_level(int(u.owner))), 0, 3) if int(u.unit) in [0,1] else 0
	rank_label.text = ["一级", "二级", "三级", "四级"][level]
	progress_bar.visible = site
	progress_bar.value = 100.0 * float(u.hp) / maxf(1.0, float(u.maxhp)) if site else 0.0
	for training in host.trainings:
		if training.b != u: continue
		var definition: Dictionary = host.map_data.units[str(int(training.unit))]
		work_icon.texture = host.remaster_art.unit_icon(int(training.unit))
		work_icon.material = portrait.material
		work_icon.show()
		work_badge.text = "%d人" % int(definition.hp)
		work_badge.show()
		progress_bar.show()
		progress_bar.value = 100.0 * (1.0 - float(training.t) / maxf(1.0, float(definition.hp)))
		break
	var research: Dictionary = host.commands._research_for_building(u)
	if not research.is_empty():
		var selling: bool = host.commands.tech_is_sell(int(research.tech))
		work_icon.texture = view.command_catalog.work_icon(host.commands.tech_row(int(research.tech))) if selling else view._unit_icon(u)
		view.command_catalog.decorate_sale(work_icon, selling)
		work_icon.show()
		progress_bar.show()
		progress_bar.value = 100.0 * float(research.t) / float(host.TECH_TICKS)
