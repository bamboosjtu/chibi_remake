param([Parameter(Mandatory=$true)][string]$Executable,[string]$StageDirectory)
# Required build gate: execute the release binary on all maps, then debug-check
# the same PCK with assertions and deterministic baselines.
$ErrorActionPreference='Stop'
$projectRoot=Split-Path $PSScriptRoot -Parent
$Executable=[IO.Path]::GetFullPath($Executable)
$candidate=Split-Path $Executable -Parent
$pack=[IO.Path]::ChangeExtension($Executable,'.pck')
if (!(Test-Path -LiteralPath $Executable) -or !(Test-Path -LiteralPath $pack)) { throw 'Invalid candidate EXE/PCK' }
if ($StageDirectory -and !(Test-Path -LiteralPath (Join-Path $StageDirectory 'release_inputs.json'))) { throw 'Explicit stage has no release input manifest' }
$engine=Join-Path $candidate ('_validation-engine-'+[Guid]::NewGuid().ToString('N')+'.exe')
$output=Join-Path $projectRoot ('_work/candidate-smoke/'+[Guid]::NewGuid().ToString('N'))
. (Join-Path $PSScriptRoot 'candidate_lock.ps1')
$validationLock=Enter-CandidateValidationLock $candidate
try {
$evidencePath=Join-Path $candidate 'verification.json'
if (Test-Path -LiteralPath $evidencePath) {
    Copy-Item -LiteralPath $evidencePath -Destination ($evidencePath+'.previous') -Force
    Remove-Item -LiteralPath $evidencePath -Force
}
$artifacts=@(Get-ChildItem -LiteralPath $candidate -File -Recurse | Where-Object { ($_.Extension -in @('.exe','.pck','.dll') -or $_.Name -eq 'portable.txt') -and $_.Name -notlike '_validation-engine*.exe' } | ForEach-Object {
    @{path=$_.FullName.Substring($candidate.Length+1).Replace('\','/');sha256=(Get-FileHash -LiteralPath $_.FullName).Hash}
})
try {
    & node (Join-Path $PSScriptRoot 'run_regressions.mjs') --engine $Executable --native --maps --output (Join-Path $output 'maps')
    if ($LASTEXITCODE -ne 0) { throw "Candidate map loading failed: $output" }
    Copy-Item -LiteralPath (Join-Path $projectRoot 'Godot_v4.7.2-stable_win64.exe') -Destination $engine
    # Assertions enabled; native DLLs resolve beside this owned temporary engine.
    & node (Join-Path $PSScriptRoot 'run_regressions.mjs') --engine $engine --pack $pack --suite (Join-Path $PSScriptRoot 'inputs/release_tests.json') --baselines --output (Join-Path $output 'regressions')
    if ($LASTEXITCODE -ne 0) { throw "Candidate smoke failed: $output" }
    & node (Join-Path $PSScriptRoot 'verify_native_save.mjs') --exe $Executable --output (Join-Path $output 'native')
    if ($LASTEXITCODE -ne 0) { throw "Native EXE save/restart acceptance failed: $output" }
    . (Join-Path $PSScriptRoot 'candidate_verification.ps1')
    $results=@(Read-CandidateResults $output)
    $evidence=[ordered]@{
        schemaVersion=1; verifiedAt=(Get-Date).ToUniversalTime().ToString('o')
        suiteSha256=(Get-FileHash -LiteralPath (Join-Path $PSScriptRoot 'inputs/release_tests.json')).Hash
        baselineSha256=(Get-FileHash -LiteralPath (Join-Path $PSScriptRoot 'inputs/baselines.json')).Hash
        artifacts=$artifacts
        results=@($results | Select-Object name,ok,code,timedOut,missing)
    }
    [IO.File]::WriteAllText($evidencePath,($evidence | ConvertTo-Json -Depth 8),(New-Object System.Text.UTF8Encoding $false))
    $null=Assert-CandidateVerification $candidate $null
    Write-Output "CANDIDATE SMOKE PASS maps / release suite / baselines: $output"
} finally {
    if (Test-Path -LiteralPath $engine) { Remove-Item -LiteralPath $engine -Force }
}
} finally { $validationLock.Dispose() }
