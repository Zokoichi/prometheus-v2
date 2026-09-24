\set ON_ERROR_STOP on
\pset pager off

\echo ============================================================
\echo 11-E.24 - FAIL_STAGE_ATOMICALLY
\echo TRANSACTIONAL IMPLEMENTATION + ISOLATED TESTS
\echo ============================================================

BEGIN;

\echo
\echo === 01. CREATE FAIL_STAGE_ATOMICALLY ===

CREATE OR REPLACE FUNCTION public.fail_stage_atomically(
    p_stage_id varchar,
    p_error_code varchar,
    p_error_message text,
    p_event_data jsonb DEFAULT '{}'::jsonb
)
RETURNS TABLE (
    allowed boolean,
    message text,
    stage_id varchar,
    stage_status varchar,
    attempt integer,
    retryable boolean,
    error_code varchar
)
LANGUAGE plpgsql
AS $function$
DECLARE
    v_stage public.production_stage%ROWTYPE;
    v_classification RECORD;
    v_event_data jsonb;
BEGIN
    SELECT *
    INTO v_stage
    FROM public.production_stage
    WHERE production_stage.stage_id = p_stage_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RETURN QUERY
        SELECT
            false,
            'STAGE_NOT_FOUND'::text,
            p_stage_id,
            NULL::varchar,
            NULL::integer,
            NULL::boolean,
            NULL::varchar;
        RETURN;
    END IF;

    /*
     * State guard:
     * only RUNNING may transition to ERROR.
     *
     * This also provides idempotence for repeated calls:
     * the first call changes RUNNING -> ERROR;
     * a second identical call sees ERROR and performs no mutation.
     */
    IF v_stage.status <> 'RUNNING' THEN
        RETURN QUERY
        SELECT
            false,
            ('STAGE_NOT_RUNNING: ' || v_stage.status)::text,
            v_stage.stage_id,
            v_stage.status,
            v_stage.attempt,
            v_stage.retryable,
            v_stage.error_code;
        RETURN;
    END IF;

    IF p_error_code IS NULL OR btrim(p_error_code) = '' THEN
        RAISE EXCEPTION
            'FAIL_STAGE_INVALID_ERROR_CODE';
    END IF;

    IF p_error_message IS NULL OR btrim(p_error_message) = '' THEN
        RAISE EXCEPTION
            'FAIL_STAGE_INVALID_ERROR_MESSAGE';
    END IF;

    SELECT *
    INTO v_classification
    FROM public.classify_error(
        p_error_code,
        v_stage.attempt
    );

    /*
     * retryable on production_stage represents whether THIS ATTEMPT
     * is actually allowed to retry.
     *
     * This is deliberately NOT v_classification.retryable.
     *
     * Example:
     * NETWORK_ERROR attempt 3:
     * policy.retryable = true
     * retry_allowed    = false
     * persisted retryable = false
     */
    v_event_data :=
        COALESCE(p_event_data, '{}'::jsonb)
        ||
        jsonb_build_object(
            'error_code', p_error_code,
            'retryable', v_classification.retry_allowed,
            'policy_retryable', v_classification.retryable,
            'retry_allowed', v_classification.retry_allowed,
            'max_attempts', v_classification.max_attempts,
            'next_backoff_seconds', v_classification.next_backoff_seconds,
            'category', v_classification.category,
            'known_error', v_classification.known
        );

    UPDATE public.production_stage
    SET
        status = 'ERROR',
        error_code = p_error_code,
        error_message = p_error_message,
        retryable = v_classification.retry_allowed,
        completed_at = NULL,
        updated_at = NOW()
    WHERE production_stage.stage_id = p_stage_id
      AND production_stage.status = 'RUNNING';

    IF NOT FOUND THEN
        RAISE EXCEPTION
            'FAIL_STAGE_CONCURRENT_STATE_CHANGE';
    END IF;

    INSERT INTO public.production_stage_event (
        stage_id,
        run_id,
        event_type,
        from_status,
        to_status,
        stage_name,
        attempt,
        event_data
    )
    VALUES (
        v_stage.stage_id,
        v_stage.run_id,
        'STAGE_ERROR',
        'RUNNING',
        'ERROR',
        v_stage.stage_name,
        v_stage.attempt,
        v_event_data
    );

    RETURN QUERY
    SELECT
        true,
        'STAGE_FAILED_ATOMICALLY'::text,
        v_stage.stage_id,
        'ERROR'::varchar,
        v_stage.attempt,
        v_classification.retry_allowed,
        p_error_code;
END;
$function$;

\echo
\echo === 02. FUNCTION SOURCE CHECK ===

SELECT
    p.proname,
    pg_get_function_identity_arguments(p.oid) AS arguments,
    pg_get_function_result(p.oid) AS return_type
