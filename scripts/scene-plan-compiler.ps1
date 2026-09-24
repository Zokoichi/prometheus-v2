[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [ValidateSet("compile", "validate")]
    [string]$Operation,

    [Parameter(Mandatory = $true)]
    [string]$InputFile,

    [Parameter(Mandatory = $false)]
    [string]$OutputFile
)

$ErrorActionPreference = "Stop"

$CompilerName = "SCENE_PLAN_COMPILER"
$CompilerVersion = "1.0.0"
$ContractName = "SCENE_PLAN_OUTPUT"
$ContractVersion = 1

$TargetWordsPerSecond = 2.5
$MinSceneSeconds = 4.0
$MaxSceneSeconds = 13.0
$MinScenes = 7
$MaxScenes = 12

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

function Repair-Mojibake {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Text
    )

    # The SCRIPT V3 forensic tests established this exact
    # deterministic repair chain for the observed corruption:
    #
    # UTF-8 bytes interpreted as Latin-1 text
    # -> encode Latin-1
    # -> decode UTF-8
    #
    # We only apply it when characteristic mojibake markers
    # are actually present.

    if ($Text -notmatch 'Ã|Â|â€|â€™|â€œ|â€|â€“|â€”|â€¦') {
        return $Text
    }

    try {
        $Latin1 = [System.Text.Encoding]::GetEncoding(
            28591,
            [System.Text.EncoderExceptionFallback]::new(),
            [System.Text.DecoderExceptionFallback]::new()
        )

        $Utf8 = [System.Text.UTF8Encoding]::new(
            $false,
            $true
        )

        $Bytes = $Latin1.GetBytes($Text)
        $Repaired = $Utf8.GetString($Bytes)

        return $Repaired
    }
    catch {
        throw "Encoding repair failed: $($_.Exception.Message)"
    }
}

function Get-WordCount {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Text
    )

    $Clean = $Text.Trim()

    if ([string]::IsNullOrWhiteSpace($Clean)) {
        return 0
    }

    return @(
        $Clean -split '\s+' |
        Where-Object { $_ -ne "" }
    ).Count
}

function Get-SceneDuration {
    param(
        [Parameter(Mandatory = $true)]
        [int]$WordCount
    )

    $Raw = $WordCount / $TargetWordsPerSecond

    # Deterministic rounding to one decimal.
    $Rounded = [Math]::Round(
        $Raw,
        1,
        [MidpointRounding]::AwayFromZero
    )

    if ($Rounded -lt $MinSceneSeconds) {
        return $MinSceneSeconds
    }

    if ($Rounded -gt $MaxSceneSeconds) {
        return $MaxSceneSeconds
    }

    return $Rounded
}

function Get-ShotType {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Role,

        [Parameter(Mandatory = $true)]
        [int]$SceneNumber
    )

    switch ($Role.ToLowerInvariant()) {
        "hook" {
            return "CLOSE_UP"
        }

        "context" {
            return "WIDE"
        }

        "revelation" {
            return "WIDE"
        }

        "conclusion" {
            return "WIDE"
        }

        default {
            $Sequence = @(
                "MEDIUM",
                "CLOSE_UP",
                "MEDIUM",
                "EXTREME_WIDE"
            )

            return $Sequence[
                (($SceneNumber - 1) % $Sequence.Count)
            ]
        }
    }
}

function Get-CameraMotion {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Role,

        [Parameter(Mandatory = $true)]
        [int]$SceneNumber
    )

    switch ($Role.ToLowerInvariant()) {
        "hook" {
            return "ZOOM_IN"
        }

        "context" {
            return "PAN_LEFT"
        }

        "revelation" {
            return "ZOOM_OUT"
        }

        "conclusion" {
            return "STATIC"
        }

        default {
            $Sequence = @(
                "STATIC",
                "PAN_RIGHT",
                "ZOOM_IN",
                "STATIC",
                "PAN_LEFT"
            )

            return $Sequence[
                (($SceneNumber - 1) % $Sequence.Count)
            ]
        }
    }
}

