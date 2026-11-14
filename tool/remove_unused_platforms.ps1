# Run from this project's root. This never changes Flutter's global settings.
$projectRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..')).Path
foreach ($platform in @('ios', 'web', 'windows', 'macos', 'linux')) {
    $candidate = Join-Path $projectRoot $platform
    if (Test-Path -LiteralPath $candidate) {
        $resolved = (Resolve-Path -LiteralPath $candidate).Path
        if ((Split-Path -Path $resolved -Parent) -ne $projectRoot) {
            throw "Refusing to remove a directory outside the project: $resolved"
        }
        Remove-Item -LiteralPath $resolved -Recurse -Force
        Write-Output "Removed $platform"
    }
}
