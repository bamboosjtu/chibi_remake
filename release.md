# 从源码打包与发布

本文按 Windows 环境说明源码准备、构建、版本安装与回滚。以下命令均在仓库根目录执行。

## 1. 准备源码和运行素材

首次获取项目：

```powershell
git lfs install
git clone <仓库地址>
Set-Location <仓库目录>
git lfs pull
```

已有工作区时，进入包含 `tools`、`godot` 和 `LICENSE` 的项目根目录，准备好本次要发布的源码与素材。构建记录当前 Git 提交和工作区是否有未提交改动。

标准打包使用仓库内的关卡 JSON、规则表及 Git LFS 运行素材，不需要原始光盘、REA、研究工具或绘画母版。

## 2. 准备构建工具

| 工具 | 放置方式 |
|---|---|
| Node.js 22 | 加入 PATH，可直接执行 `node` |
| PowerShell 5.1 或 7 | 使用 `powershell` 或 `pwsh` |
| Godot 4.7.2 Windows x86_64 | 将下列两个引擎文件放在仓库根目录 |
| Godot 同版本 Windows x86_64 导出模板 | 安装到用户模板目录，或设置 `CHIBI_GODOT_TEMPLATES` |
| .NET Framework 4 C# 编译器 | Windows 的 `Microsoft.NET/Framework64/v4.0.30319/csc.exe`，用于生成启动器 |

引擎文件名：

```text
Godot_v4.7.2-stable_win64.exe
Godot_v4.7.2-stable_win64_console.exe
```

若模板放在自定义目录，在当前 PowerShell 窗口中设置：

```powershell
$env:CHIBI_GODOT_TEMPLATES = 'D:\Tools\Godot\export_templates\4.7.2.stable'
```

该目录包含 `windows_release_x86_64.exe` 等 Windows 模板文件。构建会将所需模板放入隔离的 `_work/build/roaming` 中。

