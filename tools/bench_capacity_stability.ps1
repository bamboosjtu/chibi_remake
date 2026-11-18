param(
    [Parameter(Mandatory=$true)][string]$ReleasePack,
    [string]$OutputDirectory = "",
    [switch]$IncludeSynthetic,
    [switch]$SummarizeOnly
)
$ErrorActionPreference = 'Stop'
$pack = [IO.Path]::GetFullPath($ReleasePack)
if (!(Test-Path -LiteralPath $pack -PathType Leaf)) { throw 'Release PCK missing' }
$directory = if ($OutputDirectory) {
    [IO.Path]::GetFullPath($OutputDirectory)
} else {
    Join-Path (Split-Path $PSScriptRoot -Parent) ('_work/bench/capacity-'+[Guid]::NewGuid().ToString('N'))
}
if ($SummarizeOnly -and !$OutputDirectory) { throw 'Specify an existing output directory to summarize' }
$summaryName = if ($SummarizeOnly) { 'logic-summary.json' } else { 'summary.json' }
$summaryPath = Join-Path $directory $summaryName
if (Test-Path -LiteralPath $summaryPath) { throw 'Evidence summary already exists' }
if (!$SummarizeOnly) { New-Item -ItemType Directory -Force $directory | Out-Null }
$shell = (Get-Process -Id $PID).Path
$bench = Join-Path $PSScriptRoot 'bench_full_battle.ps1'
$runner = Join-Path $directory 'runner'
$pckHash = (Get-FileHash -LiteralPath $pack).Hash.ToLowerInvariant()

function Test-CapacityRound($report) {
    if ($null -eq $report -or $report.engineBuild -ne 'release' -or $report.acceptanceRun -ne $true -or
        $report.protocolVersion -ne 4 -or $report.workloadMode -ne 'scenario-capacity' -or
        $report.validWorkload -ne $true -or $report.renderWarmupPreservedSimulation -ne $true -or
        $report.frameInitialTick -ne 360 -or !$report.frameInitialStateChecksum -or
        $report.packSha256 -ne $pckHash -or $report.unitsMeasured -ne 460 -or
        $report.pausedAtEnd -ne $false -or $report.gameEnd -ne 0) { return $false }
    foreach ($name in @('logicP95Ms','commandLatencyP95Ms','ticksPerSecond','targetTicksPerSecond','simAccumulatorBegin','simAccumulatorEnd')) {
        if ($null -eq $report.$name -or [double]::IsNaN([double]$report.$name) -or
            [double]::IsInfinity([double]$report.$name) -or [double]$report.$name -lt 0) { return $false }
    }
    return ($report.logicP95Ms -le 30 -and $report.commandLatencyP95Ms -le 100 -and
            $report.targetTicksPerSecond -ge 33.3333 -and
            $report.ticksPerSecond -ge 0.95*$report.targetTicksPerSecond -and
            $report.simAccumulatorEnd -le [Math]::Max(0.2, [double]$report.simAccumulatorBegin+0.1))
}

$rounds = @()
foreach ($round in 1..5) {
    $output = Join-Path $directory ('capacity-'+$round+'.json')
    $code = $null
    if (!$SummarizeOnly) {
        if (Test-Path -LiteralPath $output) { throw 'Choose a new evidence directory' }
        & $shell -NoProfile -File $bench -ReleasePack $pack -RunnerDirectory $runner -CapacityStress -Output $output
        $code = $LASTEXITCODE
    }
    $report = if (Test-Path -LiteralPath $output) { Get-Content -Raw -LiteralPath $output | ConvertFrom-Json }
    $rounds += [pscustomobject]@{
        round=$round; exitCode=$code; report=(Split-Path $output -Leaf)
        pass=(Test-CapacityRound $report); fullBattlePass=$report.qualityPassed
        startChecksum=$report.frameInitialStateChecksum; tickP95Ms=$report.logicP95Ms
        fps=$report.fps; workingSetBytes=$report.peakWorkingSetBytes; videoMemoryBytes=$report.videoMemoryBytes
    }
}
$times = @($rounds | Where-Object { $null -ne $_.tickP95Ms } | ForEach-Object { [double]$_.tickP95Ms } | Sort-Object)
$starts = @($rounds.startChecksum | Where-Object { $_ } | Sort-Object -Unique)
$variation = if ($times.Count -eq 5 -and $times[2] -gt 0) { ($times[4] - $times[0]) / $times[2] }
$stable = @($rounds | Where-Object { $_.pass }).Count -eq 5 -and $starts.Count -eq 1 -and $null -ne $variation -and $variation -lt 0.15
$synthetic = $null
if ($IncludeSynthetic -and !$SummarizeOnly) {
    $output = Join-Path $directory 'synthetic-660.json'
    & $shell -NoProfile -File $bench -ReleasePack $pack -RunnerDirectory $runner -Stress -Output $output
    $synthetic = @{exitCode=$LASTEXITCODE; report=(Split-Path $output -Leaf)}
} elseif ($SummarizeOnly -and (Test-Path -LiteralPath (Join-Path $directory 'synthetic-660.json'))) {
    $synthetic = @{report='synthetic-660.json'}
}
$summary = [ordered]@{
    pass=$stable; packSha256=$pckHash; tickP95RelativeRange=$variation; rounds=$rounds
    minimumFps=($rounds.fps | Measure-Object -Minimum).Minimum
    peakWorkingSetBytes=($rounds.workingSetBytes | Measure-Object -Maximum).Maximum
    peakVideoMemoryBytes=($rounds.videoMemoryBytes | Measure-Object -Maximum).Maximum
    syntheticDiagnostic=$synthetic
}
$summary | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $summaryPath -Encoding UTF8
Write-Output ('CAPACITY EVIDENCE '+$directory)
if (!$stable) { exit 1 }
