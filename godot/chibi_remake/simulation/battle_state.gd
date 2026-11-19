extends RefCounted
const PROXY_FIELDS := ["session", "effects", "units", "selected", "_officer_pool", "player_owner", "cheats_enabled", "auto_control", "cheat_build_any", "cheat_invulnerable", "cheat_reveal", "economy", "trainings", "player_tech", "research_jobs", "army_tech", "scenario_sides", "game_end", "clock", "_officer_initial_state", "nav", "visibility", "map_data", "map_id", "gold", "wood", "food", "stone", "projectiles", "fire_fields", "transports", "harvesting", "construction", "resource_revision", "sheet_by_unit", "train_types", "build_types", "next_uid", "_cell_index", "_cell_index_cell", "_cell_index_layer", "_cell_index_cells", "_index_unit_id", "_foot_cache", "_targets", "_target_owner", "_index_units_ref", "_index_units_size", "cnt_player", "cnt_enemy", "tile_w", "tile_hw", "tile_hh", "scenario_source", "scenario_mission", "scenario_avi", "ai", "ai_res", "sim_acc", "simulation_rng", "sim_tick", "simtest_seconds", "cnt_enemy_buildings", "task_latches", "terrain_changes", "terrain_base", "officer_progress", "rules", "task_events", "objective_done", "officer_policy", "cli_mode", "command_rules", "stratagems", "jimou_pending", "jimou_caster", "duel_pending", "cmd_pending", "cmd_pending_data", "decor_targets", "decor_cells", "control_groups", "automatic_gates", "player_commands"]
## Single owner of battle data. No scene nodes or rendering handles.
const CombatRules = preload("res://simulation/systems/combat_rules.gd")
const OFFICER_BLOCK_FOR_OWNER = preload("res://simulation/battle_config.gd").OFFICER_BLOCK_FOR_OWNER
const GRID_FALLBACK = preload("res://simulation/battle_config.gd").GRID_FALLBACK
const SPEED = preload("res://simulation/battle_config.gd").SPEED
const HUD_HZ = preload("res://simulation/battle_config.gd").HUD_HZ
const Nav = preload("res://simulation/navigation/nav.gd")
const SIM_HZ = preload("res://simulation/battle_config.gd").SIM_HZ
const SIM_DT = preload("res://simulation/battle_config.gd").SIM_DT
const SIM_MAX_CATCHUP = preload("res://simulation/battle_config.gd").SIM_MAX_CATCHUP
const Progression = preload("res://simulation/systems/officer_progression.gd")
const PRODUCE_BY_BUILDING = preload("res://simulation/battle_config.gd").PRODUCE_BY_BUILDING
const RESOURCE_YIELD = preload("res://simulation/battle_config.gd").RESOURCE_YIELD
const FOOD_BUILDINGS = preload("res://simulation/battle_config.gd").FOOD_BUILDINGS
const STOCK_UNITS = preload("res://simulation/battle_config.gd").STOCK_UNITS
const JIMOU_NAMES = preload("res://simulation/battle_config.gd").JIMOU_NAMES
const JIMOU_SIDE = preload("res://simulation/battle_config.gd").JIMOU_SIDE
const JIMOU_LV_MASK = preload("res://simulation/battle_config.gd").JIMOU_LV_MASK
const FORM_NAMES = preload("res://simulation/battle_config.gd").FORM_NAMES
const FORM_OFFSETS = preload("res://simulation/battle_config.gd").FORM_OFFSETS
const GATHER_REACH = preload("res://simulation/battle_config.gd").GATHER_REACH
const VISION_SCALE = preload("res://simulation/battle_config.gd").VISION_SCALE
const EDGE_DISTANCE = preload("res://simulation/battle_config.gd").EDGE_DISTANCE
const DEPOSIT_EDGE_PX = preload("res://simulation/battle_config.gd").DEPOSIT_EDGE_PX
const SCRIPTED_OBJECTIVES = preload("res://simulation/battle_config.gd").SCRIPTED_OBJECTIVES
const SCRIPTED_EVENT_MISSIONS = preload("res://simulation/battle_config.gd").SCRIPTED_EVENT_MISSIONS
const SPECIAL_OBJECTIVE_MISSIONS = preload("res://simulation/battle_config.gd").SPECIAL_OBJECTIVE_MISSIONS
var session = preload("res://simulation/session_state.gd").new()
var effects = preload("res://simulation/battle_effects.gd").new()
var units: Array = []

var selected: Array:
	get: return session.selected
	set(value): session.selected = value

var _officer_pool: Array = [[], [], [], []]   # DATA.EXP 第 5 段的 4 个阵营块

var player_owner := 2

# research/meta: only auto_control is persisted; the other switches belong to this battle.
var cheats_enabled: bool:
	get: return session.cheats_enabled
	set(value): session.cheats_enabled = value
var auto_control := false
var cheat_build_any: bool:
	get: return session.cheat_build_any
	set(value): session.cheat_build_any = value
var cheat_invulnerable: bool:
	get: return session.cheat_invulnerable
	set(value): session.cheat_invulnerable = value
var cheat_reveal: bool:
	get: return session.cheat_reveal
	set(value): session.cheat_reveal = value

var economy: RefCounted

