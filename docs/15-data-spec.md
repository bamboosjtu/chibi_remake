# 15 数据规格

> 本章定义运行时 JSON 的字段、取值与文件职责。数值规则见各玩法章节；开局明细见[附录](reference/level-openings.md)。

## 1. 文件布局

| 路径 | 内容 |
|---|---|
| `data/<地图 ID>.json` | 一张地图：地形、通行、饰物、对象、类型定义、战役参数 |
| `data/db/unit_definitions.json` | 已核对的兵种属性；覆盖关卡内对应属性 |
| `data/db/production_units.json` | 生产兜底定义与权威费用，仅费用覆盖兵种属性表 |
| `data/db/officers.json` | 117 名武将 |
| `data/db/officer_progression.json` | 武将经验阈值、官职品级、53 类经验/士气奖励 |
| `data/db/command_variants.json` | 将本体、成员、未编组与运输船的面板分型 |
| `data/db/startup_briefings.json` | 34 关 MISSION.EXT 任务标题与开场白 |
| `data/db/commands.json` | 命令注册表、面板槽位、热键、图标帧 |
| `data/db/cursors.json` | 光标图集、热点、状态与动画 |
| `data/db/audio_index.json` | 122 条音频索引 |
| `data/db/events.json` | 事件 → 视频或文本 |
| `data/db/scenario_rules.json` | 8 个任务的条件与效果 |
| `data/db/registry_compatibility.json` | 存档内容版本的上/下兼容映射 |
| `data/db/video_catalog.json` | AVI 视频路径、尺寸、帧率、时长与 SHA256 |

- 关卡文件由 `tools/godot_export.mjs` 生成，并作为可运行的数据快照进入 Git；构建可用 `-SkipData` 复用现有文件。
- 数字在 JSON 中可能以浮点表示；读取时按字段语义转整数，键统一用字符串。
- 上述三份研究数据由根目录执行 `node tools/import_research_systems.mjs` 同步；游戏运行时无需访问 `research` 目录。

单位加载顺序固定为：关卡提供布局和素材；兵种表覆盖属性；生产表覆盖费用并补充缺失兵种。两个目录全部校验成功后才修改关卡定义。保留的关卡属性属于导出快照，不能改变运行时的覆盖顺序。`tools/inputs/schema/content.json` 规定目录与关卡结构，数据门禁还校验通行数组长度及对象类型引用。

## 2. 关卡文件

### 2.1 顶层

| 字段 | 类型 | 说明 |
|---|---|---|
| `name` | string | 关卡名 |
| `map` | string | 地图资源名（大写） |
| `kind` | string | 可选；存在时必须为 `level`（注册表校验用） |
| `scenario` | object | 战役参数（见 2.4） |
| `terrain` | string | 地形分块清单路径 |
| `terrainW` / `terrainH` | number | 世界像素尺寸 |
| `tileW` | number | 格宽（44） |
| `rows` / `cols` | number | 格坐标范围 |
| `walkable` | number[] | 地格通行表，长度 `rows × cols` |
| `terrainWalkable` | number[] | 运行时通行表（地形 + 静态建筑 + 饰物阻挡） |
| `waterWalkable` | number[] | 水面通行表；纯陆战图全 0 |
| `decor` | array | 饰物 `[行, 列, 相位]` |
| `objects` | array | 地图对象（见 2.2） |
| `units` | object | 类型 ID → 类型定义（见 2.3） |
| `navigation` | object | `schemaVersion`、`topology`、`occupancy` |
| `artMode` | string | 固定 `hd-catalog` |
| `note` | string | 生成说明 |

关卡注册校验要求：`terrainW/terrainH > 0`、`rows/cols > 0`、`objects/walkable` 为数组、`kind` 缺省或为 `level`。

### 2.2 地图对象

| 字段 | 类型 | 说明 |
|---|---|---|
| `sec` | number | 段号（= 归属，0–4） |
| `owner` | number | 归属 |
| `unit` | number | 类型 ID |
| `A` / `B` | number | 格坐标（行 / 列） |
| `C` | number | 保留 |
| `tail` | number[] | 尾部字段：部队为统辖武将编号，资源点为存量，其余为空 |
| `px` / `py` | number | 精灵左上角像素 |
| `w` / `h` | number | 精灵尺寸 |
| `sheet` | string | 图集路径 |

### 2.3 类型定义

`units[str(id)]` 的字段：

| 字段 | 说明 |
|---|---|
| `name` | 显示名 |
| `spriteName` | 素材名 |
| `w` / `h` | 精灵尺寸 |
| `frames` | `{first, count, cols}`：图集起始帧、总帧数、列数 |
| `clips` | 动作行：`turn/die/walk/act1/act2/act3` → 8 方向帧数组 |
| `f9` | 速率（0 按 100 处理） |
| `sheetK` | 图集缩放倍率 |
| `hp` | 基础生命 |
| `attack` / `attackB` | 攻击 A / B |
| `defence` / `defenceB` | 防御 A / B |
| `vision` | 视野（运行时 ×2） |
| `range` | 射程（格） |
| `mitig` / `mitig2` | 保留字段 |
| `building` | 是否建筑 |
| `costs` | 费用三元组（见 5.1） |
| `costStone` | 铁费用 |
| `expGain` / `moraleGain` | 被击杀时给击杀方的经验/士气 |
| `sheet` | 图集路径 |

