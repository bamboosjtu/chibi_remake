# 评审复核与修复结果：《三国赤壁 · 高清重制》

复核基准：`be52402`；2026-11-06。以下为本轮修复结论；文末保留原评审的修复前快照，便于核对证据。原评审中的“当前仍然存在”仅指原快照，不代表修复后的状态。

| 项目 | 复核结论与处理 |
|---|---|
| D1 | 属实。取消 212 个扁平命令转发，改为六个领域命令端口，全部进入组合根的 `wire` 与静态组成清单；候选恢复复用相同工厂及契约。当前共检查 62 个端口、682 个提供者方法要求。缺失提供者及方法均有引擎负向用例。 |
| D2 | 属实。所有真实包装方法先取得并检查提供者，失效时记录契约错误、请求退出码 1，并从当前包装方法返回类型对应的空结果；不再在 `quit()` 后解引用 null。运行时负向测试直接调用生产包装方法，要求没有二次脚本错误。 |
| D3 | 属实。静态清单与 main/view/menu/nav 实际工厂声明交叉校验；运行时严格比较服务集合和脚本路径。新增、删除或替换提供者的负向测试均拒绝通过。 |
| D4 | 属实。删除恒空 `conflicts`、死参数及恒真断言，保留实际缺失依赖断言，并修正相关注释。 |
| D5 | 属实。读模型在战斗子树内持有场景状态和命令端口，数据 Node 使用统一受检弱引用。跨关时取消已退出场景的延迟地形初始化；正常关闭不会触发过期访问，意外访问有一致诊断。反复读档释放与跨关回归通过。 |
| D6 | 属实。含非 ASCII 的 PowerShell 脚本使用 UTF-8 BOM，新增编码门禁和负向测试；发布锁测试改按内层异常 HResult 32/33 判断，不依赖消息语言。Windows PowerShell 5.1 解析及锁用例通过。 |
| D7 | 属实。宽命令面拆为科技、经济、军事、指令、世界、会话六域，`battle_commands` 从 517 行降为 14 行，读模型从 349 行降为 253 行且不再转发命令。主场景及候选不再使用裸 `_modules[...].method()` 业务调用。六类状态显式登记 `PROXY_FIELDS`，代理读写仅接受白名单，未知字段产生诊断；静态门禁验证白名单与字段声明一致。所有直接调用及按钮回调均迁移。 |
| D8 | 属实。`ai_decisions` 统一引用 `ai_config` 的全部共享常量，包括计划映射，不改变数值。原 15/60 秒确定性摘要保持通过。 |
| D9 | 属实。从独立历史 q78 传输缓存提取 35,664 个哈希，并逐项与源素材重建产物核对后固化为受控清单；配套记录 34 图几何摘要、源输入身份和历史清单哈希。CI 检查声明及负向用例，正式构建检查生成字节与几何。打包安全、发布/回滚及锁测试接入 Windows CI 入口。轻量 CI 不宣称完成了完整烘焙。 |
| D10 | 属实。候选验证改用 OS 独占文件句柄，强制结束后可重新取得锁；调试引擎使用唯一文件名，遗留文件不阻塞验证、不进入产物验收清单。并发拒绝、残留文件、强制终止恢复及发布排除遗留引擎的测试通过。 |
| D11 | 属实。缓存键包含实际引擎 SHA-256，并写入构建记录；同版本不同引擎字节产生不同键。Windows/Linux 微型实际烘焙验证冷构建、命中、失效、损坏、中断、锁及缺失输入拒绝。 |
| D12 | 倍率计算成立，但不是已确认的玩法缺陷：`docs/02` 与 `docs/14` 已明确保留原作 100/50/30/20 ms 周期。补充 1/3、2/3、10/9、5/3 倍率和默认“快”为 10/9 倍的说明，保留现有节奏。 |
| D13 | 部分属实。删除未使用的 `save_path`、失效 JPG/JPEG LFS 规则并更新旧命名注释。`-SkipImport` 在原 `docs/18` 已有兼容说明，原评审此处过时；继续保留兼容参数，并新增弃用警告，避免静默无效。 |

本轮验收：

