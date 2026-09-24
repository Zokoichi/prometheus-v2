\set ON_ERROR_STOP on
\pset pager off

BEGIN;

INSERT INTO public.production_run (
    run_id,
    project_id,
    status,
    current_stage,
    attempt
)
VALUES (
    'RUN-11E31-FIXTURE',
    'PROJECT-11E31-FIXTURE',
    'CREATED',
    'RUN_MANAGER',
    1
);

INSERT INTO public.production_stage (
    stage_id,
    run_id,
    stage_name,
    stage_order,
    status,
    attempt,
    retryable,
    error_code,
    error_message,
    idempotency_key
)
VALUES (
    'STG-11E31-FIXTURE',
    'RUN-11E31-FIXTURE',
    'FAIL_RUN_CONCURRENCY',
    1,
    'ERROR',
    3,
    FALSE,
    'NETWORK_ERROR',
    '11-E31 terminal concurrency fixture',
    'RUN-11E31-FIXTURE:FAIL_RUN_CONCURRENCY:3'
);

COMMIT;

SELECT
    r.run_id,
    r.status AS run_status,
    s.stage_id,
    s.status AS stage_status,
    s.attempt,
    s.retryable
FROM public.production_run r
JOIN public.production_stage s
    ON s.run_id = r.run_id
WHERE r.run_id = 'RUN-11E31-FIXTURE';
