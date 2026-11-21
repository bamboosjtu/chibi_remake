param([switch]$SkipData,[switch]$SkipImport,[switch]$NoOriginalMedia,[switch]$NoPublish,[switch]$AllowDirty,[switch]$SkipVerify,[switch]$IncludeLocalCampaignMedia)
& (Join-Path $PSScriptRoot 'build_game.ps1') @PSBoundParameters
exit $LASTEXITCODE
