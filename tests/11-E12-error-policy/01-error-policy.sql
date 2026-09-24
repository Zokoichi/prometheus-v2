\pset pager off
\pset format aligned
\pset border 1

\echo '============================================================'
\echo '11-E.12 — ERROR POLICY FORENSICS'
\echo '============================================================'

\echo '============================================================'
\echo '1. CLASSIFY_ERROR — DEFINITION'
\echo '============================================================'

SELECT pg_get_functiondef(
    'public.classify_error(character varying,integer)'::regprocedure
);

\echo '============================================================'
\echo '2. EXISTING ERROR POLICY TABLES'
\echo '============================================================'

SELECT
    schemaname,
    tablename
FROM pg_tables
WHERE schemaname = 'public'
  AND (
       tablename ILIKE '%error%'
    OR tablename ILIKE '%retry%'
    OR tablename ILIKE '%policy%'
  )
ORDER BY tablename;

\echo '============================================================'
\echo '3. ERROR POLICY COLUMNS'
\echo '============================================================'

SELECT
    table_name,
    column_name,
    data_type,
    is_nullable,
    column_default
FROM information_schema.columns
WHERE table_schema = 'public'
  AND (
       table_name ILIKE '%error%'
    OR table_name ILIKE '%retry%'
    OR table_name ILIKE '%policy%'
  )
ORDER BY table_name, ordinal_position;

\echo '============================================================'
\echo '4. CURRENT ERROR POLICY DATA'
\echo '============================================================'

SELECT
    table_name,
    column_name
FROM information_schema.columns
WHERE table_schema = 'public'
  AND table_name = 'error_policy'
ORDER BY ordinal_position;

\echo '============================================================'
\echo '5. CLASSIFY KNOWN / UNKNOWN CODES'
\echo '============================================================'

SELECT * FROM classify_error('STAGE_NOT_RUNNING', 1);

SELECT * FROM classify_error('UNKNOWN_TEST_ERROR', 1);

SELECT * FROM classify_error('UNKNOWN_TEST_ERROR', 2);

\echo '============================================================'
\echo '6. CLASSIFY RETRY ATTEMPT BOUNDARIES'
\echo '============================================================'

SELECT * FROM classify_error('STAGE_NOT_RUNNING', 1);
SELECT * FROM classify_error('STAGE_NOT_RUNNING', 2);
SELECT * FROM classify_error('STAGE_NOT_RUNNING', 3);
SELECT * FROM classify_error('STAGE_NOT_RUNNING', 4);

\echo '============================================================'
\echo '7. STAGE DEFINITION RETRY POLICIES'
\echo '============================================================'

SELECT
    stage_name,
    version,
    max_attempts,
    retry_policy,
    recovery_policy,
    enabled
FROM stage_definition
ORDER BY stage_name, version;

\echo '============================================================'
\echo '11-E.12 END'
\echo '============================================================'
