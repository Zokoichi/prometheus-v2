param(
    [string]$Project = "C:\Projects\prometheus-v2"
)

$ErrorActionPreference = "Stop"

Write-Host ""
Write-Host "============================================================"
Write-Host " PROMETHEUS V2 — MEDIA PRODUCTION CONTRACT VALIDATOR V1.1"
Write-Host "============================================================"
Write-Host ""

$Failures = 0

function Pass($Message) {
    Write-Host "[PASS] $Message" -ForegroundColor Green
}

function Fail($Message) {
    Write-Host "[FAIL] $Message" -ForegroundColor Red
    $script:Failures++
}

function Check-JsonFile($Path) {

    if (-not (Test-Path -LiteralPath $Path)) {
        Fail "Missing: $Path"
        return $null
    }

    try {
        $Raw = Get-Content -LiteralPath $Path -Raw -Encoding UTF8
        $Obj = $Raw | ConvertFrom-Json

        Pass "Valid JSON: $Path"

        return $Obj
    }
    catch {
        Fail "Invalid JSON: $Path :: $($_.Exception.Message)"
        return $null
    }
}

function Require-Property($Object, $Name, $Context) {

    if ($null -eq $Object) {
        Fail "Cannot inspect '$Name' because object is null: $Context"
        return
    }

    if ($null -eq $Object.PSObject.Properties[$Name]) {
        Fail "Missing property '$Name' in $Context"
    }
    else {
        Pass "Property '$Name' present in $Context"
    }
}

function Require-SchemaProperty($Schema, $Name, $Context) {

    if ($null -eq $Schema.properties.PSObject.Properties[$Name]) {
        Fail "Schema property '$Name' missing in $Context"
    }
    else {
        Pass "Schema property '$Name' present in $Context"
    }
}

# ============================================================
# PATHS
# ============================================================

$ProfilePath = "$Project\config\media-production.json"

$ContractPaths = @(
    "$Project\contracts\media\voice-output-v1.json",
    "$Project\contracts\media\music-asset-v1.json",
    "$Project\contracts\media\sfx-asset-v1.json",
    "$Project\contracts\media\visual-asset-v1.json",
    "$Project\contracts\media\caption-plan-v1.json",
    "$Project\contracts\media\editing-blueprint-v1.json",
    "$Project\contracts\media\video-master-v1.json"
)

# ============================================================
# 1. JSON SYNTAX
# ============================================================

Write-Host "[VALIDATION] JSON files"

$Profile = Check-JsonFile $ProfilePath

$Contracts = @{}

foreach ($Path in $ContractPaths) {
    $Contracts[$Path] = Check-JsonFile $Path
}

# ============================================================
# 2. PRODUCTION PROFILE
# ============================================================

Write-Host ""
Write-Host "[VALIDATION] Production profile"

if ($Profile) {

    $RequiredProfileProperties = @(
        "schema_version",
        "profile_id",
        "delivery",
        "audio_master",
        "timeline",
        "quality",
        "render"
    )

    foreach ($Name in $RequiredProfileProperties) {
        Require-Property $Profile $Name "media-production.json"
    }

    if ($Profile.profile_id -eq "PROM-V2-SHORT-V1") {
        Pass "Profile ID = PROM-V2-SHORT-V1"
    }
    else {
        Fail "Unexpected profile ID: $($Profile.profile_id)"
    }

    if ($Profile.delivery.width -eq 1080) {
        Pass "Delivery width = 1080"
    }
    else {
        Fail "Delivery width must be 1080"
    }

    if ($Profile.delivery.height -eq 1920) {
        Pass "Delivery height = 1920"
    }
    else {
        Fail "Delivery height must be 1920"
    }

    if ($Profile.delivery.orientation -eq "VERTICAL") {
        Pass "Delivery orientation = VERTICAL"
    }
    else {
        Fail "Delivery orientation must be VERTICAL"
    }

    if ($Profile.delivery.video_codec -eq "H264") {
        Pass "Video codec = H264"
    }
    else {
        Fail "Video codec must be H264"
    }

    if ($Profile.delivery.audio_codec -eq "AAC") {
        Pass "Audio codec = AAC"
    }
    else {
        Fail "Audio codec must be AAC"
    }

    if ($Profile.delivery.audio_sample_rate_hz -eq 48000) {
        Pass "Audio sample rate = 48000 Hz"
    }
    else {
        Fail "Audio sample rate must be 48000 Hz"
    }

    if ($Profile.audio_master.loudness_standard -eq "EBU_R128") {
        Pass "Audio standard = EBU_R128"
    }
    else {
        Fail "Audio standard must be EBU_R128"
    }

    if ($Profile.render.engine -eq "FFMPEG") {
        Pass "Render engine = FFMPEG"
    }
    else {
        Fail "Render engine must be FFMPEG"
    }

    if ($Profile.render.normalization_mode -eq "TWO_PASS") {
        Pass "Audio normalization mode = TWO_PASS"
    }
    else {
        Fail "Audio normalization mode must be TWO_PASS"
    }
}

