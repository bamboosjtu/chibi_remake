function Assert-StandardPerformanceEvidence($evidence, [string]$PackHash, [string]$ExecutableHash) {
    if ($evidence.performanceContract -ne 'release-standard-3-runs-v2' -or @($evidence.standardPerformance).Count -ne 3) { throw 'Incomplete standard performance evidence' }
    $starts = @($evidence.standardPerformance.frameInitialStateChecksum | Sort-Object -Unique)
    if ($starts.Count -ne 1 -or $starts[0] -notmatch '^[a-f0-9]{64}$') { throw 'Standard benchmarks must start from the same snapshot' }
    $ids = @{}
    foreach ($run in $evidence.standardPerformance) {
        if ($run.runId -notmatch '^[a-f0-9]{32}$' -or $ids.ContainsKey($run.runId)) { throw 'Missing or duplicate benchmark run ID' }
        $ids[$run.runId] = $true
        if ($run.packSha256 -ne $PackHash -or $run.engineSha256 -ne $ExecutableHash) { throw 'Benchmark tested a different candidate' }
        if ($run.frameInitialStateChecksum -ne $starts[0]) { throw 'Benchmark has no matching start snapshot' }
        if ($run.map -ne 'chibic17' -or $run.workloadMode -ne 'legacy-synthetic' -or $run.frames -ne 180 -or $run.ticks -ne 300) { throw 'Invalid standard benchmark workload' }
        foreach ($metric in @('fps','logicP95Ms','realtimeLogicBudgetMs','ticksPerSecond','targetTicksPerSecond','commandLatencyP95Ms','simAccumulatorBegin','simAccumulatorEnd')) {
            if ($run.PSObject.Properties.Name -notcontains $metric -or $null -eq $run.$metric -or [double]::IsNaN([double]$run.$metric) -or [double]::IsInfinity([double]$run.$metric) -or [double]$run.$metric -lt 0) { throw ('Missing or nonfinite performance metric: '+$metric) }
        }
        if ($run.protocolVersion -ne 4 -or $run.renderWarmupPreservedSimulation -ne $true -or $run.frameInitialTick -ne 360 -or $run.profilingEnabled -ne $false -or $run.pausedAtEnd -ne $false -or $run.gameEnd -ne 0 -or $run.simulationTicksAdvanced -le 0 -or $run.unitsMeasured -lt 200 -or $run.engaged -lt 60 -or $run.viewport.Count -ne 2 -or $run.viewport[0] -ne 1920 -or $run.viewport[1] -ne 1080 -or $run.realtimeLogicBudgetMs -gt 30.000001 -or $run.targetTicksPerSecond -lt 33.3333) { throw 'Invalid standard benchmark workload' }
        if ($run.engineBuild -ne 'release' -or $run.qualityPassed -ne $true -or $run.acceptanceRun -ne $true -or $run.validWorkload -ne $true -or $run.unitsTarget -ne 200 -or $run.engagedTarget -ne 60 -or $run.fps -lt 60 -or $run.logicP95Ms -gt $run.realtimeLogicBudgetMs -or $run.ticksPerSecond -lt 0.95*$run.targetTicksPerSecond -or $run.commandLatencyP95Ms -gt 100) { throw 'Failed standard performance evidence' }
        if ($run.simAccumulatorEnd -gt [Math]::Max(0.2, [double]$run.simAccumulatorBegin + 0.1)) { throw 'Simulation backlog exceeds the standard budget' }
    }
}

# Shared by verification, publication and final release packaging.
function Read-CandidateResults([string]$Directory) {
    # Windows PowerShell 5.1 emits a JSON array as one pipeline object.
    # Assign before concatenating; @(ConvertFrom-Json ...) nests the arrays.
    $maps=ConvertFrom-Json -InputObject ([IO.File]::ReadAllText((Join-Path $Directory 'maps/results.json')))
    $regressions=ConvertFrom-Json -InputObject ([IO.File]::ReadAllText((Join-Path $Directory 'regressions/results.json')))
    $native=ConvertFrom-Json -InputObject ([IO.File]::ReadAllText((Join-Path $Directory 'native/results.json')))
    $isolation=ConvertFrom-Json -InputObject ([IO.File]::ReadAllText((Join-Path $Directory 'native/isolation/results.json')))
    return @($maps)+@($regressions)+@($native)+@($isolation)
}

