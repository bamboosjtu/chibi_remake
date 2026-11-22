$ErrorActionPreference='Stop'
. (Join-Path $PSScriptRoot 'candidate_verification.ps1')
. (Join-Path $PSScriptRoot 'performance_fixture.ps1')
$packHash='b'*64
$exeHash='c'*64
$good=New-StandardPerformanceFixture $packHash $exeHash
Assert-StandardPerformanceEvidence $good $packHash $exeHash
foreach ($failure in @('missingContract','duplicate','differentPack','differentExe','differentStart','fps','paused','debug','missingRound','tick','latency','missingMetric','nonfinite','slowClock','viewport','profile')) {
    $case=New-StandardPerformanceFixture $packHash $exeHash
    switch ($failure) {
        'missingContract' {$case.PSObject.Properties.Remove('performanceContract'); $case.PSObject.Properties.Remove('standardPerformance')}
        'duplicate' {$case.standardPerformance[1]=$case.standardPerformance[0]}
        'differentPack' {$case.standardPerformance[1].packSha256='d'*64}
        'differentExe' {$case.standardPerformance[1].engineSha256='d'*64}
        'differentStart' {$case.standardPerformance[1].frameInitialStateChecksum='d'*64}
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
    try { Assert-StandardPerformanceEvidence $case $packHash $exeHash } catch { $rejected=$true }
    if (!$rejected) { throw ('Accepted invalid performance evidence: '+$failure) }
}
Write-Output 'BENCHMARK EVIDENCE PASS three release rounds / FPS / active workload / throughput / latency rejection'

$root = Split-Path $PSScriptRoot -Parent
$fixture = Join-Path $root ('_work/capacity-evidence-tests/'+[Guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $fixture | Out-Null
$pack = Join-Path $fixture 'fixture.pck'
Set-Content -LiteralPath $pack -Value 'fixture'
$packHash = (Get-FileHash -LiteralPath $pack).Hash.ToLowerInvariant()
$shell = (Get-Process -Id $PID).Path
foreach ($case in @('logic-pass','unstable','different-start','throughput','fps')) {
    $rounds = Join-Path $fixture $case
    New-Item -ItemType Directory -Path $rounds | Out-Null
    foreach ($round in 1..5) {
        $report = @{
            engineBuild='release'; acceptanceRun=$true; validWorkload=$true; protocolVersion=4
            workloadMode='scenario-capacity'; renderWarmupPreservedSimulation=$true; frameInitialTick=360
            frameInitialStateChecksum='same'; packSha256=$packHash; unitsMeasured=460; pausedAtEnd=$false
            gameEnd=0; logicP95Ms=25; commandLatencyP95Ms=5; ticksPerSecond=33
            targetTicksPerSecond=33.3333333333333; simAccumulatorBegin=0; simAccumulatorEnd=0.03
            fps=35; peakWorkingSetBytes=1000000; videoMemoryBytes=1000000; qualityPassed=$false
        }
        if ($round -eq 5) {
            switch ($case) {
                'fps' { $report.fps=29 }
                'unstable' { $report.logicP95Ms=29 }
                'different-start' { $report.frameInitialStateChecksum='different' }
                'throughput' { $report.ticksPerSecond=30 }
            }
        }
        $report | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $rounds "capacity-$round.json")
    }
    & $shell -NoProfile -File (Join-Path $PSScriptRoot 'bench_capacity_stability.ps1') -ReleasePack $pack -OutputDirectory $rounds -SummarizeOnly
    $expected = if ($case -eq 'logic-pass') { 0 } else { 1 }
    if ($LASTEXITCODE -ne $expected) { throw ('Unexpected capacity evidence verdict: '+$case) }
}
Write-Output 'CAPACITY EVIDENCE PASS five identical starts / tick variability / 30 FPS floor'
