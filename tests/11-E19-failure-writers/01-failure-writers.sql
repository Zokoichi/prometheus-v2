\pset pager off
\pset format aligned
\pset border 1

\echo '============================================================'
\echo '11-E.19 — FAILURE WRITERS FORENSICS'
\echo '============================================================'

\echo '============================================================'
\echo '1. ALL PUBLIC FUNCTIONS — IDENTIFICATION'
\echo '============================================================'

SELECT
    p.oid,
    p.proname,
    pg_get_function_identity_arguments(p.oid) AS arguments
FROM pg_proc p
JOIN pg_namespace n ON n.oid = p.pronamespace
WHERE n.nspname = 'public'
  AND p.prokind = 'f'
ORDER BY p.proname, p.oid;

\echo '============================================================'
\echo '2. ROUTINES WHOSE SOURCE CONTAINS request_run_transition'
\echo '============================================================'

SELECT
    p.oid,
    p.proname,
    pg_get_function_identity_arguments(p.oid) AS arguments,
    position('request_run_transition' in pg_get_functiondef(p.oid)) AS source_position
FROM pg_proc p
JOIN pg_namespace n ON n.oid = p.pronamespace
WHERE n.nspname = 'public'
  AND p.prokind = 'f'
  AND position('request_run_transition' in pg_get_functiondef(p.oid)) > 0
ORDER BY p.proname, p.oid;

\echo '============================================================'
\echo '3. ROUTINES WHOSE SOURCE WRITES production_run'
\echo '============================================================'

SELECT
    p.oid,
    p.proname,
    pg_get_function_identity_arguments(p.oid) AS arguments,
    CASE
        WHEN position('UPDATE production_run' in pg_get_functiondef(p.oid)) > 0
            THEN 'UPDATE production_run'
        WHEN position('UPDATE public.production_run' in pg_get_functiondef(p.oid)) > 0
            THEN 'UPDATE public.production_run'
        ELSE 'OTHER'
    END AS detected_write
FROM pg_proc p
JOIN pg_namespace n ON n.oid = p.pronamespace
WHERE n.nspname = 'public'
  AND p.prokind = 'f'
  AND (
       position('UPDATE production_run' in pg_get_functiondef(p.oid)) > 0
    OR position('UPDATE public.production_run' in pg_get_functiondef(p.oid)) > 0
  )
ORDER BY p.proname, p.oid;

\echo '============================================================'
\echo '4. ROUTINES WHOSE SOURCE WRITES production_stage'
\echo '============================================================'

SELECT
    p.oid,
    p.proname,
    pg_get_function_identity_arguments(p.oid) AS arguments,
    CASE
        WHEN position('UPDATE production_stage' in pg_get_functiondef(p.oid)) > 0
            THEN 'UPDATE production_stage'
        WHEN position('UPDATE public.production_stage' in pg_get_functiondef(p.oid)) > 0
            THEN 'UPDATE public.production_stage'
        ELSE 'OTHER'
    END AS detected_write
FROM pg_proc p
JOIN pg_namespace n ON n.oid = p.pronamespace
WHERE n.nspname = 'public'
  AND p.prokind = 'f'
  AND (
       position('UPDATE production_stage' in pg_get_functiondef(p.oid)) > 0
    OR position('UPDATE public.production_stage' in pg_get_functiondef(p.oid)) > 0
  )
ORDER BY p.proname, p.oid;

\echo '============================================================'
\echo '5. ROUTINES CONTAINING RUN ERROR TRANSITION'
\echo '============================================================'

SELECT
    p.oid,
    p.proname,
    pg_get_function_identity_arguments(p.oid) AS arguments
FROM pg_proc p
JOIN pg_namespace n ON n.oid = p.pronamespace
WHERE n.nspname = 'public'
  AND p.prokind = 'f'
  AND (
       position('p_to_status = ''ERROR''' in pg_get_functiondef(p.oid)) > 0
    OR position('to_status = ''ERROR''' in pg_get_functiondef(p.oid)) > 0
    OR position('status = ''ERROR''' in pg_get_functiondef(p.oid)) > 0
  )
ORDER BY p.proname, p.oid;

\echo '============================================================'
\echo '6. ROUTINES CONTAINING STAGE ERROR TRANSITION'
\echo '============================================================'

SELECT
    p.oid,
    p.proname,
    pg_get_function_identity_arguments(p.oid) AS arguments
FROM pg_proc p
JOIN pg_namespace n ON n.oid = p.pronamespace
WHERE n.nspname = 'public'
  AND p.prokind = 'f'
  AND (
       position('status = ''ERROR''' in pg_get_functiondef(p.oid)) > 0
    OR position('''ERROR'' + retryable' in pg_get_functiondef(p.oid)) > 0
    OR position('RUNNING' in pg_get_functiondef(p.oid)) > 0
  )
ORDER BY p.proname, p.oid;

\echo '============================================================'
\echo '7. production_stage EVENT WRITERS'
\echo '============================================================'

SELECT
    p.oid,
    p.proname,
    pg_get_function_identity_arguments(p.oid) AS arguments
FROM pg_proc p
JOIN pg_namespace n ON n.oid = p.pronamespace
WHERE n.nspname = 'public'
  AND p.prokind = 'f'
  AND position('production_stage_event' in pg_get_functiondef(p.oid)) > 0
ORDER BY p.proname, p.oid;

\echo '============================================================'
\echo '11-E.19 END'
\echo '============================================================'
