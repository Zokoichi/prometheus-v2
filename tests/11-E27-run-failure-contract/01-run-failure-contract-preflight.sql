\set ON_ERROR_STOP on
\pset pager off

\echo ============================================================
\echo 11-E.27
\echo RUN FAILURE CONTRACT PREFLIGHT
\echo READ ONLY
\echo ============================================================

\echo
\echo === 01. PRODUCTION_RUN FULL STRUCTURE ===

SELECT
    ordinal_position,
    column_name,
    data_type,
    is_nullable,
    column_default
FROM information_schema.columns
WHERE table_schema = 'public'
  AND table_name = 'production_run'
ORDER BY ordinal_position;

\echo
\echo === 02. PRODUCTION_RUN CHECK CONSTRAINTS ===

SELECT
    conname,
    pg_get_constraintdef(oid) AS constraint_definition
FROM pg_constraint
WHERE conrelid = 'public.production_run'::regclass
ORDER BY conname;

\echo
\echo === 03. PRODUCTION_RUN_EVENT STRUCTURE ===

SELECT
    ordinal_position,
    column_name,
    data_type,
    is_nullable,
    column_default
FROM information_schema.columns
WHERE table_schema = 'public'
  AND table_name = 'production_run_event'
ORDER BY ordinal_position;

\echo
\echo === 04. PRODUCTION_RUN_EVENT CONSTRAINTS ===

SELECT
    conname,
    pg_get_constraintdef(oid) AS constraint_definition
FROM pg_constraint
WHERE conrelid = 'public.production_run_event'::regclass
ORDER BY conname;

\echo
\echo === 05. DISTINCT RUN EVENT TYPES ===

SELECT
    event_type,
    COUNT(*) AS event_count
FROM public.production_run_event
GROUP BY event_type
ORDER BY event_type;

\echo
\echo === 06. DISTINCT RUN STATUS TRANSITIONS ===

SELECT
    from_status,
    to_status,
    COUNT(*) AS event_count
FROM public.production_run_event
GROUP BY from_status, to_status
ORDER BY from_status, to_status;

\echo
\echo === 07. RUN ERROR EVENTS WITH STAGE FIELD ===

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
FROM public.production_run_event
WHERE to_status = 'ERROR'
   OR from_status = 'ERROR'
   OR event_type IN ('ERROR', 'STAGE_ERROR', 'RETRY')
ORDER BY id;

\echo
\echo === 08. CURRENT RUN / STAGE STATE ===

SELECT
    r.run_id,
    r.status AS run_status,
    r.current_stage,
    r.attempt AS run_attempt,
    s.stage_id,
    s.stage_name,
    s.stage_order,
    s.status AS stage_status,
    s.attempt AS stage_attempt,
    s.retryable,
    s.error_code,
    s.error_message,
    s.idempotency_key
FROM public.production_run r
LEFT JOIN public.production_stage s
    ON s.run_id = r.run_id
ORDER BY r.run_id, s.stage_order, s.stage_id;

\echo
\echo === 09. RUNS WITH MULTIPLE ERROR STAGES ===

SELECT
    run_id,
    COUNT(*) AS error_stage_count,
    ARRAY_AGG(
        stage_id
        ORDER BY stage_order, stage_id
    ) AS error_stage_ids
FROM public.production_stage
WHERE status = 'ERROR'
GROUP BY run_id
HAVING COUNT(*) > 1
ORDER BY run_id;

\echo
\echo === 10. CURRENT ERROR STAGE DETAIL ===

SELECT
    stage_id,
    run_id,
    stage_name,
    stage_order,
    status,
    attempt,
    retryable,
    error_code,
    error_message,
    started_at,
    completed_at,
    idempotency_key
FROM public.production_stage
WHERE status = 'ERROR'
ORDER BY run_id, stage_order, stage_id;

\echo
\echo === 11. FAIL_STAGE_ATOMICALLY SOURCE ===

SELECT
    pg_get_functiondef(p.oid)
FROM pg_proc p
JOIN pg_namespace n
    ON n.oid = p.pronamespace
WHERE n.nspname = 'public'
  AND p.prokind = 'f'
  AND p.proname = 'fail_stage_atomically';

\echo
\echo === 12. REQUEST_RUN_TRANSITION SOURCE ===

SELECT
    pg_get_functiondef(p.oid)