function Assert-ScenePlan {
    param(
        [Parameter(Mandatory = $true)]
        $Plan
    )

    if ([string]::IsNullOrWhiteSpace([string]$Plan.title)) {
        throw "VALIDATION: title absent."
    }

    $Scenes = @($Plan.scenes)

    if ($Scenes.Count -lt $MinScenes -or $Scenes.Count -gt $MaxScenes) {
        throw "VALIDATION: scene_count=$($Scenes.Count), attendu $MinScenes-$MaxScenes."
    }

    if ([int]$Plan.scene_count -ne $Scenes.Count) {
        throw "VALIDATION: scene_count incoherent."
    }

    $CalculatedTotal = 0.0
    $PreviousShot = $null

    foreach ($Scene in $Scenes) {

        $Required = @(
            "scene_number",
            "role",
            "voice_over",
            "visual_description",
            "word_count",
            "estimated_duration_seconds",
            "shot_type",
            "camera_motion"
        )

        foreach ($Field in $Required) {
            if ($null -eq $Scene.$Field) {
                throw "VALIDATION: champ absent '$Field' scène $($Scene.scene_number)."
            }
        }

        $Words = [int]$Scene.word_count
        $Duration = [double]$Scene.estimated_duration_seconds

        if ($Words -lt 12 -or $Words -gt 30) {
            throw "VALIDATION: word_count=$Words scène $($Scene.scene_number)."
        }

        if ($Duration -lt $MinSceneSeconds -or $Duration -gt $MaxSceneSeconds) {
            throw "VALIDATION: duration=$Duration scène $($Scene.scene_number)."
        }

        if ($AllowedShotTypes -notcontains [string]$Scene.shot_type) {
            throw "VALIDATION: shot_type invalide scène $($Scene.scene_number)."
        }

        if ($AllowedCameraMotion -notcontains [string]$Scene.camera_motion) {
            throw "VALIDATION: camera_motion invalide scène $($Scene.scene_number)."
        }

        if ($null -ne $PreviousShot -and
            $PreviousShot -eq [string]$Scene.shot_type) {

            throw "VALIDATION: shot_type identique consécutif aux scènes précédentes."
        }

        $PreviousShot = [string]$Scene.shot_type
        $CalculatedTotal += $Duration
    }

    if ($CalculatedTotal -lt 30 -or $CalculatedTotal -gt 90) {
        throw "VALIDATION: durée totale=$CalculatedTotal secondes."
    }

    $DeclaredTotal = [double]$Plan.total_estimated_duration_seconds

    if ([Math]::Abs($DeclaredTotal - $CalculatedTotal) -gt 0.0001) {
        throw "VALIDATION: total_estimated_duration_seconds incoherent."
    }

    return $true
}

# ------------------------------------------------------------
# INPUT
# ------------------------------------------------------------

if (-not (Test-Path $InputFile)) {
    throw "Input introuvable : $InputFile"
}

$Raw = Get-Content -LiteralPath $InputFile -Raw -Encoding UTF8

try {
    $InputJson = $Raw | ConvertFrom-Json
}
catch {
    throw "INPUT INVALID: JSON illisible."
}

# ------------------------------------------------------------
# NORMALISATION
# ------------------------------------------------------------

$Title = Repair-Mojibake ([string]$InputJson.title)

$InputScenes = @($InputJson.scenes)

if ($InputScenes.Count -lt $MinScenes -or
    $InputScenes.Count -gt $MaxScenes) {

    throw "INPUT INVALID: nombre de scènes=$($InputScenes.Count), attendu $MinScenes-$MaxScenes."
}

$CompiledScenes = @()

foreach ($InputScene in $InputScenes) {

    $SceneNumber = [int]$InputScene.scene_number
    $Role = Repair-Mojibake ([string]$InputScene.role)
    $VoiceOver = Repair-Mojibake ([string]$InputScene.voice_over)
    $VisualDescription = Repair-Mojibake ([string]$InputScene.visual_description)

    if ([string]::IsNullOrWhiteSpace($VoiceOver)) {
        throw "INPUT INVALID: voice_over vide scène $SceneNumber."
    }

    if ([string]::IsNullOrWhiteSpace($VisualDescription)) {
        throw "INPUT INVALID: visual_description vide scène $SceneNumber."
    }

    $WordCount = Get-WordCount $VoiceOver
    $Duration = Get-SceneDuration $WordCount

    if ($WordCount -lt 12 -or $WordCount -gt 30) {
        throw "INPUT/COMPILER: scène $SceneNumber contient $WordCount mots; contrat = 12-30."
    }

    $ShotType = Get-ShotType `
        -Role $Role `
        -SceneNumber $SceneNumber

    $CameraMotion = Get-CameraMotion `
        -Role $Role `
        -SceneNumber $SceneNumber

    $CompiledScenes += [ordered]@{
        scene_number = $SceneNumber
        role = $Role
        voice_over = $VoiceOver
        visual_description = $VisualDescription
        word_count = $WordCount
        estimated_duration_seconds = $Duration
        shot_type = $ShotType
        camera_motion = $CameraMotion
    }
}

