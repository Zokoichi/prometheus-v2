\pset pager off
\pset format wrapped
\pset border 1

\echo '============================================================'
\echo '11-E.16 — CRITICAL ERROR/RETRY ROUTINE SOURCE'
\echo '============================================================'

\echo '============================================================'
\echo '1. cancel_run_atomically'
\echo '============================================================'

SELECT
    p.oid,
    n.nspname AS schema_name,
    p.proname AS routine_name,
    pg_get_function_identity_arguments(p.oid) AS arguments,
    p.prosrc
FROM pg_proc p
JOIN pg_namespace n
    ON n.oid = p.pronamespace
WHERE n.nspname = 'public'
  AND p.proname = 'cancel_run_atomically';

\echo '============================================================'
\echo '2. claim_stage_for_execution'
\echo '============================================================'

SELECT
    p.oid,
    n.nspname AS schema_name,
    p.proname AS routine_name,
    pg_get_function_identity_arguments(p.oid) AS arguments,
    p.prosrc
FROM pg_proc p
JOIN pg_namespace n
    ON n.oid = p.pronamespace
WHERE n.nspname = 'public'
  AND p.proname = 'claim_stage_for_execution';

\echo '============================================================'
\echo '3. classify_error'
\echo '============================================================'

SELECT
    p.oid,
    n.nspname AS schema_name,
    p.proname AS routine_name,
    pg_get_function_identity_arguments(p.oid) AS arguments,
    p.prosrc
FROM pg_proc p
JOIN pg_namespace n
    ON n.oid = p.pronamespace
WHERE n.nspname = 'public'
  AND p.proname = 'classify_error';

\echo '============================================================'
\echo '4. HISTORICAL ERROR/RETRY EVENTS'
\echo '============================================================'

SELECT
    id,
    event_id,
    run_id,
    stage_id,
    stage_name,
    attempt,
    event_type,
    from_status,
    to_status,
    event_data,
    created_at
FROM production_stage_event
WHERE from_status = 'ERROR'
   OR to_status = 'ERROR'
   OR event_type IN ('STAGE_ERROR','RETRY')
ORDER BY created_at, id;

\echo '============================================================'
\echo '11-E.16 END'
\echo '============================================================'
