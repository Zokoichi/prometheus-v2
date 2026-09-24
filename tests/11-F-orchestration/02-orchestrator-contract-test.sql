\set ON_ERROR_STOP on
\timing off

\echo ============================================================
\echo PROMETHEUS V2 - 11-F.2 ORCHESTRATOR CONTRACT TEST
\echo READ-ONLY
\echo ============================================================

BEGIN;

\echo
\echo ============================================================
\echo 01. REQUIRED FUNCTIONS
\echo ============================================================

DO $$
DECLARE
    v_count INTEGER;
BEGIN
    SELECT COUNT(*)
    INTO v_count
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
      );

    IF v_count <> 7 THEN
        RAISE EXCEPTION
            'CONTRACT_FAIL: expected 7 orchestration primitives, found %',
            v_count;
    END IF;

    RAISE NOTICE 'PASS: all 7 orchestration primitives exist';
END $$;

\echo
\echo ============================================================
\echo 02. REQUIRED TABLES
\echo ============================================================

DO $$
DECLARE
    v_missing INTEGER;
BEGIN
    SELECT COUNT(*)
    INTO v_missing
    FROM (
        VALUES
            ('production_run'),
            ('production_stage'),
            ('production_stage_dependency'),
            ('production_run_event'),
            ('production_stage_event'),
            ('production_execution_event'),
            ('artifact_registry'),
            ('stage_definition')
    ) AS required(table_name)
    WHERE NOT EXISTS (
        SELECT 1
        FROM information_schema.tables t
        WHERE t.table_schema = 'public'
          AND t.table_name = required.table_name
    );

    IF v_missing <> 0 THEN
        RAISE EXCEPTION
            'CONTRACT_FAIL: % required tables are missing',
            v_missing;
    END IF;

    RAISE NOTICE 'PASS: all required orchestration tables exist';
END $$;

\echo
\echo ============================================================
\echo 03. STAGE CLAIM CONTRACT
\echo ============================================================

DO $$
DECLARE
    v_def TEXT;
BEGIN
    SELECT pg_get_functiondef(p.oid)
    INTO v_def
    FROM pg_proc p
    JOIN pg_namespace n ON n.oid = p.pronamespace
    WHERE n.nspname = 'public'
      AND p.proname = 'claim_stage_for_execution'
    LIMIT 1;

    IF v_def IS NULL THEN
        RAISE EXCEPTION
            'CONTRACT_FAIL: claim_stage_for_execution missing';
    END IF;

    IF v_def NOT ILIKE '%FOR UPDATE%' THEN
        RAISE EXCEPTION
            'CONTRACT_FAIL: claim does not lock stage';
    END IF;

    IF v_def NOT ILIKE '%production_stage_dependency%' THEN
        RAISE EXCEPTION
            'CONTRACT_FAIL: claim does not inspect dependencies';
    END IF;

    IF v_def NOT ILIKE '%idempotency_key%' THEN
        RAISE EXCEPTION
            'CONTRACT_FAIL: claim does not handle idempotency key';
    END IF;

    RAISE NOTICE
        'PASS: Stage claim exposes required transactional guards';
END $$;

\echo
\echo ============================================================
\echo 04. STAGE COMPLETION CONTRACT
\echo ============================================================

DO $$
DECLARE
    v_def TEXT;
BEGIN
    SELECT pg_get_functiondef(p.oid)
    INTO v_def
    FROM pg_proc p
    JOIN pg_namespace n ON n.oid = p.pronamespace
    WHERE n.nspname = 'public'
      AND p.proname = 'complete_stage_atomically'
    LIMIT 1;

    IF v_def IS NULL THEN
        RAISE EXCEPTION
            'CONTRACT_FAIL: complete_stage_atomically missing';
    END IF;

    IF v_def NOT ILIKE '%FOR UPDATE%' THEN
        RAISE EXCEPTION
            'CONTRACT_FAIL: complete does not lock stage';
    END IF;

    IF v_def NOT ILIKE '%VALIDATED%' THEN
        RAISE EXCEPTION
            'CONTRACT_FAIL: complete does not require validated artifact';
    END IF;

    IF v_def NOT ILIKE '%SUCCEEDED%' THEN
        RAISE EXCEPTION
            'CONTRACT_FAIL: complete does not transition to SUCCEEDED';
    END IF;

    RAISE NOTICE 'PASS: Stage completion contract present';
