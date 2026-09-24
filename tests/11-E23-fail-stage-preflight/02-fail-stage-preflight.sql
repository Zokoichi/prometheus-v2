\set ON_ERROR_STOP on
\pset pager off

\echo ============================================================
\echo 11-E.23 - FAIL_STAGE_ATOMICALLY PREFLIGHT
\echo READ-ONLY
\echo ============================================================

\echo
\echo === 01. production_stage constraints ===

SELECT
    conname,
    contype,
    pg_get_constraintdef(oid) AS definition
FROM pg_constraint
WHERE conrelid = 'public.production_stage'::regclass
ORDER BY conname;

\echo
\echo === 02. production_stage triggers ===

SELECT
    tgname,
    pg_get_triggerdef(oid) AS definition
FROM pg_trigger
WHERE tgrelid = 'public.production_stage'::regclass
  AND NOT tgisinternal
ORDER BY tgname;

\echo
\echo === 03. production_stage_event constraints ===

SELECT
    conname,
    contype,
    pg_get_constraintdef(oid) AS definition
FROM pg_constraint
WHERE conrelid = 'public.production_stage_event'::regclass
ORDER BY conname;

\echo
\echo === 04. production_stage_event triggers ===

SELECT
    tgname,
    pg_get_triggerdef(oid) AS definition
FROM pg_trigger
WHERE tgrelid = 'public.production_stage_event'::regclass
  AND NOT tgisinternal
ORDER BY tgname;

\echo
\echo === 05. fail_stage_atomically existence ===

SELECT
    n.nspname AS schema_name,
    p.proname AS function_name,
    pg_get_function_identity_arguments(p.oid) AS arguments,
    pg_get_function_result(p.oid) AS return_type
FROM pg_proc p
JOIN pg_namespace n
    ON n.oid = p.pronamespace
WHERE n.nspname = 'public'
  AND p.prokind = 'f'
  AND p.proname = 'fail_stage_atomically';

\echo
\echo === 06. functions writing production_stage ===

SELECT
    p.proname,
    pg_get_function_identity_arguments(p.oid) AS arguments
FROM pg_proc p
JOIN pg_namespace n
    ON n.oid = p.pronamespace
WHERE n.nspname = 'public'
  AND p.prokind = 'f'
  AND pg_get_functiondef(p.oid) ILIKE '%UPDATE production_stage%'
ORDER BY p.proname;

\echo
\echo === 07. functions inserting production_stage_event ===

SELECT
    p.proname,
    pg_get_function_identity_arguments(p.oid) AS arguments
FROM pg_proc p
JOIN pg_namespace n
    ON n.oid = p.pronamespace
WHERE n.nspname = 'public'
  AND p.prokind = 'f'
  AND pg_get_functiondef(p.oid) ILIKE '%INSERT INTO production_stage_event%'
ORDER BY p.proname;

\echo
\echo === 08. classify_error callers ===

SELECT
    p.proname,
    pg_get_function_identity_arguments(p.oid) AS arguments
FROM pg_proc p
JOIN pg_namespace n
    ON n.oid = p.pronamespace
WHERE n.nspname = 'public'
  AND p.prokind = 'f'
  AND p.proname <> 'classify_error'
  AND pg_get_functiondef(p.oid) ILIKE '%classify_error(%'
ORDER BY p.proname;

\echo
\echo === 09. STAGE_ERROR references ===

SELECT
    p.proname,
    pg_get_function_identity_arguments(p.oid) AS arguments
FROM pg_proc p
JOIN pg_namespace n
    ON n.oid = p.pronamespace
WHERE n.nspname = 'public'
  AND p.prokind = 'f'
  AND pg_get_functiondef(p.oid) ILIKE '%STAGE_ERROR%'
ORDER BY p.proname;

\echo
\echo === 10. current stage error state ===

SELECT
    status,
    retryable,
    COUNT(*) AS count
FROM production_stage
GROUP BY status, retryable
ORDER BY status, retryable;

\echo
\echo === 11. current ERROR stages ===

SELECT
    stage_id,
    run_id,
    stage_name,
    status,
    attempt,
    retryable,
    error_code,
    error_message
FROM production_stage
WHERE status = 'ERROR'
ORDER BY run_id, stage_id;

\echo
\echo === 12. stage definitions failure/retry ===

SELECT
    stage_name,
    version,
    enabled,
    max_attempts,
    retry_policy,
    recovery_policy,
    idempotency_policy,
    executor_type
FROM stage_definition
WHERE enabled = TRUE
ORDER BY stage_name, version;

\echo
\echo === 13. current stage snapshot ===

SELECT
    stage_id,
    run_id,
    stage_name,
    status,
    attempt,
    retryable,
    idempotency_key
FROM production_stage
ORDER BY run_id, stage_order, stage_id;

\echo
\echo === 14. SUMMARY ===

SELECT
    (SELECT COUNT(*)
     FROM production_stage
     WHERE status = 'ERROR') AS current_error_stages,

    (SELECT COUNT(*)
     FROM production_stage
     WHERE status = 'ERROR'
       AND retryable = TRUE) AS current_retryable_error_stages,

    (SELECT COUNT(*)
     FROM production_stage
     WHERE status = 'ERROR'
       AND retryable = FALSE) AS current_terminal_error_stages,

    (SELECT COUNT(*)
     FROM pg_proc p
     JOIN pg_namespace n ON n.oid = p.pronamespace
     WHERE n.nspname = 'public'
       AND p.prokind = 'f'
       AND p.proname = 'fail_stage_atomically') AS fail_stage_function_count,

    (SELECT COUNT(*)
     FROM pg_proc p
     JOIN pg_namespace n ON n.oid = p.pronamespace
     WHERE n.nspname = 'public'
       AND p.prokind = 'f'
       AND p.proname <> 'classify_error'
       AND pg_get_functiondef(p.oid) ILIKE '%classify_error(%') AS classify_error_callers;

\echo
\echo ============================================================
\echo 11-E.23 END
\echo ============================================================
