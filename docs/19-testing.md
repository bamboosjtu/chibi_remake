# 19 测试与验收

> 本章定义测试层级、运行方式、覆盖矩阵与发布门禁。回归入口随代码维护，本文档只规定契约与判据。

## 1. 层级

| 层 | 入口 | 作用 |
|---|---|---|
| 引擎自检 | `--selftest` | 单图断言：加载、选择、生产、组建、战斗、任务、34 关注册 |
| 模拟摘要 | `--simtest=<秒>` | 固定 tick 后的状态摘要，跨版本/跨速度回归 |
| 独立回归 | `tools/gd/test_*.gd` | 子系统与跨系统场景，断言式 |
| 数据与工具 | `tools/test_*.mjs`、`test_publish.ps1` | 关卡数据、开局配置、内容管线、发布夹具 |
| 候选冒烟 | `tools/verify_candidate.ps1` | 实际 EXE 全地图加载、同一 PCK 的完整 release 套件与已登记模拟基线；跳过时只能生成未发布候选 |
| 本地 CI | `tools/ci_windows.ps1` | 默认文档、素材清单、架构与最小冒烟；`-FullRegression` 扩展到完整回归 |
| 托管门禁 | `.github/workflows/ci.yml` | 单一工作流四个作业：`contracts` 聚合 `tools/ci_lightweight.mjs` 六组契约；`simulation`/`engine`/`continuation` 跑无素材依赖的引擎门禁 |

GitHub Actions 只有一个 `ci` 工作流，四个作业都随推送与拉取请求执行：`contracts` 把架构、注册表、数据、文档、仓库完整性和工具检查交给 `tools/ci_lightweight.mjs` 聚合成一次运行（单项失败不跳过后续检查，最终 job 保留失败状态），并补克隆输入声明、工作流自检与 PowerShell 解析；`simulation` 在无 LFS 美术的条件下执行完整已登记模拟基线、34 张地图启动与存档/Schema 回归；`engine` 执行 Godot 脚本套件、组合注册表、三组"必须拒绝启动"的负例，并拉取两张地形源图运行地形管线；`continuation` 以四图矩阵各起一个独立进程跑 0/31/120/450/900/1800 tick 的续跑。**引擎自检（`--selftests`）不在托管 CI 运行**：自检会挂载单位表现，缺少运行素材时恢复阶段会因缺图集失败；它由 `tools/ci_windows.ps1 -FullRegression` 与发布候选验证在具备运行素材的环境执行，`run_regressions.mjs` 也会在素材仍是 LFS 指针时拒绝该参数。完整源码发布套件、缺表现资源恢复、热路径预算、Windows 启动器与打包安全属于发布验收，由本地 `tools/ci_windows.ps1 -FullRegression`、`tools/release.ps1` 与 `verify_candidate.ps1` 执行；CI 不代替 Windows EXE、GPU、性能和打包验收。

## 2. 引擎自检

```powershell
$env:APPDATA = (Resolve-Path "_work\godot_appdata").Path
.\Godot_v4.7.2-stable_win64.exe --headless --path godot/chibi_remake `
  res://main.tscn -- --map=CHIBIC1 --selftest
```

判据：

- 输出 `SELFTEST RESULT: PASS`，退出码 0；
- 输出 `SELFTEST levels: [...] count=34`；
- 无 `SCRIPT ERROR` / `Parse Error`；
- 关键行存在：缩放、关卡注册、组建、胜负规则、墓碑清理。

自检会用临时建筑与资源夹具补齐本图缺失的仓库与科技建筑，避免把“严格仓库规则”误判成不回运。

## 3. 模拟摘要

```powershell
.\Godot_v4.7.2-stable_win64.exe --headless --path godot/chibi_remake `
  res://main.tscn -- --map=chibic1 --simtest=15
```

输出：

```
SIMTEST: 15.0s tick=450 digest=<FNV-1a>
```

- 摘要逐单位覆盖 `uid / unit / owner / ax / ay / hp / alive`，只由模拟状态决定。
- 摘要同时取决于地图与 tick 数；基线记录在 `tools/inputs/baselines.json`。
- 修改模拟逻辑、通行数据或开局数据后，必须显式更新基线并在提交说明中写明原因。
- 不同速度档位与不同渲染帧率下，相同 tick 数的摘要必须一致。

## 4. 独立回归

```powershell
.\Godot_v4.7.2-stable_win64.exe --headless --path godot/chibi_remake `
  --script tools/gd/test_economy_rules.gd -- --no-intro --noview
