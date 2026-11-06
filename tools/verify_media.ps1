# Verify original AVI bytes and real playback without producing converted videos.
$ErrorActionPreference='Continue'
$root=Split-Path $PSScriptRoot -Parent
$oldRoaming=$env:APPDATA; $oldLocal=$env:LOCALAPPDATA
try {
 $env:APPDATA=Join-Path $root '_work/media-verify/roaming'; $env:LOCALAPPDATA=Join-Path $root '_work/media-verify/local'
 New-Item -ItemType Directory -Force $env:APPDATA,$env:LOCALAPPDATA | Out-Null
 & (Join-Path $root 'Godot_v4.7.2-stable_win64_console.exe') --headless --path (Join-Path $root 'godot/chibi_remake') --import
 if($LASTEXITCODE -ne 0) { throw 'Media project import failed' }
 & (Join-Path $root 'Godot_v4.7.2-stable_win64_console.exe') --headless --path (Join-Path $root 'godot/chibi_remake') --script (Join-Path $PSScriptRoot 'gd/test_original_media.gd') -- --no-intro
 if($LASTEXITCODE -ne 0) { throw 'Original media verification failed' }
} finally { $env:APPDATA=$oldRoaming; $env:LOCALAPPDATA=$oldLocal }