- 源码引擎回归最终 91/91 通过：发布清单 4 项、开发清单 48 项、三个关卡自检、两项原确定性基线、34 图加载。初轮发现的按钮回调、旧能力标识断言和跨关延迟初始化问题均已修复并定向复测；原失败日志保留，复测覆盖关系见 `_work/review/final-results.json`。
- Windows 和 Linux 的三项 CI 引擎冒烟通过；四个根的运行时组成与静态清单一致；7 个生产路径负向用例均以 1 退出且没有 `SCRIPT ERROR`。
- `ci_lightweight`、分层及传递依赖、组成覆盖、属性白名单、文档、编码与负向门禁通过；没有新增架构豁免，也没有修改模拟基线或性能预算。
- 历史地形完整比较通过：34 图、35,664 个分块哈希及几何/LOD 一致。微型冷烘焙在 Windows/Linux 均通过；本轮没有重新冷烘焙全部 34 图。
- Windows PowerShell 5.1 下打包安全、发布/回滚、启动器锁及候选锁强制终止恢复通过。测试仅使用隔离夹具；发布与分卷仍不要求签名。

本轮交付为源码、构建门禁与验收记录；尚未重新导出本轮改动的发行 EXE/PCK，也未进行真人试玩。

---

# 原始评审（修复前快照）

# 架构缺陷清单：《三国赤壁 · 高清重制》

| 项 | 值 |
|---|---|
| 快照 | HEAD `dd740f0`，工作区干净 |
| 范围 | **仅列当前仍然存在的缺陷**；已解决的问题、设计优点与历次对照不在本文件内 |
| 既定约束 | 原作素材随包分发（复现所需），不计为缺陷；本文件不涉及素材取舍 |
| 规模 | 2,501 个跟踪文件；199 个 `.gd` / 24,284 行；56 个端口 / 223 条 provider 边 / 465 个受检方法 / 678 处 `_require` |
| 验证方式 | 静态阅读 + 实际执行门禁 + 引擎内运行 + 两个定向探针；未执行完整构建与真人试玩 |

严重度：**高** = 已产生静默错误或可致发布物失效；**中** = 保障机制有缺口或行为与声明不一致；**低** = 卫生问题或明确的局部错误。

## 缺陷索引

| # | 缺陷 | 位置 | 严重度 |
|---|---|---|---|
| D1 | 最大的分发面（212 个转发，占 31%）完全在契约体系之外 | `app/battle_commands.gd` | **高** |
| D2 | `_require` 的"中止"不中止当前帧，且负向测试未覆盖真实调用 | `named_port.gd` / `test_registry_runtime.mjs` | **高** |
| D3 | 静态组成清单与运行时组成无交叉校验 | `tools/inputs/composition.json` / `registry_check.mjs` | 中高 |
| D4 | `conflicts` 恒空仍被断言，形成 5 处恒真断言与一个死参数 | `composition_contract.gd` / 两个测试 | 中 |
| D5 | 生命周期语义不一致：端口 fail-stop，表现层 110 处解引用零判空 | `presentation/**` | 中 |
| D6 | PowerShell 编码使 `test_publish.ps1` 的中文分支在 CP936 下失效 | `tools/*.ps1` | 中 |
| D7 | 仍并存 4 套派发机制，两个宽口 facade 达 517/349 行 | `app/` / `presentation/` | 中 |
| D8 | AI 调度常量两处逐字重复且互不引用 | `ai_config.gd` / `ai_decisions.gd` | 中低 |
| D9 | 三个测试工具无人调用，"可重建等价"无自动证据 | `compare_terrain_rebuild.mjs` 等 | 中低 |
| D10 | 候选冒烟残留锁无恢复路径，且错误信息误导 | `verify_candidate.ps1:13` | 低 |
| D11 | 地形缓存键不含引擎哈希，换引擎会复用旧分块 | `build_terrain.mjs:20` | 低 |
| D12 | 速度档周期与固定步长不对齐，默认档实际 1.11× | `battle_clock.gd:3-5` | 低 |
| D13 | 死参数、死代码、失效规则与命名残留 | 多处 | 低 |

---

## D1（高）212 个转发在契约体系之外

