$ErrorActionPreference='Stop'
. (Join-Path $PSScriptRoot 'candidate_verification.ps1')
function New-Evidence {
    $runs=@(1..3 | ForEach-Object { [pscustomobject]@{engineBuild='release';qualityPassed=$true;acceptanceRun=$true;validWorkload=$true;unitsTarget=200;engagedTarget=60;fps=70;logicP95Ms=24;realtimeLogicBudgetMs=30;ticksPerSecond=33.3;targetTicksPerSecond=33.333;commandLatencyP95Ms=40} })
    foreach ($run in $runs) {
        foreach ($entry in @{protocolVersion=4;renderWarmupPreservedSimulation=$true;frameInitialTick=360;profilingEnabled=$false;pausedAtEnd=$false;gameEnd=0;simulationTicksAdvanced=80;unitsMeasured=200;engaged=60;viewport=@(1920,1080)}.GetEnumerator()) { $run | Add-Member -NotePropertyName $entry.Key -NotePropertyValue $entry.Value }
        $run.targetTicksPerSecond=33.3333333333333
    }
    return [pscustomobject]@{performanceContract='release-standard-3-runs-v1';standardPerformance=$runs}
}
$good=New-Evidence
Assert-StandardPerformanceEvidence $good
foreach ($failure in @('fps','paused','debug','missingRound','tick','latency','missingMetric','nonfinite','slowClock','viewport','profile')) {
    $case=New-Evidence
    switch ($failure) {
        'fps' {$case.standardPerformance[1].fps=59}
        'paused' {$case.standardPerformance[1].validWorkload=$false}
        'debug' {$case.standardPerformance[1].engineBuild='debug'}
        'missingRound' {$case.standardPerformance=@($case.standardPerformance[0])}
        'tick' {$case.standardPerformance[1].ticksPerSecond=30}
        'latency' {$case.standardPerformance[1].commandLatencyP95Ms=101}
        'missingMetric' {$case.standardPerformance[1].PSObject.Properties.Remove('logicP95Ms')}
        'nonfinite' {$case.standardPerformance[1].logicP95Ms=[double]::NaN}
        'slowClock' {$case.standardPerformance[1].targetTicksPerSecond=10}
        'viewport' {$case.standardPerformance[1].viewport=@(640,360)}
        'profile' {$case.standardPerformance[1].profilingEnabled=$true}
    }
    $rejected=$false
    try { Assert-StandardPerformanceEvidence $case } catch { $rejected=$true }
    if (!$rejected) { throw ('Accepted invalid performance evidence: '+$failure) }
}
Write-Output 'BENCHMARK EVIDENCE PASS three release rounds / FPS / active workload / throughput / latency rejection'