FROM pg_proc p
JOIN pg_namespace n
    ON n.oid = p.pronamespace
WHERE n.nspname = 'public'
  AND p.prokind = 'f'
  AND p.proname = 'fail_stage_atomically';

\echo
\echo === 03. CREATE ISOLATED RUN FIXTURE ===

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
    'RUN-11E24-FIXTURE',
    'PROJECT-11E24-FIXTURE',
    'CREATED',
    'RUN_MANAGER',
    1,
    '{}'::jsonb,
    '{}'::jsonb
);

\echo
\echo === 04. CREATE RUNNING STAGE FIXTURE ===

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
    'STG-11E24-FIXTURE',
    'RUN-11E24-FIXTURE',
    'FAIL_STAGE_TEST',
    1,
    'RUNNING',
    1,
    'RUN-11E24-FIXTURE:FAIL_STAGE_TEST:1',
    '[]'::jsonb,
    '[]'::jsonb,
    '{}'::jsonb,
    '{}'::jsonb,
    false
);

\echo
\echo === 05. TEST RETRYABLE ERROR — NETWORK_ERROR ATTEMPT 1 ===

SELECT *
FROM public.fail_stage_atomically(
    'STG-11E24-FIXTURE',
    'NETWORK_ERROR',
    'Fixture network failure',
    jsonb_build_object(
        'test_case', 'retryable_attempt_1'
    )
);

\echo
\echo === 06. VERIFY RETRYABLE FAILURE STATE ===

SELECT
    stage_id,
    status,
    attempt,
    retryable,
    error_code,
    error_message
FROM public.production_stage
WHERE stage_id = 'STG-11E24-FIXTURE';

\echo
\echo === 07. VERIFY STAGE_ERROR EVENT ===

SELECT
    stage_id,
    run_id,
    event_type,
    from_status,
    to_status,
    stage_name,
    attempt,
    event_data
FROM public.production_stage_event
WHERE stage_id = 'STG-11E24-FIXTURE'
ORDER BY id;

\echo
\echo === 08. TEST IDEMPOTENCE — SECOND FAILURE CALL ===

SELECT *
FROM public.fail_stage_atomically(
    'STG-11E24-FIXTURE',
    'NETWORK_ERROR',
    'Duplicate failure call',
    jsonb_build_object(
        'test_case', 'idempotence_second_call'
    )
);

\echo
\echo === 09. VERIFY EVENT COUNT REMAINS ONE ===

SELECT
    COUNT(*) AS stage_error_event_count
FROM public.production_stage_event
WHERE stage_id = 'STG-11E24-FIXTURE'
  AND event_type = 'STAGE_ERROR';

\echo
\echo === 10. RESET FIXTURE TO RUNNING FOR PERMANENT ERROR ===

UPDATE public.production_stage
SET
    status = 'RUNNING',
    error_code = NULL,
    error_message = NULL,
    retryable = false,
    completed_at = NULL
WHERE stage_id = 'STG-11E24-FIXTURE';

\echo
\echo === 11. TEST PERMANENT ERROR — VALIDATION_ERROR ===

SELECT *
FROM public.fail_stage_atomically(
    'STG-11E24-FIXTURE',
    'VALIDATION_ERROR',
    'Fixture validation failure',
    jsonb_build_object(
        'test_case', 'permanent_error'
    )
);

\echo
\echo === 12. VERIFY PERMANENT ERROR STATE ===

SELECT
    stage_id,
    status,
    attempt,
    retryable,
    error_code
FROM public.production_stage
WHERE stage_id = 'STG-11E24-FIXTURE';

\echo
\echo === 13. RESET TO ATTEMPT 3 FOR MAX-ATTEMPT TEST ===

UPDATE public.production_stage
SET
    status = 'RUNNING',
    attempt = 3,
    error_code = NULL,
    error_message = NULL,
    retryable = false,
    completed_at = NULL
WHERE stage_id = 'STG-11E24-FIXTURE';

\echo
\echo === 14. TEST NETWORK_ERROR ATTEMPT 3 ===

SELECT *
FROM public.fail_stage_atomically(
    'STG-11E24-FIXTURE',
    'NETWORK_ERROR',
    'Fixture final network failure',
    jsonb_build_object(
        'test_case', 'max_attempt'
    )
);

\echo
\echo === 15. VERIFY ATTEMPT 3 IS NOT RETRYABLE ===

SELECT
    stage_id,
    status,
    attempt,
    retryable,
    error_code
FROM public.production_stage
WHERE stage_id = 'STG-11E24-FIXTURE';

\echo
\echo === 16. RESET TO RUNNING FOR UNKNOWN ERROR ===

