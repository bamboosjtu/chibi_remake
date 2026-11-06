# 16 存档与兼容

> 本章定义存档槽、文件结构、写入协议、校验与版本迁移。存档触发点见[游戏流程](02-game-flow.md)；数据字段见[数据规格](15-data-spec.md)。

## 1. 槽位

| 槽 | 文件 | 用途 |
|---:|---|---|
| 0 | `save.json` | 自动槽：结束战役、关闭窗口；兼容旧版单档 |
| 1–20 | `slot-01.json` … `slot-20.json` | 手动槽：玩家命名保存 |

- 每个槽独立保存，覆盖一个槽不影响其他槽。
- 槽列表显示：名称、关卡、保存时间；损坏记录置灰不可读。
- 手动槽名称最长 40 字；留空时使用关卡名。

## 2. 位置

绿色发行物以 `portable.txt` 显式选择本地存储：独立候选使用 EXE 旁 `userdata/<用户名>`，启动器显式传入发行根的 `userdata`，跨版本保持位置稳定。移除配置或使用 `--storage-mode=system` 可选择系统存储。

系统模式优先保留已有槽位所在目录；首存逐个尝试并实际写入验证：

1. `%LOCALAPPDATA%/ChibiRTS/saves/`
2. `%APPDATA%/ChibiRTS/saves/`
3. Godot 用户数据目录
显式使用 `--portable` 或可执行文件旁的 `portable.txt` 时，优先使用可执行文件旁的 `userdata/<用户名>/`；默认模式不探测该位置。

- 启动选择路径不创建空存档目录；实际提交创建最终目录、写入并回读临时文件，通过后才认定可写。已有槽位或显式便携根不静默切换。失败记录目录、目标槽文件、临时文件、阶段及错误码，保留旧档并清理本次临时文件。
- 旧位置的有效存档会迁移到新位置；已存在的新档不被旧档覆盖。
- 启动日志与保存提示会给出实际路径。
- 每个槽保留一个 `.bak` 备份。

## 3. 文件结构

```json
{
  "v": 8,
  "kind": "save",
  "map": "chibic1",
  "saveName": "赤壁首战",
  "savedAt": "YYYY-MM-DDTHH:MM:SS",
  "nextUid": 120,
  "gameEnd": 0,
  "resources": { "gold": 3000.0, "wood": 2000.0, "food": 1000.0, "stone": 800.0 },
  "units": [ ... ],
  "trainings": [ ... ],
  "simulation": { ... },
  "checksum": "<SHA-256>"
}
```

### 3.1 单位记录

| 字段 | 说明 |
|---|---|
| `uid` | 稳定 UID |
| `alive` | 是否存活（含淡出中的尸体标记） |
| `x` / `y` | 脚点像素 |
| `hp` | 当前生命 |
| `owner` / `unit` | 归属与类型 |
| `building` | 是否建筑 |
| `mapObject` / `mapIndex` | 是否地图对象及其序号 |
| `dieT` | 死亡淡出进度，−1 表示未死亡 |
| `state` | 当前状态名 |
| `officerIndex` | 所辖武将索引，−1 表示无 |
| `simulation` | 模拟字段（见 3.2） |

### 3.2 模拟字段

单位级字段包括：

- 位置与朝向：`A`、`B`、`dir`、`pi`、`path`；
- 生命与加成：`maxhp`、`base_maxhp`、`tech_hp_bonus`；
- 动作：`action_wait`、`action_phase`、`action_started`、`action_kind`、`action_target_uid`；
- 计时：`rest_t`、`build_t`、`gather_t`、`gather_ticks`、`delivery_ticks`；
- 状态计时：`inspired_t`、`haste_t`、`slow_t`、`farsight_t`、`confused_t`、`ambush_t`、`rolling_t`；`hidden_t` 仅作为旧档别名读取；
- 采集与载货：`carry`、`carry_kind`、`gatherRef`、`stock`、`stock_max`；
- 施工：`site`、`site_inside_uid`、`site_follow_uid`、`site_entry_x/y`、`site_exit_pending`、`build_cost`；
- 运输：`attached`、`aboard_uid`、`carry_n`、`carry_hp`、`loaded`、`unload_active`、`unload_t`；
- 编组与目标：`group_officer`、`join_target_uid`、`targetUid`、`build_targetUid`、`repair_targetUid`、`board_targetUid`；
- 其他：`hold`、`cool`、`repath`、`anim`、`moved`、`build_frame`、`status_173`、`mou`、`formation`、`fo_x/y`、`exp` 相关字段。