```

- 脚本为 `SceneTree`，自行加载 `main.tscn`、关闭渲染与 AI 后直接驱动模拟。
- 断言失败即退出非零；脚本带超时保护。
- 所有写盘使用隔离 `APPDATA`，不触碰玩家存档。
- 回归入口应与被改动的系统对应，不要求每次构建跑全部脚本。

规则边界有静态和运行时两层验证。架构门禁拒绝模拟层文件/目录访问、动态资源加载、JSON 解析和未受控墙钟采样；负例覆盖字符串及注释干扰。`node tools/test_rule_startup.mjs` 在独立项目副本中注入规则故障，并在成功启动后移除全部规则目录，再执行状态变化、世界交换及回滚，校验没有重新读取或重试加载。`--cpu-only` 使用无视图路径，适用于未获取 LFS 美术的托管 CI；有视图套件另验证附着后的事务回滚。源目录和玩家存档不参与故障注入。

## 5. 覆盖矩阵

| 系统 | 主要回归 |
|---|---|
| 资源与采集 | `test_economy_rules`、`test_economy_boundaries`、`test_harvest_retarget`、`test_grain_patch`、`test_hq_delivery`、`test_edge_interaction` |
| 建筑与施工 | `test_construction`、`test_build_feedback`、`test_building_square`、`test_resource_input` |
| 生产与科技 | `test_research_jobs`、`test_army_technology`、`test_special_units`、`test_combat_rules` |
| 编组与指令 | `test_worker_groups`、`test_team_lifecycle`、`test_command_replace`、`test_cmd_paging`、`test_battle_interaction` |
| 规则常量与准入 | `test_rule_constants`、`rule_constants_check.mjs`：旧值基线、冻结角色、科技完成、实体/主将名额与训练预留；科技文档由目录生成并校验 |
| 规则启动与内存边界 | `test_rule_catalog`、`test_rule_startup.mjs`：目录校验、深层冻结、无文件 tick、候选交换/回滚、可选后端与启动拒绝 |
| 研究规则集成 | `test_research_rules`：三层指令、34 关开场白、1170 组武将属性、奖励/晋升边界、存读档 |
| 移动质量 | `test_movement_quality`：完整步长、避墙/避资源的直线路径、显示插值、动画节拍、队伍独立落点 |
| AI | `test_ai_planning`、`test_ai_policy`、`test_ai_slots`、`test_l1_assault`、`test_ai_research` |
| 水战与载员 | `test_transports`（核心交互）、`test_transport_worlds`（11 图）、`test_unload_state`、`test_naval_casualty_save` |
| 战斗与弹体 | `test_projectiles`、`test_action_clock`、`test_action_lifecycle`、`test_duel`、`test_visibility_rules` |
| 导航与占格 | `test_spatial_rules`、`test_unit_footprint`、`test_unit_collision`、`test_unit_index`、`test_nav_invalidation`、`test_automatic_gates` |
| 任务与胜负 | `test_scenario_end`、`test_architecture` |
| 应用生命周期 | `test_pause_ownership`、`test_app_boundaries`、`test_portable_startup.mjs`：暂停所有权、退出清理、世界回滚、索引缓存、场景切换失败、只读快照与便携配置拒绝 |
| 存档与时钟 | `test_architecture`、`test_tick_timers`、`test_clock`、`test_clock_ui`、`test_m0` |
| 界面与光标 | `test_input_research`、`test_cmd_paging`、`test_battle_interaction`、`test_hud_metrics` |
| 表现与素材 | `test_texture_states`、`test_chibil1_presentation`、`verify_full_art`、`verify_architecture_view` |
| 音频 | `test_sfx` |
| 开局数据 | `test_opening_forces.mjs`、`test_opening_forces.gd` |
| 内容与发布 | `test_content_pipeline.mjs`、`test_publish.ps1`、`test_bootstrap.mjs` |

## 6. 人工验收与候选冒烟

构建会在导出后自动对候选包运行下面的基础冒烟、全部已登记 release 用例、全部地图加载及两档确定性基线，失败即构建失败；发布重新校验证据覆盖与产物哈希，不会把它标记为人工验收通过。画面、手感与关卡的最终验收仍由人工完成。

`release_tests.json` 的基础冒烟入口：

| 脚本 | 范围 |
|---|---|
| `test_m0` | 菜单、存档槽及跨关读档 |
| `test_battle_interaction` | 核心输入、选择和建筑工作入口 |
| `test_review_contracts` | 随机数续跑、存档校验与状态摘要 |
| `test_save_roundtrip` | 六个带 AI 的采样点保存、恢复及续跑摘要；字段登记、原子拒绝与生命周期 |

另以实际发行 EXE 执行绿色配置与隔离系统目录两种模式的保存、自动槽、结束进程及重启菜单读档；全部使用显式条件判定，不依赖发布版会移除的 assert。`test_world_exchange` 验证显示暂存失败回滚、稳定访问入口、旧世界及其服务释放和过期操作拒绝。

其余玩法、媒体、画面和性能测试归入 `development_tests.json`，不删除测试实现。全地图、自检、固定 tick 摘要仍可按需运行。

```powershell
# 源码最小冒烟
node tools/run_regressions.mjs --suite tools/inputs/release_tests.json

# 对已构建候选重跑同一清单（构建已自动执行）
powershell -NoProfile -File tools/verify_candidate.ps1 -Executable '<候选目录>\ChibiRTS.exe'

