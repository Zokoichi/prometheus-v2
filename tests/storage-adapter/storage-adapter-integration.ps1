$ErrorActionPreference = "Stop"

$Root = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$Adapter = Join-Path $Root "scripts\storage-adapter.ps1"

$Workspace = Join-Path $PSScriptRoot "workspace"
New-Item -ItemType Directory -Force -Path $Workspace | Out-Null

$InputFile = Join-Path $Workspace "storage-adapter-test.txt"
$OutputFile = Join-Path $Workspace "storage-adapter-test-download.txt"

$RunId = "RUN-STORAGE-ADAPTER-TEST"
$Key = "run/$RunId/storage/storage-adapter-test.txt"

Set-Content `
    -LiteralPath $InputFile `
    -Value "PROMETHEUS V2 STORAGE ADAPTER TEST" `
    -Encoding UTF8

Write-Host ""
Write-Host "=== STORAGE ADAPTER INTEGRATION TEST ===" -ForegroundColor Cyan

Write-Host "[1] PUT" -ForegroundColor Yellow

& powershell.exe `
    -NoProfile `
    -ExecutionPolicy Bypass `
    -File $Adapter `
    -Operation put `
    -Environment test `
    -ObjectKey $Key `
    -LocalFile $InputFile `
    -ContentType "text/plain"

if ($LASTEXITCODE -ne 0) {
    throw "PUT failed"
}

Write-Host "[2] HEAD" -ForegroundColor Yellow

& powershell.exe `
    -NoProfile `
    -ExecutionPolicy Bypass `
    -File $Adapter `
    -Operation head `
    -Environment test `
    -ObjectKey $Key

if ($LASTEXITCODE -ne 0) {
    throw "HEAD failed"
}

Write-Host "[3] GET" -ForegroundColor Yellow

& powershell.exe `
    -NoProfile `
    -ExecutionPolicy Bypass `
    -File $Adapter `
    -Operation get `
    -Environment test `
    -ObjectKey $Key `
    -DestinationFile $OutputFile

if ($LASTEXITCODE -ne 0) {
    throw "GET failed"
}

if (-not (Test-Path -LiteralPath $OutputFile)) {
    throw "Downloaded file missing"
}

$InputHash  = (Get-FileHash -LiteralPath $InputFile -Algorithm SHA256).Hash
$OutputHash = (Get-FileHash -LiteralPath $OutputFile -Algorithm SHA256).Hash

if ($InputHash -ne $OutputHash) {
    throw "SHA256 mismatch: source=$InputHash destination=$OutputHash"
}

Write-Host "[4] DELETE" -ForegroundColor Yellow

& powershell.exe `
    -NoProfile `
    -ExecutionPolicy Bypass `
    -File $Adapter `
    -Operation delete `
    -Environment test `
    -ObjectKey $Key

if ($LASTEXITCODE -ne 0) {
    throw "DELETE failed"
}

Write-Host ""
Write-Host "RESULT: PASS" -ForegroundColor Green
Write-Host "SHA256 : $InputHash" -ForegroundColor Green
