$ErrorActionPreference='Stop'
. (Join-Path $PSScriptRoot 'candidate_lock.ps1')
$root=Split-Path $PSScriptRoot -Parent
$fixture=Join-Path $root ('_work/validation-lock/'+[Guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Force $fixture | Out-Null
[IO.File]::WriteAllText((Join-Path $fixture '.validation.lock'),'stale owner')
$first=Enter-CandidateValidationLock $fixture
try {
    try { $unexpected=Enter-CandidateValidationLock $fixture; $unexpected.Dispose(); throw 'Concurrent validator accepted' }
    catch { if ($_.Exception.Message -notmatch 'validation is active') { throw } }
} finally { $first.Dispose() }
$second=Enter-CandidateValidationLock $fixture
$second.Dispose()
$holder=Join-Path $fixture 'hold.ps1'
$ready=Join-Path $fixture 'ready'
$body='. "'+(Join-Path $PSScriptRoot 'candidate_lock.ps1')+'"; $held=Enter-CandidateValidationLock "'+$fixture+'"; [IO.File]::WriteAllText("'+$ready+'","ready"); Start-Sleep -Seconds 60'
[IO.File]::WriteAllText($holder,$body)
$start=New-Object Diagnostics.ProcessStartInfo
$start.FileName=(Join-Path $env:WINDIR 'System32/WindowsPowerShell/v1.0/powershell.exe')
$start.Arguments='-NoProfile -ExecutionPolicy Bypass -File "'+$holder+'"'
$start.UseShellExecute=$false; $start.CreateNoWindow=$true
$child=[Diagnostics.Process]::Start($start)
try {
    $deadline=(Get-Date).AddSeconds(10)
    while (!(Test-Path -LiteralPath $ready) -and !$child.HasExited -and (Get-Date) -lt $deadline) { Start-Sleep -Milliseconds 100 }
    if (!(Test-Path -LiteralPath $ready)) { throw 'Lock holder did not start' }
    $child.Kill(); $null=$child.WaitForExit(10000)
    $recovered=Enter-CandidateValidationLock $fixture
    $recovered.Dispose()
} finally { if (!$child.HasExited) { $child.Kill() }; $child.Dispose() }
Write-Output 'CANDIDATE LOCK PASS stale file recovery / active handle rejection / forced termination recovery'
