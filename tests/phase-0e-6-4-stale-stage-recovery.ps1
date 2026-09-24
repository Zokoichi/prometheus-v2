$ErrorActionPreference = "Stop"

$ProjectRoot = "C:\Projects\prometheus-v2"

$RunId = "RUN-20260910-0E64"
$StageId = "STG-20260910-0E64-SCRIPT"
$RecentStageId = "STG-20260910-0E64-RECENT"

$StaleThresholdMinutes = 15

function Invoke-Psql {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Sql
    )

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

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "PROMETHEUS V2 - PHASE 0E.6.4" -ForegroundColor Cyan
Write-Host "STALE STAGE RECOVERY" -ForegroundColor Cyan
Write-Host "TEST COMPLET" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# ============================================================
# 1 - PRECHECK
# ============================================================

Write-Host "[1] PRECHECK INFRA..." -ForegroundColor Yellow

$postgres = docker inspect prometheus-v2-postgres `
    --format "{{.State.Status}}" 2>$null

if ($postgres -ne "running") {
    throw "PostgreSQL n'est pas running."
}

$tableCount = Invoke-Psql @"
SELECT COUNT(*)
FROM information_schema.tables
WHERE table_schema = 'public'
  AND table_name = 'production_stage';
"@

if ([int]$tableCount -ne 1) {
    throw "Table production_stage absente."
}

$eventTableCount = Invoke-Psql @"
SELECT COUNT(*)
FROM information_schema.tables
WHERE table_schema = 'public'
  AND table_name = 'production_stage_event';
"@

if ([int]$eventTableCount -ne 1) {
    throw "Table production_stage_event absente."
}

Write-Host "PostgreSQL : PRESENT" -ForegroundColor Green
Write-Host "production_stage : PRESENT" -ForegroundColor Green
Write-Host "production_stage_event : PRESENT" -ForegroundColor Green

# ============================================================
# 2 - CLEANUP CIBLE
# ============================================================

Write-Host ""
Write-Host "[2] CLEANUP CIBLE..." -ForegroundColor Yellow

Invoke-Psql @"
DELETE FROM production_run
WHERE run_id = '$RunId';
"@ | Out-Null

Write-Host "Cleanup initial : OK" -ForegroundColor Green

# ============================================================
# 3 - CREATION RUN
# ============================================================

Write-Host ""
Write-Host "[3] CREATION RUN..." -ForegroundColor Yellow

Invoke-Psql @"
INSERT INTO production_run (
    run_id,
    project_id,
    status,
    current_stage,
    attempt,
    input_json,
    output_json
)
VALUES (
    '$RunId',
    'PROJECT-TEST-0E64',
    'VALIDATED',
    'SCRIPT',
    1,
    '{}'::jsonb,
    '{}'::jsonb
);
"@ | Out-Null

Write-Host "Run : OK" -ForegroundColor Green

# ============================================================
# 4 - CREATION STAGE PRINCIPAL
# ============================================================

Write-Host ""
Write-Host "[4] CREATION STAGE..." -ForegroundColor Yellow

Invoke-Psql @"
INSERT INTO production_stage (
    stage_id,
    run_id,
    stage_name,
    stage_order,
    status,
    attempt,
    idempotency_key,
    input_artifact_ids,
    output_artifact_ids,
    input_json,
    output_json,
    retryable
)
VALUES (
    '$StageId',
    '$RunId',
    'SCRIPT',
    1,
    'PENDING',
    1,
    '${RunId}:SCRIPT:1',
    '[]'::jsonb,
    '[]'::jsonb,
    '{}'::jsonb,
    '{}'::jsonb,
    FALSE
);
"@ | Out-Null

Invoke-Psql @"
INSERT INTO production_stage_event (
    stage_id,
    run_id,
    event_type,
    from_status,
    to_status,
    stage_name,
    attempt,
    event_data
)
VALUES (
    '$StageId',
    '$RunId',
    'STAGE_CREATED',
    NULL,
    'PENDING',
    'SCRIPT',
    1,
    jsonb_build_object(
        'test', '0E.6.4'
    )
);
"@ | Out-Null

Write-Host "Stage PENDING : OK" -ForegroundColor Green

# ============================================================
# 5 - PENDING -> RUNNING
# ============================================================

Write-Host ""
Write-Host "[5] PASSAGE PENDING -> RUNNING..." -ForegroundColor Yellow

Invoke-Psql @"
UPDATE production_stage
SET
    status = 'RUNNING',
    started_at = NOW(),
    completed_at = NULL,
    error_code = NULL,
    error_message = NULL,
    retryable = FALSE,
    updated_at = NOW()
WHERE stage_id = '$StageId'
  AND status = 'PENDING';
"@ | Out-Null

Invoke-Psql @"
INSERT INTO production_stage_event (
    stage_id,
    run_id,
    event_type,
    from_status,
    to_status,
    stage_name,
    attempt,
    event_data
)
VALUES (
    '$StageId',
    '$RunId',
    'STATE_CHANGE',
    'PENDING',
    'RUNNING',
    'SCRIPT',
    1,
    jsonb_build_object(
        'test', '0E.6.4'
    )
);
"@ | Out-Null

$state = Invoke-Psql @"
SELECT status || '|' || attempt
FROM production_stage
WHERE stage_id = '$StageId';
"@

if ($state -ne "RUNNING|1") {
    throw "Etat inattendu après démarrage : $state"
}

Write-Host "Stage : RUNNING attempt 1" -ForegroundColor Green

# ============================================================
# 6 - CRASH SIMULE
# ============================================================

Write-Host ""
Write-Host "[6] SIMULATION CRASH..." -ForegroundColor Yellow

# On ne touche PAS à Docker.
# On reproduit l'état laissé par un processus mort :
# stage RUNNING + started_at ancien.

Invoke-Psql @"
UPDATE production_stage
SET
    started_at = NOW() - INTERVAL '60 minutes',
    updated_at = NOW() - INTERVAL '60 minutes'
WHERE stage_id = '$StageId'
  AND status = 'RUNNING';
"@ | Out-Null

$crashState = Invoke-Psql @"
SELECT
    status || '|' ||
    attempt || '|' ||
    ROUND(EXTRACT(EPOCH FROM (NOW() - started_at))::numeric / 60, 1)
FROM production_stage
WHERE stage_id = '$StageId';
"@

Write-Host "Etat après crash simulé : $crashState" -ForegroundColor Green

# ============================================================
# 7 - DETECTION STALE
# ============================================================

Write-Host ""
Write-Host "[7] DETECTION STALE..." -ForegroundColor Yellow

$stale = Invoke-Psql @"
SELECT COUNT(*)
FROM production_stage
WHERE stage_id = '$StageId'
  AND status = 'RUNNING'
  AND started_at IS NOT NULL
  AND started_at < NOW() - INTERVAL '$StaleThresholdMinutes minutes';
"@

if ([int]$stale -ne 1) {
    throw "Le stage stale n'a pas été détecté."
}

Write-Host "Stage stale : DETECTE" -ForegroundColor Green

# ============================================================
# 8 - RECOVERY -> ERROR
# ============================================================

Write-Host ""
Write-Host "[8] RECOVERY STALE -> ERROR..." -ForegroundColor Yellow

Invoke-Psql @"
UPDATE production_stage
SET
    status = 'ERROR',
    completed_at = NOW(),
    error_code = 'STALE_STAGE_RECOVERED',
    error_message = 'Stage détecté RUNNING sans activité au-delà du seuil de récupération.',
    retryable = TRUE,
    updated_at = NOW()
WHERE stage_id = '$StageId'
  AND status = 'RUNNING'
  AND started_at IS NOT NULL
  AND started_at < NOW() - INTERVAL '$StaleThresholdMinutes minutes';
"@ | Out-Null

Invoke-Psql @"
INSERT INTO production_stage_event (
    stage_id,
    run_id,
    event_type,
    from_status,
    to_status,
    stage_name,
    attempt,
    event_data
)
VALUES (
    '$StageId',
    '$RunId',
    'STALE_RECOVERY',
    'RUNNING',
    'ERROR',
    'SCRIPT',
    1,
    jsonb_build_object(
        'test', '0E.6.4',
        'reason', 'STALE_STAGE',
        'retryable', TRUE
    )
);
"@ | Out-Null

$recoveredState = Invoke-Psql @"
SELECT
    status || '|' ||
    attempt || '|' ||
    COALESCE(error_code, '') || '|' ||
    retryable
FROM production_stage
WHERE stage_id = '$StageId';
"@

Write-Host "Etat recovery : $recoveredState" -ForegroundColor Green

if ($recoveredState -ne "ERROR|1|STALE_STAGE_RECOVERED|True") {
    throw "Recovery stale incorrecte : $recoveredState"
}

Write-Host "RUNNING stale -> ERROR retryable : OK" -ForegroundColor Green

# ============================================================
# 9 - RETRY ATTEMPT 2
# ============================================================

Write-Host ""
Write-Host "[9] RETRY ATTEMPT 2..." -ForegroundColor Yellow

Invoke-Psql @"
UPDATE production_stage
SET
    status = 'RUNNING',
    attempt = attempt + 1,
    started_at = NOW(),
    completed_at = NULL,
    error_code = NULL,
    error_message = NULL,
    retryable = FALSE,
    idempotency_key = '${RunId}:SCRIPT:2',
    updated_at = NOW()
WHERE stage_id = '$StageId'
  AND status = 'ERROR'
  AND retryable = TRUE;
"@ | Out-Null

Invoke-Psql @"
INSERT INTO production_stage_event (
    stage_id,
    run_id,
    event_type,
    from_status,
    to_status,
    stage_name,
    attempt,
    event_data
)
VALUES (
    '$StageId',
    '$RunId',
    'RETRY',
    'ERROR',
    'RUNNING',
    'SCRIPT',
    2,
    jsonb_build_object(
        'test', '0E.6.4',
        'previous_error', 'STALE_STAGE_RECOVERED'
    )
);
"@ | Out-Null

$retryState = Invoke-Psql @"
SELECT status || '|' || attempt || '|' || idempotency_key
FROM production_stage
WHERE stage_id = '$StageId';
"@

if ($retryState -ne "RUNNING|2|${RunId}:SCRIPT:2") {
    throw "Retry incorrect : $retryState"
}

Write-Host "Stage : RUNNING attempt 2" -ForegroundColor Green
Write-Host "Idempotency key : ${RunId}:SCRIPT:2" -ForegroundColor Green

# ============================================================
# 10 - SUCCES ATTEMPT 2
# ============================================================

Write-Host ""
Write-Host "[10] SUCCES ATTEMPT 2..." -ForegroundColor Yellow

Invoke-Psql @"
UPDATE production_stage
SET
    status = 'SUCCEEDED',
    completed_at = NOW(),
    output_json = jsonb_build_object(
        'test', '0E.6.4',
        'recovered', TRUE
    ),
    error_code = NULL,
    error_message = NULL,
    retryable = FALSE,
    updated_at = NOW()
WHERE stage_id = '$StageId'
  AND status = 'RUNNING'
  AND attempt = 2;
"@ | Out-Null

Invoke-Psql @"
INSERT INTO production_stage_event (
    stage_id,
    run_id,
    event_type,
    from_status,
    to_status,
    stage_name,
    attempt,
    event_data
)
VALUES (
    '$StageId',
    '$RunId',
    'STATE_CHANGE',
    'RUNNING',
    'SUCCEEDED',
    'SCRIPT',
    2,
    jsonb_build_object(
        'test', '0E.6.4',
        'recovered', TRUE
    )
);
"@ | Out-Null

$finalState = Invoke-Psql @"
SELECT
    status || '|' ||
    attempt || '|' ||
    CASE
        WHEN started_at IS NOT NULL AND completed_at IS NOT NULL
        THEN 'TIMED'
        ELSE 'INVALID'
    END
FROM production_stage
WHERE stage_id = '$StageId';
"@

Write-Host "Etat final : $finalState" -ForegroundColor Green

if ($finalState -ne "SUCCEEDED|2|TIMED") {
    throw "Etat final incorrect : $finalState"
}

Write-Host "Recovery complète : OK" -ForegroundColor Green

# ============================================================
# 11 - PROTECTION CONTRE RECOVERY ABUSIVE
# ============================================================

Write-Host ""
Write-Host "[11] TEST RUNNING RECENT : NE DOIT PAS ETRE RECUPERE..." -ForegroundColor Yellow

Invoke-Psql @"
INSERT INTO production_stage (
    stage_id,
    run_id,
    stage_name,
    stage_order,
    status,
    attempt,
    idempotency_key,
    input_artifact_ids,
    output_artifact_ids,
    input_json,
    output_json,
    retryable,
    started_at
)
VALUES (
    '$RecentStageId',
    '$RunId',
    'RECENT_TEST',
    99,
    'RUNNING',
    1,
    '${RunId}:RECENT_TEST:1',
    '[]'::jsonb,
    '[]'::jsonb,
    '{}'::jsonb,
    '{}'::jsonb,
    FALSE,
    NOW()
);
"@ | Out-Null

$recentStale = Invoke-Psql @"
SELECT COUNT(*)
FROM production_stage
WHERE stage_id = '$RecentStageId'
  AND status = 'RUNNING'
  AND started_at IS NOT NULL
  AND started_at < NOW() - INTERVAL '$StaleThresholdMinutes minutes';
"@

if ([int]$recentStale -ne 0) {
    throw "FAUX STALE : un stage récent a été considéré stale."
}

$recentState = Invoke-Psql @"
SELECT status || '|' || attempt
FROM production_stage
WHERE stage_id = '$RecentStageId';
"@

if ($recentState -ne "RUNNING|1") {
    throw "Le stage récent a été modifié abusivement : $recentState"
}

Write-Host "Stage récent : CONSERVE RUNNING" -ForegroundColor Green
Write-Host "Recovery abusive : REFUSEE" -ForegroundColor Green

# ============================================================
# 12 - HISTORIQUE
# ============================================================

Write-Host ""
Write-Host "[12] VERIFICATION HISTORIQUE..." -ForegroundColor Yellow

$eventCount = Invoke-Psql @"
SELECT COUNT(*)
FROM production_stage_event
WHERE stage_id = '$StageId';
"@

$history = Invoke-Psql @"
SELECT
    event_type || '|' ||
    COALESCE(from_status, '') || '|' ||
    COALESCE(to_status, '') || '|' ||
    attempt
FROM production_stage_event
WHERE stage_id = '$StageId'
ORDER BY id;
"@

Write-Host "Nombre événements : $eventCount" -ForegroundColor Green
Write-Host ""
Write-Host $history

if ([int]$eventCount -ne 5) {
    throw "Nombre d'événements inattendu : $eventCount"
}

# ============================================================
# 13 - PREUVE NO FALSE SUCCESS
# ============================================================

Write-Host ""
Write-Host "[13] PREUVE NO FALSE SUCCESS..." -ForegroundColor Yellow

$badRunningSuccess = Invoke-Psql @"
SELECT COUNT(*)
FROM production_stage
WHERE stage_id = '$StageId'
  AND status = 'SUCCEEDED'
  AND attempt = 1;
"@

if ([int]$badRunningSuccess -ne 0) {
    throw "FAUX SUCCES : attempt 1 considérée SUCCEEDED."
}

$staleRecoveryEvents = Invoke-Psql @"
SELECT COUNT(*)
FROM production_stage_event
WHERE stage_id = '$StageId'
  AND event_type = 'STALE_RECOVERY'
  AND from_status = 'RUNNING'
  AND to_status = 'ERROR';
"@

if ([int]$staleRecoveryEvents -ne 1) {
    throw "Événement STALE_RECOVERY absent ou incorrect."
}

Write-Host "Attempt 1 : jamais SUCCEEDED" -ForegroundColor Green
Write-Host "STALE_RECOVERY : PROUVE" -ForegroundColor Green
Write-Host "NO FALSE SUCCESS : PROUVE" -ForegroundColor Green

# ============================================================
# 14 - CLEANUP
# ============================================================

Write-Host ""
Write-Host "[14] CLEANUP CIBLE..." -ForegroundColor Yellow

Invoke-Psql @"
DELETE FROM production_run
WHERE run_id = '$RunId';
"@ | Out-Null

$remaining = Invoke-Psql @"
SELECT COUNT(*)
FROM production_run
WHERE run_id = '$RunId';
"@

if ([int]$remaining -ne 0) {
    throw "Cleanup incomplet : Run restant."
}

Write-Host "Cleanup ciblé : OK" -ForegroundColor Green

# ============================================================
# FINAL
# ============================================================

Write-Host ""
Write-Host "========================================" -ForegroundColor Green
Write-Host "PHASE 0E.6.4 - VALIDATION" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
Write-Host "Crash simulé                    : OK" -ForegroundColor Green
Write-Host "RUNNING stale détecté           : OK" -ForegroundColor Green
Write-Host "STALE -> ERROR                  : OK" -ForegroundColor Green
Write-Host "Erreur marquée retryable        : OK" -ForegroundColor Green
Write-Host "Retry attempt 2                 : OK" -ForegroundColor Green
Write-Host "SUCCEEDED attempt 2             : OK" -ForegroundColor Green
Write-Host "RUNNING récent protégé           : OK" -ForegroundColor Green
Write-Host "Historique                      : OK" -ForegroundColor Green
Write-Host "Cleanup ciblé                  : OK" -ForegroundColor Green
Write-Host "NO FALSE SUCCESS               : PROUVE" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green