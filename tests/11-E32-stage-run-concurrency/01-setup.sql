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
    'RUN-11E32-FIXTURE',
    'PROJECT-11E32-FIXTURE',
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
    idempotency_key
)
VALUES (
    'STG-11E32-FIXTURE',
    'RUN-11E32-FIXTURE',
    'STAGE_RUN_CONCURRENCY',
    1,
    'RUNNING',
    1,
    FALSE,
    'RUN-11E32-FIXTURE:STAGE_RUN_CONCURRENCY:1'
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
WHERE r.run_id = 'RUN-11E32-FIXTURE';
