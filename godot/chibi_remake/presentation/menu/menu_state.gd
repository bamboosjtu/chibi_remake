extends RefCounted
const PROXY_FIELDS := ["media_view", "slots_dialog", "level_panel", "level_face", "level_scroll", "level_list", "level_back", "title_label", "main_buttons", "toast", "toast_serial", "row_parity", "campaign_panel", "campaign_cursor", "campaign_slots", "campaign_frames", "campaign_tex", "campaign_choice", "campaign", "scrim", "subtitle_label", "level_title", "level_hint", "C_FACE", "C_FACE_IN", "C_GROOVE", "C_BEVEL", "C_HEAD", "C_HINT", "C_ACCENT", "C_WOOD_A", "C_WOOD_B", "C_WOOD_RIM", "C_WOOD_DARK", "C_WOOD_HOVER", "C_WOOD_HOVER_RIM", "C_WOOD_PRESS", "C_WOOD_TXT", "C_GOLD", "C_GOLD_HOVER", "C_GOLD_PRESS", "C_GOLD_RIM", "C_GOLD_DARK", "C_GOLD_TXT", "sb_row_a", "sb_row_b", "sb_row_hover", "sb_row_press", "sb_row_focus", "sb_gold", "sb_gold_hover", "sb_gold_press", "sb_gold_focus"]
## Presentation-owned node references and interaction state.
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

var media_view:CanvasLayer

var slots_dialog: CanvasLayer
# 主菜单 — 复刻原版布局（书桌/茶壶/书卷背景 + 居中五木牌）
# 木牌坐标取自原版实拍 boot_001（归一化：x=0.5 居中，y 依次 0.575/0.669/0.764/0.857/0.951）
#
# 本轮重做：关卡选择不再是「一屏塞 34 个默认主题按钮」的调试列表，
# 改成原版「读取进度」那种模态对话框：
#   外框   深青灰石面 + 3px 浅色倒角 + 投影；内层再嵌一圈暗槽 = 凹面
#   标题行 面板左上角，前置一个 14x14 红方块（ColorRect）
#   列表   一列木条行，行与行之间 3px 暗缝（面板底色透出来就是木缝）
#   右侧   金色凸起 ▲▼ 两个小按钮翻页（和底部按钮同一套样式）
#   底栏   金色凸起按钮「返回」，暗色字
#
# 为什么是一列 + 分节，不是两列：
#   `CHIBIL16  「二旬进犯」  50 对象` 这种行两列后每列只剩 ~370px，中文关名会挤成一团；
#   一列（~770px）能保证整行不被截断。34 行装不下一屏，所以按原版的两条线分节
#   （CHIBIC* = 曹操线 / CHIBIL* = 刘备线），再加限高滚动 + ▲▼ 翻页。
#
# 为什么全是色块：
#   res:// 里没有任何 UI 贴图（也不许新增引用），木纹和金属面只能用
#   StyleBoxFlat 的底色 + 上/左亮边 + shadow_offset 压出的暗底边凑出立体感。
#   ⚠ 这是平色近似，不是真的木纹/金属材质。
#
# ── 本轮（2a / 2b / 2c）──
#   2a 「开始游戏」不再直接甩出 34 关的大列表，先弹「选择势力」：
#      左曹操 / 右刘备两块大立绘（059 / 039 已有的官员像）+ 木框 + 木名牌
#      + 金凸「确定 / 取消」+ 红箭头（Polygon2D）标出选中边。
#      ← / → 或 A/D 换边 · Enter 确定 · Esc 取消；确定后只列该线关卡。
#   2b 关卡对话框改成**几何居中**（原来是 anchor_top=0.39，停在标题下面）。
#      居中就必然压到「赤壁之战」→ 加整屏压暗遮罩 scrim + 开框时把标题/副标题收掉，
#      让重叠读起来是有意的模态而不是排版事故。
#      自检里三条一起看：centred=true / title_shown=false / overlap_title=false。
#   2c 行文本 `CHIBIC1  「侦察新野」  37 对象` → `第N章 侦察新野`
#      （N = 该关在本线自然序里的 1-based 位置），地图 id 和对象数全部不显示；
#      势力已经选过 → 分节头取消，「曹操线 · 选择关卡」升成对话框标题。
#
# 验证钩子：--levels（默认曹操线，可加 --campaign=cao|liu 换线）
#           · --campaign（只把「选择势力」摊开）· --scroll= / --focus= / --scrollby=
#           · --screenshot（--shot=<路径> 指定落盘文件）· --keytest（合成按键走真输入流验键盘路径）
#           · --mouseclick=slotL|slotR|slot0|slot1|outside|x,y（合成鼠标，走真 GUI 命中）
#           · --mousetest（完整点击矩阵：选边/重复点/Esc/Enter/外部/金凸按钮）
#           · --map=CHIBIC1 直入关卡 —— 原样保留，没动
#
# 保留的既有行为：
#   - 点某一行 → _on_level(id)（写 Game.current_map 后切 main.tscn）
#   - 「返回」→ _on_back()；面板在按「开始游戏」之前一直隐藏
#   - 列表仍然来自 Game.list_levels()，没有改动任何其它文件的契约
#
# 保留的上一轮修复：
#   - toast 2.6 秒后自动消失（用序号防止被新提示覆盖后误隐藏）
#   - 关卡按钮重建前先 remove_child 再 queue_free，不会重复堆叠
#   - 截图等 frame_post_draw 再取图（R5）