FROM pg_proc p
JOIN pg_namespace n
    ON n.oid = p.pronamespace
WHERE n.nspname = 'public'
  AND p.prokind = 'f'
  AND p.proname = 'request_run_transition';

\echo
\echo === 13. VALIDATE_RUN_STAGE_CONSISTENCY SOURCE ===

SELECT
    pg_get_functiondef(p.oid)
FROM pg_proc p
JOIN pg_namespace n
    ON n.oid = p.pronamespace
WHERE n.nspname = 'public'
  AND p.prokind = 'f'
  AND p.proname = 'validate_run_stage_consistency';

\echo
\echo === 14. EXISTING FAIL_RUN_ATOMICALLY ===

SELECT
    n.nspname AS schema_name,
    p.proname,
    pg_get_function_identity_arguments(p.oid) AS arguments,
    pg_get_function_result(p.oid) AS result_type
FROM pg_proc p
JOIN pg_namespace n
    ON n.oid = p.pronamespace
WHERE n.nspname = 'public'
  AND p.prokind = 'f'
  AND p.proname = 'fail_run_atomically';

\echo
\echo === 15. FUNCTIONS REFERENCING RUN ERROR FIELDS ===

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
       pg_get_functiondef(p.oid) ILIKE '%error_code%'
       OR pg_get_functiondef(p.oid) ILIKE '%error_message%'
  )
ORDER BY p.proname;

\echo
\echo === 16. RUN ERROR CONSISTENCY INVARIANT ===

SELECT
    CASE
        WHEN pg_get_functiondef(p.oid)
             ILIKE '%RUN_ERROR_WITHOUT_STAGE_ERROR%'
        THEN 'PASS'
        ELSE 'FAIL'
    END AS run_error_requires_stage_error
FROM pg_proc p
JOIN pg_namespace n
    ON n.oid = p.pronamespace
WHERE n.nspname = 'public'
  AND p.prokind = 'f'
  AND p.proname = 'validate_run_stage_consistency';

\echo
\echo === 17. CURRENT ERROR COUNTS ===

SELECT
    (
        SELECT COUNT(*)
        FROM public.production_run
        WHERE status = 'ERROR'
    ) AS current_error_runs,

    (
        SELECT COUNT(*)
        FROM public.production_stage
        WHERE status = 'ERROR'
    ) AS current_error_stages,

    (
        SELECT COUNT(*)
        FROM public.production_stage
        WHERE status = 'ERROR'
          AND retryable = true
    ) AS current_retryable_error_stages,

    (
        SELECT COUNT(*)
        FROM public.production_stage
        WHERE status = 'ERROR'
          AND retryable = false
    ) AS current_terminal_error_stages;

\echo
\echo === 18. CONTRACT QUESTIONS - OBSERVABLE FACTS ===

SELECT
    'RUN_ERROR_REQUIRES_STAGE_ERROR' AS contract_question,
    CASE
        WHEN EXISTS (
            SELECT 1
            FROM pg_proc p
            JOIN pg_namespace n ON n.oid = p.pronamespace
            WHERE n.nspname = 'public'
              AND p.prokind = 'f'
              AND p.proname = 'validate_run_stage_consistency'
              AND pg_get_functiondef(p.oid)
                  ILIKE '%RUN_ERROR_WITHOUT_STAGE_ERROR%'
        )
        THEN 'YES'
        ELSE 'NO'
    END AS observed_value

UNION ALL

SELECT
    'FAIL_RUN_ATOMICALLY_ALREADY_EXISTS',
    CASE
        WHEN EXISTS (
            SELECT 1
            FROM pg_proc p
            JOIN pg_namespace n ON n.oid = p.pronamespace
            WHERE n.nspname = 'public'
              AND p.prokind = 'f'
              AND p.proname = 'fail_run_atomically'
        )
        THEN 'YES'
        ELSE 'NO'
    END

UNION ALL

SELECT
    'CURRENT_ERROR_RUNS',
    (
        SELECT COUNT(*)::text
        FROM public.production_run
        WHERE status = 'ERROR'
    )

UNION ALL

SELECT
    'CURRENT_ERROR_STAGES',
    (
        SELECT COUNT(*)::text
        FROM public.production_stage
        WHERE status = 'ERROR'
    );

\echo
\echo ============================================================
\echo 11-E.27 END - READ ONLY
\echo ============================================================
