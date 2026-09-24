\set ON_ERROR_STOP on
\pset pager off
\pset format aligned

\echo ============================================================
\echo 11-E.32-DIAG-3
\echo ORCHESTRATION / RETRY CONSUMER FORENSICS
\echo READ ONLY
\echo ============================================================

\echo
\echo === 01. FUNCTIONS CALLING CLAIM_STAGE ===

SELECT
    n.nspname AS schema_name,
    p.proname,
    pg_get_function_identity_arguments(p.oid) AS arguments
FROM pg_proc p
JOIN pg_namespace n
  ON n.oid = p.pronamespace
WHERE n.nspname = 'public'
  AND p.prokind = 'f'
  AND pg_get_functiondef(p.oid) ILIKE '%claim_stage_for_execution%'
ORDER BY p.proname, arguments;

\echo
\echo === 02. FUNCTIONS CALLING FAIL_STAGE ===

SELECT
    n.nspname AS schema_name,
    p.proname,
    pg_get_function_identity_arguments(p.oid) AS arguments
FROM pg_proc p
JOIN pg_namespace n
  ON n.oid = p.pronamespace
WHERE n.nspname = 'public'
  AND p.prokind = 'f'
  AND pg_get_functiondef(p.oid) ILIKE '%fail_stage_atomically%'
ORDER BY p.proname, arguments;

\echo
\echo === 03. FUNCTIONS CALLING FAIL_RUN ===

SELECT
    n.nspname AS schema_name,
    p.proname,
    pg_get_function_identity_arguments(p.oid) AS arguments
FROM pg_proc p
JOIN pg_namespace n
  ON n.oid = p.pronamespace
WHERE n.nspname = 'public'
  AND p.prokind = 'f'
  AND pg_get_functiondef(p.oid) ILIKE '%fail_run_atomically%'
ORDER BY p.proname, arguments;

\echo
\echo === 04. FUNCTIONS READING RETRYABLE ===

SELECT
    n.nspname AS schema_name,
    p.proname,
    pg_get_function_identity_arguments(p.oid) AS arguments
FROM pg_proc p
JOIN pg_namespace n
  ON n.oid = p.pronamespace
WHERE n.nspname = 'public'
  AND p.prokind = 'f'
  AND pg_get_functiondef(p.oid) ILIKE '%retryable%'
ORDER BY p.proname, arguments;

\echo
\echo === 05. FUNCTIONS READING ATTEMPT ===

SELECT
    n.nspname AS schema_name,
    p.proname,
    pg_get_function_identity_arguments(p.oid) AS arguments
FROM pg_proc p
JOIN pg_namespace n
  ON n.oid = p.pronamespace
WHERE n.nspname = 'public'
  AND p.prokind = 'f'
  AND pg_get_functiondef(p.oid) ILIKE '%attempt%'
ORDER BY p.proname, arguments;

\echo
\echo === 06. FUNCTIONS READING MAX_ATTEMPTS ===

SELECT
    n.nspname AS schema_name,
    p.proname,
    pg_get_function_identity_arguments(p.oid) AS arguments
FROM pg_proc p
JOIN pg_namespace n
  ON n.oid = p.pronamespace
WHERE n.nspname = 'public'
  AND p.prokind = 'f'
  AND pg_get_functiondef(p.oid) ILIKE '%max_attempts%'
ORDER BY p.proname, arguments;

\echo
\echo === 07. FUNCTIONS READING RETRY_POLICY ===

SELECT
    n.nspname AS schema_name,
    p.proname,
    pg_get_function_identity_arguments(p.oid) AS arguments
FROM pg_proc p
JOIN pg_namespace n
  ON n.oid = p.pronamespace
WHERE n.nspname = 'public'
  AND p.prokind = 'f'
  AND pg_get_functiondef(p.oid) ILIKE '%retry_policy%'
ORDER BY p.proname, arguments;

\echo
\echo === 08. FUNCTIONS WRITING PRODUCTION_STAGE ===

SELECT
    n.nspname AS schema_name,
    p.proname,
    pg_get_function_identity_arguments(p.oid) AS arguments
FROM pg_proc p
JOIN pg_namespace n
  ON n.oid = p.pronamespace
WHERE n.nspname = 'public'
  AND p.prokind = 'f'
  AND (
      pg_get_functiondef(p.oid) ILIKE '%UPDATE production_stage%'
      OR pg_get_functiondef(p.oid) ILIKE '%INSERT INTO production_stage%'
      OR pg_get_functiondef(p.oid) ILIKE '%DELETE FROM production_stage%'
  )
ORDER BY p.proname, arguments;

\echo
\echo === 09. FUNCTIONS WRITING PRODUCTION_RUN ===

SELECT
    n.nspname AS schema_name,
    p.proname,
    pg_get_function_identity_arguments(p.oid) AS arguments
FROM pg_proc p
JOIN pg_namespace n
  ON n.oid = p.pronamespace
