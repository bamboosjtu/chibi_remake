param(
    [int]$Units = 200,
    [int]$Engage = 60,
    [int]$Ticks = 300,
    [int]$Frames = 180,
    [switch]$Stress,
    [switch]$CapacityStress,
    [string]$Map = "chibic17",
    [string]$Output = "",
    [string]$ReleasePack = "",
    [string]$RunnerDirectory = "",
    [switch]$DeveloperSource,
    [switch]$ProfileUnits,
    [switch]$CpuMinimap,
    [ValidateSet('project','gl_compatibility','mobile','forward_plus')][string]$RenderingMethod = 'project',
    [int]$MaxSeconds = 1800
)
# Full-battle benchmark gate. The microbench in test_unit_index only covers the
# placement index; this run drives the real scenario with AI, combat,
# projectiles, economy, rendering and terrain streaming.
$ErrorActionPreference = 'Continue'
$root = Split-Path $PSScriptRoot -Parent
Set-Location -LiteralPath $root
if ($Stress -and $CapacityStress) { throw 'Stress and CapacityStress are separate workloads' }
if ($CapacityStress) { $Engage=240; $Frames=120 }
if ($Stress) { $Units = 660; $Engage = 240; $Ticks = 300; $Frames = 120 }
$p95Budget = if ($Stress -or $CapacityStress) { 1200.0 } else { 500.0 }
$fpsFloor = if ($Stress -or $CapacityStress) { 30.0 } else { 60.0 }
$workingSetBudget = if ($Stress -or $CapacityStress) { 3.5GB } else { 2.5GB }
$videoBudget = if ($Stress -or $CapacityStress) { 1.5GB } else { 1.25GB }
. (Join-Path $PSScriptRoot 'engine_environment.ps1')
if ($DeveloperSource -and $ReleasePack) { throw 'Choose DeveloperSource or ReleasePack' }
if (!$DeveloperSource -and !$ReleasePack) {
    $pointer=Get-Content -Raw -LiteralPath (Join-Path $root 'release/current.json') | ConvertFrom-Json
    $ReleasePack=Join-Path (Join-Path $root 'release') ($pointer.directory+'/ChibiRTS.pck')
}
$engine = Resolve-ChibiEngine $root
$output = if ($Output) { [IO.Path]::GetFullPath($Output) } else { Join-Path $root ('_work/bench/full-battle-' + (Get-Date -Format 'yyyyMMdd-HHmmss') + '.json') }
New-Item -ItemType Directory -Force (Split-Path $output -Parent) | Out-Null
$arguments = '--path godot/chibi_remake --script "' + (Join-Path $root 'tools/gd/bench_full_battle.gd') + '" -- --no-intro --save-test-id=full-battle-bench --bench-map=' + $Map + ' --bench-units=' + $Units + ' --bench-engage=' + $Engage + ' --bench-ticks=' + $Ticks + ' --bench-frames=' + $Frames + ' --bench-output="' + $output + '"'
if ($ReleasePack) {
    $packPath=[IO.Path]::GetFullPath($ReleasePack)
    if (!(Test-Path -LiteralPath $packPath -PathType Leaf)) { throw ('Missing release PCK: '+$packPath) }
    $template=Join-Path $root '_work/build/roaming/Godot/export_templates/4.7.2.stable/windows_release_x86_64.exe'
    & node tools/verify_engine.mjs --platform win32_release --engine $template
    if ($LASTEXITCODE -ne 0) { throw 'Unreviewed release template' }
    $nativeDirectory=if ($RunnerDirectory) { [IO.Path]::GetFullPath($RunnerDirectory) } else { Join-Path (Split-Path $output -Parent) ('native-bench-'+[Guid]::NewGuid().ToString('N')) }
    $engine=Join-Path $nativeDirectory 'ChibiBench.exe'
    $inputs=@{'ChibiBench.exe'=$template;'ChibiBench.pck'=$packPath}
    $sidecars=Join-Path (Split-Path $packPath -Parent) 'addons'
    if (Test-Path -LiteralPath $sidecars -PathType Container) {
        foreach ($file in @(Get-ChildItem -LiteralPath $sidecars -File -Recurse)) { $inputs['addons/'+$file.FullName.Substring($sidecars.Length+1).Replace('\','/')]=$file.FullName }
    }
    foreach ($dll in @(Get-ChildItem -LiteralPath (Split-Path $packPath -Parent) -Filter '*.dll' -File)) { $inputs[$dll.Name]=$dll.FullName }
    $hashes=@{}; foreach ($name in $inputs.Keys) { $hashes[$name]=(Get-FileHash -LiteralPath $inputs[$name]).Hash }
    $marker=Join-Path $nativeDirectory 'runner-complete.json'
    if (!(Test-Path -LiteralPath $nativeDirectory)) {
        New-Item -ItemType Directory -Force $nativeDirectory | Out-Null
        foreach ($name in $inputs.Keys) {
            $target=Join-Path $nativeDirectory $name
            New-Item -ItemType Directory -Force (Split-Path $target -Parent) | Out-Null
            Copy-Item -LiteralPath $inputs[$name] -Destination $target
        }
        [IO.File]::WriteAllText($marker,($hashes | ConvertTo-Json),(New-Object System.Text.UTF8Encoding $false))
    } elseif (!(Test-Path -LiteralPath $marker)) { throw 'Incomplete benchmark runner; choose a new RunnerDirectory' }
    foreach ($name in $inputs.Keys) {
        $target=Join-Path $nativeDirectory $name
        if (!(Test-Path -LiteralPath $target -PathType Leaf) -or (Get-FileHash -LiteralPath $target).Hash -ne $hashes[$name]) { throw ('Benchmark runner changed; choose a new RunnerDirectory: '+$name) }
    }
    if (@(Get-ChildItem -LiteralPath $nativeDirectory -Filter '*.dll' -File -Recurse).Count -ne @($inputs.Keys | Where-Object { $_ -match '\.dll$' }).Count) { throw 'Unexpected benchmark runner DLL' }
    $arguments='-- --full-battle-bench --no-intro --save-test-id=full-battle-bench --bench-map='+$Map+' --bench-units='+$Units+' --bench-engage='+$Engage+' --bench-ticks='+$Ticks+' --bench-frames='+$Frames+' --bench-output="'+$output+'"'
}
if ($CapacityStress) { $arguments += ' --bench-capacity' }
if ($ProfileUnits) { $arguments += ' --bench-profile' }
if ($CpuMinimap) { $arguments += ' --cpu-minimap' }
if ($RenderingMethod -ne 'project') {
    $driver=if ($RenderingMethod -eq 'gl_compatibility') { 'opengl3' } else { 'vulkan' }
    $arguments='--rendering-method '+$RenderingMethod+' --rendering-driver '+$driver+' '+$arguments
}
$benchmarkStarted=[DateTime]::UtcNow
$start = [Diagnostics.ProcessStartInfo]::new($engine, $arguments)
$start.UseShellExecute = $false
$start.RedirectStandardOutput = $true
$start.RedirectStandardError = $true
$start.WorkingDirectory = $root
$benchmarkProfile=Join-Path (Split-Path $output -Parent) ([IO.Path]::GetFileNameWithoutExtension($output)+'-profile')
New-Item -ItemType Directory -Force $benchmarkProfile | Out-Null
$start.EnvironmentVariables['APPDATA']=$benchmarkProfile
$start.EnvironmentVariables['LOCALAPPDATA']=$benchmarkProfile
$process = [Diagnostics.Process]::Start($start)
$stdoutTask=$process.StandardOutput.ReadToEndAsync()
$stderrTask=$process.StandardError.ReadToEndAsync()
$peak = 0L
$watch=[Diagnostics.Stopwatch]::StartNew()
$timedOut=$false
while (!$process.HasExited) {
    if ($watch.Elapsed.TotalSeconds -gt $MaxSeconds) { $timedOut=$true; $process.Kill(); $process.WaitForExit(); break }
    try {
        foreach ($candidate in @(Get-Process -Id $process.Id -ErrorAction SilentlyContinue)) { $peak = [Math]::Max($peak, $candidate.WorkingSet64) }
    } catch { }
    Start-Sleep -Milliseconds 200
}
try {
    foreach ($candidate in @(Get-Process -Id $process.Id -ErrorAction SilentlyContinue)) { $peak = [Math]::Max($peak, $candidate.PeakWorkingSet64) }
} catch { }
$engineOutput=$stdoutTask.Result+$stderrTask.Result
[IO.File]::WriteAllText($output+'.log',$engineOutput,(New-Object System.Text.UTF8Encoding $false))
if ($engineOutput -match 'SCRIPT ERROR:|Parse Error:|ERROR: Error calling|Corrupted header|Couldn.t load project data|Couldn.t save project.binary|GDExtension dynamic library not found|Can.t open dynamic library') { throw ('Benchmark engine errors; log: '+$output+'.log') }
if ($timedOut -or $process.ExitCode -ne 0 -or !(Test-Path -LiteralPath $output)) { throw ('Benchmark process failed: ' + $process.ExitCode + '; log: ' + $output+'.log') }
if ([IO.File]::GetLastWriteTimeUtc($output) -lt $benchmarkStarted) { throw 'Stale benchmark report was not produced by this run' }
$report = Get-Content -Raw -Encoding UTF8 $output | ConvertFrom-Json
if (!$DeveloperSource -and $report.engineBuild -ne 'release') { throw 'Acceptance requires a release template' }
$report | Add-Member -NotePropertyName acceptanceRun -NotePropertyValue (!$DeveloperSource -and !$ProfileUnits -and !$CpuMinimap -and $RenderingMethod -eq 'project') -Force
if ($RenderingMethod -ne 'project' -and $report.renderingMethod -ne $RenderingMethod) { throw 'Requested rendering method was not active' }
$report | Add-Member -NotePropertyName engineSha256 -NotePropertyValue (Get-FileHash -LiteralPath $engine).Hash.ToLowerInvariant() -Force
if ($ReleasePack) {
    $report | Add-Member -NotePropertyName packPath -NotePropertyValue $packPath -Force
    if ((Get-FileHash -LiteralPath $packPath).Hash -ne $hashes['ChibiBench.pck']) { throw 'Source PCK changed during benchmark' }
    $report | Add-Member -NotePropertyName packSha256 -NotePropertyValue $hashes['ChibiBench.pck'].ToLowerInvariant() -Force
    $report | Add-Member -NotePropertyName runnerInputsSha256 -NotePropertyValue $hashes -Force
}
$report | Add-Member -NotePropertyName peakWorkingSetBytes -NotePropertyValue $peak -Force
$report | Add-Member -NotePropertyName p95BudgetMs -NotePropertyValue $p95Budget -Force
$report | Add-Member -NotePropertyName fpsFloor -NotePropertyValue $fpsFloor -Force
$report | Add-Member -NotePropertyName workingSetBudgetBytes -NotePropertyValue $workingSetBudget -Force
$report | Add-Member -NotePropertyName videoBudgetBytes -NotePropertyValue $videoBudget -Force
$report | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $output -Encoding UTF8
$failures = @()
if ($CapacityStress -and $report.workloadMode -ne 'scenario-capacity') { throw 'PCK does not support the capacity workload; rebuild it first' }
if (!$report.validWorkload -or $report.pausedAtEnd -or $report.gameEnd -ne 0 -or $report.simulationTicksAdvanced -le 0) { $failures += 'Invalid paused/stopped workload' }
if ([double]$report.ticksPerSecond -lt 0.95*[double]$report.targetTicksPerSecond) { $failures += ('Tick throughput '+$report.ticksPerSecond+' < 95% of '+$report.targetTicksPerSecond) }
if ([double]$report.simAccumulatorEnd -gt [Math]::Max(0.2,[double]$report.simAccumulatorBegin+0.1)) { $failures += ('Simulation backlog '+$report.simAccumulatorEnd+'s') }
if ([double]$report.commandLatencyP95Ms -gt 100.0) { $failures += ('Command latency '+$report.commandLatencyP95Ms+'ms > 100ms') }
if ([double]$report.unitsMeasured -lt [double]$report.unitsTarget) { $failures += ('units ' + $report.unitsMeasured + '/' + $report.unitsTarget) }
if ([double]$report.logicP95Ms -gt [double]$report.realtimeLogicBudgetMs) { $failures += ('Realtime tick P95 '+$report.logicP95Ms+'ms > '+$report.realtimeLogicBudgetMs+'ms') }
if ([double]$report.logicP95Ms -gt $p95Budget) { $failures += ('P95 ' + [math]::Round([double]$report.logicP95Ms, 1) + 'ms > ' + $p95Budget + 'ms') }
if ([double]$report.fps -lt $fpsFloor) { $failures += ('FPS ' + [math]::Round([double]$report.fps, 1) + ' < ' + $fpsFloor) }
if ($peak -gt $workingSetBudget) { $failures += ('working set ' + [math]::Round($peak / 1GB, 2) + 'GiB > ' + [math]::Round($workingSetBudget / 1GB, 2) + 'GiB') }
if ([double]$report.videoMemoryBytes -gt $videoBudget) { $failures += ('video memory ' + [math]::Round([double]$report.videoMemoryBytes / 1GB, 2) + 'GiB > ' + [math]::Round($videoBudget / 1GB, 2) + 'GiB') }
Write-Output ('FULL BATTLE BENCH units=' + $report.unitsMeasured + ' engaged=' + $Engage + ' P50=' + [math]::Round([double]$report.logicP50Ms, 1) + 'ms P95=' + [math]::Round([double]$report.logicP95Ms, 1) + 'ms FPS=' + [math]::Round([double]$report.fps, 1) + ' WS=' + [math]::Round($peak / 1GB, 2) + 'GiB VRAM=' + [math]::Round([double]$report.videoMemoryBytes / 1GB, 2) + 'GiB')
Write-Output ('REPORT ' + $output)
$report | Add-Member -NotePropertyName qualityPassed -NotePropertyValue ($failures.Count -eq 0) -Force
$report | Add-Member -NotePropertyName validationFailures -NotePropertyValue @($failures) -Force
$report | Add-Member -NotePropertyName minimumTickRateRatio -NotePropertyValue 0.95 -Force
$report | Add-Member -NotePropertyName commandLatencyBudgetMs -NotePropertyValue 100.0 -Force
$report | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $output -Encoding UTF8
if ($failures.Count -gt 0) {
    Write-Output ('FULL BATTLE BENCH FAIL ' + ($failures -join '; '))
    exit 1
}
Write-Output ('FULL BATTLE BENCH PASS reference=' + $report.cpu + ' / ' + $report.gpu)
exit 0

