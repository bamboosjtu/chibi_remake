extends Control
## Composition root; presentation components own their specific behavior.
const RemasterArt = preload("res://presentation/battle/art_catalog.gd")

const Textures = preload("res://presentation/battle/runtime_textures.gd")

# ── 「选择势力」这一步（2a 新增）：开始游戏 → 先问曹操/刘备，再列该线关卡 ──

const CAMPAIGN_CAO := "chibic"             # 左格：曹操（关卡 id 前缀也是它）

const CAMPAIGN_LIU := "chibil"             # 右格：刘备

const CAMPAIGN_IDS := ["chibic", "chibil"]

const CAMPAIGN_TITLE := {"chibic": "曹操线", "chibil": "刘备线"}

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

const ROW_H := 42                       # 木条行高

const ROW_GAP := 3                      # 木条之间的暗缝

const ROW_STEP := ROW_H + ROW_GAP

const ARROW_STEP := 135                 # ▲▼ 一次滚 3 行

# ── 调色板（原版是暗石头 + 木 + 金，这里全部按截图取近似色）──

var _ui = preload("res://presentation/menu/menu_state.gd").new()
var _components: Dictionary = {}
var _fields: Dictionary = {}
var _api_conflicts: Array = []
var _api_missing: Array = []
var media_view: CanvasLayer:
	get: return _ui.media_view
	set(value): _ui.media_view = value
var slots_dialog: CanvasLayer:
	get: return _ui.slots_dialog
	set(value): _ui.slots_dialog = value
var level_panel: PanelContainer:
	get: return _ui.level_panel
	set(value): _ui.level_panel = value
var level_face: PanelContainer:
	get: return _ui.level_face
	set(value): _ui.level_face = value
var level_scroll: ScrollContainer:
	get: return _ui.level_scroll
	set(value): _ui.level_scroll = value
var level_list: VBoxContainer:
	get: return _ui.level_list
	set(value): _ui.level_list = value
var level_back: Button:
	get: return _ui.level_back
	set(value): _ui.level_back = value
var title_label: Label:
	get: return _ui.title_label
	set(value): _ui.title_label = value
var toast: Label:
	get: return _ui.toast
	set(value): _ui.toast = value
var campaign_panel: PanelContainer:
	get: return _ui.campaign_panel
	set(value): _ui.campaign_panel = value
var campaign_cursor: Polygon2D:
	get: return _ui.campaign_cursor
	set(value): _ui.campaign_cursor = value
var scrim: ColorRect:
	get: return _ui.scrim
	set(value): _ui.scrim = value
var subtitle_label: Label:
	get: return _ui.subtitle_label
	set(value): _ui.subtitle_label = value
var level_title: Label:
	get: return _ui.level_title
	set(value): _ui.level_title = value
var level_hint: Label:
	get: return _ui.level_hint
	set(value): _ui.level_hint = value
var sb_row_a: StyleBoxFlat:
	get: return _ui.sb_row_a
	set(value): _ui.sb_row_a = value
var sb_row_b: StyleBoxFlat:
	get: return _ui.sb_row_b
	set(value): _ui.sb_row_b = value
var sb_row_hover: StyleBoxFlat:
	get: return _ui.sb_row_hover
	set(value): _ui.sb_row_hover = value
var sb_row_press: StyleBoxFlat:
	get: return _ui.sb_row_press
	set(value): _ui.sb_row_press = value
var sb_row_focus: StyleBoxFlat:
	get: return _ui.sb_row_focus
	set(value): _ui.sb_row_focus = value
var sb_gold: StyleBoxFlat:
	get: return _ui.sb_gold
	set(value): _ui.sb_gold = value
var sb_gold_hover: StyleBoxFlat:
	get: return _ui.sb_gold_hover
	set(value): _ui.sb_gold_hover = value
var sb_gold_press: StyleBoxFlat:
	get: return _ui.sb_gold_press
	set(value): _ui.sb_gold_press = value
