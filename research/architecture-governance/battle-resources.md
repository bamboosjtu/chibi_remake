# BattleResources 只读值投影迁移

日期：2026-11-16，Asia/Shanghai。本轮接续工作区中尚未提交的建造预览迁移，保留其实现、文档和独立验收记录；本轮结果记在 `resources-acceptance.json`。

## 已迁出的借用

资源层删除 entries、last_rect、last_revision，改为只保存冻结的值键、可见投影和表现层拥有的精灵。它不读取 map_data/nav/decor_cells，BattleAccess 的 decor_cells 借用 getter 也已删除。frames 来自表现层图集元数据，不是世界数据，本轮保留该表现资源生命周期。

`resource_layer_key(viewport)` 返回五项值：world ID、nav ID、resource_revision、geometry_revision、Rect2。`resource_layer_projection(viewport)` 返回递归冻结的描述数组，每个描述严格只有 index、anchor、phase。只投影与原 44×60 资源矩形相交的条目，保留原索引和 phase 默认规则，不把 alive=false 的残留画法错误地过滤掉。

没有缓存源 decor 数组、资源对象或 nav。公开结果没有 Object/Callable/Packed 数组，输出按字段白名单创建。保留旧投影不会保留旧世界，也不能通过修改副本影响原投影或源资源。

## 更新与成本

未变化帧只创建并比较常量大小的值键，不扫描地图，不复制资源记录，不创建精灵。回归跨三个暂停帧重复调用 60 次，确认模型对象和重建计数不变。

世界/资源/几何/视口变化时扫描当前 decor，只分配可见描述，再与 active 精灵集合协调。当前扫描复杂度仍为 O(地图 decor 数量)，分配为 O(可见数量)，没有将全地图深拷贝或构建整张地图的每帧快照，也未认证空间索引或正式帧预算。普通 nav.version 的阻挡变化不改变资源画法，因此不进入键。

phase 变化后重建相应画法；图集 phase 5 表示空矿，移除旧精灵并跳过绘制。相同 index/phase 可以复用精灵，但每次键变化仍更新位置与深度，防止世界替换或几何变化后留在旧坐标。

资源布局在一个世界内按定义保持稳定；测试/编辑器若直接改 decor，必须提升 resource_revision。该缓存不是任意字典写入的通用追踪器。

## 回归覆盖

- 固定三字段、递归只读、纯值叶子以及修改副本的隔离。
- 视口进出、空视口、同 phase 几何重定位、无关阻挡变化的缓存复用。
- 部分采集不改变画法；0→1、2→3、4→5 耗尽阶段正确，旧画法精灵释放。
- 候选世界实际成为查询来源，然后回到原世界；保留候选投影时候选 World/nav 仍释放。
- 真实读档在 attach 后强制失败并回滚，原状态摘要和原投影不变。
- 修改旧世界的 decor 数组后成功读档，强制全部非身份键值相同，仍重建新世界投影。
- 同 index/phase 精灵跨世界复用时必须重新定位；相同 BattleAccess 实例读取新的世界。
- 保留旧投影直到关闭战场，BattleState 的 WeakRef 仍释放。
- owner 已释放后的两个新查询必须请求非零退出，并安全返回空值，无 SCRIPT ERROR。

## 治理与范围

清单 schemaVersion 2 增加 decor_cells。相较本轮开始的四入口清单 40 处，map_data/nav 的两处访问已消除，四入口剩余 38 处；新增纳入扫描的 decor_cells 原有一处，也已消除。当前五入口合计 38 处、10 个消费者，其中 2 处属于软件光标直接访问场景 facade，余下 36 处来自 BattleAccess host。清单仍是字面量线索，不解析完整接收者身份、别名、动态键或命令返回对象。

相机、建造预览和资源层都有防止重新直接借用的门禁；资源字典也纳入边界深拷贝禁止规则。未迁移的 HUD、命令、单位渲染、minimap 等接口仍保留，未宣称完成全部 BattleAccess 治理。

最终本地验证和日志哈希见 `resources-acceptance.json`。模拟代码、规则数据和基线文件不变；未触发 hosted CI，也不把源码回归算作正式 EXE/GPU 像素或性能认证。

最终本地验收：静态/工具 31/31，发布 21/21，相关功能 8/8，资源专项 1/1，编译/组合 5/5，生命周期/无效组合负向场景 14 个均通过。