# ------------------------------------------------------------
# SECONDARY GRAMMAR PASS
# ------------------------------------------------------------

for ($i = 1; $i -lt $CompiledScenes.Count; $i++) {

    if ($CompiledScenes[$i].shot_type -eq
        $CompiledScenes[$i - 1].shot_type) {

        $Fallback = $AllowedShotTypes |
            Where-Object {
                $_ -ne $CompiledScenes[$i - 1].shot_type
            } |
            Select-Object -First 1

        $CompiledScenes[$i].shot_type = $Fallback
    }
}

# ------------------------------------------------------------
# TOTAL
# ------------------------------------------------------------

$TotalDuration = 0.0

foreach ($Scene in $CompiledScenes) {
    $TotalDuration += [double]$Scene.estimated_duration_seconds
}

$TotalDuration = [Math]::Round(
    $TotalDuration,
    1,
    [MidpointRounding]::AwayFromZero
)

$Plan = [ordered]@{
    compiler = $CompilerName
    compiler_version = $CompilerVersion
    contract = $ContractName
    contract_version = $ContractVersion
    title = $Title
    scene_count = $CompiledScenes.Count
    total_estimated_duration_seconds = $TotalDuration
    scenes = $CompiledScenes
}

$PlanObject = [pscustomobject]$Plan

# ------------------------------------------------------------
# VALIDATION
# ------------------------------------------------------------

Assert-ScenePlan $PlanObject | Out-Null

# ------------------------------------------------------------
# VALIDATE ONLY
# ------------------------------------------------------------

if ($Operation -eq "validate") {

    $Canonical = $PlanObject |
        ConvertTo-Json -Depth 20 -Compress

    $Bytes = [System.Text.Encoding]::UTF8.GetBytes($Canonical)

    $Sha = [System.Security.Cryptography.SHA256]::Create()

    try {
        $HashBytes = $Sha.ComputeHash($Bytes)
    }
    finally {
        $Sha.Dispose()
    }

    $Hash = (
        [BitConverter]::ToString($HashBytes)
    ).Replace("-", "")

    [pscustomobject]@{
        status = "VALID"
        compiler = $CompilerName
        version = $CompilerVersion
        scene_count = $PlanObject.scene_count
        duration_seconds = $PlanObject.total_estimated_duration_seconds
        canonical_sha256 = $Hash
    }

    exit 0
}

# ------------------------------------------------------------
# COMPILE OUTPUT
# ------------------------------------------------------------

if ([string]::IsNullOrWhiteSpace($OutputFile)) {
    throw "compile nécessite -OutputFile."
}

$OutputDirectory = Split-Path -Parent (
    [IO.Path]::GetFullPath($OutputFile)
)

if (-not (Test-Path $OutputDirectory)) {
    New-Item -ItemType Directory -Path $OutputDirectory -Force | Out-Null
}

$CanonicalJson = $PlanObject |
    ConvertTo-Json -Depth 20 -Compress

[IO.File]::WriteAllText(
    [IO.Path]::GetFullPath($OutputFile),
    $CanonicalJson,
    [System.Text.UTF8Encoding]::new($false)
)

$OutputSha = (
    Get-FileHash `
        -LiteralPath $OutputFile `
        -Algorithm SHA256
).Hash.ToUpperInvariant()

[pscustomobject]@{
    status = "COMPILED"
    compiler = $CompilerName
    version = $CompilerVersion
    contract = $ContractName
    contract_version = $ContractVersion
    scene_count = $PlanObject.scene_count
    duration_seconds = $PlanObject.total_estimated_duration_seconds
    output_file = [IO.Path]::GetFullPath($OutputFile)
    sha256 = $OutputSha
}
