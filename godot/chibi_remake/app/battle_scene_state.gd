extends RefCounted
## Scene-owned services and nodes. No simulation rules.
const RemasterArt = preload("res://presentation/battle/art_catalog.gd")

const SaveSvc = preload("res://app/save_service.gd")    # ARCH-006：存档/读档编排

const View = preload("res://presentation/battle/battle_view.gd")        # ARCH-013：表现层（HUD/相机/单位外观/框选）


var saver: RefCounted = null                        # 需要宿主，所以在 _ready 里用 self 造

var cam: Camera2D
# info / panel_label / officer_portrait / end_label 已随 ARCH-013 搬到 battle_view.gd

var bgm: Node = null            # 战场 BGM

var sfx: Node = null            # 原版 WAVE.EXP 音效（选中/攻击）

var remaster_art := RemasterArt.new()

var view: Node2D = null                             # ARCH-013：表现层宿主（--simtest/--noview 时为 null）

var cheat_input_open := false

var hover_text := ""

var show_units := true

var show_buildings := true

var hud_acc := 0.0

var show_debug := false          # ARCH-011：工程信息默认不显示给玩家（F3 切换）
