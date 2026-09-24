\set ON_ERROR_STOP on
\pset pager off

BEGIN;

DELETE FROM public.production_run_event
WHERE run_id = 'RUN-11E31-FIXTURE';

DELETE FROM public.production_stage
WHERE stage_id = 'STG-11E31-FIXTURE';

DELETE FROM public.production_run
WHERE run_id = 'RUN-11E31-FIXTURE';

COMMIT;

SELECT
    (SELECT COUNT(*)
     FROM public.production_run
     WHERE run_id = 'RUN-11E31-FIXTURE') AS fixture_run_count,

    (SELECT COUNT(*)
     FROM public.production_stage
     WHERE stage_id = 'STG-11E31-FIXTURE') AS fixture_stage_count,

    (SELECT COUNT(*)
     FROM public.production_run_event
     WHERE run_id = 'RUN-11E31-FIXTURE') AS fixture_event_count;
