\set ON_ERROR_STOP on
SET lock_timeout = '5000ms';

SELECT pg_sleep(0.2);

SELECT *
FROM public.complete_stage_atomically(
    'STG-11F3B-C',
    '{"test":"C-worker-B"}'::jsonb
);