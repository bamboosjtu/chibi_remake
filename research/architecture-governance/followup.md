# 存档完整性与边界治理后续交付

日期：2026-11-16，Asia/Shanghai。本轮按用户指定的六项顺序推进；首轮证据保留在 `acceptance.json`，本轮最终结果单独记录在 `followup-acceptance.json`。

## 1. v8 必需字段完整性

`SaveEnvelope.valid_collections` 成为文件读取、SaveService 内存快照入口、SnapshotValidator 和候选恢复共用的版本策略。v8 必须有 resources 对象、全部四种有限非负资源，以及显式 Array 类型的 trainings；空队列用 `[]` 表达。checksum 正确不能弥补结构不完整。

v1–v7 保留原兼容约定：缺队列表示无生产；资源缺省沿用恢复种子值，v1–v3 的种子来自地图，v4–v7 的种子来自候选输入。这是显式旧版策略，不适用于 v8。生产和研究的 cost 字典仍可只列支付的资源，不能把通用 `_valid_cost` 全面改成四键必填。

恢复资源时，v8 直接读取已验证的四键，不再借用当前值兜底。恢复生产前先确认队列形状，避免先清空再返回。九个正确 checksum 的故障夹具分别删除整组字段、删除每一种资源、置入错误队列类型；文件读取和内存应用均拒绝，原世界对象、资源和生产快照保持不变。测试另验证 v7 的合法缺省。

## 2. Unit Schema record 组

序列化映射与恢复读取共用 `UnitSchema.record_value`。SaveService 中的位置、HP、alive/state/die_t、officer 身份读取，以及 Restorer 的 UID、地图对象身份读取，都从 Schema 取得线格式键；生命归一、尸体、武将解析等语义保留在原恢复路径。

`test_unit_schema` 遍历全部 13 个 record 字段，使用真实候选世界恢复后重新序列化逐项对照，同时对每个字段注入错误类型。用例包含稀疏 UID、非默认地图索引、死亡/负 HP、阵营/兵种、武将身份及位置。新 record 字段进入 Schema 后也进入循环；未落实恢复会使对照失败。持久化字段不应仅靠同一套 getter/setter 的直接往返测试。

## 3. BattleWorld 封装

正常场景与候选都通过 `connect_services(label, access_overrides, application_services, activate_native)` 连接。World 在内部复制并组合服务集合，候选只传应用命令适配器，安装前不激活 native port。`seed_map_units` 统一正常启动和旧档种子的地图实体构造。

运行代码不再访问 `world._modules/world._access`；架构门禁对回退到这些访问有负向测试。诊断用 `module_view()` 返回只读集合副本，修改副本不能更换 World 的成员。模块对象仍用于诊断与剖析，这不等于所有服务对象变成不可变值，也不是 GDScript 的语言级私有保障。

构造协议明确保留两种：领域系统 `new(world)` 取得能力接口，22 个行为模块 `new(state)` 取得领域状态。是否统一作为后续架构决策，不因本次集合封装重写所有系统。

## 4. BattleAccess 相机试点

整个 camera_controller 已移除对 units、selected、map_data、nav 的直接借用。它通过三个值查询获得地图边界、开局中心、瓦片几何；Vector 返回值脱离世界对象，调用者修改副本不会影响模拟。

开局中心保持原浮点累加口径，只在初始化查询时扫描单位；逐帧夹边只取边界值，不深拷贝全场字典。测试验证值隔离、世界数据变化后读取新值、开局筛选和空军队退回地图中心；现有 HUD 边界和交互回归继续检验实际相机。其他表现组件的可变引用保留为后续迁移范围。

## 5. SnapshotValidator 拆分

prepare 从 217 行减为 18 行，负责阶段编排。单位记录与索引、地形、归属/编组/武将、生产、科技/研究、单位状态、全局服务/时钟各有独立校验阶段，最长阶段函数为 55 行。保持原校验条件及共享的生产/研究占用表，避免抽取后丢失跨队列冲突约束。

Restorer 也把实体恢复和画面同步分离，两个长函数豁免随之删除，没有扩大预算。七阶段故障矩阵验证各阶段仍被执行，并核对拒绝后的世界身份和完整摘要不变；资源/生产必需字段由前置版本门禁覆盖。

## 6. Game 职责拆分

| 所有者 | 已迁出职责 |
|---|---|
| SaveRepository | 存储对象、路径与槽地址、保存准入、提交错误、写事务、旧目录迁移 |
| SlotCatalog | 注入读取器的槽位元数据缓存、槽列表和有效档查询 |
| CampaignSession | 当前战役、待加载槽、启动消费状态、章节目录、下一关和会话推进 |
| Game | autoload 兼容接口、现有编解码、字体/启动与场景切换适配 |

Game 从 375 行降到 311 行。保留公开 API 避免一次性改写所有消费者；数据和决策已有唯一服务所有者。Repository 的成功写入事件使 Catalog 失效，涵盖同长度、同一时间粒度内的元数据更新；Catalog 不返回自己的缓存对象。原有外部文件替换检查仍保留。

服务测试不需要战场：分别验证独立 Repository、注入读取器、受保护写入、缓存隔离与失效、独立 CampaignSession。Game 仍保留编解码与场景适配，不宣称消除了全部全局入口。

## 7. 端口清单的方法论

清单升级为 schemaVersion 2，原 `directCallers` 改名为 `nameMatches`，明确 `receiverResolution: unresolved` 和 `safeForAutomatedDeletion: false`。

当前 694 个 provider 方法中，264 个没有名称命中；这个数字比首轮变化是地图播种进入 World 后的静态检索变化。正命中也可能属于其他接收者，零命中也可能经信号、Callable 或继承调用。分类和名称命中只用于选择复审对象，本轮没有依据该清单自动删除端口。

## 验证范围

最终机器结果、源码上下文和日志哈希见 `followup-acceptance.json`。本轮运行发布/自检、完整开发回归、确定性基线、编译与组合契约，并检查新服务、record 字段、必需字段和相机试点。未更新确定性基线。hosted CI、正式 EXE/GPU/完整地形 staging 与性能认证仍与本地源码回归分开报告。
