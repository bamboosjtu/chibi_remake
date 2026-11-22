function Remove-PackageTestFixture([string]$Directory) {
    if (!(Test-Path -LiteralPath $Directory -PathType Container)) { return }
    $repo = Split-Path $PSScriptRoot -Parent
    $work = [IO.Path]::GetFullPath((Join-Path $repo '_work')) + [IO.Path]::DirectorySeparatorChar
    $target = (Resolve-Path -LiteralPath $Directory).Path
    if (!$target.StartsWith($work, [StringComparison]::OrdinalIgnoreCase)) { throw 'Packaging fixture is outside the workspace scratch directory' }
    $ancestor = Get-Item -LiteralPath $target -Force
    while ($null -ne $ancestor -and $ancestor.FullName.StartsWith($work.TrimEnd('\'), [StringComparison]::OrdinalIgnoreCase)) {
        if ($ancestor.Attributes -band [IO.FileAttributes]::ReparsePoint) { throw 'Packaging fixture contains a reparse point in its path' }
        $ancestor = $ancestor.Parent
    }
    Remove-Item -LiteralPath $target -Recurse -Force
}