# 完整源码 CI
powershell -NoProfile -File tools/ci_windows.ps1 -FullRegression
```

候选冒烟复用统一运行器的超时、退出码、脚本错误和 PASS 标记判据；临时引擎位于候选目录以使用同包 DLL，结束时删除，结果放入 `_work/candidate-smoke`。清单记录 `verification=candidate-smoke` 时只说明该清单跑过，不代表人工验收；`-SkipVerify` 或旧候选记为 `skipped`/`unverified`，不可发布；`-SkipVerify` 必须同时指定 `-NoPublish`。

## 7. 测试原则

1. **断言行为，不只断言字段**：例如“装载时资源不增加、交付时增加”，而不是只检查 `carry=200`。
2. **覆盖负向路径**：非法目标、不可达、资源不足、建筑被毁、坏档，都必须有拒绝并保留状态的用例。
3. **跨系统场景**：生产 → 升级 → 登船 → 命令替换 → 保存 → 恢复，作为连续流程测试。
4. **确定性**：固定随机种子与 tick 数；摘要比较优先于逐字段快照。
5. **隔离**：测试使用独立 `APPDATA`、独立存档目录，不读写玩家数据。
6. **不把静态审查当运行验证**：未运行的行为不能写成通过结论。

## 8. 证据与记录

- 发布的 `build-manifest.json` 随版本目录发布，只记录构建产物；导出日志与详细证据留在本地候选目录；机器摘要 `verification.json` 随版本保存。
- 本地验证摘要存放在 `_work/verification/`，不进入 Git。
- 文档不记录测试轮次、日期与历史通过率；变更由提交历史与发布证据承载。

## 9. 实现对应

| 职责 | 文件 |
|---|---|
| 自检 | `testing/battle_selftest.gd` |
| 摘要 | `simulation/world/battle_simulation.gd::_state_digest`、`simulation/diagnostics/state_digest.gd` |
| 回归脚本 | `tools/gd/test_*.gd` |
| 数据测试 | `tools/test_*.mjs` |
| 发布测试清单 | `tools/inputs/release_tests.json` |
| 基线 | `tools/inputs/baselines.json` |
| 候选验证 | `tools/verify_candidate.ps1`、`tools/gd/verify_*.gd` |
| CI | `tools/ci_windows.ps1` |

## 10. 验收要点

- 自检与回归失败必须非零退出，不允许“只打印不判负”。
- 摘要变化必须伴随基线更新与原因说明。
- 发布前由人工决定验收范围与是否接受当前产物。
- 测试不依赖编辑器缓存与玩家目录。
- 每条规格规则至少有一个正向与一个负向用例（或明确标注为未覆盖）。

## 11 专项覆盖

### 建筑与显示

`test_building_panels` 检查工人成员的武将归属与空手返回入口、钱庄六个三列图标、出售/生产当前工作图标、绿色进度条与红叉取消、工地进度以及 640–1920 窗口内的控件边界。用 `--output=<目录>` 可在原生渲染下输出截图。

`test_building_research` 覆盖读档后四座城门的安装高度、640/1280/1920 窗口、工兵/步兵/骑兵/弓兵的实际精灵尺寸与脚底、民居点选及真实攻击伤害、费用与研究/出售入口、四段施工、大本营生产等级（不依赖 `init[0]`）、车兵/舰船清单和岸边检查。美术证据由 `capture_building_review` 在原生渲染下输出。

### 资源推进与探索显示

`test_resource_frontier` 要求两名工人分别采空 5×5 粮田和树林、每片 5000 资源全部入库，覆盖中心格、采空格行走、禁止进入活资源、采集中途存读及占地重建；另检查岸边不会变成陆桥、将领及四名工人共同攻击民居、第一关 21 个敌军及可达道路。`capture_exploration_review` 用实际存档探索记录采样小地图，验证明亮/暗色/黑色三个状态。缩略图由 `generate_minimap_terrain` 从发布地形最低 LOD 离线生成，数据为 `data/db/minimap_terrain.json`。

`test_chibil1_presentation` 锁定命令子菜单的三列布局与面板边界。`test_ability_menus` 检查十个等级的具体计谋身份、固定空槽、与主指令相同的图标尺寸、阵法分页、锁定阵法执行拒绝、恢复的 X 快捷键，以及点击战场退出且保持选择。用 `--output=<目录>` 可输出计谋和阵法的原生渲染截图。

### 遭遇接战、章节推进与单挑

`test_encounter_campaign`、`test_duel` 验证双方自动接战、工人队伍及工作/行军/警戒优先、隐蔽和中立过滤、34 关次序与终章边界、倒计时切换新世界、单挑合法性/接受公式/平局及胜负一次结算、自然播放和跳过。`capture_duel_review` 完整播放 28 秒影片，截取交锋/尾段/下一章界面并检查影片期间已提交的伤害和结束时的兵力。

### 移动

`test_movement_quality` 按 `research/movements/data/movement.json` 对照 26 个已登记兵种、208 个方向序列（包括原表重复帧），断言每两 tick 一帧、180 度转身经过相邻方向、转身不重置步态、显示插值不推进模拟时钟、拐角存读后的下一步相同，以及坏朝向快照拒收。`test_architecture --noview` 验证整世界快照的继续执行一致性。`capture_movement_review` 输出六种单位、420 帧原生高清对照。

### 单位

`test_unit_research` 汇总 26 种 canonical 属性、17 种生产费用、平民采集/交付/修理与禁止建造、混合施工队、工人费用和 100 更新训练、完整占地上下船/离岸等待/4 更新相位存档；并验证 15 支队伍选取、800 更新末清状态、混乱排队/过期跳过、滚木视野首目标士气 −50、32/45 埋伏固定 30 且可见、主将单体恢复、火场 5/9/…/97 结算/友伤/建筑/离开重入/240 上限、坏档原子拒绝和当前状态字段拒绝检查。

### 原片播放与死亡编队

`test_original_media` 校验 47 个 AVI 的原始哈希，逐个建立真实 Indeo3 播放，验证原始尺寸、640/1280/1920 窗口下物理像素 1:1 居中、自然结束/跳过/读档取消/暂停恢复、LDAN 按结果直接定位原片段；原生图形检查另验证 PCM 音频信号正常幅度。

`test_research_rules` 覆盖真实 `_kill` 当帧释放槽位；`test_team_lifecycle` 覆盖仅含成员的控制组、混合控制组保留其他单位、死亡动画中存读及最终解绑。发布测试将原生 DLL 和 EXE/PCK 共同校验、复制；任一 DLL 被更改时保持旧启动指针。

候选冒烟将引擎临时置于候选目录，使用同包解码库，退出后删除；运行器隔离 APPDATA 与 LOCALAPPDATA。模拟报告保留 world 整数基线和子系统摘要。`test_public_audio` 按需构建小型 PCK，检查实际音乐、音效和混音采样。

`test_clock_ui` 通过真实菜单控件验证设置面板、四档速度、Esc 返回、暂停、存读档与结束战役入口；`test_texture_states` 验证无编辑器缓存时的正式高清解码、缓存命中、原图缺失警告级与正式高清缺失错误级。

## 12 模块回归与进程门禁

```powershell
node tools/architecture_check.mjs
node tools/run_regressions.mjs --selftests --baselines --maps --suite tools/inputs/release_tests.json --suite tools/inputs/development_tests.json --suite tools/inputs/known_failures.json
```

`test_modular_battle` 验证表现节点所有权、无效存档原子拒绝、稳定世界访问入口、恢复后的 UID 注册表以及关闭战场后的组件释放。架构测试覆盖移动、战斗和生产并发状态的存档续跑。模拟摘要与子系统摘要逐项比较 `baselines.json`，纯结构重构不能修改该文件来消除差异。

`tools/build_release.ps1 -SkipData -NoPublish` 生成并验证候选，不切换发布版本指针；增加 `-SkipVerify` 才跳过验证。

### 秘籍、计谋与阵法

开发组 `test_meta_abilities` 直接对照九计谋名称、费用、解锁和十阵法全部 150 个坐标。真实视口键盘事件覆盖第五字符开关、大小写与失配、输入期间不派发命令、等级上下限与经验不变、调试键兼容。领域检查覆盖取消前置仍扣费且拒绝重叠、普通免伤与火场/旧灼烧、全图开关不污染探索、托管仅影响空闲可攻击单位及其存档续跑、坏字段原子拒绝、战役相邻关卡边界。

同组验证主将优先的 15 支固定队伍、不混入其他选择、陈旧/阵亡/载员/建筑内部引用过滤、主将使用首槽立即移动、夹边和战斗结束拒绝，以及远视当帧揭示与到期恢复。`capture_abilities_review` 在原生渲染下检查信息条、窗口尺寸变化、计谋及阵法面板。


### 读档表现与发布回归

开发回归包含 `test_restored_view`：在未探索区域恢复远处的我军，暂停中校验大地图实际遮罩的透明、半透明和全黑三种 alpha；视野模型替换时，即使修订号相同也必须重建纹理。六类单位逐个验证八个屏幕方向使用不同采样区域、移动与攻击行分离，原生模式输出读档前后及四个步态相位截图。

`test_worker_groups`、`test_nav_invalidation`、`test_ai_slots`、`test_command_replace`、`test_research_jobs`、`test_initial_teams` 以及 `test_unit_index` 均属于按需开发回归。命令测试显式派发队列，施工仅由武将发起，弓术使用木材场，升级生产需要已建大本营，导航测试检查连续路段安全而不限定平滑路径的路点数量。工人续跑比较完整快照；新建实体在保存前必须已具备规范动画字段。800 单位预算保持 100 ms，取预热后三批 10 tick 的中位数，不通过放宽阈值规避失败。

`test_worker_visuals` 属于按需开发回归，覆盖工人八方向、四个步态相位、空手与四种资源，以及攻击和修理。除检查动作行与显示高度外，还检查实际采样像素，拒绝混入被透明间隔隔开的相邻姿势。空手但保留上次资源种类的工人仍使用空手步态；可用 `--review-output=<目录>` 导出四个相位的渲染对照图。

## 13 完整战场基准

`test_unit_index` 的 800 单位微基准只覆盖占格索引。完整基准在真实关卡 `chibic17` 上运行 AI、寻路、战斗、弹体、采集、施工、视野、渲染和地形流式加载：

```powershell
pwsh -NoProfile -File tools/bench_full_battle.ps1            # 200 机动单位、60 支交战
pwsh -NoProfile -File tools/bench_full_battle.ps1 -Stress    # 660 机动单位（约 800 个对象）、240 支交战
# 同一个驱动也可在正式 release 模板 + 导出 PCK 中运行（保留 PCK 旁的 addons/DLL）：
pwsh -NoProfile -File tools/bench_full_battle.ps1 -ReleasePack "D:/path/to/candidate/ChibiRTS.pck"
```

脚本输出逻辑每 tick 完整 `_sim_step` 的 P50/P95/P99/最大值、实际窗口 FPS、进程峰值工作集、Godot 视频内存和静态内存峰值，任一项越界即失败；`--bench-output` 或 `_work/bench/` 保留 JSON。参考机为 Intel i7-8700（6 核 12 线程，3.2 GHz）、64 GB 内存、NVIDIA Quadro P4000 8 GB、Windows 11、1920×1080、GL Compatibility。

| 场景 | 机动单位 | 交战队 | P95 预算 | FPS 下限 | 峰值工作集 | 显存上限 |
|---|---:|---:|---:|---:|---:|---:|
| 标准 | 200 | 60 | 500 ms | 60 | 2.5 GiB | 1.25 GiB |
| 压力 | 660 | 240 | 1200 ms | 30 | 3.5 GiB | 1.5 GiB |

基准显式传入 `--no-intro` 与独立验收命名空间。开始及测量期间要求未暂停、未结算，逻辑阶段每次调用必须推进一个 tick；帧阶段必须由正常战场进程持续推进模拟并处理全部输入采样。生成部队后先更新视野，实际交战数不足请求值则拒绝测量。

报告同时记录帧时间分位数、实际完成 tick/s、目标 tick/s、`sim_acc` 首尾与峰值、相对墙钟的模拟落后量，以及游戏内指令队列响应 P95。该响应只覆盖游戏队列，不包含操作系统输入投递。进程内存只统计本次启动的引擎 PID。

相对回归预算与实时体验分开判断：相对 P95 仍保留 500/1200 ms；另以当前逻辑周期为实时 P95 上限（最快档 30 ms），同时要求实际 tick/s 达目标的 95%、无持续积压、指令队列 P95≤100 ms，并保留 60/30 FPS 下限。较小的 `sim_acc` 不能替代实际吞吐检查，因为上游帧时钟也可能限制传入的时间步长。只有完整工作负载和所有门槛通过，才能作为发布依据；测得数据保留在报告中，不以暂停后的高 FPS 代替运行性能。

`tools/test_terrain_dedup.mjs` 检查重复内容合并、不同内容保留、引用图一致、源输入溯源与越界路径在修改前拒绝；候选包另验证全部重写后的地形资源可加载。历史失败清单只保留尚未解决且已验证的条目，不将修复项继续豁免。

验收显示环境固定为 1920×1080。`--selftest`、`--native-save` 自动使用独立验收命名空间；不带标识也不写玩家槽位。`--save-test-id` 仅接受字母、数字、下划线与连字符，拒绝任意目录参数。

CI 的续跑矩阵分别检查 chibic1、chibil1、chibic10、chibic17：保留原整数与分段基线，额外以完整快照检查 0/31/120/450/900/1800 tick 六个采样点的恢复和 AI 续跑。包含 15 秒、60 秒点，覆盖资源阻挡、探索、编组、载员、计时与堵路状态。每图独立进程，功能性看门狗为 600 秒；既有每 tick 性能预算保持不变。

基准协议 v4 在创建战场后立即停止自动处理，等待显示初始化，再填充部队、设置持续交战血量并推进固定的预热与测量 tick。它避免启动 30 帧期间因机器速度不同而改变初始世界。源码入口 `tools/gd/bench_full_battle.gd` 与发行入口 `--full-battle-bench` 共用 `testing/full_battle_benchmark.gd`；报告标明 `protocolVersion`、`engineBuild`、规则指纹及实际单位数。发布模板模式校验模板哈希，使用独立副本与存档目录，不切换发行版本。

新增诊断包括 `pathCallsPerTick`、`pathMsPerTick`、搜索/平滑分项、`updateVisualMsPerFrame` 和 `fogUpdateMsPerFrame`。后两者是 CPU 提交时间，实际帧时间仍包含 GPU 合成。渲染模式将视野的两张 R8 位图上传后在小型视口中合成 RGBA 雾层，大地图与小地图继续共享同一张三档透明度纹理；无渲染测试保留 CPU 参考路径。`test_restored_view` 另在实际窗口中读取合成纹理，验证暂停读档后的透明度。

`test_realtime_queries` 覆盖网格边界归属、密集参考射线、失败重寻路冷却及恢复、五次追帧一次表现同步、旧对象排除、重试状态存读及不匹配规则身份拒绝。`test_visibility_rules` 以完整重建对照 40 轮随机移动、重叠、载员及视野半径变化，核对可见计数与探索记忆。

完整战场实测结果由 `bench_full_battle.ps1` 输出的 JSON 报告保存，报告路径可通过 `-Output` 指定。验收应核对全部轮次的 `qualityPassed` 与 `validationFailures`，不能只引用通过轮次。


### 压力场景与后端对照

```powershell
pwsh -NoProfile -File tools/bench_full_battle.ps1 -ReleasePack <候选目录>/ChibiRTS.pck
pwsh -NoProfile -File tools/bench_full_battle.ps1 -ReleasePack <候选目录>/ChibiRTS.pck -Stress
pwsh -NoProfile -File tools/bench_full_battle.ps1 -ReleasePack <候选目录>/ChibiRTS.pck -CapacityStress
# 源码或带分段计时的运行仅作诊断，不计为发行验收：
pwsh -NoProfile -File tools/bench_full_battle.ps1 -DeveloperSource -Stress -ProfileUnits
```

原有 `-Stress` 继续运行 660/240，不改变旧工作负载及预算。`-CapacityStress` 按真实关卡参战方补足每方 200 实体槽；建筑、工人及武将本体计入同一上限。chibic17 的三方满员为 460 个机动单位、240 个初始交战单位；报告逐方记录实体、建筑与武将数。该用例和添加第四方的历史 660 用例分别报告，互不替代。

协议 v4 记录计算后端、分段计时开关、人口分布、导航预热以及引擎/PCK 哈希。已发布目录只有根 DLL 时照常运行，不要求额外 addons 目录。验收仍要求真实模拟持续推进、最快档 tick P95 ≤30 ms、tick 吞吐 ≥95%、命令队列延迟 P95 ≤100 ms，以及标准/压力 FPS ≥60/30；不丢欠账、不降低频率、行为变化须记录原因并重新验证基线，不能直接更新参考值来消除失败。

`test_pressure_contracts` 校验坐标与接触缓存的精度、失效、剖析一致性及两种人口工作负载。`test_native_math`、`test_native_geometry` 和 `test_native_world` 分别对照 2,000 个状态夹具、16,000 次攻击更新、160 轮完整视野更新、800 个接触/占格夹具、100 个有序分离选择，以及 660 单位的六个完整世界采样点。无原生后端时保留脚本执行；Windows 的原生数学测试必须实际加载 DLL。

新候选验证强制连续三轮正式 PCK 标准场景全部通过，并把结果写入 `verification.json` 的 `standardPerformance`。`test_benchmark_evidence.ps1` 验证缺轮、暂停、调试构建、慢时钟、低分辨率、剖析运行及缺失/非有限指标均被拒绝。这个标准门禁不单独认证压力实时性，压力结果仍需独立查看对应的 JSON 报告。


### GPU 绘制对照

`test_gpu_minimap.gd` 需要实际渲染窗口，不能使用 `--headless`。它冻结 660 单位场景，以相同的单位次序分别运行 CPU 标记绘制和 GPU 实例绘制，比较完整小地图图像、相机框和模拟快照；像素差不能超过一个颜色量化级。

```powershell
Godot_v4.7.2-stable_win64.exe --path godot/chibi_remake --script tools/gd/test_gpu_minimap.gd -- --no-intro --save-test-id=gpu-minimap
# 同一 PCK 的对照运行，均保留原性能门槛：
pwsh -NoProfile -File tools/bench_full_battle.ps1 -ReleasePack <候选目录>/ChibiRTS.pck -Stress -CpuMinimap
pwsh -NoProfile -File tools/bench_full_battle.ps1 -ReleasePack <候选目录>/ChibiRTS.pck -Stress -RenderingMethod mobile
```

`-CpuMinimap` 与渲染后端覆盖用于 A/B，报告 `acceptanceRun=false`；正式验收使用项目默认配置。报告注明实际渲染方法、驱动、小地图后端、批量单位执行和实际窗口绘制调用数。重复轮次可指定同一 `-RunnerDirectory`，每次重新验证 EXE、PCK 与全部原生依赖哈希，避免反复复制大型 PCK；不复用不完整或内容变化的目录。APPDATA 与保存槽仍然逐轮隔离。


协议 v4 将 FPS 测量起点固定在预热 60 + 逻辑采样 300 = 360 tick。随后 30 个渲染预热帧保持自动模拟关闭，并比较完整快照摘要；确认状态未变化后，才开启正常逐帧处理并测量 FPS、真实 tick 吞吐和命令延迟。手动逻辑采样的渲染帧同步显示模型，防止新增单位长期保留初始化可见性。报告包含 `frameInitialTick`、`frameInitialStateChecksum`、`renderWarmupPreservedSimulation`；候选门禁核对固定起点。历史 v2/v3 的 FPS 数字保留，但不与 v4 结果当作同一初始状态直接比较。


`test_command_determinism` 从战场输入入口提交采集命令，比较不同帧批次和速度的规范化快照，涵盖目标耗尽、暂停保存拒绝及 v9 续跑。固定摘要覆盖四张代表地图和 450、1800 tick，保留整数与分段摘要，并校验规范化完整快照。自检的存档写入、读取失败使用 `node tools/run_regressions.mjs --selftest-failures` 验证退出码。

用 `pwsh -NoProfile -File tools/bench_capacity_stability.ps1 -ReleasePack <候选目录>/ChibiRTS.pck` 执行 460 单位的五轮专项验证。各轮使用相同 PCK 和初始摘要，要求窗口 ≥30 FPS、tick P95≤30 ms、吞吐≥95%、命令延迟 P95≤100 ms，积压符合完整战场检查，同时核对五轮 P95 极差低于中位数的 15%。报告保留每轮、最低 FPS 和内存峰值。加 `-IncludeSynthetic` 时另跑一次 660 单位诊断。对完整报告目录可用 `-OutputDirectory <报告目录> -SummarizeOnly` 复核专项验收条件。

`bench_full_battle.ps1 -FrameDiagnostics` 附带逐帧采样，`-PanCamera` 用于滚屏诊断。诊断报告保留模拟步数、单位同步、插值、HUD、小地图和绘制调用数。兼容渲染器下 GPU 时间字段为空。逻辑和表现计数存在嵌套，求总耗时时应采用外层计时。

## 测试归属与门禁结果

`node tools/suite_check.mjs` 检查 `tools/gd` 下全部 GDScript：自动套件必须有成功标记，非自动入口必须在 `manual_tests.json` 中声明类别、前提与运行方式。CI 和存档套件各自声明运行范围，发布与开发主套件之间保持唯一归属。新增脚本未登记、条目失效或手工排除缺少理由均阻止门禁。开局兵力测试声明 `opening-forces` fixture，runner 先从规格文档生成并校验输入；准备失败单独记为失败并继续其他测试。

### 架构依赖与字段所有权基线

`tools/inputs/module_map.json` 保存 181 个源文件的逐文件目标路径（moved/renamed/retained/deleted 与阶段），`tools/inputs/dependency_matrix.json` 是目标包允许集与文件级例外，`tools/inputs/dependency_baseline.json` 记录尚未消除的历史边（含 `removeByStage` 与 `reviewBy`）。三者由以下门禁消费：

- `node tools/dependency_check.mjs`：用 `tools/dependency_report.mjs` 扫描 `preload/load/extends`、`_dep_` 绑定、`world.<svc>` 调用、构造函数注入和动态加载，输出 `_work/refactor/dependency-graph.json`（含 SCC）；新增未登记违规或已失效的基线边都失败。
- `node tools/unit_schema_ownership_check.mjs`：`unit_schema_ownership.json` 的键集与 `UnitSchema.FIELDS` 精确相等，owner 唯一，`persist`/`derived` 与 Schema 一致。
- `node tools/battle_state_write_check.mjs`：按 `battle_state_ownership.json` 的唯一业务 owner 判定 `battle.<field>`/`state.<field>`/`.set()` 写入；跨包写入冻结在 `battle_state_write_baseline.json`（43 条，P7 收敛），新增跨包写入或失效基线即失败。
- `node tools/battle_state_ownership_check.mjs`：`battle_state_ownership.json` 覆盖 69 个属性，12 个代理指向 `session.<field>`，策略与 `BattleStateFields` 一致；`auto_control` 归 AI，`selected` 归 Commands，`tile_*` 归 Navigation 只读。
- `node tools/test_dependency_report.mjs` 与 `node tools/test_ownership_checks.mjs`：正负夹具，验证合法边通过、非法边失败、基线可消解、字段缺失/重复/错误 owner 失败。

`node tools/ci_lightweight.mjs` 执行全部检查并汇总；`--group architecture|registry|data|docs|repository|tooling` 执行对应组，均把机器可读结果写入 `_work/lightweight`。退出非零表示至少一项失败，不允许用后续成功覆盖失败。`repository` 组包含 `node tools/workflow_check.mjs`：工作流必须唯一、每个作业都有超时、引用的脚本/输入/本地 action/LFS 夹具必须存在，续跑矩阵必须与 `test_continuation_coverage.mjs` 支持的地图一致——避免托管流水线在推送后才发现引用了已删除的脚本。架构体积预算与边界豁免必须有 owner、reason、reviewBy；到期阻止门禁。`node tools/port_inventory.mjs` 检查已退役的依赖适配器、提供者字段和作用域调用。

单位字段检查同时使用 `unit_schema_check.mjs` 的工厂/常见字面量写入检查、`test_unit_schema.gd` 的逐字段保存/校验/恢复，以及真实快照和续跑样本。静态扫描无法证明任意动态键表达式的完整性，新增动态字段必须补充真实场景样本。Schema 不替代载员、科技、生产、AI 和引用的语义验证。

源码发布回归使用 `runtime_assets.mjs --check --hash --versioned-only` 检查已提交资源；该模式不要求生成地形缓存，也不认证完整 staging 图。正式构建继续使用完整的 `--check --hash`，生成地形后再验收。

`test_save_validity` 以正确 checksum 覆盖当前格式缺整组资源、缺任一资源键、缺队列及队列错误类型，并核对拒绝后资源/生产队列和世界身份不变。`test_unit_schema` 的 record 组走完整候选恢复；`test_snapshot_stages` 分别破坏七个校验阶段并检查拒绝的原子性。`test_app_services` 覆盖服务独立性、写入保护和槽缓存失效；`test_camera_read_model` 验证值投影不返回可变世界引用。


`test_build_preview_read_model` 检查投影的递归只读容器和固定字段集、复制值隔离、跨三个暂停帧的缓存复用、资源/选择/导航失效、失败交换回滚、所有非身份缓存值相同的世界替换，以及旧世界/导航的释放。测试也以真实读档核对相机读模型仍读取当前世界。过期 owner 的预览 key/model 两种查询另由进程级契约负向测试覆盖，必须非零退出且无 SCRIPT ERROR。

`battle_access_inventory.mjs` 的默认模式校验清单新鲜度，`--write` 更新人工复审用的字面量使用位置。迁移后的相机和建造预览组件有禁止回退到四类借用属性的门禁；读边界也禁止直接深拷贝这些整组世界字段。正则检查不代替别名和动态表达式的审查。


`test_resource_layer_read_model` 验证固定三字段的递归只读可见投影、跨三个暂停帧的 60 次缓存复用、视口进出、同阶段几何重定位、普通阻挡版本不触发重扫，以及 0→1、2→3、4→5 的资源耗尽与空矿跳过。它还实际读取临时世界后回滚、注入读档失败回滚、强制全部非身份缓存值相等后加载新世界，并在保留旧投影时检查旧世界/导航和关闭战场状态的释放。资源键和资源投影的过期 owner 查询由进程级负向测试覆盖。

借用清单 schemaVersion 2 将 decor_cells 纳入扫描。相机、建造预览、资源层都有禁止回退到借用入口的门禁，资源层另覆盖该资源字典；已有逐帧深拷贝世界数据的禁止规则扩展到 decor_cells。


### 缺图和损坏表现资源

`node tools/test_missing_presentation.mjs` 将运行脚本和 JSON 复制到独立工程，链接只读素材，再仅在副本内删除四类 HUD 母版、删除/破坏 minimap 目录，验证真实场景进入可用回退。原资源哈希必须保持不变；测试不临时隐藏工作区资源。terrain-budget 用例覆盖最低 LOD 整批拒绝、错误字节声明的解码尺寸拒绝、后台任务排空与恢复。对应 GDScript 是 wrapper 专用入口，不能直接作为正常资源目录的套件运行。

该 wrapper 进入 hosted 源码发布回归与本地 FullRegression。`test_invalid_unit_removal` 验证错误索引、内容相同的克隆和已移除对象不会损坏世界；`test_save_semantics` 用正确 checksum 验证建筑分类、终局、nextUid、状态和巨大坐标输入被原子拒绝。二者属于必需 release 套件，存档语义用例也进入 CPU-only save 门禁。

### 单位状态与模拟热点

release 套件包含 `test_unit_action_states` 和 `test_hot_path_contracts`。前者逐一驱动十三个状态，核对非法目标退回、休息完成、交付等待、混乱前置条件和动画尾处理；现有战斗、施工、采集、载员与原生对照测试继续覆盖实际动作。后者核对资源缓存复用、耗尽分片与几何失效、失败查询后的导航标志恢复、施工成员身份与可变属性、每次更新的堵塞查询上限、中途进度保存、规则身份拒绝、失败回滚及旧世界释放，并核实 chibil8 的 10736 个饰物与最大 1240 格资源片。

`node tools/benchmark_hot_paths.mjs` 运行八工人采集、饰物命中、600 单位施工选择、堵塞终点和建造选址五组 CPU 场景。每组预热三次、采样三十次，记录中位数、P95、最大值及查询次数；预算由 hot_path_budgets.json 声明，使用标准完整战场的 500 ms 上限，堵塞查询另有十二次硬上限。该基准进入 hosted 源码发布回归及本地 FullRegression，不替代完整战场的实时吞吐、GPU 或正式包验收。

可选 `--baseline <commit>` 将历史工程解包到独立目录，只物化哈希一致的 LFS 素材，用同一脚本比较前后耗时；八名工人的目标与路径必须完全相同。输出包含引擎及 Harness 哈希。基准对比应串行运行，避免其他回归争用 CPU；硬件相关耗时与确定性的查询上限分别报告。

### 存档边界与单位投影隔离

`test_save_boundaries` 属于 release 和 CPU-only save 套件：正确 checksum 下的越界位置、超长路径、非法游标、整数溢出、悬空引用类型错误、任务数量/深度超限和坏费用被原子拒绝；旧版本、派生格缓存、缺失字段和非法游标拒绝。它验证解析前的大小/深度限额、输入容器所有权，以及同大小同修改时间下的备份来源失效、槽位标签和实际读取反馈。

`test_unit_read_models` 覆盖递归冻结、复制值隔离、暂停时的属性/选择/武将类别变化、tick/事件/导航几何失效、跨三个渲染帧的缓存复用，以及世界交换、回滚、旧 UID 回调拒绝和保留投影时旧世界释放。另以 800 个名册项、24 个可见单位采样十次更新，检查 600 次不变帧命中和静态元数据仅复制一次；该成本记录不替代完整战场 FPS 验收。过期宿主的单位、选择、生产、工作、指针和运动查询进入进程级负向测试，要求退出 1 且无二次脚本错误。


### 服务投影与当前格式

test_context_read_models 检查雾、时钟、选项、弹体及火场的递归冻结、字节缓冲隔离、暂停帧复用和手动步进失效；强制新世界的逻辑修订相同后验证身份失效、交换回滚、旧排队动作拒绝及服务释放。test_restored_view 核对可见/已探索/未知三种实际像素。

test_current_format 接受 v9，拒绝 v1–v8、无 checksum、旧规则别名和不匹配地图内容；拒绝不得改变当前世界。旧格式恢复正向用例已退役，仍保留当前格式的完整读写与续跑、载员、计时、AI、Schema 和脚本/原生对照。
