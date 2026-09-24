# ============================================================
# PROMETHEUS V2 — EVIDENCE SCANNER
# ============================================================

$ErrorActionPreference = "Stop"

# ------------------------------------------------------------
# ROOT
# ------------------------------------------------------------

$Root = Split-Path -Parent $PSScriptRoot

$EvidenceDir  = Join-Path $Root "portfolio\evidence"
$EvidencePath = Join-Path $EvidenceDir "evidence.jsonl"
$ProjectJson  = Join-Path $Root "portfolio\project\project.json"

# ------------------------------------------------------------
# SOURCE ROOTS
# ------------------------------------------------------------

$SourceRoots = @(
    "tests",
    "contracts",
    "scripts",
    "config",
    "docs"
)

$ExcludedExtensions = @(
    ".pem",
    ".key",
    ".pfx",
    ".p12"
)

# ------------------------------------------------------------
# PRECONDITIONS
# ------------------------------------------------------------

if (-not (Test-Path -LiteralPath $Root -PathType Container)) {
    throw "Root projet introuvable."
}

if (-not (Test-Path -LiteralPath $ProjectJson -PathType Leaf)) {
    throw "project.json introuvable."
}

if (-not (Test-Path -LiteralPath $EvidenceDir -PathType Container)) {
    New-Item `
        -ItemType Directory `
        -Path $EvidenceDir `
        -Force |
        Out-Null
}

# ------------------------------------------------------------
# PROJECT
# ------------------------------------------------------------

$Project = Get-Content `
    -LiteralPath $ProjectJson `
    -Raw |
    ConvertFrom-Json

$ProjectId = [string]$Project.project.id

if ([string]::IsNullOrWhiteSpace($ProjectId)) {
    throw "Project ID absent."
}

# ------------------------------------------------------------
# COLLECT
# ------------------------------------------------------------

$Files = @()

foreach ($SourceRoot in $SourceRoots) {

    $AbsoluteRoot = Join-Path $Root $SourceRoot

    if (-not (Test-Path -LiteralPath $AbsoluteRoot -PathType Container)) {
        continue
    }

    $Found = Get-ChildItem `
        -LiteralPath $AbsoluteRoot `
        -File `
        -Recurse `
        -Force |
        Where-Object {
            $ExcludedExtensions -notcontains $_.Extension.ToLowerInvariant()
        }

    if ($null -ne $Found) {
        $Files += @($Found)
    }
}

# ------------------------------------------------------------
# BUILD
# ------------------------------------------------------------

$Records = @()

foreach ($File in $Files) {

    $RelativePath = $File.FullName.Substring($Root.Length)
    $RelativePath = $RelativePath.TrimStart("\")

    # IMPORTANT :
    # .Replace() est utilisé volontairement.
    # Aucun moteur regex n'est impliqué.
    $NormalizedPath = $RelativePath.Replace("\", "/")

    $Hash = (
        Get-FileHash `
            -LiteralPath $File.FullName `
            -Algorithm SHA256
    ).Hash

    $Record = [ordered]@{
        schema_version = "1.0"
        evidence_id    = ("sha256:" + $Hash.ToLowerInvariant())
        project        = $ProjectId
        source         = $NormalizedPath
        type           = "source_artifact"
        sha256         = $Hash
        size_bytes     = [int64]$File.Length
        status         = "observed"
        reproducible   = $false
        claim          = $null
        skill          = $null
        result         = $null
        decision       = $null
        limitation     = $null
        generated_at   = [DateTime]::UtcNow.ToString("o")
    }

    $Records += (
        $Record |
        ConvertTo-Json -Compress -Depth 10
    )
}

# ------------------------------------------------------------
# WRITE ATOMICALLY
# ------------------------------------------------------------

$TempPath = $EvidencePath + ".tmp"

if (Test-Path -LiteralPath $TempPath) {
    Remove-Item `
        -LiteralPath $TempPath `
        -Force
}

$Utf8 = New-Object System.Text.UTF8Encoding($false)

[System.IO.File]::WriteAllLines(
    $TempPath,
    $Records,
    $Utf8
)

if (-not (Test-Path -LiteralPath $TempPath -PathType Leaf)) {
    throw "Fichier temporaire evidence non créé."
}

Move-Item `
    -LiteralPath $TempPath `
    -Destination $EvidencePath `
    -Force

# ------------------------------------------------------------
# VALIDATION
# ------------------------------------------------------------

$WrittenLines = @(
    Get-Content `
        -LiteralPath $EvidencePath
)

if ($WrittenLines.Count -ne $Files.Count) {
    throw "Nombre de records incohérent."
}

foreach ($Line in $WrittenLines) {

    if ([string]::IsNullOrWhiteSpace($Line)) {
        throw "Ligne JSONL vide."
    }

    $null = $Line | ConvertFrom-Json
}

# ------------------------------------------------------------
# OUTPUT
# ------------------------------------------------------------

Write-Host ""
Write-Host "EVIDENCE SCAN COMPLETE"
Write-Host "Root    : $Root"
Write-Host "Records : $($Files.Count)"
Write-Host "Output  : $EvidencePath"
Write-Host "Size    : $((Get-Item -LiteralPath $EvidencePath).Length) octets"
Write-Host "PASS : scanner exécuté."
