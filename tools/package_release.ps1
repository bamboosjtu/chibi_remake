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
$VersionDirectory = [IO.Path]::GetFullPath($VersionDirectory)
if (!(Test-Path -LiteralPath $VersionDirectory)) { throw ('Missing version directory: ' + $VersionDirectory) }
$versionName = Split-Path $VersionDirectory -Leaf
if (!$Tag) { $Tag = $versionName }
if (!$OutputDirectory) { $OutputDirectory = Join-Path $root ('dist/' + $versionName) }
$OutputDirectory = [IO.Path]::GetFullPath($OutputDirectory)
if ($OutputDirectory.TrimEnd('\','/') -eq $VersionDirectory.TrimEnd('\','/')) { throw 'OutputDirectory must differ from VersionDirectory' }
# This directory is deleted recursively below; never accept a path outside the
# project's own dist/ tree, and never accept the tree root itself.
$distRoot = [IO.Path]::GetFullPath((Join-Path $root 'dist')) + [IO.Path]::DirectorySeparatorChar
if (!$OutputDirectory.StartsWith($distRoot, [StringComparison]::OrdinalIgnoreCase)) { throw ('OutputDirectory must live under ' + $distRoot) }
if ($VersionDirectory.StartsWith($OutputDirectory.TrimEnd('\','/')+[IO.Path]::DirectorySeparatorChar,[StringComparison]::OrdinalIgnoreCase)) { throw 'OutputDirectory must not contain VersionDirectory' }
# Lexical containment is insufficient when a parent is a junction/symlink.
$ancestor=$OutputDirectory
while ($ancestor -and $ancestor.StartsWith($root,[StringComparison]::OrdinalIgnoreCase)) {
    if ((Test-Path -LiteralPath $ancestor) -and ((Get-Item -LiteralPath $ancestor -Force).Attributes -band [IO.FileAttributes]::ReparsePoint)) { throw ('OutputDirectory contains a reparse point: '+$ancestor) }
    if ($ancestor -eq $root) { break }
    $ancestor=Split-Path $ancestor -Parent
}
if ($PartMiB -ge 1024 -or $PartMiB -lt 1) { throw 'PartMiB must be between 1 and 1023' }
$limit = [int64]$PartMiB * 1MB
if (Test-Path -LiteralPath $OutputDirectory) { Remove-Item -LiteralPath $OutputDirectory -Recurse -Force }
New-Item -ItemType Directory -Force $OutputDirectory | Out-Null

function Write-Utf8NoBom([string]$Path, [string]$Text) {
    [IO.File]::WriteAllText($Path, $Text, (New-Object System.Text.UTF8Encoding $false))
}

function Split-LargeFile([string]$Source, [string]$TargetBase, [int64]$Limit) {
    $input = [IO.File]::OpenRead($Source)
    $buffer = New-Object byte[] (4 * 1024 * 1024)
    $index = 1
    try {
        while ($input.Position -lt $input.Length) {
            $partPath = ('{0}.part{1:D3}' -f $TargetBase, $index)
            $output = [IO.File]::Create($partPath)
            $remaining = $Limit
            try {
                while ($remaining -gt 0) {
                    $want = [int][Math]::Min([int64]$buffer.Length, $remaining)
                    $read = $input.Read($buffer, 0, $want)
                    if ($read -le 0) { break }
                    $output.Write($buffer, 0, $read)
                    $remaining -= $read
                }
            } finally { $output.Dispose() }
            $index++
        }
    } finally { $input.Dispose() }
}

$sums = New-Object System.Collections.Generic.List[string]
$parts = New-Object System.Collections.Generic.List[object]
$files = @(Get-ChildItem -LiteralPath $VersionDirectory -Recurse -File | Sort-Object FullName)
foreach ($file in $files) {
    $relative = $file.FullName.Substring($VersionDirectory.Length + 1)
    $flat = ($relative -replace '[\\/]', '-')
    $target = Join-Path $OutputDirectory $flat
    if (Test-Path -LiteralPath $target) { throw ('Duplicate release asset name: ' + $flat) }
    $hash = (Get-FileHash -LiteralPath $file.FullName -Algorithm SHA256).Hash
    if ($file.Length -gt $limit) {
        Split-LargeFile $file.FullName $target $limit
        $made = @(Get-ChildItem -LiteralPath $OutputDirectory -Filter ($flat + '.part*') | Sort-Object Name)
        foreach ($part in $made) { $parts.Add($part) | Out-Null }
    } else {
        Copy-Item -LiteralPath $file.FullName -Destination $target
    }
    $sums.Add(($hash + '  ' + $flat))
}
if ($sums.Count -ne $files.Count) { throw 'Hash count does not match packaged file count' }
Write-Utf8NoBom (Join-Path $OutputDirectory 'SHA256SUMS.txt') (($sums -join "`n") + "`n")

$joinScript = @'
param([string]$Directory = $PSScriptRoot)
$ErrorActionPreference = 'Stop'
Set-Location -LiteralPath $Directory
$groups = @{}
Get-ChildItem -LiteralPath $Directory -File | Where-Object { $_.Name -match '^(.*)\.part(\d+)$' } | ForEach-Object {
    $base = $Matches[1]
    if (!$groups.ContainsKey($base)) { $groups[$base] = New-Object System.Collections.ArrayList }
    [void]$groups[$base].Add($_)
}
foreach ($base in $groups.Keys) {
    $target = Join-Path $Directory $base
    $output = [IO.File]::Create($target)
    try {
        foreach ($part in ($groups[$base] | Sort-Object Name)) {
            $input = [IO.File]::OpenRead($part.FullName)
            try { $input.CopyTo($output) } finally { $input.Dispose() }
        }
    } finally { $output.Dispose() }
    foreach ($part in $groups[$base]) { Remove-Item -LiteralPath $part.FullName -Force }
}
$failures = New-Object System.Collections.Generic.List[string]
foreach ($line in (Get-Content -LiteralPath (Join-Path $Directory 'SHA256SUMS.txt'))) {
    if ($line -match '^([0-9A-Fa-f]{64})\s+\*?(.+)$') {
        $expected = $Matches[1].ToUpperInvariant()
        $name = $Matches[2].Trim()
        $path = Join-Path $Directory $name
        if (!(Test-Path -LiteralPath $path)) { $failures.Add('missing ' + $name); continue }
        $actual = (Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash
        if ($actual -ne $expected) { $failures.Add('hash ' + $name) }
    }
}
if ($failures.Count -gt 0) { throw ('Verification failed: ' + ($failures -join '; ')) }
Write-Host 'Joined and verified. Run ChibiRTS.exe.'
'@
Write-Utf8NoBom (Join-Path $OutputDirectory 'join-release.ps1') $joinScript

$joinCmd = @'
@echo off
setlocal enabledelayedexpansion
cd /d "%~dp0"
for %%F in (*.part001) do (
  set "base=%%~nF"
  copy /b "!base!.part*" "!base!" >nul
  del "!base!.part*" >nul
)
echo Joined. Run join-release.ps1 once to verify hashes before starting ChibiRTS.exe.
'@
Write-Utf8NoBom (Join-Path $OutputDirectory 'join-release.cmd') $joinCmd

$totalBytes = ($files | Measure-Object Length -Sum).Sum
$info = Get-Content -Raw -Encoding UTF8 (Join-Path $VersionDirectory 'release-info.json') | ConvertFrom-Json
$commit = [string]$info.commit
$body = @"
# 三国赤壁 · 高清重制 $Tag

预发布版本 ${versionName}，由本地发布脚本生成。

- 提交：$commit
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
Write-Utf8NoBom (Join-Path (Split-Path $OutputDirectory -Parent) 'release-body.md') $body

$large = @(Get-ChildItem -LiteralPath $OutputDirectory -Recurse -File | Where-Object { $_.Length -ge 1GB })
if ($large.Count -gt 0) { throw ('Release asset exceeds 1 GiB: ' + $large[0].Name) }
Write-Output ('PACKAGE ' + $versionName + ' files=' + $files.Count + ' parts=' + $parts.Count + ' assets=' + @(Get-ChildItem -LiteralPath $OutputDirectory -File).Count)
Write-Output ('PACKAGE DIR ' + $OutputDirectory)
