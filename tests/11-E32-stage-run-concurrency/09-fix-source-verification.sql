\set ON_ERROR_STOP on
\pset pager off

\echo ============================================================
\echo 11-E.32-FIX-VERIFY
\echo INSTALLED FUNCTION — EXECUTION ORDER FORENSICS
\echo READ ONLY
\echo ============================================================

\echo
\echo === 01. INSTALLED FUNCTION COUNT ===

SELECT COUNT(*) AS function_count
FROM pg_proc p
JOIN pg_namespace n ON n.oid = p.pronamespace
WHERE n.nspname = 'public'
  AND p.proname = 'fail_stage_atomically';

\echo
\echo === 02. RUN LOCK STATEMENT ===

SELECT
    substring(
        pg_get_functiondef(p.oid)
        FROM 'PERFORM 1.*?FOR UPDATE;'
    ) AS run_lock_statement
FROM pg_proc p
JOIN pg_namespace n ON n.oid = p.pronamespace
WHERE n.nspname = 'public'
  AND p.proname = 'fail_stage_atomically';

\echo
\echo === 03. STAGE LOCK STATEMENT ===

SELECT
    substring(
        pg_get_functiondef(p.oid)
        FROM 'SELECT \*.*?FROM public.production_stage.*?FOR UPDATE;'
    ) AS stage_lock_statement
FROM pg_proc p
JOIN pg_namespace n ON n.oid = p.pronamespace
WHERE n.nspname = 'public'
  AND p.proname = 'fail_stage_atomically';

\echo
\echo === 04. SOURCE ORDER MARKERS ===

WITH f AS (
    SELECT pg_get_functiondef(p.oid) AS d
    FROM pg_proc p
    JOIN pg_namespace n ON n.oid = p.pronamespace
    WHERE n.nspname = 'public'
      AND p.proname = 'fail_stage_atomically'
),
m AS (
    SELECT
        d,
        strpos(d, 'PERFORM 1') AS run_lock_pos,
        strpos(d, 'FOR UPDATE;') AS first_for_update_pos,
        strpos(
            d,
            'SELECT *'
        ) AS stage_select_pos
    FROM f
)
SELECT
    run_lock_pos,
    first_for_update_pos,
    stage_select_pos,
    CASE
        WHEN run_lock_pos > 0
         AND first_for_update_pos > 0
         AND stage_select_pos > 0
         AND first_for_update_pos < stage_select_pos
        THEN 'PASS'
        ELSE 'REVIEW_REQUIRED'
    END AS structural_check
FROM m;

\echo
\echo === 05. REQUIRED INSTALLED BEHAVIOUR MARKERS ===

WITH f AS (
    SELECT pg_get_functiondef(p.oid) AS d
    FROM pg_proc p
    JOIN pg_namespace n ON n.oid = p.pronamespace
    WHERE n.nspname = 'public'
      AND p.proname = 'fail_stage_atomically'
)
SELECT
    CASE WHEN d LIKE '%FROM public.production_run pr%' THEN 'PASS' ELSE 'FAIL' END
        AS run_lock_source,
    CASE WHEN d LIKE '%FOR UPDATE%' THEN 'PASS' ELSE 'FAIL' END
        AS for_update_present,
    CASE WHEN d LIKE '%FROM public.production_stage ps%' THEN 'PASS' ELSE 'FAIL' END
        AS stage_source,
    CASE WHEN d LIKE '%STAGE_ERROR%' THEN 'PASS' ELSE 'FAIL' END
        AS stage_error_event,
    CASE WHEN d LIKE '%classify_error%' THEN 'PASS' ELSE 'FAIL' END
        AS error_classification
FROM f;

\echo
\echo === 06. DATABASE STATE ===

SELECT
    COUNT(*) FILTER (WHERE status = 'ERROR') AS error_stages,
    COUNT(*) FILTER (WHERE status = 'ERROR' AND retryable = TRUE) AS retryable_error_stages,
    COUNT(*) FILTER (WHERE status = 'ERROR' AND retryable = FALSE) AS terminal_error_stages
FROM production_stage;

SELECT
    COUNT(*) FILTER (WHERE status = 'ERROR') AS error_runs
FROM production_run;

SELECT COUNT(*) AS fixture_runs
FROM production_run
WHERE run_id = 'RUN-11E32-FIXTURE';

SELECT COUNT(*) AS fixture_stages
FROM production_stage
WHERE stage_id = 'STG-11E32-FIXTURE';

\echo
\echo ============================================================
\echo 11-E.32-FIX-VERIFY END
\echo ============================================================
