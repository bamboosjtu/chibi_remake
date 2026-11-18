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
| 输入与显示 | `node tools/run_regressions.mjs --suite tools/inputs/ci_godot_tests.json --suite tools/inputs/release_tests.json` |
| Windows 候选 | `pwsh -NoProfile -File tools/ci_windows.ps1 -ReleaseSafetyOnly`、`pwsh -NoProfile -File tools/build_release.ps1 -SkipData -NoPublish` |
| 真实容量和合成诊断 | `pwsh -NoProfile -File tools/bench_capacity_stability.ps1 -ReleasePack <PCK> -IncludeSynthetic` |

基线变更说明须记录有效行为差异、受影响分段和复跑证据。Actions 上传的结果以被验证提交和运行编号定位。
