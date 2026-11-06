# Shared by verification, publication and final release packaging.
function Read-CandidateResults([string]$Directory) {
    # Windows PowerShell 5.1 emits a JSON array as one pipeline object.
    # Assign before concatenating; @(ConvertFrom-Json ...) nests the arrays.
    $maps=ConvertFrom-Json -InputObject ([IO.File]::ReadAllText((Join-Path $Directory 'maps/results.json')))
    $regressions=ConvertFrom-Json -InputObject ([IO.File]::ReadAllText((Join-Path $Directory 'regressions/results.json')))
    $native=ConvertFrom-Json -InputObject ([IO.File]::ReadAllText((Join-Path $Directory 'native/results.json')))
    return @($maps)+@($regressions)+@($native)
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
    $actual=@($evidence.results | ForEach-Object { $_.name })
    if ($actual.Count -ne $expected.Count -or @(Compare-Object ($expected | Sort-Object) ($actual | Sort-Object)).Count -gt 0) { throw 'Candidate verification coverage is incomplete' }
    foreach ($result in $evidence.results) {
        if ($result.ok -isnot [bool] -or $result.ok -ne $true -or ($result.code -isnot [int] -and $result.code -isnot [long]) -or $result.code -ne 0 -or $result.timedOut -isnot [bool] -or $result.timedOut -ne $false -or @($result.missing).Count -gt 0) { throw ('Candidate verification failed: '+$result.name) }
    }
    $files=@(Get-ChildItem -LiteralPath $Directory -File -Recurse | Where-Object { ($_.Extension -in @('.exe','.pck','.dll') -or $_.Name -eq 'portable.txt') -and $_.Name -ne '_validation-engine.exe' })
    if ($files.Count -ne @($evidence.artifacts).Count) { throw 'Candidate verification artifact set changed' }
    foreach ($file in $files) {
        $relative=$file.FullName.Substring($Directory.TrimEnd('\','/').Length+1).Replace('\','/')
        $entry=@($evidence.artifacts | Where-Object { $_.path -eq $relative })
        if ($entry.Count -ne 1 -or $entry[0].sha256 -ne (Get-FileHash -LiteralPath $file.FullName).Hash) { throw ('Candidate changed after verification: '+$relative) }
    }
    return $evidence
}
