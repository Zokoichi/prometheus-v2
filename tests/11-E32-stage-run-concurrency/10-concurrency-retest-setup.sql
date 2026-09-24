\set ON_ERROR_STOP on
\pset pager off

BEGIN;

DELETE FROM production_stage_event
WHERE run_id = 'RUN-11E32-FIX-RETEST';

DELETE FROM production_run_event
WHERE run_id = 'RUN-11E32-FIX-RETEST';

DELETE FROM production_stage
WHERE stage_id = 'STG-11E32-FIX-RETEST';

DELETE FROM production_run
WHERE run_id = 'RUN-11E32-FIX-RETEST';

INSERT INTO production_run (
    run_id,
    project_id,
    status,
    current_stage,
    attempt,
    input_json,
    output_json
)
VALUES (
    'RUN-11E32-FIX-RETEST',
    'PROJECT-11E32-FIX-RETEST',
    'CREATED',
    'RUN_MANAGER',
    1,
    '{}'::jsonb,
    '{}'::jsonb
);

INSERT INTO production_stage (
    stage_id,
    run_id,
    stage_name,
    stage_order,
    status,
    attempt,
    idempotency_key,
    retryable,
    input_artifact_ids,
    output_artifact_ids,
    input_json,
    output_json
)
VALUES (
    'STG-11E32-FIX-RETEST',
    'RUN-11E32-FIX-RETEST',
    'FAIL_RUN_CONCURRENCY',
    1,
    'PENDING',
    1,
    'RUN-11E32-FIX-RETEST:FAIL_RUN_CONCURRENCY:1',
    FALSE,
    '[]'::jsonb,
    '[]'::jsonb,
    '{}'::jsonb,
    '{}'::jsonb
);

COMMIT;

SELECT
    run_id,
    status,
    current_stage
FROM production_run
WHERE run_id = 'RUN-11E32-FIX-RETEST';

SELECT
    stage_id,
    run_id,
    stage_name,
    status,
    attempt,
    retryable
FROM production_stage
WHERE stage_id = 'STG-11E32-FIX-RETEST';
