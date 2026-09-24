\pset pager off
\pset format aligned
\pset border 1

\echo '============================================================'
\echo '11-E.17 — FAILURE CONTRACT FORENSICS'
\echo '============================================================'

\echo '============================================================'
\echo '1. production_stage COLUMNS / DEFAULTS / CHECKS'
\echo '============================================================'

SELECT
    a.attnum,
    a.attname AS column_name,
    pg_catalog.format_type(a.atttypid, a.atttypmod) AS data_type,
    a.attnotnull AS not_null,
    pg_get_expr(d.adbin, d.adrelid) AS default_value
FROM pg_attribute a
LEFT JOIN pg_attrdef d
    ON d.adrelid = a.attrelid
   AND d.adnum = a.attnum
WHERE a.attrelid = 'public.production_stage'::regclass
  AND a.attnum > 0
  AND NOT a.attisdropped
ORDER BY a.attnum;

\echo '============================================================'
\echo '2. production_stage CHECK CONSTRAINTS'
\echo '============================================================'

SELECT
    conname,
    pg_get_constraintdef(oid) AS constraint_definition
FROM pg_constraint
WHERE conrelid = 'public.production_stage'::regclass
ORDER BY conname;

\echo '============================================================'
\echo '3. production_stage_event COLUMNS'
\echo '============================================================'

SELECT
    a.attnum,
    a.attname AS column_name,
    pg_catalog.format_type(a.atttypid, a.atttypmod) AS data_type,
    a.attnotnull AS not_null,
    pg_get_expr(d.adbin, d.adrelid) AS default_value
FROM pg_attribute a
LEFT JOIN pg_attrdef d
    ON d.adrelid = a.attrelid
   AND d.adnum = a.attnum
WHERE a.attrelid = 'public.production_stage_event'::regclass
  AND a.attnum > 0
  AND NOT a.attisdropped
ORDER BY a.attnum;

\echo '============================================================'
\echo '4. production_stage_event CHECK CONSTRAINTS'
\echo '============================================================'

SELECT
    conname,
    pg_get_constraintdef(oid) AS constraint_definition
FROM pg_constraint
WHERE conrelid = 'public.production_stage_event'::regclass
ORDER BY conname;

\echo '============================================================'
\echo '5. HISTORICAL ERROR EVENTS — RAW'
\echo '============================================================'

SELECT *
FROM production_stage_event
WHERE from_status = 'ERROR'
   OR to_status = 'ERROR'
   OR event_type IN ('STAGE_ERROR','RETRY')
ORDER BY created_at, id;

\echo '============================================================'
\echo '6. HISTORICAL ERROR STAGE SNAPSHOTS — IF ANY'
\echo '============================================================'

SELECT
    stage_id,
    run_id,
    stage_name,
    status,
    attempt,
    retryable,
    error_code,
    error_message,
    input_artifact_ids,
    output_artifact_ids,
    input_json,
    output_json,
    started_at,
    completed_at,
    created_at,
    updated_at,
    idempotency_key
FROM production_stage
WHERE status = 'ERROR'
   OR error_code IS NOT NULL
   OR error_message IS NOT NULL
   OR retryable = TRUE
ORDER BY created_at, stage_id;

\echo '============================================================'
\echo '7. STAGE DEFINITIONS — RECOVERY POLICY'
\echo '============================================================'

SELECT
    stage_name,
    version,
    enabled,
    max_attempts,
    retry_policy,
    recovery_policy,
    idempotency_policy,
    executor_type
FROM stage_definition
ORDER BY stage_name, version;

\echo '============================================================'
\echo '8. RUN TRANSITION MATRIX — ERROR'
\echo '============================================================'

SELECT
    p.oid,
    p.proname,
    pg_get_function_identity_arguments(p.oid) AS arguments
FROM pg_proc p
JOIN pg_namespace n
    ON n.oid = p.pronamespace
WHERE n.nspname = 'public'
  AND p.prosrc ILIKE '%status = ''ERROR''%'
ORDER BY p.proname, p.oid;

\echo '============================================================'
\echo '11-E.17 END'
\echo '============================================================'
