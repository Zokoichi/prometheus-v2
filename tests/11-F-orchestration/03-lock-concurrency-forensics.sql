\set ON_ERROR_STOP on
\timing off

\echo ============================================================
\echo PROMETHEUS V2 - 11-F.3-A LOCK / CONCURRENCY FORENSICS
\echo READ-ONLY
\echo ============================================================

BEGIN;

\echo
\echo ============================================================
\echo 01. PRIMITIVE INVENTORY
\echo ============================================================

SELECT
    p.proname AS function_name,
    pg_get_function_identity_arguments(p.oid) AS arguments
FROM pg_proc p
JOIN pg_namespace n ON n.oid = p.pronamespace
WHERE n.nspname = 'public'
  AND p.proname IN (
      'claim_stage_for_execution',
      'complete_stage_atomically',
      'fail_stage_atomically',
      'fail_run_atomically',
      'record_execution_event',
      'validate_stage_artifacts',
      'validate_run_stage_consistency'
  )
ORDER BY p.proname;

\echo
\echo ============================================================
\echo 02. CLAIM SOURCE
\echo ============================================================

SELECT pg_get_functiondef(p.oid)
FROM pg_proc p
JOIN pg_namespace n ON n.oid = p.pronamespace
WHERE n.nspname = 'public'
  AND p.proname = 'claim_stage_for_execution'
ORDER BY p.oid
LIMIT 1;

\echo
\echo ============================================================
\echo 03. COMPLETE SOURCE
\echo ============================================================

SELECT pg_get_functiondef(p.oid)
FROM pg_proc p
JOIN pg_namespace n ON n.oid = p.pronamespace
WHERE n.nspname = 'public'
  AND p.proname = 'complete_stage_atomically'
ORDER BY p.oid
LIMIT 1;

\echo
\echo ============================================================
\echo 04. FAIL STAGE SOURCE
\echo ============================================================

SELECT pg_get_functiondef(p.oid)
FROM pg_proc p
JOIN pg_namespace n ON n.oid = p.pronamespace
WHERE n.nspname = 'public'
  AND p.proname = 'fail_stage_atomically'
ORDER BY p.oid
LIMIT 1;

\echo
\echo ============================================================
\echo 05. FAIL RUN SOURCE
\echo ============================================================

SELECT pg_get_functiondef(p.oid)
FROM pg_proc p
JOIN pg_namespace n ON n.oid = p.pronamespace
WHERE n.nspname = 'public'
  AND p.proname = 'fail_run_atomically'
ORDER BY p.oid
LIMIT 1;

\echo
\echo ============================================================
\echo 06. EXECUTION EVENT SOURCE
\echo ============================================================

SELECT pg_get_functiondef(p.oid)
FROM pg_proc p
JOIN pg_namespace n ON n.oid = p.pronamespace
WHERE n.nspname = 'public'
  AND p.proname = 'record_execution_event'
ORDER BY p.oid
LIMIT 1;

\echo
\echo ============================================================
\echo 07. TRIGGER INVENTORY
\echo ============================================================

SELECT
    n.nspname AS schema_name,
    c.relname AS table_name,
    t.tgname AS trigger_name,
    pg_get_triggerdef(t.oid) AS trigger_definition
FROM pg_trigger t
JOIN pg_class c ON c.oid = t.tgrelid
JOIN pg_namespace n ON n.oid = c.relnamespace
WHERE NOT t.tgisinternal
  AND n.nspname = 'public'
ORDER BY c.relname, t.tgname;

\echo
\echo ============================================================
\echo 08. FUNCTIONS REFERENCED BY TRIGGERS
\echo ============================================================

SELECT DISTINCT
    p.proname AS trigger_function,
    pg_get_function_identity_arguments(p.oid) AS arguments
FROM pg_proc p
JOIN pg_namespace n ON n.oid = p.pronamespace
WHERE n.nspname = 'public'
  AND p.oid IN (
      SELECT t.tgfoid
      FROM pg_trigger t
      JOIN pg_class c ON c.oid = t.tgrelid
      JOIN pg_namespace tn ON tn.oid = c.relnamespace
      WHERE NOT t.tgisinternal
        AND tn.nspname = 'public'
  )
ORDER BY p.proname;

\echo
\echo ============================================================
\echo 09. TABLE LOCK TARGETS / FOREIGN KEYS
\echo ============================================================

SELECT
    tc.table_name,
    kcu.column_name,
    ccu.table_name AS referenced_table,
    ccu.column_name AS referenced_column,
    tc.constraint_name
FROM information_schema.table_constraints tc
JOIN information_schema.key_column_usage kcu
  ON tc.constraint_name = kcu.constraint_name
 AND tc.table_schema = kcu.table_schema
