\set ON_ERROR_STOP on
\pset pager off

BEGIN;

\echo ============================================================
\echo 11-E.30
\echo PERSISTENT FAIL_RUN_ATOMICALLY
\echo INTEGRATION TEST
\echo TRANSACTIONAL FIXTURE
\echo ============================================================

\echo
\echo === 01. BASELINE PRODUCTION ERROR STATE ===

SELECT
    (SELECT COUNT(*)
     FROM public.production_run
     WHERE status = 'ERROR') AS baseline_error_runs,

    (SELECT COUNT(*)
     FROM public.production_stage
     WHERE status = 'ERROR') AS baseline_error_stages;

\echo
\echo === 02. CREATE FIXTURE ===

INSERT INTO public.production_run (
    run_id,
    project_id,
    status,
    current_stage,
    attempt
)
VALUES (
    'RUN-11E30-FIXTURE',
    'PROJECT-11E30-FIXTURE',
    'CREATED',
    'RUN_MANAGER',
    1
);

INSERT INTO public.production_stage (
    stage_id,
    run_id,
    stage_name,
    stage_order,
    status,
    attempt,
    idempotency_key
)
VALUES (
    'STG-11E30-FIXTURE',
    'RUN-11E30-FIXTURE',
    'FAIL_RUN_INTEGRATION',
    1,
    'PENDING',
    1,
    'RUN-11E30-FIXTURE:FAIL_RUN_INTEGRATION:1'
);

\echo
\echo === 03. CLAIM ATTEMPT 1 ===

SELECT *
FROM public.claim_stage_for_execution(
    'STG-11E30-FIXTURE'
);

\echo
\echo === 04. FAIL ATTEMPT 1 ===

SELECT *
FROM public.fail_stage_atomically(
    'STG-11E30-FIXTURE',
    'NETWORK_ERROR',
    '11-E30 network failure attempt 1',
    '{"fixture":"11-E30","attempt":1}'::jsonb
);

\echo
\echo === 05. CLAIM ATTEMPT 2 ===

SELECT *
FROM public.claim_stage_for_execution(
    'STG-11E30-FIXTURE'
);

\echo
\echo === 06. FAIL ATTEMPT 2 ===

SELECT *
FROM public.fail_stage_atomically(
    'STG-11E30-FIXTURE',
    'NETWORK_ERROR',
    '11-E30 network failure attempt 2',
    '{"fixture":"11-E30","attempt":2}'::jsonb
);

\echo
\echo === 07. CLAIM ATTEMPT 3 ===

SELECT *
FROM public.claim_stage_for_execution(
    'STG-11E30-FIXTURE'
);

\echo
\echo === 08. FAIL ATTEMPT 3 TERMINAL ===

SELECT *
FROM public.fail_stage_atomically(
    'STG-11E30-FIXTURE',
    'NETWORK_ERROR',
    '11-E30 terminal network failure attempt 3',
    '{"fixture":"11-E30","attempt":3}'::jsonb
);

\echo
\echo === 09. VERIFY TERMINAL STAGE ===

SELECT
    stage_id,
    run_id,
    stage_name,
    status,
    attempt,
    retryable,
    error_code,
    error_message,
    idempotency_key
FROM public.production_stage
WHERE stage_id = 'STG-11E30-FIXTURE';

\echo
\echo === 10. CALL PERSISTENT FAIL_RUN_ATOMICALLY ===

SELECT *
FROM public.fail_run_atomically(
    'RUN-11E30-FIXTURE',
    'STG-11E30-FIXTURE',
    'RUN_ERROR',
    '{"fixture":"11-E30","reason":"terminal_stage_failure"}'::jsonb
);

\echo
\echo === 11. VERIFY RUN ===

SELECT
    run_id,
    status,
    current_stage,
    attempt,
    error_code,
    error_message
FROM public.production_run
WHERE run_id = 'RUN-11E30-FIXTURE';

