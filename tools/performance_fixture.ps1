function New-StandardPerformanceFixture([string]$PackHash, [string]$ExecutableHash) {
    $runs=@(1..3 | ForEach-Object { [pscustomobject]@{engineBuild='release';qualityPassed=$true;acceptanceRun=$true;validWorkload=$true;unitsTarget=200;engagedTarget=60;fps=70;logicP95Ms=24;realtimeLogicBudgetMs=30;ticksPerSecond=33.3;targetTicksPerSecond=33.333;commandLatencyP95Ms=40} })
    foreach ($run in $runs) {
        $fields=@{runId=[Guid]::NewGuid().ToString('N'); packSha256=$PackHash; engineSha256=$ExecutableHash; frameInitialStateChecksum=('a'*64); map='chibic17'; workloadMode='legacy-synthetic'; frames=180; ticks=300; simAccumulatorBegin=0; simAccumulatorEnd=0}
        foreach ($entry in $fields.GetEnumerator()) { $run | Add-Member -NotePropertyName $entry.Key -NotePropertyValue $entry.Value }
        foreach ($entry in @{protocolVersion=4;renderWarmupPreservedSimulation=$true;frameInitialTick=360;profilingEnabled=$false;pausedAtEnd=$false;gameEnd=0;simulationTicksAdvanced=80;unitsMeasured=200;engaged=60;viewport=@(1920,1080)}.GetEnumerator()) { $run | Add-Member -NotePropertyName $entry.Key -NotePropertyValue $entry.Value }
        $run.targetTicksPerSecond=33.3333333333333
    }
    return [pscustomobject]@{performanceContract='release-standard-3-runs-v2';standardPerformance=$runs}
}
