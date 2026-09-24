\set ON_ERROR_STOP on
\pset pager off

BEGIN;

\echo ============================================================
\echo 11-E.32-INTEGRATION
\echo RETRY -> TERMINAL -> RUN ERROR
\echo ============================================================

\echo
\echo === 01. CLEAN PRECHECK ===

DO $$
BEGIN
    IF EXISTS (
        SELECT 1
        FROM production_run
        WHERE run_id = 'RUN-11E32-INTEGRATION'
    ) THEN
        RAISE EXCEPTION 'Fixture Run already exists';
    END IF;

    IF EXISTS (
        SELECT 1
        FROM production_stage
        WHERE stage_id = 'STG-11E32-INTEGRATION'
    ) THEN
        RAISE EXCEPTION 'Fixture Stage already exists';
    END IF;
END
$$;

\echo
\echo === 02. FIXTURE SETUP ===

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
    'RUN-11E32-INTEGRATION',
    'PROJECT-11E32-INTEGRATION',
    'CREATED',
    'TEST_RETRY',
    1,
    '{}'::jsonb,
    '{}'::jsonb
);

INSERT INTO public.production_stage (
    stage_id,
    run_id,
    stage_name,
    stage_order,
    status,
    attempt,
    retryable,
    idempotency_key,
    input_artifact_ids,
    output_artifact_ids,
    input_json,
    output_json
)
VALUES (
    'STG-11E32-INTEGRATION',
    'RUN-11E32-INTEGRATION',
    'TEST_RETRY',
    1,
    'PENDING',
    1,
    FALSE,
    'RUN-11E32-INTEGRATION:TEST_RETRY:1',
    '[]'::jsonb,
    '[]'::jsonb,
    '{}'::jsonb,
    '{}'::jsonb
);

\echo PASS: fixture created

\echo
\echo === 03. CLAIM ATTEMPT 1 ===

SELECT *
FROM claim_stage_for_execution(
    'STG-11E32-INTEGRATION'
);

DO $$
DECLARE
    v_status VARCHAR;
    v_attempt INTEGER;
BEGIN
    SELECT status, attempt
    INTO v_status, v_attempt
    FROM production_stage
    WHERE stage_id = 'STG-11E32-INTEGRATION';

    IF v_status <> 'RUNNING'
       OR v_attempt <> 1 THEN
        RAISE EXCEPTION
            'TEST FAILED: attempt 1 claim. status=% attempt=%',
            v_status, v_attempt;
    END IF;
END
$$;

\echo PASS: attempt 1 RUNNING

\echo
\echo === 04. FAIL ATTEMPT 1 — NETWORK_ERROR ===

SELECT *
FROM fail_stage_atomically(
    'STG-11E32-INTEGRATION',
    'NETWORK_ERROR',
    'integration attempt 1',
    '{"test":"11-E.32-INTEGRATION","attempt":1}'::jsonb
);

DO $$
DECLARE
    v_status VARCHAR;
    v_attempt INTEGER;
    v_retryable BOOLEAN;
    v_error_code VARCHAR;
BEGIN
    SELECT status, attempt, retryable, error_code
    INTO v_status, v_attempt, v_retryable, v_error_code
    FROM production_stage
    WHERE stage_id = 'STG-11E32-INTEGRATION';

    IF v_status <> 'ERROR'
       OR v_attempt <> 1
       OR v_retryable IS DISTINCT FROM TRUE
       OR v_error_code <> 'NETWORK_ERROR' THEN
        RAISE EXCEPTION
            'TEST FAILED: retryable failure. status=% attempt=% retryable=% code=%',
            v_status, v_attempt, v_retryable, v_error_code;
    END IF;
END
$$;

\echo PASS: attempt 1 ERROR retryable

\echo
\echo === 05. CONSISTENCY AFTER RETRYABLE FAILURE ===

SELECT *
FROM validate_run_stage_consistency(
    'RUN-11E32-INTEGRATION'
);

