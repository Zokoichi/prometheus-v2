\pset pager off
\pset format wrapped
\pset border 1

\echo '============================================================'
\echo '11-E.20 — RUN ERROR CONSISTENCY FORENSICS'
\echo '============================================================'

\echo '============================================================'
\echo '1. validate_run_stage_consistency()'
\echo '============================================================'

SELECT pg_get_functiondef(p.oid)
FROM pg_proc p
JOIN pg_namespace n
  ON n.oid = p.pronamespace
WHERE n.nspname = 'public'
  AND p.proname = 'validate_run_stage_consistency';

\echo '============================================================'
\echo '2. request_run_transition() — ERROR REFERENCES'
\echo '============================================================'

SELECT
    p.oid,
    p.proname,
    pg_get_function_identity_arguments(p.oid) AS arguments,
    position('ERROR' in pg_get_functiondef(p.oid)) AS first_error_reference
FROM pg_proc p
JOIN pg_namespace n
  ON n.oid = p.pronamespace
WHERE n.nspname = 'public'
  AND p.proname = 'request_run_transition';

\echo '============================================================'
\echo '3. CURRENT RUN / STAGE CONSISTENCY SNAPSHOT'
\echo '============================================================'

SELECT
    pr.run_id,
    pr.status AS run_status,
    pr.current_stage,
    ps.stage_id,
    ps.stage_name,
    ps.stage_order,
    ps.status AS stage_status,
    ps.attempt,
    ps.retryable,
    ps.error_code,
    ps.error_message
FROM production_run pr
LEFT JOIN production_stage ps
    ON ps.run_id = pr.run_id
ORDER BY pr.run_id, ps.stage_order, ps.stage_id;

\echo '============================================================'
\echo '4. RUNS CURRENTLY IN ERROR'
\echo '============================================================'

SELECT
    pr.run_id,
    pr.status,
    pr.current_stage,
    pr.error_code,
    pr.error_message,
    pr.attempt
FROM production_run pr
WHERE pr.status = 'ERROR'
ORDER BY pr.run_id;

\echo '============================================================'
\echo '5. STAGES CURRENTLY IN ERROR'
\echo '============================================================'

SELECT
    stage_id,
    run_id,
    stage_name,
    stage_order,
    status,
    attempt,
    retryable,
    error_code,
    error_message
FROM production_stage
WHERE status = 'ERROR'
ORDER BY run_id, stage_order, stage_id;

\echo '============================================================'
\echo '6. ERROR EVENTS — RUN LEVEL'
\echo '============================================================'

SELECT
    id,
    run_id,
    event_type,
    from_status,
    to_status,
    stage,
    attempt,
    event_data,
    created_at
FROM production_run_event
WHERE from_status = 'ERROR'
   OR to_status = 'ERROR'
ORDER BY created_at, id;

\echo '============================================================'
\echo '11-E.20 END'
\echo '============================================================'
