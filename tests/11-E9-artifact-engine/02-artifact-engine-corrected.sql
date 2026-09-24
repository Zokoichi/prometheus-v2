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
JOIN pg_namespace n ON n.oid = p.pronamespace
WHERE n.nspname = 'public'
  AND p.proname IN (
      'register_artifact',
      'create_artifact',
      'store_artifact',
      'validate_artifact',
      'reconcile_artifact_presence',
      'validate_stage_artifacts'
  )
ORDER BY p.proname, p.oid;

\echo '============================================================'
\echo '2. TABLE DEFINITION'
\echo '============================================================'

SELECT
    column_name,
    data_type,
    is_nullable,
    column_default
FROM information_schema.columns
WHERE table_schema = 'public'
  AND table_name = 'artifact_registry'
ORDER BY ordinal_position;

\echo '============================================================'
\echo '3. CONSTRAINTS'
\echo '============================================================'

SELECT
    conname,
    pg_get_constraintdef(oid)
FROM pg_constraint
WHERE conrelid = 'public.artifact_registry'::regclass
ORDER BY conname;

\echo '============================================================'
\echo '4. INDEXES'
\echo '============================================================'

SELECT
    indexname,
    indexdef
FROM pg_indexes
WHERE schemaname = 'public'
  AND tablename = 'artifact_registry'
ORDER BY indexname;

\echo '============================================================'
\echo '5. CURRENT ARTIFACTS'
\echo '============================================================'

SELECT
    id,
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

\echo '============================================================'
\echo '6. EXACT RECONCILIATION FUNCTION'
\echo '============================================================'

SELECT pg_get_functiondef(p.oid)
FROM pg_proc p
JOIN pg_namespace n ON n.oid = p.pronamespace
WHERE n.nspname = 'public'
  AND p.proname = 'reconcile_artifact_presence';

\echo '============================================================'
\echo '7. EXACT STAGE ARTIFACT VALIDATION FUNCTION'
\echo '============================================================'

SELECT pg_get_functiondef(p.oid)
FROM pg_proc p
JOIN pg_namespace n ON n.oid = p.pronamespace
WHERE n.nspname = 'public'
  AND p.proname = 'validate_stage_artifacts';
