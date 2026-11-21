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

已有工作区时，进入包含 `tools`、`godot` 和 `LICENSE` 的项目根目录，准备好本次要发布的源码与素材。正式构建使用该 Git 提交中的项目文件，LFS 运行素材按该提交中的指针校验，地形从声明的输入生成。构建清单记录 Git 提交和工作区状态。

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
Godot_v4.7.2-stable_win64.exe
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
5. 复用未变化的地形和 Godot 导入结果。暂存工程仍由 Godot 扫描，变化或缺失的资源重新导入。
6. 按 `Windows HD Art` 导出预设生成 EXE、独立 PCK 与配套 DLL。
7. 用实际 EXE 加载全部地图，再运行同一 PCK 的发行回归、已登记的确定性基线、真实 EXE 存档与隔离测试以及三轮性能验收。失败即终止构建。`-SkipVerify` 仅可与 `-NoPublish` 一起使用。
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

本机高清：安装目录登记的 34 个 MP4 后，显式加 `-NoPublish -IncludeLocalCampaignMedia` 生成并验证私有候选。它可以设置为本机当前版本，但分卷与分发入口拒绝该版本；公开构建不得加入此开关。`-NoOriginalMedia` 会排除全部原作视频/音频和私有高清，两开关不能并用。

## 4. 安装为正式版本

将命令中的候选路径替换为上一步实际输出：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\publish_release.ps1 `
  -Executable 'D:\项目目录\_work\build\candidate-<构建ID>\ChibiRTS.exe'
```

发布脚本将运行产物复制到新的 `release/versions/<版本>`，随包写入构建清单，然后原子替换 `release/current.json`。此前的指针保存为 `release/current.json.bak`。旧版本目录、构建清单和机器验收摘要随版本保留，运行日志留在候选目录。

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
    ├── verification.json        候选逐项验收证据
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

GitHub Actions 的 `ci` 工作流检查静态契约、语法、引擎启动和存档续跑。Windows 发布安全回归入口为 `tools/ci_windows.ps1 -ReleaseSafetyOnly`。参考机性能验收、安装、分卷和上传在本地执行。统一入口 `tools/release.ps1` 提供 `preview` 与 `release` 两个模式。

```powershell
# 试玩：构建并安装到 release/versions，允许未提交改动
powershell -NoProfile -ExecutionPolicy Bypass -File tools/release.ps1 -Mode preview

# 查看当前指针指向的版本
powershell -NoProfile -ExecutionPolicy Bypass -File tools/release.ps1 -Mode preview -SkipBuild

# 在准备发布的提交上创建标签并推送到 origin（仅在标签尚未创建时执行）
git tag -a v0.1.1 -m 'Release v0.1.1'
git push origin refs/tags/v0.1.1

# 构建并分卷，要求远程标签匹配构建提交
powershell -NoProfile -ExecutionPolicy Bypass -File tools/release.ps1 -Mode release -Tag v0.1.1

# 已有干净版本只重新分卷
powershell -NoProfile -ExecutionPolicy Bypass -File tools/release.ps1 -Mode release -SkipBuild -Tag v0.1.1
```

- `preview` 允许 `dirty=true`，构建完成后写入 `release/versions/<时间>_<提交>_<ID>` 并切换 `release/current.json`；双击 `release\ChibiRTS.exe` 即可试玩本次构建。
- `release` 要求干净工作区，且 `origin` 上的 `-Tag` 必须指向本次构建提交。分卷只使用构建及验证清单中的交付文件和固定的许可证、发布元数据。分卷和校验全部成功后才替换 `dist/package`，新构建随后切换本地版本指针。发布说明与分卷保存在同一个目录。每个资产小于 1 GiB。
- 发布资产采用扁平命名，避免 GitHub 资产名不能含路径。手动上传：

```powershell
# 使用 release.ps1 输出的 UPLOAD 命令。该命令显式指定 origin 对应仓库及 --verify-tag。
```

下载包后先运行 `join-release.ps1` 合并并校验，再启动 `ChibiRTS.exe`。

## 9. 存档、验收包与签名

此版本读取 v9 存档。v1–v8 在读取界面显示“格式不支持或数据无效”。损坏主档与可用备份分别保留，清理隔离文件需要在存档界面确认。

本地验收驱动写入独立的 `ChibiAcceptance.testpack`。配套脚本在验收进程中启用该包，玩家 PCK 的资源清单排除 `testing/`。正式候选须使用实际 EXE/PCK 连续三轮通过标准性能检查，安装和分卷都读取同一份凭据。

构建从 `project.godot` 取得 Windows 文件版本。默认分卷状态为未签名。维护者提供发布证书后，可为分卷校验清单生成分离签名，并用可信的证书指纹核验。

```powershell
pwsh -NoProfile -File tools/sign_release_checksums.ps1 -ChecksumFile dist/package/SHA256SUMS.txt -Thumbprint <发布证书指纹>
pwsh -NoProfile -File tools/sign_release_checksums.ps1 -ChecksumFile dist/package/SHA256SUMS.txt -Thumbprint <可信发布证书指纹> -Verify
```
