extends RefCounted
## campaign dialog: presentation component.
const UIState = preload("res://presentation/menu/menu_state.gd")
var _ui: UIState
var surface: Control
var ports = preload("res://presentation/menu/ports/campaign_dialog_dependencies.gd").new()
const Textures = preload("res://presentation/battle/runtime_textures.gd")

# ── 「选择势力」这一步（2a 新增）：开始游戏 → 先问曹操/刘备，再列该线关卡 ──

const CAMPAIGN_CAO := "chibic"             # 左格：曹操（关卡 id 前缀也是它）

const CAMPAIGN_LIU := "chibil"             # 右格：刘备

const CAMPAIGN_IDS := ["chibic", "chibil"]

const CAMPAIGN_FACTION := {"chibic": "曹操", "chibil": "刘备"}
# 立绘取自 res:// 里已有的官员像（059=曹操 / 039=刘备）。
# res:// 没有任何 UI 贴图，所以木框/名牌/箭头全部是形状，不许引用不存在的贴图。

const PORTRAIT_PATH := {
	"chibic": "res://art/full/officers/059-portrait-v2.png",
	"chibil": "res://art/full/officers/039-portrait-v2.png",
}

const PORTRAIT_SIZE := 300                 # 立绘显示边长（原图 1254x1254 正方形，等比不裁）

const SLOT_W := 330                        # 单个势力格宽

const SLOT_H := 450                        # 单个势力格高（箭头落脚区 + 木框立绘 + 名牌）

const ARROW_ROOM := 34                     # 顶部留给红箭头的高度

func _init(data: UIState, node: Control) -> void:
	_ui = data
	surface = node

func _campaign_alias(s: String) -> String:
	var v := s.strip_edges().to_lower()
	if v == "cao" or v == "wei" or v == "chibic" or v == "0":
		return CAMPAIGN_CAO
	if v == "liu" or v == "shu" or v == "chibil" or v == "1":
		return CAMPAIGN_LIU
	return ""

func _load_portrait(camp: String) -> Texture2D:
	var path := str(PORTRAIT_PATH.get(camp, ""))
	if path == "" or not ResourceLoader.exists(path):
		push_warning("campaign portrait missing: %s -> %s" % [camp, path])
		return null
	var t := Textures.load_texture(path) as Texture2D
	if t == null:
		push_warning("campaign portrait is not a texture: %s -> %s" % [camp, path])
		return null
	_ui.campaign_tex[camp] = t
	return t

func _make_faction_slot(camp: String) -> Control:
	var slot := Control.new()
	slot.custom_minimum_size = Vector2(SLOT_W, SLOT_H)
	slot.mouse_filter = Control.MOUSE_FILTER_STOP
	slot.gui_input.connect(_on_slot_input.bind(camp))

	var col := VBoxContainer.new()
	col.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	col.add_theme_constant_override("separation", 10)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	slot.add_child(col)

	# 顶部留出红箭头的落脚区（箭头画在这里，不参与布局）
	var arrow_room := Control.new()
	arrow_room.custom_minimum_size = Vector2(0, ARROW_ROOM)
	arrow_room.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(arrow_room)

	var frame := PanelContainer.new()
	frame.add_theme_stylebox_override("panel", ports._wood_frame(false, 10))
	frame.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(frame)

	var pic := TextureRect.new()
	pic.texture = _load_portrait(camp)
	pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	pic.custom_minimum_size = Vector2(PORTRAIT_SIZE, PORTRAIT_SIZE)
	pic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_child(pic)

	var plate := PanelContainer.new()
	plate.add_theme_stylebox_override("panel", ports._wood_plate())
	plate.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(plate)

	var nm := Label.new()
	nm.text = str(CAMPAIGN_FACTION.get(camp, ""))
	nm.add_theme_font_size_override("font_size", 34)
	nm.add_theme_color_override("font_color", _ui.C_WOOD_TXT)
	nm.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	nm.mouse_filter = Control.MOUSE_FILTER_IGNORE
	plate.add_child(nm)

	_ui.campaign_slots.append(slot)
	_ui.campaign_frames.append(frame)
	return slot

func _on_slot_input(event: InputEvent, camp: String) -> void:
	if not (event is InputEventMouseButton):
		return
	var mb := event as InputEventMouseButton
	if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
		_set_campaign(camp, true)

func _set_campaign(camp: String, refresh: bool) -> void:
	if not CAMPAIGN_IDS.has(camp):
		return
	_ui.campaign_choice = camp
	if refresh:
		_refresh_campaign_cursor()

func _move_campaign(d: int) -> void:
	var i := CAMPAIGN_IDS.find(_ui.campaign_choice)
	if i < 0:
		i = 0
	i = posmod(i + d, CAMPAIGN_IDS.size())
	_set_campaign(str(CAMPAIGN_IDS[i]), true)

