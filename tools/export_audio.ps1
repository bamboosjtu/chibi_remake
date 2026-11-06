# Re-export WAV sound sources and OGG music. Video playback uses original AVI files.
$ErrorActionPreference = 'Continue'
$root = Split-Path $PSScriptRoot -Parent
$ffmpeg = (Get-Command ffmpeg -ErrorAction Stop).Source
$iso = Join-Path $root '_work/iso'
$project = Join-Path $root 'godot/chibi_remake'
$media = Join-Path $project 'media'

function Write-Utf8NoBom([string]$path, [string]$text) {
    [System.IO.File]::WriteAllText($path, $text, (New-Object System.Text.UTF8Encoding($false)))
}

# ---------------------------------------------------------------- audio ----
$soundDir = Join-Path $iso 'SOUND'
$waveTxt = Get-Content -Raw (Join-Path $root '_work/dec/WAVE.EXP.txt')
$names = [regex]::Matches($waveTxt, '(?i)[A-Za-z0-9_]+\.wav') | ForEach-Object { $_.Value }
if ($names.Count -ne 122) { throw "WAVE.EXP decoded list expected 122 names, got $($names.Count)" }

$sfxDir = Join-Path $media 'sfx'
$musicDir = Join-Path $media 'music'
New-Item -ItemType Directory -Force -Path $sfxDir, $musicDir | Out-Null

$index = @()
for ($i = 0; $i -lt $names.Count; $i++) {
    $canonical = $names[$i]
    $source = Join-Path $soundDir $canonical
    if (!(Test-Path -LiteralPath $source)) { throw "missing source sound: $source" }
    $lower = $canonical.ToLowerInvariant()
    $dest = Join-Path $sfxDir $lower
    Copy-Item -LiteralPath $source -Destination $dest -Force
    $entry = [ordered]@{
        id = $i
        name = $canonical
        kind = if ($i -lt 12) { 'music' } else { 'sfx' }
        file = "res://media/sfx/$lower"
    }
    if ($i -lt 12) {
        $musicFile = [System.IO.Path]::GetFileNameWithoutExtension($lower) + '.ogg'
        & $ffmpeg -hide_banner -loglevel error -i $source -c:a libvorbis -q:a 5 -y (Join-Path $musicDir $musicFile)
        if ($LASTEXITCODE -ne 0) { throw "ffmpeg failed (music): $source" }
        $entry.music = "res://media/music/$musicFile"
    }
    $index += $entry
}

# Ending music is END\VEND.WAV (not part of WAVE.EXP).
$vendSrc = Join-Path $iso 'END/VEND.WAV'
if (Test-Path -LiteralPath $vendSrc) {
    Copy-Item -LiteralPath $vendSrc -Destination (Join-Path $sfxDir 'vend.wav') -Force
    & $ffmpeg -hide_banner -loglevel error -i $vendSrc -c:a libvorbis -q:a 5 -y (Join-Path $musicDir 'vend.ogg')
    if ($LASTEXITCODE -ne 0) { throw "ffmpeg failed (vend)" }
}

$audioIndex = [ordered]@{
    source = 'SET/WAVE.EXP (XOR-0x22, 12 BGM + 110 SFX)'
    count = 122
    ending_music = 'res://media/music/vend.ogg'
    entries = $index
}
Write-Utf8NoBom (Join-Path $project 'data/db/audio_index.json') ($audioIndex | ConvertTo-Json -Depth 6)
Write-Utf8NoBom (Join-Path $sfxDir 'index.json') ($audioIndex | ConvertTo-Json -Depth 6)

Write-Host "audio: $($names.Count) wav + vend; 13 music tracks"
