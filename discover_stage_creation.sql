\echo '=== RECHERCHE CREATION PRODUCTION STAGE ==='

SELECT 
    p.proname,
    pg_get_functiondef(p.oid)
FROM pg_proc p
JOIN pg_namespace n 
    ON n.oid = p.pronamespace
WHERE n.nspname='public'
AND (
    p.proname ILIKE '%stage%'
    OR p.proname ILIKE '%run%'
)
ORDER BY p.proname;

