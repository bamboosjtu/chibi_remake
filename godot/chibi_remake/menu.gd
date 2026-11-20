extends Control
## Composition root; presentation components own their specific behavior.


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
var controller: Object
var menu_styles: Object
var campaign_dialog: Object
var level_dialog: Object
var automation_driver: Object
var _disposed := false
var _fields: Dictionary = {}
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
	for field in _ui.PROXY_FIELDS: _fields[field] = true
	var probe := Array(OS.get_cmdline_user_args()).any(func(arg: String):
		return arg in ["--levels", "--screenshot", "--keytest", "--mousetest", "--mouseclick"] or arg.begins_with("--mouseclick="))
	if probe and Game.acceptance_enabled:
		automation_driver = load("res://testing/automation/menu_harness.gd").new(_ui, self)
	elif probe:
		push_error("Menu probes require the acceptance companion")
	controller = preload("res://presentation/menu/controller.gd").new(_ui, self)
	menu_styles = preload("res://presentation/menu/menu_styles.gd").new(_ui, self)
	campaign_dialog = preload("res://presentation/menu/campaign_dialog.gd").new(_ui, self)
	level_dialog = preload("res://presentation/menu/level_dialog.gd").new(_ui, self)
	var components := _owned_components()
	for component in components.values():
		if component != null and component.has_method("bind_dependencies"): component.bind_dependencies(self)
	var report := preload("res://composition_contract.gd").wire(components, "menu")
	_api_missing = report.missing

func _get(key: StringName):
	if _fields.has(key): return _ui.get(key)
	preload("res://property_contract.gd").reject(self,key)
	return null

func _set(key: StringName, value) -> bool:
	if _fields.has(key): _ui.set(key, value); return true
	preload("res://property_contract.gd").reject(self,key)
	return false

func contract_abort() -> bool:
	return preload("res://composition_contract.gd").abort_if_broken("menu", _api_missing)

func _ready() -> void:
	if Game.acceptance_enabled and "--full-battle-bench" in OS.get_cmdline_user_args():
		get_tree().root.add_child.call_deferred(load("res://testing/benchmark/full_battle_benchmark.gd").new())
		queue_free();return
	# An ambiguous composition dispatches calls to the wrong component; never
	# build the menu on top of that. Contract rejection also runs in exported builds.
	if contract_abort(): return
	await controller._ready()
func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE and not _disposed: _dispose_components()
	if what != Node.NOTIFICATION_WM_CLOSE_REQUEST: return
	controller._notification(what)
func _unhandled_key_input(event: InputEvent) -> void:
	controller._unhandled_key_input(event)

func _dispose_components() -> void:
	if _disposed: return
	_disposed = true
	for component in _owned_components().values():
		if is_instance_valid(component): component.free()
	for property in _ui.get_property_list():
		var value = _ui.get(property.name)
		if value is Array or value is Dictionary: value.clear()


func _owned_components() -> Dictionary:
	var components := {
		"controller": controller,
		"menu_styles": menu_styles,
		"campaign_dialog": campaign_dialog,
		"level_dialog": level_dialog,
	}
	if automation_driver != null: components["automation_driver"] = automation_driver
	return components