JOIN information_schema.constraint_column_usage ccu
  ON ccu.constraint_name = tc.constraint_name
 AND ccu.table_schema = tc.table_schema
WHERE tc.constraint_type = 'FOREIGN KEY'
  AND tc.table_schema = 'public'
ORDER BY tc.table_name, tc.constraint_name;

\echo
\echo ============================================================
\echo 10. ADVISORY LOCK REFERENCES
\echo ============================================================

SELECT
    p.proname AS function_name,
    CASE
        WHEN pg_get_functiondef(p.oid) ILIKE '%pg_advisory%'
        THEN 'ADVISORY_LOCK_PRESENT'
        ELSE 'NO_ADVISORY_LOCK_REFERENCE'
    END AS advisory_lock_status
FROM pg_proc p
JOIN pg_namespace n ON n.oid = p.pronamespace
WHERE n.nspname = 'public'
  AND p.proname IN (
      'claim_stage_for_execution',
      'complete_stage_atomically',
      'fail_stage_atomically',
      'fail_run_atomically',
      'record_execution_event',
      'validate_stage_artifacts',
      'validate_run_stage_consistency'
  )
ORDER BY p.proname;

\echo
\echo ============================================================
\echo 11. RUN / STAGE STATUS DISTRIBUTION
\echo ============================================================

SELECT
    status,
    COUNT(*) AS count
FROM public.production_run
GROUP BY status
ORDER BY status;

SELECT
    status,
    COUNT(*) AS count
FROM public.production_stage
GROUP BY status
ORDER BY status;

\echo
\echo ============================================================
\echo 12. ACTIVE / NONTERMINAL STAGES
\echo ============================================================

SELECT
    stage_id,
    run_id,
    stage_name,
    stage_order,
    status,
    attempt,
    retryable,
    idempotency_key
FROM public.production_stage
WHERE status IN ('PENDING','RUNNING','ERROR')
ORDER BY run_id, stage_order;

\echo
\echo ============================================================
\echo 13. DEPENDENCY GRAPH
\echo ============================================================

SELECT
    d.stage_id,
    s.stage_name AS stage_name,
    d.depends_on_stage_id,
    ds.stage_name AS depends_on_stage_name,
    d.dependency_type
FROM public.production_stage_dependency d
JOIN public.production_stage s
  ON s.stage_id = d.stage_id
JOIN public.production_stage ds
  ON ds.stage_id = d.depends_on_stage_id
ORDER BY s.run_id, s.stage_order, d.depends_on_stage_id;

\echo
\echo ============================================================
\echo 14. EXECUTION EVENT UNIQUENESS
\echo ============================================================

SELECT
    indexname,
    indexdef
FROM pg_indexes
WHERE schemaname = 'public'
  AND tablename = 'production_execution_event'
ORDER BY indexname;

\echo
\echo ============================================================
\echo 15. STAGE IDEMPOTENCY UNIQUENESS
\echo ============================================================

SELECT
    indexname,
    indexdef
FROM pg_indexes
WHERE schemaname = 'public'
  AND tablename = 'production_stage'
ORDER BY indexname;

\echo
\echo ============================================================
\echo 16. POTENTIAL ORCHESTRATOR / DISPATCHER FUNCTIONS
\echo ============================================================

SELECT
    p.proname AS function_name,
    pg_get_function_identity_arguments(p.oid) AS arguments
FROM pg_proc p
JOIN pg_namespace n ON n.oid = p.pronamespace
WHERE n.nspname = 'public'
  AND (
      p.proname ILIKE '%orchestrat%'
      OR p.proname ILIKE '%dispatch%'
      OR p.proname ILIKE '%scheduler%'
      OR p.proname ILIKE '%run_next%'
      OR p.proname ILIKE '%execute_stage%'
      OR p.proname ILIKE '%stage_executor%'
      OR p.proname ILIKE '%worker%'
  )
ORDER BY p.proname;

\echo
\echo ============================================================
\echo 17. STAGE DEFINITIONS / EXECUTOR CONTRACT
\echo ============================================================

SELECT
    stage_name,
    version,
    executor_type,
    timeout_seconds,
    max_attempts,
    retry_policy,
    idempotency_policy,
    validation_contract,
    recovery_policy,
    enabled
FROM public.stage_definition
ORDER BY stage_name, version;

\echo
\echo ============================================================
\echo 18. CONTRACT / PRODUCER / CONSUMER MAP
\echo ============================================================

SELECT
    contract_name,
    version,
    producer,
    consumers,
    enabled
