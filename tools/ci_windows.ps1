param([switch]$SkipArtCheck,[switch]$FullRegression)
# Windows CI: minimal smoke by default; full gameplay checks are opt-in.
# Requires the local Godot engine and declared runtime assets, not art masters.
# Godot may write a certificate warning to stderr; every native result is checked below.
$ErrorActionPreference='Continue'
$root=Split-Path $PSScriptRoot -Parent
Set-Location -LiteralPath $root

Write-Host '== docs lint (links + spec purity + appendix) =='
node tools/docs_lint.mjs
if ($LASTEXITCODE -ne 0) { throw 'docs_lint failed' }

if (!$SkipArtCheck -and (Test-Path 'godot/chibi_remake/art/full/manifest.json')) {
    Write-Host '== declared runtime assets (size check) =='
    node tools/runtime_assets.mjs --check
    if ($LASTEXITCODE -ne 0) { throw 'runtime asset check failed' }
} else {
    Write-Host '== art manifest skipped (no art masters or -SkipArtCheck) =='
}

$env:APPDATA=Join-Path $root '_work/ci/appdata'
$env:LOCALAPPDATA=Join-Path $root '_work/ci/localappdata'
New-Item -ItemType Directory -Force $env:APPDATA,$env:LOCALAPPDATA | Out-Null
$godot=Join-Path $root 'Godot_v4.7.2-stable_win64_console.exe'
if (!(Test-Path $godot)) { throw '缺少 Godot 引擎：Godot_v4.7.2-stable_win64_console.exe' }

foreach ($test in @('test_package_safety.ps1','test_publish.ps1','test_candidate_lock.ps1')) {
    & (Join-Path $PSScriptRoot $test)
    if (!$?) { throw ('Windows tool regression failed: '+$test) }
}

Write-Host '== architecture boundaries and regression suites =='
node tools/architecture_check.mjs
if ($LASTEXITCODE -ne 0) { throw 'Architecture boundary check failed' }
node tools/registry_check.mjs
if ($LASTEXITCODE -ne 0) { throw 'Composition registry check failed' }
node tools/data_check.mjs
if ($LASTEXITCODE -ne 0) { throw 'Data schema check failed' }
node tools/test_registry_check.mjs
if ($LASTEXITCODE -ne 0) { throw 'Negative composition checks failed' }
node tools/test_registry_runtime.mjs
if ($LASTEXITCODE -ne 0) { throw 'Runtime composition rejection failed' }
if ($FullRegression) {
    node tools/run_regressions.mjs --selftests --baselines --maps --suite tools/inputs/release_tests.json --suite tools/inputs/development_tests.json --suite tools/inputs/known_failures.json --output _work/ci/regressions
} else {
    node tools/run_regressions.mjs --suite tools/inputs/release_tests.json --output _work/ci/regressions
}
if ($LASTEXITCODE -ne 0) { throw 'Runtime regressions failed; inspect _work/ci/regressions/results.json' }
Write-Host 'CI OK'