引用字段一律保存 UID 或稳定键，不保存对象：

- 采集目标：`{"kind":"decor","cell":"A_B"}`、`{"kind":"unit","uid":N}` 或 `{"kind":"spent","unit":N,"x":..,"y":..}`；
- 施工/修理/上船目标：对应 `*Uid`；
- 攻击目标：`targetUid`。

### 3.3 全局模拟

| 字段 | 说明 |
|---|---|
| `contentRevision` | 关卡内容哈希（见 15 章） |
| `tick` / `accumulator` | 已走 tick 与余量 |
| `speedIndex` | 速度档位 0–3 |
| `autoControl` | 可选布尔值；托管开启时写入 `true`，缺省为关闭；无效类型在构建候选世界前拒收 |
| `explored` | 迷雾探索位图（Base64） |
| `projectiles` | 飞行中的箭/石 |
| `decorResources` | 饰物剩余存量 |
| `aiResources` | 各势力四资源 |
| `groups` | 控制组（组号 → UID 数组） |
| `taskLatches` | 任务阶段锁存 |
| `taskEvents` | 已触发事件游标 |
| `officerProgress` | 任务事件经验 |
| `terrainChanges` | 地形清除记录 |
| `objectiveDone` | 脚本目标是否达成 |
| `officerPool` | 武将池经验/等级 |
| `playerTech` / `armyTech` | 玩家与各势力科技等级 |
| `techProgress` / `researchJobs` | 旧式单项研究/建筑研究订单 |
| `rngState` | 战斗随机数状态（十进制字符串） |
| `fireFields` | 单格火场列表（坐标、存在时长、归属） |
| `ai` | AI 计数、计划、撤退、陆军槽、水军槽 |

### 3.4 生产订单

| 字段 | 说明 |
|---|---|
| `buildingUid` | 生产建筑 UID |
| `unit` | 兵种 |
| `t` | 剩余 tick |
| `ticks` | 是否 tick 计时 |
| `owner` | 订单归属（独立于建筑当前归属） |
| `cost` | 已支付费用 |
| `aiSlot` / `aiToken` | 陆军槽关联 |
| `navalSlot` / `navalToken` | 水军槽关联 |

武将池的 `hasExp` 可选布尔字段保留经验键是否存在；旧档没有该字段时按既有经验恢复规则处理。字段缺失与显式零在成长计算中等价，但完整恢复保留两者在规范摘要中的区别。

## 4. 写入协议

1. 序列化为带缩进的 JSON；
2. 写入唯一临时文件；
3. flush 后重新解析并校验；
4. 当前主文件有效时改名为 `.bak`；主文件已损坏时隔离为 `.damaged-*`；
5. 临时文件改名为正式文件；
6. 读回校验；失败则回滚到 `.bak` 或隔离文件。

- 任一阶段失败都保留上一份有效存档。
- 备份不会因一次无效主文件被覆盖。
- 保存失败时返回原因（阶段与错误码），界面提示并保留原记录。

## 5. 校验和

- 覆盖除 `checksum` 外的整个 payload。
- 规范化：键排序、整数按整数输出、浮点保留 6 位小数、非有限值写 `null`。
- SHA-256 十六进制存入 `checksum`。
- 旧档没有 `checksum` 时按兼容路径放行。

## 6. 加载流程

1. 读取文件；主文件无效时读 `.bak`；校验和不符则拒绝。
2. 校验 `map` 与当前关卡一致。
3. 校验 `v`：大于当前版本拒绝；v4–v8 走当前路径；v1–v3 走兼容路径。
4. 校验 `contentRevision`；不匹配时查兼容表（`registry_compatibility.json`）。
5. 在**修改世界之前**完成全部结构校验：
   - 单位 UID 唯一、类型/归属/图集有效；
   - 路径点、坐标、格位有限且在范围内；
   - 资源、击杀者 UID、采集引用、施工/修理/上船引用合法；
   - 生产订单：建筑存在、同属、无重复、费用合法；
   - 研究订单：建筑存在、同属、科技与线匹配、无重复；
   - 计时与动作字段为整数且在范围内；
   - 生命上限满足“基础 + 科技加成”契约；
   - 载员图：人数 ≤ 16、船/载员归属一致、汇总与真实成员一致；
   - 弹体、地形变化、AI 槽位、控制组结构合法。
