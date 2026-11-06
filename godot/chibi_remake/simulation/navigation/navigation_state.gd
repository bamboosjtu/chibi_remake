extends RefCounted
## Shared navigation grids and occupancy.
const UnitFootprint = preload("res://simulation/systems/unit_footprint.gd")

var tile_w := 44.0              # 来自 map_data.tileW

var tile_hw := 22.0

var tile_hh := 11.0

var map_data: Dictionary = {}

var astar := AStar2D.new()
## 水面层（2026-10-17 水战批次）：同一套格坐标，另一张 AStar2D。
## 水面格 = `waterWalkable[i] == 1`（MED ground set ∈ {3,4}，见 tools/lib/water_grid.mjs）。
## 水军/运输船（46/47/48/49/52）在这一层寻路；陆军仍走 `astar`（默认层 0）。

var water_astar := AStar2D.new()

var has_water := false

var occupancy := {}

var version := 0                  # REQ-003：阻挡版本——动态占地变更即递增（路径失效依据）

var gates: Array = []

var gate_cells: Dictionary = {}

var blocked_cells: Dictionary = {}
## Resource cells override the MED's original solid flag: live crops/trees block,
## harvested remnants become floor. This state survives building-grid rebuilds.

var resource_cells: Dictionary = {}

var _route_owner := -1

var _planning_gates := false
## R04：多格单位（车兵/骑兵/舰船）按**整块占格**寻路。每层每占格档一张按需建立的
## AStar2D（点/邻接照抄基础图，只把“身体放不下”的锚点禁用）；occupancy/封格/城门变化
## 只标记受影响的锚点，查询前增量刷新，避免每次全图重算。

var _shape_graphs := {}

var _shape_pending := {}

# ------------------------------------------------------------------- setup ----
## 取瓦片尺寸并建立 A* 网格。main.gd 在 _ready 里调一次。
