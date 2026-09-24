SELECT
    status,
    current_stage
FROM production_run
WHERE run_id = 'RUN-20260910-0F062';

SELECT
    COUNT(*) AS event_count
FROM production_execution_event
WHERE run_id = 'RUN-20260910-0F062';

SELECT CASE
    WHEN
        (SELECT status
         FROM production_run
         WHERE run_id = 'RUN-20260910-0F062') = 'VALIDATED'
        AND
        (SELECT current_stage
         FROM production_run
         WHERE run_id = 'RUN-20260910-0F062') = 'SCRIPT'
        AND
        (SELECT COUNT(*)
         FROM production_execution_event
         WHERE run_id = 'RUN-20260910-0F062') = 3
        AND
        NOT EXISTS (
            SELECT 1
            FROM production_run
            WHERE run_id = 'RUN-20260910-0F062'
              AND status = 'PUBLISHED'
        )
    THEN 'ASSERT_OK_READ_ONLY'
    ELSE 'ASSERT_FAIL_READ_ONLY'
END;