UPDATE public.production_stage
SET
    status = 'RUNNING',
    attempt = 1,
    error_code = NULL,
    error_message = NULL,
    retryable = false,
    completed_at = NULL
WHERE stage_id = 'STG-11E24-FIXTURE';

\echo
\echo === 17. TEST UNKNOWN ERROR ===

SELECT *
FROM public.fail_stage_atomically(
    'STG-11E24-FIXTURE',
    'TOTALLY_UNKNOWN_ERROR',
    'Fixture unknown error',
    jsonb_build_object(
        'test_case', 'unknown_error'
    )
);

\echo
\echo === 18. VERIFY UNKNOWN ERROR IS TERMINAL ===

SELECT
    stage_id,
    status,
    attempt,
    retryable,
    error_code
FROM public.production_stage
WHERE stage_id = 'STG-11E24-FIXTURE';

\echo
\echo === 19. INVALID STATE — PENDING ===

UPDATE public.production_stage
SET
    status = 'PENDING',
    error_code = NULL,
    error_message = NULL,
    retryable = false
WHERE stage_id = 'STG-11E24-FIXTURE';

SELECT *
FROM public.fail_stage_atomically(
    'STG-11E24-FIXTURE',
    'NETWORK_ERROR',
    'Must not fail pending stage',
    '{}'::jsonb
);

\echo
\echo === 20. INVALID STATE — SUCCEEDED ===

UPDATE public.production_stage
SET
    status = 'SUCCEEDED',
    error_code = NULL,
    error_message = NULL,
    retryable = false
WHERE stage_id = 'STG-11E24-FIXTURE';

SELECT *
FROM public.fail_stage_atomically(
    'STG-11E24-FIXTURE',
    'NETWORK_ERROR',
    'Must not fail succeeded stage',
    '{}'::jsonb
);

\echo
\echo === 21. INVALID STAGE ID ===

SELECT *
FROM public.fail_stage_atomically(
    'STG-11E24-NOT-FOUND',
    'NETWORK_ERROR',
    'Missing stage',
    '{}'::jsonb
);

\echo
\echo === 22. NULL ERROR CODE MUST ROLLBACK ===

UPDATE public.production_stage
SET
    status = 'RUNNING',
    attempt = 1,
    error_code = NULL,
    error_message = NULL,
    retryable = false
WHERE stage_id = 'STG-11E24-FIXTURE';

DO $test$
BEGIN
    BEGIN
        PERFORM *
        FROM public.fail_stage_atomically(
            'STG-11E24-FIXTURE',
            NULL,
            'Invalid null error code',
            '{}'::jsonb
        );

        RAISE EXCEPTION 'EXPECTED_EXCEPTION_NOT_RAISED';
    EXCEPTION
        WHEN OTHERS THEN
            IF SQLERRM = 'EXPECTED_EXCEPTION_NOT_RAISED' THEN
                RAISE;
            END IF;
            RAISE NOTICE 'EXPECTED FAILURE CAPTURED: %', SQLERRM;
    END;
END;
$test$;

SELECT
    stage_id,
    status,
    error_code,
    error_message,
    retryable
FROM public.production_stage
WHERE stage_id = 'STG-11E24-FIXTURE';

\echo
\echo === 23. UNKNOWN FUNCTION RESULT CONTRACT ===

SELECT
    public.classify_error(
        'TOTALLY_UNKNOWN_ERROR',
        1
    );

\echo
\echo === 24. FINAL FIXTURE STATE BEFORE ROLLBACK ===

SELECT
    stage_id,
    status,
    attempt,
    retryable,
    error_code,
    error_message
FROM public.production_stage
WHERE stage_id = 'STG-11E24-FIXTURE';

SELECT
    COUNT(*) AS fixture_events
FROM public.production_stage_event
WHERE stage_id = 'STG-11E24-FIXTURE';

\echo
\echo === 25. ROLLBACK ALL TEST CHANGES ===

ROLLBACK;

\echo
\echo === 26. POST-ROLLBACK FUNCTION CHECK ===

SELECT
    COUNT(*) AS fail_stage_function_count
FROM pg_proc p
JOIN pg_namespace n
    ON n.oid = p.pronamespace
WHERE n.nspname = 'public'
  AND p.prokind = 'f'
  AND p.proname = 'fail_stage_atomically';

\echo
\echo === 27. POST-ROLLBACK FIXTURE CHECK ===

SELECT
    COUNT(*) AS fixture_stage_count
FROM public.production_stage
WHERE stage_id = 'STG-11E24-FIXTURE';

SELECT
    COUNT(*) AS fixture_run_count
FROM public.production_run
WHERE run_id = 'RUN-11E24-FIXTURE';

\echo
\echo ============================================================
\echo 11-E.24 END - ALL DATABASE CHANGES ROLLED BACK
\echo ============================================================