### 2.4 战役参数

```json
"scenario": {
  "missionId": 17,
  "avi": "cao1.AVI",
  "sides": [
    {
      "owner": 3,
      "init": [0, 1, 1],
      "resources": [3000, 1000, 2000, 800],
      "roster": [67, 68, 90, 81],
      "ranks": [0, 0, 0, 0]
    }
  ]
}
```

| 字段 | 说明 |
|---|---|
| `missionId` | 任务号 0–33 |
| `avi` | 开场片名 |
| `sides[].owner` | 归属 |
| `sides[].init` | `[行为档位, 科技门槛, 信息面板变体]`（第三项为保留字段） |
| `sides[].resources` | 金、粮、木、铁 |
| `sides[].roster` | 武将全局索引 +1 |
| `sides[].ranks` | 档次，0 表示用默认等级 |

## 3. 数据库

### 3.1 生产单位

`production_units.json`：

```json
{ "units": { "30": { "name": "工人", "hp": 100, "costs": [400, 50, 50], "costStone": 0 } } }
```

- 顶层 `source` 为说明文本，运行时忽略。
- 该文件的 `costs`/`costStone` **覆盖**关卡类型表中的费用，是扣费的唯一口径。
- 共 17 条可生产单位定义（工人 30、民居产物 32、投石车 34、36–49 各兵种）。

### 3.2 武将

```json
{ "kind": "officerDatabase", "blocks": [
  { "faction": 1, "firstIndex": 0, "officers": [
    { "index": 0, "name": "甘  宁", "might": 93, "intellect": 67,
      "tier": 1, "level": 0, "heroType": 35, "heroTypeName": "骑将", "hp": 500 }
  ] }
] }
```

- `faction`：1 孙权、2 刘备、3 曹操、4 荆州。
- `tier`：1 骑、2 步、3 弓、4 文。
- `heroType`：29 文将、31 步将、33 弓将、35 骑将。
- `index` 全局唯一、从 0 起；关卡名单与地图尾部使用 **index + 1**。

### 3.3 命令

```json
{ "hotkeys": { "order": ["Q","W","E","A","S","D","Z","X","C"] },
  "panels": { "combat": { "slots": [16130, ...] }, "worker": { "slots": [...] } },
  "commands": [ { "command": 16130, "frame": 154, "name": "移动" } ],
  "runtimeActions": { "16130": "move" } }
```

- `panels.combat` / `panels.worker` 各 9 格，`null` 表示空格。
- `runtimeActions` 把命令 ID 映射到运行时动作名。
- `frame` 为图标帧号；图标图集见[美术规格](17-art.md)。

### 3.4 光标

| 字段 | 说明 |
|---|---|
| `banks` | A（10 状态 × 4 帧）、B（8 方向）、C（红旗 4 帧） |
| `banks[].hotspots` | 每行热点 |
| `sourceRows` | 各 bank 在纹理中的行边界 |
| `runtimeTextures` | bank → 运行纹理路径 |
| `timing` | 每帧 160 ms |

### 3.5 音频与事件

```json
{ "entries": [ { "id": 0, "name": "Record01.WAV", "kind": "music",
                 "file": "res://media/sfx/record01.wav",
                 "music": "res://media/music/record01.ogg" } ] }
```

```json
{ "events": { "1": { "video": "res://media/videos/EVENT1.AVI", "source": "event1.avi" },
              "4": { "text": "在长坂坡救回糜竺，经验增加。" } } }
```

### 3.6 任务规则

