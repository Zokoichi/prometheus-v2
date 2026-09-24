SELECT
    allowed,
    error_code,
    error_message,
    run_status,
    current_stage,
    total_events,
    error_events,
    successful_events,
    total_duration_ms,
    last_stage_name,
    last_attempt,
    providers
FROM diagnose_run('RUN-20260910-0F062');

SELECT CASE
    WHEN
        (
            SELECT allowed
            FROM diagnose_run('RUN-20260910-0F062')
        ) = TRUE
        AND
        (
            SELECT total_events
            FROM diagnose_run('RUN-20260910-0F062')
        ) = 3
        AND
        (
            SELECT error_events
            FROM diagnose_run('RUN-20260910-0F062')
        ) = 1
        AND
        (
            SELECT successful_events
            FROM diagnose_run('RUN-20260910-0F062')
        ) = 1
        AND
        (
            SELECT total_duration_ms
            FROM diagnose_run('RUN-20260910-0F062')
        ) = 2000
        AND
        (
            SELECT run_status
            FROM diagnose_run('RUN-20260910-0F062')
        ) = 'VALIDATED'
        AND
        (
            SELECT current_stage
            FROM diagnose_run('RUN-20260910-0F062')
        ) = 'SCRIPT'
        AND
        (
            SELECT last_stage_name
            FROM diagnose_run('RUN-20260910-0F062')
        ) = 'SCRIPT'
        AND
        (
            SELECT last_attempt
            FROM diagnose_run('RUN-20260910-0F062')
        ) = 1
        AND
        (
            SELECT providers
            FROM diagnose_run('RUN-20260910-0F062')
        ) @> '["TEST_PROVIDER"]'::jsonb
    THEN 'ASSERT_OK_RUN_DIAGNOSTIC'
    ELSE 'ASSERT_FAIL_RUN_DIAGNOSTIC'
END;