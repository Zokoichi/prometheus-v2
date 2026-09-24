\pset pager off
\pset format aligned
\pset border 1

\echo '============================================================'
\echo '11-E.13 — ERROR POLICY DATA + USAGE'
\echo '============================================================'

\echo '============================================================'
\echo '1. COMPLETE ERROR POLICY DATA'
\echo '============================================================'

SELECT
    id,
    error_code,
    category,
    retryable,
    max_attempts,
    initial_backoff_seconds,
    backoff_multiplier,
    max_backoff_seconds,
    description,
    enabled
FROM error_policy
ORDER BY id;

\echo '============================================================'
\echo '2. ERROR POLICY COUNTS'
\echo '============================================================'

SELECT
    enabled,
    retryable,
    COUNT(*) AS count
FROM error_policy
GROUP BY enabled, retryable
ORDER BY enabled DESC, retryable DESC;

\echo '============================================================'
\echo '3. CLASSIFY EVERY REGISTERED ERROR CODE — ATTEMPT 1'
\echo '============================================================'

SELECT
    ep.error_code,
    ep.category,
    ep.retryable,
    ep.max_attempts,
    ce.retry_allowed,
    ce.next_backoff_seconds,
    ce.message
FROM error_policy ep
CROSS JOIN LATERAL classify_error(ep.error_code, 1) ce
ORDER BY ep.id;

\echo '============================================================'
\echo '4. CLASSIFY EVERY REGISTERED RETRYABLE ERROR — BOUNDARY'
\echo '============================================================'

SELECT
    ep.error_code,
    ep.max_attempts,
    ep.initial_backoff_seconds,
    ep.backoff_multiplier,
    ep.max_backoff_seconds,
    ce.retry_allowed,
    ce.next_backoff_seconds,
    ce.message
FROM error_policy ep
CROSS JOIN LATERAL classify_error(
    ep.error_code,
    ep.max_attempts
) ce
WHERE ep.retryable = TRUE
ORDER BY ep.id;

\echo '============================================================'
\echo '5. FUNCTIONS WHOSE SOURCE REFERENCES ERROR_POLICY'
\echo '============================================================'

SELECT
    n.nspname AS schema_name,
    p.proname AS function_name,
    pg_get_function_identity_arguments(p.oid) AS arguments
FROM pg_proc p
JOIN pg_namespace n
    ON n.oid = p.pronamespace
WHERE n.nspname = 'public'
  AND pg_get_functiondef(p.oid) ILIKE '%error_policy%'
ORDER BY p.proname, p.oid;

\echo '============================================================'
\echo '6. FUNCTIONS WHOSE SOURCE REFERENCES CLASSIFY_ERROR'
\echo '============================================================'

SELECT
    n.nspname AS schema_name,
    p.proname AS function_name,
    pg_get_function_identity_arguments(p.oid) AS arguments
FROM pg_proc p
JOIN pg_namespace n
    ON n.oid = p.pronamespace
WHERE n.nspname = 'public'
  AND pg_get_functiondef(p.oid) ILIKE '%classify_error%'
ORDER BY p.proname, p.oid;

\echo '============================================================'
\echo '7. STAGE ERROR / RETRY CONSTRAINTS'
\echo '============================================================'

SELECT
    conname,
    pg_get_constraintdef(oid)
FROM pg_constraint
WHERE conrelid = 'public.production_stage'::regclass
ORDER BY conname;

\echo '============================================================'
\echo '8. STAGE EVENT CONSTRAINTS'
\echo '============================================================'

SELECT
    conname,
    pg_get_constraintdef(oid)
FROM pg_constraint
WHERE conrelid = 'public.production_stage_event'::regclass
ORDER BY conname;

\echo '============================================================'
\echo '11-E.13 END'
\echo '============================================================'