var sb_gold_focus: StyleBoxFlat:
	get: return _ui.sb_gold_focus
	set(value): _ui.sb_gold_focus = value

func _init() -> void:
	for property in _ui.get_property_list(): _fields[property.name] = true
	_components["automation_driver"] = preload("res://presentation/menu/automation_driver.gd").new(_ui, self)
	_components["controller"] = preload("res://presentation/menu/controller.gd").new(_ui, self)
	_components["menu_styles"] = preload("res://presentation/menu/menu_styles.gd").new(_ui, self)
	_components["campaign_dialog"] = preload("res://presentation/menu/campaign_dialog.gd").new(_ui, self)
	_components["level_dialog"] = preload("res://presentation/menu/level_dialog.gd").new(_ui, self)
	var report := preload("res://composition_contract.gd").wire(_components, "menu")
	_api_missing = report.missing

func _get(key: StringName):
	if _fields.has(key): return _ui.get(key)
	return null

func _set(key: StringName, value) -> bool:
	if _fields.has(key): _ui.set(key, value); return true
	return false

func registry_abort() -> bool:
	return preload("res://composition_contract.gd").abort_if_broken("menu", _api_conflicts, _api_missing)

func _flat(bg: Color, border: Color, width: int, radius: int) -> StyleBoxFlat:
	return _components["menu_styles"]._flat(bg, border, width, radius)
func _bevel(bg: Color, rim: Color, dark: Color, rim_px: int, drop: int, radius: int, pad: Vector4) -> StyleBoxFlat:
	return _components["menu_styles"]._bevel(bg, rim, dark, rim_px, drop, radius, pad)
func _highlight(bg: Color, rim: Color, pad: Vector4) -> StyleBoxFlat:
	return _components["menu_styles"]._highlight(bg, rim, pad)
func _sunk(bg: Color, rim: Color, rim_px: int, radius: int, pad: Vector4) -> StyleBoxFlat:
	return _components["menu_styles"]._sunk(bg, rim, rim_px, radius, pad)
func _build_styles() -> void:
	_components["menu_styles"]._build_styles()
func _ready() -> void:
	# An ambiguous composition dispatches calls to the wrong component; never
	# build the menu on top of that. registry.gd already asserts in debug builds.
	if registry_abort(): return
	await _components["controller"]._ready()
func _notification(what: int) -> void:
	if what != Node.NOTIFICATION_WM_CLOSE_REQUEST: return
	_components["controller"]._notification(what)
func _build_level_dialog() -> void:
	_components["level_dialog"]._build_level_dialog()
func _make_arrow_button(glyph: String, delta: int) -> Button:
	return _components["level_dialog"]._make_arrow_button(glyph, delta)
func _make_level_row(d: Dictionary, chapter: int, alt: bool) -> Button:
	return _components["level_dialog"]._make_level_row(d, chapter, alt)
func _level_key(id: String) -> Array:
	return _components["level_dialog"]._level_key(id)
func _is_digit(ch: String) -> bool:
	return _components["level_dialog"]._is_digit(ch)
func _level_before(a: Dictionary, b: Dictionary) -> bool:
	return _components["level_dialog"]._level_before(a, b)
func _fill_level_list() -> void:
	_components["level_dialog"]._fill_level_list()
func _add_rows(arr: Array) -> void:
	_components["level_dialog"]._add_rows(arr)
func _campaign_title_text() -> String:
	return _components["level_dialog"]._campaign_title_text()
func _first_row() -> Button:
	return _components["level_dialog"]._first_row()
func _scroll_by(delta: int) -> void:
	_components["level_dialog"]._scroll_by(delta)
func _scroll_to(pos: int) -> void:
	_components["level_dialog"]._scroll_to(pos)
func _focus_row(n: int) -> void:
	_components["level_dialog"]._focus_row(n)
func _report_scroll_state() -> void:
	_components["automation_driver"]._report_scroll_state()
func _report_level_dialog() -> void:
	_components["automation_driver"]._report_level_dialog()
