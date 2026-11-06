param(
    [int]$Units = 200,
    [int]$Engage = 60,
    [int]$Ticks = 300,
    [int]$Frames = 180,
    [switch]$Stress,
    [string]$Map = "chibic17"
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
$engine = Join-Path $root 'Godot_v4.7.2-stable_win64_console.exe'
if (!(Test-Path -LiteralPath $engine)) { throw 'Missing Godot engine: Godot_v4.7.2-stable_win64_console.exe' }
$output = Join-Path $root ('_work/bench/full-battle-' + (Get-Date -Format 'yyyyMMdd-HHmmss') + '.json')
New-Item -ItemType Directory -Force (Split-Path $output -Parent) | Out-Null
$arguments = '--path godot/chibi_remake --script "' + (Join-Path $root 'tools/gd/bench_full_battle.gd') + '" -- --bench-map=' + $Map + ' --bench-units=' + $Units + ' --bench-engage=' + $Engage + ' --bench-ticks=' + $Ticks + ' --bench-frames=' + $Frames + ' --bench-output=' + $output
$start = [Diagnostics.ProcessStartInfo]::new($engine, $arguments)
$start.UseShellExecute = $false
$start.WorkingDirectory = $root
$process = [Diagnostics.Process]::Start($start)
$peak = 0L
while (!$process.HasExited) {
    try {
        foreach ($candidate in @(Get-Process -Name 'Godot*' -ErrorAction SilentlyContinue)) { $peak = [Math]::Max($peak, $candidate.WorkingSet64) }
    } catch { }
    Start-Sleep -Milliseconds 200
}
try {
    foreach ($candidate in @(Get-Process -Name 'Godot*' -ErrorAction SilentlyContinue)) { $peak = [Math]::Max($peak, $candidate.PeakWorkingSet64) }
} catch { }
if ($process.ExitCode -ne 0 -or !(Test-Path -LiteralPath $output)) { throw ('Benchmark process failed: ' + $process.ExitCode) }
$report = Get-Content -Raw -Encoding UTF8 $output | ConvertFrom-Json
$report | Add-Member -NotePropertyName peakWorkingSetBytes -NotePropertyValue $peak -Force
$report | Add-Member -NotePropertyName p95BudgetMs -NotePropertyValue $p95Budget -Force
$report | Add-Member -NotePropertyName fpsFloor -NotePropertyValue $fpsFloor -Force
$report | Add-Member -NotePropertyName workingSetBudgetBytes -NotePropertyValue $workingSetBudget -Force
$report | Add-Member -NotePropertyName videoBudgetBytes -NotePropertyValue $videoBudget -Force
$report | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $output -Encoding UTF8
$failures = @()
if ([double]$report.unitsMeasured -lt [double]$report.unitsTarget) { $failures += ('units ' + $report.unitsMeasured + '/' + $report.unitsTarget) }
if ([double]$report.logicP95Ms -gt $p95Budget) { $failures += ('P95 ' + [math]::Round([double]$report.logicP95Ms, 1) + 'ms > ' + $p95Budget + 'ms') }
if ([double]$report.fps -lt $fpsFloor) { $failures += ('FPS ' + [math]::Round([double]$report.fps, 1) + ' < ' + $fpsFloor) }
if ($peak -gt $workingSetBudget) { $failures += ('working set ' + [math]::Round($peak / 1GB, 2) + 'GiB > ' + [math]::Round($workingSetBudget / 1GB, 2) + 'GiB') }
if ([double]$report.videoMemoryBytes -gt $videoBudget) { $failures += ('video memory ' + [math]::Round([double]$report.videoMemoryBytes / 1GB, 2) + 'GiB > ' + [math]::Round($videoBudget / 1GB, 2) + 'GiB') }
Write-Output ('FULL BATTLE BENCH units=' + $report.unitsMeasured + ' engaged=' + $Engage + ' P50=' + [math]::Round([double]$report.logicP50Ms, 1) + 'ms P95=' + [math]::Round([double]$report.logicP95Ms, 1) + 'ms FPS=' + [math]::Round([double]$report.fps, 1) + ' WS=' + [math]::Round($peak / 1GB, 2) + 'GiB VRAM=' + [math]::Round([double]$report.videoMemoryBytes / 1GB, 2) + 'GiB')
Write-Output ('REPORT ' + $output)
if ($failures.Count -gt 0) {
    Write-Output ('FULL BATTLE BENCH FAIL ' + ($failures -join '; '))
    exit 1
}
Write-Output ('FULL BATTLE BENCH PASS reference=' + $report.cpu + ' / ' + $report.gpu)
exit 0

