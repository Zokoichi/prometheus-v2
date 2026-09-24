\set ON_ERROR_STOP on
\timing off

\echo ============================================================
\echo PROMETHEUS V2 — 11-F.1 ORCHESTRATION FORENSICS
\echo READ-ONLY
\echo ============================================================

\echo
\echo ============================================================
\echo 01. DATABASE / SERVER
\echo ============================================================

SELECT
    current_database() AS database_name,
    current_user AS current_user,
    version() AS postgres_version;

\echo
\echo ============================================================
\echo 02. PRODUCTION TABLE INVENTORY
\echo ============================================================

SELECT
    table_schema,
    table_name
FROM information_schema.tables
WHERE table_schema = 'public'
  AND (
      table_name LIKE 'production_%'
      OR table_name IN (
          'artifact_registry',
          'stage_definition',
          'contract_definition'
      )
  )
ORDER BY table_name;

\echo
\echo ============================================================
\echo 03. RUN TABLE STRUCTURE
\echo ============================================================

SELECT
    ordinal_position,
    column_name,
    data_type,
    is_nullable,
    column_default
FROM information_schema.columns
WHERE table_schema = 'public'
  AND table_name = 'production_run'
ORDER BY ordinal_position;

\echo
\echo ============================================================
\echo 04. STAGE TABLE STRUCTURE
\echo ============================================================

SELECT
    ordinal_position,
    column_name,
    data_type,
    is_nullable,
    column_default
FROM information_schema.columns
WHERE table_schema = 'public'
  AND table_name = 'production_stage'
ORDER BY ordinal_position;

\echo
\echo ============================================================
\echo 05. RUN EVENT STRUCTURE
\echo ============================================================

SELECT
    ordinal_position,
    column_name,
    data_type,
    is_nullable,
    column_default
FROM information_schema.columns
WHERE table_schema = 'public'
  AND table_name = 'production_run_event'
ORDER BY ordinal_position;

\echo
\echo ============================================================
\echo 06. STAGE EVENT STRUCTURE
\echo ============================================================

SELECT
    ordinal_position,
    column_name,
    data_type,
    is_nullable,
    column_default
FROM information_schema.columns
WHERE table_schema = 'public'
  AND table_name = 'production_stage_event'
ORDER BY ordinal_position;

\echo
\echo ============================================================
\echo 07. EXECUTION EVENT STRUCTURE
\echo ============================================================

SELECT
    ordinal_position,
    column_name,
    data_type,
    is_nullable,
    column_default
FROM information_schema.columns
WHERE table_schema = 'public'
  AND table_name = 'production_execution_event'
ORDER BY ordinal_position;

\echo
\echo ============================================================
\echo 08. STAGE DEPENDENCY STRUCTURE
\echo ============================================================

SELECT
    ordinal_position,
    column_name,
    data_type,
    is_nullable,
    column_default
FROM information_schema.columns
WHERE table_schema = 'public'
  AND table_name = 'production_stage_dependency'
ORDER BY ordinal_position;

\echo
\echo ============================================================
\echo 09. STAGE DEFINITION STRUCTURE
\echo ============================================================

SELECT
    ordinal_position,
    column_name,
    data_type,
    is_nullable,
    column_default
FROM information_schema.columns
WHERE table_schema = 'public'
  AND table_name = 'stage_definition'
ORDER BY ordinal_position;

\echo
\echo ============================================================
\echo 10. CURRENT STAGE DEFINITIONS
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
\echo 11. ENABLED STAGE DEFINITIONS
\echo ============================================================

SELECT
    stage_name,
    version,
    executor_type,
    timeout_seconds,
    max_attempts,
    retry_policy,
    idempotency_policy,
    enabled
FROM public.stage_definition
WHERE enabled = TRUE
ORDER BY stage_name;

\echo
\echo ============================================================
\echo 12. RUN STATUS DISTRIBUTION
\echo ============================================================

SELECT
    status,
    COUNT(*) AS count
FROM public.production_run
GROUP BY status
ORDER BY status;

\echo
\echo ============================================================
\echo 13. STAGE STATUS DISTRIBUTION
\echo ============================================================

SELECT
    status,
    COUNT(*) AS count
FROM public.production_stage
GROUP BY status
ORDER BY status;

\echo
\echo ============================================================
\echo 14. RUN → STAGE RELATIONSHIPS
\echo ============================================================

SELECT
    pr.run_id,
    pr.status AS run_status,
    pr.current_stage,
    ps.stage_id,
    ps.stage_name,
    ps.stage_order,
    ps.status AS stage_status,
    ps.attempt,
    ps.retryable,
    ps.idempotency_key
FROM public.production_run pr
LEFT JOIN public.production_stage ps
    ON ps.run_id = pr.run_id
ORDER BY pr.run_id, ps.stage_order, ps.stage_id;

