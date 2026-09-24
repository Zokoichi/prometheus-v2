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
    'RUN-20260910-0F062',
    'PROJECT-TEST-0F062',
    'VALIDATED',
    'SCRIPT',
    1,
    '{"topic":"diagnostic-test"}'::jsonb,
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
    input_artifact_ids,
    output_artifact_ids,
    input_json,
    output_json
)
VALUES (
    'STG-20260910-0F062',
    'RUN-20260910-0F062',
    'SCRIPT',
    1,
    'RUNNING',
    1,
    'RUN-20260910-0F062:SCRIPT:1',
    '[]'::jsonb,
    '[]'::jsonb,
    '{}'::jsonb,
    '{}'::jsonb
);

SELECT CASE
    WHEN
        (SELECT COUNT(*)
         FROM production_run
         WHERE run_id = 'RUN-20260910-0F062') = 1
        AND
        (SELECT COUNT(*)
         FROM production_stage
         WHERE stage_id = 'STG-20260910-0F062') = 1
    THEN 'ASSERT_OK_FIXTURE'
    ELSE 'ASSERT_FAIL_FIXTURE'
END;