\pset pager off
\pset format aligned
\pset border 1

\echo '============================================================'
\echo '1. ARTIFACT-RELATED FUNCTION INVENTORY'
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
    OR p.proname ILIKE '%upload%'
    OR p.proname ILIKE '%store%'
  )
ORDER BY p.proname, p.oid;

\echo '============================================================'
\echo '2. ARTIFACT REGISTRY TRIGGERS'
\echo '============================================================'

SELECT
    tgname AS trigger_name,
    pg_get_triggerdef(oid) AS trigger_definition
FROM pg_trigger
WHERE tgrelid = 'public.artifact_registry'::regclass
  AND NOT tgisinternal
ORDER BY tgname;

\echo '============================================================'
\echo '3. ARTIFACT REGISTRY STATUS COUNTS'
\echo '============================================================'

SELECT
    status,
    COUNT(*) AS count
FROM artifact_registry
GROUP BY status
ORDER BY status;

\echo '============================================================'
\echo '4. CURRENT ARTIFACT REGISTRY ROWS'
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
    status,
    metadata_json
FROM artifact_registry
ORDER BY id;
