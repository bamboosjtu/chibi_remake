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

function Get-CurrentVersion {
    $pointerPath = Join-Path $root 'release/current.json'
    if (!(Test-Path -LiteralPath $pointerPath -PathType Leaf)) { throw 'release/current.json is missing; build a version first' }
    $pointer = Get-Content -Raw -Encoding UTF8 -LiteralPath $pointerPath | ConvertFrom-Json
    if ($pointer.schemaVersion -ne 1 -or $pointer.directory -notmatch '^versions/[\w-]+$') { throw 'Invalid current version pointer' }
    $directory = Join-Path $root ('release/' + $pointer.directory)
    if (!(Test-Path -LiteralPath $directory -PathType Container)) { throw ('Missing version directory: '+$directory) }
    return $directory
}

if ($Mode -eq 'preview') {
    if (!$SkipBuild) {
        & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot 'build_release.ps1') -SkipData -AllowDirty
        if ($LASTEXITCODE -ne 0) { throw ('Build failed with exit code ' + $LASTEXITCODE) }
    }
    $versionDir = Get-CurrentVersion
    Write-Output 'MODE preview'
    Write-Output ('VERSION ' + (Split-Path $versionDir -Leaf))
    Write-Output ('VERSION_DIR ' + $versionDir)
    Write-Output ('RUN ' + (Join-Path $root 'release\ChibiRTS.exe'))
    exit 0
}

if ($PartMiB -lt 1 -or $PartMiB -ge 1024) { throw 'PartMiB must be between 1 and 1023' }
$head = (& git -C $root rev-parse HEAD 2>$null)
if ($LASTEXITCODE -ne 0 -or !$head) { throw 'Cannot identify the release commit' }
$status = @(& git -C $root status --porcelain 2>$null)
if ($LASTEXITCODE -ne 0 -or $status.Count -gt 0) { throw 'Release mode requires a clean worktree' }
. (Join-Path $PSScriptRoot 'release_tag.ps1')
Assert-ReleaseTag $root $Tag $head
$origin = (& git -C $root remote get-url origin)
if ($LASTEXITCODE -ne 0) { throw 'Cannot identify origin for upload' }
$uploadRepo = Get-ReleaseRepository $origin

$packageDir = Join-Path $root 'dist/package'
if ($SkipBuild) {
    $versionDir = Get-CurrentVersion
    $manifestDir = $versionDir
} else {
    & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot 'build_release.ps1') -SkipData -NoPublish |
        Tee-Object -Variable buildOutput
    if ($LASTEXITCODE -ne 0) { throw ('Build failed with exit code ' + $LASTEXITCODE) }
    $built = @($buildOutput | Where-Object { $_ -like 'Built candidate: *' })
    if ($built.Count -ne 1) { throw 'Build did not report exactly one candidate' }
    $manifestDir = $built[0].Substring('Built candidate: '.Length)
}
$manifest = Get-Content -Raw -Encoding UTF8 -LiteralPath (Join-Path $manifestDir 'build-manifest.json') | ConvertFrom-Json
if ($manifest.commit -ne $head -or $manifest.dirty -isnot [bool] -or $manifest.dirty) {
    throw ('Release mode requires a clean candidate built from '+$head)
}
Assert-ReleaseTag $root $Tag $manifest.commit

if ($SkipBuild) {
    & (Join-Path $PSScriptRoot 'package_release.ps1') -VersionDirectory $versionDir -OutputDirectory $packageDir -PartMiB $PartMiB -Tag $Tag
} else {
    # Package this exact candidate before publishing its pointer.
    $publishArgs = @{
        Executable=(Join-Path $manifestDir 'ChibiRTS.exe')
        PackageDirectory=$packageDir; PartMiB=$PartMiB; Tag=$Tag
    }
    & (Join-Path $PSScriptRoot 'publish_release.ps1') @publishArgs | Tee-Object -Variable publishOutput
    $published = @($publishOutput | Where-Object { $_ -like 'Published immutable version: *' })
    if ($published.Count -ne 1) { throw 'Publish did not report exactly one version' }
    $versionDir = Join-Path $root ('release/versions/'+$published[0].Substring('Published immutable version: '.Length))
}

$notes = Join-Path $packageDir 'release-body.md'
Copy-Item -LiteralPath $notes -Destination (Join-Path $root 'dist/release-body.md') -Force
$assets = @(Get-ChildItem -LiteralPath $packageDir -File)
$largest = ($assets | Measure-Object Length -Maximum).Maximum
Write-Output 'MODE release'
Write-Output ('VERSION ' + (Split-Path $versionDir -Leaf))
Write-Output ('VERSION_DIR ' + $versionDir)
Write-Output ('PACKAGE ' + $packageDir)
Write-Output ('ASSETS ' + $assets.Count + ' maxMiB=' + [math]::Round($largest / 1MB, 1))
Write-Output ('BODY ' + $notes)
$quotedTag = "'" + $Tag.Replace("'","''") + "'"
Write-Output ('UPLOAD gh release create --repo ' + $uploadRepo + ' --verify-tag --prerelease --notes-file dist/package/release-body.md -- ' + $quotedTag + ' dist/package/*')
exit 0
