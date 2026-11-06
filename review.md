# 架构复核结论：《三国赤壁 · 高清重制》

| 项 | 值 |
|---|---|
| 快照 | HEAD `18bb452`（`bugfix: round2`），工作区干净 |
| 结论 | 上轮 5 项缺陷**全部关闭**；本轮未发现仍存在的架构缺陷 |
| 规模 | 2,517 个跟踪文件；206 个 `.gd` / 25,624 行；62 个端口 / 682 条 provider 契约 |
| 发布 | 版本 `20261107_012037_18bb4522_72ad14`，候选冒烟通过，已安装并分卷 |
| 范围 | 前两轮完整缺陷清单见 `5263026` 与 `7f10edc` 的 `review.md` 历史版本；本文只保留当前结论 |

## 一、上轮缺陷复核

| # | 上轮缺陷 | 状态 | 验证方式 |
|---|---|---|---|
| D1 | 组成清单逐字复制 682 条契约且无生成器 | **关闭** | `composition.json` 只剩 `{host}`（39,784 → 8,210 字节，重复条目 682 → 0）；`registry_check.mjs:33` 反向拒绝残留 `providers`；62 端口 / 682 方法仍逐条从源码 `CONTRACTS` 校验 |
| D2 | "中止"只请求退出，当前帧继续 | **关闭（语义已明确）** | 保留"记录 + 请求退出 + 包装方法返回空值"；日志与 `docs/14:186` 明确写入该语义；探针确认缺/失效 provider 只产生一条诊断、无 `SCRIPT ERROR`、退出码 1 |
| D3 | 未登记视觉/音效动词导致进程退出 | **关闭** | 新增 `presentation/battle/event_diagnostics.gd`：调试构建维持 fail-stop，正式构建按动词计数、首次告警、结束汇总；`test_presentation_diagnostics.gd` 纳入 CI 与开发清单，本地实跑 PASS |
| D4 | 速度档周期与 `SIM_DT` 不对齐 | **关闭（约定已写明）** | `docs/14:86` 与 `battle_clock.gd` 注释明确保留原作 100/50/30/20 ms，倍率 1/3、2/3、10/9、5/3，默认档 10/9 倍，不定义为实时 1 倍 |
| D5 | 守卫静态检查对换行敏感 | **关闭** | 匹配改为忽略注释、允许空格/制表符/多行/空行，校验缩进与"守卫先于调用"；正负向夹具覆盖单行、多行、注释伪装、错误缩进、晚于调用 |

**对我上一轮结论的更正。** 我曾判断"34 张地图与基线在同一进程内串行，端口失效会让批量冒烟整体误判"。这一点不成立：`run_regressions` 对每一项都单独调用 `runGodot` 启动进程。D2 的语义问题仍然成立（现已明确），但影响范围被我高估。

## 二、仍存在的问题

**无。** 本轮静态门禁、引擎内检查、确定性基线与候选冒烟均通过，未发现新的架构缺陷。

以下三项经复核**不构成缺陷**，列此以免重复提出：

1. **`composition.json` 的 `hosts`（45 条）仍需在新增服务时手改。** 端口方法已改为源码单源，且失败信息明确为 `factory services differ from composition manifest`；这是一份有意的"服务必须显式登记"声明，不是冗余副本。
2. **发布分卷与 `SHA256SUMS.txt` 同源、无签名。** 项目已明确不作为发布要求；哈希绑定的是原始 `ChibiRTS.pck`，玩家端 `join-release.ps1` 合并后仍可校验。
3. **`portable.txt` 内容为 `userdata`。** 启动器会追加 `--portable-root=<安装根>/userdata`，存档落在安装根而非版本目录；写入失败时回退 `%LOCALAPPDATA%\ChibiRTS\saves`。已核对，行为正确。

## 三、观察（不计为缺陷）

- **地形重烘焙是当前构建的主要耗时。** 本轮因缓存键纳入引擎哈希而全量重建：34 图烘焙约 24 分钟、LOD 约 23 分钟，占整次构建（55 分钟）的八成以上。缓存命中后不再发生；若需要缩短"换引擎首次构建"，可把逐图烘焙改为并行（旧的分块传输流水线已有 4 worker 实现可复用）。
- **`_work` 已累积约 159 GB**（542k 文件），`cleanup_project.ps1` 未接入任何自动流程，需手动清理。

## 附录 A：本轮实测记录

```
node tools/registry_check.mjs          PASS 62 named ports / 682 checked provider methods
node tools/architecture_check.mjs      PASS（18 长函数，violations 为空）
node tools/data_check.mjs              PASS 2 unit catalogs / 34 levels
node tools/docs_lint.mjs               0 issue(s); broken links: 0

Godot check_runtime_scripts.gd         RUNTIME SCRIPTS PASS（205 个 .gd 全量编译）
Godot test_architecture --noview       ARCH-013/017/018/019/022 全 PASS，exit 0
Godot dump_composition --noview        COMPOSITION PASS
node registry_check --runtime-log      main/view/menu/nav 四项 PASS（运行时 = 清单）
Godot test_presentation_diagnostics    PRESENTATION DIAGNOSTICS PASS
Godot --simtest=15 (chibic1)           tick=450 digest=5724146327678163799，
                                       ai/combat/economy/scenario 摘要与基线逐字一致
```

构建与发布（`tools/release.ps1 -Mode release -Tag v0.1.1`，退出码 0）：

```
TERRAIN BUILD PASS                    34 maps / 34 rebuilt / 0 cache hits
RUNTIME ASSETS PASS                   files=626 / sha256 / exact staging inputs
TERRAIN EQUIVALENCE PASS              34 maps / 35664 identical historical chunks
Staged                                36,599 files / 4.25 GiB
TERRAIN DEDUP                         35,664 files → 24,567 unique（节省 793,231,923 字节）
CANDIDATE SMOKE PASS                  34 maps + 4 release suites + 2 baselines + 4 native save
PACKAGE                               23 files / 29 assets / 4 parts（≤900 MiB）
Published                             20261107_012037_18bb4522_72ad14
```

产物校验：

```
ChibiRTS.exe  sha256  72F5CE72C5F54FEFCADB743596EAB2A552E73058601F1E29F5C871E683595A6D
ChibiRTS.pck  sha256  BBB4ACA7663D64753384B69B1B39F5D9F4A4FB9136E2F01DAC8E9718C16ABFE4
release-info.json     verification=candidate-smoke, dirty=false, commit=18bb4522…
release/current.json  → versions/20261107_012037_18bb4522_72ad14（.bak 保留上一版本）
```

## 附录 B：证据索引

```
tools/inputs/composition.json（62 端口，仅 host 映射）
tools/registry_check.mjs:33（拒绝残留 providers）, 43-57（守卫与调用顺序）
godot/chibi_remake/composition_contract.gd:32-37
godot/chibi_remake/named_port.gd:3-7
godot/chibi_remake/presentation/battle/event_diagnostics.gd
godot/chibi_remake/main.gd:124-141
godot/chibi_remake/simulation/systems/battle_clock.gd:2-6
docs/14-architecture.md:86,186
tools/gd/test_presentation_diagnostics.gd
tools/launcher.cs:44-46
godot/chibi_remake/app/user_storage.gd:20-33
dist/release-body.md
```