DO $$
DECLARE
    v_allowed BOOLEAN;
BEGIN
    SELECT allowed
    INTO v_allowed
    FROM validate_run_stage_consistency(
        'RUN-11E32-INTEGRATION'
    );

    IF v_allowed IS DISTINCT FROM TRUE THEN
        RAISE EXCEPTION
            'TEST FAILED: retryable Stage ERROR must keep Run coherent';
    END IF;
END
$$;

\echo PASS: Run coherent during retryable ERROR

\echo
\echo === 06. RUN MUST NOT ESCALATE WHILE RETRYABLE ===

SELECT *
FROM fail_run_atomically(
    'RUN-11E32-INTEGRATION',
    'STG-11E32-INTEGRATION',
    'RUN_ERROR',
    '{"test":"11-E.32-INTEGRATION","phase":"retryable"}'::jsonb
);

DO $$
DECLARE
    v_status VARCHAR;
BEGIN
    SELECT status
    INTO v_status
    FROM production_run
    WHERE run_id = 'RUN-11E32-INTEGRATION';

    IF v_status <> 'CREATED' THEN
        RAISE EXCEPTION
            'TEST FAILED: Run escalated while Stage retryable. status=%',
            v_status;
    END IF;
END
$$;

\echo PASS: Run remains CREATED while retryable

\echo
\echo === 07. CLAIM ATTEMPT 2 ===

SELECT *
FROM claim_stage_for_execution(
    'STG-11E32-INTEGRATION'
);

DO $$
DECLARE
    v_status VARCHAR;
    v_attempt INTEGER;
    v_retryable BOOLEAN;
BEGIN
    SELECT status, attempt, retryable
    INTO v_status, v_attempt, v_retryable
    FROM production_stage
    WHERE stage_id = 'STG-11E32-INTEGRATION';

    IF v_status <> 'RUNNING'
       OR v_attempt <> 2
       OR v_retryable IS DISTINCT FROM FALSE THEN
        RAISE EXCEPTION
            'TEST FAILED: attempt 2 claim. status=% attempt=% retryable=%',
            v_status, v_attempt, v_retryable;
    END IF;
END
$$;

\echo PASS: attempt 2 RUNNING

\echo
\echo === 08. FAIL ATTEMPT 2 — NETWORK_ERROR ===

SELECT *
FROM fail_stage_atomically(
    'STG-11E32-INTEGRATION',
    'NETWORK_ERROR',
    'integration attempt 2',
    '{"test":"11-E.32-INTEGRATION","attempt":2}'::jsonb
);

DO $$
DECLARE
    v_status VARCHAR;
    v_attempt INTEGER;
    v_retryable BOOLEAN;
BEGIN
    SELECT status, attempt, retryable
    INTO v_status, v_attempt, v_retryable
    FROM production_stage
    WHERE stage_id = 'STG-11E32-INTEGRATION';

    IF v_status <> 'ERROR'
       OR v_attempt <> 2
       OR v_retryable IS DISTINCT FROM TRUE THEN
        RAISE EXCEPTION
            'TEST FAILED: attempt 2 retryable failure. status=% attempt=% retryable=%',
            v_status, v_attempt, v_retryable;
    END IF;
END
$$;

\echo PASS: attempt 2 ERROR retryable

\echo
\echo === 09. CLAIM ATTEMPT 3 ===

SELECT *
FROM claim_stage_for_execution(
    'STG-11E32-INTEGRATION'
);

DO $$
DECLARE
    v_status VARCHAR;
    v_attempt INTEGER;
BEGIN
    SELECT status, attempt
    INTO v_status, v_attempt
    FROM production_stage
    WHERE stage_id = 'STG-11E32-INTEGRATION';

    IF v_status <> 'RUNNING'
       OR v_attempt <> 3 THEN
        RAISE EXCEPTION
            'TEST FAILED: attempt 3 claim. status=% attempt=%',
            v_status, v_attempt;
    END IF;
