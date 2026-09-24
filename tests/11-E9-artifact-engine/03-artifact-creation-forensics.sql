\pset pager off
\pset format aligned
\pset border 1

\echo '============================================================'
\echo '1. FUNCTIONS CONTAINING ARTIFACT_REGISTRY INSERT'
\echo '============================================================'

SELECT
    p.oid,
    n.nspname AS schema_name,
    p.proname AS function_name,
    pg_get_function_identity_arguments(p.oid) AS arguments
FROM pg_proc p
JOIN pg_namespace n
    ON n.oid = p.pronamespace
WHERE n.nspname = 'public'
  AND pg_get_functiondef(p.oid) ILIKE '%INSERT INTO artifact_registry%'
ORDER BY p.proname, p.oid;

\echo '============================================================'
\echo '2. FUNCTIONS REFERENCING ARTIFACT_REGISTRY'
\echo '============================================================'

SELECT
    p.oid,
    n.nspname AS schema_name,
    p.proname AS function_name,
    pg_get_function_identity_arguments(p.oid) AS arguments
FROM pg_proc p
JOIN pg_namespace n
    ON n.oid = p.pronamespace
WHERE n.nspname = 'public'
  AND pg_get_functiondef(p.oid) ILIKE '%artifact_registry%'
ORDER BY p.proname, p.oid;

\echo '============================================================'
\echo '3. FUNCTIONS WITH ARTIFACT / STORAGE / REGISTER NAMES'
\echo '============================================================'

SELECT
    p.oid,
    n.nspname AS schema_name,
    p.proname AS function_name,
    pg_get_function_identity_arguments(p.oid) AS arguments,
    pg_get_function_result(p.oid) AS result
FROM pg_proc p
JOIN pg_namespace n
    ON n.oid = p.pronamespace
WHERE n.nspname = 'public'
  AND (
       p.proname ILIKE '%artifact%'
    OR p.proname ILIKE '%storage%'
    OR p.proname ILIKE '%object%'
    OR p.proname ILIKE '%register%'
    OR p.proname ILIKE '%upload%'
    OR p.proname ILIKE '%store%'
  )
ORDER BY p.proname, p.oid;

\echo '============================================================'
\echo '4. ALL TRIGGERS ON ARTIFACT_REGISTRY'
\echo '============================================================'

SELECT
    tgname AS trigger_name,
    pg_get_triggerdef(oid) AS trigger_definition
FROM pg_trigger
WHERE tgrelid = 'public.artifact_registry'::regclass
  AND NOT tgisinternal
ORDER BY tgname;

\echo '============================================================'
\echo '5. ARTIFACT STATUS DISTRIBUTION'
\echo '============================================================'

SELECT
    status,
    COUNT(*) AS artifact_count
FROM artifact_registry
GROUP BY status
ORDER BY status;

\echo '============================================================'
\echo '6. ARTIFACTS WITH COMPLETE STORAGE METADATA'
\echo '============================================================'

SELECT
    artifact_id,
    run_id,
    stage,
    artifact_type,
    object_key,
    content_type,
    size_bytes,
    sha256,
    version,
    status
FROM artifact_registry
ORDER BY id;

\echo '============================================================'
\echo '7. FUNCTION DEFINITIONS FOR ARTIFACT CANDIDATES'
\echo '============================================================'

SELECT
    p.oid,
    p.proname AS function_name,
    pg_get_function_identity_arguments(p.oid) AS arguments,
    pg_get_functiondef(p.oid) AS definition
FROM pg_proc p
JOIN pg_namespace n
    ON n.oid = p.pronamespace
WHERE n.nspname = 'public'
  AND (
       p.proname ILIKE '%artifact%'
    OR p.proname ILIKE '%storage%'
    OR p.proname ILIKE '%object%'
    OR p.proname ILIKE '%upload%'
    OR p.proname ILIKE '%store%'
  )
ORDER BY p.proname, p.oid;
