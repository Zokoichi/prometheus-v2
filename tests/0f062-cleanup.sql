DELETE FROM production_execution_event
WHERE run_id = 'RUN-20260910-0F062';

DELETE FROM production_stage
WHERE run_id = 'RUN-20260910-0F062';

DELETE FROM production_run
WHERE run_id = 'RUN-20260910-0F062';

SELECT CASE
    WHEN
        (SELECT COUNT(*) FROM production_run
         WHERE run_id = 'RUN-20260910-0F062') = 0
        AND
        (SELECT COUNT(*) FROM production_stage
         WHERE run_id = 'RUN-20260910-0F062') = 0
        AND
        (SELECT COUNT(*) FROM production_execution_event
         WHERE run_id = 'RUN-20260910-0F062') = 0
    THEN 'ASSERT_OK_CLEANUP'
    ELSE 'ASSERT_FAIL_CLEANUP'
END;