\echo
\echo ============================================================
\echo 15. STAGE DEPENDENCIES
\echo ============================================================

SELECT
    d.stage_id,
    s.stage_name,
    s.stage_order,
    d.depends_on_stage_id,
    ds.stage_name AS depends_on_stage_name,
    d.dependency_type
FROM public.production_stage_dependency d
JOIN public.production_stage s
    ON s.stage_id = d.stage_id
LEFT JOIN public.production_stage ds
    ON ds.stage_id = d.depends_on_stage_id
ORDER BY s.run_id, s.stage_order, s.stage_id;

\echo
\echo ============================================================
\echo 16. RUN STATUS TRANSITION FUNCTION
\echo ============================================================

SELECT
    n.nspname AS schema_name,
    p.proname AS function_name,
    pg_get_function_identity_arguments(p.oid) AS arguments
FROM pg_proc p
JOIN pg_namespace n
    ON n.oid = p.pronamespace
WHERE n.nspname = 'public'
  AND p.proname = 'request_run_transition';

\echo
\echo ============================================================
\echo 17. ORCHESTRATION-RELATED FUNCTIONS
\echo ============================================================

SELECT
    n.nspname AS schema_name,
    p.proname AS function_name,
    pg_get_function_identity_arguments(p.oid) AS arguments
FROM pg_proc p
JOIN pg_namespace n
    ON n.oid = p.pronamespace
WHERE n.nspname = 'public'
  AND (
      p.proname ILIKE '%orchestrat%'
      OR p.proname ILIKE '%stage%'
      OR p.proname ILIKE '%run%'
      OR p.proname ILIKE '%execution%'
      OR p.proname ILIKE '%claim%'
      OR p.proname ILIKE '%complete%'
      OR p.proname ILIKE '%fail%'
  )
ORDER BY p.proname, arguments;

\echo
\echo ============================================================
\echo 18. FUNCTION SOURCE — CLAIM
\echo ============================================================

SELECT
    pg_get_functiondef(p.oid)
FROM pg_proc p
JOIN pg_namespace n
    ON n.oid = p.pronamespace
WHERE n.nspname = 'public'
  AND p.proname = 'claim_stage_for_execution';

\echo
\echo ============================================================
\echo 19. FUNCTION SOURCE — COMPLETE
\echo ============================================================

SELECT
    pg_get_functiondef(p.oid)
FROM pg_proc p
JOIN pg_namespace n
    ON n.oid = p.pronamespace
WHERE n.nspname = 'public'
  AND p.proname = 'complete_stage_atomically';

\echo
\echo ============================================================
\echo 20. FUNCTION SOURCE — FAIL STAGE
\echo ============================================================

SELECT
    pg_get_functiondef(p.oid)
FROM pg_proc p
JOIN pg_namespace n
    ON n.oid = p.pronamespace
WHERE n.nspname = 'public'
  AND p.proname = 'fail_stage_atomically';

\echo
\echo ============================================================
\echo 21. FUNCTION SOURCE — FAIL RUN
\echo ============================================================

SELECT
    pg_get_functiondef(p.oid)
FROM pg_proc p
JOIN pg_namespace n
    ON n.oid = p.pronamespace
WHERE n.nspname = 'public'
  AND p.proname = 'fail_run_atomically';

\echo
\echo ============================================================
\echo 22. FUNCTION SOURCE — EXECUTION EVENT
\echo ============================================================

SELECT
    pg_get_functiondef(p.oid)
FROM pg_proc p
JOIN pg_namespace n
    ON n.oid = p.pronamespace
WHERE n.nspname = 'public'
  AND p.proname = 'record_execution_event';

\echo
\echo ============================================================
\echo 23. FUNCTION SOURCE — RUN CONSISTENCY
\echo ============================================================

SELECT
    pg_get_functiondef(p.oid)
FROM pg_proc p
JOIN pg_namespace n
    ON n.oid = p.pronamespace
WHERE n.nspname = 'public'
  AND p.proname = 'validate_run_stage_consistency';

\echo
\echo ============================================================
\echo 24. FOREIGN KEYS
\echo ============================================================

SELECT
    tc.table_name,
    kcu.column_name,
    ccu.table_name AS foreign_table_name,
    ccu.column_name AS foreign_column_name,
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
  AND (
      tc.table_name LIKE 'production_%'
      OR tc.table_name IN (
          'artifact_registry',
          'stage_definition',
          'contract_definition'
      )
  )
ORDER BY tc.table_name, tc.constraint_name;

\echo
\echo ============================================================
\echo 25. UNIQUE / PRIMARY CONSTRAINTS
\echo ============================================================

SELECT
    tc.table_name,
    tc.constraint_name,
    tc.constraint_type
