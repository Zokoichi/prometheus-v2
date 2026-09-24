# ============================================================
# PROMETHEUS V2 — PORTFOLIO GENERATOR
# Compatible Windows PowerShell 5.1
# ============================================================

$ErrorActionPreference = "Stop"

$Root = Split-Path -Parent $PSScriptRoot

$EvidencePath = Join-Path $Root "portfolio\evidence\evidence.jsonl"
$ProjectPath  = Join-Path $Root "portfolio\project\project.json"
$OutputDir    = Join-Path $Root "portfolio\generated"

# ------------------------------------------------------------
# SOURCES
# ------------------------------------------------------------

if (-not (Test-Path $EvidencePath)) {
    throw "Evidence file missing: $EvidencePath"
}

if (-not (Test-Path $ProjectPath)) {
    throw "Project manifest missing: $ProjectPath"
}

if (-not (Test-Path $OutputDir)) {
    New-Item -ItemType Directory -Path $OutputDir -Force | Out-Null
}

# ------------------------------------------------------------
# LOAD EVIDENCE
# ------------------------------------------------------------

$evidence = @()

$evidenceLines = @(
    Get-Content -LiteralPath $EvidencePath
)

foreach ($line in $evidenceLines) {

    if ([string]::IsNullOrWhiteSpace($line)) {
        continue
    }

    try {
        $evidence += ($line | ConvertFrom-Json)
    }
    catch {
        throw "Invalid JSONL evidence record."
    }
}

# ------------------------------------------------------------
# LOAD PROJECT
# ------------------------------------------------------------

try {
    $project =
        Get-Content -LiteralPath $ProjectPath -Raw |
        ConvertFrom-Json
}
catch {
    throw "Invalid project.json."
}

# ------------------------------------------------------------
# VALIDATE STATUS
# ------------------------------------------------------------

$invalidStatus = @(
    $evidence |
        Where-Object {
            $_.status -notin @("observed","validated")
        }
)

if ($invalidStatus.Count -gt 0) {
    throw "Unknown evidence status detected."
}

$observed = @(
    $evidence |
        Where-Object {
            $_.status -eq "observed"
        }
)

$validated = @(
    $evidence |
        Where-Object {
            $_.status -eq "validated"
        }
)

# ------------------------------------------------------------
# ANTI-INVENTION
#
# Aucun mot-clé ne permet de transformer automatiquement
# un artefact en compétence.
# Seules les preuves explicitement validated et portant
# un champ skill/achievement peuvent alimenter ces listes.
# ------------------------------------------------------------

$skills = @()
$achievements = @()

foreach ($item in $validated) {

    if (
        $null -ne $item.skill -and
        [string]$item.skill -ne ""
    ) {
        $skills += [string]$item.skill
    }

    if (
        $null -ne $item.achievement -and
        [string]$item.achievement -ne ""
    ) {
        $achievements += [string]$item.achievement
    }
}

$skills =
    @($skills | Sort-Object -Unique)

$achievements =
    @($achievements | Sort-Object -Unique)

# ------------------------------------------------------------
# GENERATE PROJECT.JSON
# ------------------------------------------------------------

$generated = [ordered]@{
    schema_version = "1.0"

    project = [ordered]@{
        id = [string]$project.project.id
        name = [string]$project.project.name
        type = [string]$project.project.type
        status = [string]$project.project.status
        visibility = [string]$project.project.visibility
    }

    purpose = [ordered]@{
        summary = [string]$project.purpose.summary
    }

    technical = [ordered]@{
        stack = @($project.technical.stack)
    }

    evidence = [ordered]@{
        count = [int]$evidence.Count
        observed_count = [int]$observed.Count
        validated_count = [int]$validated.Count
    }

    skills = @($skills)

    achievements = @($achievements)

    portfolio = [ordered]@{
        generated_from_real_work = $true
        validation_required = $true
        generated_at = (
            (Get-Date).ToUniversalTime().ToString("o")
        )
    }
}

$GeneratedJson =
    Join-Path $OutputDir "project.json"

$JsonText =
    $generated | ConvertTo-Json -Depth 20

# Windows PowerShell 5.1
# Encoding UTF8 natif = UTF-8 avec BOM.
Set-Content `
    -LiteralPath $GeneratedJson `
    -Value $JsonText `
    -Encoding UTF8

# ------------------------------------------------------------
# GENERATE PROJECT.MD
# ------------------------------------------------------------

$md = @()

$md += "# $($project.project.name)"
$md += ""
$md += "> Portfolio généré automatiquement à partir d'artefacts réels du projet."
$md += ""
$md += "## Projet"
$md += ""
$md += "- Identifiant : $($project.project.id)"
$md += "- Type : $($project.project.type)"
$md += "- Statut : $($project.project.status)"
$md += "- Visibilité : $($project.project.visibility)"
$md += ""
$md += "## Finalité"
$md += ""
$md += [string]$project.purpose.summary
$md += ""
$md += "## Stack observée"
$md += ""

foreach ($technology in @($project.technical.stack)) {
    $md += "- $technology"
}

$md += ""
$md += "## Evidence"
$md += ""
$md += "- Nombre total d'artefacts : $($evidence.Count)"
$md += "- Artefacts observés : $($observed.Count)"
$md += "- Artefacts validés : $($validated.Count)"
$md += ""

$md += "## Compétences validées"
$md += ""

if ($skills.Count -eq 0) {
    $md += "Aucune compétence déclarée à ce stade."
}
else {
    foreach ($skill in $skills) {
        $md += "- $skill"
    }
}

$md += ""
$md += "## Réalisations validées"
$md += ""

if ($achievements.Count -eq 0) {
    $md += "Aucune réalisation déclarée à ce stade."
}
else {
    foreach ($achievement in $achievements) {
        $md += "- $achievement"
    }
}

$md += ""
$md += "## Evidence détaillée"
$md += ""

foreach ($item in ($evidence | Sort-Object source)) {

    $md += "### $($item.source)"
    $md += ""
    $md += "- Evidence ID : $($item.evidence_id)"
    $md += "- SHA-256 : $($item.sha256)"
    $md += "- Taille : $($item.size_bytes) octets"
    $md += "- Statut : $($item.status)"
    $md += "- Reproductible : $($item.reproducible)"
    $md += ""
}

$GeneratedMd =
    Join-Path $OutputDir "project.md"

Set-Content `
    -LiteralPath $GeneratedMd `
    -Value $md `
    -Encoding UTF8

# ------------------------------------------------------------
# RESULT
# ------------------------------------------------------------

Write-Host ""
Write-Host "PORTFOLIO GENERATION COMPLETE"
Write-Host "Evidence      : $($evidence.Count)"
Write-Host "Observed      : $($observed.Count)"
Write-Host "Validated     : $($validated.Count)"
Write-Host "Skills        : $($skills.Count)"
Write-Host "Achievements  : $($achievements.Count)"
Write-Host "JSON          : $GeneratedJson"
Write-Host "Markdown      : $GeneratedMd"
