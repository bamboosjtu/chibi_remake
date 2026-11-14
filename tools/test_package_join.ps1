$ErrorActionPreference='Stop'
$root=Split-Path $PSScriptRoot -Parent
$fixture=Join-Path $root ('_work/join-tests/'+[Guid]::NewGuid().ToString('N'))
$version=Join-Path $fixture 'version'
$output=Join-Path $root ('dist/join-tests-'+[Guid]::NewGuid().ToString('N')+'/package')
New-Item -ItemType Directory -Force (Join-Path $version 'licenses') | Out-Null
$data=New-Object byte[] (2MB+37)
(New-Object Random 1997).NextBytes($data)
[IO.File]::WriteAllBytes((Join-Path $version 'ChibiRTS.pck'),$data)
[IO.File]::WriteAllText((Join-Path $version 'licenses/test.txt'),'notice')
[IO.File]::WriteAllText((Join-Path $version 'release-info.json'),'{"commit":"fixture"}')
& (Join-Path $PSScriptRoot 'package_release.ps1') -VersionDirectory ($version+'\') -OutputDirectory $output -PartMiB 1
if (Test-Path -LiteralPath (Join-Path (Split-Path $output -Parent) 'release-body.md')) { throw 'Packaging wrote outside its output directory' }
$part=Join-Path $output 'ChibiRTS.pck.part002'
$held=Join-Path $fixture 'held-part'
Move-Item -LiteralPath $part -Destination $held
$target=Join-Path $output 'ChibiRTS.pck'
[IO.File]::WriteAllText($target,'old usable target')
$oldHash=(Get-FileHash -LiteralPath $target).Hash
try { & (Join-Path $output 'join-release.ps1'); throw 'Missing part accepted' }
catch { if ($_.Exception.Message -notmatch 'Missing release input') { throw } }
if ((Get-FileHash -LiteralPath $target).Hash -ne $oldHash -or @(Get-ChildItem -LiteralPath $output -Filter '*.part*').Count -ne 2) { throw 'Failure destroyed input or old target' }
Move-Item -LiteralPath $held -Destination $part
$partBytes=[IO.File]::ReadAllBytes($part)
[IO.File]::WriteAllText($part,'corrupt')
try { & (Join-Path $output 'join-release.ps1'); throw 'Corrupt part accepted' }
catch { if ($_.Exception.Message -notmatch 'Hash or size mismatch') { throw } }
if ((Get-FileHash -LiteralPath $target).Hash -ne $oldHash -or @(Get-ChildItem -LiteralPath $output -Filter '*.part*').Count -ne 3) { throw 'Corruption destroyed input or old target' }
[IO.File]::WriteAllBytes($part,$partBytes)
$mapPath=Join-Path $output 'release-files.json'
$mapBytes=[IO.File]::ReadAllBytes($mapPath)
[IO.File]::WriteAllText($mapPath,'{}')
try { & (Join-Path $output 'join-release.ps1'); throw 'Tampered map accepted' }
catch { if ($_.Exception.Message -notmatch 'Checksum mismatch: release-files.json') { throw } }
if ((Get-FileHash -LiteralPath $target).Hash -ne $oldHash) { throw 'Bad map changed previous target' }
[IO.File]::WriteAllBytes($mapPath,$mapBytes)
& (Join-Path $output 'join-release.ps1')
if ((Get-FileHash -LiteralPath $target).Hash -ne (Get-FileHash -LiteralPath (Join-Path $version 'ChibiRTS.pck')).Hash) { throw 'Joined bytes differ' }
if (!(Test-Path -LiteralPath (Join-Path $output 'licenses/test.txt')) -or @(Get-ChildItem -LiteralPath $output -Filter '*.part*').Count) { throw 'Layout or cleanup failed' }
& (Join-Path $output 'join-release.ps1')
& (Join-Path $output 'join-release.cmd')
if ($LASTEXITCODE -ne 0) { throw 'CMD did not use the verified reconstruction path' }
Write-Output 'PACKAGE JOIN PASS missing/corrupt input preserves all parts and old target / original paths / trailing slash / repeated join / SHA256'
