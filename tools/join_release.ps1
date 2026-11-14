param([string]$Directory = $PSScriptRoot)
$ErrorActionPreference='Stop'
$Directory=[IO.Path]::GetFullPath($Directory)
if ($Directory.Length -gt [IO.Path]::GetPathRoot($Directory).Length) { $Directory=$Directory.TrimEnd('\','/') }
$prefix=$Directory.TrimEnd('\','/')+[IO.Path]::DirectorySeparatorChar
function Resolve-Child([string]$Relative) {
    if ([IO.Path]::IsPathRooted($Relative)) { throw ('Unsafe release path: '+$Relative) }
    $resolved=[IO.Path]::GetFullPath((Join-Path $Directory $Relative))
    if (!$resolved.StartsWith($prefix,[StringComparison]::OrdinalIgnoreCase)) { throw ('Unsafe release path: '+$Relative) }
    $ancestor=$resolved
    while ($ancestor -ne $Directory) {
        if ((Test-Path -LiteralPath $ancestor) -and ((Get-Item -LiteralPath $ancestor -Force).Attributes -band [IO.FileAttributes]::ReparsePoint)) { throw ('Reparse point in release path: '+$ancestor) }
        $ancestor=Split-Path $ancestor -Parent
    }
    return $resolved
}
function Assert-Bytes([string]$Path,$Expected) {
    if (!(Test-Path -LiteralPath $Path -PathType Leaf)) { throw ('Missing release input: '+$Path) }
    if ((Get-Item -LiteralPath $Path).Length -ne [long]$Expected.bytes -or (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash -ne $Expected.sha256) { throw ('Hash or size mismatch: '+$Path) }
}
$hashes=@{}
foreach ($line in (Get-Content -LiteralPath (Join-Path $Directory 'SHA256SUMS.txt'))) {
    if ($line -notmatch '^([0-9A-Fa-f]{64})\s+\*?(.+)$' -or $hashes.ContainsKey($Matches[2])) { throw 'Malformed or duplicate checksum entry' }
    $hashes[$Matches[2]]=$Matches[1]
}
foreach ($name in @('release-files.json','join-release.ps1','join-release.cmd')) {
    if (!$hashes.ContainsKey($name) -or (Get-FileHash -LiteralPath (Resolve-Child $name)).Hash -ne $hashes[$name]) { throw ('Checksum mismatch: '+$name) }
}
$map=Get-Content -Raw -Encoding UTF8 (Join-Path $Directory 'release-files.json') | ConvertFrom-Json
if ($map.schemaVersion -ne 1 -or @($map.files).Count -eq 0) { throw 'Unsupported or empty release file map' }
if ($hashes.Count -ne @($map.files).Count+3) { throw 'Checksum set differs from release map' }
$stage=Join-Path $Directory ('.join-'+[Guid]::NewGuid().ToString('N'))
if (![IO.Path]::GetFullPath($stage).StartsWith($prefix,[StringComparison]::OrdinalIgnoreCase)) { throw 'Unsafe staging directory' }
New-Item -ItemType Directory -Path $stage | Out-Null
$pending=@(); $consumed=@(); $destinations=@{}
try {
    foreach ($file in $map.files) {
        $target=Resolve-Child ([string]$file.relative)
        if ($destinations.ContainsKey($target)) { throw ('Duplicate release destination: '+$target) }
        $destinations[$target]=$true
        if ($file.asset -ne [IO.Path]::GetFileName($file.asset)) { throw 'Unsafe asset name' }
        if (!$hashes.ContainsKey($file.asset) -or $hashes[$file.asset] -ne $file.sha256) { throw ('Checksum map differs: '+$file.asset) }
        $temporary=Join-Path $stage ([Guid]::NewGuid().ToString('N'))
        $parts=@($file.parts)
        if ($parts.Count -gt 0) {
            if ((Test-Path -LiteralPath $target) -and @($parts | Where-Object { Test-Path -LiteralPath (Resolve-Child ([string]$_.name)) }).Count -eq 0) {
                Assert-Bytes $target $file
                continue
            }
            $output=[IO.File]::Create($temporary)
            try {
                for ($i=0;$i -lt $parts.Count;$i++) {
                    $part=$parts[$i]
                    if ($part.name -ne ('{0}.part{1:D3}' -f $file.asset,($i+1))) { throw ('Invalid part sequence: '+$part.name) }
                    $inputPath=Resolve-Child ([string]$part.name)
                    Assert-Bytes $inputPath $part
                    $input=[IO.File]::OpenRead($inputPath)
                    try { $input.CopyTo($output) } finally { $input.Dispose() }
                    $consumed+=$inputPath
                }
            } finally { $output.Dispose() }
            Assert-Bytes $temporary $file
            $pending+=@{temporary=$temporary;target=$target}
        } else {
            $inputPath=Resolve-Child ([string]$file.asset)
            Assert-Bytes $inputPath $file
            if ($inputPath -ne $target) {
                [IO.File]::Copy($inputPath,$temporary)
                $pending+=@{temporary=$temporary;target=$target}
            }
        }
    }
    # No input or previous target is changed until every group has validated.
    foreach ($item in $pending) {
        New-Item -ItemType Directory -Force (Split-Path $item.target -Parent) | Out-Null
        if (Test-Path -LiteralPath $item.target) { [IO.File]::Replace($item.temporary,$item.target,(Join-Path $stage ([Guid]::NewGuid().ToString('N')+'.bak'))) }
        else { [IO.File]::Move($item.temporary,$item.target) }
    }
    foreach ($file in $map.files) { Assert-Bytes (Resolve-Child ([string]$file.relative)) $file }
    foreach ($part in $consumed) { Remove-Item -LiteralPath $part -Force }
    Write-Output 'Joined and verified. Run ChibiRTS.exe.'
} finally {
    # Only this owned, checked, non-reparse child can be deleted recursively.
    if ((Test-Path -LiteralPath $stage) -and [IO.Path]::GetFullPath($stage).StartsWith($prefix,[StringComparison]::OrdinalIgnoreCase) -and !((Get-Item -LiteralPath $stage -Force).Attributes -band [IO.FileAttributes]::ReparsePoint)) { Remove-Item -LiteralPath $stage -Recurse -Force }
}
