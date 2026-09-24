\set ON_ERROR_STOP on

\pset pager off
\pset tuples_only off
\pset format aligned

SELECT
    'FUNCTION_SOURCE' AS section,
    p.proname,
    pg_get_function_identity_arguments(p.oid) AS signature
FROM pg_proc p
JOIN pg_namespace n ON n.oid = p.pronamespace
WHERE n.nspname = 'public'
  AND p.proname IN (
      'complete_stage_atomically',
      'fail_stage_atomically'
  )
ORDER BY p.proname;

SELECT
    'COMPLETE_SOURCE' AS section,
    pg_get_functiondef(p.oid)
FROM pg_proc p
JOIN pg_namespace n ON n.oid = p.pronamespace
WHERE n.nspname = 'public'
  AND p.proname = 'complete_stage_atomically';

SELECT
    'FAIL_STAGE_SOURCE' AS section,
    pg_get_functiondef(p.oid)
FROM pg_proc p
JOIN pg_namespace n ON n.oid = p.pronamespace
WHERE n.nspname = 'public'
  AND p.proname = 'fail_stage_atomically';

-- ============================================================
-- LOCK / TABLE REFERENCES — COMPLETE
-- ============================================================

WITH src AS (
    SELECT pg_get_functiondef(p.oid) AS s
    FROM pg_proc p
    JOIN pg_namespace n ON n.oid = p.pronamespace
    WHERE n.nspname='public'
      AND p.proname='complete_stage_atomically'
)
SELECT
    'COMPLETE_MARKER' AS marker,
    x.label,
    x.pos,
    substring(src.s FROM greatest(x.pos-180,1) FOR 360) AS context
FROM src
CROSS JOIN LATERAL (
    VALUES
      ('STAGE_FOR_UPDATE', position('production_stage ps WHERE ps.stage_id = p_stage_id FOR UPDATE' IN src.s)),
      ('STAGE_FOR_SHARE', position('production_stage ps WHERE ps.stage_id = p_stage_id FOR SHARE' IN src.s)),
      ('ARTIFACT_FOR_SHARE', position('artifact_registry ar' IN src.s)),
      ('PRODUCTION_RUN', position('production_run' IN src.s)),
      ('STAGE_EVENT', position('production_stage_event' IN src.s)),
      ('RUN_EVENT', position('production_run_event' IN src.s)),
      ('RECORD_EXECUTION_EVENT', position('record_execution_event' IN src.s)),
      ('VALIDATE_STAGE_ARTIFACTS', position('validate_stage_artifacts' IN src.s))
) AS x(label,pos)
ORDER BY x.pos;

-- ============================================================
-- LOCK / TABLE REFERENCES — FAIL_STAGE
-- ============================================================

WITH src AS (
    SELECT pg_get_functiondef(p.oid) AS s
    FROM pg_proc p
    JOIN pg_namespace n ON n.oid = p.pronamespace
    WHERE n.nspname='public'
      AND p.proname='fail_stage_atomically'
)
SELECT
    'FAIL_STAGE_MARKER' AS marker,
    x.label,
    x.pos,
    substring(src.s FROM greatest(x.pos-180,1) FOR 360) AS context
FROM src
CROSS JOIN LATERAL (
    VALUES
      ('RUN_FOR_UPDATE', position('production_run pr WHERE pr.run_id = v_run_id FOR UPDATE' IN src.s)),
      ('STAGE_FOR_UPDATE', position('production_stage ps WHERE ps.stage_id = p_stage_id FOR UPDATE' IN src.s)),
      ('ARTIFACT_FOR_SHARE', position('artifact_registry' IN src.s)),
      ('STAGE_EVENT', position('production_stage_event' IN src.s)),
      ('RUN_EVENT', position('production_run_event' IN src.s)),
      ('RECORD_EXECUTION_EVENT', position('record_execution_event' IN src.s)),
      ('CLASSIFY_ERROR', position('classify_error' IN src.s))
) AS x(label,pos)
ORDER BY x.pos;

-- ============================================================
-- ALL FUNCTIONS CALLED DIRECTLY BY COMPLETE / FAIL_STAGE
-- ============================================================

