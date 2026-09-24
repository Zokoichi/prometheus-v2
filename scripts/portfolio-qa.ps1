# ============================================================
# PROMETHEUS V2 — PORTFOLIO QA
# Security / consistency / anti-invention
# ============================================================

$ErrorActionPreference = "Stop"

$Repo = Split-Path -Parent $PSScriptRoot
Set-Location $Repo

Write-Host ""
Write-Host "PORTFOLIO QA"
Write-Host "============"

$failures = New-Object System.Collections.Generic.List[string]

# 1. Generated files must stay inside generated/
$generatedRoot = [System.IO.Path]::GetFullPath(
    (Join-Path (Get-Location) "portfolio\generated")
)

Get-ChildItem "portfolio\generated" -Recurse -File -ErrorAction SilentlyContinue |
    ForEach-Object {

        $full = [System.IO.Path]::GetFullPath($_.FullName)

        if (-not $full.StartsWith($generatedRoot, [System.StringComparison]::OrdinalIgnoreCase)) {
            $failures.Add("Generated output escaped portfolio/generated: $full")
        }
    }

# 2. .env must never be tracked
if (@(git ls-files -- ".env").Count -gt 0) {
    $failures.Add(".env is tracked by Git.")
}

# 3. No obvious secret literals in generated portfolio
$secretPatterns = @(
    'ghp_[A-Za-z0-9]{20,}',
    'github_pat_[A-Za-z0-9_]{20,}',
    'AKIA[0-9A-Z]{16}',
    'BEGIN (RSA |EC |OPENSSH )?PRIVATE KEY',
    'Bearer\s+[A-Za-z0-9\-_\.]+',
    'sk-[A-Za-z0-9]{20,}'
)

$generatedFiles = @(Get-ChildItem "portfolio\generated" -Recurse -File -ErrorAction SilentlyContinue)

foreach ($file in $generatedFiles) {

    $content = Get-Content -Raw -LiteralPath $file.FullName

    foreach ($pattern in $secretPatterns) {
        if ($content -match $pattern) {
            $failures.Add("Possible secret pattern in generated file: $($file.FullName)")
        }
    }
}

# 4. Evidence JSONL must be valid
$evidenceFile = "portfolio\evidence\evidence.jsonl"

if (-not (Test-Path $evidenceFile)) {
    $failures.Add("Missing evidence.jsonl")
}
else {
    $lineNumber = 0

    Get-Content $evidenceFile | ForEach-Object {

        $lineNumber++

        if ($_.Trim()) {
            try {
                $_ | ConvertFrom-Json | Out-Null
            }
            catch {
                $failures.Add("Invalid JSONL at line $lineNumber")
            }
        }
    }
}

# 5. Claims must have status validated
if (Test-Path $evidenceFile) {

    Get-Content $evidenceFile |
        Where-Object { $_.Trim() } |
        ForEach-Object {

            $record = $_ | ConvertFrom-Json

            if ($record.claim -and $record.status -ne "validated") {
                $failures.Add(
                    "Claim without validated status: $($record.source)"
                )
            }

            if ($record.skill -and $record.status -ne "validated") {
                $failures.Add(
                    "Skill without validated status: $($record.source)"
                )
            }
        }
}

if ($failures.Count -gt 0) {

    Write-Host ""
    Write-Host "QA : FAIL"

    $failures | ForEach-Object {
        Write-Host "  FAIL : $_"
    }

    exit 1
}

Write-Host ""
Write-Host "QA : PASS"
Write-Host "No obvious secrets."
Write-Host "No .env tracked."
Write-Host "No unvalidated claims."
Write-Host "Evidence JSONL valid."