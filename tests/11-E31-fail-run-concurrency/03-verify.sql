\set ON_ERROR_STOP on
\pset pager off

\echo ============================================================
\echo 11-E.31
\echo CONCURRENCY / IDEMPOTENCE VERIFY
\echo ============================================================

\echo
\echo === 01. RUN STATE ===

SELECT
    run_id,
    status,
    current_stage,
    attempt,
    error_code,
    error_message
FROM public.production_run
WHERE run_id = 'RUN-11E31-FIXTURE';

\echo
\echo === 02. STAGE STATE ===

SELECT
    stage_id,
    run_id,
    stage_name,
    status,
    attempt,
    retryable,
    error_code,
    error_message
FROM public.production_stage
WHERE stage_id = 'STG-11E31-FIXTURE';

\echo
\echo === 03. RUN ERROR EVENT COUNT ===

SELECT
    COUNT(*) AS run_error_event_count
FROM public.production_run_event
WHERE run_id = 'RUN-11E31-FIXTURE'
  AND event_type = 'RUN_ERROR';

\echo
\echo === 04. ALL RUN EVENTS ===

SELECT
    id,
    run_id,
    event_type,
    from_status,
    to_status,
    stage,
    attempt,
    event_data
FROM public.production_run_event
WHERE run_id = 'RUN-11E31-FIXTURE'
ORDER BY id;

\echo
\echo === 05. CONSISTENCY ===

SELECT *
FROM public.validate_run_stage_consistency(
    'RUN-11E31-FIXTURE'
);

\echo
\echo === 06. FINAL ASSERTIONS ===

SELECT
    CASE
        WHEN (
            SELECT status
            FROM public.production_run
            WHERE run_id = 'RUN-11E31-FIXTURE'
        ) = 'ERROR'
        THEN 'RUN_ERROR=PASS'
        ELSE 'RUN_ERROR=FAIL'
    END AS run_state,

    CASE
        WHEN (
            SELECT COUNT(*)
            FROM public.production_run_event
            WHERE run_id = 'RUN-11E31-FIXTURE'
              AND event_type = 'RUN_ERROR'
        ) = 1
        THEN 'SINGLE_RUN_ERROR_EVENT=PASS'
        ELSE 'SINGLE_RUN_ERROR_EVENT=FAIL'
    END AS event_count,

    CASE
        WHEN (
            SELECT COUNT(*)
            FROM public.production_stage
            WHERE stage_id = 'STG-11E31-FIXTURE'
              AND status = 'ERROR'
              AND retryable = FALSE
        ) = 1
        THEN 'TERMINAL_STAGE=PASS'
        ELSE 'TERMINAL_STAGE=FAIL'
    END AS stage_state;

\echo
\echo ============================================================
\echo 11-E.31 VERIFY END
\echo ============================================================
