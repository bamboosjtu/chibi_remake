# 本轮评审复核与修复结果

复核基准：`5263026`（评审所据代码为 `7f10edc`）。原评审完整保留在下方，其“当前缺陷”指修复前快照。

| 项目 | 结论 | 处理与验证 |
|---|---|---|
| D1 | 属实，已修复 | 组成清单仅保留服务路径与端口所属宿主，删除重复的 `providers`。体积从 39,784 字节降至 8,210 字节；62 个端口、682 条方法要求仍全部从源码 `CONTRACTS` 读取和验证。夹具验证新增源码契约无需改清单，错误方法仍被拒绝。 |
| D2 | 现象成立；既有语义已明确，补齐诊断 | 保留“请求退出并从包装方法安全返回”，不引入硬崩溃。错误日志明确标注 `shutdown requested (exit 1); current frame continues with defaults`；真实缺失/过期包装方法探针验证调用方后续语句仍执行，最终退出 1 且没有二次脚本错误。修正文档中“终止”及同名方法的歧义。评审所称候选把 34 图及基线放在同一进程的推断不成立：`run_regressions` 对每项调用 `runGodot` 启动独立进程。 |
| D3 | 当前无动词遗漏；正式版失败策略风险属实，已修复 | 未知视觉/音效请求在调试引擎继续报契约错误并请求退出；正式引擎按默认 `OS.is_debug_build()` 策略警告并丢弃，同动词只首次报警，战役结束或退出时汇总一次。计数属于表现会话，不进入存档或模拟摘要。实际路由回归、调试版负向用例及真实正式导出模板的隔离 EXE/PCK 均验证通过。 |
| D4 | 不构成需改玩法的缺陷；补充源码说明 | 倍率计算正确，但 `docs/02` 和 `docs/14` 已明确约定原作周期与默认 10/9 倍。保留 100/50/30/20 ms 周期，在 `battle_clock.gd` 补齐倍率与默认档注释；速度界面及原确定性基线通过。 |
| D5 | 属实，已修复 | 守卫检查允许空格、制表符、多行及中间注释，支持多行函数绑定；忽略注释内容，要求真实返回与正确缩进，并拒绝守卫之前调用提供者。单行/多行正向及注释伪装、错误缩进、晚于调用的守卫等负向夹具通过。 |

本轮验收：

- Windows：4 项 CI 引擎检查通过（全量脚本编译、无视图架构、运行时组成及表现降级路由）；9 个负向用例均以 1 退出且无 `SCRIPT ERROR`；正式策略的重复警告与单次汇总计数检查通过。
- Linux：同一组 4 项 CI 引擎检查、组成交叉校验、静态正负向夹具、9 个运行时负向用例及正式策略计数检查通过。
- 10 项定向引擎回归通过：发布清单 4 项、速度界面、跨关、单挑、世界切换、15/60 秒原确定性基线。未改模拟基线、性能预算或架构豁免。
- `ci_lightweight`、文档检查及 `git diff --check` 通过。新增路由测试纳入开发清单和 CI，警告/汇总次数验证纳入既有运行时门禁。
- 真实正式模板的隔离导出夹具验证默认正式策略：未知视觉事件两次、未知音效一次，进程正常以 0 退出、两条独立动词警告、一条结束汇总。证据见 `_work/review2/release-proof.json`，源码引擎结果见 `_work/review2/results.json`。

本轮未重建完整游戏发行 EXE/PCK，未进行真人试玩；正式模板夹具用于验证本次调试/发布分支，不等同于完整游戏发行验收。发布和分卷仍无签名要求。

---

# 原始评审（修复前快照）

# 架构缺陷清单：《三国赤壁 · 高清重制》

| 项 | 值 |
|---|---|
| 快照 | HEAD `7f10edc`（`bugfix: 根据评审意见整改架构问题`）；评审开始时工作区干净，本文件是唯一改动 |
| 范围 | **仅列当前仍然存在的缺陷**；已修复项、设计优点与历次对照不在本文件内 |
| 既定约束 | 原作素材随包分发（复现所需），不计为缺陷 |
| 规模 | 2,515 个跟踪文件；205 个 `.gd` / 25,593 行；62 个端口 / 682 条 provider 边 / 682 处端口守卫 |
| 验证方式 | 静态阅读 + 四个静态门禁 + 引擎内编译/架构/组成/确定性 + 一个定向探针；未执行完整构建与真人试玩 |

