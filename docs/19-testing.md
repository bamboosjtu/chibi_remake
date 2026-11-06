# 19 测试与验收

> 本章定义测试层级、运行方式、覆盖矩阵与发布门禁。回归入口随代码维护，本文档只规定契约与判据。

## 1. 层级

| 层 | 入口 | 作用 |
|---|---|---|
| 引擎自检 | `--selftest` | 单图断言：加载、选择、生产、组建、战斗、任务、34 关注册 |
| 模拟摘要 | `--simtest=<秒>` | 固定 tick 后的状态摘要，跨版本/跨速度回归 |
| 独立回归 | `tools/gd/test_*.gd` | 子系统与跨系统场景，断言式 |
| 数据与工具 | `tools/test_*.mjs`、`test_publish.ps1` | 关卡数据、开局配置、内容管线、发布夹具 |
| 候选冒烟 | `tools/verify_candidate.ps1` | 实际 EXE 全地图加载、同一 PCK 的四项冒烟与确定性基线；跳过时只能生成未发布候选 |
| 本地 CI | `tools/ci_windows.ps1` | 默认文档、素材清单、架构与最小冒烟；`-FullRegression` 扩展到完整回归 |
| 托管契约 | `.github/workflows/contracts.yml` | `tools/ci_lightweight.mjs`：注册表、分层、素材白名单与发布套件形状 |

GitHub Actions 分两个工作流：`contracts` 运行不依赖引擎与 LFS 的静态契约（注册表、分层、素材白名单）；`ci` 运行 `tools/syntax_check.mjs`（JS/JSON）、PowerShell 语法解析，以及不依赖 LFS 的 Godot 轻量门禁（`check_runtime_scripts.gd` 编译全部运行脚本，`test_architecture.gd --noview` 加载第一关数据并验证核心模拟）。完整回归、引擎模板测试与构建发布仍在本地执行。

## 2. 引擎自检

```powershell
$env:APPDATA = (Resolve-Path "_work\godot_appdata").Path
.\Godot_v4.7.2-stable_win64_console.exe --headless --path godot/chibi_remake `
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
.\Godot_v4.7.2-stable_win64_console.exe --headless --path godot/chibi_remake `
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
.\Godot_v4.7.2-stable_win64_console.exe --headless --path godot/chibi_remake `
  --script tools/gd/test_economy_rules.gd -- --no-intro --noview