END $$;

\echo
\echo ============================================================
\echo 05. STAGE FAILURE CONTRACT
\echo ============================================================

DO $$
DECLARE
    v_def TEXT;
BEGIN
    SELECT pg_get_functiondef(p.oid)
    INTO v_def
    FROM pg_proc p
    JOIN pg_namespace n ON n.oid = p.pronamespace
    WHERE n.nspname = 'public'
      AND p.proname = 'fail_stage_atomically'
    LIMIT 1;

    IF v_def IS NULL THEN
        RAISE EXCEPTION
            'CONTRACT_FAIL: fail_stage_atomically missing';
    END IF;

    IF v_def NOT ILIKE '%classify_error%' THEN
        RAISE EXCEPTION
            'CONTRACT_FAIL: fail stage does not classify errors';
    END IF;

    IF v_def NOT ILIKE '%retryable%' THEN
        RAISE EXCEPTION
            'CONTRACT_FAIL: fail stage does not persist retryability';
    END IF;

    IF v_def NOT ILIKE '%STAGE_ERROR%' THEN
        RAISE EXCEPTION
            'CONTRACT_FAIL: fail stage does not emit stage error event';
    END IF;

    RAISE NOTICE 'PASS: Stage failure/retry contract present';
END $$;

\echo
\echo ============================================================
\echo 06. RUN ESCALATION CONTRACT
\echo ============================================================

DO $$
DECLARE
    v_def TEXT;
BEGIN
    SELECT pg_get_functiondef(p.oid)
    INTO v_def
    FROM pg_proc p
    JOIN pg_namespace n ON n.oid = p.pronamespace
    WHERE n.nspname = 'public'
      AND p.proname = 'fail_run_atomically'
    LIMIT 1;

    IF v_def IS NULL THEN
        RAISE EXCEPTION
            'CONTRACT_FAIL: fail_run_atomically missing';
    END IF;

    IF v_def NOT ILIKE '%FOR UPDATE%' THEN
        RAISE EXCEPTION
            'CONTRACT_FAIL: fail run does not lock Run';
    END IF;

    IF v_def NOT ILIKE '%STAGE_STILL_RETRYABLE%' THEN
        RAISE EXCEPTION
            'CONTRACT_FAIL: retryable stage escalation guard missing';
    END IF;

    IF v_def NOT ILIKE '%RUN_ERROR%' THEN
        RAISE EXCEPTION
            'CONTRACT_FAIL: Run ERROR transition missing';
    END IF;

    IF v_def NOT ILIKE '%production_run_event%' THEN
        RAISE EXCEPTION
            'CONTRACT_FAIL: Run error event missing';
    END IF;

    RAISE NOTICE 'PASS: Run escalation contract present';
END $$;

\echo
\echo ============================================================
\echo 07. EXECUTION EVENT CONTRACT
\echo ============================================================

DO $$
DECLARE
    v_def TEXT;
BEGIN
    SELECT pg_get_functiondef(p.oid)
    INTO v_def
    FROM pg_proc p
    JOIN pg_namespace n ON n.oid = p.pronamespace
    WHERE n.nspname = 'public'
      AND p.proname = 'record_execution_event'
    LIMIT 1;

    IF v_def IS NULL THEN
        RAISE EXCEPTION
            'CONTRACT_FAIL: record_execution_event missing';
    END IF;

    IF v_def NOT ILIKE '%event_id%' THEN
        RAISE EXCEPTION
            'CONTRACT_FAIL: event_id handling missing';
    END IF;

    IF v_def NOT ILIKE '%IS NOT DISTINCT FROM%' THEN
        RAISE EXCEPTION
            'CONTRACT_FAIL: exact idempotence comparison missing';
    END IF;

    RAISE NOTICE
        'PASS: Execution event idempotence contract present';
END $$;

\echo
\echo ============================================================
\echo 08. ARTIFACT VALIDATION CONTRACT
\echo ============================================================

