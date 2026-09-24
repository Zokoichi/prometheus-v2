\set ON_ERROR_STOP on
\timing on

SELECT clock_timestamp() AS worker_start;

SELECT *
FROM public.fail_run_atomically(
    'RUN-11E32-CONCURRENT-POST-FIX',
    'STG-11E32-CONCURRENT-POST-FIX',
    'RUN_ERROR',
    jsonb_build_object(
        'test','11-E.32-CONCURRENT-POST-FIX',
        'worker','RUN'
    )
);

SELECT clock_timestamp() AS worker_end;
