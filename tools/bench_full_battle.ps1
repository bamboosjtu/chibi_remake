param(
    [int]$Units = 200,
    [int]$Engage = 60,
    [int]$Ticks = 300,
    [int]$Frames = 180,
    [switch]$Stress,
    [string]$Map = "chibic17",
    [string]$Output = "",
    [int]$MaxSeconds = 1800
)
# Full-battle benchmark gate. The microbench in test_unit_index only covers the
# placement index; this run drives the real scenario with AI, combat,
# projectiles, economy, rendering and terrain streaming.
$ErrorActionPreference = 'Continue'
$root = Split-Path $PSScriptRoot -Parent
Set-Location -LiteralPath $root
if ($Stress) { $Units = 660; $Engage = 240; $Ticks = 300; $Frames = 120 }
$p95Budget = if ($Stress) { 1200.0 } else { 500.0 }
$fpsFloor = if ($Stress) { 30.0 } else { 60.0 }
$workingSetBudget = if ($Stress) { 3.5GB } else { 2.5GB }
$videoBudget = if ($Stress) { 1.5GB } else { 1.25GB }
. (Join-Path $PSScriptRoot 'engine_environment.ps1')
$engine = Resolve-ChibiEngine $root
& node tools/verify_engine.mjs --engine $engine
if ($LASTEXITCODE -ne 0) { throw 'Unreviewed benchmark engine' }
$output = if ($Output) { [IO.Path]::GetFullPath($Output) } else { Join-Path $root ('_work/bench/full-battle-' + (Get-Date -Format 'yyyyMMdd-HHmmss') + '.json') }
New-Item -ItemType Directory -Force (Split-Path $output -Parent) | Out-Null
$arguments = '--path godot/chibi_remake --script "' + (Join-Path $root 'tools/gd/bench_full_battle.gd') + '" -- --no-intro --save-test-id=full-battle-bench --bench-map=' + $Map + ' --bench-units=' + $Units + ' --bench-engage=' + $Engage + ' --bench-ticks=' + $Ticks + ' --bench-frames=' + $Frames + ' --bench-output=' + $output
$start = [Diagnostics.ProcessStartInfo]::new($engine, $arguments)
$start.UseShellExecute = $false
$start.RedirectStandardOutput = $true
$start.RedirectStandardError = $true
$start.WorkingDirectory = $root
$profile=Join-Path (Split-Path $output -Parent) ([IO.Path]::GetFileNameWithoutExtension($output)+'-profile')
New-Item -ItemType Directory -Force $profile | Out-Null
$start.EnvironmentVariables['APPDATA']=$profile
$start.EnvironmentVariables['LOCALAPPDATA']=$profile
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
[IO.File]::WriteAllText($output+'.log',($stdoutTask.Result+$stderrTask.Result),(New-Object System.Text.UTF8Encoding $false))
if ($timedOut -or $process.ExitCode -ne 0 -or !(Test-Path -LiteralPath $output)) { throw ('Benchmark process failed: ' + $process.ExitCode + '; log: ' + $output+'.log') }
$report = Get-Content -Raw -Encoding UTF8 $output | ConvertFrom-Json
$report | Add-Member -NotePropertyName peakWorkingSetBytes -NotePropertyValue $peak -Force
$report | Add-Member -NotePropertyName p95BudgetMs -NotePropertyValue $p95Budget -Force
$report | Add-Member -NotePropertyName fpsFloor -NotePropertyValue $fpsFloor -Force
$report | Add-Member -NotePropertyName workingSetBudgetBytes -NotePropertyValue $workingSetBudget -Force
$report | Add-Member -NotePropertyName videoBudgetBytes -NotePropertyValue $videoBudget -Force
$report | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $output -Encoding UTF8
$failures = @()
if (!$report.validWorkload -or $report.pausedAtEnd -or $report.gameEnd -ne 0 -or $report.simulationTicksAdvanced -le 0) { $failures += 'Invalid paused/stopped workload' }
if ([double]$report.ticksPerSecond -lt 0.95*[double]$report.targetTicksPerSecond) { $failures += ('Tick throughput '+$report.ticksPerSecond+' < 95% of '+$report.targetTicksPerSecond) }
if ([double]$report.simAccumulatorEnd -gt [Math]::Max(0.2,[double]$report.simAccumulatorBegin+0.1)) { $failures += ('Simulation backlog '+$report.simAccumulatorEnd+'s') }
if ([double]$report.commandLatencyP95Ms -gt 100.0) { $failures += ('Command latency '+$report.commandLatencyP95Ms+'ms > 100ms') }
if ([double]$report.unitsMeasured -lt [double]$report.unitsTarget) { $failures += ('units ' + $report.unitsMeasured + '/' + $report.unitsTarget) }
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

