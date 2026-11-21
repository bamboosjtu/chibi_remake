# Verify retained originals and local HD using the reviewed engine. No release output.
$ErrorActionPreference='Continue'
$root=Split-Path $PSScriptRoot -Parent
Set-Location -LiteralPath $root
. (Join-Path $PSScriptRoot 'engine_environment.ps1')
. (Join-Path $PSScriptRoot 'workspace_lock.ps1')
$lock=Enter-WorkspaceLock $root 'media verification'
$oldRoaming=$env:APPDATA; $oldLocal=$env:LOCALAPPDATA
try {
 $logs=Join-Path $root '_work/media-verify'
 $env:APPDATA=Join-Path $logs 'roaming'; $env:LOCALAPPDATA=Join-Path $logs 'local'
 New-Item -ItemType Directory -Force $env:APPDATA,$env:LOCALAPPDATA | Out-Null
 $engine=Resolve-ChibiEngine $root
 $project=Join-Path $root 'godot/chibi_remake'
 & node tools/godot_cli.mjs --timeout 360 --log (Join-Path $logs 'import.log') $engine --headless --path $project --import
 if($LASTEXITCODE -ne 0) { throw 'Media project import failed' }
 & node tools/godot_cli.mjs --timeout 180 --log (Join-Path $logs 'shared.log') $engine --headless --path $project --script (Join-Path $PSScriptRoot 'gd/test_original_media.gd') -- --no-intro
 if($LASTEXITCODE -ne 0) { throw 'Shared AVI verification failed' }
 & node tools/godot_cli.mjs --timeout 180 --log (Join-Path $logs 'campaign.log') $engine --headless --path $project --script (Join-Path $PSScriptRoot 'gd/test_campaign_media.gd')
 if($LASTEXITCODE -ne 0) { throw 'HD campaign media verification failed' }
} finally {
 $env:APPDATA=$oldRoaming; $env:LOCALAPPDATA=$oldLocal
 Exit-WorkspaceLock $lock
}
