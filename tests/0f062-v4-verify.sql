SELECT CASE
    WHEN to_regclass('public.production_execution_event') IS NOT NULL
    THEN 'ASSERT_OK_EVENT_TABLE'
    ELSE 'ASSERT_FAIL_EVENT_TABLE'
END;

SELECT CASE
    WHEN to_regclass('public.execution_event_diagnostic') IS NOT NULL
    THEN 'ASSERT_OK_DIAGNOSTIC_VIEW'
    ELSE 'ASSERT_FAIL_DIAGNOSTIC_VIEW'
END;

SELECT CASE
    WHEN EXISTS (
        SELECT 1
        FROM pg_proc
        WHERE proname = 'record_execution_event'
    )
    THEN 'ASSERT_OK_EVENT_FUNCTION'
    ELSE 'ASSERT_FAIL_EVENT_FUNCTION'
END;

SELECT CASE
    WHEN EXISTS (
        SELECT 1
        FROM pg_proc
        WHERE proname = 'diagnose_run'
    )
    THEN 'ASSERT_OK_DIAGNOSE_FUNCTION'
    ELSE 'ASSERT_FAIL_DIAGNOSE_FUNCTION'
END;