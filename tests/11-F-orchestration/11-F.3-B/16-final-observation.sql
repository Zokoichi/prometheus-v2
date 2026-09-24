\set ON_ERROR_STOP on

SELECT
    pr.run_id,
    pr.status AS run_status,
    ps.stage_id,
    ps.status AS stage_status,
    ps.attempt,
    ps.retryable
FROM public.production_run pr
JOIN public.production_stage ps
  ON ps.run_id = pr.run_id
WHERE pr.run_id LIKE 'RUN-11F3B-%'
ORDER BY pr.run_id;

SELECT
    run_id,
    event_type,
    from_status,
    to_status,
    attempt,
    created_at
FROM public.production_stage_event
WHERE run_id LIKE 'RUN-11F3B-%'
ORDER BY run_id, created_at, id;

SELECT
    run_id,
    event_type,
    from_status,
    to_status,
    stage,
    attempt,
    created_at
FROM public.production_run_event
WHERE run_id LIKE 'RUN-11F3B-%'
ORDER BY run_id, created_at;

SELECT
    CASE
        WHEN COUNT(*) = 0 THEN 'NO_ACTIVE_ERRORS'
        ELSE 'ACTIVE_ERRORS_PRESENT'
    END AS error_state
FROM public.production_stage
WHERE run_id LIKE 'RUN-11F3B-%'
  AND status = 'ERROR';

SELECT
    COUNT(*) AS fixture_runs
FROM public.production_run
WHERE run_id LIKE 'RUN-11F3B-%';

SELECT
    COUNT(*) AS fixture_stages
FROM public.production_stage
WHERE stage_id LIKE 'STG-11F3B-%';

SELECT
    COUNT(*) AS fixture_artifacts
FROM public.artifact_registry
WHERE artifact_id LIKE 'ART-11F3B-%';