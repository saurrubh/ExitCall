param([string]$Flutter)

$ErrorActionPreference = "Stop"
if (-not $Flutter) {
    $localFlutter = Join-Path $PSScriptRoot ".tooling\flutter\bin\flutter.bat"
    if (Test-Path $localFlutter) { $Flutter = $localFlutter }
    else { $Flutter = "flutter" }
}
Push-Location $PSScriptRoot
try {
    & $Flutter build apk --release
    if ($LASTEXITCODE -ne 0) { throw "Flutter APK build failed with exit code $LASTEXITCODE." }
} finally {
    Pop-Location
}
