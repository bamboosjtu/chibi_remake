param([Parameter(Mandatory=$true)][string]$Executable,[string]$ReleaseRoot,[switch]$FailBeforeCommit,[switch]$AllowDirty)
# No Godot invocation here: filesystem errors must stop before pointer commit.
$ErrorActionPreference='Stop'
$projectRoot=Split-Path $PSScriptRoot -Parent
if (!$ReleaseRoot) { $ReleaseRoot=Join-Path $projectRoot 'release' }
$ReleaseRoot=[IO.Path]::GetFullPath($ReleaseRoot)
$Executable=[IO.Path]::GetFullPath($Executable)
$pack=[IO.Path]::ChangeExtension($Executable,'.pck')
if (!(Test-Path -LiteralPath $Executable) -or !(Test-Path -LiteralPath $pack)) { throw 'EXE/PCK pair is incomplete' }
# 资源包大小**不设上限**（业主明确要求）。
$candidate=[IO.Path]::GetDirectoryName($Executable)
$manifestPath=Join-Path $candidate 'build-manifest.json'
if (!(Test-Path -LiteralPath $manifestPath)) { throw 'Candidate has no build manifest' }
$build=Get-Content -Raw -Encoding UTF8 $manifestPath | ConvertFrom-Json
# Record how the candidate was exercised. Never claim a manual pass we cannot see.
$verification=if ($build.PSObject.Properties.Name -contains 'verification') { [string]$build.verification } else { 'unverified' }
$verificationNote=if ($build.PSObject.Properties.Name -contains 'verificationNote') { [string]$build.verificationNote } else { 'manifest has no verification field' }
if ($verification -ne 'candidate-smoke') {
    throw ('Refusing to publish without candidate verification: ' + $verification)
}
$checks=@(
    [pscustomobject]@{ Path=$Executable; Key='exeSha256' },
    [pscustomobject]@{ Path=$pack; Key='packSha256' }
)
foreach ($check in $checks) {
    $actual=(Get-FileHash -LiteralPath $check.Path).Hash
    $expected=[string]$build.($check.Key)
    if ($actual -ne $expected) { throw ('Candidate changed after build: '+$check.Key+' '+$actual+' != '+$expected) }
}
$nativeFiles=@($build.nativeFiles | Where-Object { $_ -ne $null })
$listedDlls=@($nativeFiles | Where-Object { $_.path -match '\.dll$' })
if (@(Get-ChildItem -LiteralPath $candidate -Recurse -File -Filter '*.dll').Count -ne $listedDlls.Count) { throw 'Native dependency list is incomplete' }
foreach ($file in $nativeFiles) {
    $path=[IO.Path]::GetFullPath((Join-Path $candidate $file.path))
    if (!$path.StartsWith($candidate+[IO.Path]::DirectorySeparatorChar,[StringComparison]::OrdinalIgnoreCase)) { throw 'Unsafe native dependency path' }
    if (!(Test-Path -LiteralPath $path) -or (Get-FileHash -LiteralPath $path).Hash -ne $file.sha256) { throw ('Native dependency changed after build: '+$file.path) }
}
. (Join-Path $PSScriptRoot 'candidate_verification.ps1')
$evidence=Assert-CandidateVerification $candidate $build
if ($build.dirty -and !$AllowDirty) { throw 'Refusing to publish a dirty build: commit the source and rebuild' }
$head=(& git -C $projectRoot rev-parse HEAD 2>$null)
if (!$AllowDirty -and ([string]$build.commit -notmatch '^(?:[a-f0-9]{40}|[a-f0-9]{64})$' -or !$head)) { throw 'Build commit is unavailable; rebuild from a Git checkout' }
if (!$AllowDirty -and $head -and [string]$build.commit -ne 'unknown' -and ([string]$build.commit).Trim() -ne ([string]$head).Trim()) { throw ('Build commit '+$build.commit+' does not match HEAD '+$head+'; rebuild from the released commit') }
$requiredNotices=@('LICENSE','NOTICE.md')
foreach ($relative in $requiredNotices) {
    if (!(Test-Path -LiteralPath (Join-Path $projectRoot $relative))) { throw ('Missing required notice: '+$relative) }
}
$entry=Join-Path $ReleaseRoot 'ChibiRTS.exe' 
$launcherSource=Join-Path $PSScriptRoot 'launcher.cs'
$launcherSourceHash=(Get-FileHash -LiteralPath $launcherSource).Hash
$reuseLauncher=$false
# An active launcher waits for its game and Windows locks its executable.
# Reuse it only when the prior release records the exact same launcher source.
if (Test-Path -LiteralPath $entry) {
    try {
        $prior=Get-Content -Raw -Encoding UTF8 (Join-Path $ReleaseRoot 'current.json') | ConvertFrom-Json
        $priorDirectory=[IO.Path]::GetFullPath((Join-Path $ReleaseRoot $prior.directory))
        if ($priorDirectory.StartsWith((Join-Path $ReleaseRoot 'versions')+[IO.Path]::DirectorySeparatorChar,[StringComparison]::OrdinalIgnoreCase)) {
            $priorInfo=Get-Content -Raw -Encoding UTF8 (Join-Path $priorDirectory 'release-info.json') | ConvertFrom-Json
            $reuseLauncher=$priorInfo.launcherSourceSha256 -eq $launcherSourceHash
        }
    } catch { $reuseLauncher=$false }
}
$commitShort=[Guid]::NewGuid().ToString('N').Substring(0,8)
if ($build.commit -and [string]$build.commit -ne 'unknown') {
    $commitShort=[string]$build.commit
    if ($commitShort.Length -gt 8) { $commitShort=$commitShort.Substring(0,8) }
}
$version=(Get-Date -Format 'yyyyMMdd_HHmmss')+'_'+$commitShort+'_'+[Guid]::NewGuid().ToString('N').Substring(0,6)
$versionDir=Join-Path $ReleaseRoot ('versions/'+$version)
New-Item -ItemType Directory -Force $versionDir | Out-Null
Copy-Item -LiteralPath $Executable -Destination (Join-Path $versionDir 'ChibiRTS.exe')
Copy-Item -LiteralPath $pack -Destination (Join-Path $versionDir 'ChibiRTS.pck')
$pairs=@(
    [pscustomobject]@{ Source=$Executable; Name='ChibiRTS.exe' },
    [pscustomobject]@{ Source=$pack; Name='ChibiRTS.pck' }
)
foreach ($pair in $pairs) {
    $sourceHash=(Get-FileHash -LiteralPath $pair.Source).Hash
    $targetPath=Join-Path $versionDir $pair.Name
    $targetHash=(Get-FileHash -LiteralPath $targetPath).Hash
    if ($sourceHash -ne $targetHash) { throw 'Version copy hash mismatch' }
}
foreach ($file in $nativeFiles) {
    $target=Join-Path $versionDir $file.path
    New-Item -ItemType Directory -Force (Split-Path $target -Parent) | Out-Null
    Copy-Item -LiteralPath (Join-Path $candidate $file.path) -Destination $target
    if ((Get-FileHash -LiteralPath $target).Hash -ne $file.sha256) { throw 'Native dependency copy mismatch' }
}
foreach ($relative in $requiredNotices) {
    $target=Join-Path $versionDir $relative
    New-Item -ItemType Directory -Force (Split-Path $target -Parent) | Out-Null
    Copy-Item -LiteralPath (Join-Path $projectRoot $relative) -Destination $target
    if ((Get-FileHash -LiteralPath $target).Hash -ne (Get-FileHash -LiteralPath (Join-Path $projectRoot $relative)).Hash) { throw 'Notice copy mismatch' }
}
# Build metadata only: logs and validation evidence stay in the local candidate directory.
Copy-Item -LiteralPath $manifestPath -Destination (Join-Path $versionDir 'build-manifest.json')
Copy-Item -LiteralPath (Join-Path $candidate 'verification.json') -Destination (Join-Path $versionDir 'verification.json')
if ((Get-FileHash -LiteralPath (Join-Path $versionDir 'verification.json')).Hash -ne $build.verificationSha256) { throw 'Verification evidence copy mismatch' }
$info=[ordered]@{
    schemaVersion=5
    nativeFiles=$nativeFiles
    version=$version
    commit=$build.commit
    dirty=$build.dirty
    builtAt=$build.builtAt
    publishedAt=(Get-Date).ToUniversalTime().ToString('o')
    exeSha256=(Get-FileHash -LiteralPath $Executable).Hash
    packSha256=(Get-FileHash -LiteralPath $pack).Hash
    buildManifestSha256=(Get-FileHash -LiteralPath $manifestPath).Hash
    launcherSourceSha256=$launcherSourceHash
    verification=$verification
    verificationNote=$verificationNote
    verificationSha256=$build.verificationSha256
    verifiedMaps=@($evidence.results | Where-Object { $_.name -like 'load-*' } | ForEach-Object { $_.name.Substring(5) })
    verifiedBaselines=@($evidence.results | Where-Object { $_.name -like 'sim-*' } | ForEach-Object { $_.name })
}
$infoJson=$info | ConvertTo-Json -Depth 8
[IO.File]::WriteAllText((Join-Path $versionDir 'release-info.json'), $infoJson, (New-Object System.Text.UTF8Encoding $false))
$launcher=Join-Path $ReleaseRoot 'launcher.new.exe'
$compiler=Join-Path $env:WINDIR 'Microsoft.NET/Framework64/v4.0.30319/csc.exe'
if (!$reuseLauncher) {
    # launcher.cs is UTF-8 without BOM; csc otherwise decodes it with the system
    # code page and the Chinese strings land in the binary as mojibake.
    & $compiler /nologo /codepage:65001 /target:winexe /reference:System.Runtime.Serialization.dll /reference:System.Windows.Forms.dll "/out:$launcher" $launcherSource
    if ($LASTEXITCODE -ne 0) { throw 'Launcher compiler failed' }
}
if ($FailBeforeCommit) { throw 'Injected failure: current version not touched' }
# Install a changed launcher before committing current.json; a locked executable
# then leaves the previous pointer intact. Unchanged launchers need no replacement.
if (!$reuseLauncher) {
    if (Test-Path -LiteralPath $entry) { [IO.File]::Replace($launcher,$entry,(Join-Path $ReleaseRoot 'launcher.previous.exe'),$true) } else { [IO.File]::Move($launcher,$entry) }
} else { Write-Output 'Reused unchanged launcher' }
$pointer=Join-Path $ReleaseRoot 'current.json'
$pointerTmp=$pointer+'.tmp'
$pointerJson=(@{directory=('versions/'+$version);schemaVersion=1} | ConvertTo-Json)
[IO.File]::WriteAllText($pointerTmp, $pointerJson, (New-Object System.Text.UTF8Encoding $false))
if (Test-Path -LiteralPath $pointer) { [IO.File]::Replace($pointerTmp,$pointer,$pointer+'.bak',$true) } else { [IO.File]::Move($pointerTmp,$pointer) }
Write-Output "Published immutable version: $version"
