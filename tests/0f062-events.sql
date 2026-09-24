SELECT * FROM record_execution_event(
    'EVT-20260910-0F062-START',
    'RUN-20260910-0F062',
    'STG-20260910-0F062',
    'SCRIPT',
    1,
    'EXECUTION_STARTED',
    'TEST_PROVIDER',
    'TEST_EXECUTOR',
    'RUNNING',
    NOW() - INTERVAL '2 seconds',
    NULL,
    NULL,
    NULL,
    '[]'::jsonb,
    '[]'::jsonb,
    '{"test":true,"phase":"start"}'::jsonb
);

SELECT * FROM record_execution_event(
    'EVT-20260910-0F062-SUCCESS',
    'RUN-20260910-0F062',
    'STG-20260910-0F062',
    'SCRIPT',
    1,
    'EXECUTION_COMPLETED',
    'TEST_PROVIDER',
    'TEST_EXECUTOR',
    'SUCCEEDED',
    NOW() - INTERVAL '1.5 seconds',
    NOW(),
    1500,
    NULL,
    '["INPUT-TEST-001"]'::jsonb,
    '["OUTPUT-TEST-001"]'::jsonb,
    '{"test":true,"quality":"ok"}'::jsonb
);

SELECT * FROM record_execution_event(
    'EVT-20260910-0F062-ERROR',
    'RUN-20260910-0F062',
    'STG-20260910-0F062',
    'SCRIPT',
    1,
    'EXECUTION_WARNING',
    'TEST_PROVIDER',
    'TEST_EXECUTOR',
    'ERROR',
    NOW() - INTERVAL '0.5 seconds',
    NOW(),
    500,
    'NETWORK_ERROR',
    '[]'::jsonb,
    '[]'::jsonb,
    '{"test":true,"quality":"degraded"}'::jsonb
);

SELECT CASE
    WHEN
        (SELECT COUNT(*)
         FROM production_execution_event
         WHERE run_id = 'RUN-20260910-0F062') = 3
    THEN 'ASSERT_OK_THREE_EVENTS'
    ELSE 'ASSERT_FAIL_THREE_EVENTS'
END;