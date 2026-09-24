\echo '=== SIGNATURES REELLES - A VERIFIER AVANT INTEGRATION SCRIPT ==='
SELECT p.proname, pg_get_functiondef(p.oid) AS definition
FROM pg_proc p
JOIN pg_namespace n ON n.oid = p.pronamespace
WHERE n.nspname = 'public'
  AND p.proname IN (
    'claim_stage_for_execution',
    'complete_stage_atomically',
    'register_stage_definition',
    'classify_error',
    'create_stage_dependency'
  )
ORDER BY p.proname, p.oid;
