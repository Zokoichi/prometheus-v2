$ErrorActionPreference = "Stop"

$ProjectRoot = "C:\Projects\prometheus-v2"
$Workspace   = Join-Path $ProjectRoot "tests\workspace-0e63"

$AwsImage = "public.ecr.aws/aws-cli/aws-cli:2.36.42"
$Network  = "prometheus-v2-network"
$Bucket   = "prometheus-v2-test"
$Endpoint = "http://prometheus-v2-seaweedfs:8333"

$RunA = "RUN-20260910-0E63-A"
$RunB = "RUN-20260910-0E63-B"

$StageA = "STG-20260910-0E63-A-SCRIPT"
$StageB = "STG-20260910-0E63-B-SCRIPT"

$ArtifactDbOrphan       = "ART-20260910-0E63-DB-ORPHAN"
$ArtifactPhysicalOrphan = "ART-20260910-0E63-PHYSICAL-ORPHAN"

$DbOrphanKey       = "run/$RunA/script/db-orphan.txt"
$PhysicalOrphanKey = "run/$RunB/script/physical-orphan.txt"

$DbOrphanFile       = Join-Path $Workspace "db-orphan.txt"
$PhysicalOrphanFile = Join-Path $Workspace "physical-orphan.txt"

function Get-EnvValue {
    param([string]$Name)

    $envPath = Join-Path $ProjectRoot ".env"

    if (-not (Test-Path $envPath)) {
        throw ".env introuvable."
    }

    $line = Get-Content $envPath |
        Where-Object {
            $_ -match ("^\s*" + [regex]::Escape($Name) + "\s*=")
        } |
        Select-Object -First 1

    if (-not $line) {
        throw "Variable absente du .env : $Name"
    }

    return ($line -replace ("^\s*" + [regex]::Escape($Name) + "\s*=\s*"), "").Trim()
}

$AccessKey = Get-EnvValue "SEAWEEDFS_ACCESS_KEY"
$SecretKey = Get-EnvValue "SEAWEEDFS_SECRET_KEY"

if ([string]::IsNullOrWhiteSpace($AccessKey)) {
    throw "SEAWEEDFS_ACCESS_KEY vide."
}

if ([string]::IsNullOrWhiteSpace($SecretKey)) {
    throw "SEAWEEDFS_SECRET_KEY vide."
}

function Invoke-Psql {
    param([string]$Sql)

    $result = & docker exec prometheus-v2-postgres `
        psql `
        -U prometheus `
        -d prometheus_v2 `
        -v ON_ERROR_STOP=1 `
        -t `
        -A `
        -c $Sql 2>&1

    if ($LASTEXITCODE -ne 0) {
        throw "PostgreSQL a échoué : $($result -join "`n")"
    }

    return (($result -join "`n").Trim())
}