func _refresh_campaign_cursor() -> void:
	var idx := CAMPAIGN_IDS.find(_ui.campaign_choice)
	if idx < 0:
		idx = 0
	for i in _ui.campaign_frames.size():
		var f: PanelContainer = _ui.campaign_frames[i]
		f.add_theme_stylebox_override("panel", ports._wood_frame(i == idx, 10))
	if _ui.campaign_cursor == null:
		return
	if _ui.campaign_panel == null or not _ui.campaign_panel.visible or idx >= _ui.campaign_slots.size():
		_ui.campaign_cursor.visible = false
		return
	var slot: Control = _ui.campaign_slots[idx]
	var r := slot.get_global_rect()
	_ui.campaign_cursor.visible = true
	_ui.campaign_cursor.position = Vector2(r.get_center().x, r.position.y + 4.0)

func _build_campaign_dialog() -> void:
	_ui.campaign_slots.clear()
	_ui.campaign_frames.clear()
	_ui.campaign_tex.clear()

	var frame := StyleBoxFlat.new()
	frame.bg_color = _ui.C_FACE
	frame.border_color = _ui.C_BEVEL
	frame.set_border_width_all(3)
	frame.set_corner_radius_all(4)
	frame.shadow_color = Color(0, 0, 0, 0.55)
	frame.shadow_size = 12
	frame.shadow_offset = Vector2(0, 6)
	frame.set_content_margin_all(6)

	_ui.campaign_panel = PanelContainer.new()
	_ui.campaign_panel.add_theme_stylebox_override("panel", frame)
	_ui.campaign_panel.anchor_left = 0.5
	_ui.campaign_panel.anchor_right = 0.5
	_ui.campaign_panel.anchor_top = 0.5
	_ui.campaign_panel.anchor_bottom = 0.5
	_ui.campaign_panel.offset_left = -420.0
	_ui.campaign_panel.offset_right = 420.0
	_ui.campaign_panel.offset_top = -318.0
	_ui.campaign_panel.offset_bottom = 318.0
	_ui.campaign_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_ui.campaign_panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	_ui.campaign_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_ui.campaign_panel.visible = false
	surface.add_child(_ui.campaign_panel)

	var face := StyleBoxFlat.new()
	face.bg_color = _ui.C_FACE_IN
	face.border_color = _ui.C_GROOVE
	face.set_border_width_all(2)
	face.set_corner_radius_all(2)
	face.set_content_margin_all(16)
	var inner := PanelContainer.new()
	inner.add_theme_stylebox_override("panel", face)
	_ui.campaign_panel.add_child(inner)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 10)
	inner.add_child(col)

	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 10)
	col.add_child(head)

	var dot := ColorRect.new()
	dot.color = _ui.C_ACCENT
	dot.custom_minimum_size = Vector2(14, 14)
	dot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	head.add_child(dot)

	var head_txt := Label.new()
	head_txt.text = "选择势力"
	head_txt.add_theme_font_size_override("font_size", 26)
	head_txt.add_theme_color_override("font_color", _ui.C_HEAD)
	head_txt.mouse_filter = Control.MOUSE_FILTER_IGNORE
	head.add_child(head_txt)

	var hint := Label.new()
	hint.text = "←/→ 或 A/D 换边 · Enter 确定 · Esc 取消"
	hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	hint.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override("font_size", 15)
	hint.add_theme_color_override("font_color", _ui.C_HINT)
	hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	head.add_child(hint)

	var body := HBoxContainer.new()
	body.alignment = BoxContainer.ALIGNMENT_CENTER
	body.add_theme_constant_override("separation", 36)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(body)
	body.add_child(_make_faction_slot(CAMPAIGN_CAO))
	body.add_child(_make_faction_slot(CAMPAIGN_LIU))

	var foot := HBoxContainer.new()
	foot.alignment = BoxContainer.ALIGNMENT_CENTER
	foot.add_theme_constant_override("separation", 24)
	col.add_child(foot)
	foot.add_child(ports._gold_button("确定", 200.0, 46.0, 22, ports._on_campaign_confirm))
	foot.add_child(ports._gold_button("取消", 200.0, 46.0, 22, ports._on_back))

	# 红箭头：Polygon2D 是 Node2D，容器不碰它 → 挂在根上按全局坐标自己摆。
	# 放在 campaign_panel 之后（并给 z_index）保证画在面板之上。
	_ui.campaign_cursor = Polygon2D.new()
	_ui.campaign_cursor.color = _ui.C_ACCENT
	_ui.campaign_cursor.polygon = PackedVector2Array([
		Vector2(-22.0, 2.0), Vector2(22.0, 2.0), Vector2(0.0, 28.0),
	])
	_ui.campaign_cursor.z_index = 20
	_ui.campaign_cursor.visible = false
	surface.add_child(_ui.campaign_cursor)

func _set_title_visible(v: bool) -> void:
	if _ui.title_label != null:
		_ui.title_label.visible = v
	if _ui.subtitle_label != null:
		_ui.subtitle_label.visible = v

func _release_focus() -> void:
	var fo: Control = surface.get_viewport().gui_get_focus_owner()
	if fo != null:
		fo.release_focus()

func _portrait_status(camp: String) -> String:
	if not _ui.campaign_tex.has(camp):
		return "%s=missing" % camp
	var t: Texture2D = _ui.campaign_tex[camp]
	if t == null:
		return "%s=missing" % camp
	return "%s=%dx%d" % [camp, t.get_width(), t.get_height()]