严重度：**中** = 会产生持续维护成本或与声明语义不一致；**低** = 局部错误、潜伏风险或工具健壮性问题。

## 缺陷索引

| # | 缺陷 | 位置 | 严重度 |
|---|---|---|---|
| D1 | `composition.json` 逐字复制了 682 条端口契约，且没有生成器 | `tools/inputs/composition.json` | 中 |
| D2 | 端口失效只"请求退出"：当前帧剩余调用以默认值继续 | `named_port.gd` / `composition_contract.gd` | 低 |
| D3 | 未登记的视觉/音效动词会让进程以非零码退出 | `main.gd:129,137` | 低 |
| D4 | 速度档周期与固定步长不对齐，默认档实际 1.11× | `battle_clock.gd:3-5` | 低 |
| D5 | 端口守卫的静态检查对代码换行敏感，会误报 | `registry_check.mjs` | 低 |

---

## D1（中）682 条端口契约被手工复制进清单，且没有生成器

**现象。** `tools/inputs/composition.json`（39.8 KB）的 62 个端口条目全部带 `providers`，把每个端口源文件里的 `const CONTRACTS` **逐字复制**了一遍，共 682 条方法字符串。而 `registry_check.mjs` 又把两者做严格比对：

```javascript
// tools/registry_check.mjs:7
const manifest=JSON.parse(fs.readFileSync('tools/inputs/composition.json','utf8'));
// tools/registry_check.mjs:32
assert.deepEqual(declared,entry.providers,file+': manifest contract differs from source');
```

**全仓库没有任何工具写这个文件**：检索 `composition.json` 只得到两处读取（`registry_check.mjs:7`、`test_registry_check.mjs:15`），没有 `--write`、没有生成脚本。

**影响。** 每次新增、删除或改名一个端口方法，都必须手工同步这份 682 条的清单，否则 CI 在 `assert.deepEqual` 处失败。这是纯粹的双记账：`providers` 不携带任何独立信息——检查器完全可以直接读源文件的 `CONTRACTS`，再用 `hosts` 校验 provider 方法是否存在；清单里真正不可推导的只有"哪个端口属于哪个宿主"（`host` 字段）。

开发者遇到这条门禁时的失败信息是 `manifest contract differs from source`，没有说明该怎么办。

**建议。** 二选一：

1. **删掉 `providers`**（推荐）。保留 `ports[file].host` 与 `hosts`；`registry_check.mjs` 直接用源码 `CONTRACTS` 做 provider 方法存在性校验。覆盖面不变（68x 条仍逐条校验），维护成本归零。
2. 保留双份，但补 `registry_check.mjs --write`：由源码重新生成 `providers`，CI 以 `--check` 比对，失败信息里给出 `node tools/registry_check.mjs --write`。

**验收。** 在任一端口新增一个方法后：选方案 1 则 CI 直接通过且仍能检出错误方法名；选方案 2 则 `--check` 仅提示"运行 --write"，不产生人工编辑。

---

## D2（低）"中止"只是请求退出，当前帧继续以默认值运行

**现象。** 682 处端口守卫的统一形态是：

```gdscript
# simulation/ports/technology_dependencies.gd:5-8
func _feedback(msg: String) -> void:
    var provider = _require(_provider_battle_simulation, "battle_simulation")
    if provider == null: return
    provider._feedback(msg)
```

`_require` → `require_provider`（`named_port.gd:3-7`）在 provider 失效时调用 `abort_if_broken`，后者的实现是 `push_error` + `SceneTree.quit(1)`（`composition_contract.gd:32-37`）。`quit()` 只请求退出，**当前帧不会中断**：守卫返回该类型的空值（裸 `return` 104 处；`false` 50、`{}` 43、`[]` 37、`0` 35、`Vector2i.ZERO` 17、`""` 13、`0.0` 6，其余为 `null`），调用方继续按"操作失败"往下走。全库共 682 处这样的守卫。

