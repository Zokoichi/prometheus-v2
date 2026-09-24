\set ON_ERROR_STOP on
\pset pager off

\echo ============================================================
\echo 11-E.32-DIAG-2
\echo CONTRACT / CONSUMER FORENSICS
\echo READ ONLY
\echo ============================================================

\echo
\echo === 01. ALL FUNCTIONS REFERENCING CONSISTENCY ===

SELECT
    n.nspname AS schema_name,
    p.proname,
    pg_get_function_identity_arguments(p.oid) AS arguments
FROM pg_proc p
JOIN pg_namespace n
  ON n.oid = p.pronamespace
WHERE pg_get_functiondef(p.oid) ILIKE '%validate_run_stage_consistency%'
ORDER BY n.nspname, p.proname;

\echo
\echo === 02. ALL FUNCTIONS REFERENCING FAIL_RUN ===

SELECT
    n.nspname AS schema_name,
    p.proname,
    pg_get_function_identity_arguments(p.oid) AS arguments
FROM pg_proc p
JOIN pg_namespace n
  ON n.oid = p.pronamespace
WHERE pg_get_functiondef(p.oid) ILIKE '%fail_run_atomically%'
ORDER BY n.nspname, p.proname;

\echo
\echo === 03. RUN STATUS CONSTRAINT ===

SELECT
    conname,
    pg_get_constraintdef(oid) AS constraint_definition
FROM pg_constraint
WHERE conrelid = 'public.production_run'::regclass
ORDER BY conname;

\echo
\echo === 04. STAGE STATUS CONSTRAINT ===

SELECT
    conname,
    pg_get_constraintdef(oid) AS constraint_definition
FROM pg_constraint
WHERE conrelid = 'public.production_stage'::regclass
ORDER BY conname;

\echo
\echo === 05. RUN TRANSITION FUNCTION SOURCE ===

SELECT pg_get_functiondef(
    'public.request_run_transition(character varying,character varying,character varying,character varying,jsonb)'::regprocedure
);

\echo
\echo === 06. RUN TRANSITION REFERENCES TO ERROR ===

SELECT
    position('ERROR' in pg_get_functiondef(
        'public.request_run_transition(character varying,character varying,character varying,character varying,jsonb)'::regprocedure
    )) AS first_error_position,

    position('validate_run_stage_consistency' in pg_get_functiondef(
        'public.request_run_transition(character varying,character varying,character varying,character varying,jsonb)'::regprocedure
    )) AS consistency_position;

\echo
\echo === 07. STAGE DEFINITION ERROR / RECOVERY POLICIES ===

SELECT
    stage_name,
    version,
    max_attempts,
    retry_policy,
    recovery_policy,
    enabled
FROM stage_definition
ORDER BY stage_name, version;

\echo
\echo === 08. ERROR POLICY SUMMARY ===

SELECT
    category,
    COUNT(*) AS policy_count,
    COUNT(*) FILTER (WHERE retryable = TRUE) AS retryable_count,
    COUNT(*) FILTER (WHERE retryable = FALSE) AS permanent_count
FROM error_policy
GROUP BY category
ORDER BY category;

\echo
\echo === 09. PRODUCTION RUN STATUS DISTRIBUTION ===

SELECT
    status,
    COUNT(*) AS count
FROM production_run
GROUP BY status
ORDER BY status;

\echo
\echo === 10. PRODUCTION STAGE STATUS DISTRIBUTION ===

SELECT
    status,
    retryable,
    COUNT(*) AS count
FROM production_stage
GROUP BY status, retryable
ORDER BY status, retryable;

\echo
\echo === 11. FUNCTION INVENTORY ===

SELECT
    n.nspname AS schema_name,
    p.proname,
    pg_get_function_identity_arguments(p.oid) AS arguments
FROM pg_proc p
JOIN pg_namespace n
  ON n.oid = p.pronamespace
WHERE n.nspname = 'public'
  AND (
      p.proname ILIKE '%run%'
      OR p.proname ILIKE '%stage%'
      OR p.proname ILIKE '%retry%'
      OR p.proname ILIKE '%error%'
  )
ORDER BY p.proname, arguments;

\echo
\echo === 12. DATABASE CLEAN STATE ===

SELECT COUNT(*) AS error_stages
FROM production_stage
WHERE status = 'ERROR';

SELECT COUNT(*) AS error_runs
FROM production_run
WHERE status = 'ERROR';

SELECT COUNT(*) AS retryable_error_stages
FROM production_stage
WHERE status = 'ERROR'
  AND retryable = TRUE;

\echo
\echo ============================================================
\echo 11-E.32-DIAG-2 END
\echo ============================================================