## 3. 构建候选包

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\build_release.ps1 -SkipData -NoPublish
```

使用 PowerShell 7 时，可把 `powershell` 换成 `pwsh`。

脚本依次完成：

1. 创建隔离的临时目录与用户目录。
2. 读取已有 `godot/chibi_remake/data/*.json` 和运行资源清单。
3. 将源码、规则、UI、图集、音视频及原生扩展暂存到 `_work/build/stage-<构建ID>`。
4. 从版本化地形源输入重建或命中缓存，保留既有编码顺序，并合并重复内容。
5. 导入暂存工程的资源。
6. 按 `Windows HD Art` 导出预设生成 EXE、独立 PCK 与配套 DLL。
7. 用实际 EXE 加载全部地图，并用同一 PCK 运行 `release_tests.json` 的四项冒烟、两档确定性基线及真实 EXE 保存/重启读取；失败即终止构建。`-SkipVerify` 仅允许与 `-NoPublish` 组合。
8. 补齐原生库声明文件，写入 `build-manifest.json`（含本次验收摘要与证据哈希）。

成功后终端输出：

```text
Built candidate: D:\项目目录\_work\build\candidate-<构建ID>
```

请保留此处输出的准确目录。候选目录至少包含：

```text
candidate-<构建ID>/
├── ChibiRTS.exe
├── ChibiRTS.pck
├── portable.txt
├── build-manifest.json
├── verification.json
├── export.log
├── *.dll
└── licenses/ffmpeg/
```

`-NoPublish` 只生成候选包，不改变 `release/current.json`。

## 4. 安装为正式版本

将命令中的候选路径替换为上一步实际输出：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\publish_release.ps1 `
  -Executable 'D:\项目目录\_work\build\candidate-<构建ID>\ChibiRTS.exe'
```

发布脚本将运行产物复制到新的 `release/versions/<版本>`，随包写入构建清单，然后原子替换 `release/current.json`。此前的指针保存为 `release/current.json.bak`，旧版本目录保留。日志与验证证据不进入发布包。

构建和发布分开执行时，不要在两步之间更改候选包的 EXE、PCK、DLL 或声明文件；发布过程会根据构建清单确认文件仍为同一套产物。

## 5. 使用发布入口

```powershell
.\release\ChibiRTS.exe
```

该文件是启动器，读取 `current.json` 并进入当前版本。正在运行的游戏继续使用原版本，关闭后重新启动才使用新版本。

交付时携带完整的 `release` 目录，或携带某一个完整版本目录。EXE、同名 PCK、DLL 和 `licenses` 必须一起保留。

## 6. 常用命令变体

直接完成构建并安装正式版本：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\build_release.ps1 -SkipData
```

排除原作过场、音乐与音效的候选包：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\build_release.ps1 -SkipData -NoOriginalMedia -NoPublish
```

需要从本地生产输入重新导出关卡时，准备好 `_work/iso/MEDS/*.MED` 及相关数据导入素材，然后去掉 `-SkipData`：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\build_release.ps1 -NoPublish
```

日常源码或 UI 修改使用 `-SkipData` 即可。暂存目录每次单独创建，资源导入自动完成。

## 7. 产物位置与回滚

```text
release/
├── ChibiRTS.exe                 统一启动器
├── current.json                 当前版本指针
├── current.json.bak             上一版本指针
└── versions/<时间>_<提交>_<ID>/
    ├── ChibiRTS.exe
    ├── ChibiRTS.pck
    ├── *.dll
    ├── licenses/
    ├── LICENSE
    ├── NOTICE.md
    ├── release-info.json        提交、构建时间、发布时间及产物哈希
    └── build-manifest.json      构建清单（日志不随包）
```

恢复上一版本指针：

```powershell
$releaseRoot = (Resolve-Path '.\release').Path
$rollbackTemp = Join-Path $releaseRoot 'current.rollback.tmp'
Copy-Item -LiteralPath (Join-Path $releaseRoot 'current.json.bak') -Destination $rollbackTemp
[IO.File]::Replace($rollbackTemp, (Join-Path $releaseRoot 'current.json'), (Join-Path $releaseRoot 'current.rollback.bak'), $true)
```

回滚后从统一启动器重新进入游戏。无需删除或覆盖任何版本目录。

## 8. 本地试玩与发布打包

GitHub Actions 运行静态契约（`contracts`）与语法/第一关冒烟（`ci`），不做构建与发布；构建、试玩安装、分卷和上传都在本地执行。统一入口是 `tools/release.ps1`，包含 `preview` 与 `release` 两个模式。

```powershell
# 试玩：构建并安装到 release/versions，允许未提交改动
powershell -NoProfile -ExecutionPolicy Bypass -File tools/release.ps1 -Mode preview

# 只启动当前指针指向的版本，不重新构建
powershell -NoProfile -ExecutionPolicy Bypass -File tools/release.ps1 -Mode preview -SkipBuild

# 发布包：干净工作区构建，再拆成小于 1 GiB 的资产
powershell -NoProfile -ExecutionPolicy Bypass -File tools/release.ps1 -Mode release -Tag v0.1.1

# 已有干净版本只重新分卷
powershell -NoProfile -ExecutionPolicy Bypass -File tools/release.ps1 -Mode release -SkipBuild -Tag v0.1.1
```

- `preview` 允许 `dirty=true`，构建完成后写入 `release/versions/<时间>_<提交>_<ID>` 并切换 `release/current.json`；双击 `release\ChibiRTS.exe` 即可试玩本次构建。
- `release` 要求干净工作区，构建后由 `tools/package_release.ps1` 以 900 MiB 为上限生成 `.partNNN` 分卷、`join-release.ps1`、`join-release.cmd`、`SHA256SUMS.txt` 和 `dist/release-body.md`，所有资产均小于 1 GiB。
- 发布资产采用扁平命名，避免 GitHub 资产名不能含路径。手动上传：

```powershell
gh release create v0.1.1 dist/package/* --title "三国赤壁 · 高清重制 v0.1.1" --notes-file dist/release-body.md --prerelease
gh release upload v0.1.1 dist/package/* --clobber
```

下载包后先运行 `join-release.ps1` 合并并校验，再启动 `ChibiRTS.exe`。
