param(
    [Parameter(Mandatory=$true)]
    [string]$ScenePlanPath
)

$ErrorActionPreference = "Stop"

$Failures = 0
$Passes = 0

function Pass($Message) {
    $script:Passes++
    Write-Host "[PASS] $Message" -ForegroundColor Green
}

function Fail($Message) {
    $script:Failures++
    Write-Host "[FAIL] $Message" -ForegroundColor Red
}

function Warn($Message) {
    Write-Host "[WARN] $Message" -ForegroundColor Yellow
}

if (-not (Test-Path $ScenePlanPath)) {
    throw "Scene plan introuvable : $ScenePlanPath"
}

try {
    $Plan = Get-Content -Raw -LiteralPath $ScenePlanPath | ConvertFrom-Json
}
catch {
    throw "Scene plan JSON invalide"
}

Write-Host ""
Write-Host "============================================================"
Write-Host "PROMETHEUS V2 — SCENE PLAN QUALITY VALIDATOR"
Write-Host "============================================================"
Write-Host ""

# ------------------------------------------------------------
# BASIC CONTRACT
# ------------------------------------------------------------

$RequiredRoot = @(
    "title",
    "scene_count",
    "total_estimated_duration_seconds",
    "scenes"
)

foreach ($Field in $RequiredRoot) {

    if ($null -ne $Plan.PSObject.Properties[$Field]) {
        Pass "Champ racine présent : $Field"
    }
    else {
        Fail "Champ racine absent : $Field"
    }
}

if ($null -eq $Plan.scenes) {
    throw "Impossible de poursuivre : scenes absent"
}

$SceneCount = @($Plan.scenes).Count

if ($SceneCount -ge 7 -and $SceneCount -le 12) {
    Pass "Nombre de scènes : $SceneCount"
}
else {
    Fail "Nombre de scènes hors plage 7–12 : $SceneCount"
}

if ([int]$Plan.scene_count -eq $SceneCount) {
    Pass "scene_count cohérent avec le tableau scenes"
}
else {
    Fail "scene_count incohérent"
}

# ------------------------------------------------------------
# SCENE SEMANTICS
# ------------------------------------------------------------

$AllowedRoles = @(
    "HOOK",
    "CONTEXT",
    "DEVELOPMENT",
    "INSIGHT",
    "TWIST",
    "CONCLUSION",
    "CTA"
)

$AllowedShotTypes = @(
    "WIDE",
    "MEDIUM",
    "CLOSE_UP",
    "EXTREME_WIDE"
)

$AllowedCameraMotion = @(
    "ZOOM_IN",
    "ZOOM_OUT",
    "PAN_LEFT",
    "PAN_RIGHT",
    "STATIC"
)

$PreviousShot = $null
$PreviousVoice = $null
$TotalWords = 0
$ComputedDuration = 0.0