var trainings: Array = []

var player_tech := {
	"level": 0, "bow": 0, "weapon": 0, "armor": 0,
	"catapult": 0, "ship_atk": 0, "ship_def": 0,
}


var research_jobs: Array = []

var army_tech := {}

var scenario_sides: Array = []

var game_end := 0

var clock = preload("res://simulation/systems/battle_clock.gd").new()



## HUD 提示（几秒后自动消失）。main 仍保留同名方法，行为一致。

var _officer_initial_state: Dictionary = {}

var nav := Nav.new()                                # 拥有 AStarGrid2D 与瓦片尺寸（tile_w/tile_hw/tile_hh）

var visibility = preload("res://simulation/systems/battle_visibility.gd").new()

var map_data: Dictionary = {}

var map_id := "chibic1"










var gold := 3000.0

var wood := 1000.0

var food := 2000.0

var stone := 800.0

var projectiles: RefCounted

var fire_fields: RefCounted

var transports: RefCounted

var harvesting: RefCounted

var construction: RefCounted

var resource_revision := 0

var sheet_by_unit := {}

var train_types: Array = []

var build_types: Array = []     # 玩家可造建筑（与 AI 共用计划项表）

var next_uid := 0               # 稳定的单位序号，存档用它配对
# R13：非建筑单位的格位占用索引（layer -> cell -> {uid: unit}）+ 单位形状缓存。
# 每 tick 的防叠/落点查询从 O(全体单位) 降为 O(身体格数)；位置变化经 _place_unit 增量同步。

var _cell_index := {}

var _cell_index_cell := {}

var _cell_index_layer := {}

var _cell_index_cells := {}

var _index_unit_id := {}          # 组建会改变兵种 → 形状档可能变化，必须重收索引

var _foot_cache := {}
# R13：索敌按归属分桶（owner -> {uid: unit}），箭楼每 tick 只遍历敌对归属，
# 不再为每座塔扫描全体单位（chibic13 静止场景的主要剩余开销）。

var _targets := {}

var _target_owner := {}
## 索引与 units 数组的一致性哨兵：测试/夹具会整体替换 units，查询时自动重建。

var _index_units_ref: Array = []

var _index_units_size := 0


var cnt_player := 0

var cnt_enemy := 0
# ARCH-006：瓦片尺寸的**所有者是 nav.gd**（它要拿它做坐标换算）。
# 这里只做只读转发，所以 _make_unit / _step_unit / 相机等调用点一行都不用改。

var tile_w: float:
	get:
		return nav.state.tile_w

var tile_hw: float:
	get:
		return nav.state.tile_hw

var tile_hh: float:
	get:
		return nav.state.tile_hh
# ARCH-007 / #5：本关规则来源。prototype = 未在 BATTLE.EXP 中找到，必须显式标注，
# 不能把原型规则冒充成原版规则。

var scenario_source := "prototype"

var scenario_mission := -1

var scenario_avi := ""
# ARCH-010：固定模拟步长。表现层用真实 delta，**模拟**用固定 tick，
# 这样帧率（30/60/144）不会改变同一命令序列的结束状态。

var ai: RefCounted = null       # ARCH-006：电脑势力决策已抽到 ai.gd

var ai_res := {}                # owner -> {gold,wood,food,stone}（电脑势力各有各的钱）

var sim_acc := 0.0

var simulation_rng := RandomNumberGenerator.new()

var sim_tick := 0

var simtest_seconds: float:
	get: return session.simtest_seconds
	set(value): session.simtest_seconds = value

var cnt_enemy_buildings := 0   # ARCH-011 调试面板用

var task_latches := {}

var terrain_changes := {}

var terrain_base: Array = []

var officer_progress := {}

var rules: RefCounted = null

var task_events: Array = []

var objective_done := false     # 脚本目标是否已达成（CB.EXE FUN_00404800）


var officer_policy := "none"     # ARCH-008：battle.exp = 用战役表点名；prototype = 启发式

var cli_mode: bool:
	get: return session.cli_mode
	set(value): session.cli_mode = value

# ------------------------------------------------------------------- setup ----

var command_rules: RefCounted

var stratagems: RefCounted

var jimou_pending: int:
	get: return session.jimou_pending
	set(value): session.jimou_pending = value

var jimou_caster: Dictionary:
	get: return session.jimou_caster
	set(value): session.jimou_caster = value

var duel_pending: bool:
	get: return session.duel_pending
	set(value): session.duel_pending = value

## 待选目标的命令（原版 UI 模型：**先点面板按钮，再点地图目标**，随后命令块带上目标下发）。
## 与 jimou_pending / duel_pending 同一套模型；`cmd_pending_kind()` 给出当前待选命令。

var cmd_pending: String:
	get: return session.cmd_pending
	set(value): session.cmd_pending = value

var cmd_pending_data: Dictionary:
	get: return session.cmd_pending_data
	set(value): session.cmd_pending_data = value

var decor_targets: Array = []          # 全部饰物伪对象（载入时一次性构建）

var decor_cells: Dictionary = {}       # "行_列" → 伪对象（按格命中）

var control_groups := {}


var automatic_gates = preload("res://simulation/navigation/automatic_gates.gd").new()


var player_commands: RefCounted
