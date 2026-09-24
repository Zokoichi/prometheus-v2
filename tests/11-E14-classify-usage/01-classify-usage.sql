\pset pager off
\pset format aligned
\pset border 1

\echo '============================================================'
\echo '11-E.14 — CLASSIFY_ERROR USAGE FORENSICS'
\echo '============================================================'

\echo '============================================================'
\echo '1. ROUTINES REFERENCING CLASSIFY_ERROR'
\echo '============================================================'

SELECT
    p.oid,
    n.nspname AS schema_name,
    p.proname AS routine_name,
    p.prokind,
    pg_get_function_identity_arguments(p.oid) AS arguments
FROM pg_proc p
JOIN pg_namespace n
    ON n.oid = p.pronamespace
WHERE n.nspname = 'public'
  AND p.prosrc ILIKE '%classify_error%'
ORDER BY p.proname, p.oid;

\echo '============================================================'
\echo '2. ROUTINES REFERENCING ERROR_POLICY'
\echo '============================================================'

SELECT
    p.oid,
    n.nspname AS schema_name,
    p.proname AS routine_name,
    p.prokind,
    pg_get_function_identity_arguments(p.oid) AS arguments
FROM pg_proc p
JOIN pg_namespace n
    ON n.oid = p.pronamespace
WHERE n.nspname = 'public'
  AND p.prosrc ILIKE '%error_policy%'
ORDER BY p.proname, p.oid;

\echo '============================================================'
\echo '3. ROUTINES REFERENCING STAGE ERROR STATUS'
\echo '============================================================'

SELECT
    p.oid,
    n.nspname AS schema_name,
    p.proname AS routine_name,
    p.prokind,
    pg_get_function_identity_arguments(p.oid) AS arguments
FROM pg_proc p
JOIN pg_namespace n
    ON n.oid = p.pronamespace
WHERE n.nspname = 'public'
  AND (
       p.prosrc ILIKE '%status%ERROR%'
    OR p.prosrc ILIKE '%ERROR%status%'
    OR p.prosrc ILIKE '%retryable%'
    OR p.prosrc ILIKE '%RETRY%'
  )
ORDER BY p.proname, p.oid;

\echo '============================================================'
\echo '4. ROUTINES REFERENCING production_stage_event'
\echo '============================================================'

SELECT
    p.oid,
    n.nspname AS schema_name,
    p.proname AS routine_name,
    p.prokind,
    pg_get_function_identity_arguments(p.oid) AS arguments
FROM pg_proc p
JOIN pg_namespace n
    ON n.oid = p.pronamespace
WHERE n.nspname = 'public'
  AND p.prosrc ILIKE '%production_stage_event%'
ORDER BY p.proname, p.oid;

\echo '============================================================'
\echo '5. ROUTINES REFERENCING UPDATE OF production_stage'
\echo '============================================================'

SELECT
    p.oid,
    n.nspname AS schema_name,
    p.proname AS routine_name,
    p.prokind,
    pg_get_function_identity_arguments(p.oid) AS arguments
FROM pg_proc p
JOIN pg_namespace n
    ON n.oid = p.pronamespace
WHERE n.nspname = 'public'
  AND (
       p.prosrc ILIKE '%UPDATE production_stage%'
    OR p.prosrc ILIKE '%UPDATE public.production_stage%'
    OR p.prosrc ILIKE '%INSERT INTO production_stage%'
  )
ORDER BY p.proname, p.oid;

\echo '============================================================'
\echo '6. ROUTINES REFERENCING ATTEMPT IN production_stage'
\echo '============================================================'

SELECT
    p.oid,
    n.nspname AS schema_name,
    p.proname AS routine_name,
    p.prokind,
    pg_get_function_identity_arguments(p.oid) AS arguments
FROM pg_proc p
JOIN pg_namespace n
    ON n.oid = p.pronamespace
WHERE n.nspname = 'public'
  AND p.prosrc ILIKE '%attempt%'
  AND p.prosrc ILIKE '%production_stage%'
ORDER BY p.proname, p.oid;

\echo '============================================================'
\echo '7. ROUTINE SOURCE — ONLY IF CLASSIFY_ERROR IS REFERENCED'
\echo '============================================================'

SELECT
    p.oid,
    p.proname AS routine_name,
    pg_get_function_identity_arguments(p.oid) AS arguments,
    p.prosrc
FROM pg_proc p
JOIN pg_namespace n
    ON n.oid = p.pronamespace
WHERE n.nspname = 'public'
  AND p.prosrc ILIKE '%classify_error%'
ORDER BY p.proname, p.oid;

\echo '============================================================'
\echo '11-E.14 END'
\echo '============================================================'
