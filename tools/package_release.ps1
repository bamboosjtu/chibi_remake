param(
    [string]$VersionDirectory = "",
    [string]$OutputDirectory = "",
    [int]$PartMiB = 900,
    [string]$Tag = ""
)
# Package a published version directory for GitHub Releases.
# Files larger than PartMiB are split into .partNNN chunks.  Every chunk and
# every copied file stays below 1 GiB; the generated join-release.ps1 restores
# the original names and verifies SHA256SUMS.txt.
$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
if (!$VersionDirectory) {
    $pointer = Get-Content -Raw -Encoding UTF8 (Join-Path $root 'release/current.json') | ConvertFrom-Json
    $VersionDirectory = Join-Path $root ('release/' + $pointer.directory)
}
$VersionDirectory = [IO.Path]::GetFullPath($VersionDirectory).TrimEnd("\","/")
if (!(Test-Path -LiteralPath $VersionDirectory)) { throw ('Missing version directory: ' + $VersionDirectory) }
$versionName = Split-Path $VersionDirectory -Leaf
if (!$Tag) { $Tag = $versionName }
if (!$OutputDirectory) { $OutputDirectory = Join-Path $root ('dist/' + $versionName) }
$OutputDirectory = [IO.Path]::GetFullPath($OutputDirectory).TrimEnd("\","/")
if ($OutputDirectory.TrimEnd('\','/') -eq $VersionDirectory.TrimEnd('\','/')) { throw 'OutputDirectory must differ from VersionDirectory' }
$distRoot = [IO.Path]::GetFullPath((Join-Path $root 'dist')) + [IO.Path]::DirectorySeparatorChar
$workspaceOutput = [IO.Path]::GetFullPath((Join-Path $root '_work/package-outputs')) + [IO.Path]::DirectorySeparatorChar
function Assert-PackageOutputPath([string]$Path) {
    $absolute = [IO.Path]::GetFullPath($Path)
    if (!$absolute.StartsWith($distRoot, [StringComparison]::OrdinalIgnoreCase) -and
        !$absolute.StartsWith($workspaceOutput, [StringComparison]::OrdinalIgnoreCase)) {
        throw 'OutputDirectory must live under dist or _work/package-outputs'
    }
    $ancestor = $absolute
    while ($ancestor -and $ancestor.StartsWith($root,[StringComparison]::OrdinalIgnoreCase)) {
        if ((Test-Path -LiteralPath $ancestor) -and ((Get-Item -LiteralPath $ancestor -Force).Attributes -band [IO.FileAttributes]::ReparsePoint)) {
            throw ('OutputDirectory contains a reparse point: '+$ancestor)
        }
        if ($ancestor -eq $root) { break }
        $ancestor = Split-Path $ancestor -Parent
    }
}
Assert-PackageOutputPath $OutputDirectory
if ($VersionDirectory.StartsWith($OutputDirectory+[IO.Path]::DirectorySeparatorChar,[StringComparison]::OrdinalIgnoreCase)) { throw 'OutputDirectory must not contain VersionDirectory' }
if ($OutputDirectory.StartsWith($VersionDirectory+[IO.Path]::DirectorySeparatorChar,[StringComparison]::OrdinalIgnoreCase)) { throw 'OutputDirectory must be outside VersionDirectory' }
if ($PartMiB -ge 1024 -or $PartMiB -lt 1) { throw 'PartMiB must be between 1 and 1023' }
$limit = [int64]$PartMiB * 1MB

function Get-VersionFile([string]$Relative) {
    if ($Relative -notmatch '^[\w.-]+(?:/[\w.-]+)*$' -or ($Relative.Split('/') | Where-Object { $_ -in @('.', '..') -or $_.EndsWith('.') })) {
        throw ('Invalid version file path: '+$Relative)
    }
    $file = Get-Item -LiteralPath (Join-Path $VersionDirectory $Relative) -Force
    if ($file.PSIsContainer) { throw ('Expected a version file: '+$Relative) }
    $ancestor = $file
    while ($ancestor -and $ancestor.FullName.StartsWith($VersionDirectory,[StringComparison]::OrdinalIgnoreCase)) {
        if ($ancestor.Attributes -band [IO.FileAttributes]::ReparsePoint) { throw ('Reparse point in version path: '+$Relative) }
        if ($ancestor.FullName -eq $VersionDirectory) { break }
        $ancestor = Get-Item -LiteralPath (Split-Path $ancestor.FullName -Parent) -Force
    }
    return $file
}

if (!(Test-Path -LiteralPath (Join-Path $VersionDirectory 'build-manifest.json') -PathType Leaf)) { throw 'Published build manifest is missing' }
$manifestFile = Get-VersionFile 'build-manifest.json'
$manifest = Get-Content -Raw -Encoding UTF8 -LiteralPath $manifestFile.FullName | ConvertFrom-Json
if ($manifest.PSObject.Properties.Name -contains 'includesLocalCampaignMedia') {
    if ($manifest.includesLocalCampaignMedia -isnot [bool]) { throw 'Invalid local campaign media flag in build manifest' }
    if ($manifest.includesLocalCampaignMedia) { throw 'Local campaign media cannot be packaged for distribution' }
}
if ($manifest.schemaVersion -ne 3 -or $manifest.dirty -isnot [bool] -or $manifest.dirty -or
    $manifest.commit -notmatch '^(?:[a-f0-9]{40}|[a-f0-9]{64})$') { throw 'Packaging requires a clean published build manifest' }
$infoFile = Get-VersionFile 'release-info.json'
$info = Get-Content -Raw -Encoding UTF8 -LiteralPath $infoFile.FullName | ConvertFrom-Json
$buildHash = (Get-FileHash -LiteralPath $manifestFile.FullName).Hash
if ($info.schemaVersion -ne 5 -or $info.version -ne $versionName -or $info.commit -ne $manifest.commit -or
    $info.dirty -ne $manifest.dirty -or $info.buildManifestSha256 -ne $buildHash -or
    $info.exeSha256 -ne $manifest.exeSha256 -or $info.packSha256 -ne $manifest.packSha256 -or
    $info.verificationSha256 -ne $manifest.verificationSha256) { throw 'Release metadata differs from the build manifest' }

$approved = @{
    'ChibiRTS.exe' = $manifest.exeSha256
    'ChibiRTS.pck' = $manifest.packSha256
    'build-manifest.json' = $buildHash
    'verification.json' = $manifest.verificationSha256
    'release-info.json' = (Get-FileHash -LiteralPath $infoFile.FullName).Hash
}
foreach ($entry in $manifest.nativeFiles) {
    $relative = [string]$entry.path
    if ($relative -notmatch '^(?:[\w.-]+\.dll|portable\.txt|licenses/(?:[\w.-]+/)*[\w.-]+\.(?:txt|json))$' -or $approved.ContainsKey($relative)) {
        throw ('Unexpected or duplicate file in the build manifest: '+$relative)
    }
    $approved[$relative] = $entry.sha256
}
foreach ($relative in @('LICENSE','NOTICE.md')) {
    if ($info.PSObject.Properties.Name -contains 'noticeFiles') {
        $entries = @($info.noticeFiles | Where-Object path -eq $relative)
        if ($entries.Count -ne 1) { throw ('Missing published notice hash: '+$relative) }
        $approved[$relative] = $entries[0].sha256
    } else {
        # Older schema-5 versions included the two fixed notices without hashes.
        $approved[$relative] = (Get-FileHash -LiteralPath (Get-VersionFile $relative).FullName).Hash
    }
}
$files = @(foreach ($relative in ($approved.Keys | Sort-Object)) {
    if ($approved[$relative] -notmatch '^[a-f0-9]{64}$') { throw ('Missing published file hash: '+$relative) }
    [pscustomobject]@{ Relative=$relative; File=(Get-VersionFile $relative); Sha256=$approved[$relative] }
})
. (Join-Path $PSScriptRoot 'candidate_verification.ps1')
$null = Assert-CandidateVerification $VersionDirectory $manifest

function Write-Utf8NoBom([string]$Path, [string]$Text) {
    [IO.File]::WriteAllText($Path, $Text, (New-Object System.Text.UTF8Encoding $false))
}

function Split-LargeFile([string]$Source, [string]$TargetBase, [int64]$Limit, [string]$ExpectedHash) {
    $input = [IO.File]::OpenRead($Source)
    $sha = [Security.Cryptography.SHA256]::Create()
    $buffer = New-Object byte[] (4 * 1024 * 1024)
    $index = 1
    try {
        while ($input.Position -lt $input.Length) {
            $partPath = ('{0}.part{1:D3}' -f $TargetBase, $index)
            $output = [IO.File]::Open($partPath,[IO.FileMode]::CreateNew,[IO.FileAccess]::Write)
            $remaining = $Limit
            try {
                while ($remaining -gt 0) {
                    $want = [int][Math]::Min([int64]$buffer.Length, $remaining)
                    $read = $input.Read($buffer, 0, $want)
                    if ($read -le 0) { break }
                    $output.Write($buffer, 0, $read)
                    $null = $sha.TransformBlock($buffer, 0, $read, $buffer, 0)
                    $remaining -= $read
                }
            } finally { $output.Dispose() }
            Get-Item -LiteralPath $partPath
            $index++
        }
        $null = $sha.TransformFinalBlock($buffer, 0, 0)
        if ([BitConverter]::ToString($sha.Hash).Replace('-','') -ne $ExpectedHash) { throw ('Published file changed: '+$Source) }
    } finally { $input.Dispose(); $sha.Dispose() }
}

$outputParent = Split-Path $OutputDirectory -Parent
New-Item -ItemType Directory -Force $outputParent | Out-Null
$transaction = Join-Path $outputParent ('.package-'+[Guid]::NewGuid().ToString('N'))
$stageDirectory = $transaction+'-new'
$backupDirectory = $transaction+'-previous'
$lockPath = Join-Path $outputParent ('.'+(Split-Path $OutputDirectory -Leaf)+'.package.lock')
Assert-PackageOutputPath $lockPath
$lock = [IO.File]::Open($lockPath,[IO.FileMode]::OpenOrCreate,[IO.FileAccess]::ReadWrite,[IO.FileShare]::None)
try {
Assert-PackageOutputPath $stageDirectory
New-Item -ItemType Directory -Path $stageDirectory | Out-Null
$fileMap = @()
$sums = New-Object System.Collections.Generic.List[string]
$parts = New-Object System.Collections.Generic.List[object]
$assetNames = @('release-files.json','join-release.ps1','join-release.cmd','SHA256SUMS.txt','release-body.md')
foreach ($item in $files) {
    $file = $item.File
    $relative = $item.Relative
    $flat = ($relative -replace '/', '-')
    if ($flat -in $assetNames) { throw ('Reserved or duplicate release asset name: '+$flat) }
    $target = Join-Path $stageDirectory $flat
    $hash = $item.Sha256
    $partRecords=@()
    if ($file.Length -gt $limit) {
        foreach ($part in @(Split-LargeFile $file.FullName $target $limit $hash)) {
            $parts.Add($part) | Out-Null
            $assetNames += $part.Name
            $partRecords+=@{name=$part.Name;bytes=$part.Length;sha256=(Get-FileHash -LiteralPath $part.FullName -Algorithm SHA256).Hash}
        }
    } else {
        [IO.File]::Copy($file.FullName,$target)
        if ((Get-FileHash -LiteralPath $target -Algorithm SHA256).Hash -ne $hash) { throw ('Published file changed: '+$relative) }
        $assetNames += $flat
    }
    $fileMap+=@{relative=$relative;asset=$flat;bytes=$file.Length;sha256=$hash;parts=@($partRecords)}
    $sums.Add(($hash + '  ' + $flat))
}
if ($sums.Count -ne $files.Count) { throw 'Hash count does not match packaged file count' }

Write-Utf8NoBom (Join-Path $stageDirectory 'release-files.json') ((@{schemaVersion=1;files=@($fileMap)} | ConvertTo-Json -Depth 8)+"`n")
Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'join_release.ps1') -Destination (Join-Path $stageDirectory 'join-release.ps1')
$joinCmd = @'
@echo off
setlocal
set "PSModulePath="
"%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe" -NoProfile -ExecutionPolicy Bypass -File "%~dp0join-release.ps1" %*
exit /b %errorlevel%
'@
Write-Utf8NoBom (Join-Path $stageDirectory 'join-release.cmd') $joinCmd
foreach ($name in @('release-files.json','join-release.ps1','join-release.cmd')) { $sums.Add((Get-FileHash -LiteralPath (Join-Path $stageDirectory $name)).Hash+'  '+$name) }
Write-Utf8NoBom (Join-Path $stageDirectory 'SHA256SUMS.txt') (($sums -join "`n") + "`n")
$checksumListHash=(Get-FileHash -LiteralPath (Join-Path $stageDirectory 'SHA256SUMS.txt')).Hash


$totalBytes = ($fileMap | ForEach-Object { $_.bytes } | Measure-Object -Sum).Sum
$commit = [string]$info.commit
$body = @"
# 三国赤壁 · 高清重制 $Tag

预发布版本 ${versionName}，由本地发布脚本生成。

- 提交：$commit
- SHA256SUMS.txt 的 SHA-256：$checksumListHash
- 单文件上限：$PartMiB MiB；超过上限的文件拆成 `.partNNN` 分卷。
- 文件数：$($files.Count)，原始体积：$([math]::Round($totalBytes / 1GB, 2)) GiB。

## 下载与安装

1. 把本页全部文件下载到同一目录。
2. 运行 `join-release.ps1`（推荐，会合并分卷并校验 SHA256），或运行 `join-release.cmd` 后自行按 `SHA256SUMS.txt` 校验。
3. 双击 `ChibiRTS.exe` 启动；Windows x86_64，需保留同目录 DLL 和 `ChibiRTS.pck`。

## 分卷

只有超过 $PartMiB MiB 的文件会拆分；`ChibiRTS.pck.part001..` 合并后还原为 `ChibiRTS.pck`。不要单独解压分卷。

## 声明

非官方、非商业社区 MOD；需自备原作《三国赤壁》（1997）。许可与致谢见 `LICENSE`、`NOTICE.md`。
"@
Write-Utf8NoBom (Join-Path $stageDirectory 'release-body.md') $body

$assets = @(Get-ChildItem -LiteralPath $stageDirectory -File)
if ($assets.Count -ne $assetNames.Count -or @(Compare-Object $assetNames @($assets.Name)).Count) { throw 'Package asset set differs from the release map' }
if (@($assets | Where-Object { $_.Length -ge 1GB }).Count) { throw 'Release asset exceeds 1 GiB' }

Assert-PackageOutputPath $OutputDirectory
$hadOutput = Test-Path -LiteralPath $OutputDirectory
if ($hadOutput) {
    Assert-PackageOutputPath $backupDirectory
    [IO.Directory]::Move($OutputDirectory,$backupDirectory)
}
try {
    [IO.Directory]::Move($stageDirectory,$OutputDirectory)
} catch {
    if ($hadOutput) {
        Assert-PackageOutputPath $backupDirectory
        Assert-PackageOutputPath $OutputDirectory
        [IO.Directory]::Move($backupDirectory,$OutputDirectory)
    }
    throw
}
if ($hadOutput) {
    try {
        Assert-PackageOutputPath $backupDirectory
        Remove-Item -LiteralPath $backupDirectory -Recurse -Force
    } catch { Write-Warning ('Previous package retained at '+$backupDirectory+': '+$_.Exception.Message) }
}
Write-Output ('PACKAGE ' + $versionName + ' files=' + $files.Count + ' parts=' + $parts.Count + ' assets=' + $assets.Count)
Write-Output ('PACKAGE DIR ' + $OutputDirectory)
} finally {
    try {
        if (Test-Path -LiteralPath $stageDirectory) {
            Assert-PackageOutputPath $stageDirectory
            Remove-Item -LiteralPath $stageDirectory -Recurse -Force
        }
    } finally { $lock.Dispose() }
}