```

- 脚本为 `SceneTree`，自行加载 `main.tscn`、关闭渲染与 AI 后直接驱动模拟。
- 断言失败即退出非零；脚本带超时保护。
- 所有写盘使用隔离 `APPDATA`，不触碰玩家存档。
- 回归入口应与被改动的系统对应，不要求每次构建跑全部脚本。

## 5. 覆盖矩阵

| 系统 | 主要回归 |
|---|---|
| 资源与采集 | `test_economy_rules`、`test_economy_boundaries`、`test_harvest_retarget`、`test_grain_patch`、`test_hq_delivery`、`test_edge_interaction` |
| 建筑与施工 | `test_construction`、`test_build_feedback`、`test_building_square`、`test_resource_input` |
| 生产与科技 | `test_research_jobs`、`test_army_technology`、`test_special_units`、`test_combat_rules` |
| 编组与指令 | `test_worker_groups`、`test_team_lifecycle`、`test_command_replace`、`test_cmd_paging`、`test_battle_interaction` |
| 研究规则集成 | `test_research_rules`：三层指令、34 关开场白、1170 组武将属性、奖励/晋升边界、存读档 |
| 移动质量 | `test_movement_quality`：完整步长、避墙/避资源的直线路径、显示插值、动画节拍、队伍独立落点 |
| AI | `test_ai_planning`、`test_ai_policy`、`test_ai_slots`、`test_l1_assault` |
| 水战与载员 | `test_transports`、`test_unload_state`、`test_naval_casualty_save` |
| 战斗与弹体 | `test_projectiles`、`test_action_clock`、`test_action_lifecycle`、`test_duel`、`test_visibility_rules` |
| 导航与占格 | `test_spatial_rules`、`test_unit_footprint`、`test_unit_collision`、`test_unit_index`、`test_nav_invalidation`、`test_automatic_gates` |
| 任务与胜负 | `test_scenario_end`、`test_architecture` |
| 存档与时钟 | `test_architecture`、`test_tick_timers`、`test_clock`、`test_clock_ui`、`test_m0` |
| 界面与光标 | `test_input_research`、`test_cmd_paging`、`test_battle_interaction`、`test_hud_metrics` |
| 表现与素材 | `test_texture_states`、`test_chibil1_presentation`、`verify_full_art`、`verify_architecture_view` |
| 音频 | `test_sfx` |
| 开局数据 | `test_opening_forces.mjs`、`test_opening_forces.gd` |
| 内容与发布 | `test_content_pipeline.mjs`、`test_publish.ps1`、`test_bootstrap.mjs` |

## 6. 人工验收与候选冒烟

构建会在导出后自动对候选包运行下面的四项冒烟、全部地图加载及两档确定性基线，失败即构建失败；发布重新校验证据覆盖与产物哈希，不会把它标记为人工验收通过。画面、手感与关卡的最终验收仍由人工完成。

`release_tests.json` 的四项冒烟：

| 脚本 | 范围 |
|---|---|
| `test_m0` | 菜单、存档槽及跨关读档 |
| `test_battle_interaction` | 核心输入、选择和建筑工作入口 |
| `test_review_contracts` | 随机数续跑、存档校验与状态摘要 |
| `test_save_roundtrip` | 六个带 AI 的采样点保存、恢复及续跑摘要；字段登记、原子拒绝与生命周期 |

另以实际发行 EXE 执行绿色配置与隔离系统目录两种模式的保存、自动槽、结束进程及重启菜单读档；全部使用显式条件判定，不依赖发布版会移除的 assert。`test_world_exchange` 验证显示暂存失败回滚、稳定访问入口、旧世界释放和过期单挑票据。

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
| 自检 | `main.gd::_selftest_*` |
| 摘要 | `main.gd::_state_digest` |
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

`test_encounter_campaign`、`test_duel` 验证双方自动接战、工人队伍及工作/行军/警戒优先、隐蔽和中立过滤、34 关次序与终章边界、倒计时切换新世界、单挑合法性/接受公式/平局及胜负一次结算、自然播放和跳过。`capture_duel_review` 完整播放 28 秒影片，截取交锋/尾段/下一章界面并断言延迟结算。

### 移动

`test_movement_quality` 按 `research/movements/data/movement.json` 对照 26 个已登记兵种、208 个方向序列（包括原表重复帧），断言每两 tick 一帧、180 度转身经过相邻方向、转身不重置步态、显示插值不推进模拟时钟、拐角存读后的下一步相同，以及坏朝向快照拒收。`test_architecture --noview` 验证整世界快照的继续执行一致性。`capture_movement_review` 输出六种单位、420 帧原生高清对照。

### 单位

`test_unit_research` 汇总 26 种 canonical 属性、17 种生产费用、平民采集/交付/修理与禁止建造、混合施工队、工人费用和 100 更新训练、完整占地上下船/离岸等待/4 更新相位存档；并验证 15 支队伍选取、800 更新末清状态、混乱排队/过期跳过、滚木视野首目标士气 −50、32/45 埋伏固定 30 且可见、主将单体恢复、火场 5/9/…/97 结算/友伤/建筑/离开重入/240 上限、坏档原子拒绝和旧隐蔽字段迁移。

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
```

脚本输出逻辑每 tick 完整 `_sim_step` 的 P50/P95/P99/最大值、实际窗口 FPS、进程峰值工作集、Godot 视频内存和静态内存峰值，任一项越界即失败；`--bench-output` 或 `_work/bench/` 保留 JSON。参考机为 Intel i7-8700（6 核 12 线程，3.2 GHz）、64 GB 内存、NVIDIA Quadro P4000 8 GB、Windows 11、1920×1080、GL Compatibility。

| 场景 | 机动单位 | 交战队 | P95 预算 | FPS 下限 | 峰值工作集 | 显存上限 |
|---|---:|---:|---:|---:|---:|---:|
| 标准 | 200 | 60 | 500 ms | 60 | 2.5 GiB | 1.25 GiB |
| 压力 | 660 | 240 | 1200 ms | 30 | 3.5 GiB | 1.5 GiB |

当前参考机基线：标准 P50 122–167 ms、P95 240–420 ms（受寻路峰值影响）、548–859 FPS、0.46–0.48 GiB 工作集、0.63–0.64 GiB 显存；压力 P50 477.8 ms、P95 773.1 ms、318 FPS、0.48 GiB 工作集、0.65 GiB 显存。完整战场 P95 高于 30 Hz 的 33.3 ms 逻辑预算，因此微基准负责 800 单位的索引预算，完整基准按内容规模设定回归上限；两者都不通过放宽阈值规避失败。

`tools/test_terrain_dedup.mjs` 检查重复内容合并、不同内容保留、引用图一致、源输入溯源与越界路径在修改前拒绝；候选包另验证全部重写后的地形资源可加载。历史失败清单只保留尚未解决且已验证的条目，不将修复项继续豁免。