# IMPORTANT :
# L'image AWS CLI utilise déjà "aws" comme ENTRYPOINT.
# Le premier argument après l'image doit donc être directement
# "s3api", "s3", etc.
function Invoke-Aws {
    param(
        [Parameter(Mandatory = $true)]
        [string[]]$AwsArgs
    )

    $dockerArgs = @(
        "run",
        "--rm",
        "--network", $Network,
        "-e", "AWS_ACCESS_KEY_ID=$AccessKey",
        "-e", "AWS_SECRET_ACCESS_KEY=$SecretKey",
        "-e", "AWS_DEFAULT_REGION=us-east-1",
        $AwsImage
    ) + $AwsArgs + @(
        "--endpoint-url", $Endpoint
    )

    $previousPreference = $ErrorActionPreference

    try {
        $ErrorActionPreference = "Continue"
        $result = & docker @dockerArgs 2>&1
        $exitCode = $LASTEXITCODE
    }
    finally {
        $ErrorActionPreference = $previousPreference
    }

    if ($exitCode -ne 0) {
        throw "AWS CLI a échoué avec le code $exitCode : $($result -join "`n")"
    }

    return @($result)
}

function Invoke-AwsExpectedFailure {
    param(
        [Parameter(Mandatory = $true)]
        [string[]]$AwsArgs
    )

    $dockerArgs = @(
        "run",
        "--rm",
        "--network", $Network,
        "-e", "AWS_ACCESS_KEY_ID=$AccessKey",
        "-e", "AWS_SECRET_ACCESS_KEY=$SecretKey",
        "-e", "AWS_DEFAULT_REGION=us-east-1",
        $AwsImage
    ) + $AwsArgs + @(
        "--endpoint-url", $Endpoint
    )

    $previousPreference = $ErrorActionPreference

    try {
        $ErrorActionPreference = "Continue"
        $result = & docker @dockerArgs 2>&1
        $exitCode = $LASTEXITCODE
    }
    finally {
        $ErrorActionPreference = $previousPreference
    }

    return [PSCustomObject]@{
        ExitCode = $exitCode
        Output   = @($result)
    }
}

function Normalize-GuardResult {
    param([string]$Raw)

    $text = ($Raw -replace "`r", "" -replace "`n", "").Trim()

    if ([string]::IsNullOrWhiteSpace($text)) {
        throw "Guard : résultat vide."
    }

    $parts = $text -split "\|", 3

    if ($parts.Count -lt 3) {
        throw "Guard : format inattendu : $text"
    }

    $allowed = switch ($parts[0].Trim().ToLowerInvariant()) {
        "t"     { $true }
        "true"  { $true }
        "f"     { $false }
        "false" { $false }
        default {
            throw "Guard : valeur booléenne inattendue : $($parts[0])"
        }
    }

    [PSCustomObject]@{
        Allowed      = $allowed
        ErrorCode    = $parts[1].Trim()
        ErrorMessage = $parts[2].Trim()
    }
}

function Test-S3ObjectPresent {
    param([string]$Key)

    $result = Invoke-Aws @(
        "s3api",
        "head-object",
        "--bucket", $Bucket,
        "--key", $Key,
        "--query", "ContentLength",
        "--output", "text"
    )

    $size = (($result -join "`n").Trim())

    if ([string]::IsNullOrWhiteSpace($size)) {
        throw "Taille S3 introuvable : $Key"
    }

    return [int64]$size
}

function Test-S3ObjectAbsent {
    param([string]$Key)

    $result = Invoke-AwsExpectedFailure @(
        "s3api",
        "head-object",
        "--bucket", $Bucket,
        "--key", $Key
    )

    if ($result.ExitCode -eq 0) {
        throw "Objet S3 présent alors qu'il devrait être absent : $Key"
    }

    return $true
}

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "PROMETHEUS V2 - PHASE 0E.6.3" -ForegroundColor Cyan
Write-Host "CRASH / ORPHAN RECOVERY" -ForegroundColor Cyan
Write-Host "TEST COMPLET - VERSION 3" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# ============================================================
# 1
# ============================================================

Write-Host "[1] CREDENTIALS S3..." -ForegroundColor Yellow

Write-Host "Access key : PRESENT"
Write-Host "Secret key : PRESENT"
Write-Host "Credentials : OK" -ForegroundColor Green

# ============================================================
# 2
# ============================================================

Write-Host ""
Write-Host "[2] PRECHECK INFRA..." -ForegroundColor Yellow

$postgres = docker inspect prometheus-v2-postgres --format "{{.State.Status}}" 2>$null
$seaweed  = docker inspect prometheus-v2-seaweedfs --format "{{.State.Status}}" 2>$null

if ($postgres -ne "running") {
    throw "PostgreSQL n'est pas running."
}

if ($seaweed -ne "running") {
    throw "SeaweedFS n'est pas running."
}

$guardCount = Invoke-Psql @"
SELECT COUNT(*)
FROM pg_proc
WHERE proname = 'validate_stage_artifacts';
"@

if ([int]$guardCount -ne 1) {
    throw "Artifact Integrity Guard absent."
}

Write-Host "PostgreSQL : PRESENT" -ForegroundColor Green
Write-Host "SeaweedFS : PRESENT" -ForegroundColor Green
Write-Host "Artifact Guard : PRESENT" -ForegroundColor Green

# ============================================================
# 3
# ============================================================

Write-Host ""
Write-Host "[3] PREPARATION WORKSPACE..." -ForegroundColor Yellow

if (Test-Path $Workspace) {
    Remove-Item $Workspace -Recurse -Force
}

New-Item -ItemType Directory -Path $Workspace -Force | Out-Null

Write-Host "Workspace : OK" -ForegroundColor Green

# ============================================================
# 4
# ============================================================

Write-Host ""
Write-Host "[4] VERIFICATION BUCKET TEST..." -ForegroundColor Yellow

$listBuckets = Invoke-Aws @(
    "s3api",
    "list-buckets",
    "--query", "Buckets[].Name",
    "--output", "text"
)

$bucketNames = (($listBuckets -join " ") -split "\s+") |
    Where-Object { -not [string]::IsNullOrWhiteSpace($_) }

if ($bucketNames -notcontains $Bucket) {

    Invoke-Aws @(
        "s3api",
        "create-bucket",
        "--bucket", $Bucket
    ) | Out-Null

    Write-Host "Bucket créé : $Bucket" -ForegroundColor Green
}
else {
    Write-Host "Bucket existant : $Bucket" -ForegroundColor Green
}

# ============================================================
# 5
# ============================================================

Write-Host ""
Write-Host "[5] NETTOYAGE CIBLE..." -ForegroundColor Yellow

Invoke-Psql @"
DELETE FROM production_run
WHERE run_id IN ('$RunA', '$RunB');
"@ | Out-Null

foreach ($key in @(
    $DbOrphanKey,
    $PhysicalOrphanKey
)) {
    $delete = Invoke-AwsExpectedFailure @(
        "s3api",
        "delete-object",
        "--bucket", $Bucket,
        "--key", $key
    )

    if ($delete.ExitCode -eq 0) {
        Write-Host "Objet supprimé : $key"
    }
}

Write-Host "Cleanup ciblé : OK" -ForegroundColor Green

# ============================================================
# 6
# ============================================================

Write-Host ""
Write-Host "[6] CREATION DES RUNS..." -ForegroundColor Yellow

Invoke-Psql @"
INSERT INTO production_run (
    run_id,
    project_id,
    status,
    current_stage,
    input_json,
    output_json
)
VALUES
(
    '$RunA',
    'PROJECT-TEST-0E63-A',
    'VALIDATED',
    'SCRIPT',
    '{}'::jsonb,
    '{}'::jsonb
),
(
    '$RunB',
    'PROJECT-TEST-0E63-B',
    'VALIDATED',
    'SCRIPT',
    '{}'::jsonb,
    '{}'::jsonb
);
"@ | Out-Null

Write-Host "2 Runs : OK" -ForegroundColor Green

# ============================================================
# 7
# ============================================================

Write-Host ""
Write-Host "[7] CREATION DES ARTIFACTS..." -ForegroundColor Yellow

Set-Content `
    -Path $DbOrphanFile `
    -Value "PROMETHEUS-V2-0E63-DB-ORPHAN-RECOVERY" `
    -NoNewline `
    -Encoding utf8

Set-Content `
    -Path $PhysicalOrphanFile `
    -Value "PROMETHEUS-V2-0E63-PHYSICAL-ORPHAN-DETECTION" `
    -NoNewline `
    -Encoding utf8

$DbOrphanHash = (Get-FileHash $DbOrphanFile -Algorithm SHA256).Hash.ToUpperInvariant()
$PhysicalOrphanHash = (Get-FileHash $PhysicalOrphanFile -Algorithm SHA256).Hash.ToUpperInvariant()

$DbOrphanSize = (Get-Item $DbOrphanFile).Length
$PhysicalOrphanSize = (Get-Item $PhysicalOrphanFile).Length

Invoke-Psql @"
INSERT INTO artifact_registry (
    artifact_id,
    run_id,
    stage,
    artifact_type,
    object_key,
    content_type,
    size_bytes,
    sha256,
    version,
    status,
    metadata_json
)
VALUES (
    '$ArtifactDbOrphan',
    '$RunA',
    'SCRIPT',
    'TEXT',
    '$DbOrphanKey',
    'text/plain',
    $DbOrphanSize,
    '$DbOrphanHash',
    1,
    'REGISTERED',
    jsonb_build_object(
        'test', '0E6.3',
        'case', 'DB_ORPHAN'
    )
);
"@ | Out-Null

Write-Host "Artifact DB orphan : REGISTERED" -ForegroundColor Green

# ============================================================
# 8
# ============================================================

Write-Host ""
Write-Host "[8] CAS A - DB PRESENT / S3 ABSENT..." -ForegroundColor Yellow

Test-S3ObjectAbsent $DbOrphanKey | Out-Null

Write-Host "DB record : PRESENT" -ForegroundColor Green
Write-Host "S3 object : ABSENT" -ForegroundColor Green
Write-Host "Orphelin logique : DETECTE" -ForegroundColor Green

# ============================================================
# 9
# ============================================================

Write-Host ""
Write-Host "[9] CREATION STAGE A..." -ForegroundColor Yellow

Invoke-Psql @"
INSERT INTO production_stage (
    stage_id,
    run_id,
    stage_name,
    stage_order,
    status,
    attempt,
    idempotency_key,
    input_artifact_ids
)
VALUES (
    '$StageA',
    '$RunA',
    'SCRIPT',
    1,
    'PENDING',
    1,
    '${RunA}:SCRIPT:1',
    jsonb_build_array('$ArtifactDbOrphan')
);
"@ | Out-Null

Write-Host "Stage A : OK" -ForegroundColor Green

# ============================================================
# 10
# ============================================================

Write-Host ""
Write-Host "[10] GUARD - REGISTERED DOIT ETRE REFUSE..." -ForegroundColor Yellow

$guardA1 = Normalize-GuardResult (
    Invoke-Psql "SELECT * FROM validate_stage_artifacts('$StageA');"
)

Write-Host "Resultat : $($guardA1.Allowed)|$($guardA1.ErrorCode)|$($guardA1.ErrorMessage)"

if ($guardA1.Allowed) {
    throw "FAUX SUCCES : REGISTERED a été autorisé."
}

if ($guardA1.ErrorCode -ne "ARTIFACT_NOT_VALIDATED") {
    throw "Code inattendu : $($guardA1.ErrorCode)"
}

Write-Host "REGISTERED : REFUS CONFIRME" -ForegroundColor Green

# ============================================================
# 11
# ============================================================

Write-Host ""
Write-Host "[11] RECOVERY - UPLOAD ARTIFACT..." -ForegroundColor Yellow

$dockerArgs = @(
    "run",
    "--rm",
    "--network", $Network,
    "-v", "${Workspace}:/workspace",
    "-e", "AWS_ACCESS_KEY_ID=$AccessKey",
    "-e", "AWS_SECRET_ACCESS_KEY=$SecretKey",
    "-e", "AWS_DEFAULT_REGION=us-east-1",
    $AwsImage,
    "s3",
    "cp",
    "/workspace/db-orphan.txt",
    "s3://$Bucket/$DbOrphanKey",
    "--endpoint-url",
    $Endpoint
)

$result = & docker @dockerArgs 2>&1

if ($LASTEXITCODE -ne 0) {
    throw "Upload recovery échoué : $($result -join "`n")"
}

Write-Host "Upload recovery : OK" -ForegroundColor Green

# ============================================================
# 12
# ============================================================

Write-Host ""
Write-Host "[12] VERIFICATION OBJET RECUPERE..." -ForegroundColor Yellow

$recoveredSize = Test-S3ObjectPresent $DbOrphanKey

if ($recoveredSize -ne $DbOrphanSize) {
    throw "Taille recovery incorrecte."
}

Write-Host "Objet S3 : PRESENT" -ForegroundColor Green
Write-Host "Taille : $recoveredSize" -ForegroundColor Green

# ============================================================
# 13
# ============================================================

Write-Host ""
Write-Host "[13] STORED DOIT ENCORE ETRE REFUSE..." -ForegroundColor Yellow

Invoke-Psql @"
UPDATE artifact_registry
SET
    status = 'STORED',
    updated_at = NOW()
WHERE artifact_id = '$ArtifactDbOrphan';
"@ | Out-Null

$guardA2 = Normalize-GuardResult (
    Invoke-Psql "SELECT * FROM validate_stage_artifacts('$StageA');"
)

Write-Host "Resultat : $($guardA2.Allowed)|$($guardA2.ErrorCode)|$($guardA2.ErrorMessage)"

if ($guardA2.Allowed) {
    throw "FAUX SUCCES : STORED a été autorisé."
}

if ($guardA2.ErrorCode -ne "ARTIFACT_NOT_VALIDATED") {
    throw "Code inattendu : $($guardA2.ErrorCode)"
}

Write-Host "STORED : REFUS CONFIRME" -ForegroundColor Green

# ============================================================
# 14
# ============================================================

Write-Host ""
Write-Host "[14] VALIDATION FINALE ARTIFACT..." -ForegroundColor Yellow

Invoke-Psql @"
UPDATE artifact_registry
SET
    status = 'VALIDATING',
    updated_at = NOW()
WHERE artifact_id = '$ArtifactDbOrphan';
"@ | Out-Null

Invoke-Psql @"
UPDATE artifact_registry
SET
    status = 'VALIDATED',
    size_bytes = $DbOrphanSize,
    sha256 = '$DbOrphanHash',
    updated_at = NOW()
WHERE artifact_id = '$ArtifactDbOrphan';
"@ | Out-Null

$artifactState = Invoke-Psql @"
SELECT status || '|' || size_bytes || '|' || sha256
FROM artifact_registry
WHERE artifact_id = '$ArtifactDbOrphan';
"@

Write-Host "Artifact : $artifactState" -ForegroundColor Green

if ($artifactState -ne "VALIDATED|$DbOrphanSize|$DbOrphanHash") {
    throw "Etat final artifact incorrect."
}

# ============================================================
# 15
# ============================================================

Write-Host ""
Write-Host "[15] GUARD GLOBAL APRES RECOVERY..." -ForegroundColor Yellow

$guardA3 = Normalize-GuardResult (
    Invoke-Psql "SELECT * FROM validate_stage_artifacts('$StageA');"
)

Write-Host "Resultat : $($guardA3.Allowed)|$($guardA3.ErrorCode)|$($guardA3.ErrorMessage)"

if (-not $guardA3.Allowed) {
    throw "Recovery terminée mais Guard refuse."
}

Write-Host "Recovery : AUTORISATION CONFIRMEE" -ForegroundColor Green

# ============================================================
# 16
# ============================================================

Write-Host ""
Write-Host "[16] CAS B - ORPHELIN PHYSIQUE S3..." -ForegroundColor Yellow

$dockerArgs = @(
    "run",
    "--rm",
    "--network", $Network,
    "-v", "${Workspace}:/workspace",
    "-e", "AWS_ACCESS_KEY_ID=$AccessKey",
    "-e", "AWS_SECRET_ACCESS_KEY=$SecretKey",
    "-e", "AWS_DEFAULT_REGION=us-east-1",
    $AwsImage,
    "s3",
    "cp",
    "/workspace/physical-orphan.txt",
    "s3://$Bucket/$PhysicalOrphanKey",
    "--endpoint-url",
    $Endpoint
)

$result = & docker @dockerArgs 2>&1

if ($LASTEXITCODE -ne 0) {
    throw "Création orphelin physique échouée : $($result -join "`n")"
}

Write-Host "Objet physique : CREE" -ForegroundColor Green

$physicalSize = Test-S3ObjectPresent $PhysicalOrphanKey

if ($physicalSize -ne $PhysicalOrphanSize) {
    throw "Taille objet physique incorrecte."
}

# ============================================================
# 17
# ============================================================

Write-Host ""
Write-Host "[17] ABSENCE DB..." -ForegroundColor Yellow

$physicalDbCount = Invoke-Psql @"
SELECT COUNT(*)
FROM artifact_registry
WHERE artifact_id = '$ArtifactPhysicalOrphan';
"@

if ([int]$physicalDbCount -ne 0) {
    throw "Artifact physique possède un enregistrement DB inattendu."
}

Write-Host "DB record : ABSENT" -ForegroundColor Green
Write-Host "S3 object : PRESENT" -ForegroundColor Green

# ============================================================
# 18
# ============================================================

Write-Host ""
Write-Host "[18] STAGE B REFERENCE ARTIFACT ABSENT..." -ForegroundColor Yellow

Invoke-Psql @"
INSERT INTO production_stage (
    stage_id,
    run_id,
    stage_name,
    stage_order,
    status,
    attempt,
    idempotency_key,
    input_artifact_ids
)
VALUES (
    '$StageB',
    '$RunB',
    'SCRIPT',
    1,
    'PENDING',
    1,
    '${RunB}:SCRIPT:1',
    jsonb_build_array('$ArtifactPhysicalOrphan')
);
"@ | Out-Null

$guardB = Normalize-GuardResult (
    Invoke-Psql "SELECT * FROM validate_stage_artifacts('$StageB');"
)

Write-Host "Resultat : $($guardB.Allowed)|$($guardB.ErrorCode)|$($guardB.ErrorMessage)"

if ($guardB.Allowed) {
    throw "FAUX SUCCES : artifact absent accepté."
}

if ($guardB.ErrorCode -ne "ARTIFACT_NOT_FOUND") {
    throw "Code inattendu : $($guardB.ErrorCode)"
}

Write-Host "Artifact absent : REFUS CONFIRME" -ForegroundColor Green

# ============================================================
# 19
# ============================================================

Write-Host ""
Write-Host "[19] DETECTION ORPHELIN PHYSIQUE..." -ForegroundColor Yellow

$physicalObjectExists = $false

try {
    $null = Test-S3ObjectPresent $PhysicalOrphanKey
    $physicalObjectExists = $true
}
catch {
    $physicalObjectExists = $false
}

if (-not $physicalObjectExists) {
    throw "Objet physique absent alors qu'il devait exister."
}

$physicalDbCountAfter = Invoke-Psql @"
SELECT COUNT(*)
FROM artifact_registry
WHERE object_key = '$PhysicalOrphanKey';
"@

if ([int]$physicalDbCountAfter -ne 0) {
    throw "Objet physique référence inattendue en DB."
}

Write-Host "S3 : PRESENT" -ForegroundColor Green
Write-Host "DB : ABSENT" -ForegroundColor Green
Write-Host "Orphelin physique : DETECTE" -ForegroundColor Green

# ============================================================
# 20
# ============================================================

Write-Host ""
Write-Host "[20] CLEANUP CIBLE..." -ForegroundColor Yellow

Invoke-Psql @"
DELETE FROM production_run
WHERE run_id IN ('$RunA', '$RunB');
"@ | Out-Null

foreach ($key in @(
    $DbOrphanKey,
    $PhysicalOrphanKey
)) {
    $delete = Invoke-AwsExpectedFailure @(
        "s3api",
        "delete-object",
        "--bucket", $Bucket,
        "--key", $key
    )

    if ($delete.ExitCode -eq 0) {
        Write-Host "Objet supprimé : $key"
    }
}

if (Test-Path $Workspace) {
    Remove-Item $Workspace -Recurse -Force
}

Write-Host "Cleanup ciblé : OK" -ForegroundColor Green

# ============================================================
# 21
# ============================================================

Write-Host ""
Write-Host "[21] PREUVE FINALE..." -ForegroundColor Yellow

$remainingRuns = Invoke-Psql @"
SELECT COUNT(*)
FROM production_run
WHERE run_id IN ('$RunA', '$RunB');
"@

$remainingArtifacts = Invoke-Psql @"
SELECT COUNT(*)
FROM artifact_registry
WHERE artifact_id IN (
    '$ArtifactDbOrphan',
    '$ArtifactPhysicalOrphan'
);
"@

if ([int]$remainingRuns -ne 0) {
    throw "Runs de test restants : $remainingRuns"
}

if ([int]$remainingArtifacts -ne 0) {
    throw "Artifacts de test restants : $remainingArtifacts"
}

Write-Host "Runs restants : $remainingRuns" -ForegroundColor Green
Write-Host "Artifacts restants : $remainingArtifacts" -ForegroundColor Green

Write-Host ""
Write-Host "========================================" -ForegroundColor Green
Write-Host "PHASE 0E.6.3 - VERSION 3" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
Write-Host "DB orphan détecté              : OK" -ForegroundColor Green
Write-Host "REGISTERED refusé              : OK" -ForegroundColor Green
Write-Host "Recovery upload                : OK" -ForegroundColor Green
Write-Host "STORED refusé                  : OK" -ForegroundColor Green
Write-Host "VALIDATED autorisé             : OK" -ForegroundColor Green
Write-Host "Physical orphan détecté        : OK" -ForegroundColor Green
Write-Host "Artifact absent refusé         : OK" -ForegroundColor Green
Write-Host "Cleanup ciblé                  : OK" -ForegroundColor Green
Write-Host "NO FALSE SUCCESS               : PROUVE" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green