**现象。** `app/battle_commands.gd`（517 行、214 个 `func`、212 处 `_require`、26 个 provider）承担了全部端口调用的 **31%（212/678）**，但它与其余 56 个端口有本质差异：

| 检查项 | 其余 56 个端口 | `battle_commands.gd` |
|---|---|---|
| `const CONTRACTS` | 有（223 条边 / 465 方法） | **无** |
| 在 `composition.json.ports` 中 | 是（56 个） | **否** |
| `connect_services()` 校验方法存在 | `has_method` 逐条检查并返回 `missing` | **裸索引，无校验** |
| 缺失时进入 `wire` 报告 | 是 | 否（返回 `void`） |
| 静态检查覆盖 | `registry_check.mjs:25-38` | 仅反向校验调用方，见下 |

**证据。**

```gdscript
# app/battle_commands.gd:441-443
func connect_services(services: Dictionary) -> void:
    _provider_cheat_rules = weakref(services["cheat_rules"])   # 缺键即运行时报错
```

```gdscript
# main.gd:94 —— 返回 void，缺失既不上报也不进入 wire 的 missing
commands.connect_services(_modules)
```

`registry_check.mjs:40-41` 只校验了 `battle_access.gd` 的 60 个命令名能在 `battle_commands` 中找到，**没有反向校验 `battle_commands` 的 212 个转发目标是否存在**。

**影响。** 两种失效都只在运行期暴露：
1. provider 缺失 → 裸字典索引抛 `Invalid get index`，绕过了统一诊断；
2. 方法改名 → `_require` 通过（provider 存活），调用时才炸；212 个方法中多数位于低频路径，回归未必覆盖。

**建议。** 补 `CONTRACTS`（可按 provider 分组，从 `_require` 调用点脚本生成）；`connect_services()` 改为 `has_method` 校验并返回 `missing`；`main.gd:94` 收集后并入 `wire` 的报告；把该文件加入 `composition.json.ports`。

**验收。** 删除任一 provider 的方法 → 启动即 `explicit port contract failed`；`node tools/registry_check.mjs` 报红。

---

## D2（高）"中止"不中止当前帧，负向测试绕开了真实路径

**现象。** `named_port.gd:3-6` 在 provider 失效时调用 `abort_if_broken`，后者的实现是 `push_error` + `SceneTree.quit(1)`（`composition_contract.gd:26-30`）。`quit()` 只请求退出，当前调用栈继续执行，于是 `_require` 返回 `null`，紧接着 `null._method()`。

**证据（探针实测）。** 用真实调用点 `technology_dependencies._feedback("boom")` 且 provider 缺失：

```
PROBE connect_services missing=[{"method":"_feedback","provider":"battle_simulation"}]
ERROR: expired port: explicit port contract failed: [{"method":"provider lifetime","provider":"battle_simulation"}]
SCRIPT ERROR: Invalid call. Nonexistent function '_feedback' in base 'Nil'.
    at: _feedback (res://simulation/ports/technology_dependencies.gd:6)
```

即一次契约失效打印**两条**错误，第二条是误导性的空指针，且该帧剩余逻辑仍以 null provider 继续。

**同时暴露测试缺陷。** `tools/test_registry_runtime.mjs` 的 `expired` 用例直接调 `_require` 而**不调用任何包装方法**：

```javascript
expired:'var port=preload("res://named_port.gd").new()\n\t...\n\tport._require(reference,"expired")'
```

因此它的 `assert.doesNotMatch(result.output, /SCRIPT ERROR:|Parse Error:/)` 能通过；真实调用点会违反该断言。**这条断言目前不代表生产行为。**

**建议。** 二选一并写进 `docs/14`：
- 若"停"是硬要求：改用能真正终止的手段（`assert` + 崩溃式终止），或让包装方法统一 `var p = _require(...); if p == null: return <默认值>`；
- 若只需"记录并退出下一帧"：把措辞改为 requesting shutdown，并把 CI 断言改为"两条错误都出现"。

无论选哪个，把 `expired` 用例改为调用真实包装方法，使测试与生产同路径。

---

## D3（中高）静态清单与运行时组成没有交叉校验

