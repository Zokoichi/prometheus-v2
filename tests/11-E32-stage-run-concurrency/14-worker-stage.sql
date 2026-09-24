\set ON_ERROR_STOP on
\pset pager off

SET statement_timeout = '5000ms';

SELECT now() AS worker_start,
       'STAGE_WORKER' AS worker;

SELECT *
FROM public.fail_stage_atomically(
    'STG-11E32-FIX-RETEST-V2',
    'NETWORK_ERROR',
    '11-E32 fixed concurrency stage failure',
    jsonb_build_object(
        'test', '11-E32-FIX-RETEST-V2',
        'worker', 'STAGE'
    )
);

SELECT now() AS worker_end;
