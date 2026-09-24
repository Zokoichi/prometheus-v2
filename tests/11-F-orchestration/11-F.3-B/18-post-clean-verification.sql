\set ON_ERROR_STOP on

SELECT
    (SELECT COUNT(*) FROM public.production_run
     WHERE run_id LIKE 'RUN-11F3B-%') AS runs_remaining,
    (SELECT COUNT(*) FROM public.production_stage
     WHERE stage_id LIKE 'STG-11F3B-%') AS stages_remaining,
    (SELECT COUNT(*) FROM public.artifact_registry
     WHERE artifact_id LIKE 'ART-11F3B-%') AS artifacts_remaining,
    (SELECT COUNT(*) FROM public.production_stage_event
     WHERE run_id LIKE 'RUN-11F3B-%') AS stage_events_remaining,
    (SELECT COUNT(*) FROM public.production_run_event
     WHERE run_id LIKE 'RUN-11F3B-%') AS run_events_remaining;