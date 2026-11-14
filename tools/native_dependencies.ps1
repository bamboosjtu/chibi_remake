function Get-RequiredNativeNames([string]$SourceRoot) {
    $declaration=Join-Path $SourceRoot 'godot/chibi_remake/addons/ffmpegplayer/FFmpegPlayer.gdextension'
    if (!(Test-Path -LiteralPath $declaration)) { throw ('Missing native dependency declaration: '+$declaration) }
    $names=@([regex]::Matches([IO.File]::ReadAllText($declaration),'res://addons/ffmpegplayer/win64/([^"\s/]+\.dll)') | ForEach-Object { $_.Groups[1].Value } | Sort-Object -Unique)
    if ($names.Count -eq 0) { throw 'Native dependency declaration is empty' }
    return $names
}
function Assert-NativeDependencies([string]$Directory,[string]$SourceRoot) {
    $required=@(Get-RequiredNativeNames $SourceRoot)
    foreach ($name in $required) { if (!(Test-Path -LiteralPath (Join-Path $Directory $name) -PathType Leaf)) { throw ('Missing required native dependency: '+$name) } }
    $actual=@(Get-ChildItem -LiteralPath $Directory -Filter '*.dll' -Recurse -File)
    if ($actual.Count -ne $required.Count -or @(Compare-Object ($actual.Name|Sort-Object) ($required|Sort-Object)).Count) { throw 'Native dependency set differs from declaration' }
}
