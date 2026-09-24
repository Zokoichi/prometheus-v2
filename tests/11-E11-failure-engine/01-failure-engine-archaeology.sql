\pset pager off
\pset format aligned
\pset border 1

\echo '============================================================'
\echo '11-E.11 — FAILURE / RETRY ENGINE ARCHAEOLOGY'
\echo '============================================================'

\echo '============================================================'
\echo '1. FUNCTIONS WITH FAILURE / RETRY / ERROR / CANCEL NAMES'
\echo '============================================================'

SELECT
    p.oid,
    n.nspname AS schema_name,
    p.proname AS function_name,
    pg_get_function_identity_arguments(p.oid) AS arguments,
    pg_get_function_result(p.oid) AS result
FROM pg_proc p
JOIN pg_namespace n
    ON n.oid = p.pronamespace
WHERE n.nspname = 'public'
  AND (
       p.proname ILIKE '%fail%'
    OR p.proname ILIKE '%error%'
    OR p.proname ILIKE '%retry%'
    OR p.proname ILIKE '%cancel%'
    OR p.proname ILIKE '%recover%'
  )
ORDER BY p.proname, p.oid;

\echo '============================================================'
\echo '2. FUNCTIONS WITH STAGE TRANSITION / STAGE STATE NAMES'
\echo '============================================================'

SELECT
    p.oid,
    n.nspname AS schema_name,
    p.proname AS function_name,
    pg_get_function_identity_arguments(p.oid) AS arguments,
    pg_get_function_result(p.oid) AS result
FROM pg_proc p
JOIN pg_namespace n
    ON n.oid = p.pronamespace
WHERE n.nspname = 'public'
  AND (
       p.proname ILIKE '%stage%'
    OR p.proname ILIKE '%transition%'
    OR p.proname ILIKE '%claim%'
    OR p.proname ILIKE '%complete%'
  )
ORDER BY p.proname, p.oid;

\echo '============================================================'
\echo '3. CURRENT STAGE ERROR / RETRY STATES'
\echo '============================================================'

SELECT
    status,
    retryable,
    COUNT(*) AS count
FROM production_stage
GROUP BY status, retryable
ORDER BY status, retryable;

\echo '============================================================'
\echo '4. CURRENT STAGES WITH ERROR FIELDS'
\echo '============================================================'

SELECT
    stage_id,
    run_id,
    stage_name,
    status,
    attempt,
    retryable,
    error_code,
    error_message,
    started_at,
    completed_at
FROM production_stage
WHERE error_code IS NOT NULL
   OR error_message IS NOT NULL
   OR status = 'ERROR'
ORDER BY created_at;

\echo '============================================================'
\echo '5. STAGE EVENT HISTORY FOR V3 SCENE_PLAN'
\echo '============================================================'

SELECT
    stage_id,
    run_id,
    event_type,
    from_status,
    to_status,
    stage_name,
    attempt,
    event_data,
    created_at
FROM production_stage_event
WHERE stage_id = 'STAGE-SCENE-PLAN-V3'
ORDER BY created_at;

\echo '============================================================'
\echo '6. STAGE EVENT HISTORY CONTAINING ERROR'
\echo '============================================================'

SELECT
    stage_id,
    run_id,
    event_type,
    from_status,
    to_status,
    stage_name,
    attempt,
    event_data,
    created_at
FROM production_stage_event
WHERE from_status = 'ERROR'
   OR to_status = 'ERROR'
   OR event_type ILIKE '%ERROR%'
   OR event_type ILIKE '%FAIL%'
ORDER BY created_at;

\echo '============================================================'
\echo '7. CURRENT RUN ERROR STATES'
\echo '============================================================'

SELECT
    run_id,
    project_id,
    status,
    current_stage,
    attempt,
    error_code,
    error_message,
    created_at,
    updated_at
FROM production_run
WHERE status = 'ERROR'
   OR error_code IS NOT NULL
   OR error_message IS NOT NULL
ORDER BY created_at;

\echo '============================================================'
\echo '11-E.11 END'
\echo '============================================================'
