\set ON_ERROR_STOP on
\pset pager off

SELECT *
FROM public.fail_stage_atomically(
    'STG-11E32-FIXTURE',
    'NETWORK_ERROR',
    '11-E32 concurrent stage failure',
    '{"fixture":"11-E32","worker":"STAGE"}'::jsonb
);
