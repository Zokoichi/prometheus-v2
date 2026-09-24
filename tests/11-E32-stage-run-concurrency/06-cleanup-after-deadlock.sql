\set ON_ERROR_STOP on
\pset pager off

\echo ============================================================
\echo 11-E.32-CLEANUP
\echo CLEANUP AFTER REAL DEADLOCK
\echo ============================================================

\echo
\echo === 01. BEFORE CLEANUP ===

SELECT
    (SELECT COUNT(*)
     FROM public.production_run
     WHERE run_id = 'RUN-11E32-FIXTURE') AS fixture_run_count,

    (SELECT COUNT(*)
     FROM public.production_stage
     WHERE stage_id = 'STG-11E32-FIXTURE') AS fixture_stage_count,

    (SELECT COUNT(*)
     FROM public.production_run_event
     WHERE run_id = 'RUN-11E32-FIXTURE') AS fixture_run_event_count,

    (SELECT COUNT(*)
     FROM public.production_stage_event
     WHERE run_id = 'RUN-11E32-FIXTURE') AS fixture_stage_event_count;

\echo
\echo === 02. CURRENT FIXTURE STATE ===

SELECT
    r.run_id,
    r.status AS run_status,
    r.current_stage,
    r.error_code AS run_error_code,
    s.stage_id,
    s.status AS stage_status,
    s.attempt,
    s.retryable,
    s.error_code AS stage_error_code
FROM public.production_run r
LEFT JOIN public.production_stage s
    ON s.run_id = r.run_id
WHERE r.run_id = 'RUN-11E32-FIXTURE';

\echo
\echo === 03. DELETE EVENTS ===

DELETE FROM public.production_stage_event
WHERE run_id = 'RUN-11E32-FIXTURE';

DELETE FROM public.production_run_event
WHERE run_id = 'RUN-11E32-FIXTURE';

\echo
\echo === 04. DELETE STAGE ===

DELETE FROM public.production_stage
WHERE stage_id = 'STG-11E32-FIXTURE';

\echo
\echo === 05. DELETE RUN ===

DELETE FROM public.production_run
WHERE run_id = 'RUN-11E32-FIXTURE';

\echo
\echo === 06. AFTER CLEANUP ===

SELECT
    (SELECT COUNT(*)
     FROM public.production_run
     WHERE run_id = 'RUN-11E32-FIXTURE') AS fixture_run_count,

    (SELECT COUNT(*)
     FROM public.production_stage
     WHERE stage_id = 'STG-11E32-FIXTURE') AS fixture_stage_count,

    (SELECT COUNT(*)
     FROM public.production_run_event
     WHERE run_id = 'RUN-11E32-FIXTURE') AS fixture_run_event_count,

    (SELECT COUNT(*)
     FROM public.production_stage_event
     WHERE run_id = 'RUN-11E32-FIXTURE') AS fixture_stage_event_count;

\echo
\echo ============================================================
\echo 11-E.32-CLEANUP END
\echo ============================================================