**证据。** 定向探针（provider 缺失与 provider 已释放各一次）：

```
ERROR: expired port: explicit port contract failed: [{"method":"provider lifetime","provider":"battle_simulation"}]
PROBE absent returned without crashing
ERROR: expired port: explicit port contract failed: [{"method":"provider lifetime","provider":"battle_simulation"}]
PROBE expired returned without crashing
```

二次 `SCRIPT ERROR` 已消除（这是上轮的缺陷），现在只剩"一次错误日志 + 请求退出 + 本帧继续"。

**影响。** 契约失效仍能保证非零退出码，也不会崩栈，所以影响有界；但存在一个具体误判场景：`verify_candidate.ps1` 用同一进程连续跑 34 张地图与 3 条基线，若某次地图销毁期间端口失效，进程会在批处理中途以 1 退出，冒烟表现为"候选不可用"，而真实原因只是本帧继续执行。

**建议。** 明确语义并写进 `docs/14`：若"立即停止"是要求，`require_provider` 在失效时应使用能真正终止的手段（调试构建 `assert` + 正式构建的硬终止），而不是先返回 null；若接受"本帧继续、下帧退出"，则应在日志里补一句 `frame continued with defaults`，让冒烟失败时能区分两类原因。

**验收。** 在 `_work` 下构造一个 provider 失效的探针：若选择"立即停止"，探针不得打印任何后续语句；若选择"下帧退出"，日志中必须出现明确的"已降级"说明。

---

## D3（低）未登记的视觉/音效动词会让进程退出

**现象。** 表现层的动词分派以 `match` 的默认分支兜底为终止：

```gdscript
# main.gd:129 与 main.gd:137
_: preload("res://composition_contract.gd").abort_if_broken("visual event", [{"method":action}])
_: preload("res://composition_contract.gd").abort_if_broken("sound event", [{"method":action}])
```

**证据。** 当前动词集合是闭合的：模拟层发出 12 个视觉动词 + 3 个音效动词，`main.gd` 的 `match` 有 15 个分支，**无遗漏**（逐项比对）：

```
emitted visual: attach_unit,capture_motion,fade_unit,free_unit,hide_unit,impact,
                place_unit,set_frame,set_unit_attached,show_end,update_panel,update_visual
emitted sound : play_attack,play_id,play_select
emitted but unhandled: （空）
```

**影响。** 属潜伏风险：新增一个视觉动词而忘记登记分支，表现不是"特效不显示"，而是**玩家对局中途进程退出（exit 1）**。对一个纯表现事件而言，代价与收益不成比例。

**建议。** 分开处理调试与发布：调试构建保留 fail-stop（便于立即发现漏登记），正式构建改为 `push_warning` + 丢弃该事件，并在对局结束时汇总一次"未登记动词"计数。

---

## D4（低）速度档周期与固定步长不对齐

**现象。**

```gdscript
# simulation/systems/battle_clock.gd:3-5
const PERIODS := [0.1, 0.05, 0.03, 0.02]
const LABELS := ["慢", "中", "快", "最快"]
var speed_index := 2
```

固定步长为 `SIM_DT = 1/30 ≈ 0.03333`（`simulation/battle_config.gd:78`）。加速循环每消耗 `period()` 的墙钟时间推进一步 `SIM_DT`，因此实际"模拟时间 / 墙钟时间"为：

| 档位 | period | 实际倍率 |
|---|---|---|
| 慢 (0) | 0.10 | 0.333 |
| 中 (1) | 0.05 | 0.667 |
| 快 (2，默认) | 0.03 | **1.111** |
| 最快 (3) | 0.02 | 1.667 |

**影响。** 若设计意图是"默认档 = 1×"，则四档整体偏移、默认档偏快 11%；确定性摘要不受影响（按 tick 推进），只影响节奏与手感，因而不会被现有基线发现。

**建议。** 让周期以 `SIM_DT` 为基准表达（例如 2×/1×/0.5×/0.33× 对应 `2.0/30`、`1.0/30`、`0.5/30`、`0.333/30`），或在 `battle_clock.gd` 的注释与 `docs/14` 中明确"档位是近似倍率，与 `SIM_DT` 不等比"。