6. 校验通过后交换世界：生成实体、写回 UID、解析引用、恢复资源/科技/任务/AI、重建导航与城门、恢复视野。
7. 同步表现：隐藏载员、刷新面板、清空旧的待选命令。

失败时原世界、选择与载入状态保持不变，并给玩家可读原因。

## 7. 版本迁移

| 来源 | 处理 |
|---|---|
| v1 | 4 字段数组，按下标配对；仅恢复位置/生命 |
| v2 | 10 字段数组，带 UID 与身份 |
| v3 | 具名字段，完整快照（缺席地图对象视为已阵亡） |
| v4 | 增加全局模拟字段；缺失秒值按 1/30 秒换算 |
| v5 | 计时字段仍为秒；迁移到 tick |
| v6 | 休息/施工/六状态改为整数 tick；新增科技/研究订单 |
| v7 | 新增动作相位、弹体、AI 陆军槽 |
| v8 | 新增载员身份图、卸载相位、AI 水军槽、探索 |

迁移原则：

- 旧秒值按 `1/30` 秒换算为 tick；缺字段置 0。
- 缺 `armyTech` 时非玩家势力回到未研究。
- 缺载员字段时按真实成员重算汇总；隐藏的死亡载员清除船引用。
- 旧槽位/订单缺失时清空对应槽，不猜成普通订单。
- 超过 15 名成员的旧队按 UID 保留前 15 名，超额成员解除编组并保留生命与载货。
- 旧动作相位无法推断时从命令首 tick 重新初始化。

## 8. 兼容边界

| 情况 | 结果 |
|---|---|
| 关卡内容变化 | 拒绝加载，保留原档 |
| 内容哈希命中兼容表 | 允许加载 |
| 未知字段 | 忽略，不报错 |
| 非法字段值 | 拒绝加载 |
| 版本高于当前 | 拒绝加载 |
| 关卡文件已删除 | 拒绝并从关卡列表提示 |
| 图集/纹理变化 | 不影响存档 |

## 9. 实现对应

| 职责 | 模块 |
|---|---|
| 槽位、文件、校验和、原子写 | `app/game.gd`、`app/json_store.gd` |
| 目录探测与迁移 | `app/user_storage.gd` |
| 恢复编排 | `app/save_service.gd` |
| 共用单位字段 | `app/saves/snapshot_fields.gd` |
| 完整快照校验 | `app/saves/snapshot_validator.gd` |
| 候选实体与引用恢复 | `app/saves/snapshot_restorer.gd` |
| 候选世界提交与能力重绑定 | `app/saves/world_transaction.gd` |
| v1/v2/v3 兼容恢复 | `app/saves/legacy_snapshot.gd` |
| 计时迁移 | `simulation/systems/tick_timers.gd`、`action_clock.gd` |
| 载员校验 | `simulation/systems/transports.gd` |
| AI 槽位校验 | `simulation/systems/ai.gd`、`ai_training_slots.gd`、`ai_naval_slots.gd` |
| 科技校验 | `simulation/systems/technology_state.gd` |

v4–v8 完整快照先在不进入场景树的候选世界中恢复，再提交到原状态对象。表现节点按恢复后的 UID 重建，不进入单位字典或存档。v1/v2 的按位置恢复和 v3 的 UID 迁移保留原有兼容口径；旧实体改写 UID 时同步更新表现注册表。

## 10. 验收要点

- 保存失败不破坏旧档；损坏主档不覆盖有效备份。
- 读取失败不修改当前世界，选择与载入状态保留。
- 同状态存读后继续相同 tick 数，结果与不读档一致。
- 非法载员、负 UID、越界计时、重复订单在交换世界前被拒绝。
- 上升级后上船、船内升级、受伤后登船等合法状态可存读。
- 跨关卡读取会切换场景并在新场景内恢复。
