# 基线变更记录

`tools/inputs/baselines.json` 是模拟确定性基线。**基线只能与这里的复核说明一起移动**——CI 的 `Require evidence for baseline changes` 作业要求：改动 baseline 的提交必须同时改本文件。

## 记录格式

```text
## YYYY-MM-DD 提交 <sha> · <改动原因>
- 改动：<哪些图的摘要变了>
- 复核：<谁、用什么证据确认这是预期变化>
- 影响：<哪些测试/发布门禁受影响>
```

## 当前基线文件校验和

`tools/inputs/baselines.json`（仓库内 LF 版本）SHA-256：`cbfa0a0a2345a68a946c64de45b80da871ef726c39cf9b9e8e890624d50fe603`

> CI 的 `Require evidence for baseline changes` 会校验本文件包含该值。

## 历史
## 2026-11-22 提交 be0afab 之后（合并提交见下） · 进攻等待门槛改 0 基 + 武将目标 + 城门

- 改动：四图 15s/60s 的 SIMTEST 整数、`subsystems`（ai/combat/economy/scenario/total/world）**均未变化**；只有 `full` 摘要变化。
- 原因：`full` 覆盖规则身份；`unit_roles.json` 拆分 `workers/civilians/harvesters` 改变了身份。首波进攻在 2911 tick，晚于 1800 tick 采样窗口，所以模拟摘要本身不变。
- 注：AI 行为修正（0 基等级、武将目标、城门）在同一提交中，但本基线的采样窗口覆盖不到首波进攻。
- 复核：REA 反编译 `FUN_00471600`、`FUN_00464B40`、`FUN_00428810`；`FUN_00422330` 三个升级 case 写 `[side+0x4B8D29]=1/2/3` 证明等级 0 基。`test_ai_research` 新增二吕进犯断言（首轮不出击、玩家金过 15000 后下一轮出击）。
- 影响：候选冒烟的"两档确定性基线"与 GitHub `simulation` 作业改用新摘要；`release_tests.json` 未改。


- 2026-11-21 `864d405` 文档按模块重排：仅 `.gd` 注释中的 research 路径变化，未改规则值；`tools/inputs/baselines.json` 未变动。

## 2026-11-22 · 存档夹具重录

- 改动：`tools/inputs/save-v9-7ddf81a.json` → `tools/inputs/save-v9-c9d4be0.json`。
- 原因：v9 不做旧档兼容；`unit_roles.json` 拆分 `workers/civilians/harvesters` 改变了规则身份，旧夹具加载被拒（"存档规则与当前版本不匹配"）。
- 复核：用当前构建在 `chibic1`、`chibil1` 各录一份 v9 存档，按 `test_current_format` 的同一路径（写入槽位 → 载入 → 第 31/38 tick 续跑摘要）生成 `sha256`/`length`/`at31`/`at38`；`test_current_format` 通过。
- 影响：仅该测试；规则身份本身的正确性由 `rules_identity` 与 `test_rule_constants` 覆盖。

## 2026-11-22 · 二吕进犯东门阻挡与发行验收

- 东门旁两格 (32,174) 和 (33,176) 恢复原始城墙阻挡。其余地形和另外三张图的基线保持原值。
- 在审核版 Godot 4.7.2 重跑 chibil1 的 450 和 1800 tick。整数摘要和所有分段摘要一致。保存完整快照包含关卡内容校验值，因此更新这两个完整摘要。
- 用提交 463a5b4 重录并加载《二吕进犯》v9 当前格式夹具，核对加载及七 tick 续跑。除保存时间、校验和及关卡内容校验值外，新旧夹具字段逐一一致。《侦察新野》原夹具保留。

## 2026-11-22 · chibil1 east gate clearance

- Widened the existing east gate at (32,175) to enable complete travel by four-cell cavalry. The neighboring wall remains blocked.
- Re-recorded the 450- and 1800-tick full digests on Godot 4.7.2. The legacy digest and every subsystem digest match the previous baselines.
- Re-recorded only the chibil1 entry in the v9 test fixture. The chibic1 entry is byte-for-byte equal to the prior fixture.
