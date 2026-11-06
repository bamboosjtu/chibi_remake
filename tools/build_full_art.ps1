param([switch]$SkipVerifiedAssets)
& (Join-Path $PSScriptRoot 'build_game.ps1') -SkipData -SkipVerifiedAssets:$SkipVerifiedAssets
exit $LASTEXITCODE