**现象。** `tools/inputs/composition.json`（31 KB）是静态检查的世界模型：`hosts[label]` 给出每个服务对应脚本，`ports` 列出 56 个受检端口。**没有工具生成它**（全仓仅 `registry_check.mjs:6` 读取），也**没有工具校验它与 `battle_world.gd` / `main.gd` 的实际 `preload` 一致**。

`--runtime-log` 模式（`registry_check.mjs:14-22`）虽已接入 `ci.yml`，但只判空：

```javascript
if(!report?.[name]||report[name].missing.length||report[name].conflicts.length)throw Error('Invalid '+name);
```

而 `composition_contract.gd:22` 已经把每个根的 `services`（键 → 脚本路径）写进报告 —— 也就是说，可比对的数据已经具备，只是没有比。

**影响。** 往 `battle_world.gd` 新增服务而忘记更新清单 → 该服务退出静态检查覆盖范围，且无任何提示。实测当前两侧一致（main 26/26、menu 5/5、nav 2/2、view 12/12），故现阶段是**潜伏缺口**而非已发生错误。

**建议（约 10 行）。** 在 `--runtime-log` 分支对每个根比较 `Object.keys(report[name].services)` 与 `Object.keys(manifest.hosts[name])`，并比对脚本路径；不一致即失败。

**验收。** 只在 `battle_world.gd` 增加一个服务、不更新清单 → CI 报红。

---

## D4（中）`conflicts` 恒空却仍被断言

**现象。** `composition_contract.gd:22-23` 把 `conflicts` 硬编码为空，并把空数组传下去：

```gdscript
reports[label] = {"services": scripts, "owners": required, "methods": required.keys(), "conflicts": [], "missing": missing}
abort_if_broken(label, [], missing)
```

**证据。** 仍在使用该字段的位置：

| 位置 | 性质 |
|---|---|
| `main.gd:92`、`menu.gd`、`battle_view.gd`、`nav.gd` | 保存 `registry.conflicts`，恒 `[]` |
| `tools/gd/test_component_registry.gd:17,20,23,29` | 4 处 `assert(..._api_conflicts.is_empty())`，**恒真** |
| `tools/gd/dump_composition.gd:15` | `assert(reports[label].conflicts.is_empty() ...)`，**恒真** |
| `composition_contract.gd:26` | `abort_if_broken(label, conflicts, missing)` 的 `conflicts` 形参 |

同文件 `test_component_registry.gd:2-3` 的注释仍称 "must not lose a service to a duplicate method name"——该检查已随机制删除。

注意：同一批断言里的 `_api_missing.is_empty()` **是有效断言**（`missing` 为真实收集结果）。问题只在一半。

**影响。** 5 处断言永远为真，读者会误以为"重名冲突已被测试覆盖"。

**建议。** 删除 `conflicts` 字段与形参（`abort_if_broken(label, missing)`）；删除 4 处失效断言、保留 `missing` 断言；更新注释。

**验收。** `grep conflicts` 在测试与宿主中只剩 0 处断言。

---

## D5（中）生命周期语义不一致：端口 fail-stop，表现层裸解引用

**现象。** 端口层对 678 处调用做了 `_require` 保护（虽有 D2 的问题，至少有意识）；表现层则没有任何统一保护。`presentation/battle/battle_access.gd` 共 349 行，含 **110 处 `get_ref()` 解引用（39 处 `_data` + 11 处 `_scene` + 60 处 `_commands`），判空次数为 0**：

```gdscript
# presentation/battle/battle_access.gd:12-13, 24
var commands: RefCounted:
    get: return _commands.get_ref()
...
func handle_cheat_input(event: InputEvent) -> bool:
    return _commands.get_ref().handle_cheat_input(event)
```

**影响。** 同一工程两套生存期语义，且未文档化：端口层失效 → 请求退出（并产生 D2 的二次错误）；读模型层失效 → 空指针。排障时无法从现象判断属于哪一类。

**建议。** 选定一条规则（例如"场景子树内强引用，跨层 weakref 统一经 `_reader()` 检查"）并写入 `docs/14`；至少给 `battle_access` 的 `_data` / `_scene` / `_commands` 三个 getter 统一失效处理。

---

## D6（中）编码使锁消息分支在中文 Windows 上失效

