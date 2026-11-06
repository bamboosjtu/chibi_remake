extends RefCounted
## Presentation-owned node references and interaction state.
const HudMetrics = preload("res://presentation/hud/hud_metrics.gd")

const CMD_PAGE := 6

var chrome: Control

var worker_button: Button

var join_button: Button

var command_catalog = preload("res://presentation/hud/command_catalog.gd").new()

var command_panel := {}

var _hot_pressed := -1

var _hot_keycode := 0

var _hud_press_cancelled := false

var _minimap_drag := false

var classic_panel: Control

var briefing: CanvasLayer

var opening_pending := false

var _motion_previous := {}

var _gait_previous := {}

var battle_menu: CanvasLayer

var projectile_view: Node2D

var construction_preview: Node2D

var resource_layer: Node2D

var hud_metrics = HudMetrics.new()   # REQ-006：唯一战场矩形（布局写回，夹边/小地图/滚屏消费）

var host: Node2D                  # main.gd

var cam: Camera2D

var info: Label                   # 左下状态行第一行（原版「训练完成」的位置）

var panel_label: Label            # 右面板底部的属性文字

var end_label: Label

var officer_portrait: TextureRect

var ui_layer: CanvasLayer

# ------------------------------------------------- HUD 2.0 节点（全在 build_ui 里建）----
# 这些节点只在 view 存在时创建：--simtest / --noview 下一个都不建（ARCH-013 验收）。

var top_bar: ColorRect            # 顶栏（通栏）

var bar_edge: ColorRect           # 顶栏下沿金褐细线

var res_slots: Array = []         # 4 个资源槽：[{panel, icon, value, kind}]

var banner: Panel                 # 顶中红匾

var banner_label: Label

var right_panel: ColorRect        # 右侧竖排底板（钉右边缘）

var minimap_box: Panel

var minimap: Control

var fog_sprite: Sprite2D

var sel_frame: Panel              # 选中对象头像框

var sel_portrait: TextureRect

var sel_name: Label

var sel_rank: Label

var hp_bg: ColorRect

var hp_fill: ColorRect

var troop_frame: Panel            # 兵力 / 武将牌

var troop_icon: TextureRect

var troop_label: Label

var cmd_title: Label

var cmd_hint: Label

var cmd_buttons: Array = []       # 按钮池（复用，不每帧新建）

var cmd_actions: Array = []       # 每个按钮槽当前绑定的 Callable

var cmd_view: Array = []          # 每个按钮槽当前是否为"可见且可用"
# REQ-005（review.md R-05）：命令视图模型分页——六槽全部留给动作；
# 分页器独立成脚行；子菜单的返回是固定按钮，业务动作数量不再由绘制槽位决定。

var cmd_capsules: Array = []      # 完整动作清单（_apply_cmd_specs 收到的全部 specs）

var cmd_page := 0

var cmd_page_count := 1

var cmd_spec_sig := ""            # 清单变化才回第 1 页（10Hz 刷新不能把页码打回去）

var cmd_prev: Button

var cmd_next: Button

var cmd_page_label: Label

var back_button: Button

var event_view: CanvasLayer

var completion: CanvasLayer

var _hud_panel_capture := false

var hot_buttons: Array = []       # 左缘 1..10：[{btn, pip}]

var hot_actions: Array = []

var status_sub: Label             # 状态行第二行（关卡/计数）

var ornament: Control             # 右下装饰（自绘）

var ui_scale: float = 1.0

var _vp_cache := Vector2.ZERO

var _icons_real: int = 0          # 真正用上原版图标的槽数（报告/自检用）

var _click_probe: int = 0         # --hud-click 取证：pressed 信号计数

var _hud_press_pool: String = ""  # 当前被按下的 HUD 按钮（"cmd" / "hot"）

var _hud_press_idx: int = -1

# --- 原版 HUD 素材（BMP.LWC 提取，工具 tools/hd/hud_export.mjs；缺图自动回退平色绘制）---

var _topbar_original := false     # 顶栏是否走原版素材模式（=四簇纹理齐全）

var bar_tile_tex: TextureRect     # 顶栏中段平铺条

var top_left_tex: TextureRect     # 顶栏左簇（槽 1/2）

var top_right_tex: TextureRect    # 顶栏右簇（槽 3/4）

var banner_tex: TextureRect       # 红匾（"赤壁" 已烘焙在纹理里）

var left_strip_tex: TextureRect   # 左缘条背景

var btn_special_tex: TextureRect  # 左缘顶部功能钮（真机截图，原版为程序绘制）

var btn_next_tex: TextureRect     # 左缘 ▶ 翻页钮（真机截图）

var panel_bg_tex: TextureRect     # 右侧面板背景

var bottom_tex: TextureRect       # 底缘条

var res_value_labels: Array = []  # 原版模式下 4 个资源数字 Label

# 原版取色（真机截图 boot_002.png 逐点量出来的，见 _work/tmp/iconid/）

var c_bar_bg := Color(0.0, 0.0, 0.235)          # 海军蓝 RGB(0,0,60)

var c_bar_edge := Color(0.557, 0.396, 0.11)     # 金褐 RGB(142,101,28)

var c_text := Color(0.95, 0.95, 0.95)

var c_dim := Color(0.70, 0.64, 0.48)

var c_gold := Color(0.95, 0.85, 0.55)

var c_red := Color(0.635, 0.0, 0.0)             # 匾额红 RGB(162,0,0)

var c_panel_bg := Color(0.184, 0.11, 0.02, 0.93)  # 织锦底 RGB(73,44,0) 调暗

var c_panel_edge := Color(0.62, 0.44, 0.15)

var c_mini_bg := Color(0.02, 0.02, 0.02, 0.96)

var c_btn := Color(0.24, 0.24, 0.26)

var c_ok := Color(0.25, 0.85, 0.30)

var c_no := Color(0.45, 0.08, 0.08)

var _ui_cache: Dictionary = {}

var _skin = preload("res://presentation/hud/battle_skin.gd").new()

var art_panel: Control = null

var art_atlas: Texture2D = null

var art_buttons: Array = []          # [{btn: TextureRect, sub: String, idx: int}]

var art_actions: Array = []          # 与 art_buttons 平行

var art_sub: String = ""             # 当前打开的子菜单（"hot" 计谋 / "form" 列阵）

var art_back: TextureRect = null

var art_tip: Label = null            # 悬停提示（原版：悬停才显示文字）

var _art_hover_name: String = ""

var _panel_sig: String = ""          # 当前面板分型（"worker"/"combat"/""）

var build_menu := false              # 建造子菜单（高清图标分页，条目来自 host.build_types）

## 按研究中的将本体、成员、未编组三层规则分型。
## 建筑选择走文字面板（生产/建造菜单），不占用图标格位。

var officer_pick := false

## 组建：把该武将指派给选中的部队（走 main._order_form_up，与自检同一条路）

var zoom_override := 0.0     # >0 = --zoom= 给的测试覆盖值

var sheet_tex := {}          # 图集路径 -> Texture2D（渲染资产缓存，模拟不需要）

var sel_box_fill: ColorRect

var sel_box_line: Line2D

## B3：填充与描边同父，而且必须挂**世界空间** —— 挂到 CanvasLayer 会变成屏幕空间，
## 相机一动框就跟画面错位。ARCH-013：它们现在挂在 view（Node2D）下，与原先挂 main 下等价。

var _nodes_by_uid: Dictionary = {}
