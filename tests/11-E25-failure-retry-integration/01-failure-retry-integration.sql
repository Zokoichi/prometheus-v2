\set ON_ERROR_STOP on
\pset pager off

\echo ============================================================
\echo 11-E.25
\echo FAILURE -> RETRY INTEGRATION
\echo ============================================================

BEGIN;

\echo
\echo === 01. CREATE ISOLATED RUN ===

INSERT INTO public.production_run (
    run_id,
    project_id,
    status,
    current_stage,
    attempt,
    input_json,
    output_json
)
VALUES (
    'RUN-11E25-FIXTURE',
    'PROJECT-11E25-FIXTURE',
    'CREATED',
    'RUN_MANAGER',
    1,
    '{}'::jsonb,
    '{}'::jsonb
);

\echo
\echo === 02. CREATE PENDING STAGE ===

INSERT INTO public.production_stage (
    stage_id,
    run_id,
    stage_name,
    stage_order,
    status,
    attempt,
    idempotency_key,
    input_artifact_ids,
    output_artifact_ids,
    input_json,
    output_json,
    retryable
)
VALUES (
    'STG-11E25-FIXTURE',
    'RUN-11E25-FIXTURE',
    'FAIL_RETRY_TEST',
    1,
    'PENDING',
    1,
    'RUN-11E25-FIXTURE:FAIL_RETRY_TEST:1',
    '[]'::jsonb,
    '[]'::jsonb,
    '{}'::jsonb,
    '{}'::jsonb,
    false
);

\echo
\echo === 03. CLAIM ATTEMPT 1 ===

SELECT *
FROM public.claim_stage_for_execution(
    'STG-11E25-FIXTURE'
);

\echo
\echo === 04. VERIFY ATTEMPT 1 RUNNING ===

SELECT
    stage_id,
    status,
    attempt,
    idempotency_key,
    retryable,
    error_code
FROM public.production_stage
WHERE stage_id = 'STG-11E25-FIXTURE';

\echo
\echo === 05. FAIL ATTEMPT 1 ===

SELECT *
FROM public.fail_stage_atomically(
    'STG-11E25-FIXTURE',
    'NETWORK_ERROR',
    'Attempt 1 network failure',
    jsonb_build_object(
        'test_case', 'integration_attempt_1'
    )
);

\echo
\echo === 06. VERIFY ERROR ATTEMPT 1 ===

SELECT
    stage_id,
    status,
    attempt,
    idempotency_key,
    retryable,
    error_code,
    error_message
FROM public.production_stage
WHERE stage_id = 'STG-11E25-FIXTURE';

\echo
\echo === 07. CLAIM RETRY ATTEMPT 2 ===

SELECT *
FROM public.claim_stage_for_execution(
    'STG-11E25-FIXTURE'
);

\echo
\echo === 08. VERIFY ATTEMPT 2 RUNNING ===

SELECT
    stage_id,
    status,
    attempt,
    idempotency_key,
    retryable,
    error_code,
    error_message
FROM public.production_stage
WHERE stage_id = 'STG-11E25-FIXTURE';

\echo
\echo === 09. FAIL ATTEMPT 2 ===

SELECT *
FROM public.fail_stage_atomically(
    'STG-11E25-FIXTURE',
    'NETWORK_ERROR',
    'Attempt 2 network failure',
    jsonb_build_object(
        'test_case', 'integration_attempt_2'
    )
);

\echo
\echo === 10. VERIFY ERROR ATTEMPT 2 ===

SELECT
    stage_id,
    status,
    attempt,
    idempotency_key,
    retryable,
    error_code,
    error_message
FROM public.production_stage
WHERE stage_id = 'STG-11E25-FIXTURE';

\echo
\echo === 11. CLAIM RETRY ATTEMPT 3 ===

SELECT *
FROM public.claim_stage_for_execution(
    'STG-11E25-FIXTURE'
);

\echo
\echo === 12. VERIFY ATTEMPT 3 RUNNING ===

SELECT
    stage_id,
    status,
    attempt,
    idempotency_key,
    retryable,
    error_code,
    error_message
FROM public.production_stage
WHERE stage_id = 'STG-11E25-FIXTURE';

\echo
\echo === 13. FAIL ATTEMPT 3 - MAX ATTEMPTS ===

SELECT *
FROM public.fail_stage_atomically(
    'STG-11E25-FIXTURE',
    'NETWORK_ERROR',
    'Attempt 3 final network failure',
    jsonb_build_object(
        'test_case', 'integration_attempt_3'
    )
);