END
$$;

\echo PASS: attempt 3 RUNNING

\echo
\echo === 10. FAIL ATTEMPT 3 — NETWORK_ERROR TERMINAL ===

SELECT *
FROM fail_stage_atomically(
    'STG-11E32-INTEGRATION',
    'NETWORK_ERROR',
    'integration attempt 3 terminal',
    '{"test":"11-E.32-INTEGRATION","attempt":3}'::jsonb
);

DO $$
DECLARE
    v_status VARCHAR;
    v_attempt INTEGER;
    v_retryable BOOLEAN;
    v_error_code VARCHAR;
BEGIN
    SELECT status, attempt, retryable, error_code
    INTO v_status, v_attempt, v_retryable, v_error_code
    FROM production_stage
    WHERE stage_id = 'STG-11E32-INTEGRATION';

    IF v_status <> 'ERROR'
       OR v_attempt <> 3
       OR v_retryable IS DISTINCT FROM FALSE
       OR v_error_code <> 'NETWORK_ERROR' THEN
        RAISE EXCEPTION
            'TEST FAILED: terminal attempt 3. status=% attempt=% retryable=% code=%',
            v_status, v_attempt, v_retryable, v_error_code;
    END IF;
END
$$;

\echo PASS: attempt 3 terminal ERROR

\echo
\echo === 11. FINAL CLAIM MUST BE REFUSED ===

SELECT *
FROM claim_stage_for_execution(
    'STG-11E32-INTEGRATION'
);

DO $$
DECLARE
    v_status VARCHAR;
    v_attempt INTEGER;
    v_retryable BOOLEAN;
BEGIN
    SELECT status, attempt, retryable
    INTO v_status, v_attempt, v_retryable
    FROM production_stage
    WHERE stage_id = 'STG-11E32-INTEGRATION';

    IF v_status <> 'ERROR'
       OR v_attempt <> 3
       OR v_retryable IS DISTINCT FROM FALSE THEN
        RAISE EXCEPTION
            'TEST FAILED: terminal stage changed unexpectedly';
    END IF;
END
$$;

\echo PASS: terminal Stage cannot be reclaimed

\echo
\echo === 12. RUN STILL CREATED BEFORE ESCALATION ===

SELECT
    run_id,
    status,
    error_code,
    error_message
FROM production_run
WHERE run_id = 'RUN-11E32-INTEGRATION';

DO $$
DECLARE
    v_status VARCHAR;
BEGIN
    SELECT status
    INTO v_status
    FROM production_run
    WHERE run_id = 'RUN-11E32-INTEGRATION';

    IF v_status <> 'CREATED' THEN
        RAISE EXCEPTION
            'TEST FAILED: Run changed before explicit escalation. status=%',
            v_status;
    END IF;
END
$$;

\echo PASS: Run remains CREATED until escalation

\echo
\echo === 13. ESCALATE TERMINAL STAGE TO RUN ERROR ===

SELECT *
FROM fail_run_atomically(
    'RUN-11E32-INTEGRATION',
    'STG-11E32-INTEGRATION',
    'RUN_ERROR',
    '{"test":"11-E.32-INTEGRATION","phase":"terminal"}'::jsonb
);

DO $$
DECLARE
    v_status VARCHAR;
    v_error_code VARCHAR;
    v_error_message TEXT;
BEGIN
    SELECT status, error_code, error_message
    INTO v_status, v_error_code, v_error_message
    FROM production_run
    WHERE run_id = 'RUN-11E32-INTEGRATION';

    IF v_status <> 'ERROR'
       OR v_error_code <> 'NETWORK_ERROR'
       OR v_error_message <> 'integration attempt 3 terminal' THEN
        RAISE EXCEPTION
            'TEST FAILED: Run escalation. status=% code=% message=%',
            v_status, v_error_code, v_error_message;
    END IF;
END
$$;

