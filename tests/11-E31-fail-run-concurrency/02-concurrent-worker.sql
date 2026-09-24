\set ON_ERROR_STOP on
\pset pager off

SELECT *
FROM public.fail_run_atomically(
    'RUN-11E31-FIXTURE',
    'STG-11E31-FIXTURE',
    'RUN_ERROR',
    '{"fixture":"11-E31","worker":"WORKER"}'::jsonb
);
