\echo '=== SIGNATURES EXECUTION PIPELINE ==='

SELECT 
    p.proname,
    pg_get_functiondef(p.oid)
FROM pg_proc p
JOIN pg_namespace n 
    ON n.oid = p.pronamespace
WHERE n.nspname='public'
AND p.proname IN (
    'claim_stage_for_execution',
    'complete_stage_atomically'
)
ORDER BY p.proname;