\echo
\echo === 14. VERIFY FINAL ERROR IS NOT RETRYABLE ===

SELECT
    stage_id,
    status,
    attempt,
    idempotency_key,
    retryable,
    error_code,
    error_message
FROM public.production_stage
WHERE stage_id = 'STG-11E25-FIXTURE';

\echo
\echo === 15. ATTEMPT ILLEGAL RETRY AFTER MAX ATTEMPT ===

SELECT *
FROM public.claim_stage_for_execution(
    'STG-11E25-FIXTURE'
);

\echo
\echo === 16. VERIFY STAGE REMAINS ERROR ===

SELECT
    stage_id,
    status,
    attempt,
    idempotency_key,
    retryable,
    error_code,
    error_message
FROM public.production_stage
WHERE stage_id = 'STG-11E25-FIXTURE';

\echo
\echo === 17. VERIFY STAGE ERROR EVENTS ===

SELECT
    id,
    event_type,
    from_status,
    to_status,
    attempt,
    event_data
FROM public.production_stage_event
WHERE stage_id = 'STG-11E25-FIXTURE'
ORDER BY id;

\echo
\echo === 18. VERIFY RETRY EVENT HISTORY ===

SELECT
    id,
    event_type,
    from_status,
    to_status,
    attempt,
    event_data
FROM public.production_stage_event
WHERE stage_id = 'STG-11E25-FIXTURE'
  AND event_type IN ('STAGE_ERROR', 'STATE_CHANGE', 'RETRY')
ORDER BY id;

\echo
\echo === 19. VERIFY IDEMPOTENCY KEY EVOLUTION ===

SELECT
    COUNT(*) FILTER (
        WHERE event_type = 'STAGE_ERROR'
          AND attempt = 1
    ) AS error_attempt_1,
    COUNT(*) FILTER (
        WHERE event_type = 'STAGE_ERROR'
          AND attempt = 2
    ) AS error_attempt_2,
    COUNT(*) FILTER (
        WHERE event_type = 'STAGE_ERROR'
          AND attempt = 3
    ) AS error_attempt_3
FROM public.production_stage_event
WHERE stage_id = 'STG-11E25-FIXTURE';

SELECT
    stage_id,
    idempotency_key
FROM public.production_stage
WHERE stage_id = 'STG-11E25-FIXTURE';

\echo
\echo === 20. VERIFY CURRENT ERROR COUNTS ===

SELECT
    COUNT(*) FILTER (WHERE status = 'ERROR') AS current_error_stages,
    COUNT(*) FILTER (
        WHERE status = 'ERROR'
          AND retryable = true
    ) AS current_retryable_error_stages,
    COUNT(*) FILTER (
        WHERE status = 'ERROR'
          AND retryable = false
    ) AS current_terminal_error_stages
FROM public.production_stage
WHERE stage_id = 'STG-11E25-FIXTURE';

\echo
\echo === 21. VERIFY PRODUCTION RUN WAS NOT MUTATED ===

SELECT
    run_id,
    status,
    current_stage,
    attempt,
    error_code,
    error_message
FROM public.production_run
WHERE run_id = 'RUN-11E25-FIXTURE';

\echo
\echo === 22. VERIFY PRODUCTION RUN ERROR ESCALATION DID NOT OCCUR ===

SELECT
    COUNT(*) AS run_error_event_count
FROM public.production_run_event
WHERE run_id = 'RUN-11E25-FIXTURE'
  AND (
        event_type = 'STAGE_ERROR'
        OR event_type = 'ERROR'
        OR to_status = 'ERROR'
      );

\echo
\echo === 23. VERIFY NO OTHER CURRENT STAGES WERE TOUCHED ===

SELECT
    COUNT(*) AS non_fixture_error_stages
FROM public.production_stage
WHERE stage_id <> 'STG-11E25-FIXTURE'
  AND status = 'ERROR';

\echo
\echo === 24. ROLLBACK ===

ROLLBACK;

\echo
\echo === 25. POST-ROLLBACK FIXTURE CHECK ===

SELECT
    COUNT(*) AS fixture_stage_count
FROM public.production_stage
WHERE stage_id = 'STG-11E25-FIXTURE';

SELECT
    COUNT(*) AS fixture_run_count
FROM public.production_run
WHERE run_id = 'RUN-11E25-FIXTURE';

SELECT
    COUNT(*) AS fixture_event_count
FROM public.production_stage_event
WHERE stage_id = 'STG-11E25-FIXTURE';

\echo
\echo ============================================================
\echo 11-E.25 END
\echo ============================================================
