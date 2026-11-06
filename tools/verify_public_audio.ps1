# Source-only public-audio pack: no original audio files or original video files.
$ErrorActionPreference='Continue'
$root=Split-Path $PSScriptRoot -Parent
. (Join-Path $PSScriptRoot 'build_environment.ps1')
try {
 Initialize-BuildEnvironment
 $work=Join-Path $root '_work/public-audio-verify'
 $project=Join-Path $work 'project'
 New-Item -ItemType Directory -Force $project | Out-Null
 foreach ($relative in @('presentation/audio/generated_audio.gd','presentation/audio/bgm.gd','presentation/audio/sfx.gd','data/db/audio_index.json')) {
  $target=Join-Path $project $relative
  New-Item -ItemType Directory -Force (Split-Path $target -Parent) | Out-Null
  Copy-Item -LiteralPath (Join-Path (Join-Path $root 'godot/chibi_remake') $relative) -Destination $target -Force
 }
 $utf8=New-Object System.Text.UTF8Encoding $false
 [IO.File]::WriteAllText((Join-Path $project 'project.godot'),"config_version=5`n[application]`nconfig/name=`"Public Audio Test`"`n[rendering]`nrenderer/rendering_method=`"gl_compatibility`"`n",$utf8)
 [IO.File]::WriteAllText((Join-Path $project 'export_presets.cfg'),"[preset.0]`nname=`"public-audio`"`nplatform=`"Windows Desktop`"`nrunnable=true`nexport_filter=`"all_resources`"`ninclude_filter=`"*.json`"`nexclude_filter=`"`"`nexport_path=`"`"`n[preset.0.options]`nbinary_format/architecture=`"x86_64`"`n",$utf8)
 $console=Join-Path $root 'Godot_v4.7.2-stable_win64_console.exe'
 & $console --headless --path $project --import *> (Join-Path $work 'import.log')
 if ($LASTEXITCODE -ne 0) { throw 'Public audio import failed' }
 $pack=Join-Path $work 'public-audio.pck'
 & $console --headless --path $project --export-pack public-audio $pack *> (Join-Path $work 'export.log')
 if ($LASTEXITCODE -ne 0) { throw 'Public audio export failed' }
 $log=Join-Path $work 'native.log'
 $start=[Diagnostics.ProcessStartInfo]::new((Join-Path $root 'Godot_v4.7.2-stable_win64.exe'),('--main-pack "'+$pack+'" --log-file "'+$log+'" --script "'+(Join-Path $PSScriptRoot 'gd/test_public_audio.gd')+'"'))
 $start.UseShellExecute=$false;$start.CreateNoWindow=$true;$start.WindowStyle=[Diagnostics.ProcessWindowStyle]::Hidden
 $process=[Diagnostics.Process]::Start($start)
 if (!$process.WaitForExit(30000)) { $process.Kill();throw 'Public audio playback timed out' }
 $text=Get-Content -Raw $log
 if ($process.ExitCode -ne 0 -or $text -match 'SCRIPT ERROR:' -or $text -notmatch 'PUBLIC AUDIO PCK PASS') { throw 'Public audio playback failed' }
 Write-Output ($text -split "`n" | Where-Object { $_ -match 'PUBLIC AUDIO PCK PASS' })
} finally { Restore-BuildEnvironment }
