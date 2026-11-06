$BuildRoot=Split-Path $PSScriptRoot -Parent
$SavedBuildEnvironment=@{TEMP=$env:TEMP;TMP=$env:TMP;APPDATA=$env:APPDATA;LOCALAPPDATA=$env:LOCALAPPDATA}
function Initialize-BuildEnvironment {
    $cache=Join-Path $BuildRoot '_work/build'
    foreach ($name in @('temp','roaming','local')) { New-Item -ItemType Directory -Force (Join-Path $cache $name) | Out-Null }
    $templateName='4.7.2.stable'
    $destination=Join-Path $cache ('roaming/Godot/export_templates/'+$templateName)
    $sources=@()
    if ($env:CHIBI_GODOT_TEMPLATES) { $sources += $env:CHIBI_GODOT_TEMPLATES }
    $sources += (Join-Path $SavedBuildEnvironment.APPDATA ('Godot/export_templates/'+$templateName))
    $sources += (Join-Path $BuildRoot ('_work/art-v1-build/roaming/Godot/export_templates/'+$templateName))
    $found=$false
    foreach ($candidate in $sources) {
        if (Test-Path -LiteralPath (Join-Path $candidate 'windows_release_x86_64.exe')) {
            New-Item -ItemType Directory -Force $destination | Out-Null
            # Both presets target Windows x86_64; skip ~1.7 GiB of other templates.
            foreach ($name in @('windows_release_x86_64.exe','windows_debug_x86_64.exe','windows_release_x86_64_console.exe','windows_debug_x86_64_console.exe','version.txt','icudt_godot.dat')) {
                $source=Join-Path $candidate $name
                if (Test-Path -LiteralPath $source) { Copy-Item -LiteralPath $source -Destination $destination -Force }
            }
            $found=$true; break
        }
    }
    if (!$found) { throw 'Install Godot 4.7.2 export templates or set CHIBI_GODOT_TEMPLATES to their directory.' }
    $env:TEMP=Join-Path $cache 'temp'; $env:TMP=$env:TEMP
    $env:APPDATA=Join-Path $cache 'roaming'; $env:LOCALAPPDATA=Join-Path $cache 'local'
}
function Restore-BuildEnvironment {
    $env:TEMP=$SavedBuildEnvironment.TEMP; $env:TMP=$SavedBuildEnvironment.TMP
    $env:APPDATA=$SavedBuildEnvironment.APPDATA; $env:LOCALAPPDATA=$SavedBuildEnvironment.LOCALAPPDATA
}
