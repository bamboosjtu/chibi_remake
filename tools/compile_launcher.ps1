param([Parameter(Mandatory=$true)][string]$Output)
$ErrorActionPreference = 'Stop'
$project = Join-Path (Split-Path $PSScriptRoot -Parent) 'godot/chibi_remake/project.godot'
$match = Select-String -LiteralPath $project -Pattern '^config/version="(\d+\.\d+\.\d+)"$'
if ($null -eq $match) { throw 'Missing project version' }
$version = $match.Matches[0].Groups[1].Value + '.0'
$compiler = Join-Path $env:WINDIR 'Microsoft.NET/Framework64/v4.0.30319/csc.exe'
$info = Join-Path ([IO.Path]::GetTempPath()) ('chibi-launcher-'+[Guid]::NewGuid().ToString('N')+'.cs')
try {
    Set-Content -LiteralPath $info -Encoding ASCII -Value @"
[assembly: System.Reflection.AssemblyVersion("$version")]
[assembly: System.Reflection.AssemblyFileVersion("$version")]
[assembly: System.Reflection.AssemblyInformationalVersion("$version")]
"@
    & $compiler /nologo /codepage:65001 /target:winexe /reference:System.Runtime.Serialization.dll /reference:System.Windows.Forms.dll "/out:$Output" (Join-Path $PSScriptRoot 'launcher.cs') $info
    if ($LASTEXITCODE -ne 0) { throw 'Launcher compiler failed' }
} finally {
    if (Test-Path -LiteralPath $info) { Remove-Item -LiteralPath $info }
}