**现象。** `tools/*.ps1` 混合编码：4 个带 BOM，14 个无 BOM，其中 5 个含中文。Windows PowerShell 5.1（本项目文档声明的支持环境）对无 BOM 文件按 ANSI 代码页解码，zh-CN 下为 CP936。

**证据。** `test_publish.ps1:157`：

```powershell
catch { if ($_.Exception.Message -notmatch 'being used by another process|另一个进程|正由另一进程') { throw } }
```

按两种编码实际解码同一串：

```
UTF-8 : 'being used by another process|另一个进程|正由另一进程'      → 2 个 |
CP936 : 'being used by another process|鍙︿竴涓繘绋媩姝ｇ敱鍙︿竴杩涚▼' → 1 个 |
```

第二根竖线被多字节字符吞掉，三个分支塌成两个，**中文锁消息分支永不匹配** → 该用例在中文 Windows 上会误抛。同类无 BOM 且含中文字面量的还有 `ci_windows.ps1`、`cleanup_project.ps1`、`publish_release.ps1`（后两者中文多在注释，风险较低）。

**影响。** 不是显示问题：一个功能性正则失效，且 CI 只做语法解析，不校验编码。

**建议。** 给 4 个含中文字面量的脚本补 UTF-8 BOM；在 `ci.yml` 的 PowerShell 解析步骤后加一条"含非 ASCII 的 `.ps1` 必须带 BOM"的检查，防止下次重构退回。

**验收。** 在 zh-CN 的 PowerShell 5.1 下运行 `test_publish.ps1` 的锁用例通过。

---

## D7（中）仍并存 4 套派发机制，两个宽口 facade 未拆分

**现象。** 端口的引入没有消除其余分发路径：

| 机制 | 规模 | 可静态追踪 |
|---|---|---|
| `_require(_provider_x,"x").m()` | 678 处 | 是（provider 显式） |
| `_modules["key"]._method()` | `main.gd` 5 处 + `candidate_world.gd` 15 处 | 是（key 为字面量） |
| `_get/_set` 属性代理 | 5 个根（`main.gd:99-111` 等） | **否**（属性名运行期解析） |
| 宽口 weakref facade | `battle_commands.gd` 517 行 / 212 成员；`battle_access.gd` 349 行 / 110 成员 | 部分 |

**证据。** `app/battle_commands.gd` 已超过 `architecture_limits.json` 中"其余运行脚本 600 行"预算的 86%，且是最大文件；`presentation/battle/battle_view.gd` 448 行同时是第二个组合根与读模型持有者。

**影响。** 改动一个方法名需要在契约、包装方法、facade 三处同步；`_get/_set` 的属性名不受任何检查，拼错即静默返回 `null`（`main.gd:99-102`）。

**建议。** `battle_commands` 按域（经济 / 军事 / 科技）拆为 3 个 facade，每个回到 150 行量级；`_get/_set` 收紧为白名单并在文件头登记允许字段。

---

## D8（中低）AI 调度常量两处逐字重复

**证据。**

```gdscript
# simulation/systems/ai_config.gd:1-3
## Deterministic AI constants shared by the facade and its state.
const THINK_PERIOD := 41          # DAT_00485648[owner] -> 0x28
...
# simulation/systems/ai_decisions.gd:5-10 —— 同一组常量，未 preload ai_config
const THINK_PERIOD := 41          # DAT_00485648[owner] -> 0x28
```

**影响。** 两处独立定义（`ai_decisions.gd` 并不引用 `ai_config.gd`），改一处忘另一处会静默改变调度周期；确定性基线只覆盖 chibic1 的 15/60 秒，未必能发现。

**建议。** `ai_decisions.gd` 改为 `const C = preload("res://simulation/systems/ai_config.gd")` 并引用，删除重复声明。

---

## D9（中低）三个测试工具无人调用，"可重建等价"无自动证据

**证据。** 全仓检索无引用：

