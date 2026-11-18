# RTS 治理验收

## 参考输入

- 起点 `7ddf81a2495d6cec7fe0da5c3cb0f1b43ee603e9`。Windows 审核引擎 SHA-256 为 `ab1824f85bfd8e0e4128182c000c4003a3e042245b2967848d089b2a04b22424`。
- `tools/inputs/baselines.json` 的 SHA-256 为 `b1d90020270c3160c9db6509cbe8b1c7d6c9aa0fa87237bc545b1029f483a5c1`。扩充到 `chibic1`、`chibil1`、`chibic10`、`chibic17` 的 450 和 1800 tick。新增规范化完整快照摘要，原有两项整数和分段摘要逐字段保持。
- `tools/inputs/save-v9-7ddf81a.json` 的 SHA-256 为 `908116ebd73d7c8f8e4fe2882e3d4e5c9f4070817f90b9e5a34821223cd59f53`。夹具含两份第 31 tick 的原始 v9 文件，以及第 31 和 38 tick 的完整状态摘要。默认规则指纹为 `a2c29ae3ea02d264d68306d08d5dd1d35e0e18dec12c9d973c461650012c0d47`。

## 复跑

| 范围 | 本地入口 |
|---|---|
| 启动与静态契约 | `node tools/bootstrap.mjs --check -SkipData`、`node tools/ci_lightweight.mjs` |
| 存读档判负 | `node tools/run_regressions.mjs --selftest-failures` |
| 兼容、恢复与完整摘要 | `node tools/run_regressions.mjs --suite tools/inputs/save_tests.json --selftests --baselines --maps`、`node tools/test_continuation_coverage.mjs` |
| 输入与显示 | 分别用 `node tools/run_regressions.mjs --suite <清单>` 运行 `ci_godot_tests.json` 和 `release_tests.json` |
| Windows 候选 | `pwsh -NoProfile -File tools/ci_windows.ps1 -ReleaseSafetyOnly`、`pwsh -NoProfile -File tools/build_release.ps1 -SkipData -NoPublish` |
| 真实容量和合成诊断 | `pwsh -NoProfile -File tools/bench_capacity_stability.ps1 -ReleasePack <PCK> -IncludeSynthetic` |

基线变更说明须记录有效行为差异、受影响分段和复跑证据。Actions 上传的结果以被验证提交和运行编号定位。

## 本地结果

被测运行时提交为 `c75cf91e07b66d212fd079bfba0e4104818bb6af`。本地静态门禁 35/35，Windows 发布安全套件通过。三图自检通过，独立的写档失败和读档失败均以退出码 1 判负。两份历史 v9 夹具通过同图、跨图、备份和七 tick 续跑。四图六采样点续跑通过，八个固定基线在脚本和原生后端上均匹配。

Windows EXE/PCK 完成导出。冷重建中途停止，候选使用从上一发行包恢复并逐块核验的等价地形。34 图的 35,664 个分块和几何均匹配清单。候选 PCK SHA-256 为 `355a85efc6e6adaa5670077470923de2cd2df9fecb305aea2878e1bfe3e48728`。候选通过 34 图启动、40 项打包回归及基线（含实际 DLL 对照）和 8 项正式 EXE 存读与隔离测试。FPS 门槛阻止生成候选验收凭据。本地分支暂无对应的远端 Actions 结果。

| 参考机实测，协议 v4 | tick P95 | 窗口 FPS | 判定 |
|---|---:|---:|---|
| 200 单位，3 轮 | 24.94–25.35 ms | 39.3–45.1 | 0/3 通过发布性能门槛；三轮均低于 60 FPS |
| 460 真实满人口，5 轮 | 26.01–27.15 ms | 17.0–17.5 | 逻辑专项 5/5；P95 极差为中位数的 4.23%，最高命令 P95 5.02 ms |
| 660 合成，1 轮 | 29.57 ms | 9.5 | 诊断；吞吐 31.06 tick/s，低于目标的 95% |
| `7ddf81a` 对照，每档 1 轮 | 200 为 25.04 ms；460 为 26.49 ms | 200 为 29.7；460 为 16.5 | 同机、同素材、同协议，各档起始快照摘要与候选相同；帧率缺口在治理前提交可复现 |

460 五轮进程峰值工作集为 0.534 GiB，显存峰值为 0.626 GiB。对照只做单轮，且使用旧队列探针，命令延迟按各自口径记录。

本机工件见[候选目录](../../_work/arch-governance/candidate-c75cf91)、[发布回归与标准报告](../../_work/candidate-smoke/4d0f28baf82b4811a7e83266a83cb7ee)、[满人口逻辑专项摘要](../../_work/arch-governance/candidate-c75cf91/capacity-evidence/logic-summary.json)和[治理前对照](../../_work/arch-governance/control-7ddf81a)。归档 JSON 和日志由上述命令重建。