结构见[战役](11-campaign.md#5-任务与胜负)。条件与效果类型固定，未知类型忽略。

### 3.7 存档兼容表

```json
{ "previous": { "chibic1": "<旧内容哈希>" },
  "current":  { "chibic1": "<当前内容哈希>" } }
```

- 用于允许“上一版本内容哈希”的存档在新版本关卡上继续读取。
- 只匹配同一地图；不匹配时拒绝加载并保留原档。

## 4. 数值约定

| 项 | 约定 |
|---|---|
| 关卡资源数组 | 金、粮、木、铁 |
| HUD 资源栏 | 金、粮、木、铁 |
| 生产费用文本 | 金、粮、木、铁（只列非零项） |
| 研究费用文本 | 金、木、石、粮（只列非零项） |
| 单位类型 ID | 0–26 建筑与资源点，27–52 可动单位；50/51 云梯与 52 旗舰为保留类型，不可生产 |
| 归属 | 0 中立，1 孙权，2 刘备，3 曹操，4 荆州 |
| 武将索引 | 0 起；名单与地图尾部 +1 |
| 档次 | 0 用默认等级；>0 时等级 = 档次 − 1 |
| 品质列 | 步、骑、弓、文 |
| 坐标 | `(A 行, B 列)`；锚点像素按 10 章公式 |
| 时间 | 逻辑 tick（1/30 秒） |

## 5. 费用与资源

### 5.1 费用三元组

- 类型表 `costs` 在生产单位上的语义为 `[金, 木, 粮]`，与 `costStone` 一起构成四资源费用。
- `production_units.json` 覆盖关卡类型表，保证跨地图费用一致。
- 菜单、扣款、退款共用同一数据。

### 5.2 初始资源

- `scenario.sides[0].resources` 为玩家初始四资源；其余参战方由 AI 经济使用。
- 缺省地图（无战役数据）使用原型值：金 3000、粮 1000、木 2000、铁 800。

## 6. 内容哈希

存档保存 `contentRevision`，用于判断关卡内容是否变化。计算范围：

- 包含：`rows`、`cols`、`tileW`、`terrainW`、`terrainH`、`walkable`、`terrainWalkable`、`scenario`、`navigation`、`units`、`objects`，以及 `scenario_rules.json` 的哈希。
- 排除：`units[*].sheet`、`units[*].sheetK`、`objects[*].sheet`。

因此替换外观或打包路径不会使存档失效；改地形、通行、对象、战役参数或任务规则会使旧档失效（除非命中兼容表）。

## 7. 数据校验

| 文件 | 校验 |
|---|---|
| 关卡 | 必需字段与类型；`kind`；尺寸 > 0 |
| 生产单位 | 费用非负、有限 |
| 武将 | `index` 唯一、`tier` 1–4、`heroType` 29/31/33/35 |
| 命令/光标 | 槽位 9 格、帧号存在、热点数量与状态数一致 |
| 任务 | 条件/效果类型已知；矩形 4 元素；阶段 ID 唯一 |
| 存档 | 见 16 章 |

## 8. 实现对应

| 职责 | 模块/工具 |
|---|---|
| 关卡导出 | `tools/godot_export.mjs` |
| 关卡注册与校验 | `app/game.gd::is_level_doc`、`list_levels` |
| 类型与费用合并 | `app/battle/bootstrap.gd`（生产单位覆盖） |
| 武将库 | `simulation/battle/officer_pool.gd` |
| 命令与光标 | `presentation/hud/command_catalog.gd`、`software_cursor.gd` |
| 音频索引 | `presentation/audio/sfx.gd` |
| 任务数据 | `simulation/systems/scenario_rules.gd` |

## 9. 验收要点

- 34 个关卡文件全部通过注册校验；数据库文件不会被误认为关卡。
- 费用覆盖对所有地图一致；退款与扣款使用同一数据。
- 武将索引与名单 +1 规则一致；无重复索引。
- 内容哈希只覆盖模拟数据；换图集不使存档失效。
- 未知任务条件/效果不会导致崩溃。

`data/db/buildings.json` 覆盖原关卡建筑费用与已确认施工帧，不改变关卡内容校验值；`unit_display_layout.json` 只覆盖高清帧的采样区域和世界尺寸，保留动作时序与模拟状态。两者分别由 `tools/import_building_research.py` 和 `tools/hd/rebuild_unit_layout.py` 生成。

工人高清图页的行距不均匀，布局生成器按每列的透明间隔提取完整姿势，并校验姿势数量与页契约一致。空手、木材、矿物和粮食帧独立裁切，显示高度与脚底仍取源帧边界；不能先按等分网格裁切，否则会混入相邻搬运姿势或截断货物。

### 可选移动表现状态（兼容 v8 旧档）

每个机动单位可带 `walk_tick`、`move_facing`、`turn_tick`、`move_started`、`move_turning`。前三者是非负整数，朝向限制在 0–7；后两者是布尔值。恢复前验证类型与范围；旧档缺省为零时钟和当前路径朝向。它们不参与寻路、位移、攻防或胜负判定，只用于继续步态与转向，故不改变关卡内容哈希。

### 单位研究与可选计谋快照

`unit_definitions.json` 由 `tools/import_unit_research.py` 读取 research/units 的26种定义、动画与现有高清 manifest 生成；`unit_rules.gd` 只替换已确认属性，保留原地图的阵营美术配置。`unit_tuning.json` 记录800更新、2/0.5移动倍率和固定10格远视等已确认值及暂定表现说明。

v8新增字段均可缺省：每单位 `ambush_t`、`rolling_t`、`rolling_ticks`、`effect_tasks`（27/28的去重任务列表）、`effect_task`（0/27/28）；模拟全局 `fireFields`（a/b地面格、age0–99）。验证全部结构后才交换世界；旧档hidden_t迁移为ambush_t，旧档缺火场与队列时默认空。不会改变关卡内容哈希或玩家存档路径。
