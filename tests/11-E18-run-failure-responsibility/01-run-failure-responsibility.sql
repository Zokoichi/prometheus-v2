\pset pager off
\pset format wrapped
\pset border 1
\pset expanded off

\echo '============================================================'
\echo '11-E.18 — RUN / FAILURE RESPONSIBILITY FORENSICS'
\echo '============================================================'

\echo '============================================================'
\echo '1. request_run_transition()'
\echo '============================================================'

SELECT pg_get_functiondef(p.oid)
FROM pg_proc p
JOIN pg_namespace n ON n.oid = p.pronamespace
WHERE n.nspname = 'public'
  AND p.proname = 'request_run_transition';

\echo '============================================================'
\echo '2. diagnose_run()'
\echo '============================================================'

SELECT pg_get_functiondef(p.oid)
FROM pg_proc p
JOIN pg_namespace n ON n.oid = p.pronamespace
WHERE n.nspname = 'public'
  AND p.proname = 'diagnose_run';

\echo '============================================================'
\echo '3. ALL ROUTINES REFERENCING request_run_transition'
\echo '============================================================'

SELECT
    p.oid,
    p.proname,
    pg_get_function_identity_arguments(p.oid) AS arguments
FROM pg_proc p
JOIN pg_namespace n ON n.oid = p.pronamespace
WHERE n.nspname = 'public'
  AND pg_get_functiondef(p.oid) ILIKE '%request_run_transition%'
ORDER BY p.proname, p.oid;

\echo '============================================================'
\echo '4. ALL ROUTINES REFERENCING diagnose_run'
\echo '============================================================'

SELECT
    p.oid,
    p.proname,
    pg_get_function_identity_arguments(p.oid) AS arguments
FROM pg_proc p
JOIN pg_namespace n ON n.oid = p.pronamespace
WHERE n.nspname = 'public'
  AND pg_get_functiondef(p.oid) ILIKE '%diagnose_run%'
ORDER BY p.proname, p.oid;

\echo '============================================================'
\echo '5. ALL ROUTINES WRITING production_run.status'
\echo '============================================================'

SELECT
    p.oid,
    p.proname,
    pg_get_function_identity_arguments(p.oid) AS arguments
FROM pg_proc p
JOIN pg_namespace n ON n.oid = p.pronamespace
WHERE n.nspname = 'public'
  AND (
       pg_get_functiondef(p.oid) ILIKE '%UPDATE production_run%'
    OR pg_get_functiondef(p.oid) ILIKE '%UPDATE public.production_run%'
    OR pg_get_functiondef(p.oid) ILIKE '%status = ''ERROR''%'
  )
ORDER BY p.proname, p.oid;

\echo '============================================================'
\echo '6. ALL ROUTINES WRITING production_stage.status'
\echo '============================================================'

SELECT
    p.oid,
    p.proname,
    pg_get_function_identity_arguments(p.oid) AS arguments
FROM pg_proc p
JOIN pg_namespace n ON n.oid = p.pronamespace
WHERE n.nspname = 'public'
  AND (
       pg_get_functiondef(p.oid) ILIKE '%UPDATE production_stage%'
    OR pg_get_functiondef(p.oid) ILIKE '%UPDATE public.production_stage%'
  )
ORDER BY p.proname, p.oid;

\echo '============================================================'
\echo '11-E.18 END'
\echo '============================================================'
