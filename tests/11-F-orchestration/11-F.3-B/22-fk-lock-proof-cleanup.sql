\set ON_ERROR_STOP on

BEGIN;

DELETE FROM public.production_stage_event
WHERE run_id='RUN-11F3B-FK';

DELETE FROM public.production_stage
WHERE run_id='RUN-11F3B-FK';

DELETE FROM public.production_run
WHERE run_id='RUN-11F3B-FK';

COMMIT;

SELECT
    'RUNS_REMAINING' AS metric,
    count(*)
FROM public.production_run
WHERE run_id='RUN-11F3B-FK';

SELECT
    'STAGES_REMAINING' AS metric,
    count(*)
FROM public.production_stage
WHERE run_id='RUN-11F3B-FK';

SELECT
    'EVENTS_REMAINING' AS metric,
    count(*)
FROM public.production_stage_event
WHERE run_id='RUN-11F3B-FK';
