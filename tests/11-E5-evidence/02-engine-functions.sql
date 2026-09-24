SELECT
    n.nspname AS schema_name,
    p.proname AS function_name,
    pg_get_function_identity_arguments(p.oid) AS arguments,
    pg_get_functiondef(p.oid) AS definition
FROM pg_proc p
JOIN pg_namespace n ON n.oid = p.pronamespace
WHERE n.nspname = 'public'
  AND (
       p.proname ILIKE '%stage%'
       OR p.proname ILIKE '%execution%'
       OR p.proname ILIKE '%transition%'
       OR p.proname ILIKE '%claim%'
       OR p.proname ILIKE '%register%'
       OR p.proname ILIKE '%artifact%'
  )
ORDER BY p.proname, arguments;