\echo PASS: Run ERROR with Stage error propagated

\echo
\echo === 14. FINAL CONSISTENCY ===

SELECT *
FROM validate_run_stage_consistency(
    'RUN-11E32-INTEGRATION'
);

DO $$
DECLARE
    v_allowed BOOLEAN;
BEGIN
    SELECT allowed
    INTO v_allowed
    FROM validate_run_stage_consistency(
        'RUN-11E32-INTEGRATION'
    );

    IF v_allowed IS DISTINCT FROM TRUE THEN
        RAISE EXCEPTION
            'TEST FAILED: final Run/Stage consistency';
    END IF;
END
$$;

\echo PASS: final Run/Stage consistency

\echo
\echo === 15. ESCALATION IDEMPOTENCE ===

SELECT *
FROM fail_run_atomically(
    'RUN-11E32-INTEGRATION',
    'STG-11E32-INTEGRATION',
    'RUN_ERROR',
    '{"test":"11-E.32-INTEGRATION","phase":"second-call"}'::jsonb
);

DO $$
DECLARE
    v_status VARCHAR;
    v_run_error_events INTEGER;
BEGIN
    SELECT status
    INTO v_status
    FROM production_run
    WHERE run_id = 'RUN-11E32-INTEGRATION';

    SELECT COUNT(*)
    INTO v_run_error_events
    FROM production_run_event
    WHERE run_id = 'RUN-11E32-INTEGRATION'
      AND event_type = 'RUN_ERROR';

    IF v_status <> 'ERROR' THEN
        RAISE EXCEPTION
            'TEST FAILED: idempotent second escalation changed Run';
    END IF;

    IF v_run_error_events <> 1 THEN
        RAISE EXCEPTION
            'TEST FAILED: expected exactly one RUN_ERROR event, got %',
            v_run_error_events;
    END IF;
END
$$;

\echo PASS: escalation idempotent

\echo
\echo === 16. EVENT AUDIT ===

SELECT
    event_type,
    from_status,
    to_status,
    attempt,
    event_data
FROM production_stage_event
WHERE run_id = 'RUN-11E32-INTEGRATION'
ORDER BY id;

SELECT
    event_type,
    from_status,
    to_status,
    attempt,
    event_data
FROM production_run_event
WHERE run_id = 'RUN-11E32-INTEGRATION'
ORDER BY id;

\echo
\echo === 17. FINAL STATE AUDIT ===

SELECT
    pr.run_id,
    pr.status AS run_status,
    pr.error_code AS run_error_code,
    ps.stage_id,
    ps.status AS stage_status,
    ps.attempt AS stage_attempt,
    ps.retryable AS stage_retryable,
    ps.error_code AS stage_error_code
FROM production_run pr
JOIN production_stage ps
  ON ps.run_id = pr.run_id
WHERE pr.run_id = 'RUN-11E32-INTEGRATION';

\echo
\echo === 18. CLEANUP ===

DELETE FROM public.production_stage_event
WHERE run_id = 'RUN-11E32-INTEGRATION';

DELETE FROM public.production_run_event
WHERE run_id = 'RUN-11E32-INTEGRATION';

DELETE FROM public.production_stage
WHERE run_id = 'RUN-11E32-INTEGRATION';

DELETE FROM public.production_run
WHERE run_id = 'RUN-11E32-INTEGRATION';

\echo
\echo === 19. CLEAN CHECK ===

SELECT COUNT(*) AS fixture_runs
FROM production_run
WHERE run_id = 'RUN-11E32-INTEGRATION';

SELECT COUNT(*) AS fixture_stages
FROM production_stage
WHERE run_id = 'RUN-11E32-INTEGRATION';

\echo
\echo ============================================================
\echo 11-E.32-INTEGRATION
\echo ALL TESTS PASSED
\echo ============================================================

COMMIT;

\echo
\echo ============================================================
\echo 11-E.32-INTEGRATION COMMITTED
\echo ============================================================
