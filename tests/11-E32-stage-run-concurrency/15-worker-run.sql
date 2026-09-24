\set ON_ERROR_STOP on
\pset pager off

SET statement_timeout = '5000ms';

SELECT now() AS worker_start,
       'RUN_WORKER' AS worker;

SELECT *
FROM public.fail_run_atomically(
    'RUN-11E32-FIX-RETEST-V2',
    'STG-11E32-FIX-RETEST-V2',
    'RUN_ERROR',
    jsonb_build_object(
        'test', '11-E32-FIX-RETEST-V2',
        'worker', 'RUN'
    )
);

SELECT now() AS worker_end;
