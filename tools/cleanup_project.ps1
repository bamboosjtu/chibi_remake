param([switch]$Execute, [switch]$WorkOnly, [switch]$PruneVerification, [switch]$RetiredMediaOnly, [string]$ReportPath = 'docs/cleanup-report.json')
# 不能用 Stop：Godot 的证书警告会经原生 stderr 变成终止性错误，
# 整个构建当场中断（本项目已因此踩坑三次）。错误处理靠 try/catch + $LASTEXITCODE。
$ErrorActionPreference='Continue'
$cleanupRoot = [IO.Path]::GetFullPath((Split-Path $PSScriptRoot -Parent))
$workRoot = Join-Path $cleanupRoot '_work'
$reportAbsolute = [IO.Path]::GetFullPath((Join-Path $cleanupRoot $ReportPath))
if (!$reportAbsolute.StartsWith($cleanupRoot + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase)) { throw "Outside project report: $reportAbsolute" }
function Get-RelativePath([string]$base, [string]$full) {
    $base = $base.TrimEnd([IO.Path]::DirectorySeparatorChar)
    if ($full.StartsWith($base + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase)) { return $full.Substring($base.Length + 1) }
    return $full
}
$cleanupTargets = [Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
function Add-CleanupTarget([string]$relative) {
    $absolute = [IO.Path]::GetFullPath((Join-Path $cleanupRoot $relative))
    if (!$absolute.StartsWith($cleanupRoot + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase)) { throw "Outside project: $absolute" }
    if ($WorkOnly -and !$absolute.StartsWith($workRoot + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase)) { return }
    if (Test-Path -LiteralPath $absolute) { [void]$cleanupTargets.Add($absolute) }
}
# Only obsolete transcoded videos and their sidecars; AVI, WAV and OGG inputs stay.
foreach ($directory in @('cinematics','endings','events','intros')) {
    $relative = 'godot/chibi_remake/media/' + $directory
    $absolute = Join-Path $cleanupRoot $relative
    if (Test-Path -LiteralPath $absolute) {
        Get-ChildItem -LiteralPath $absolute -File | Where-Object { $_.Name -match '\.ogv(\.(uid|import))?$' } | ForEach-Object { Add-CleanupTarget ($relative + '/' + $_.Name) }
    }
}
Add-CleanupTarget 'godot/chibi_remake/media/MEDIA_MANIFEST.json'
# 无 APPDATA 时引擎会在工程内落地 user://（日志与存档），属于运行残渣。
Add-CleanupTarget 'godot/chibi_remake/Godot'
if (!$RetiredMediaOnly) {
foreach ($relative in @('godot/chibi_remake/.godot','_rea-cache','_rea-logs','_work/--list','_work/arch006','_work/battleview_base','_work/bv_backup','_work/png','_work/sheets','_work/tmp','_work/ghidra_proj','_work/art-v1-build/temp','_work/art-v1-build/local','_work/art-v1-build/roaming/Godot/app_userdata','_work/godot_appdata/Godot/app_userdata','_tools/ghidra_home/tmp')) { Add-CleanupTarget $relative }
Get-ChildItem -LiteralPath (Join-Path $cleanupRoot '_work') -File | Where-Object { $_.Extension -in @('.mjs','.ps1','.txt','.log','.png','.py','.bak','.err') -or $_.Name -in @('menu_gd_stage0_backup.gd','battleview_map.md','menu_map.md','scenario_s4.md') } | ForEach-Object { Add-CleanupTarget ((Get-RelativePath $cleanupRoot $_.FullName)) }
Get-ChildItem -LiteralPath (Join-Path $cleanupRoot '_work/hd') -Directory | Where-Object { $_.Name -notin @('sprites4_rgba','terrain4') } | ForEach-Object { Add-CleanupTarget ((Get-RelativePath $cleanupRoot $_.FullName)) }
Get-ChildItem -LiteralPath (Join-Path $cleanupRoot 'release') -File | Where-Object { $_.Name -notin @('ChibiRTS.exe','ChibiRTS.pck','ChibiRTS.console.exe','launcher.previous.exe') -and $_.Name -match '\.(exe|pck|tmp|truncated)$' } | ForEach-Object { Add-CleanupTarget ((Get-RelativePath $cleanupRoot $_.FullName)) }
Get-ChildItem -LiteralPath (Join-Path $cleanupRoot 'godot/chibi_remake/art/production') -Recurse -File | Where-Object { $_.Name -match '\.(log|log\.err|stderr|stdout)$' } | ForEach-Object { Add-CleanupTarget ((Get-RelativePath $cleanupRoot $_.FullName)) }
Get-ChildItem -LiteralPath (Join-Path $cleanupRoot '_tools') -File | Where-Object { $_.Extension -in @('.zip','.msi') } | ForEach-Object { Add-CleanupTarget ((Get-RelativePath $cleanupRoot $_.FullName)) }
# HD replacement is complete. Native sheets and superseded bake outputs are disposable.
foreach ($relative in @('godot/chibi_remake/sprites','godot/chibi_remake/sprites_hd','godot/chibi_remake/terrain_hd','godot/chibi_remake/art/remake_hd','godot/chibi_remake/art/source_fallback','godot/chibi_remake/art/full/team_masks','godot/chibi_remake/terrain.png','godot/chibi_remake/terrain.png.import','godot/chibi_remake/menu_bg.png','godot/chibi_remake/menu_bg.png.import')) { Add-CleanupTarget $relative }
Get-ChildItem -LiteralPath (Join-Path $cleanupRoot 'godot/chibi_remake') -File | Where-Object { $_.Name -match '^terrain_chibi.*\.png(\.import)?$' } | ForEach-Object { Add-CleanupTarget ((Get-RelativePath $cleanupRoot $_.FullName)) }
$runningBuild = @(Get-CimInstance Win32_Process | Where-Object { $_.Name -match '^Godot.*\.exe$' -and $_.CommandLine -match '[\\/]_work[\\/]build[\\/](stage|candidate)-' })
if ($runningBuild.Count) { throw 'A Godot build is running; finish it before cleanup.' }
Get-ChildItem -LiteralPath (Join-Path $cleanupRoot '_work/build') -Force | Where-Object { $_.Name -match '^(stage-|candidate-|jpeg-size-test$|temp$|local$|.*\.(log|err)$)' } | ForEach-Object { Add-CleanupTarget ((Get-RelativePath $cleanupRoot $_.FullName)) }
foreach ($relative in @('_work/architecture-tests','_work/chibil1-fix','_work/chibil1-polish','_work/decor_probe','_work/levelshots','_work/panel-check','_work/shots','_work/ui_probe','_work/worker-groups','_work/gate-check','_work/hud','_work/chibil1-manual.json','_work/view-report.json','_work/godot_appdata/Godot/cache')) { Add-CleanupTarget $relative }
# 已迁入 tools/gd 的回归及已归档发布证据，不再保留多轮沙箱和旧工程副本。
foreach ($relative in @('_work/ci','_work/m0','_work/resource-fix','_work/plan-implementation','_work/review','_work/review-current','_work/mousestudio')) { Add-CleanupTarget $relative }
Get-ChildItem -LiteralPath (Join-Path $cleanupRoot '_work') -File -Filter 'probe*.gd' | ForEach-Object { Add-CleanupTarget ((Get-RelativePath $cleanupRoot $_.FullName)) }
foreach ($relative in @('_work/build/roaming/Godot/app_userdata','_work/build/roaming/Godot/editor_settings-4.7.tres')) { Add-CleanupTarget $relative }
$buildTemplates=Join-Path $cleanupRoot '_work/build/roaming/Godot/export_templates/4.7.2.stable'
if (Test-Path -LiteralPath $buildTemplates) {
    Get-ChildItem -LiteralPath $buildTemplates -File | Where-Object { $_.Name -notin @('windows_release_x86_64.exe','windows_debug_x86_64.exe','windows_release_x86_64_console.exe','windows_debug_x86_64_console.exe','version.txt','icudt_godot.dat') } | ForEach-Object { Add-CleanupTarget ((Get-RelativePath $cleanupRoot $_.FullName)) }
}
foreach ($name in @('script_templates','text_editor_themes','export_templates','feature_profiles')) {
    $emptyDirectory = Join-Path $cleanupRoot ('godot/chibi_remake/' + $name)
    if ((Test-Path -LiteralPath $emptyDirectory) -and @(Get-ChildItem -LiteralPath $emptyDirectory -Force).Count -eq 0) { Add-CleanupTarget ('godot/chibi_remake/' + $name) }
}
# Retain painting inputs referenced by deliveries; discard their reproducible probes.
if (Test-Path -LiteralPath (Join-Path $cleanupRoot '_work/remaster-final')) {
    Get-ChildItem -LiteralPath (Join-Path $cleanupRoot '_work/remaster-final') -Directory | Where-Object { $_.Name -notin @('hd-assets-input','hd-assets-input2','input','input-icons','references','pose-references') } | ForEach-Object { Add-CleanupTarget ((Get-RelativePath $cleanupRoot $_.FullName)) }
    Get-ChildItem -LiteralPath (Join-Path $cleanupRoot '_work/remaster-final') -File | Where-Object { $_.Extension -in @('.log','.err','.ps1') } | ForEach-Object { Add-CleanupTarget ((Get-RelativePath $cleanupRoot $_.FullName)) }
}
if ($PruneVerification) {
    $verificationRoot=Join-Path $workRoot 'verification'
    $verified=Get-Content -LiteralPath (Join-Path $verificationRoot 'verification.json') -Raw -ErrorAction Stop | ConvertFrom-Json
    $checks=@($verified.regressions)+@($verified.selftests)+@($verified.simtests)
    if ($checks.Count -eq 0 -or @($checks | Where-Object { !$_.pass }).Count) { throw 'Keep raw verification evidence until every check passes.' }
    foreach ($name in @('appdata-sim','appdata-smoke','appdata-test_architecture','appdata-test_clock','appdata-test_construction','appdata-test_initial_teams','appdata-test_m0','review-fixes.json','selftest.json','simtest.json')) {
        Add-CleanupTarget ('_work/verification/'+$name)
    }
    Get-ChildItem -LiteralPath $verificationRoot -File -Filter '*.log' | ForEach-Object { Add-CleanupTarget ((Get-RelativePath $cleanupRoot $_.FullName)) }
}
}
$removed = @(); $skipped = @(); $bytes = [long]0; $files = 0; $scripts = 0
foreach ($target in ($cleanupTargets | Sort-Object)) {
    $resolved = (Resolve-Path -LiteralPath $target).ProviderPath
    if (!$resolved.StartsWith($cleanupRoot + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase)) { throw "Outside project: $resolved" }
    $item = Get-Item -LiteralPath $resolved -Force
    if ($item.Attributes -band [IO.FileAttributes]::ReparsePoint) { throw "Refusing reparse point: $resolved" }
    if ($item.PSIsContainer) {
        $links = @(Get-ChildItem -LiteralPath $resolved -Recurse -Force -Attributes ReparsePoint)
        if ($links.Count) { throw "Refusing descendant reparse point: $resolved" }
    }
    $contents = if ($item.PSIsContainer) { @(Get-ChildItem -LiteralPath $resolved -Recurse -File -Force) } else { @($item) }
    $size = [long](($contents | Measure-Object Length -Sum).Sum)
    if ($Execute) {
        try { Remove-Item -LiteralPath $resolved -Recurse -Force -ErrorAction Stop }
        catch {
            $skipped += @{ path=(Get-RelativePath $cleanupRoot $resolved); reason=$_.Exception.Message }
            continue
        }
    }
    $bytes += $size; $files += $contents.Count
    $scripts += @($contents | Where-Object { $_.Extension -in @('.gd','.mjs','.js','.py','.ps1','.bat','.cmd') }).Count
    $removed += @{ path=(Get-RelativePath $cleanupRoot $resolved); bytes=$size; files=$contents.Count }
}
$result = @{ executed=[bool]$Execute; workOnly=[bool]$WorkOnly; retiredMediaOnly=[bool]$RetiredMediaOnly; completedAtUtc=[DateTime]::UtcNow.ToString('o'); targets=$removed.Count; files=$files; scripts=$scripts; bytes=$bytes; removed=$removed; skipped=$skipped }
if ($Execute) {
    $result | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $reportAbsolute -Encoding utf8
}
Write-Output ("Cleanup execute={0} targets={1} files={2} reclaimedGiB={3:N2}" -f [bool]$Execute,$removed.Count,$files,($bytes/1GB))
Write-Output ("Skipped in-use targets: {0}" -f $skipped.Count)
