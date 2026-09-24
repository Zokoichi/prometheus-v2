\set ON_ERROR_STOP on
\pset pager off

\echo ============================================================
\echo 11-E.32-F
\echo LOCK ORDER FORENSICS - READ ONLY
\echo ============================================================

\echo
\echo === 01. FUNCTION INVENTORY ===

SELECT
    p.proname,
    pg_get_function_identity_arguments(p.oid) AS arguments,
    pg_get_function_result(p.oid) AS result_type
FROM pg_proc p
JOIN pg_namespace n ON n.oid = p.pronamespace
WHERE n.nspname = 'public'
  AND p.proname IN (
      'fail_stage_atomically',
      'fail_run_atomically',
      'claim_stage_for_execution',
      'complete_stage_atomically'
  )
ORDER BY p.proname;

\echo
\echo === 02. fail_stage_atomically SOURCE ===

SELECT pg_get_functiondef(p.oid)
FROM pg_proc p
JOIN pg_namespace n ON n.oid = p.pronamespace
WHERE n.nspname = 'public'
  AND p.proname = 'fail_stage_atomically';

\echo
\echo === 03. fail_run_atomically SOURCE ===

SELECT pg_get_functiondef(p.oid)
FROM pg_proc p
JOIN pg_namespace n ON n.oid = p.pronamespace
WHERE n.nspname = 'public'
  AND p.proname = 'fail_run_atomically';

\echo
\echo === 04. claim_stage_for_execution SOURCE ===

SELECT pg_get_functiondef(p.oid)
FROM pg_proc p
JOIN pg_namespace n ON n.oid = p.pronamespace
WHERE n.nspname = 'public'
  AND p.proname = 'claim_stage_for_execution';

\echo
\echo === 05. complete_stage_atomically SOURCE ===

SELECT pg_get_functiondef(p.oid)
FROM pg_proc p
JOIN pg_namespace n ON n.oid = p.pronamespace
WHERE n.nspname = 'public'
  AND p.proname = 'complete_stage_atomically';

\echo
\echo === 06. LOCK / SERIALIZATION TOKENS ===

WITH funcs AS (
    SELECT
        p.proname,
        pg_get_functiondef(p.oid) AS definition
    FROM pg_proc p
    JOIN pg_namespace n ON n.oid = p.pronamespace
    WHERE n.nspname = 'public'
      AND p.proname IN (
          'fail_stage_atomically',
          'fail_run_atomically',
          'claim_stage_for_execution',
          'complete_stage_atomically'
      )
)
SELECT
    proname,
    token,
    position(token IN definition) AS first_position
FROM funcs
CROSS JOIN LATERAL unnest(ARRAY[
    'FOR UPDATE',
    'FOR SHARE',
    'pg_advisory_xact_lock',
    'production_run',
    'production_stage',
    'production_run_event',
    'production_stage_event',
    'UPDATE production_run',
    'UPDATE production_stage',
    'INSERT INTO production_run_event',
    'INSERT INTO production_stage_event'
]) AS t(token)
WHERE position(token IN definition) > 0
ORDER BY proname, first_position;

\echo
\echo === 07. EXPLICIT LOCK-ORDER MARKERS ===

WITH funcs AS (
    SELECT
        p.proname,
        pg_get_functiondef(p.oid) AS definition
    FROM pg_proc p
    JOIN pg_namespace n ON n.oid = p.pronamespace
    WHERE n.nspname = 'public'
      AND p.proname IN (
          'fail_stage_atomically',
          'fail_run_atomically',
          'claim_stage_for_execution',
          'complete_stage_atomically'
      )
)
SELECT
    proname,
    CASE
        WHEN definition ~* 'production_run.*FOR UPDATE'
            THEN 'RUN_FOR_UPDATE_FOUND'
        ELSE 'RUN_FOR_UPDATE_NOT_FOUND'
    END AS run_lock,
    CASE
        WHEN definition ~* 'production_stage.*FOR UPDATE'
            THEN 'STAGE_FOR_UPDATE_FOUND'
        ELSE 'STAGE_FOR_UPDATE_NOT_FOUND'
    END AS stage_lock,
    CASE
        WHEN definition ~* 'pg_advisory_xact_lock'
            THEN 'ADVISORY_LOCK_FOUND'
        ELSE 'ADVISORY_LOCK_NOT_FOUND'
    END AS advisory_lock
FROM funcs
ORDER BY proname;

\echo
\echo === 08. CURRENT PRODUCTION ERROR STATE ===

SELECT
    COUNT(*) FILTER (WHERE status = 'ERROR') AS error_stages,
    COUNT(*) FILTER (
        WHERE status = 'ERROR'
          AND retryable = true
    ) AS retryable_error_stages,
    COUNT(*) FILTER (
        WHERE status = 'ERROR'
          AND retryable = false
    ) AS terminal_error_stages,
    COUNT(*) AS total_stages
FROM production_stage;

SELECT
    COUNT(*) FILTER (WHERE status = 'ERROR') AS error_runs,
    COUNT(*) AS total_runs
FROM production_run;

\echo
\echo === 09. 11-E.32 FIXTURE MUST BE ABSENT ===

SELECT
    COUNT(*) AS fixture_run_count
FROM production_run
WHERE run_id = 'RUN-11E32-FIXTURE';

SELECT
    COUNT(*) AS fixture_stage_count
FROM production_stage
WHERE stage_id = 'STG-11E32-FIXTURE';

SELECT
    COUNT(*) AS fixture_run_event_count
FROM production_run_event
WHERE run_id = 'RUN-11E32-FIXTURE';

SELECT
    COUNT(*) AS fixture_stage_event_count
FROM production_stage_event
WHERE run_id = 'RUN-11E32-FIXTURE';

\echo
\echo ============================================================
\echo 11-E.32-F END
\echo READ ONLY
\echo ============================================================
