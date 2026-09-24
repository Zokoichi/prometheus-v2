\set ON_ERROR_STOP on
\pset pager off

\echo ============================================================
\echo 11-E.29-R
\echo FAIL_RUN_ATOMICALLY POST-INSTALL VERIFY
\echo READ ONLY
\echo ============================================================

\echo
\echo === 01. FUNCTION COUNT ===

SELECT
    COUNT(*) AS fail_run_function_count
FROM pg_proc p
JOIN pg_namespace n
    ON n.oid = p.pronamespace
WHERE n.nspname = 'public'
  AND p.prokind = 'f'
  AND p.proname = 'fail_run_atomically';

\echo
\echo === 02. FUNCTION SIGNATURE ===

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
\echo === 03. SOURCE INTEGRITY ===

WITH f AS (
    SELECT pg_get_functiondef(p.oid) AS source
    FROM pg_proc p
    JOIN pg_namespace n
        ON n.oid = p.pronamespace
    WHERE n.nspname = 'public'
      AND p.prokind = 'f'
      AND p.proname = 'fail_run_atomically'
)
SELECT
    CASE
        WHEN source ILIKE '%FOR UPDATE%'
        THEN 'LOCK_RUN_AND_STAGE=PASS'
        ELSE 'LOCK_RUN_AND_STAGE=FAIL'
    END AS lock_check,

    CASE
        WHEN source ILIKE '%RUN_ALREADY_ERROR%'
        THEN 'IDEMPOTENCE=PASS'
        ELSE 'IDEMPOTENCE=FAIL'
    END AS idempotence_check,

    CASE
        WHEN source ILIKE '%STAGE_STILL_RETRYABLE%'
        THEN 'RETRYABLE_STAGE_GUARD=PASS'
        ELSE 'RETRYABLE_STAGE_GUARD=FAIL'
    END AS retryable_guard_check,

    CASE
        WHEN source ILIKE '%STAGE_NOT_ERROR%'
        THEN 'STAGE_ERROR_GUARD=PASS'
        ELSE 'STAGE_ERROR_GUARD=FAIL'
    END AS stage_error_guard_check,

    CASE
        WHEN source ILIKE '%error_code = v_stage_error_code%'
        THEN 'ERROR_CODE_PROPAGATION=PASS'
        ELSE 'ERROR_CODE_PROPAGATION=FAIL'
    END AS error_code_propagation,

    CASE
        WHEN source ILIKE '%error_message = v_stage_error_message%'
        THEN 'ERROR_MESSAGE_PROPAGATION=PASS'
        ELSE 'ERROR_MESSAGE_PROPAGATION=FAIL'
    END AS error_message_propagation,

    CASE
        WHEN source ILIKE '%validate_run_stage_consistency%'
        THEN 'CONSISTENCY_GUARD=PASS'
        ELSE 'CONSISTENCY_GUARD=FAIL'
    END AS consistency_guard,

    CASE
        WHEN source ILIKE '%INSERT INTO public.production_run_event%'
        THEN 'RUN_EVENT=PASS'
        ELSE 'RUN_EVENT=FAIL'
    END AS run_event_check,

    CASE
        WHEN source ILIKE '%status = ''ERROR''%'
        THEN 'RUN_ERROR_STATE=PASS'
        ELSE 'RUN_ERROR_STATE=FAIL'
    END AS run_error_state_check

FROM f;

\echo
\echo === 04. FUNCTION DEPENDENCIES ===

SELECT
    p.proname AS dependent_function,
    pg_get_function_identity_arguments(p.oid) AS arguments,
    CASE
        WHEN pg_get_functiondef(p.oid) ILIKE '%validate_run_stage_consistency%'
        THEN 'VALIDATES_RUN_STAGE=YES'
        ELSE 'VALIDATES_RUN_STAGE=NO'
    END AS consistency_dependency
FROM pg_proc p
JOIN pg_namespace n
    ON n.oid = p.pronamespace
WHERE n.nspname = 'public'
  AND p.prokind = 'f'
  AND p.proname = 'fail_run_atomically';

\echo
\echo === 05. CURRENT RUN ERROR STATE ===

SELECT
    COUNT(*) AS current_error_runs
FROM public.production_run
WHERE status = 'ERROR';

\echo
\echo === 06. CURRENT STAGE ERROR STATE ===

SELECT
    COUNT(*) AS current_error_stages,
    COUNT(*) FILTER (
        WHERE retryable = TRUE
    ) AS current_retryable_error_stages,
    COUNT(*) FILTER (
        WHERE retryable = FALSE
    ) AS current_terminal_error_stages
FROM public.production_stage
WHERE status = 'ERROR';

\echo
\echo === 07. CURRENT RUNS WITH ERROR FIELDS ===

SELECT
    run_id,
    status,
    current_stage,
    attempt,
    error_code,
    error_message
FROM public.production_run
WHERE error_code IS NOT NULL
   OR error_message IS NOT NULL
ORDER BY run_id;

\echo
\echo === 08. FUNCTION SOURCE SHA256 ===

SELECT
    encode(
        digest(
            pg_get_functiondef(p.oid),
            'sha256'
        ),
        'hex'
    ) AS function_source_sha256
FROM pg_proc p
JOIN pg_namespace n
    ON n.oid = p.pronamespace
WHERE n.nspname = 'public'
  AND p.prokind = 'f'
  AND p.proname = 'fail_run_atomically';

\echo
\echo === 09. FINAL ASSERTIONS ===

WITH
function_check AS (
    SELECT COUNT(*) AS c
    FROM pg_proc p
    JOIN pg_namespace n ON n.oid = p.pronamespace
    WHERE n.nspname = 'public'
      AND p.prokind = 'f'
      AND p.proname = 'fail_run_atomically'
),
error_run_check AS (
    SELECT COUNT(*) AS c
    FROM public.production_run
    WHERE status = 'ERROR'
),
error_stage_check AS (
    SELECT COUNT(*) AS c
    FROM public.production_stage
    WHERE status = 'ERROR'
)
SELECT
    CASE
        WHEN (SELECT c FROM function_check) = 1
        THEN 'FUNCTION_INSTALLED=PASS'
        ELSE 'FUNCTION_INSTALLED=FAIL'
    END,

    CASE
        WHEN (SELECT c FROM error_run_check) = 0
        THEN 'CURRENT_RUN_ERROR_STATE=PASS'
        ELSE 'CURRENT_RUN_ERROR_STATE=FAIL'
    END,

    CASE
        WHEN (SELECT c FROM error_stage_check) = 0
        THEN 'CURRENT_STAGE_ERROR_STATE=PASS'
        ELSE 'CURRENT_STAGE_ERROR_STATE=FAIL'
    END;

\echo
\echo ============================================================
\echo 11-E.29-R END
\echo READ ONLY
\echo ============================================================
