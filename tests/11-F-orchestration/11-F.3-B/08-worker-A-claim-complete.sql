\set ON_ERROR_STOP on
SET lock_timeout = '5000ms';

SELECT *
FROM public.claim_stage_for_execution('STG-11F3B-C');

SELECT pg_sleep(1);

SELECT *
FROM public.complete_stage_atomically(
    'STG-11F3B-C',
    '{"test":"C"}'::jsonb
);