param(
    [Parameter(Mandatory=$true)][string]$ReleasePack,
    [string]$OutputDirectory = "",
    [switch]$IncludeSynthetic
)
$ErrorActionPreference = 'Stop'
$pack = [IO.Path]::GetFullPath($ReleasePack)
if (!(Test-Path -LiteralPath $pack -PathType Leaf)) { throw 'Release PCK missing' }
$directory = if ($OutputDirectory) {
    [IO.Path]::GetFullPath($OutputDirectory)
} else {
    Join-Path (Split-Path $PSScriptRoot -Parent) ('_work/bench/capacity-'+[Guid]::NewGuid().ToString('N'))
}
if (Test-Path -LiteralPath (Join-Path $directory 'summary.json')) { throw 'Choose a new evidence directory' }
New-Item -ItemType Directory -Force $directory | Out-Null
$shell = (Get-Process -Id $PID).Path
$bench = Join-Path $PSScriptRoot 'bench_full_battle.ps1'
$runner = Join-Path $directory 'runner'
$pckHash = (Get-FileHash -LiteralPath $pack).Hash.ToLowerInvariant()
$rounds = @()
foreach ($round in 1..5) {
    $output = Join-Path $directory ('capacity-'+$round+'.json')
    if (Test-Path -LiteralPath $output) { throw 'Choose a new evidence directory' }
    & $shell -NoProfile -File $bench -ReleasePack $pack -RunnerDirectory $runner -CapacityStress -Output $output
    $code = $LASTEXITCODE
    $report = if (Test-Path -LiteralPath $output) { Get-Content -Raw -LiteralPath $output | ConvertFrom-Json }
    $rounds += [pscustomobject]@{
        round=$round; exitCode=$code; report=(Split-Path $output -Leaf)
        pass=($code -eq 0 -and $report.qualityPassed -eq $true -and $report.protocolVersion -eq 4 -and
              $report.frameInitialTick -eq 360 -and $report.packSha256 -eq $pckHash -and
              $report.unitsMeasured -eq 460 -and $report.logicP95Ms -le 30 -and $report.commandLatencyP95Ms -le 100)
        startChecksum=$report.frameInitialStateChecksum; tickP95Ms=$report.logicP95Ms
        fps=$report.fps; workingSetBytes=$report.peakWorkingSetBytes; videoMemoryBytes=$report.videoMemoryBytes
    }
}
$times = @($rounds | Where-Object { $null -ne $_.tickP95Ms } | ForEach-Object { [double]$_.tickP95Ms } | Sort-Object)
$starts = @($rounds.startChecksum | Where-Object { $_ } | Sort-Object -Unique)
$variation = if ($times.Count -eq 5 -and $times[2] -gt 0) { ($times[4] - $times[0]) / $times[2] }
$stable = @($rounds | Where-Object { $_.pass }).Count -eq 5 -and $starts.Count -eq 1 -and $null -ne $variation -and $variation -lt 0.15
$synthetic = $null
if ($IncludeSynthetic) {
    $output = Join-Path $directory 'synthetic-660.json'
    & $shell -NoProfile -File $bench -ReleasePack $pack -RunnerDirectory $runner -Stress -Output $output
    $synthetic = @{exitCode=$LASTEXITCODE; report=(Split-Path $output -Leaf)}
}
$summary = [ordered]@{
    pass=$stable; packSha256=$pckHash; tickP95RelativeRange=$variation; rounds=$rounds
    minimumFps=($rounds.fps | Measure-Object -Minimum).Minimum
    peakWorkingSetBytes=($rounds.workingSetBytes | Measure-Object -Maximum).Maximum
    peakVideoMemoryBytes=($rounds.videoMemoryBytes | Measure-Object -Maximum).Maximum
    syntheticDiagnostic=$synthetic
}
$summary | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath (Join-Path $directory 'summary.json') -Encoding UTF8
Write-Output ('CAPACITY EVIDENCE '+$directory)
if (!$stable) { exit 1 }
