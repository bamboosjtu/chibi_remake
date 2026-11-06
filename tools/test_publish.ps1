# 不能用 Stop：Godot 的证书警告会经原生 stderr 变成终止性错误，
# 整个构建当场中断（本项目已因此踩坑三次）。错误处理靠 try/catch + $LASTEXITCODE。
$ErrorActionPreference='Continue'
$root=Split-Path $PSScriptRoot -Parent
$fixture=Join-Path $root ('_work/architecture-tests/publish-'+[Guid]::NewGuid().ToString('N'))
$candidate=Join-Path $fixture 'candidate'; $release=Join-Path $fixture 'release'
New-Item -ItemType Directory -Force $candidate,$release | Out-Null
$code='public static class Stub { public static int Main(string[] args) { return args.Length == 2 && args[0] == "space argument" && args[1] == "trailing\\" ? 7 : 3; } }'
$stub=Join-Path $fixture 'stub.cs'; [IO.File]::WriteAllText($stub,$code)
$compiler=Join-Path $env:WINDIR 'Microsoft.NET/Framework64/v4.0.30319/csc.exe'
$exe=Join-Path $candidate 'ChibiRTS.exe'
& $compiler /nologo /target:winexe "/out:$exe" $stub
if ($LASTEXITCODE -ne 0) { throw 'Stub compile failed' }
[IO.File]::WriteAllText((Join-Path $candidate 'ChibiRTS.pck'),'fixture-pack')
try { & (Join-Path $PSScriptRoot 'publish_release.ps1') -Executable $exe -ReleaseRoot $release; throw 'Missing build manifest accepted' }
catch { if ($_.Exception.Message -notmatch 'no build manifest') { throw } }
$nativeDirectory=Join-Path $candidate 'addons/test'
New-Item -ItemType Directory -Force $nativeDirectory | Out-Null
$nativeFile=Join-Path $nativeDirectory 'decoder.dll'
[IO.File]::WriteAllText($nativeFile,'native-fixture')
$head=(& git -C $root rev-parse HEAD 2>$null)
& (Join-Path $PSScriptRoot 'write_build_manifest.ps1') -Executable $exe
$build=Get-Content -Raw (Join-Path $candidate 'build-manifest.json') | ConvertFrom-Json
if ($build.commit -ne $head) { throw 'Default manifest generation must preserve the actual Git commit' }
if ($build.PSObject.Properties.Name -contains 'validated') { throw 'Build metadata must not claim acceptance' }
[IO.File]::WriteAllText((Join-Path $release 'current.json'),'{"directory":"versions/old"}')
$before=(Get-FileHash -LiteralPath (Join-Path $release 'current.json')).Hash
try { & (Join-Path $PSScriptRoot 'publish_release.ps1') -Executable $exe -ReleaseRoot $release; throw 'Unverified candidate accepted' }
catch { if ($_.Exception.Message -notmatch 'without candidate verification') { throw } }
# This is a filesystem/metadata fixture, not a gameplay acceptance run.
# Synthetic passing results let us exercise publisher rejection and atomicity.
$suitePath=Join-Path $PSScriptRoot 'inputs/release_tests.json'
$baselinePath=Join-Path $PSScriptRoot 'inputs/baselines.json'
$names=@((Get-Content -Raw -Encoding UTF8 $suitePath | ConvertFrom-Json).tests | ForEach-Object { $_.script })
$names+=@(Get-ChildItem -LiteralPath (Join-Path $root 'godot/chibi_remake/data') -Filter 'chibi*.json' -File | ForEach-Object { 'load-'+$_.BaseName })
$names+=@((Get-Content -Raw -Encoding UTF8 $baselinePath | ConvertFrom-Json).simtest | ForEach-Object { 'sim-'+$_.map+'-'+$_.seconds })
$names+=@('native-save-green-write','native-save-green-read','native-save-system-write','native-save-system-read')
$evidence=@{
    schemaVersion=1
    suiteSha256=(Get-FileHash -LiteralPath $suitePath).Hash
    baselineSha256=(Get-FileHash -LiteralPath $baselinePath).Hash
    artifacts=@(Get-ChildItem -LiteralPath $candidate -File -Recurse | Where-Object { $_.Extension -in @('.exe','.pck','.dll') } | ForEach-Object { @{path=$_.FullName.Substring($candidate.Length+1).Replace('\','/');sha256=(Get-FileHash -LiteralPath $_.FullName).Hash} })
    results=@($names | ForEach-Object { @{name=$_;ok=$true;code=0;timedOut=$false;missing=@()} })
}
# Abandoned validation engines are temporary tooling, never release artifacts.
[IO.File]::WriteAllText((Join-Path $candidate '_validation-engine-abandoned.exe'),'abandoned')
$evidencePath=Join-Path $candidate 'verification.json'
. (Join-Path $PSScriptRoot 'candidate_verification.ps1')
$resultFixture=Join-Path $fixture 'results'
New-Item -ItemType Directory -Force (Join-Path $resultFixture 'maps'),(Join-Path $resultFixture 'regressions'),(Join-Path $resultFixture 'native') | Out-Null
[IO.File]::WriteAllText((Join-Path $resultFixture 'maps/results.json'),(ConvertTo-Json -InputObject @($evidence.results | Where-Object { $_.name -like 'load-*' }) -Depth 6))
[IO.File]::WriteAllText((Join-Path $resultFixture 'regressions/results.json'),(ConvertTo-Json -InputObject @($evidence.results | Where-Object { $_.name -notlike 'load-*' -and $_.name -notlike 'native-*' }) -Depth 6))
[IO.File]::WriteAllText((Join-Path $resultFixture 'native/results.json'),(ConvertTo-Json -InputObject @($evidence.results | Where-Object { $_.name -like 'native-*' }) -Depth 6))
$evidence.results=@(Read-CandidateResults $resultFixture)
if ($evidence.results.Count -ne $names.Count -or !$evidence.results[0].name) { throw 'JSON result arrays must flatten under PowerShell 5.1 and 7' }
function Write-FixtureEvidence { [IO.File]::WriteAllText($evidencePath,($evidence | ConvertTo-Json -Depth 8),(New-Object System.Text.UTF8Encoding $false)) }
$evidence.results[0].ok=$false
Write-FixtureEvidence
try { & (Join-Path $PSScriptRoot 'write_build_manifest.ps1') -Executable $exe -SourceCommit $head -Verification candidate-smoke; throw 'Failed verification accepted' }
catch { if ($_.Exception.Message -notmatch 'verification failed') { throw } }
$evidence.results[0].ok=$true
$complete=$evidence.results
$evidence.results=@($complete | Select-Object -Skip 1)
Write-FixtureEvidence
try { & (Join-Path $PSScriptRoot 'write_build_manifest.ps1') -Executable $exe -SourceCommit $head -Verification candidate-smoke; throw 'Incomplete verification accepted' }
catch { if ($_.Exception.Message -notmatch 'coverage is incomplete') { throw } }
$evidence.results=$complete
Write-FixtureEvidence
& (Join-Path $PSScriptRoot 'write_build_manifest.ps1') -Executable $exe -SourceCommit $head -SourceDirty:$false -Verification candidate-smoke
Move-Item -LiteralPath $evidencePath -Destination ($evidencePath+'.missing')
try {
    try { & (Join-Path $PSScriptRoot 'publish_release.ps1') -Executable $exe -ReleaseRoot $release; throw 'Missing evidence accepted' }
    catch { if ($_.Exception.Message -notmatch 'no verification evidence') { throw } }
} finally { Move-Item -LiteralPath ($evidencePath+'.missing') -Destination $evidencePath }
if ((Get-FileHash -LiteralPath (Join-Path $release 'current.json')).Hash -ne $before) { throw 'Verification rejection changed current pointer' }
Write-Output 'VERIFICATION GATE PASS unverified / missing / failed / incomplete evidence rejected'
try { & (Join-Path $PSScriptRoot 'publish_release.ps1') -Executable $exe -ReleaseRoot $release -FailBeforeCommit; throw 'Failure was not injected' }
catch { if ($_.Exception.Message -notmatch 'Injected failure') { throw } }
if ((Get-FileHash -LiteralPath (Join-Path $release 'current.json')).Hash -ne $before) { throw 'Failed publish changed current pointer' }
& (Join-Path $PSScriptRoot 'publish_release.ps1') -Executable $exe -ReleaseRoot $release
$pointer=Get-Content -Raw (Join-Path $release 'current.json') | ConvertFrom-Json
$publishedInfo=Get-Content -Raw (Join-Path (Join-Path $release $pointer.directory) 'release-info.json') | ConvertFrom-Json
if ($publishedInfo.verification -ne 'candidate-smoke' -or $publishedInfo.verifiedMaps.Count -ne 34 -or $publishedInfo.verifiedBaselines.Count -ne 2) { throw 'Publish must preserve machine verification coverage' }
$copied=Join-Path (Join-Path $release $pointer.directory) 'addons/test/decoder.dll'
if (!(Test-Path -LiteralPath $copied) -or (Get-FileHash -LiteralPath $copied).Hash -ne (Get-FileHash -LiteralPath $nativeFile).Hash) { throw 'Native dependency was not published intact' }
$versionRoot=Join-Path $release $pointer.directory
if (Test-Path -LiteralPath (Join-Path $versionRoot 'docs')) { throw 'Release must not ship docs' }
if (Test-Path -LiteralPath (Join-Path $versionRoot 'evidence')) { throw 'Release must not ship an evidence folder' }
if (@(Get-ChildItem -LiteralPath $versionRoot -Recurse -File -Filter '*.log').Count -ne 0) { throw 'Release must not ship logs' }
if (!(Test-Path -LiteralPath (Join-Path $versionRoot 'build-manifest.json'))) { throw 'Release must ship build metadata' }
if ($publishedInfo.PSObject.Properties.Name -contains 'tests') { throw 'Release metadata must not list test logs' }
Write-Output 'CLEAN PUBLISH PASS runtime / declarations / manifest only, no docs or logs'
$manifestPath=Join-Path $candidate 'build-manifest.json'
$manifestText=Get-Content -Raw -Encoding UTF8 $manifestPath
$manifest=($manifestText | ConvertFrom-Json)
$manifest.dirty=$true
[IO.File]::WriteAllText($manifestPath,($manifest | ConvertTo-Json -Depth 6),(New-Object System.Text.UTF8Encoding $false))
$dirtyBefore=(Get-FileHash -LiteralPath (Join-Path $release 'current.json')).Hash
try { & (Join-Path $PSScriptRoot 'publish_release.ps1') -Executable $exe -ReleaseRoot $release; throw 'Dirty build was published' }
catch { if ($_.Exception.Message -notmatch 'dirty build') { throw } }
if ((Get-FileHash -LiteralPath (Join-Path $release 'current.json')).Hash -ne $dirtyBefore) { throw 'Dirty rejection changed pointer' }
$manifest.dirty=$false
$manifest.commit='unknown'
[IO.File]::WriteAllText($manifestPath,($manifest | ConvertTo-Json -Depth 6),(New-Object System.Text.UTF8Encoding $false))
try { & (Join-Path $PSScriptRoot 'publish_release.ps1') -Executable $exe -ReleaseRoot $release; throw 'Unknown commit was published' }
catch { if ($_.Exception.Message -notmatch 'commit is unavailable') { throw } }
$manifest.commit=('0'*40)
[IO.File]::WriteAllText($manifestPath,($manifest | ConvertTo-Json -Depth 6),(New-Object System.Text.UTF8Encoding $false))
try { & (Join-Path $PSScriptRoot 'publish_release.ps1') -Executable $exe -ReleaseRoot $release; throw 'Stale commit was published' }
catch { if ($_.Exception.Message -notmatch 'does not match HEAD') { throw } }
if ((Get-FileHash -LiteralPath (Join-Path $release 'current.json')).Hash -ne $dirtyBefore) { throw 'Stale commit rejection changed pointer' }
[IO.File]::WriteAllText($manifestPath,$manifestText,(New-Object System.Text.UTF8Encoding $false))
Write-Output 'CLEAN SOURCE PASS dirty build or stale commit rejected before publish'
$nativeBefore=(Get-FileHash -LiteralPath (Join-Path $release 'current.json')).Hash
[IO.File]::WriteAllText($nativeFile,'tampered-native')
try { & (Join-Path $PSScriptRoot 'publish_release.ps1') -Executable $exe -ReleaseRoot $release; throw 'Modified native dependency was accepted' }
catch { if ($_.Exception.Message -notmatch 'changed after build') { throw } }
if ((Get-FileHash -LiteralPath (Join-Path $release 'current.json')).Hash -ne $nativeBefore) { throw 'Native dependency rejection changed pointer' }
[IO.File]::WriteAllText($nativeFile,'native-fixture')
Write-Output 'NATIVE PUBLISH PASS dependency copied / hash verified / tamper preserves pointer'
$start=[Diagnostics.ProcessStartInfo]::new((Join-Path $release 'ChibiRTS.exe'),'"space argument" "trailing\\"')
$start.UseShellExecute=$false; $start.CreateNoWindow=$true; $start.WindowStyle=[Diagnostics.ProcessWindowStyle]::Hidden
$process=[Diagnostics.Process]::Start($start)
if (!$process.WaitForExit(30000)) { throw 'Launcher did not exit within 30 seconds' }
if ($process.ExitCode -ne 7) { throw "Launcher arguments or version pair failed: $($process.ExitCode)" }
# Publishing a game update must work while the unchanged launcher is locked.
$locked=[IO.File]::Open((Join-Path $release 'ChibiRTS.exe'),[IO.FileMode]::Open,[IO.FileAccess]::Read,[IO.FileShare]::Read)
try { & (Join-Path $PSScriptRoot 'publish_release.ps1') -Executable $exe -ReleaseRoot $release }
finally { $locked.Dispose() }
# If launcher source changes, a locked entry must fail before the pointer changes.
$changedTools=Join-Path $fixture 'changed-tools'
New-Item -ItemType Directory -Force $changedTools | Out-Null
foreach ($relative in @('LICENSE','NOTICE.md')) {
    $noticeTarget=Join-Path $fixture $relative
    New-Item -ItemType Directory -Force (Split-Path $noticeTarget -Parent) | Out-Null
    Copy-Item -LiteralPath (Join-Path $root $relative) -Destination $noticeTarget
    $published=Join-Path (Join-Path $release $pointer.directory) $relative
    if (!(Test-Path -LiteralPath $published)) { throw 'Required notice missing from published fixture' }
}

Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'publish_release.ps1') -Destination $changedTools
Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'candidate_verification.ps1') -Destination $changedTools
New-Item -ItemType Directory -Force (Join-Path $changedTools 'inputs'),(Join-Path $fixture 'godot/chibi_remake/data') | Out-Null
Copy-Item -LiteralPath $suitePath,$baselinePath -Destination (Join-Path $changedTools 'inputs')
Get-ChildItem -LiteralPath (Join-Path $root 'godot/chibi_remake/data') -Filter 'chibi*.json' -File | ForEach-Object { New-Item -ItemType File -Path (Join-Path $fixture ('godot/chibi_remake/data/'+$_.Name)) | Out-Null }
Remove-Item -LiteralPath (Join-Path $fixture 'LICENSE') -Force
$noticePointerHash=(Get-FileHash -LiteralPath (Join-Path $release 'current.json')).Hash
try {
    try { & (Join-Path $changedTools 'publish_release.ps1') -Executable $exe -ReleaseRoot $release; throw 'Missing notice accepted' }
    catch { if ($_.Exception.Message -notmatch 'Missing required notice: LICENSE') { throw } }
    if ((Get-FileHash -LiteralPath (Join-Path $release 'current.json')).Hash -ne $noticePointerHash) { throw 'Missing notice changed pointer' }
} finally { Copy-Item -LiteralPath (Join-Path $root 'LICENSE') -Destination (Join-Path $fixture 'LICENSE') -Force }
Write-Output 'NOTICE PUBLISH PASS required declarations copied / missing declaration rejects before pointer commit'
[IO.File]::WriteAllText((Join-Path $changedTools 'launcher.cs'),([IO.File]::ReadAllText((Join-Path $PSScriptRoot 'launcher.cs'))+"`n// changed launcher source`n"))
$beforeLocked=(Get-FileHash -LiteralPath (Join-Path $release 'current.json')).Hash
$locked=[IO.File]::Open((Join-Path $release 'ChibiRTS.exe'),[IO.FileMode]::Open,[IO.FileAccess]::Read,[IO.FileShare]::Read)
try {
    try { & (Join-Path $changedTools 'publish_release.ps1') -Executable $exe -ReleaseRoot $release; throw 'Locked launcher replacement was accepted' }
    catch {
        $exception=$_.Exception
        while ($exception.InnerException) { $exception=$exception.InnerException }
        if (($exception.HResult -band 0xffff) -notin @(32,33)) { throw }
    }
} finally { $locked.Dispose() }
if ((Get-FileHash -LiteralPath (Join-Path $release 'current.json')).Hash -ne $beforeLocked) { throw 'Locked changed launcher modified current pointer' }
Write-Output 'LAUNCHER LOCK PASS unchanged source reuses locked entry / changed source preserves previous pointer'
Copy-Item -LiteralPath (Join-Path $release 'current.json') -Destination (Join-Path $release 'current.json.bak') -Force
[IO.File]::WriteAllText((Join-Path $release 'current.json'),'{"directory":"versions/missing"}')
$recovery=[Diagnostics.Process]::Start($start)
if (!$recovery.WaitForExit(30000) -or $recovery.ExitCode -ne 7) { throw 'Backup pointer recovery failed' }
$beforeTamper=(Get-FileHash -LiteralPath (Join-Path $release 'current.json')).Hash
[IO.File]::WriteAllText([IO.Path]::ChangeExtension($exe,'.pck'),'changed-after-build')
try { & (Join-Path $PSScriptRoot 'publish_release.ps1') -Executable $exe -ReleaseRoot $release; throw 'Modified candidate was accepted' }
catch { if ($_.Exception.Message -notmatch 'changed after build') { throw } }
if ((Get-FileHash -LiteralPath (Join-Path $release 'current.json')).Hash -ne $beforeTamper) { throw 'Rejected candidate changed pointer' }
Write-Output 'ARCH-021 PASS: failure preserves current pointer; immutable pair; launcher arguments'
