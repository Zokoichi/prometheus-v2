SELECT
    event_id,
    stage_name,
    attempt,
    event_type,
    provider,
    status,
    duration_ms,
    duration_seconds,
    has_error
FROM execution_event_diagnostic
WHERE run_id = 'RUN-20260910-0F062'
ORDER BY created_at, id;

SELECT CASE
    WHEN
        (SELECT COUNT(*)
         FROM execution_event_diagnostic
         WHERE run_id = 'RUN-20260910-0F062') = 3
        AND
        (SELECT COUNT(*)
         FROM execution_event_diagnostic
         WHERE run_id = 'RUN-20260910-0F062'
           AND has_error = TRUE) = 1
        AND
        (SELECT COUNT(*)
         FROM execution_event_diagnostic
         WHERE run_id = 'RUN-20260910-0F062'
           AND duration_ms IS NOT NULL) = 2
        AND
        (SELECT COUNT(*)
         FROM execution_event_diagnostic
         WHERE run_id = 'RUN-20260910-0F062'
           AND duration_seconds = 1.500) = 1
    THEN 'ASSERT_OK_DIAGNOSTIC_VIEW'
    ELSE 'ASSERT_FAIL_DIAGNOSTIC_VIEW'
END;