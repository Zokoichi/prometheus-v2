\pset pager off
\pset tuples_only off
\pset format aligned
\pset border 1
\set ON_ERROR_STOP on

\echo '============================================================'
\echo '1. ALL PROMETHEUS ENGINE FUNCTIONS'
\echo '============================================================'

SELECT
    n.nspname AS schema_name,
    p.proname AS function_name,
    pg_get_function_identity_arguments(p.oid) AS arguments,
    pg_get_function_result(p.oid) AS result_type
FROM pg_proc p
JOIN pg_namespace n ON n.oid = p.pronamespace
WHERE n.nspname = 'public'
  AND (
       p.proname ILIKE '%stage%'
    OR p.proname ILIKE '%run%'
    OR p.proname ILIKE '%execution%'
    OR p.proname ILIKE '%artifact%'
    OR p.proname ILIKE '%depend%'
    OR p.proname ILIKE '%transition%'
    OR p.proname ILIKE '%claim%'
    OR p.proname ILIKE '%register%'
    OR p.proname ILIKE '%event%'
  )
ORDER BY p.proname, p.oid;

\echo '============================================================'
\echo '2. EXACT CLAIM FUNCTION'
\echo '============================================================'

SELECT pg_get_functiondef(p.oid)
FROM pg_proc p
JOIN pg_namespace n ON n.oid = p.pronamespace
WHERE n.nspname = 'public'
  AND p.proname = 'claim_stage_for_execution';

\echo '============================================================'
\echo '3. FUNCTIONS WRITING production_stage'
\echo '============================================================'

SELECT
    n.nspname,
    p.proname,
    pg_get_function_identity_arguments(p.oid)
FROM pg_proc p
JOIN pg_namespace n ON n.oid = p.pronamespace
WHERE n.nspname = 'public'
  AND pg_get_functiondef(p.oid) ILIKE '%production_stage%'
  AND (
       pg_get_functiondef(p.oid) ILIKE '%INSERT INTO production_stage%'
    OR pg_get_functiondef(p.oid) ILIKE '%UPDATE production_stage%'
    OR pg_get_functiondef(p.oid) ILIKE '%DELETE FROM production_stage%'
  )
ORDER BY p.proname, p.oid;

\echo '============================================================'
\echo '4. FUNCTIONS WRITING production_run'
\echo '============================================================'

SELECT
    n.nspname,
    p.proname,
    pg_get_function_identity_arguments(p.oid)
FROM pg_proc p
JOIN pg_namespace n ON n.oid = p.pronamespace
WHERE n.nspname = 'public'
  AND pg_get_functiondef(p.oid) ILIKE '%production_run%'
  AND (
       pg_get_functiondef(p.oid) ILIKE '%INSERT INTO production_run%'
    OR pg_get_functiondef(p.oid) ILIKE '%UPDATE production_run%'
    OR pg_get_functiondef(p.oid) ILIKE '%DELETE FROM production_run%'
  )
ORDER BY p.proname, p.oid;

\echo '============================================================'
\echo '5. FUNCTIONS WRITING production_execution_event'
\echo '============================================================'

SELECT
    n.nspname,
    p.proname,
    pg_get_function_identity_arguments(p.oid)
FROM pg_proc p
JOIN pg_namespace n ON n.oid = p.pronamespace
WHERE n.nspname = 'public'
  AND pg_get_functiondef(p.oid) ILIKE '%production_execution_event%'
  AND (
       pg_get_functiondef(p.oid) ILIKE '%INSERT INTO production_execution_event%'
    OR pg_get_functiondef(p.oid) ILIKE '%UPDATE production_execution_event%'
    OR pg_get_functiondef(p.oid) ILIKE '%DELETE FROM production_execution_event%'
  )
ORDER BY p.proname, p.oid;

\echo '============================================================'
\echo '6. FUNCTIONS CHECKING DEPENDENCIES'
\echo '============================================================'

SELECT
    n.nspname,
    p.proname,
    pg_get_function_identity_arguments(p.oid)
FROM pg_proc p
JOIN pg_namespace n ON n.oid = p.pronamespace
WHERE n.nspname = 'public'
  AND (
       pg_get_functiondef(p.oid) ILIKE '%production_stage_dependency%'
    OR pg_get_functiondef(p.oid) ILIKE '%depends_on_stage_id%'
    OR pg_get_functiondef(p.oid) ILIKE '%dependency_type%'
  )
ORDER BY p.proname, p.oid;

\echo '============================================================'
\echo '7. FUNCTIONS MANAGING ARTIFACTS'
\echo '============================================================'

SELECT
    n.nspname,
    p.proname,
    pg_get_function_identity_arguments(p.oid)
FROM pg_proc p
JOIN pg_namespace n ON n.oid = p.pronamespace
WHERE n.nspname = 'public'
  AND pg_get_functiondef(p.oid) ILIKE '%artifact_registry%'
ORDER BY p.proname, p.oid;

\echo '============================================================'
\echo '8. FUNCTIONS MANAGING STAGE DEFINITION'
\echo '============================================================'

SELECT
    n.nspname,
    p.proname,
    pg_get_function_identity_arguments(p.oid)
FROM pg_proc p
JOIN pg_namespace n ON n.oid = p.pronamespace
WHERE n.nspname = 'public'
  AND (
       pg_get_functiondef(p.oid) ILIKE '%stage_definition%'
    OR p.proname ILIKE '%definition%'
  )
ORDER BY p.proname, p.oid;

\echo '============================================================'
\echo '9. COMPLETE DEFINITIONS OF ALL CANDIDATE ENGINE FUNCTIONS'
\echo '============================================================'

SELECT
    '### FUNCTION ' ||
    n.nspname || '.' ||
    p.proname || '(' ||
    pg_get_function_identity_arguments(p.oid) ||
    ')' ||
    E'\n' ||
    pg_get_functiondef(p.oid) ||
    E'\n### END FUNCTION\n'
FROM pg_proc p
JOIN pg_namespace n ON n.oid = p.pronamespace
WHERE n.nspname = 'public'
  AND (
       p.proname ILIKE '%stage%'
    OR p.proname ILIKE '%run%'
    OR p.proname ILIKE '%execution%'
    OR p.proname ILIKE '%artifact%'
    OR p.proname ILIKE '%depend%'
    OR p.proname ILIKE '%transition%'
    OR p.proname ILIKE '%claim%'
    OR p.proname ILIKE '%register%'
    OR p.proname ILIKE '%event%'
  )
ORDER BY p.proname, p.oid;