func _arrow_wiring(glyph: String) -> String:
	return _components["level_dialog"]._arrow_wiring(glyph)
func _unhandled_key_input(event: InputEvent) -> void:
	_components["controller"]._unhandled_key_input(event)
func _show_toast(msg: String) -> void:
	await _components["controller"]._show_toast(msg)
func _hide_toast() -> void:
	_components["controller"]._hide_toast()
func _on_start() -> void:
	_components["controller"]._on_start()
func _on_campaign_confirm() -> void:
	_components["controller"]._on_campaign_confirm()
func _on_back() -> void:
	_components["controller"]._on_back()
func _on_skirmish() -> void:
	_components["controller"]._on_skirmish()
func _on_history() -> void:
	_components["controller"]._on_history()
func _on_level(id: String) -> void:
	_components["controller"]._on_level(id)
func _on_load() -> void:
	_components["controller"]._on_load()
func _load_slot(slot: int, _title: String) -> void:
	_components["controller"]._load_slot(slot, _title)
func _campaign_alias(s: String) -> String:
	return _components["campaign_dialog"]._campaign_alias(s)
func _wood_frame(sel: bool, pad: int) -> StyleBoxFlat:
	return _components["menu_styles"]._wood_frame(sel, pad)
func _wood_plate() -> StyleBoxFlat:
	return _components["menu_styles"]._wood_plate()
func _gold_button(text: String, w: float, h: float, fs: int, cb: Callable) -> Button:
	return _components["menu_styles"]._gold_button(text, w, h, fs, cb)
func _load_portrait(camp: String) -> Texture2D:
	return _components["campaign_dialog"]._load_portrait(camp)
func _make_faction_slot(camp: String) -> Control:
	return _components["campaign_dialog"]._make_faction_slot(camp)
func _on_slot_input(event: InputEvent, camp: String) -> void:
	_components["campaign_dialog"]._on_slot_input(event, camp)
func _set_campaign(camp: String, refresh: bool) -> void:
	_components["campaign_dialog"]._set_campaign(camp, refresh)
func _move_campaign(d: int) -> void:
	_components["campaign_dialog"]._move_campaign(d)
func _refresh_campaign_cursor() -> void:
	_components["campaign_dialog"]._refresh_campaign_cursor()
func _build_campaign_dialog() -> void:
	_components["campaign_dialog"]._build_campaign_dialog()
func _set_title_visible(v: bool) -> void:
	_components["campaign_dialog"]._set_title_visible(v)
func _release_focus() -> void:
	_components["campaign_dialog"]._release_focus()
func _portrait_status(camp: String) -> String:
	return _components["campaign_dialog"]._portrait_status(camp)
func _report_campaign_dialog() -> void:
	_components["automation_driver"]._report_campaign_dialog()
func _count_rows() -> int:
	return _components["automation_driver"]._count_rows()
func _push_key(code: int) -> void:
	await _components["automation_driver"]._push_key(code)
func _run_keytest() -> void:
	await _components["automation_driver"]._run_keytest()
func _mouse_click_point_for(target: String) -> Dictionary:
	return _components["automation_driver"]._mouse_click_point_for(target)
func _find_gold_button(text: String) -> Button:
	return _components["automation_driver"]._find_gold_button(text)
func _push_mouse_click(point: Vector2) -> void:
	await _components["automation_driver"]._push_mouse_click(point)
func _run_mouse_matrix() -> void:
	await _components["automation_driver"]._run_mouse_matrix()
func _mouse_click_slot(idx: int) -> void:
	await _components["automation_driver"]._mouse_click_slot(idx)
func _run_mouse_click(target: String) -> void:
	await _components["automation_driver"]._run_mouse_click(target)

func _exit_tree() -> void:
	for component in _components.values(): component.ports.disconnect_services()
	_components.clear()
	for property in _ui.get_property_list():
		var value = _ui.get(property.name)
		if value is Array or value is Dictionary: value.clear()