# ============================================================
# 3. CONTRACT ROOTS
# ============================================================

Write-Host ""
Write-Host "[VALIDATION] Contract roots"

foreach ($Entry in $Contracts.GetEnumerator()) {

    $Path = $Entry.Key
    $Schema = $Entry.Value

    if ($null -eq $Schema) {
        continue
    }

    Require-Property $Schema '$schema' $Path
    Require-Property $Schema '$id' $Path
    Require-Property $Schema 'title' $Path
    Require-Property $Schema 'type' $Path
    Require-Property $Schema 'properties' $Path

    if ($Schema.type -eq "object") {
        Pass "Root type = object: $Path"
    }
    else {
        Fail "Root type must be object: $Path"
    }
}

# ============================================================
# 4. REQUIRED CONTRACTS
# ============================================================

Write-Host ""
Write-Host "[VALIDATION] Required media contracts"

$ExpectedIds = @{
    "voice-output-v1.json"      = "prometheus://contracts/voice-output/v1"
    "music-asset-v1.json"       = "prometheus://contracts/music-asset/v1"
    "sfx-asset-v1.json"         = "prometheus://contracts/sfx-asset/v1"
    "visual-asset-v1.json"      = "prometheus://contracts/visual-asset/v1"
    "caption-plan-v1.json"      = "prometheus://contracts/caption-plan/v1"
    "editing-blueprint-v1.json" = "prometheus://contracts/editing-blueprint/v1"
    "video-master-v1.json"      = "prometheus://contracts/video-master/v1"
}

foreach ($Entry in $Contracts.GetEnumerator()) {

    $Path = $Entry.Key
    $Schema = $Entry.Value

    if ($null -eq $Schema) {
        continue
    }

    $FileName = Split-Path $Path -Leaf

    if ($ExpectedIds.ContainsKey($FileName)) {

        $ExpectedId = $ExpectedIds[$FileName]

        if ($Schema.'$id' -eq $ExpectedId) {
            Pass "Contract ID correct: $FileName"
        }
        else {
            Fail "Contract ID mismatch: $FileName :: expected '$ExpectedId', got '$($Schema.'$id')'"
        }
    }
}

# ============================================================
# 5. REQUIRED FIELDS BY CONTRACT
# ============================================================

Write-Host ""
Write-Host "[VALIDATION] Contract required fields"

$RequiredFields = @{
    "voice-output-v1.json" = @(
        "artifact_id",
        "voice",
        "provider",
        "content_type",
        "sample_rate_hz",
        "channels",
        "duration_seconds",
        "scene_number",
        "text_sha256"
    )

    "music-asset-v1.json" = @(
        "artifact_id",
        "content_type",
        "duration_seconds",
        "sample_rate_hz",
        "channels",
        "license"
    )

    "sfx-asset-v1.json" = @(
        "artifact_id",
        "content_type",
        "duration_seconds",
        "license"
    )

    "visual-asset-v1.json" = @(
        "artifact_id",
        "media_type",
        "width",
        "height",
        "content_type",
        "duration_seconds"
    )

    "caption-plan-v1.json" = @(
        "version",
        "language",
        "segments"
    )

    "editing-blueprint-v1.json" = @(
        "version",
        "profile_id",
        "duration_seconds",
        "timeline",
        "audio"
    )

    "video-master-v1.json" = @(
        "artifact_id",
        "content_type",
        "width",
        "height",
        "duration_seconds",
        "fps",
        "video_codec",
        "audio_codec",
        "audio_sample_rate_hz",
        "qa"
    )
}

foreach ($Entry in $Contracts.GetEnumerator()) {

    $Path = $Entry.Key
    $Schema = $Entry.Value

    if ($null -eq $Schema) {
        continue
    }

    $FileName = Split-Path $Path -Leaf

    foreach ($Field in $RequiredFields[$FileName]) {
        Require-SchemaProperty $Schema $Field $FileName
    }
}

# ============================================================
# 6. EDITING BLUEPRINT
# ============================================================

Write-Host ""
Write-Host "[VALIDATION] Editing Blueprint semantics"

