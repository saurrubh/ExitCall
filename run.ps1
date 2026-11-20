param(
    [string]$Device,
    [string]$Flutter
)

$ErrorActionPreference = "Stop"
if (-not $Flutter) {
    $localFlutter = Join-Path $PSScriptRoot ".tooling\flutter\bin\flutter.bat"
    if (Test-Path $localFlutter) { $Flutter = $localFlutter }
    else { $Flutter = "flutter" }
}

$runArguments = @("run")
if ($Device) { $runArguments += @("-d", $Device) }
Push-Location $PSScriptRoot
try {
    & $Flutter @runArguments
    if ($LASTEXITCODE -ne 0) { throw "Flutter run failed with exit code $LASTEXITCODE." }
} finally {
    Pop-Location
}
