\set ON_ERROR_STOP on
\pset pager off

\echo ============================================================
\echo 11-E.32-FIX-RETEST-V3
\echo STAGE ERROR -> RUN ERROR
\echo ============================================================

BEGIN;

DELETE FROM production_stage_event
WHERE run_id = 'RUN-11E32-FIX-RETEST-V3';

DELETE FROM production_run_event
WHERE run_id = 'RUN-11E32-FIX-RETEST-V3';

DELETE FROM production_stage
WHERE stage_id = 'STG-11E32-FIX-RETEST-V3';

DELETE FROM production_run
WHERE run_id = 'RUN-11E32-FIX-RETEST-V3';

INSERT INTO production_run (
    run_id,
    project_id,
    status,
    current_stage,
    attempt,
    input_json,
    output_json
)
VALUES (
    'RUN-11E32-FIX-RETEST-V3',
    'PROJECT-11E32-FIX-RETEST-V3',
    'CREATED',
    'RUN_MANAGER',
    1,
    '{}'::jsonb,
    '{}'::jsonb
);

INSERT INTO production_stage (
    stage_id,
    run_id,
    stage_name,
    stage_order,
    status,
    attempt,
    idempotency_key,
    retryable,
    input_artifact_ids,
    output_artifact_ids,
    input_json,
    output_json
)
VALUES (
    'STG-11E32-FIX-RETEST-V3',
    'RUN-11E32-FIX-RETEST-V3',
    'FAIL_RUN_ESCALATION',
    1,
    'PENDING',
    1,
    'RUN-11E32-FIX-RETEST-V3:FAIL_RUN_ESCALATION:1',
    FALSE,
    '[]'::jsonb,
    '[]'::jsonb,
    '{}'::jsonb,
    '{}'::jsonb
);

COMMIT;

\echo
\echo === 01. CLAIM ===

SELECT *
FROM public.claim_stage_for_execution(
    'STG-11E32-FIX-RETEST-V3'
);

\echo
\echo === 02. FAIL STAGE ===

SELECT *
FROM public.fail_stage_atomically(
    'STG-11E32-FIX-RETEST-V3',
    'NETWORK_ERROR',
    '11-E32 V3 forced stage failure',
    jsonb_build_object(
        'test', '11-E32-FIX-RETEST-V3'
    )
);

\echo
\echo === 03. STATE AFTER STAGE FAILURE ===

SELECT
    run_id,
    status,
    current_stage,
    error_code,
    error_message
FROM production_run
WHERE run_id = 'RUN-11E32-FIX-RETEST-V3';

SELECT
    stage_id,
    status,
    retryable,
    error_code,
    error_message
FROM production_stage
WHERE stage_id = 'STG-11E32-FIX-RETEST-V3';

\echo
\echo === 04. CONSISTENCY BEFORE ESCALATION ===

SELECT *
FROM public.validate_run_stage_consistency(
    'RUN-11E32-FIX-RETEST-V3'
);

\echo
\echo === 05. FAIL RUN ATOMICALLY ===

SELECT *
FROM public.fail_run_atomically(
    'RUN-11E32-FIX-RETEST-V3',
    'STG-11E32-FIX-RETEST-V3',
    'RUN_ERROR',
    jsonb_build_object(
        'test', '11-E32-FIX-RETEST-V3',
        'phase', 'ESCALATION'
    )
);

\echo
\echo === 06. FINAL RUN ===

SELECT
    run_id,
    status,
    current_stage,
    attempt,
    error_code,
    error_message
FROM production_run
WHERE run_id = 'RUN-11E32-FIX-RETEST-V3';

\echo
\echo === 07. FINAL STAGE ===

SELECT
    stage_id,
    status,
    attempt,
    retryable,
    error_code,
    error_message
FROM production_stage
WHERE stage_id = 'STG-11E32-FIX-RETEST-V3';

\echo
\echo === 08. EVENTS ===

SELECT
    id,
    event_type,
    from_status,
    to_status,
    stage,
    attempt
FROM production_run_event
WHERE run_id = 'RUN-11E32-FIX-RETEST-V3'
ORDER BY id;

SELECT
    id,
    event_type,
    from_status,
    to_status,
    stage_name,
    attempt
FROM production_stage_event
WHERE run_id = 'RUN-11E32-FIX-RETEST-V3'
ORDER BY id;

\echo
\echo === 09. FINAL CONSISTENCY ===

SELECT *
FROM public.validate_run_stage_consistency(
    'RUN-11E32-FIX-RETEST-V3'
);

\echo
\echo === 10. IDEMPOTENT SECOND ESCALATION ===

SELECT *
FROM public.fail_run_atomically(
    'RUN-11E32-FIX-RETEST-V3',
    'STG-11E32-FIX-RETEST-V3',
    'RUN_ERROR',
    jsonb_build_object(
        'test', '11-E32-FIX-RETEST-V3',
        'phase', 'SECOND_CALL'
    )
);

\echo
\echo === 11. EVENT COUNT ===

SELECT
    COUNT(*) FILTER (
        WHERE event_type = 'RUN_ERROR'
    ) AS run_error_events
FROM production_run_event
WHERE run_id = 'RUN-11E32-FIX-RETEST-V3';

\echo
\echo === 12. CLEANUP ===

BEGIN;

DELETE FROM production_stage_event
WHERE run_id = 'RUN-11E32-FIX-RETEST-V3';

DELETE FROM production_run_event
WHERE run_id = 'RUN-11E32-FIX-RETEST-V3';

DELETE FROM production_stage
WHERE stage_id = 'STG-11E32-FIX-RETEST-V3';

DELETE FROM production_run
WHERE run_id = 'RUN-11E32-FIX-RETEST-V3';

COMMIT;

SELECT COUNT(*) AS remaining_runs
FROM production_run
WHERE run_id = 'RUN-11E32-FIX-RETEST-V3';

SELECT COUNT(*) AS remaining_stages
FROM production_stage
WHERE stage_id = 'STG-11E32-FIX-RETEST-V3';

\echo
\echo ============================================================
\echo 11-E.32-FIX-RETEST-V3 END
\echo ============================================================
