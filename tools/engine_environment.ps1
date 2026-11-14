function Resolve-ChibiEngine([string]$Root) {
    if ($env:CHIBI_GODOT_ENGINE) { return [IO.Path]::GetFullPath($env:CHIBI_GODOT_ENGINE) }
    $local=Join-Path $Root 'Godot_v4.7.2-stable_win64.exe'
    if (Test-Path -LiteralPath $local) { return $local }
    return (Get-Command godot.exe -ErrorAction Stop).Source
}
