\set ON_ERROR_STOP on
SET lock_timeout = '5000ms';
BEGIN;

SELECT 1
FROM public.production_run
WHERE run_id = 'RUN-11F3B-A'
FOR UPDATE;

SELECT pg_sleep(2);

SELECT *
FROM public.fail_stage_atomically(
    'STG-11F3B-A',
    'NETWORK_ERROR',
    '11-F.3-B TEST A failure',
    '{"test":"A"}'::jsonb
);

COMMIT;