\set ON_ERROR_STOP on
SET lock_timeout = '5000ms';
BEGIN;

SELECT *
FROM public.complete_stage_atomically(
    'STG-11F3B-D',
    '{"test":"D"}'::jsonb
);

COMMIT;