\set ON_ERROR_STOP on
\pset pager off

SELECT *
FROM public.fail_run_atomically(
    'RUN-11E32-FIXTURE',
    'STG-11E32-FIXTURE',
    'RUN_ERROR',
    '{"fixture":"11-E32","worker":"RUN"}'::jsonb
);