foreach ($Scene in @($Plan.scenes)) {

    $N = $Scene.scene_number

    $RequiredSceneFields = @(
        "scene_number",
        "role",
        "voice_over",
        "visual_description",
        "word_count",
        "estimated_duration_seconds",
        "shot_type",
        "camera_motion"
    )

    foreach ($Field in $RequiredSceneFields) {

        if ($null -ne $Scene.PSObject.Properties[$Field]) {
            Pass "Scene $N : $Field"
        }
        else {
            Fail "Scene $N : champ absent $Field"
        }
    }

    $Text = [string]$Scene.voice_over
    $Visual = [string]$Scene.visual_description

    if (-not [string]::IsNullOrWhiteSpace($Text)) {
        Pass "Scene $N : voice_over non vide"
    }
    else {
        Fail "Scene $N : voice_over vide"
    }

    if (-not [string]::IsNullOrWhiteSpace($Visual)) {
        Pass "Scene $N : description visuelle non vide"
    }
    else {
        Fail "Scene $N : description visuelle vide"
    }

    $WordCount = [int]$Scene.word_count

    if ($WordCount -ge 12 -and $WordCount -le 30) {
        Pass "Scene $N : densité $WordCount mots"
    }
    else {
        Fail "Scene $N : densité hors plage : $WordCount mots"
    }

    $ActualCalculatedWords = @(
        ($Text -replace '[\r\n\t]+', ' ' -split '\s+' |
            Where-Object { $_ -and $_.Trim() -ne "" })
    ).Count

    if ([math]::Abs($ActualCalculatedWords - $WordCount) -le 1) {
        Pass "Scene $N : word_count cohérent"
    }
    else {
        Fail "Scene $N : word_count déclaré=$WordCount calculé=$ActualCalculatedWords"
    }

    $Duration = [double]$Scene.estimated_duration_seconds

    if ($Duration -ge 4 -and $Duration -le 13) {
        Pass "Scene $N : durée estimée $Duration s"
    }
    else {
        Fail "Scene $N : durée hors plage : $Duration s"
    }

    $ComputedRate = 0

    if ($Duration -gt 0) {
        $ComputedRate = ($ActualCalculatedWords / $Duration) * 60
    }

    if ($ComputedRate -ge 110 -and $ComputedRate -le 190) {
        Pass "Scene $N : débit estimé $([math]::Round($ComputedRate,1)) WPM"
    }
    else {
        Warn "Scene $N : débit estimé $([math]::Round($ComputedRate,1)) WPM — à examiner"
    }

    $Role = [string]$Scene.role

    if ($AllowedRoles -contains $Role) {
        Pass "Scene $N : rôle $Role"
    }
    else {
        Warn "Scene $N : rôle non standard '$Role'"
    }

    $Shot = [string]$Scene.shot_type

    if ($AllowedShotTypes -contains $Shot) {
        Pass "Scene $N : shot_type $Shot"
    }
    else {
        Fail "Scene $N : shot_type invalide $Shot"
    }

    $Motion = [string]$Scene.camera_motion

    if ($AllowedCameraMotion -contains $Motion) {
        Pass "Scene $N : camera_motion $Motion"
    }
    else {
        Fail "Scene $N : camera_motion invalide $Motion"
    }

    if ($null -ne $PreviousShot -and $PreviousShot -eq $Shot) {
        Fail "Scene $N : shot_type identique à la scène précédente"
    }

    $PreviousShot = $Shot

    if ($null -ne $PreviousVoice) {

        $A = ($PreviousVoice -replace '[^\p{L}\p{Nd}\s]', ' ' -replace '\s+', ' ').Trim().ToLowerInvariant()
        $B = ($Text -replace '[^\p{L}\p{Nd}\s]', ' ' -replace '\s+', ' ').Trim().ToLowerInvariant()

        if ($A -eq $B -and $A.Length -gt 0) {
            Fail "Scene $N : voice-over identique à la scène précédente"
        }
    }

    $PreviousVoice = $Text

    $TotalWords += $ActualCalculatedWords
    $ComputedDuration += $Duration
}

# ------------------------------------------------------------
# ROOT TOTALS
# ------------------------------------------------------------

$DeclaredTotal = [double]$Plan.total_estimated_duration_seconds

if ([math]::Abs($DeclaredTotal - $ComputedDuration) -le 0.25) {
    Pass "Durée totale cohérente : $DeclaredTotal s"
}
else {
    Fail "Durée totale incohérente : déclarée=$DeclaredTotal calculée=$ComputedDuration"
}

if ($DeclaredTotal -ge 30 -and $DeclaredTotal -le 90) {
    Pass "Durée totale dans la cible 30–90 s"
}
else {
    Fail "Durée totale hors cible : $DeclaredTotal s"
}

Write-Host ""
Write-Host "============================================================"
Write-Host "SCENE PLAN — RESULTAT"
Write-Host "============================================================"
Write-Host "PASS : $Passes"
Write-Host "FAIL : $Failures"
Write-Host ""

if ($Failures -eq 0) {
    Write-Host "SCENE PLAN QUALITY — PASS" -ForegroundColor Green
    exit 0
}
else {
    Write-Host "SCENE PLAN QUALITY — FAIL" -ForegroundColor Red
    exit 1
}
