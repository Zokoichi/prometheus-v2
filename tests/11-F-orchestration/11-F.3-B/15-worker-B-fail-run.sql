\set ON_ERROR_STOP on
SET lock_timeout = '5000ms';

SELECT pg_sleep(0.1);

SELECT *
FROM public.fail_run_atomically(
    'RUN-11F3B-E',
    'STG-11F3B-E',
    'RUN_ERROR',
    '{"test":"E"}'::jsonb
);