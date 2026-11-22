param([switch]$SkipData,[switch]$SkipImport,[switch]$NoPublish,[switch]$AllowDirty,[switch]$SkipVerify)
& (Join-Path $PSScriptRoot 'build_game.ps1') @PSBoundParameters
exit $LASTEXITCODE