| 工具 | 用途 | 现状 |
|---|---|---|
| `tools/compare_terrain_rebuild.mjs` | 证明从 `source/terrain` 重建的分块与历史产物等价 | 默认入参指向 `_work/remediation/before/runtime_assets.sha256`、`_work/build/terrain-cache/jpeg-q78-v1`（`compare_terrain_rebuild.mjs:3-6`），二者均在 `.gitignore` 的 `_work/` 下，**新克隆不存在**；无 CI/脚本调用 |
| `tools/test_package_safety.ps1` | 验证打包脚本拒绝危险输出目录 | 未接入 `ci_windows.ps1` |
| `tools/test_publish.ps1` | 发布/回滚/锁用例 | 未接入任何入口 |

**影响。** "地形重建与旧产物等价"目前无法在新克隆上复现，只能依赖本机历史目录；两个已写好的安全测试不产生门禁价值。

**建议。** 把等价快照提升为仓库内受控输入（如 `tools/inputs/terrain_equivalence.sha256`），并将 `compare_terrain_rebuild` 接入 `contracts.yml`（只需源文件与清单，无需引擎）；`test_package_safety`、`test_publish` 接入 `ci_windows.ps1`。

---

## D10（低）候选冒烟残留锁无恢复路径

**证据。**

```powershell
# tools/verify_candidate.ps1:13
if (Test-Path -LiteralPath $engine) { throw 'Candidate smoke engine already exists; another smoke may be running' }
```

脚本末尾有 `finally` 清理，因此常规失败不会留下残留；但**强制终止（任务管理器结束、断电、CI 取消）**会留下 `_validation-engine.exe`，此后每次构建都在此门失败，且错误信息暗示"可能有另一个冒烟在运行"——无法区分残留与正在运行。

对照：`build_terrain.mjs:25-31` 对同一问题做了正确实现（写入 PID，用 `process.kill(owner,0)` 判活，`ESRCH` 时清理后重建）。

**建议。** 沿用 `build_terrain.mjs` 的判活逻辑；无法判活时给出"删除该文件后重试"的明确指引。

---

## D11（低）地形缓存键不含引擎哈希

**证据。**

```javascript
// build_terrain.mjs:20
const common=digest(Buffer.concat([...Buffer.from('Godot4.7.2/scale4/q95-q78/LOD4-2-1')]));
```

缓存键由源清单 + 烘焙脚本 + 字面量版本串构成，**不包含引擎二进制哈希**。

**影响。** 换用同版本号但不同的引擎构建（例如自定义编译、不同补丁）时，缓存判定为有效并复用旧分块，产物与烘焙行为可能不一致且无提示。

**建议。** 把引擎二进制的 SHA-256 并入 `common`（或并入版本串）。

---

## D12（低）速度档周期与固定步长不对齐

**证据。**

```gdscript
# simulation/systems/battle_clock.gd:3-5
const PERIODS := [0.1, 0.05, 0.03, 0.02]
const LABELS := ["慢", "中", "快", "最快"]
var speed_index := 2
```

固定步长 `SIM_DT = 1/30 ≈ 0.0333`（`simulation/battle_config.gd:78`）。加速循环每消耗 `period()` 的墙钟时间推进一步 `SIM_DT`，于是四档的实际"模拟时间 / 墙钟时间"为 **0.33 / 0.67 / 1.11 / 1.67**，默认档（index 2）比真实时间快 **11.1%**。

**影响。** 若设计意图是"默认档 = 1×"，则全部档位偏移且默认偏快；确定性摘要不受影响（按 tick 推进），只影响节奏与观感。

**建议。** 明确档位语义：要么把 `PERIODS` 对齐到 `SIM_DT` 的整数倍/倒数（如 1/2、1、2、3 倍 → `2/30, 1/30, 0.5/30, 0.333/30`），要么在文档中说明档位是相对于 `SIM_DT` 的近似倍率。

---

## D13（低）死参数、死代码、失效规则与命名残留

