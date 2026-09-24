\pset pager off
\pset format aligned
\pset border 1

\echo '============================================================'
\echo '11-E.15 — ERROR / RETRY TRANSITION FORENSICS'
\echo '============================================================'

\echo '============================================================'
\echo '1. ROUTINES WITH ERROR TRANSITION LOGIC'
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
       p.prosrc ILIKE '%RUNNING%'
       AND p.prosrc ILIKE '%ERROR%'
  )
ORDER BY p.proname, p.oid;

\echo '============================================================'
\echo '2. ROUTINES WITH RETRY TRANSITION LOGIC'
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
       p.prosrc ILIKE '%RETRY%'
       OR p.prosrc ILIKE '%retryable%'
       OR p.prosrc ILIKE '%retry_allowed%'
  )
ORDER BY p.proname, p.oid;

\echo '============================================================'
\echo '3. ROUTINES WRITING STAGE ERROR FIELDS'
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
       p.prosrc ILIKE '%error_code%'
       OR p.prosrc ILIKE '%error_message%'
  )
  AND p.prosrc ILIKE '%production_stage%'
ORDER BY p.proname, p.oid;

\echo '============================================================'
\echo '4. ROUTINES INSERTING STAGE ERROR / RETRY EVENTS'
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
  AND (
       p.prosrc ILIKE '%ERROR%'
       OR p.prosrc ILIKE '%RETRY%'
       OR p.prosrc ILIKE '%retry%'
  )
ORDER BY p.proname, p.oid;

\echo '============================================================'
\echo '5. ALL CURRENT STAGE STATUS VALUES'
\echo '============================================================'

SELECT
    status,
    COUNT(*) AS count
FROM production_stage
GROUP BY status
ORDER BY status;

\echo '============================================================'
\echo '6. ALL HISTORICAL ERROR / RETRY EVENT TYPES'
\echo '============================================================'

SELECT
    event_type,
    from_status,
    to_status,
    COUNT(*) AS count
FROM production_stage_event
WHERE from_status = 'ERROR'
   OR to_status = 'ERROR'
   OR event_type ILIKE '%ERROR%'
   OR event_type ILIKE '%RETRY%'
GROUP BY event_type, from_status, to_status
ORDER BY event_type, from_status, to_status;

\echo '============================================================'
\echo '7. INITIALIZATION FILES — ERROR / RETRY REFERENCES'
\echo '============================================================'

\echo 'DB INIT FILES ARE INSPECTED OUTSIDE POSTGRES IN THIS PHASE.'
\echo 'The following query only inventories installed SQL source metadata.'

SELECT
    current_database() AS database_name,
    version() AS postgres_version;

\echo '============================================================'
\echo '11-E.15 END'
\echo '============================================================'
