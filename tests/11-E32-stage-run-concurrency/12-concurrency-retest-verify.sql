\set ON_ERROR_STOP on
\pset pager off

\echo ============================================================
\echo 11-E.32-FIX-RETEST VERIFY
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
FROM production_run
WHERE run_id = 'RUN-11E32-FIX-RETEST';

\echo
\echo === 02. STAGE STATE ===

SELECT
    stage_id,
    run_id,
    status,
    attempt,
    retryable,
    error_code,
    error_message,
    idempotency_key
FROM production_stage
WHERE stage_id = 'STG-11E32-FIX-RETEST';

\echo
\echo === 03. RUN ERROR EVENTS ===

SELECT
    COUNT(*) AS run_error_event_count
FROM production_run_event
WHERE run_id = 'RUN-11E32-FIX-RETEST'
  AND event_type = 'RUN_ERROR';

\echo
\echo === 04. STAGE ERROR EVENTS ===

SELECT
    COUNT(*) AS stage_error_event_count
FROM production_stage_event
WHERE run_id = 'RUN-11E32-FIX-RETEST'
  AND event_type = 'STAGE_ERROR';

\echo
\echo === 05. EVENT DETAILS ===

SELECT
    id,
    event_type,
    from_status,
    to_status,
    stage,
    attempt,
    event_data
FROM production_run_event
WHERE run_id = 'RUN-11E32-FIX-RETEST'
ORDER BY id;

SELECT
    id,
    event_type,
    from_status,
    to_status,
    stage_name,
    attempt,
    event_data
FROM production_stage_event
WHERE run_id = 'RUN-11E32-FIX-RETEST'
ORDER BY id;

\echo
\echo === 06. CONSISTENCY ===

SELECT *
FROM public.validate_run_stage_consistency(
    'RUN-11E32-FIX-RETEST'
);

\echo
\echo === 07. GLOBAL ERROR STATE ===

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
FROM production_stage
WHERE run_id <> 'RUN-11E32-FIX-RETEST';

SELECT
    COUNT(*) FILTER (WHERE status = 'ERROR') AS error_runs
FROM production_run
WHERE run_id <> 'RUN-11E32-FIX-RETEST';

\echo
\echo ============================================================
\echo VERIFY END
\echo ============================================================
