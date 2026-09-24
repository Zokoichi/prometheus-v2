\echo '=== FONCTIONS RUN ==='

SELECT 
    proname,
    pg_get_functiondef(oid)
FROM pg_proc
WHERE proname LIKE '%run%'
ORDER BY proname;

