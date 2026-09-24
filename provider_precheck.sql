\echo '================================================'
\echo 'PROMETHEUS V2 - PROVIDER EXECUTION PRECHECK'
\echo 'READ ONLY'
\echo '================================================'

SELECT 
    p.proname,
    pg_get_function_identity_arguments(p.oid) AS arguments,
    pg_get_functiondef(p.oid)
FROM pg_proc p
JOIN pg_namespace n 
ON n.oid = p.pronamespace
WHERE n.nspname='public'
AND p.proname IN
(
'claim_stage_for_execution',
'complete_stage_atomically',
'register_stage_definition',
'classify_error'
)
ORDER BY p.proname;