FROM public.contract_definition
ORDER BY contract_name, version;

\echo
\echo ============================================================
\echo 19. PRODUCTION EXECUTION EVENT STATE
\echo ============================================================

SELECT
    event_id,
    run_id,
    stage_id,
    stage_name,
    attempt,
    event_type,
    provider,
    executor_type,
    status,
    started_at,
    completed_at,
    duration_ms
FROM public.production_execution_event
ORDER BY created_at;

\echo
\echo ============================================================
\echo 20. CURRENT DATABASE INTEGRITY
\echo ============================================================

SELECT
    (SELECT COUNT(*) FROM public.production_run) AS runs,
    (SELECT COUNT(*) FROM public.production_stage) AS stages,
    (SELECT COUNT(*) FROM public.production_stage_dependency) AS dependencies,
    (SELECT COUNT(*) FROM public.production_run_event) AS run_events,
    (SELECT COUNT(*) FROM public.production_stage_event) AS stage_events,
    (SELECT COUNT(*) FROM public.production_execution_event) AS execution_events,
    (SELECT COUNT(*) FROM public.artifact_registry) AS artifacts;

SELECT
    (SELECT COUNT(*)
     FROM public.production_run
     WHERE status = 'ERROR') AS error_runs,
    (SELECT COUNT(*)
     FROM public.production_stage
     WHERE status = 'ERROR') AS error_stages;

\echo
\echo ============================================================
\echo 21. FUNCTION SOURCE HASHES
\echo ============================================================

SELECT
    p.proname AS function_name,
    md5(pg_get_functiondef(p.oid)) AS source_md5
FROM pg_proc p
JOIN pg_namespace n ON n.oid = p.pronamespace
WHERE n.nspname = 'public'
  AND p.proname IN (
      'claim_stage_for_execution',
      'complete_stage_atomically',
      'fail_stage_atomically',
      'fail_run_atomically',
      'record_execution_event',
      'validate_stage_artifacts',
      'validate_run_stage_consistency'
  )
ORDER BY p.proname;

\echo
\echo ============================================================
\echo 22. FORENSIC SUMMARY
\echo ============================================================

DO $$
DECLARE
    v_claim INTEGER;
    v_complete INTEGER;
    v_fail_stage INTEGER;
    v_fail_run INTEGER;
    v_event INTEGER;
    v_artifact INTEGER;
    v_consistency INTEGER;
BEGIN

    SELECT COUNT(*) INTO v_claim
    FROM pg_proc p
    JOIN pg_namespace n ON n.oid = p.pronamespace
    WHERE n.nspname='public'
      AND p.proname='claim_stage_for_execution';

    SELECT COUNT(*) INTO v_complete
    FROM pg_proc p
    JOIN pg_namespace n ON n.oid = p.pronamespace
    WHERE n.nspname='public'
      AND p.proname='complete_stage_atomically';

    SELECT COUNT(*) INTO v_fail_stage
    FROM pg_proc p
    JOIN pg_namespace n ON n.oid = p.pronamespace
    WHERE n.nspname='public'
      AND p.proname='fail_stage_atomically';

    SELECT COUNT(*) INTO v_fail_run
    FROM pg_proc p
    JOIN pg_namespace n ON n.oid = p.pronamespace
    WHERE n.nspname='public'
      AND p.proname='fail_run_atomically';

    SELECT COUNT(*) INTO v_event
    FROM pg_proc p
    JOIN pg_namespace n ON n.oid = p.pronamespace
    WHERE n.nspname='public'
      AND p.proname='record_execution_event';

    SELECT COUNT(*) INTO v_artifact
    FROM pg_proc p
    JOIN pg_namespace n ON n.oid = p.pronamespace
    WHERE n.nspname='public'
      AND p.proname='validate_stage_artifacts';

    SELECT COUNT(*) INTO v_consistency
    FROM pg_proc p
    JOIN pg_namespace n ON n.oid = p.pronamespace
    WHERE n.nspname='public'
      AND p.proname='validate_run_stage_consistency';

    IF v_claim <> 1
       OR v_complete <> 1
       OR v_fail_stage <> 1
       OR v_fail_run <> 1
       OR v_event <> 1
       OR v_artifact <> 1
       OR v_consistency <> 1
    THEN
        RAISE EXCEPTION
            'FORENSIC_FAIL: primitive inventory is not exactly one each';
    END IF;

    RAISE NOTICE
        'PASS: all required orchestration primitives uniquely identified';
END $$;

ROLLBACK;

\echo
\echo ============================================================
\echo 11-F.3-A FORENSICS COMPLETE
\echo NO DATABASE MUTATION
\echo ============================================================
