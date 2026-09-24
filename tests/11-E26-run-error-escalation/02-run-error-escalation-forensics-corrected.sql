\set ON_ERROR_STOP on
\pset pager off

\echo ============================================================
\echo 11-E.26-R
\echo RUN ERROR ESCALATION FORENSICS - CORRECTED
\echo READ ONLY
\echo ============================================================

\echo
\echo === 01. PRODUCTION_RUN_EVENT COLUMNS ===

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
\echo === 02. FUNCTIONS WRITING PRODUCTION_RUN - SOURCE SEARCH ===

SELECT
    n.nspname AS schema_name,
    p.proname,
    pg_get_function_identity_arguments(p.oid) AS arguments,
    CASE
        WHEN pg_get_functiondef(p.oid) ILIKE '%UPDATE public.production_run%'
            THEN 'UPDATE_DIRECT'
        WHEN pg_get_functiondef(p.oid) ILIKE '%UPDATE production_run%'
            THEN 'UPDATE_UNQUALIFIED'
        WHEN pg_get_functiondef(p.oid) ILIKE '%production_run% SET%'
            THEN 'UPDATE_ALIAS_OR_INDIRECT'
        ELSE 'NO_DIRECT_UPDATE_PATTERN'
    END AS update_pattern
FROM pg_proc p
JOIN pg_namespace n
    ON n.oid = p.pronamespace
WHERE n.nspname = 'public'
  AND p.prokind = 'f'
  AND (
       pg_get_functiondef(p.oid) ILIKE '%UPDATE public.production_run%'
       OR pg_get_functiondef(p.oid) ILIKE '%UPDATE production_run%'
       OR pg_get_functiondef(p.oid) ILIKE '%production_run% SET%'
  )
ORDER BY p.proname;

\echo
\echo === 03. REQUEST_RUN_TRANSITION SOURCE ===

SELECT
    pg_get_functiondef(p.oid)
FROM pg_proc p
JOIN pg_namespace n
    ON n.oid = p.pronamespace
WHERE n.nspname = 'public'
  AND p.prokind = 'f'
  AND p.proname = 'request_run_transition';

\echo
\echo === 04. CURRENT RUN ERROR SNAPSHOT ===

SELECT
    run_id,
    project_id,
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
\echo === 05. HISTORICAL RUN ERROR / RETRY EVENTS ===

SELECT
    id,
    run_id,
    event_type,
    from_status,
    to_status,
    attempt,
    event_data,
    created_at
FROM public.production_run_event
WHERE from_status = 'ERROR'
   OR to_status = 'ERROR'
   OR event_type IN ('ERROR', 'STAGE_ERROR', 'RETRY')
ORDER BY id;

\echo
\echo === 06. STAGE ERROR EVENTS ===

SELECT
    id,
    stage_id,
    run_id,
    event_type,
    from_status,
    to_status,
    stage_name,
    attempt,
    event_data,
    created_at
FROM public.production_stage_event
WHERE event_type = 'STAGE_ERROR'
ORDER BY id;

\echo
\echo === 07. STAGE_ERROR -> RUN ERROR CORRELATION ===

SELECT
    se.run_id,
    COUNT(*) AS stage_error_events,
    COUNT(*) FILTER (
        WHERE se.to_status = 'ERROR'
    ) AS stage_error_transitions,
    COUNT(re.id) AS matching_run_error_events
FROM public.production_stage_event se
LEFT JOIN public.production_run_event re
    ON re.run_id = se.run_id
   AND (
        re.to_status = 'ERROR'
        OR re.event_type IN ('ERROR', 'STAGE_ERROR')
   )
WHERE se.event_type = 'STAGE_ERROR'
GROUP BY se.run_id
ORDER BY se.run_id;

\echo
\echo === 08. RUN ERROR EVENTS WITHOUT STAGE ERROR ===

SELECT
    re.id,
    re.run_id,
    re.event_type,
    re.from_status,
    re.to_status,
    re.attempt,
    re.event_data,
    (
        SELECT COUNT(*)
        FROM public.production_stage_event se
        WHERE se.run_id = re.run_id
          AND se.event_type = 'STAGE_ERROR'
    ) AS stage_error_event_count
FROM public.production_run_event re
WHERE re.to_status = 'ERROR'
   OR re.event_type = 'ERROR'
ORDER BY re.id;

\echo
\echo === 09. REQUEST_RUN_TRANSITION ERROR CONTRACT ===

SELECT
    CASE
        WHEN pg_get_functiondef(p.oid) ILIKE '%p_to_status = ''ERROR''%'
          OR pg_get_functiondef(p.oid) ILIKE '%p_to_status=''ERROR''%'
        THEN 'ERROR_TRANSITION_REFERENCE=PASS'
        ELSE 'ERROR_TRANSITION_REFERENCE=FAIL'
    END AS transition_reference,
    CASE
        WHEN pg_get_functiondef(p.oid) ILIKE '%error_code%'
        THEN 'ERROR_CODE_REFERENCE=PASS'
        ELSE 'ERROR_CODE_REFERENCE=FAIL'
    END AS error_code_reference,
    CASE
        WHEN pg_get_functiondef(p.oid) ILIKE '%error_message%'
        THEN 'ERROR_MESSAGE_REFERENCE=PASS'
        ELSE 'ERROR_MESSAGE_REFERENCE=FAIL'
    END AS error_message_reference
FROM pg_proc p
JOIN pg_namespace n
    ON n.oid = p.pronamespace
WHERE n.nspname = 'public'
  AND p.prokind = 'f'
  AND p.proname = 'request_run_transition';

\echo
\echo === 10. VALIDATE_RUN_STAGE_CONSISTENCY ERROR INVARIANT ===

SELECT
    CASE
        WHEN pg_get_functiondef(p.oid) ILIKE '%RUN_ERROR_WITHOUT_STAGE_ERROR%'
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
\echo === 11. FUNCTIONS CALLING REQUEST_RUN_TRANSITION ===

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
\echo === 12. FUNCTIONS WRITING PRODUCTION_RUN_EVENT ===

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
       pg_get_functiondef(p.oid) ILIKE '%INSERT INTO public.production_run_event%'
       OR pg_get_functiondef(p.oid) ILIKE '%INSERT INTO production_run_event%'
  )
ORDER BY p.proname;

\echo
\echo === 13. CURRENT GLOBAL ERROR STATE ===

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
\echo ============================================================
\echo 11-E.26-R END - READ ONLY
\echo ============================================================