function Assert-CandidateVerification([string]$Directory, $Build) {
    $evidencePath=Join-Path $Directory 'verification.json'
    if (!(Test-Path -LiteralPath $evidencePath)) { throw 'Candidate has no verification evidence' }
    if ($Build -and ($Build.verification -ne 'candidate-smoke' -or $Build.verificationSha256 -ne (Get-FileHash -LiteralPath $evidencePath).Hash)) { throw 'Candidate verification evidence does not match build manifest' }
    $evidence=Get-Content -Raw -Encoding UTF8 $evidencePath | ConvertFrom-Json
    if ($evidence.schemaVersion -ne 1) { throw 'Unsupported verification evidence' }
    $suitePath=Join-Path $PSScriptRoot 'inputs/release_tests.json'
    $baselinePath=Join-Path $PSScriptRoot 'inputs/baselines.json'
    if ($evidence.suiteSha256 -ne (Get-FileHash -LiteralPath $suitePath).Hash -or $evidence.baselineSha256 -ne (Get-FileHash -LiteralPath $baselinePath).Hash) { throw 'Candidate verification contract is stale; rerun verify_candidate.ps1 and write_build_manifest.ps1' }
    $expected=@(Get-RequiredCandidateChecks $Directory)
    $actual=@($evidence.results | ForEach-Object { $_.name })
    if ($actual.Count -ne $expected.Count -or @(Compare-Object ($expected | Sort-Object) ($actual | Sort-Object)).Count -gt 0) { throw 'Candidate verification coverage is incomplete' }
    foreach ($result in $evidence.results) {
        if ($result.ok -isnot [bool] -or $result.ok -ne $true -or ($result.code -isnot [int] -and $result.code -isnot [long]) -or $result.code -ne 0 -or $result.timedOut -isnot [bool] -or $result.timedOut -ne $false -or @($result.missing).Count -gt 0) { throw ('Candidate verification failed: '+$result.name) }
    }
    $packs = @($evidence.artifacts | Where-Object { $_.path -match '^[^/]+\.pck$' })
    if ($packs.Count -ne 1) { throw 'Candidate must contain one root PCK' }
    $exeName = [IO.Path]::ChangeExtension($packs[0].path, '.exe')
    $executables = @($evidence.artifacts | Where-Object path -eq $exeName)
    if ($executables.Count -ne 1) { throw 'Candidate PCK has no matching executable' }
    Assert-StandardPerformanceEvidence $evidence $packs[0].sha256 $executables[0].sha256
    $files=@(Get-ChildItem -LiteralPath $Directory -File -Recurse | Where-Object { ($_.Extension -in @('.exe','.pck','.dll') -or $_.Name -eq 'portable.txt') -and $_.Name -notlike '_validation-engine*.exe' })
    if ($files.Count -ne @($evidence.artifacts).Count) { throw 'Candidate verification artifact set changed' }
    foreach ($file in $files) {
        $relative=$file.FullName.Substring($Directory.TrimEnd('\','/').Length+1).Replace('\','/')
        $entry=@($evidence.artifacts | Where-Object { $_.path -eq $relative })
        if ($entry.Count -ne 1 -or $entry[0].sha256 -ne (Get-FileHash -LiteralPath $file.FullName).Hash) { throw ('Candidate changed after verification: '+$relative) }
    }
    return $evidence
}

function Get-RequiredCandidateChecks([string]$Directory) {
    $sourceRoot=Split-Path $PSScriptRoot -Parent
    $suitePath=Join-Path $PSScriptRoot "inputs/release_tests.json"
    $baselinePath=Join-Path $PSScriptRoot "inputs/baselines.json"
    $expected=@((Get-Content -Raw -Encoding UTF8 $suitePath | ConvertFrom-Json).tests | ForEach-Object { $_.script })
    $expected+=@(Get-ChildItem -LiteralPath (Join-Path $sourceRoot 'godot/chibi_remake/data') -File -Filter 'chibi*.json' | ForEach-Object { 'load-'+$_.BaseName })
    $expected+=@((Get-Content -Raw -Encoding UTF8 $baselinePath | ConvertFrom-Json).simtest | ForEach-Object { 'sim-'+$_.map+'-'+$_.seconds })
    if (Get-ChildItem -LiteralPath $Directory -Recurse -File -Filter 'ChibiSimulationMath.dll') { $expected+= 'test_native_world' }
    $expected+=@('native-save-green-write','native-save-green-read','native-save-system-write','native-save-system-read')
    $expected+=@('native-isolation-write','native-isolation-selftest','native-isolation-reject-dir','native-isolation-reject-id','native-isolation-player-export','native-isolation-player-reject')
    return $expected
}
