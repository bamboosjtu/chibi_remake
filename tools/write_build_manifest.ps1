param(
    [Parameter(Mandatory=$true)][string]$Executable,
    [string]$SourceCommit,
    [switch]$SourceDirty,
    [ValidateSet('candidate-smoke','skipped','unverified')][string]$Verification = 'unverified',
    [string]$VerificationNote = ''
)
# Packaging metadata plus how the candidate was exercised. `unverified` records
# a build that was never launched, so publish_release can report it instead of
# silently claiming a manual pass.
$ErrorActionPreference='Stop'
$projectRoot=Split-Path $PSScriptRoot -Parent
$Executable=[IO.Path]::GetFullPath($Executable)
$candidate=Split-Path $Executable -Parent
$pack=[IO.Path]::ChangeExtension($Executable,'.pck')
if (!(Test-Path -LiteralPath $Executable) -or !(Test-Path -LiteralPath $pack)) { throw 'EXE/PCK pair is incomplete' }
if (!$SourceCommit) {
    # Read the full one-line result. Select-Object -First 1 can terminate git
    # early under Windows PowerShell 5.1 and leave LASTEXITCODE=-1.
    $SourceCommit=(& git -C $projectRoot rev-parse HEAD 2>$null)
    if ($LASTEXITCODE -ne 0) { $SourceCommit='unknown' }
    $SourceDirty=@(& git -C $projectRoot status --porcelain 2>$null).Count -gt 0
}
if (@(Get-ChildItem -LiteralPath $candidate -File -Recurse -Filter '*.dll').Count -gt 0) {
    $notices=Join-Path $projectRoot 'godot/chibi_remake/addons/ffmpegplayer'
    $target=Join-Path $candidate 'licenses/ffmpeg'
    New-Item -ItemType Directory -Force $target | Out-Null
    Get-ChildItem -LiteralPath $notices -File | Where-Object { $_.Extension -in @('.txt','.json') } | ForEach-Object {
        Copy-Item -LiteralPath $_.FullName -Destination (Join-Path $target $_.Name) -Force
    }
}
$nativeFiles=@(Get-ChildItem -LiteralPath $candidate -File -Recurse | Where-Object {
    $_.Extension -eq '.dll' -or $_.Name -eq 'portable.txt' -or $_.FullName.StartsWith((Join-Path $candidate 'licenses')+[IO.Path]::DirectorySeparatorChar)
} | ForEach-Object {
    @{path=$_.FullName.Substring($candidate.Length+1).Replace('\','/');bytes=$_.Length;sha256=(Get-FileHash -LiteralPath $_.FullName).Hash}
})
$manifest=[ordered]@{
    schemaVersion=3
    commit=([string]$SourceCommit).Trim()
    dirty=[bool]$SourceDirty
    builtAt=(Get-Date).ToUniversalTime().ToString('o')
    engine='4.7.2.stable'
    verification=$Verification
    verificationNote=$VerificationNote
    verificationSha256=if ($Verification -eq 'candidate-smoke') { (Get-FileHash -LiteralPath (Join-Path $candidate 'verification.json')).Hash } else { '' }
    exeSha256=(Get-FileHash -LiteralPath $Executable).Hash
    packSha256=(Get-FileHash -LiteralPath $pack).Hash
    nativeFiles=$nativeFiles
}
if ($Verification -eq 'candidate-smoke') {
    . (Join-Path $PSScriptRoot 'candidate_verification.ps1')
    $null=Assert-CandidateVerification $candidate ([pscustomobject]$manifest)
}
$manifestPath=Join-Path $candidate 'build-manifest.json'
[IO.File]::WriteAllText($manifestPath,($manifest | ConvertTo-Json -Depth 6),(New-Object System.Text.UTF8Encoding $false))
Write-Output "Build manifest: $manifestPath"
