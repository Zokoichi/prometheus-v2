\set ON_ERROR_STOP on
SET lock_timeout = '5000ms';

SELECT pg_sleep(0.1);

SELECT *
FROM public.fail_stage_atomically(
    'STG-11F3B-D',
    'NETWORK_ERROR',
    '11-F.3-B TEST D failure',
    '{"test":"D"}'::jsonb
);