var level_panel: PanelContainer = null  # 模态外框（石面 + 倒角）

var level_face: PanelContainer = null   # 内层凹面

var level_scroll: ScrollContainer = null

var level_list: VBoxContainer = null    # 一列木条行 + 分节标题

var level_back: Button = null

var title_label: Label = null           # 只用于「面板有没有压住标题」的自检打印

var main_buttons: Array = []

var toast: Label = null

var toast_serial := 0

var row_parity := 0                     # 木条深浅交错用

var campaign_panel: PanelContainer = null  # 势力选择模态框

var campaign_cursor: Polygon2D = null      # 红色箭头（Polygon2D；Node2D 不受容器摆布，自己按全局坐标摆）

var campaign_slots: Array = []             # 两个势力格（普通 Control，整格可点）

var campaign_frames: Array = []            # 对应的木框 PanelContainer（选中时换红边）

var campaign_tex: Dictionary = {}          # camp -> Texture2D（只放加载成功的，不放 null）

var campaign_choice := "chibic"            # 当前高亮的势力（左=曹操 右=刘备）

var campaign := ""                         # 已确定的势力；"" = 还没选，这时不该开列表

var scrim: ColorRect = null                # 对话框后面的压暗遮罩（2b）

var subtitle_label: Label = null           # 开对话框时连副标题一起压掉

var level_title: Label = null              # 对话框标题（2c：曹操线 · 选择关卡）

var level_hint: Label = null               # 标题右侧操作提示

var C_FACE := Color("2b3138")           # 外框石面

var C_FACE_IN := Color("343b43")        # 内层凹面

var C_GROOVE := Color("12161a")         # 凹槽暗线

var C_BEVEL := Color("9aa6b0")          # 浅色倒角

var C_HEAD := Color("ece5d6")           # 面板标题字

var C_HINT := Color("98a2a9")           # 提示字

var C_ACCENT := Color("b4342a")         # 红方点

var C_WOOD_A := Color("8a6134")         # 木条（深）

var C_WOOD_B := Color("7d5730")         # 木条（浅一档）

var C_WOOD_RIM := Color("b58a51")       # 木条上亮边

var C_WOOD_DARK := Color("33200e")      # 木条下暗边

var C_WOOD_HOVER := Color("c99a52")     # 悬停/聚焦（比木条底色亮一档，暗字仍然压得住）

var C_WOOD_HOVER_RIM := Color("f2d99b")

var C_WOOD_PRESS := Color("5d3f1f")

var C_WOOD_TXT := Color("241505")       # 木条上的暗字

var C_GOLD := Color("c9a24a")           # 金色按钮面

var C_GOLD_HOVER := Color("e2c069")

var C_GOLD_PRESS := Color("a5842f")

var C_GOLD_RIM := Color("f6e7b4")       # 上/左亮边

var C_GOLD_DARK := Color("4a3410")      # 底边阴影

var C_GOLD_TXT := Color("2b1d08")       # 金色按钮上的暗字

# 共享的样式盒：34 行共用同一批，不用造 136 个

var sb_row_a: StyleBoxFlat = null

var sb_row_b: StyleBoxFlat = null

var sb_row_hover: StyleBoxFlat = null

var sb_row_press: StyleBoxFlat = null

var sb_row_focus: StyleBoxFlat = null

var sb_gold: StyleBoxFlat = null

var sb_gold_hover: StyleBoxFlat = null

var sb_gold_press: StyleBoxFlat = null

var sb_gold_focus: StyleBoxFlat = null

# ─────────────────────────────────────────────────────────────
# 样式盒工厂
# ─────────────────────────────────────────────────────────────

## 四边同宽的平板（石面、滚动条等）。
