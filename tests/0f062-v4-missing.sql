SELECT * FROM diagnose_run('RUN-DOES-NOT-EXIST');

SELECT CASE
    WHEN
        (
            SELECT error_code
            FROM diagnose_run('RUN-DOES-NOT-EXIST')
        ) = 'RUN_NOT_FOUND'
    THEN 'ASSERT_OK_RUN_NOT_FOUND'
    ELSE 'ASSERT_FAIL_RUN_NOT_FOUND'
END;