| 项 | 位置 | 说明 |
|---|---|---|
| `-SkipImport` | `build_game.ps1:1`、`build_release.ps1:1` | 声明并转发，全仓无引用；`build_game.ps1:41` 无条件 import。CLI 静默 no-op |
| `user_storage.save_path()` | `app/user_storage.gd:6` | 静态函数无人调用（`app/game.gd:26` 使用 `storage.resolve_path()`） |
| 陈旧注释 | `main.gd:140`、`menu.gd:155` | 均称 "registry.gd …"，该文件已不存在 |
| 命名残留 | `menu.gd:140`、`battle_view.gd:119` 的 `registry_abort()`；`main.gd:91` 的 `var registry := …wire(…)` | 概念已换名未换 |
| 失效 LFS 规则 | `.gitattributes:4-5`（`art/full/**/*.jpg`） | `terrain_chunks/` 已被整体忽略（`.gitignore:1394`），`.jpg` 不可能再入库 |

**建议**：按表清理；`-SkipImport` 若确需保留，应在 `docs/18` 注明"仅兼容旧调用"。

---

## 建议顺序

| 批次 | 缺陷 | 理由 |
|---|---|---|
| 第 1 批（约 1 人日） | D1、D2、D4 | 三者共同决定"契约体系是否可信"：D1 补覆盖、D2 让失败真的失败、D4 删除假证据 |
| 第 2 批（约 1 人日） | D3、D9、D6 | 都是"补齐证据链"的小改动，且能防止未来回退 |
| 第 3 批 | D5、D7 | 结构性收敛，需要设计与回归 |
| 第 4 批 | D8、D10、D11、D12、D13 | 局部修正，可随手完成 |

## 附录：本次实测记录

```
node tools/registry_check.mjs        PASS 56 ports / 465 methods / 0 unresolved
node tools/architecture_check.mjs    PASS（18 长函数，violations 为空）
node tools/data_check.mjs            PASS 2 unit catalogs / 34 levels
node tools/docs_lint.mjs             0 issue(s)

Godot check_runtime_scripts.gd       RUNTIME SCRIPTS PASS（199 个 .gd 全量编译）
Godot test_architecture --noview     ARCH-013/017/018/019/020/022 全 PASS，exit 0
Godot dump_composition --noview      COMPOSITION PASS，四个根无 missing
Godot --simtest=15 (chibic1)         tick=450 digest=5724146327678163799，
                                     6 个子系统摘要与 baselines.json 一致
运行时 vs 清单比对                   main 26/26、menu 5/5、nav 2/2、view 12/12（一致）
探针：缺失 provider 的真实调用点      复现 "explicit port contract failed" +
                                     "SCRIPT ERROR: Invalid call ... in base 'Nil'"
CP936 解码复现                       test_publish.ps1:157 的 `|` 由 2 个降为 1 个
```

未执行：完整构建（需 7 GB 地形重建与导出模板）、候选包冒烟、真人试玩。沙箱禁止 Node 管道调用子进程（`EPERM`），故 `ci_lightweight.mjs`、`test_publish.ps1` 无法在本机完整运行；相关结论均来自静态阅读与定向探针，已在各条中标注证据形式。

## 附录：证据索引

```
godot/chibi_remake/composition_contract.gd:22-30
godot/chibi_remake/named_port.gd:3-6
godot/chibi_remake/main.gd:91-94,99-111,140
godot/chibi_remake/simulation/battle_world.gd:8-62
godot/chibi_remake/app/battle_commands.gd:1-26,441-467
godot/chibi_remake/presentation/battle/battle_access.gd:12-24
godot/chibi_remake/simulation/systems/battle_clock.gd:3-5
godot/chibi_remake/simulation/battle_config.gd:78
godot/chibi_remake/simulation/systems/ai_config.gd:1-14
godot/chibi_remake/simulation/systems/ai_decisions.gd:5-16
godot/chibi_remake/app/user_storage.gd:6
godot/chibi_remake/menu.gd:140,155
godot/chibi_remake/presentation/battle/battle_view.gd:119
tools/registry_check.mjs:6,14-22,25-42
tools/test_registry_runtime.mjs（expired 用例）
tools/gd/test_component_registry.gd:2-3,17,20,23,29
tools/gd/dump_composition.gd:15
tools/inputs/composition.json
tools/build_game.ps1:1,41
tools/build_release.ps1:1
tools/build_terrain.mjs:20,24-32
tools/verify_candidate.ps1:13
tools/compare_terrain_rebuild.mjs:3-6
tools/test_publish.ps1:157
.gitattributes:4-5
.gitignore:1394
```
