SELECT 
    pg_get_functiondef(p.oid)
FROM pg_proc p
JOIN pg_namespace n 
ON n.oid = p.pronamespace
WHERE n.nspname='public'
AND p.proname='register_stage_definition';
