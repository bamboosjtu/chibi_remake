param([switch]$SkipData,[switch]$SkipImport,[switch]$NoOriginalMedia,[switch]$NoPublish,[switch]$AllowDirty,[switch]$SkipVerify)
# 注意：**不能**用 'Stop' —— Godot 在 stderr 上会打印一条无害的
# "Failed to read the root certificate store"，被 PowerShell 当成 NativeCommandError，
# 直接中断整个构建。改为 'Continue'，每个原生调用都已显式检查 $LASTEXITCODE。
$ErrorActionPreference='Continue'
. (Join-Path $PSScriptRoot 'build_environment.ps1')
Set-Location -LiteralPath $BuildRoot
try {
    if ($SkipVerify -and !$NoPublish) { throw '-SkipVerify requires -NoPublish; unverified builds cannot be published' }
    $sourceCommit=(& git -C $BuildRoot rev-parse HEAD 2>$null)
    if (!$sourceCommit) { $sourceCommit='unknown' }
    $sourceDirty=@(& git -C $BuildRoot status --porcelain 2>$null).Count -gt 0
    Initialize-BuildEnvironment
    if ($NoOriginalMedia) { $env:CHIBI_NO_ORIGINAL_MEDIA='1' } else { Remove-Item Env:CHIBI_NO_ORIGINAL_MEDIA -ErrorAction SilentlyContinue }
    $godot=Join-Path $BuildRoot 'Godot_v4.7.2-stable_win64_console.exe'
    if (!$SkipData) {
        $meds=Join-Path $BuildRoot '_work/iso/MEDS'
        if (!(Test-Path -LiteralPath $meds)) { throw '缺少 _work/iso/MEDS；请补齐原版文件，或显式使用 -SkipData 复用现有 data/*.json' }
        $medFiles=@(Get-ChildItem -LiteralPath $meds -Filter '*.MED')
        if ($medFiles.Count -eq 0) { throw '_work/iso/MEDS 中没有 .MED 文件；拒绝静默打包旧关卡数据' }
        foreach ($med in $medFiles) {
            & node tools/godot_export.mjs godot/chibi_remake --map $med.BaseName --hd --hd-sprites
            if ($LASTEXITCODE -ne 0) { throw 'Level export failed' }
        }
        $sourceDirty=$sourceDirty -or @(& git -C $BuildRoot status --porcelain 2>$null).Count -gt 0
    }
    $id=(Get-Date -Format 'yyyyMMdd_HHmmss')+'_'+[Guid]::NewGuid().ToString('N').Substring(0,8)
    & node tools/build_terrain.mjs
    if ($LASTEXITCODE -ne 0) { throw "Terrain source rebuild failed" }
	& node tools/runtime_assets.mjs --check --hash
	if ($LASTEXITCODE -ne 0) { throw 'Declared runtime asset check failed' }
    $stage=Join-Path $BuildRoot ('_work/build/stage-'+$id)
    & node tools/stage_release.mjs $stage
    if ($LASTEXITCODE -ne 0) { throw 'Resource dependency staging failed' }
    node tools/dedupe_terrain.mjs $stage
    if ($LASTEXITCODE -ne 0) { throw 'Terrain deduplication failed' }
    $inputs=Get-Content -Raw (Join-Path $stage 'release_inputs.json') | ConvertFrom-Json
    foreach ($file in $inputs.files) { if (!(Test-Path -LiteralPath (Join-Path $stage $file))) { throw ('Missing staged resource: '+$file) } }
    $log=Join-Path $BuildRoot ('_work/build/import-'+$id+'.log')
    # A new staging checkout must import its declared resources, even when old caches exist.
    & $godot --headless --path $stage --import *> $log
    if ($LASTEXITCODE -ne 0) { throw 'Stage import failed' }
    $candidate=Join-Path $BuildRoot ('_work/build/candidate-'+$id)
    New-Item -ItemType Directory -Force $candidate | Out-Null
    $exe=Join-Path $candidate 'ChibiRTS.exe'
    & $godot --headless --path $stage --export-release 'Windows HD Art' $exe *> (Join-Path $candidate 'export.log')
    if ($LASTEXITCODE -ne 0) { throw 'Export failed' }
    [IO.File]::WriteAllText((Join-Path $candidate 'portable.txt'), 'userdata', (New-Object System.Text.UTF8Encoding $false))
    # Launch the candidate before it can be published. A build that exports but
    # cannot load a map must fail here, not at the player's first click.
    $verification='unverified'; $verificationNote=''
    if ($SkipVerify) {
        $verification='skipped'; $verificationNote='-SkipVerify'
        Write-Warning 'Candidate was not launched (-SkipVerify); the manifest records verification=skipped'
    } else {
        $verifyEngine=Join-Path $BuildRoot 'Godot_v4.7.2-stable_win64.exe'
        if (!(Test-Path -LiteralPath $verifyEngine)) { throw '缺少 Godot_v4.7.2-stable_win64.exe；候选包验收需要它（确需跳过请显式加 -SkipVerify）' }
        & (Join-Path $PSScriptRoot 'verify_candidate.ps1') -Executable $exe -StageDirectory $stage
        if ($LASTEXITCODE -ne 0) { throw ('Candidate verification failed: exit ' + $LASTEXITCODE) }
        $verification='candidate-smoke'
        $verificationNote='release_tests + all maps + deterministic baselines'
        Write-Output 'Candidate smoke passed'
    }
    & (Join-Path $PSScriptRoot 'write_build_manifest.ps1') -Executable $exe -SourceCommit $sourceCommit -SourceDirty:$sourceDirty -Verification $verification -VerificationNote $verificationNote
    if (!(Test-Path -LiteralPath (Join-Path $candidate 'build-manifest.json'))) { throw 'Build manifest missing' }
    if (!$NoPublish) { & (Join-Path $PSScriptRoot 'publish_release.ps1') -Executable $exe -AllowDirty:$AllowDirty }
    Write-Output "Built candidate: $candidate"
} catch { Write-Error $_; exit 1 } finally { Restore-BuildEnvironment }
exit 0
