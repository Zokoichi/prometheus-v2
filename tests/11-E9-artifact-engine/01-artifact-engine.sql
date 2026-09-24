\pset pager off
\pset format unaligned
\pset tuples_only on

\echo '===== FUNCTIONS REFERENCING ARTIFACT_REGISTRY ====='

SELECT
    n.nspname || '.' ||
    p.proname || '(' ||
    pg_get_function_identity_arguments(p.oid) ||
    ')' || E'\n' ||
    pg_get_functiondef(p.oid) ||
    E'\n===== END ====='
FROM pg_proc p
JOIN pg_namespace n
    ON n.oid = p.pronamespace
WHERE n.nspname = 'public'
  AND pg_get_functiondef(p.oid) ILIKE '%artifact_registry%'
ORDER BY p.proname, p.oid;

\echo '===== FUNCTIONS WITH ARTIFACT NAMES ====='

SELECT
    n.nspname,
    p.proname,
    pg_get_function_identity_arguments(p.oid),
    pg_get_function_result(p.oid)
FROM pg_proc p
JOIN pg_namespace n
    ON n.oid = p.pronamespace
WHERE n.nspname = 'public'
  AND (
       p.proname ILIKE '%artifact%'
    OR p.proname ILIKE '%register%'
    OR p.proname ILIKE '%store%'
    OR p.proname ILIKE '%output%'
  )
ORDER BY p.proname, p.oid;

\echo '===== ARTIFACT TABLE CONSTRAINTS ====='

SELECT
    conname,
    pg_get_constraintdef(oid)
FROM pg_constraint
WHERE conrelid = 'public.artifact_registry'::regclass
ORDER BY conname;

\echo '===== ARTIFACT TABLE INDEXES ====='

SELECT
    indexname,
    indexdef
FROM pg_indexes
WHERE schemaname = 'public'
  AND tablename = 'artifact_registry'
ORDER BY indexname;

\echo '===== ARTIFACT STATUS DISTRIBUTION ====='

SELECT
    status,
    COUNT(*)
FROM artifact_registry
GROUP BY status
ORDER BY status;

\echo '===== EXISTING ARTIFACT ROWS ====='

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
