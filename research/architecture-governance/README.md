# 质量基线、状态与架构治理交付

日期：2026-11-16（Asia/Shanghai）。工程起点：`23f112b7b89ebf939ee95d03ce6a82d4c3eddb27`。评审依据为 `tmp/review.md`，按本轮用户指定的 P0 → P1 → P2 → P3 顺序执行。

本文件保留首轮基线；后续六项修复与新的验收记录见 `followup.md`、`followup-acceptance.json`。

## 1. 本轮边界与交付

本轮落地质量门禁、存档可靠性、Unit Schema 首版、UI 瞬态隔离、组合根试点和端口依赖盘点。保留 Dictionary 单位模型，存档格式仍为 v8，原有确定性基线不变。端口没有做代码生成，也没有按“搜索不到调用者”批量删除接口。

实际执行记录与修复后的验收结果见同目录 `acceptance.json`。其中本地结果不能替代尚未触发的 GitHub hosted run；GPU、Windows 正式 EXE、完整打包发布和性能验收分别保留自己的入口。

本地最终验收：

| 检查 | 结果 |
|---|---:|
| 聚合静态/工具门禁 | 29 / 29 |
| 运行脚本编译与 CI 冒烟 | 4 / 4 |
| 完整开发套件（平衡分成三个互斥分组执行） | 75 / 75 |
| 发布套件 | 16 / 16 |
| 三图引擎自检 | 3 / 3 |
| 已登记确定性基线 | 2 / 2，基线文件未修改 |
| 全地图启动 | 34 / 34 |
| 存档子套件 | 5 / 5 |
| 规则身份源码 / 编译 PCK 对照 | 一致 |
| 已提交资源 SHA-256 | 627 / 627 |

## 2. P0：可信门禁

`ci_lightweight.mjs` 按架构、注册表、数据、文档、仓库和工具六组执行。单个检查的非零退出、异常或信号退出都会记录为失败，后续检查继续，最终汇总非零退出。每组机器结果写到 `_work/lightweight`。

`contracts.yml` 使用相同的分组入口，独立步骤使用 `!cancelled()`，不会被前一失败静默跳过。门禁自身覆盖“首项失败后仍执行后项”、孤儿脚本、重复条目、无理由手工排除、过期或无责任人的架构豁免。

`architecture_limits.json` 的文件预算、长函数预算和边界豁免均有 owner、reason、reviewBy。责任角色 `project-maintainers` 指本仓库维护者，由当前变更维护者负责落实复审；期限为 2027-02-16。删除了已不需要的 `save_game` 长函数预算，并将七项历史宽预算收紧到实际长度；没有放宽预算。真正解决预算项时应删除对应复审条目，延期须说明原因。

### 测试归属

当前 `tools/gd` 共 120 个脚本，含 95 个 `test_*.gd`。92 个独立脚本属于自动套件，28 个属于有明确前提的手工、打包、wrapper、fixture 或工具入口。CI/save 套件允许作为主套件的覆盖子集；主套件之间禁止重复归属。

| 套件 | 条目数 | 用途 |
|---|---:|---|
| `ci_godot_tests.json` | 4 | 编译、架构、组合根、表现诊断 |
| `save_tests.json` | 5 | 无美术的 hosted 存档、Schema、旧档和规则身份门禁 |
| `release_tests.json` | 16 | 必须通过的源码发布回归 |
| `development_tests.json` | 75 | 功能、架构、媒体、原生及新增归类回归 |
| `manual_tests.json` | 28 | 明确前提与运行方式；不计为 CI 自动通过 |

评审所说的 24 个未进入主套件的测试逐项处置如下：

| 脚本 | 归属与理由 |
|---|---|
| `test_action_clock` | development：攻击/修理相位与保存 |
| `test_building_square` | development：建筑占格 |
| `test_clock` | development：时钟与续跑 |
| `test_combat_rules` | development：战斗公式 |
| `test_economy_boundaries` | development：经济边界与坏档 |
| `test_edge_interaction` | development：相邻边缘交互 |
| `test_grain_patch` | development：整片采集与回运 |
| `test_harvest_retarget` | development：转采目标 |
| `test_hq_delivery` | development：大本营交付与占格 |
| `test_hud_metrics` | development：HUD 几何 |
| `test_l1_assault` | development：首关 AI 进攻 |
| `test_opening_forces` | development：runner 先从规格文档生成并校验 fixture，再验 34 图开局 |
| `test_scenario_end` | development：任务出口 |
| `test_sfx` | development：音效解析 |
| `test_special_units` | development：特殊兵种 |
| `test_team_lifecycle` | development：编队生命周期 |
| `test_tick_timers` | development：计时与版本迁移 |
| `test_unit_footprint` | development：单位占格 |
| `test_worker_feedback` | development：工人反馈与存读 |
| `test_presentation_diagnostics` | 已属于 CI 专属套件，保留 development 与 CI 覆盖 |
| `test_public_audio` | packaged：必须使用剔除原音频后的公共 PCK |
| `test_public_duel` | packaged：必须使用剔除原影片后的公共 PCK |
| `test_public_media` | packaged：必须验证原媒体缺席；源码目录不满足前提 |
| `test_gpu_minimap` | manual：必须使用真实 GPU 窗口与像素对照 |

