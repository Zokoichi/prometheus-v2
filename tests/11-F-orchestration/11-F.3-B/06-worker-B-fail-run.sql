\set ON_ERROR_STOP on
SET lock_timeout = '5000ms';
BEGIN;

SELECT 1
FROM public.production_run
WHERE run_id = 'RUN-11F3B-B'
FOR UPDATE;

SELECT pg_sleep(2);

SELECT *
FROM public.fail_run_atomically(
    'RUN-11F3B-B',
    'STG-11F3B-B',
    'RUN_ERROR',
    '{"test":"B"}'::jsonb
);

COMMIT;