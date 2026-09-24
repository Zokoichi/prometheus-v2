\set ON_ERROR_STOP on

SELECT
    pr.run_id,
    pr.status AS run_status,
    pr.current_stage,
    ps.stage_id,
    ps.status AS stage_status,
    ps.attempt,
    ps.retryable,
    ps.error_code,
    ps.error_message
FROM public.production_run pr
JOIN public.production_stage ps ON ps.run_id = pr.run_id
WHERE pr.run_id LIKE 'RUN-11F3B-%'
ORDER BY pr.run_id;

SELECT
    'STAGE_ERROR_EVENTS' AS metric,
    count(*)
FROM public.production_stage_event
WHERE run_id LIKE 'RUN-11F3B-%'
  AND event_type = 'STAGE_ERROR';

SELECT
    'RUN_ERROR_EVENTS' AS metric,
    count(*)
FROM public.production_run_event
WHERE run_id LIKE 'RUN-11F3B-%'
  AND event_type = 'RUN_ERROR';

DO $$
DECLARE
    r record;
    ok boolean;
    msg text;
BEGIN
    FOR r IN
        SELECT run_id
        FROM public.production_run
        WHERE run_id LIKE 'RUN-11F3B-%'
        ORDER BY run_id
    LOOP
        SELECT result, message
        INTO ok, msg
        FROM public.validate_run_stage_consistency(r.run_id);

        RAISE NOTICE 'CONSISTENCY | % | % | %',
            r.run_id, ok, msg;
    END LOOP;
END $$;

SELECT
    'ACTIVE_ERRORS' AS metric,
    count(*) AS value
FROM public.production_stage
WHERE run_id LIKE 'RUN-11F3B-%'
  AND status = 'ERROR';