$Blueprint = $Contracts["$Project\contracts\media\editing-blueprint-v1.json"]

if ($Blueprint) {

    if ($Blueprint.properties.timeline.minItems -ge 1) {
        Pass "Editing Blueprint requires at least one timeline segment"
    }
    else {
        Fail "Editing Blueprint timeline must require at least one segment"
    }

    $TimelineItems = $Blueprint.properties.timeline.items

    foreach ($Field in @(
        "segment_id",
        "start_seconds",
        "end_seconds",
        "scene_number",
        "visuals"
    )) {
        if ($null -ne $TimelineItems.required -and
            $TimelineItems.required -contains $Field) {
            Pass "Timeline requires '$Field'"
        }
        else {
            Fail "Timeline does not require '$Field'"
        }
    }

    $Audio = $Blueprint.properties.audio

    foreach ($Field in @(
        "voice_artifacts",
        "music",
        "master"
    )) {
        Require-SchemaProperty $Audio $Field "editing-blueprint.audio"
    }

    if ($Audio.properties.master.properties.target_lufs) {
        Pass "Audio master exposes target_lufs"
    }
    else {
        Fail "Audio master missing target_lufs"
    }

    if ($Audio.properties.master.properties.max_true_peak_dbtp) {
        Pass "Audio master exposes max_true_peak_dbtp"
    }
    else {
        Fail "Audio master missing max_true_peak_dbtp"
    }
}

# ============================================================
# 7. VIDEO MASTER
# ============================================================

Write-Host ""
Write-Host "[VALIDATION] Video Master"

$Master = $Contracts["$Project\contracts\media\video-master-v1.json"]

if ($Master) {

    if ($Master.properties.width.const -eq 1080) {
        Pass "Video Master width constrained to 1080"
    }
    else {
        Fail "Video Master width must be constrained to 1080"
    }

    if ($Master.properties.height.const -eq 1920) {
        Pass "Video Master height constrained to 1920"
    }
    else {
        Fail "Video Master height must be constrained to 1920"
    }

    if ($Master.properties.content_type.enum -contains "video/mp4") {
        Pass "Video Master content type = video/mp4"
    }
    else {
        Fail "Video Master must allow video/mp4"
    }

    if ($Master.properties.video_codec.enum -contains "H264") {
        Pass "Video Master codec = H264"
    }
    else {
        Fail "Video Master must allow H264"
    }

    if ($Master.properties.audio_codec.enum -contains "AAC") {
        Pass "Video Master audio codec = AAC"
    }
    else {
        Fail "Video Master must allow AAC"
    }

    if ($Master.properties.audio_sample_rate_hz.const -eq 48000) {
        Pass "Video Master audio sample rate = 48000 Hz"
    }
    else {
        Fail "Video Master audio sample rate must be 48000 Hz"
    }

    if ($Master.properties.qa.properties.status.enum -contains "PASS") {
        Pass "Video Master QA gate supports PASS"
    }
    else {
        Fail "Video Master QA gate missing PASS state"
    }
}

# ============================================================
# 8. SECURITY
# ============================================================

Write-Host ""
Write-Host "[VALIDATION] Secret scan"

$SecretPatterns = @(
    "AWS_SECRET_ACCESS_KEY",
    "AWS_ACCESS_KEY_ID",
    "SECRET_KEY",
    "PASSWORD=",
    "API_KEY",
    "TOKEN="
)

$ScanFiles = @(
    "$Project\config\media-production.json"
) + $ContractPaths

foreach ($File in $ScanFiles) {

    if (-not (Test-Path $File)) {
        continue
    }

    $Content = Get-Content -LiteralPath $File -Raw -Encoding UTF8

    foreach ($Pattern in $SecretPatterns) {

        if ($Content -match [regex]::Escape($Pattern)) {
            Fail "Potential secret material detected: $(Split-Path $File -Leaf) :: $Pattern"
        }
    }
}

if ($Failures -eq 0) {
    Pass "No secret material detected"
}

# ============================================================
# RESULT
# ============================================================

Write-Host ""
Write-Host "============================================================"

if ($Failures -eq 0) {

    Write-Host " MEDIA PRODUCTION FOUNDATION V1.1 — VALIDATION PASS" -ForegroundColor Green
    Write-Host "============================================================"
    exit 0
}
else {

    Write-Host " MEDIA PRODUCTION FOUNDATION V1.1 — VALIDATION FAIL" -ForegroundColor Red
    Write-Host "Failures: $Failures"
    Write-Host "============================================================"
    exit 1
}