**验收。** 若改为对齐，新增一条断言：`period() == SIM_DT` 在默认档成立。

---

## D5（低）端口守卫的静态检查对代码换行敏感

**现象。** `registry_check.mjs` 用一个函数块正则抓取包装方法，然后用**字面子串**判断守卫是否存在：

```javascript
for(const wrapper of text.matchAll(/^func \w+\([^\n]*\n(?:(?:\t[^\n]*|[ \t]*)\n)*/gm)){
 const binding=wrapper[0].match(/var provider = _require\(_provider_(\w+), "([^"]+)"\)/);
 if(!binding)continue;
 if(binding[1]!==binding[2]||!wrapper[0].includes('if provider == null: return'))throw Error(file+': unguarded provider');
```

只有当守卫被写成**同一行** `if provider == null: return` 时才被认可。把它排成两行（GDScript 完全等价、更易读，也与项目里 `if not conflicts.is_empty():` 风格一致）：

```gdscript
var provider = _require(_provider_x, "x")
if provider == null:
    return
```

会被判定为 `unguarded provider` 并让 CI 变红——与代码是否安全无关。

**影响。** 门禁会产生与事实相反的红灯；维护者为过门禁会倾向于保留挤在一行的写法，反而降低可读性。

**建议。** 改为空白不敏感匹配：`/if provider == null:\s*return/`，或先把函数块压缩空白再判断。

**验收。** 把任一包装方法的守卫改成两行，`node tools/registry_check.mjs` 必须仍然通过。

---

## 建议顺序

| 批次 | 缺陷 | 理由 |
|---|---|---|
| 第 1 批（约 2 小时） | D1、D5 | 两者都直接影响日常开发体验：一个要求人工双写 682 条契约，一个会把正确代码判红 |
| 第 2 批（约 2 小时） | D2、D3 | 都是"失败时的行为"问题，需要先明确语义再改代码；会影响冒烟判据与线上崩溃面 |
| 第 3 批 | D4 | 需要先确认设计意图（默认档是否应为 1×），改动本身很小 |

## 附录 A：本次复验记录

```
node tools/registry_check.mjs          PASS 62 named ports / 682 checked provider methods
node tools/architecture_check.mjs      PASS（18 长函数，violations 为空）
node tools/data_check.mjs              PASS 2 unit catalogs / 34 levels
node tools/docs_lint.mjs               0 issue(s); broken links: 0

Godot check_runtime_scripts.gd         RUNTIME SCRIPTS PASS（205 个 .gd 全量编译）
Godot test_architecture --noview       ARCH-013/017/018/019/022 全 PASS，exit 0
Godot dump_composition --noview        COMPOSITION PASS，四个根无缺失
node registry_check --runtime-log      main/view/menu/nav 四项 PASS
                                       （运行时 services 与 composition.json 严格相等）
Godot --simtest=15 (chibic1)           tick=450 digest=5724146327678163799，
                                       6 个子系统摘要与 baselines.json 逐字一致
探针：真实包装方法的失效路径             缺 provider 与已释放 provider 各一次，
                                       均只打印一条 contract failed，无 SCRIPT ERROR
```

未执行：完整构建（需 7 GB 地形重建与导出模板）、候选包冒烟、真人试玩。沙箱禁止 Node 管道调用子进程（`EPERM`），故 `powershell_encoding.mjs`（依赖 `git ls-files`）、`test_registry_runtime.mjs`、`test_publish.ps1` 无法在本机完整运行；其负向自检 `test_powershell_encoding.mjs` 可独立运行并通过。

## 附录 B：证据索引

```
tools/inputs/composition.json（62 端口 / 682 条 provider 契约 / 39.8 KB）
tools/registry_check.mjs:7,32,34-38
tools/test_registry_check.mjs:15
godot/chibi_remake/named_port.gd:3-7
godot/chibi_remake/composition_contract.gd:32-37
godot/chibi_remake/simulation/ports/technology_dependencies.gd:5-8
godot/chibi_remake/main.gd:116-137
godot/chibi_remake/simulation/systems/battle_clock.gd:3-5
godot/chibi_remake/simulation/battle_config.gd:76-78
```