WHERE n.nspname = 'public'
  AND p.prokind = 'f'
  AND (
      pg_get_functiondef(p.oid) ILIKE '%UPDATE production_run%'
      OR pg_get_functiondef(p.oid) ILIKE '%INSERT INTO production_run%'
      OR pg_get_functiondef(p.oid) ILIKE '%DELETE FROM production_run%'
  )
ORDER BY p.proname, arguments;

\echo
\echo === 10. FUNCTIONS WRITING STAGE EVENTS ===

SELECT
    n.nspname AS schema_name,
    p.proname,
    pg_get_function_identity_arguments(p.oid) AS arguments
FROM pg_proc p
JOIN pg_namespace n
  ON n.oid = p.pronamespace
WHERE n.nspname = 'public'
  AND p.prokind = 'f'
  AND pg_get_functiondef(p.oid) ILIKE '%production_stage_event%'
ORDER BY p.proname, arguments;

\echo
\echo === 11. FUNCTIONS WRITING RUN EVENTS ===

SELECT
    n.nspname AS schema_name,
    p.proname,
    pg_get_function_identity_arguments(p.oid) AS arguments
FROM pg_proc p
JOIN pg_namespace n
  ON n.oid = p.pronamespace
WHERE n.nspname = 'public'
  AND p.prokind = 'f'
  AND pg_get_functiondef(p.oid) ILIKE '%production_run_event%'
ORDER BY p.proname, arguments;

\echo
\echo === 12. FULL RELEVANT FUNCTION SOURCES ===

SELECT
    '===== ' ||
    p.proname || '(' ||
    pg_get_function_identity_arguments(p.oid) ||
    ') =====' ||
    E'\n' ||
    pg_get_functiondef(p.oid)
FROM pg_proc p
JOIN pg_namespace n
  ON n.oid = p.pronamespace
WHERE n.nspname = 'public'
  AND p.prokind = 'f'
  AND p.proname IN (
      'claim_stage_for_execution',
      'complete_stage_atomically',
      'fail_stage_atomically',
      'fail_run_atomically',
      'request_run_transition',
      'validate_run_stage_consistency',
      'diagnose_run',
      'cancel_run_atomically',
      'record_execution_event'
  )
ORDER BY p.proname;

\echo
\echo === 13. STAGE DEFINITION CONTRACTS ===

SELECT
    stage_name,
    version,
    max_attempts,
    retry_policy,
    recovery_policy,
    executor_type,
    enabled
FROM public.stage_definition
ORDER BY stage_name, version;

\echo
\echo === 14. ERROR POLICY DETAIL ===

SELECT
    error_code,
    category,
    retryable,
    max_attempts,
    initial_backoff_seconds,
    backoff_multiplier,
    max_backoff_seconds,
    enabled
FROM public.error_policy
ORDER BY error_code;

\echo
\echo === 15. CURRENT RUN/STAGE RELATIONSHIPS ===

SELECT
    pr.run_id,
    pr.status AS run_status,
    pr.current_stage,
    ps.stage_id,
    ps.stage_name,
    ps.status AS stage_status,
    ps.attempt AS stage_attempt,
    ps.retryable,
    ps.error_code
FROM public.production_run pr
LEFT JOIN public.production_stage ps
  ON ps.run_id = pr.run_id
ORDER BY pr.run_id, ps.stage_order;

\echo
\echo === 16. TRIGGERS ON RUN/STAGE ===

SELECT
    event_object_schema,
    event_object_table,
    trigger_name,
    action_timing,
    event_manipulation,
    action_statement
FROM information_schema.triggers
WHERE event_object_schema = 'public'
  AND event_object_table IN (
      'production_run',
      'production_stage',
      'production_run_event',
      'production_stage_event'
  )
ORDER BY event_object_table, trigger_name;

\echo
\echo === 17. DB OBJECT COUNTS ===

SELECT
    'production_run' AS object_name,
    COUNT(*) AS count
FROM production_run
UNION ALL
SELECT
    'production_stage',
    COUNT(*)
FROM production_stage
UNION ALL
SELECT
    'production_run_event',
    COUNT(*)
FROM production_run_event
UNION ALL
SELECT
    'production_stage_event',
    COUNT(*)
FROM production_stage_event
UNION ALL
SELECT
    'production_execution_event',
    COUNT(*)
FROM production_execution_event;

\echo
\echo === 18. CLEAN STATE ===

SELECT COUNT(*) AS error_runs
FROM production_run
WHERE status = 'ERROR';

SELECT COUNT(*) AS error_stages
FROM production_stage
WHERE status = 'ERROR';

SELECT COUNT(*) AS retryable_error_stages
FROM production_stage
WHERE status = 'ERROR'
  AND retryable = TRUE;

SELECT COUNT(*) AS terminal_error_stages
FROM production_stage
WHERE status = 'ERROR'
  AND retryable = FALSE;

\echo
\echo ============================================================
\echo 11-E.32-DIAG-3 SQL END
\echo ============================================================
