$ErrorActionPreference='Stop'
$repo=Split-Path $PSScriptRoot -Parent
$fixture=Join-Path $repo ('_work/release-tag-tests/'+[Guid]::NewGuid().ToString('N'))
$local=Join-Path $fixture 'local'
$remote=Join-Path $fixture 'origin.git'
. (Join-Path $PSScriptRoot 'release_tag.ps1')
. (Join-Path $PSScriptRoot 'package_test_fixture.ps1')
try {
    New-Item -ItemType Directory -Force $local,$remote | Out-Null
    & git -C $remote init --bare --quiet
    if ($LASTEXITCODE -ne 0) { throw 'Cannot initialize remote fixture' }
    & git -C $local init --quiet
    if ($LASTEXITCODE -ne 0) { throw 'Cannot initialize local fixture' }
    & git -C $local -c 'user.name=Release Fixture' -c 'user.email=fixture@example.invalid' commit --allow-empty -qm 'Fixture commit'
    if ($LASTEXITCODE -ne 0) { throw 'Cannot create fixture commit' }
    $commit=(& git -C $local rev-parse HEAD).Trim()
    & git -C $local remote add origin $remote
    & git -C $local tag 'v-light'
    & git -C $local -c 'user.name=Release Fixture' -c 'user.email=fixture@example.invalid' tag -a 'v-annotated' -m 'Fixture'
    if ($LASTEXITCODE -ne 0) { throw 'Cannot create fixture tags' }
    & git -C $local push --quiet --tags origin
    if ($LASTEXITCODE -ne 0) { throw 'Cannot populate local remote fixture' }
    Assert-ReleaseTag $local 'v-light' $commit
    Assert-ReleaseTag $local 'v-annotated' $commit
    try { Assert-ReleaseTag $local 'v-annotated' ('0'*40); throw 'Wrong tag target accepted' }
    catch { if ($_.Exception.Message -notmatch 'does not match build commit') { throw } }
    try { Assert-ReleaseTag $local 'v-missing' $commit; throw 'Missing remote tag accepted' }
    catch { if ($_.Exception.Message -notmatch 'Cannot verify release tag') { throw } }
    foreach ($origin in @('git@github.com:owner/project.git','https://github.com/owner/project.git','ssh://git@ssh.github.com:443/owner/project.git')) {
        if ((Get-ReleaseRepository $origin) -ne 'github.com/owner/project') { throw 'Upload repository differs from origin' }
    }
    Write-Output 'RELEASE TAG PASS annotated and lightweight tags / missing and wrong target rejected'
} finally { Remove-PackageTestFixture $fixture }
