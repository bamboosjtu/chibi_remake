# 18 构建与发布

> 按步骤执行的操作手册见根目录 [release.md](../release.md)。本章说明构建职责、产物契约与版本切换；测试工具见[测试与验收](19-testing.md)。

## 1. 依赖与输入

构建依赖 Node.js 22、PowerShell 5.1 或 7、Godot 4.7.2 Windows x86_64 引擎和同版本导出模板。启动器使用 Windows .NET Framework 4 的 `csc.exe` 编译。引擎放在仓库根目录；模板可通过 `CHIBI_GODOT_TEMPLATES` 指定。

标准构建读取已提交的关卡 JSON、规则及 Git LFS 运行素材。最小运行集由 `tools/inputs/runtime_assets.sha256` 声明。`-SkipData` 不读取地图源文件、绘画母版或研究工具。重新导出数据才需要 `_work/iso`、`_work/dec` 与 `_work/hd` 等本地生产输入。

## 2. 构建入口

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\build_release.ps1 -SkipData -NoPublish
```

| 参数 | 作用 |
|---|---|
| `-SkipData` | 复用现有 `data/*.json`，日常修改采用此方式 |
| `-NoPublish` | 只生成候选包，不改变当前版本 |
| `-NoOriginalMedia` | 排除原作过场、音乐与音效 |
| `-SkipImport` | 仅为旧调用保留；新暂存工程仍会导入资源 |
| `-SkipVerify` | 跳过候选冒烟；清单记 `verification=skipped`，只允许与 `-NoPublish` 一起使用；未验证候选不可发布 |

`build_release.ps1` 转发到 `build_game.ps1`。导出成功后构建会**启动候选包**运行全部地图加载、`release_tests.json` 的四项冒烟及两档确定性基线（`verify_candidate.ps1`），通过后才写清单并进入发布；失败则整次构建失败。这一层只证明"包能载入关卡并跑通核心交互"，画面与玩法验收仍由人工完成。

## 3. 构建职责

1. 准备隔离的临时目录、用户目录和导出模板。
2. 按参数导出或复用关卡数据，核对运行资源白名单与全部输入的 SHA-256。
3. `stage_release.mjs` 创建独立暂存工程与 `release_inputs.json`。
4. `build_terrain.mjs` 验证 `source/terrain` 的版本化源输入，并按源内容、地图、烘焙器及编码参数重建或命中 `_work/terrain`；`dedupe_terrain.mjs` 合并同内容分块并重写引用。
5. 导入资源，按 `Windows HD Art` 导出独立 EXE/PCK、配套原生库和显式绿色存储配置。
6. 先用实际 EXE 加载全部地图，再用启用断言的临时引擎挂载同一 PCK，运行四项冒烟、确定性基线，以及真实 EXE 的绿色/系统模式保存与重启读取，写出绑定 EXE/PCK/DLL/存储配置哈希的 `verification.json`。
7. `write_build_manifest.ps1` 补齐原生库声明文件并生成 `build-manifest.json`。
8. 按参数保留候选，或调用 `publish_release.ps1` 安装正式版本。

构建仍处理缺失输入、非零导出退出码、EXE/PCK 配套及原生依赖完整性等产物错误。候选冒烟通过不代表游戏已完成人工验收。

## 4. 构建清单与发布

`build-manifest.json` 记录构建起点的提交、工作区改动标记、生成时间、引擎版本、候选冒烟结果（`candidate-smoke` / `skipped` / `unverified`），以及 EXE/PCK、DLL 和声明文件的哈希。schema 3 同时记录 `verification.json` 的哈希。`publish_release.ps1` 重新核对证据、全部必测项目和产物哈希；无证据、证据失败、覆盖不全、清单过期或产物变化均拒绝发布。

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\publish_release.ps1 -Executable '<候选目录>\ChibiRTS.exe'
```

发布依赖构建清单和机器验收摘要 `verification.json`，不依赖运行日志或画面报告。发布脚本确认产物未被修改、复制完整依赖与声明文件、编译或复用启动器，最后原子切换版本指针。`docs/`、测试日志与画面证据留在仓库或本地候选目录；体积很小的 `verification.json` 随版本保存。构建清单的 `dirty=true` 或 `commit` 与当前 `HEAD` 不一致时，发布脚本拒绝安装。

## 5. 产物契约

```text
release/
├── ChibiRTS.exe
├── current.json
├── current.json.bak
└── versions/<时间>_<提交>_<ID>/
    ├── ChibiRTS.exe
    ├── ChibiRTS.pck
    ├── *.dll
    ├── licenses/
    ├── LICENSE
    ├── NOTICE.md
    ├── release-info.json
    ├── verification.json
    └── build-manifest.json
```

- 版本目录只放运行文件、原生依赖、许可证/声明与构建元数据；不含 `docs/`、测试日志或画面报告。
- 正式发布要求干净工作区：`build-manifest.json` 的 `dirty` 必须为 `false`，`commit` 必须等于发布时的 `HEAD`；否则先提交并重新构建。

- PCK 与 EXE 同名同目录，导出预设保持 `binary_format/embed_pck=false`。
- 包体大小不设上限；GitHub 发布资产按 900 MiB 分卷，本地版本目录不受此限制。
- 版本目录唯一且不可变；发布不覆盖或删除旧版本。
- `release-info.json` 使用 schema 5，记录构建与发布元数据、验收证据哈希、已验证地图和基线；`verification=candidate-smoke` 仅表示机器验收，不写入 `validated=true`。
- 文件复制、声明缺失或启动器替换失败时，旧指针保持不变。
- 启动器优先读取主指针，损坏时读取备份；运行中的旧游戏不会因指针切换而更换文件。

发布与分卷不要求签名、证书或 attestation。SHA-256 用于完整性检查；机器验收、不可变版本目录和原子指针切换继续执行。

## 6. 回滚与清理

回滚只恢复指针，操作命令见 [release.md](../release.md#7-产物位置与回滚)。保留当前和备份指针引用的版本。清理仅针对已确认可重建且不再被引用的暂存、缓存和候选目录；素材母版、玩家存档和正式版本不参与自动清理。

## 7. 本地试玩与发布打包

GitHub Actions 运行两个工作流：`contracts` 做不依赖引擎与 LFS 的静态契约（注册表、分层、素材白名单），`ci` 做语法校验和不依赖 LFS 的 Godot 第一关冒烟；两者都不构建、不打包、不发布。统一入口 `tools/release.ps1` 提供两个模式：

```powershell
# 试玩：构建并安装到 release/versions，允许未提交改动
powershell -NoProfile -ExecutionPolicy Bypass -File tools/release.ps1 -Mode preview

# 发布包：干净工作区构建后分卷到 dist/package
powershell -NoProfile -ExecutionPolicy Bypass -File tools/release.ps1 -Mode release -Tag v0.1.1
```

- `preview` 写入 `release/versions/<时间>_<提交>_<ID>` 并切换 `release/current.json`，双击 `release\ChibiRTS.exe` 即可试玩；`-SkipBuild` 只打印当前版本。
- `release` 要求 `build-manifest.json` 的 `dirty=false`；`tools/package_release.ps1` 以 900 MiB 为上限拆分：超过上限的文件生成 `.partNNN` 分卷，其余文件直接复制，同时生成 `join-release.ps1`、`join-release.cmd`、`SHA256SUMS.txt` 和 `dist/release-body.md`。
- 发布资产采用扁平命名（例如 `licenses-ffmpeg-LICENSE-ffmpeg.txt`），避免 GitHub 资产名不能含路径的问题；所有资产都小于 1 GiB。
- 手动上传：

```powershell
gh release create v0.1.1 dist/package/* --title "三国赤壁 · 高清重制 v0.1.1" --notes-file dist/release-body.md --prerelease
# 已存在的 Release：
gh release upload v0.1.1 dist/package/* --clobber
```

- 下载包后先运行 `join-release.ps1` 合并分卷并校验 SHA256，再启动 `ChibiRTS.exe`。

发布和分卷均不要求签名。验收、完整性哈希及原子版本切换继续作为发行门禁。

地形缓存键包含实际引擎二进制 SHA-256、源输入、烘焙脚本和编码参数；同版本号的不同引擎构建也必须重新烘焙。`tools/inputs/terrain_equivalence.sha256` 固化整改前运行 JPEG 经既有 q78 传输编码后的历史哈希，配套 JSON 记录源输入身份、34 图几何摘要及 LOD 数量。该快照来自独立历史缓存，并逐项核对源素材重建结果；不可用生成结果自动覆盖预期。

`contracts` 运行 `compare_terrain_rebuild.mjs --declarations` 检查历史清单完整性和源输入身份，不宣称已生成地形。正式构建在烘焙后运行不带该参数的比较，逐个验证 35,664 个分块及几何；新克隆不再依赖本机历史 `_work` 目录。修改地图源或编码参数需要单独评审其预期变化。

`tools/ci_windows.ps1` 固定执行打包目录安全、发布/回滚/锁及候选锁恢复测试。含非 ASCII 的 PowerShell 脚本使用带 BOM 的 UTF-8，CI 同时检查语法和 Windows PowerShell 5.1 编码兼容性。候选验证使用操作系统独占文件句柄，进程异常结束后自动释放；临时调试引擎采用唯一文件名，旧临时文件不会被误认成正在运行的验证，也不纳入发行哈希清单。
