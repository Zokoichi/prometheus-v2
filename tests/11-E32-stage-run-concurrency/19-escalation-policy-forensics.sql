\set ON_ERROR_STOP on
\pset pager off

\echo ============================================================
\echo 11-E.32-DIAG
\echo ESCALATION POLICY FORENSICS
\echo READ ONLY
\echo ============================================================

\echo
\echo === 01. FAIL_RUN_ATOMICALLY SOURCE ===

SELECT pg_get_functiondef(
    'public.fail_run_atomically(character varying,character varying,character varying,jsonb)'::regprocedure
);

\echo
\echo === 02. VALIDATE_RUN_STAGE_CONSISTENCY SOURCE ===

SELECT pg_get_functiondef(
    'public.validate_run_stage_consistency(character varying)'::regprocedure
);

\echo
\echo === 03. STAGE ERROR POLICY ===

SELECT
    error_code,
    category,
    retryable,
    max_attempts,
    initial_backoff_seconds,
    backoff_multiplier,
    max_backoff_seconds,
    enabled
FROM error_policy
ORDER BY error_code;

\echo
\echo === 04. FAIL_RUN SOURCE MARKERS ===

SELECT
    position('STAGE_STILL_RETRYABLE' in pg_get_functiondef(
        'public.fail_run_atomically(character varying,character varying,character varying,jsonb)'::regprocedure
    )) AS stage_still_retryable_pos,

    position('retryable' in lower(pg_get_functiondef(
        'public.fail_run_atomically(character varying,character varying,character varying,jsonb)'::regprocedure
    ))) AS retryable_pos,

    position('RUN_ALREADY_ERROR' in pg_get_functiondef(
        'public.fail_run_atomically(character varying,character varying,character varying,jsonb)'::regprocedure
    )) AS already_error_pos,

    position('STAGE_ERROR' in pg_get_functiondef(
        'public.fail_run_atomically(character varying,character varying,character varying,jsonb)'::regprocedure
    )) AS stage_error_pos,

    position('RUN_ERROR' in pg_get_functiondef(
        'public.fail_run_atomically(character varying,character varying,character varying,jsonb)'::regprocedure
    )) AS run_error_pos;

\echo
\echo === 05. CONSISTENCY SOURCE MARKERS ===

SELECT
    position('RUN_STAGE_STATE_MISMATCH' in pg_get_functiondef(
        'public.validate_run_stage_consistency(character varying)'::regprocedure
    )) AS mismatch_pos,

    position('CREATED' in pg_get_functiondef(
        'public.validate_run_stage_consistency(character varying)'::regprocedure
    )) AS created_pos,

    position('ERROR' in pg_get_functiondef(
        'public.validate_run_stage_consistency(character varying)'::regprocedure
    )) AS error_pos,

    position('retryable' in lower(pg_get_functiondef(
        'public.validate_run_stage_consistency(character varying)'::regprocedure
    ))) AS retryable_pos;

\echo
\echo === 06. FUNCTION SIGNATURES ===

SELECT
    n.nspname AS schema_name,
    p.proname,
    pg_get_function_identity_arguments(p.oid) AS arguments
FROM pg_proc p
JOIN pg_namespace n
  ON n.oid = p.pronamespace
WHERE n.nspname = 'public'
  AND p.proname IN (
      'fail_run_atomically',
      'fail_stage_atomically',
      'validate_run_stage_consistency',
      'request_run_transition'
  )
ORDER BY p.proname;

\echo
\echo === 07. CURRENT DATABASE STATE ===

SELECT
    COUNT(*) FILTER (WHERE status = 'ERROR') AS error_stages,
    COUNT(*) FILTER (
        WHERE status = 'ERROR'
          AND retryable = TRUE
    ) AS retryable_error_stages,
    COUNT(*) FILTER (
        WHERE status = 'ERROR'
          AND retryable = FALSE
    ) AS terminal_error_stages
FROM production_stage;

SELECT
    COUNT(*) FILTER (WHERE status = 'ERROR') AS error_runs
FROM production_run;

\echo
\echo === 08. FIXTURE STATE ===

SELECT COUNT(*) AS fixture_runs
FROM production_run
WHERE run_id = 'RUN-11E32-FIX-RETEST-V3';

SELECT COUNT(*) AS fixture_stages
FROM production_stage
WHERE stage_id = 'STG-11E32-FIX-RETEST-V3';

\echo
\echo ============================================================
\echo 11-E.32-DIAG END
\echo ============================================================