归类后的实际运行还修复了开局 fixture 解析对 CRLF 的依赖，并将工人反馈测试更新为当前生产面板、HD 图标、可见载货姿态和成员命令契约，保留对生产费用、进度、加入编队和存读的断言。

此外，`test_exit_safety` 明确由 `tools/test_exit_safety.mjs` 驱动多个原生窗口退出场景；capture/verify、离线美术工具和 economy fixture 也都登记在非套件清单中，不能悄悄失去归属。

### Hosted CI 可行性与接入

push/PR 的 `ci.yml` 新增全部已登记模拟基线、34 图启动与 `save_tests`，不要求美术或导出模板；既有四图续跑保留。`release-regressions.yml` 提供显式 `workflow_dispatch`：获取 `godot/chibi_remake/**` 的 LFS 资源，按清单验证字节后运行完整 release 套件。运行资源清单为 627 个文件、约 1.087 GiB，远小于把参考图、研究源和所有制作中间件一起下载。

运行资源校验显式使用 `--versioned-only`，因为完整 staging 枚举还需要生成的地形缓存。本轮仓库没有当前完整地形缓存，完整 `runtime_assets --check --hash` 因此拒绝运行，未被记作通过；627 个已提交资源的大小、SHA-256 与白名单均已单独验证。版本化资源模式对同大小篡改和缺失字节有负向测试，完整构建检查保持原语义。

这条 hosted 发布门禁验证源码引擎下的发布套件，不认证 Windows 正式 EXE、GPU、精简公共 PCK 或打包链。后几类仍需对应环境与专门证据。本轮只配置工作流、验证本地等价入口；没有 push、触发远端工作流或发布产物。

## 3. P1：文件有效性、备份与规则身份

三个判断彼此独立：

1. `verify_save_checksum` 仅证明存在且匹配的校验和，缺失时返回 false。
2. `save_envelope.valid` 与 `Game.is_valid_save` 检查文件结构、版本、记录和旧版策略。结构合法的 v1–v7 可以无 checksum 读取，任意 `{"v":7}` 不再算有效存档。
3. `snapshot_validator` 在接触候选世界前检查当前地图、规则、科技、队列和跨实体引用。文件可读取不等于与当前规则兼容。

备份资格使用独立的 `can_rotate_save`：旧主档必须通过结构和 checksum 检查。无 checksum 的旧档即使可加载，也不能替换已验证备份，而是按原字节隔离。故障注入覆盖裸 v7、完整旧档和 checksum 正确但结构损坏的主档；强制在隔离/轮换后提交失败，断言 `.bak` 哈希不变且仍可读取。当前格式允许合法的空终局快照，避免用“非空单位列表”错误代替有效性。

规则指纹改为显式 ABI 与八类模拟数据投影。小地图、音视频、UI 布局、引擎哈希、源码清单和注释不直接参与身份；动作帧保留长度，帧号与图像路径属于表现。代码行为改变时需要显式复审 ABI、基线与迁移，`rules_manifest` 仍检查源码/导出完整性，它不是自动的语义等价证明。

旧宽指纹 `f9634e5c...` 到新指纹 `fc1e0633...` 的迁移固定了两个完整端点；历史上已批准的两个迁移也固定到新目标。新的数据平衡变化将使目标不匹配，不能自动继承许可。既有档案的完整迁移、无指纹旧档采用当前规则、未知指纹拒绝和源码/编译 PCK 身份一致均有测试。

## 4. P1：Unit Schema 与状态边界

`simulation/definitions/unit_schema.gd` 登记 118 个真实单位字段，包含类型、默认值、persist、derived、恢复组、范围/枚举以及记录键或关系编码。它同时覆盖身份、可保存标量、动作、计时、移动状态、稳定引用和可重建缓存，不等于要求所有字段入档。坐标、HP 与模板属性等上下文值继续由工厂根据地图和规则计算；Schema 默认值不取代这些派生输入，字面量初始化另与字段默认值对照。

快照按 Schema 产生标量和记录，校验器按同一类型定义检查，恢复器按同一分组和类型恢复。ActionClock 与 Locomotion 从 Schema 获取字段和默认值；TickTimers 从 Schema 获取状态与经过时间字段及上限，保留旧版秒数到 tick 的迁移。目标、路径、地形/单位引用及子系统不变量仍由专用编解码器处理。删掉了被 Schema 替代的 `snapshot_fields.gd`，没有再保留只转发字段列表的抽象。

约束分三层：工厂键、常见单位/城门写入及字面量默认值静态对照；实际快照在调试/测试引擎中拒绝未登记键；逐字段测试检查每个持久化标量确实被保存、拒绝错误类型并恢复。真实回归曾拦住遗漏的 `gate_open`，经核对后登记为派生导航状态。任意动态键表达式仍不能靠正则完全证明，新增动态路径必须增加场景样本。

