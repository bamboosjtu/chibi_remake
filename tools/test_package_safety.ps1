$ErrorActionPreference='Stop'
$root=Split-Path $PSScriptRoot -Parent
$fixture=Join-Path $root ('_work/package-safety/'+[Guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Force $fixture | Out-Null
$sentinel=Join-Path $fixture 'must-survive.txt'
[IO.File]::WriteAllText($sentinel,'keep')
foreach ($output in @($root,(Join-Path $root 'dist'),$fixture,($fixture+[IO.Path]::DirectorySeparatorChar))) {
    try { & (Join-Path $PSScriptRoot 'package_release.ps1') -VersionDirectory $fixture -OutputDirectory $output; throw 'Unsafe output accepted' }
    catch { if ($_.Exception.Message -notmatch 'must live under|must differ') { throw } }
    if (!(Test-Path -LiteralPath $sentinel)) { throw 'Rejected packaging deleted its source' }
}
$nested=Join-Path $root ('dist/package-safety-'+[Guid]::NewGuid().ToString('N'))
$version=Join-Path $nested 'version'
New-Item -ItemType Directory -Force $version | Out-Null
try { & (Join-Path $PSScriptRoot 'package_release.ps1') -VersionDirectory $version -OutputDirectory $nested; throw 'Source-containing output accepted' }
catch { if ($_.Exception.Message -notmatch 'must not contain') { throw } }
Write-Output 'PACKAGE SAFETY PASS workspace / dist root / source equality / source ancestor rejected before deletion'
