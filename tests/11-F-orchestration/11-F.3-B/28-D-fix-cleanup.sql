\set ON_ERROR_STOP on

SELECT
    pr.run_id,
    pr.status AS run_status,
    ps.stage_id,
    ps.status AS stage_status,
    ps.attempt,
    ps.retryable,
    ps.error_code
FROM public.production_run pr
JOIN public.production_stage ps
  ON ps.run_id=pr.run_id
WHERE pr.run_id='RUN-11F3B-D-FIX';

SELECT
    'STAGE_EVENTS' AS metric,
    count(*)
FROM public.production_stage_event
WHERE run_id='RUN-11F3B-D-FIX';

BEGIN;

DELETE FROM public.production_stage_event
WHERE run_id='RUN-11F3B-D-FIX';

DELETE FROM public.artifact_registry
WHERE run_id='RUN-11F3B-D-FIX';

DELETE FROM public.production_stage
WHERE run_id='RUN-11F3B-D-FIX';

DELETE FROM public.production_run
WHERE run_id='RUN-11F3B-D-FIX';

COMMIT;

SELECT
    'RUNS_REMAINING' AS metric,
    count(*)
FROM public.production_run
WHERE run_id='RUN-11F3B-D-FIX';

SELECT
    'STAGES_REMAINING' AS metric,
    count(*)
FROM public.production_stage
WHERE run_id='RUN-11F3B-D-FIX';

SELECT
    'ARTIFACTS_REMAINING' AS metric,
    count(*)
FROM public.artifact_registry
WHERE run_id='RUN-11F3B-D-FIX';
