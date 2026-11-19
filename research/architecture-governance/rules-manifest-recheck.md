# 规则清单重录复核（rules-manifest-recheck）

| 项 | 值 |
|---|---|
| 起点 | `008969c`（hosted `contracts` 失败步骤：`Simulation data and rules manifest`；`ci` 同 tree 全绿，见 runs/44512639980） |
| 触发 | `008969c` 落袋了 8 个 simulation 源的行为整改（命令成败传播、视野单次化、单挑/编组布尔化、原生射程口径统一等），`data/db/rules_manifest.json` 未随之重录 |
| 重录范围 | 恰 8 条哈希：abilities / battle_simulation / command_groups / officer_teams / transport_orders / unit_actions / battle_world / player_commands |
| 审查 | 8 文件逐个 diff 复核：均为上一轮评审整改对象；无未经审查的源变化混入 |

## 行为验证（Godot 4.7.2.stable.official.ed1daf0bf，Windows x64，原生数学路径启用）

- 引擎 sha256 前缀 `ab1824f85bfd`，与 `tools/inputs/engines.json` 登记值一致。
- **确定性基线 8/8 逐位一致**（tick / digest / subsystems / full 四层，退出码 0）：
  sim-chibic1-15/60、sim-chibic10-15/60、sim-chibic17-15/60、sim-chibil1-15/60 全部与 `tools/inputs/baselines.json`（updatedAt 2026-11-18）逐位一致；含 `chibil1` 15s/60s 同摘要的既有退化特征，未重录、无需 rts-baselines.md 联动。
- **34 图 `--noview --smoketest` 全 PASS**（`ARCH-013: view=false` + 退出码 0 + 隔离 profile 的 smoke.json ok=true）。
- **存档套件 9/9 全 PASS**（`tools/inputs/save_tests.json` 全部 marker + 退出码 0）。
- hosted 佐证：GitHub Actions `ci`（runs/44512639980，同 tree `6cccd62`）在 Linux/脚本路径全绿；本机复核补上了 CI 覆盖不到的 **Windows 原生路径**证据。

## 复现命令

```powershell
node tools/run_regressions.mjs --engine .\Godot_v4.7.2-stable_win64.exe --baselines --maps --suite tools/inputs/save_tests.json
node tools/rules_manifest.mjs        # 重录后：RULES MANIFEST PASS 85 simulation sources
```

沙箱内 Node 直接 spawn 引擎受命名管道限制时，可经 `tools/godot_cli.mjs` 的 stdio-inherit 通道逐项直驱（本记录的本地数字即由此产生，判定语义与 `run_regressions.mjs` 一致）。

## 结论

- 重录后 11 项静态门禁全绿（architecture / registry / port / battle_access / unit_schema / docs_lint / suite / level_index / rule_constants / rules_manifest / data_check）。
- `contracts.yml` data 组与 `stage_release.mjs:7` 的清单一致性恢复。
- 基线未动：摘要与录制值逐位一致，属预期内的零行为漂移。