\echo
\echo === 12. VERIFY STAGE ===

SELECT
    stage_id,
    run_id,
    stage_name,
    status,
    attempt,
    retryable,
    error_code,
    error_message
FROM public.production_stage
WHERE stage_id = 'STG-11E30-FIXTURE';

\echo
\echo === 13. VERIFY RUN EVENT ===

SELECT
    id,
    run_id,
    event_type,
    from_status,
    to_status,
    stage,
    attempt,
    event_data
FROM public.production_run_event
WHERE run_id = 'RUN-11E30-FIXTURE'
ORDER BY id;

\echo
\echo === 14. VERIFY RUN/STAGE CONSISTENCY ===

SELECT *
FROM public.validate_run_stage_consistency(
    'RUN-11E30-FIXTURE'
);

\echo
\echo === 15. IDEMPOTENCE TEST ===

SELECT *
FROM public.fail_run_atomically(
    'RUN-11E30-FIXTURE',
    'STG-11E30-FIXTURE',
    'RUN_ERROR',
    '{"fixture":"11-E30","second_call":true}'::jsonb
);

\echo
\echo === 16. EVENT COUNT AFTER SECOND CALL ===

SELECT
    COUNT(*) AS run_event_count
FROM public.production_run_event
WHERE run_id = 'RUN-11E30-FIXTURE';

\echo
\echo === 17. NEGATIVE - RETRYABLE STAGE ===

UPDATE public.production_run
SET
    status = 'CREATED',
    current_stage = 'RUN_MANAGER',
    error_code = NULL,
    error_message = NULL
WHERE run_id = 'RUN-11E30-FIXTURE';

UPDATE public.production_stage
SET
    status = 'ERROR',
    retryable = TRUE,
    error_code = 'NETWORK_ERROR',
    error_message = 'retryable failure'
WHERE stage_id = 'STG-11E30-FIXTURE';

SELECT *
FROM public.fail_run_atomically(
    'RUN-11E30-FIXTURE',
    'STG-11E30-FIXTURE'
);

\echo
\echo === 18. NEGATIVE - NON ERROR STAGE ===

UPDATE public.production_stage
SET
    status = 'RUNNING',
    retryable = FALSE,
    error_code = NULL,
    error_message = NULL
WHERE stage_id = 'STG-11E30-FIXTURE';

SELECT *
FROM public.fail_run_atomically(
    'RUN-11E30-FIXTURE',
    'STG-11E30-FIXTURE'
);

\echo
\echo === 19. VERIFY NO PRODUCTION RUN ERROR CREATED ===

SELECT
    run_id,
    status,
    error_code,
    error_message
FROM public.production_run
WHERE run_id <> 'RUN-11E30-FIXTURE'
  AND (
      status = 'ERROR'
      OR error_code IS NOT NULL
      OR error_message IS NOT NULL
  )
ORDER BY run_id;

\echo
\echo === 20. ROLLBACK ===

ROLLBACK;

\echo
\echo === 21. POST-ROLLBACK FIXTURE CHECK ===

SELECT COUNT(*) AS fixture_run_count
FROM public.production_run
WHERE run_id = 'RUN-11E30-FIXTURE';

SELECT COUNT(*) AS fixture_stage_count
FROM public.production_stage
WHERE stage_id = 'STG-11E30-FIXTURE';

SELECT COUNT(*) AS fixture_event_count
FROM public.production_run_event
WHERE run_id = 'RUN-11E30-FIXTURE';

\echo
\echo === 22. POST-ROLLBACK PRODUCTION ERROR STATE ===

SELECT
    (SELECT COUNT(*)
     FROM public.production_run
     WHERE status = 'ERROR') AS final_error_runs,

    (SELECT COUNT(*)
     FROM public.production_stage
     WHERE status = 'ERROR') AS final_error_stages;

\echo
\echo ============================================================
\echo 11-E.30 END
\echo TRANSACTION ROLLED BACK
\echo ============================================================