DO $$
DECLARE
    v_def TEXT;
BEGIN
    SELECT pg_get_functiondef(p.oid)
    INTO v_def
    FROM pg_proc p
    JOIN pg_namespace n ON n.oid = p.pronamespace
    WHERE n.nspname = 'public'
      AND p.proname = 'validate_stage_artifacts'
    LIMIT 1;

    IF v_def IS NULL THEN
        RAISE EXCEPTION
            'CONTRACT_FAIL: validate_stage_artifacts missing';
    END IF;

    IF v_def NOT ILIKE '%artifact_registry%' THEN
        RAISE EXCEPTION
            'CONTRACT_FAIL: artifact registry not checked';
    END IF;

    IF v_def NOT ILIKE '%VALIDATED%' THEN
        RAISE EXCEPTION
            'CONTRACT_FAIL: validated artifact state not checked';
    END IF;

    RAISE NOTICE
        'PASS: Artifact validation contract present';
END $$;

\echo
\echo ============================================================
\echo 09. EXECUTOR TYPES
\echo ============================================================

SELECT
    executor_type,
    COUNT(*) AS definitions
FROM public.stage_definition
GROUP BY executor_type
ORDER BY executor_type;

\echo
\echo ============================================================
\echo 10. ENABLED DEFINITIONS
\echo ============================================================

SELECT
    stage_name,
    version,
    executor_type,
    timeout_seconds,
    max_attempts,
    enabled
FROM public.stage_definition
WHERE enabled = TRUE
ORDER BY stage_name;

\echo
\echo ============================================================
\echo 11. ACTIVE CONTRACTS
\echo ============================================================

SELECT
    contract_name,
    version,
    producer,
    consumers,
    enabled
FROM public.contract_definition
WHERE enabled = TRUE
ORDER BY contract_name;

\echo
\echo ============================================================
\echo 12. ORCHESTRATOR GAP CHECK
\echo ============================================================

DO $$
DECLARE
    v_orchestrator_functions INTEGER;
    v_executor_functions INTEGER;
BEGIN
    SELECT COUNT(*)
    INTO v_orchestrator_functions
    FROM pg_proc p
    JOIN pg_namespace n ON n.oid = p.pronamespace
    WHERE n.nspname = 'public'
      AND (
          p.proname ILIKE '%orchestrat%'
          OR p.proname ILIKE '%dispatch%'
          OR p.proname ILIKE '%scheduler%'
          OR p.proname ILIKE '%run_next%'
      );

    SELECT COUNT(*)
    INTO v_executor_functions
    FROM pg_proc p
    JOIN pg_namespace n ON n.oid = p.pronamespace
    WHERE n.nspname = 'public'
      AND (
          p.proname ILIKE '%execute_stage%'
          OR p.proname ILIKE '%stage_executor%'
      );

    RAISE NOTICE
        'INFO: orchestrator functions found = %, executor functions found = %',
        v_orchestrator_functions,
        v_executor_functions;
END $$;

\echo
\echo ============================================================
\echo 13. CURRENT ERROR STATE
\echo ============================================================

SELECT
    (SELECT COUNT(*)
     FROM public.production_run
     WHERE status = 'ERROR') AS error_runs,

    (SELECT COUNT(*)
     FROM public.production_stage
     WHERE status = 'ERROR') AS error_stages;

\echo
\echo ============================================================
\echo 14. FINAL DATABASE COUNTS
\echo ============================================================

SELECT
    (SELECT COUNT(*) FROM public.production_run) AS runs,
    (SELECT COUNT(*) FROM public.production_stage) AS stages,
    (SELECT COUNT(*) FROM public.production_stage_dependency) AS dependencies,
    (SELECT COUNT(*) FROM public.production_run_event) AS run_events,
    (SELECT COUNT(*) FROM public.production_stage_event) AS stage_events,
    (SELECT COUNT(*) FROM public.production_execution_event) AS execution_events,
    (SELECT COUNT(*) FROM public.artifact_registry) AS artifacts;

ROLLBACK;

\echo
\echo ============================================================
\echo 11-F.2 CONTRACT TEST COMPLETE
\echo NO DATABASE MUTATION
\echo ============================================================
