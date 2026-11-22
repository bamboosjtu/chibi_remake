function Resolve-ChibiEngine([string]$Root) {
    $engine = & node (Join-Path $PSScriptRoot 'verify_engine.mjs') --resolve --root $Root
    if ($LASTEXITCODE -ne 0) { throw 'Could not resolve a reviewed Godot engine' }
    return $engine
}
