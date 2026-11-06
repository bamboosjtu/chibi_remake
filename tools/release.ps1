param(
    [ValidateSet('preview', 'release')]
    [string]$Mode = 'preview',
    [string]$Tag = '',
    [switch]$SkipBuild,
    [int]$PartMiB = 900
)
# Local packaging CLI.
#   preview: build and install into release\versions for local play testing.
#   release: build from a clean tree, then split the current version into
#            dist\package assets below 1 GiB for a manual GitHub upload.
$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
Set-Location -LiteralPath $root

if (!$SkipBuild) {
    $buildArgs = @('-SkipData')
    if ($Mode -eq 'preview') { $buildArgs += '-AllowDirty' }
    & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot 'build_release.ps1') @buildArgs
    if ($LASTEXITCODE -ne 0) { throw ('Build failed with exit code ' + $LASTEXITCODE) }
}

$pointerPath = Join-Path $root 'release/current.json'
if (!(Test-Path -LiteralPath $pointerPath)) { throw 'release/current.json is missing; build a version first' }
$pointer = Get-Content -Raw -Encoding UTF8 $pointerPath | ConvertFrom-Json
$version = Split-Path ([string]$pointer.directory) -Leaf
$versionDir = Join-Path $root ('release/' + [string]$pointer.directory)
if (!(Test-Path -LiteralPath $versionDir)) { throw ('Missing version directory: ' + $versionDir) }

if ($Mode -eq 'preview') {
    Write-Output ('MODE preview')
    Write-Output ('VERSION ' + $version)
    Write-Output ('VERSION_DIR ' + $versionDir)
    Write-Output ('RUN ' + (Join-Path $root 'release\ChibiRTS.exe'))
    Write-Output 'Pointer release/current.json now selects this version.'
    exit 0
}

$manifestPath = Join-Path $versionDir 'build-manifest.json'
if (!(Test-Path -LiteralPath $manifestPath)) { throw 'Version has no build-manifest.json' }
$manifest = Get-Content -Raw -Encoding UTF8 $manifestPath | ConvertFrom-Json
. (Join-Path $PSScriptRoot 'candidate_verification.ps1')
$null=Assert-CandidateVerification $versionDir $manifest
if ($manifest.dirty) { throw 'Release mode requires a clean build; commit the source and rerun without -SkipBuild' }
$head = (& git -C $root rev-parse HEAD 2>$null)
if ($head -and ([string]$manifest.commit).Trim() -ne ([string]$head).Trim()) {
    throw ('Release mode requires a version built from HEAD ' + $head + '; rebuild without -SkipBuild')
}
if (!$Tag) { $Tag = $version }

$packageDir = Join-Path $root 'dist/package'
& powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot 'package_release.ps1') -VersionDirectory $versionDir -OutputDirectory $packageDir -PartMiB $PartMiB -Tag $Tag
if ($LASTEXITCODE -ne 0) { throw ('Packaging failed with exit code ' + $LASTEXITCODE) }
$assets = @(Get-ChildItem -LiteralPath $packageDir -File)
$largest = ($assets | Measure-Object Length -Maximum).Maximum
Write-Output ('MODE release')
Write-Output ('VERSION ' + $version)
Write-Output ('VERSION_DIR ' + $versionDir)
Write-Output ('PACKAGE ' + $packageDir)
Write-Output ('ASSETS ' + $assets.Count + ' maxMiB=' + [math]::Round($largest / 1MB, 1))
Write-Output ('BODY ' + (Join-Path $root 'dist/release-body.md'))
Write-Output ('UPLOAD gh release create ' + $Tag + ' dist/package/* --notes-file dist/release-body.md --prerelease')
exit 0