FROM information_schema.table_constraints tc
WHERE tc.table_schema = 'public'
  AND tc.constraint_type IN ('PRIMARY KEY','UNIQUE')
  AND (
      tc.table_name LIKE 'production_%'
      OR tc.table_name IN (
          'artifact_registry',
          'stage_definition',
          'contract_definition'
      )
  )
ORDER BY tc.table_name, tc.constraint_type, tc.constraint_name;

\echo
\echo ============================================================
\echo 26. CHECK CONSTRAINTS
\echo ============================================================

SELECT
    tc.table_name,
    tc.constraint_name,
    cc.check_clause
FROM information_schema.table_constraints tc
JOIN information_schema.check_constraints cc
    ON cc.constraint_name = tc.constraint_name
WHERE tc.table_schema = 'public'
  AND tc.constraint_type = 'CHECK'
  AND (
      tc.table_name LIKE 'production_%'
      OR tc.table_name IN (
          'artifact_registry',
          'stage_definition',
          'contract_definition'
      )
  )
ORDER BY tc.table_name, tc.constraint_name;

\echo
\echo ============================================================
\echo 27. TRIGGERS
\echo ============================================================

SELECT
    event_object_table AS table_name,
    trigger_name,
    event_manipulation,
    action_timing,
    action_statement
FROM information_schema.triggers
WHERE event_object_schema = 'public'
  AND (
      event_object_table LIKE 'production_%'
      OR event_object_table IN (
          'artifact_registry',
          'stage_definition',
          'contract_definition'
      )
  )
ORDER BY event_object_table, trigger_name;

\echo
\echo ============================================================
\echo 28. INDEXES
\echo ============================================================

SELECT
    schemaname,
    tablename,
    indexname,
    indexdef
FROM pg_indexes
WHERE schemaname = 'public'
  AND (
      tablename LIKE 'production_%'
      OR tablename IN (
          'artifact_registry',
          'stage_definition',
          'contract_definition'
      )
  )
ORDER BY tablename, indexname;

\echo
\echo ============================================================
\echo 29. EXECUTION EVENT COUNTS
\echo ============================================================

SELECT
    COUNT(*) AS production_execution_events
FROM public.production_execution_event;

SELECT
    COUNT(*) AS production_run_events
FROM public.production_run_event;

SELECT
    COUNT(*) AS production_stage_events
FROM public.production_stage_event;

\echo
\echo ============================================================
\echo 30. ARTIFACT REGISTRY DISTRIBUTION
\echo ============================================================

SELECT
    stage,
    artifact_type,
    status,
    COUNT(*) AS count
FROM public.artifact_registry
GROUP BY stage, artifact_type, status
ORDER BY stage, artifact_type, status;

\echo
\echo ============================================================
\echo 31. CONTRACT DEFINITIONS
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
\echo 32. ACTIVE PRODUCTION ERRORS
\echo ============================================================

SELECT
    'RUN' AS object_type,
    run_id AS object_id,
    status,
    error_code,
    error_message
FROM public.production_run
WHERE status = 'ERROR'

UNION ALL

SELECT
    'STAGE',
    stage_id,
    status,
    error_code,
    error_message
FROM public.production_stage
WHERE status = 'ERROR'

ORDER BY object_type, object_id;

\echo
\echo ============================================================
\echo 33. ORCHESTRATOR SOURCE SEARCH — DATABASE FUNCTIONS
\echo ============================================================

SELECT
    n.nspname AS schema_name,
    p.proname AS function_name,
    pg_get_function_identity_arguments(p.oid) AS arguments
FROM pg_proc p
JOIN pg_namespace n
    ON n.oid = p.pronamespace
WHERE n.nspname = 'public'
  AND pg_get_functiondef(p.oid) ILIKE ANY (
      ARRAY[
          '%claim_stage_for_execution%',
          '%complete_stage_atomically%',
          '%fail_stage_atomically%',
          '%fail_run_atomically%',
          '%record_execution_event%'
      ]
  )
ORDER BY p.proname;

\echo
\echo ============================================================
\echo 34. FINAL COUNTS
\echo ============================================================

SELECT
    (SELECT COUNT(*) FROM public.production_run) AS runs,
    (SELECT COUNT(*) FROM public.production_stage) AS stages,
    (SELECT COUNT(*) FROM public.production_stage_dependency) AS dependencies,
    (SELECT COUNT(*) FROM public.production_run_event) AS run_events,
    (SELECT COUNT(*) FROM public.production_stage_event) AS stage_events,
    (SELECT COUNT(*) FROM public.production_execution_event) AS execution_events,
    (SELECT COUNT(*) FROM public.artifact_registry) AS artifacts,
    (SELECT COUNT(*) FROM public.stage_definition) AS stage_definitions,
    (SELECT COUNT(*) FROM public.contract_definition) AS contracts;

\echo
\echo ============================================================
\echo 11-F.1 FORENSICS COMPLETE
\echo READ-ONLY — NO MUTATION
\echo ============================================================
