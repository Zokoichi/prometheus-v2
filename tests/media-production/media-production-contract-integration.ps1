$ErrorActionPreference = "Stop"

$Project = "C:\Projects\prometheus-v2"

Write-Host ""
Write-Host "============================================================"
Write-Host " PROMETHEUS V2 — MEDIA PRODUCTION INTEGRATION TEST V1.1"
Write-Host "============================================================"
Write-Host ""

& "$Project\scripts\media-production-validator.ps1" -Project $Project

if ($LASTEXITCODE -ne 0) {
    throw "Media production validator failed."
}

Write-Host ""
Write-Host "[VALIDATION] Required files"

$Required = @(
    "$Project\config\media-production.json",
    "$Project\contracts\media\voice-output-v1.json",
    "$Project\contracts\media\music-asset-v1.json",
    "$Project\contracts\media\sfx-asset-v1.json",
    "$Project\contracts\media\visual-asset-v1.json",
    "$Project\contracts\media\caption-plan-v1.json",
    "$Project\contracts\media\editing-blueprint-v1.json",
    "$Project\contracts\media\video-master-v1.json",
    "$Project\docs\media-production-contract-v1.md",
    "$Project\scripts\media-production-validator.ps1"
)

foreach ($Path in $Required) {

    if (Test-Path -LiteralPath $Path) {
        Write-Host "[PASS] $Path" -ForegroundColor Green
    }
    else {
        throw "Missing required file: $Path"
    }
}

Write-Host ""
Write-Host "[VALIDATION] Foundation separation"

if (Test-Path "$Project\config\media-production.json") {
    Write-Host "[PASS] Production profile exists separately from JSON Schemas" -ForegroundColor Green
}
else {
    throw "Production profile missing."
}

Write-Host ""
Write-Host "============================================================"
Write-Host " MEDIA PRODUCTION FOUNDATION — INTEGRATION PASS" -ForegroundColor Green
Write-Host "============================================================"
