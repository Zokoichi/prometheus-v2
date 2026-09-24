\set ON_ERROR_STOP on
\pset pager off

\echo ============================================================
\echo 11-E.26
\echo RUN ERROR ESCALATION FORENSICS
\echo READ ONLY
\echo ============================================================

\echo
\echo === 01. RUN ERROR COLUMNS ===

SELECT
    column_name,
    data_type,
    is_nullable,
    column_default
FROM information_schema.columns
WHERE table_schema = 'public'
  AND table_name = 'production_run'
  AND column_name IN (
      'status',
      'current_stage',
      'error_code',
      'error_message',
      'attempt',
      'output_json',
      'updated_at'
  )
ORDER BY ordinal_position;

\echo
\echo === 02. FUNCTIONS REFERENCING production_run.error_code ===

SELECT
    n.nspname AS schema_name,
    p.proname,
    pg_get_function_identity_arguments(p.oid) AS arguments
FROM pg_proc p
JOIN pg_namespace n
    ON n.oid = p.pronamespace
WHERE n.nspname = 'public'
  AND p.prokind = 'f'
  AND pg_get_functiondef(p.oid) ILIKE '%production_run%'
  AND pg_get_functiondef(p.oid) ILIKE '%error_code%'
ORDER BY p.proname;

\echo
\echo === 03. FUNCTIONS WRITING production_run ===

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
       pg_get_functiondef(p.oid) ILIKE '%UPDATE public.production_run%'
       OR pg_get_functiondef(p.oid) ILIKE '%INSERT INTO public.production_run%'
       OR pg_get_functiondef(p.oid) ILIKE '%DELETE FROM public.production_run%'
  )
ORDER BY p.proname;

\echo
\echo === 04. FUNCTIONS REFERENCING request_run_transition ===

SELECT
    n.nspname AS schema_name,
    p.proname,
    pg_get_function_identity_arguments(p.oid) AS arguments
FROM pg_proc p
JOIN pg_namespace n
    ON n.oid = p.pronamespace
WHERE n.nspname = 'public'
  AND p.prokind = 'f'
  AND pg_get_functiondef(p.oid) ILIKE '%request_run_transition%'
ORDER BY p.proname;

\echo
\echo === 05. FUNCTIONS REFERENCING validate_run_stage_consistency ===

SELECT
    n.nspname AS schema_name,
    p.proname,
    pg_get_function_identity_arguments(p.oid) AS arguments
FROM pg_proc p
JOIN pg_namespace n
    ON n.oid = p.pronamespace
  AND p.prokind = 'f'
WHERE n.nspname = 'public'
  AND pg_get_functiondef(p.oid) ILIKE '%validate_run_stage_consistency%'
ORDER BY p.proname;

\echo
\echo === 06. FUNCTIONS REFERENCING production_run_event ===

SELECT
    n.nspname AS schema_name,
    p.proname,
    pg_get_function_identity_arguments(p.oid) AS arguments
FROM pg_proc p
JOIN pg_namespace n
    ON n.oid = p.pronamespace
  AND p.prokind = 'f'
  AND pg_get_functiondef(p.oid) ILIKE '%production_run_event%'
WHERE n.nspname = 'public'
ORDER BY p.proname;

\echo
\echo === 07. FUNCTIONS WITH RUN ERROR TRANSITION ===

SELECT
    n.nspname AS schema_name,
    p.proname,
    pg_get_function_identity_arguments(p.oid) AS arguments
FROM pg_proc p
JOIN pg_namespace n
    ON n.oid = p.pronamespace
  AND p.prokind = 'f'
  AND (
       pg_get_functiondef(p.oid) ILIKE '%to_status = ''ERROR''%'
       OR pg_get_functiondef(p.oid) ILIKE '%status = ''ERROR''%'
       OR pg_get_functiondef(p.oid) ILIKE '%''ERROR''%'
  )
WHERE n.nspname = 'public'
ORDER BY p.proname;

\echo
\echo === 08. CURRENT RUN ERROR SNAPSHOT ===

SELECT
    run_id,
    status,
    current_stage,
    attempt,
    error_code,
    error_message
FROM public.production_run
WHERE status = 'ERROR'
   OR error_code IS NOT NULL
   OR error_message IS NOT NULL
ORDER BY run_id;

\echo
\echo === 09. HISTORICAL RUN ERROR EVENTS ===

SELECT
    id,
    run_id,
    event_type,
    from_status,
    to_status,
    stage_name,
    attempt,
    event_data,
    created_at
FROM public.production_run_event
WHERE from_status = 'ERROR'
   OR to_status = 'ERROR'
   OR event_type IN ('ERROR', 'STAGE_ERROR', 'RETRY')
ORDER BY id;

\echo
\echo === 10. STAGE ERROR -> RUN ERROR CORRELATION ===

SELECT
    se.run_id,
    COUNT(*) AS stage_error_events,
    COUNT(*) FILTER (
        WHERE se.to_status = 'ERROR'
    ) AS stage_error_transitions,
    COUNT(*) FILTER (
        WHERE se.event_type = 'STAGE_ERROR'
    ) AS explicit_stage_error_events,
    COUNT(re.run_id) AS matching_run_error_events
FROM public.production_stage_event se
LEFT JOIN public.production_run_event re
    ON re.run_id = se.run_id
   AND (
        re.to_status = 'ERROR'
        OR re.event_type = 'ERROR'
        OR re.event_type = 'STAGE_ERROR'
   )
WHERE se.event_type = 'STAGE_ERROR'
GROUP BY se.run_id
ORDER BY se.run_id;

\echo
\echo === 11. RUN ERROR CONSISTENCY FUNCTION SOURCE ===

SELECT
    pg_get_functiondef(p.oid)
FROM pg_proc p
JOIN pg_namespace n
    ON n.oid = p.pronamespace
WHERE n.nspname = 'public'
  AND p.prokind = 'f'
  AND p.proname = 'validate_run_stage_consistency';

\echo
\echo === 12. REQUEST RUN TRANSITION SOURCE ===

SELECT
    pg_get_functiondef(p.oid)
FROM pg_proc p
JOIN pg_namespace n
    ON n.oid = p.pronamespace
WHERE n.nspname = 'public'
  AND p.prokind = 'f'
  AND p.proname = 'request_run_transition';

\echo
\echo === 13. SUMMARY COUNTS ===

SELECT
    (
        SELECT COUNT(*)
        FROM pg_proc p
        JOIN pg_namespace n ON n.oid = p.pronamespace
        WHERE n.nspname = 'public'
          AND p.prokind = 'f'
          AND pg_get_functiondef(p.oid) ILIKE '%UPDATE public.production_run%'
    ) AS run_update_function_count,

    (
        SELECT COUNT(*)
        FROM pg_proc p
        JOIN pg_namespace n ON n.oid = p.pronamespace
        WHERE n.nspname = 'public'
          AND p.prokind = 'f'
          AND pg_get_functiondef(p.oid) ILIKE '%production_run.error_code%'
    ) AS explicit_error_code_reference_count,

    (
        SELECT COUNT(*)
        FROM public.production_run
        WHERE status = 'ERROR'
    ) AS current_error_runs,

    (
        SELECT COUNT(*)
        FROM public.production_stage
        WHERE status = 'ERROR'
    ) AS current_error_stages;

\echo
\echo ============================================================
\echo 11-E.26 END - READ ONLY
\echo ============================================================