`feedback_text / ev_count / sec_visible / drag_pan / selecting / sel_start / sel_end` 已从 BattleState 移到 BattleSceneState，BattleState 代理字段从 93 降到 86。反馈通过已有 effects 通道传递。待选命令、施法/单挑指针和输入执行上下文使用 RESET 策略，不深拷贝进候选；成功交换后清空拖拽、反馈和旧命令，失败回滚保留原会话。命令执行上下文仍由 simulation session 持有，不把它误当可保存规则状态。

## 5. P2：端口、组合根与试点

完整关系清单为 `tools/inputs/port_inventory.json`，由 `port_inventory.mjs` 维护并校验新鲜度。它解析 62 个端口的消费者、provider、CONTRACTS 方法、直接调用证据与边界性质。统计包含 694 个 provider 方法和额外的 135 个生命周期/装配方法；与原评审“端口方法”口径有区别。

| 分类 | 方法数 | 当前处理原则 |
|---|---:|---|
| 跨层边界 | 232 | 保留，逐步收窄命令/读模型；私有方法名另列标记 |
| 同层私有实现进入契约 | 405 | 优先重新定义能力边界，不自动改名 |
| 同层纯转发 | 57 | 结合真实生命周期、动态调用和热路径证据决定删除/直连 |
| 生命周期与模块能力 | 135 | 明确所有者，避免与业务转发数混算 |

263 个转发方法没有在“直接字面量消费者”里命中调用。这不等于没有调用者：信号、Callable、继承和命令适配器会绕过这个搜索口径，不能据此批量删代码。重复业务逻辑采用人工核对，本轮选择 AI facade 的三个静态规则作为归并试点：规则只保留在 `ai_decisions.gd`，三个仍被测试或外部调用的入口委托到它，`ai.gd` 从 228 行降到 165 行。

### 服务清单与唯一所有者

| 所有者 | 服务/对象 | 正常启动与候选 |
|---|---|---|
| BattleState（由 World 创建） | session、effects、clock、nav、visibility、simulation_rng、automatic_gates | 每个世界独立实例 |
| BattleWorld | economy、projectiles、fire_fields、transports、harvesting、construction、stratagems | 同一构造路径，`new(world)` |
| BattleWorld | command_rules、player_commands、rules、ai | 已移出 bootstrap/candidate 的重复构造；统一 `new(world)`，AI 可显式关闭 |
| BattleWorld | 22 个 `simulation/battle` 行为模块 | 统一 `new(state)`，具体列表在 composition 清单 |
| BattleWorld | 11 个领域 access 对象 | 每个世界独立，持有该世界状态 |
| main / app | bootstrap、scene_controller、cheat_controller、duel_controller、稳定命令端口、command_pump | 场景适配；候选不创建场景服务或命令泵 |
| BattleSceneState / view | saver、view、camera、BGM、SFX、art 与 HUD 生命周期 | 候选只创建无视图的 save adapter；画面暂存/提交由原场景负责 |
| 进程 | MathKernel 原生提供者 | 进程退出时释放；世界激活/失效管理 native port，不归 UI 所有 |

`prepare_map` 统一 nav/visibility 初始化。候选先取得不可变定义的私有副本，再恢复可变状态；世界安装后才连接当前场景效果与 native port。现有不可变 `world.definition` 与可变 `state.map_data` 的双重表达仍保留，后续应将地形覆盖单独建模，禁止借此试点重写所有服务。

### 明确下一阶段依赖方向

- simulation 只依赖 domain definitions、状态和领域能力；不导入 app/presentation，不保留场景节点。
- app 的存档、命令、流程用例依赖 simulation 能力；只有场景装配/生命周期适配层可以创建表现节点，普通用例不访问表现私有状态。
- presentation 读取投影/窄查询，修改通过 app/session 命令；可以使用不可变的 definitions，不导入可变 BattleState/BattleWorld 或领域系统实现。

本轮删掉了 read model 中无调用者的 saver 暴露。units、selected、map_data、nav 和部分服务仍是借用的可变引用，文档已如实声明；下一步采用按帧缓存的 UID 读投影、选择 UID 列表、导航查询能力与命令输入 UID 化，避免每个 getter 深拷贝全场字典带来的性能成本。需先保留对象身份相关的视觉/命令验收，再迁移一个组件试点，不能直接把全部 getter 换成深拷贝。

Game 的后续拆分边界为 SnapshotCodec、SaveRepository、SlotCatalog、CampaignSession 和应用生命周期适配。当前已经抽出独立文件有效性模块，但尚未宣称消除了 Game 全局对象。

## 6. P3 后续工作

依次评估资源片采集 A*、AI 建筑/工人索引、被堵单位重寻路预算、构建发布工具清理和发布证据的 harness 哈希绑定。需要正式工作负载的前后性能证据；本轮不更改性能预算，不用确定性基线更新消除差异，也不把源码回归当正式 EXE/性能验收。

后续读模型盘点、建造预览迁移和验收记录见 `battle-access.md`、`read-model-acceptance.json`。

资源层后续迁移及独立验收记录见 `battle-resources.md`、`resources-acceptance.json`。