WITH src AS (
    SELECT
      p.proname,
      pg_get_functiondef(p.oid) AS s
    FROM pg_proc p
    JOIN pg_namespace n ON n.oid=p.pronamespace
    WHERE n.nspname='public'
      AND p.proname IN ('complete_stage_atomically','fail_stage_atomically')
)
SELECT
    proname,
    regexp_matches(
        upper(s),
        '\m([A-Z_][A-Z0-9_]*)\s*\(',
        'g'
    ) AS token
FROM src
ORDER BY proname;

-- ============================================================
-- TRIGGERS ON ALL TABLES TOUCHED BY THESE FUNCTIONS
-- ============================================================

SELECT
    event_object_table AS table_name,
    trigger_name,
    action_statement
FROM information_schema.triggers
WHERE event_object_schema='public'
  AND event_object_table IN (
      'production_run',
      'production_stage',
      'production_stage_event',
      'production_run_event',
      'artifact_registry',
      'production_execution_event'
  )
ORDER BY event_object_table, trigger_name;

-- ============================================================
-- TRIGGER FUNCTIONS
-- ============================================================

SELECT
    tg.tgname AS trigger_name,
    c.relname AS table_name,
    p.proname AS function_name,
    pg_get_functiondef(p.oid)
FROM pg_trigger tg
JOIN pg_class c ON c.oid=tg.tgrelid
JOIN pg_proc p ON p.oid=tg.tgfoid
JOIN pg_namespace n ON n.oid=p.pronamespace
WHERE NOT tg.tgisinternal
  AND c.relnamespace = 'public'::regnamespace
  AND c.relname IN (
      'production_run',
      'production_stage',
      'production_stage_event',
      'production_run_event',
      'artifact_registry',
      'production_execution_event'
  )
ORDER BY c.relname, tg.tgname;

-- ============================================================
-- FK CONSTRAINTS ON TOUCHED TABLES
-- ============================================================

SELECT
    tc.table_name,
    tc.constraint_name,
    kcu.column_name,
    ccu.table_name AS foreign_table_name,
    ccu.column_name AS foreign_column_name
FROM information_schema.table_constraints tc
JOIN information_schema.key_column_usage kcu
  ON tc.constraint_name=kcu.constraint_name
 AND tc.table_schema=kcu.table_schema
JOIN information_schema.constraint_column_usage ccu
  ON tc.constraint_name=ccu.constraint_name
 AND tc.table_schema=ccu.table_schema
WHERE tc.constraint_type='FOREIGN KEY'
  AND tc.table_schema='public'
  AND (
      tc.table_name IN (
        'production_run',
        'production_stage',
        'production_stage_event',
        'production_run_event',
        'artifact_registry',
        'production_execution_event'
      )
      OR ccu.table_name IN (
        'production_run',
        'production_stage',
        'production_stage_event',
        'production_run_event',
        'artifact_registry',
        'production_execution_event'
      )
  )
ORDER BY tc.table_name, tc.constraint_name, kcu.ordinal_position;

-- ============================================================
-- FUNCTION DEFINITIONS INVOKED BY COMPLETE
-- ============================================================

SELECT
    p.proname,
    pg_get_function_identity_arguments(p.oid) AS signature,
    md5(pg_get_functiondef(p.oid)) AS source_md5
FROM pg_proc p
JOIN pg_namespace n ON n.oid=p.pronamespace
WHERE n.nspname='public'
  AND p.proname IN (
      'complete_stage_atomically',
      'fail_stage_atomically',
      'validate_stage_artifacts',
      'record_execution_event',
      'validate_run_stage_consistency'
  )
ORDER BY p.proname;

-- ============================================================
-- CURRENT DATABASE ERROR STATE
-- ============================================================

SELECT
    'ERROR_RUNS' AS metric,
    count(*)
FROM public.production_run
WHERE status='ERROR';

SELECT
    'ERROR_STAGES' AS metric,
    count(*)
FROM public.production_stage
WHERE status='ERROR';

SELECT
    '11-F.3-B-DIAGNOSTIC' AS result;
