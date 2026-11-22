$ErrorActionPreference='Stop'
. (Join-Path $PSScriptRoot 'workspace_lock.ps1')
$root=Split-Path $PSScriptRoot -Parent
$fixture=Join-Path $root ('_work/workspace-lock-tests/'+[Guid]::NewGuid().ToString('N'))
$stage=Join-Path $fixture '_work/build/stage-in-progress'
$tools=Join-Path $fixture 'tools'
$hostShell=(Get-Process -Id $PID).Path
New-Item -ItemType Directory -Force $stage,$tools | Out-Null
foreach ($name in @('workspace_lock.ps1','cleanup_project.ps1','build_game.ps1','build_environment.ps1')) {
    Copy-Item -LiteralPath (Join-Path $PSScriptRoot $name) -Destination $tools
}
$marker=Join-Path $stage 'pending.bin'
[IO.File]::WriteAllText($marker,'build is writing')
$outer=Enter-WorkspaceLock $fixture 'test build'
try {
    $nested=Enter-WorkspaceLock $fixture 'test nested verification'
    Exit-WorkspaceLock $nested
    foreach ($entry in @('cleanup_project.ps1','build_game.ps1')) {
        $ErrorActionPreference='Continue'
        try {
            $output=& $hostShell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $tools $entry) 2>&1
            $exitCode=$LASTEXITCODE
        } finally { $ErrorActionPreference='Stop' }
        if ($exitCode -eq 0 -or (($output -join '') -replace '\s','') -notmatch 'Workspaceisbusy') {
            throw ('An active build did not block '+$entry+': '+($output -join "`n"))
        }
        if (!(Test-Path -LiteralPath $marker)) { throw 'Busy cleanup touched active staging' }
    }
} finally { Exit-WorkspaceLock $outer }

$holder=Join-Path $fixture 'hold.ps1'
$ready=Join-Path $fixture 'ready'
[IO.File]::WriteAllText($holder, @'
param([string]$Fixture)
. (Join-Path $Fixture 'tools/workspace_lock.ps1')
$held=Enter-WorkspaceLock $Fixture 'fixture build'
try {
    [IO.File]::WriteAllText((Join-Path $Fixture 'ready'),'ready')
    Start-Sleep -Seconds 30
} finally { Exit-WorkspaceLock $held }
'@)
$start=[Diagnostics.ProcessStartInfo]::new()
$start.FileName=$hostShell
$start.Arguments='-NoProfile -ExecutionPolicy Bypass -File "'+$holder+'" -Fixture "'+$fixture+'"'
$start.UseShellExecute=$false; $start.CreateNoWindow=$true
$child=[Diagnostics.Process]::Start($start)
try {
    $deadline=(Get-Date).AddSeconds(10)
    while (!(Test-Path -LiteralPath $ready) -and !$child.HasExited -and (Get-Date) -lt $deadline) { Start-Sleep -Milliseconds 100 }
    if (!(Test-Path -LiteralPath $ready)) { throw 'Fixture build did not acquire lock' }
    $child.Kill()
    if (!$child.WaitForExit(10000)) { throw 'Fixture build did not exit' }
    $recovered=Enter-WorkspaceLock $fixture 'cleanup after interrupted build'
    Exit-WorkspaceLock $recovered
} finally { if (!$child.HasExited) { $child.Kill() }; $child.Dispose() }
Write-Output 'WORKSPACE LOCK PASS build / cleanup exclusion / nested verification / crash recovery'
