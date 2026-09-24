\set ON_ERROR_STOP on

DELETE FROM public.production_stage_event
WHERE run_id LIKE 'RUN-11F3B-%';

DELETE FROM public.production_execution_event
WHERE run_id LIKE 'RUN-11F3B-%';

DELETE FROM public.production_stage_dependency
WHERE stage_id LIKE 'STG-11F3B-%'
   OR depends_on_stage_id LIKE 'STG-11F3B-%';

DELETE FROM public.production_stage
WHERE stage_id LIKE 'STG-11F3B-%';

DELETE FROM public.production_run_event
WHERE run_id LIKE 'RUN-11F3B-%';

DELETE FROM public.production_run
WHERE run_id LIKE 'RUN-11F3B-%';

COMMIT;