\set ON_ERROR_STOP on
\pset pager off

\echo ============================================================
\echo 11-E.32
\echo STAGE <-> RUN CONCURRENCY VERIFY
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
WHERE run_id = 'RUN-11E32-FIXTURE';

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
WHERE stage_id = 'STG-11E32-FIXTURE';

\echo
\echo === 03. RUN ERROR EVENT COUNT ===

SELECT
    COUNT(*) AS run_error_event_count
FROM public.production_run_event
WHERE run_id = 'RUN-11E32-FIXTURE'
  AND event_type = 'RUN_ERROR';

\echo
\echo === 04. STAGE ERROR EVENT COUNT ===

SELECT
    COUNT(*) AS stage_error_event_count
FROM public.production_stage_event
WHERE run_id = 'RUN-11E32-FIXTURE'
  AND event_type = 'STAGE_ERROR';

\echo
\echo === 05. ALL RUN EVENTS ===

SELECT
    id,
    event_type,
    from_status,
    to_status,
    stage,
    attempt,
    event_data
FROM public.production_run_event
WHERE run_id = 'RUN-11E32-FIXTURE'
ORDER BY id;

\echo
\echo === 06. ALL STAGE EVENTS ===

SELECT
    id,
    event_type,
    from_status,
    to_status,
    stage_name,
    attempt,
    event_data
FROM public.production_stage_event
WHERE run_id = 'RUN-11E32-FIXTURE'
ORDER BY id;

\echo
\echo === 07. CONSISTENCY ===

SELECT *
FROM public.validate_run_stage_consistency(
    'RUN-11E32-FIXTURE'
);

\echo
\echo === 08. FINAL ASSERTIONS ===

SELECT
    CASE
        WHEN (
            SELECT status
            FROM public.production_run
            WHERE run_id = 'RUN-11E32-FIXTURE'
        ) = 'ERROR'
        THEN 'RUN_ERROR=PASS'
        ELSE 'RUN_ERROR=FAIL'
    END AS run_state,

    CASE
        WHEN (
            SELECT status
            FROM public.production_stage
            WHERE stage_id = 'STG-11E32-FIXTURE'
        ) = 'ERROR'
        THEN 'STAGE_ERROR=PASS'
        ELSE 'STAGE_ERROR=FAIL'
    END AS stage_state,

    CASE
        WHEN (
            SELECT COUNT(*)
            FROM public.production_run_event
            WHERE run_id = 'RUN-11E32-FIXTURE'
              AND event_type = 'RUN_ERROR'
        ) <= 1
        THEN 'MAX_ONE_RUN_ERROR_EVENT=PASS'
        ELSE 'MAX_ONE_RUN_ERROR_EVENT=FAIL'
    END AS run_event_count,

    CASE
        WHEN (
            SELECT COUNT(*)
            FROM public.production_stage_event
            WHERE run_id = 'RUN-11E32-FIXTURE'
              AND event_type = 'STAGE_ERROR'
        ) <= 1
        THEN 'MAX_ONE_STAGE_ERROR_EVENT=PASS'
        ELSE 'MAX_ONE_STAGE_ERROR_EVENT=FAIL'
    END AS stage_event_count;

\echo
\echo ============================================================
\echo 11-E.32 VERIFY END
\echo ============================================================
