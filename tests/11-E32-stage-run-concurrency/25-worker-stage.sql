\set ON_ERROR_STOP on
\timing on

SELECT clock_timestamp() AS worker_start;

SELECT *
FROM public.fail_stage_atomically(
    'STG-11E32-CONCURRENT-POST-FIX',
    'NETWORK_ERROR',
    '11-E.32 concurrent post-FIX-1 stage failure',
    jsonb_build_object(
        'test','11-E.32-CONCURRENT-POST-FIX',
        'worker','STAGE'
    )
);

SELECT clock_timestamp() AS worker_end;
