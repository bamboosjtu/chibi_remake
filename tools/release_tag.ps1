function Assert-ReleaseTag([string]$Root, [string]$Tag, [string]$Commit) {
    if (!$Tag) { throw 'Release mode requires -Tag naming the remote tag for this commit' }
    $ref='refs/tags/'+$Tag
    & git -C $Root check-ref-format $ref
    if ($LASTEXITCODE -ne 0) { throw ('Invalid release tag: '+$Tag) }
    $dereferenced=$ref+'^{}'
    $remote=@(& git -C $Root ls-remote --exit-code origin $ref $dereferenced)
    if ($LASTEXITCODE -ne 0) { throw ('Cannot verify release tag on origin: '+$Tag) }
    $refs=@{}
    foreach ($line in $remote) {
        $parts=$line -split "\t",2
        if ($parts.Count -eq 2) { $refs[$parts[1]]=$parts[0] }
    }
    $target=if ($refs.ContainsKey($dereferenced)) { $refs[$dereferenced] } else { $refs[$ref] }
    if (!$refs.ContainsKey($ref) -or $target -ne $Commit) { throw ('Remote tag '+$Tag+' does not match build commit '+$Commit) }
}

function Get-ReleaseRepository([string]$Origin) {
    if ($Origin -match '^(?:[^@/\s]+@)?(?<host>[\w.-]+):(?<path>[^/]+/[^/]+)$') {
        $server=$Matches.host
        $repository=$Matches.path
    } else {
        $uri=$null
        if (![Uri]::TryCreate($Origin,[UriKind]::Absolute,[ref]$uri) -or $uri.Scheme -notin @('http','https','ssh','git')) {
            throw 'Cannot identify the GitHub repository for origin'
        }
        $server=$uri.Host
        $repository=$uri.AbsolutePath.Trim('/')
    }
    $repository=$repository -replace '\.git$',''
    if ($server -eq 'ssh.github.com') { $server='github.com' }
    if ($server -notmatch '^[\w.-]+$' -or $repository -notmatch '^[\w.-]+/[\w.-]+$') {
        throw 'Cannot identify the GitHub repository for origin'
    }
    return $server+'/'+$repository
}
