function Assert-StandardPerformanceEvidence($evidence) {
    if ($evidence.performanceContract -ne 'release-standard-3-runs-v1' -or @($evidence.standardPerformance).Count -ne 3) { throw 'Incomplete standard performance evidence' }
    foreach ($run in $evidence.standardPerformance) {
        foreach ($metric in @('fps','logicP95Ms','realtimeLogicBudgetMs','ticksPerSecond','targetTicksPerSecond','commandLatencyP95Ms')) {
            if ($run.PSObject.Properties.Name -notcontains $metric -or $null -eq $run.$metric -or [double]::IsNaN([double]$run.$metric) -or [double]::IsInfinity([double]$run.$metric)) { throw ('Missing or nonfinite performance metric: '+$metric) }
        }
        if ($run.protocolVersion -ne 4 -or $run.renderWarmupPreservedSimulation -ne $true -or $run.frameInitialTick -ne 360 -or $run.profilingEnabled -ne $false -or $run.pausedAtEnd -ne $false -or $run.gameEnd -ne 0 -or $run.simulationTicksAdvanced -le 0 -or $run.unitsMeasured -lt 200 -or $run.engaged -lt 60 -or $run.viewport.Count -ne 2 -or $run.viewport[0] -ne 1920 -or $run.viewport[1] -ne 1080 -or $run.realtimeLogicBudgetMs -gt 30.000001 -or $run.targetTicksPerSecond -lt 33.3333) { throw 'Invalid standard benchmark workload' }
        if ($run.engineBuild -ne 'release' -or $run.qualityPassed -ne $true -or $run.acceptanceRun -ne $true -or $run.validWorkload -ne $true -or $run.unitsTarget -ne 200 -or $run.engagedTarget -ne 60 -or $run.fps -lt 60 -or $run.logicP95Ms -gt $run.realtimeLogicBudgetMs -or $run.ticksPerSecond -lt 0.95*$run.targetTicksPerSecond -or $run.commandLatencyP95Ms -gt 100) { throw 'Failed standard performance evidence' }
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
    $sourceRoot=Split-Path $PSScriptRoot -Parent
    $suitePath=Join-Path $PSScriptRoot 'inputs/release_tests.json'
    $baselinePath=Join-Path $PSScriptRoot 'inputs/baselines.json'
    if ($evidence.suiteSha256 -ne (Get-FileHash -LiteralPath $suitePath).Hash -or $evidence.baselineSha256 -ne (Get-FileHash -LiteralPath $baselinePath).Hash) { throw 'Candidate verification contract is stale; rerun verify_candidate.ps1 and write_build_manifest.ps1' }
    $expected=@((Get-Content -Raw -Encoding UTF8 $suitePath | ConvertFrom-Json).tests | ForEach-Object { $_.script })
    $expected+=@(Get-ChildItem -LiteralPath (Join-Path $sourceRoot 'godot/chibi_remake/data') -File -Filter 'chibi*.json' | ForEach-Object { 'load-'+$_.BaseName })
    $expected+=@((Get-Content -Raw -Encoding UTF8 $baselinePath | ConvertFrom-Json).simtest | ForEach-Object { 'sim-'+$_.map+'-'+$_.seconds })
    $expected+=@('native-save-green-write','native-save-green-read','native-save-system-write','native-save-system-read')
    $expected+=@('native-isolation-write','native-isolation-selftest','native-isolation-reject-dir','native-isolation-reject-id')
    $actual=@($evidence.results | ForEach-Object { $_.name })
    if ($actual.Count -ne $expected.Count -or @(Compare-Object ($expected | Sort-Object) ($actual | Sort-Object)).Count -gt 0) { throw 'Candidate verification coverage is incomplete' }
    foreach ($result in $evidence.results) {
        if ($result.ok -isnot [bool] -or $result.ok -ne $true -or ($result.code -isnot [int] -and $result.code -isnot [long]) -or $result.code -ne 0 -or $result.timedOut -isnot [bool] -or $result.timedOut -ne $false -or @($result.missing).Count -gt 0) { throw ('Candidate verification failed: '+$result.name) }
    }
    if ($evidence.PSObject.Properties.Name -contains 'performanceContract') { Assert-StandardPerformanceEvidence $evidence }
    $files=@(Get-ChildItem -LiteralPath $Directory -File -Recurse | Where-Object { ($_.Extension -in @('.exe','.pck','.dll') -or $_.Name -eq 'portable.txt') -and $_.Name -notlike '_validation-engine*.exe' })
    if ($files.Count -ne @($evidence.artifacts).Count) { throw 'Candidate verification artifact set changed' }
    foreach ($file in $files) {
        $relative=$file.FullName.Substring($Directory.TrimEnd('\','/').Length+1).Replace('\','/')
        $entry=@($evidence.artifacts | Where-Object { $_.path -eq $relative })
        if ($entry.Count -ne 1 -or $entry[0].sha256 -ne (Get-FileHash -LiteralPath $file.FullName).Hash) { throw ('Candidate changed after verification: '+$relative) }
    }
    return $evidence
}
