\set ON_ERROR_STOP on
\pset pager off

BEGIN;

\echo ============================================================
\echo 11-E.28
\echo FAIL_RUN_ATOMICALLY
\echo TRANSACTIONAL TEST
\echo NO PERSISTENT INSTALLATION
\echo ============================================================

\echo
\echo === 01. BASELINE FUNCTION COUNT ===

SELECT COUNT(*) AS fail_run_function_count
FROM pg_proc p
JOIN pg_namespace n ON n.oid = p.pronamespace
WHERE n.nspname = 'public'
  AND p.prokind = 'f'
  AND p.proname = 'fail_run_atomically';

\echo
\echo === 02. CREATE ISOLATED FIXTURE ===

INSERT INTO public.production_run (
    run_id,
    project_id,
    status,
    current_stage,
    attempt
)
VALUES (
    'RUN-11E28-FIXTURE',
    'PROJECT-11E28-FIXTURE',
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
    'STG-11E28-FIXTURE',
    'RUN-11E28-FIXTURE',
    'FAIL_RUN_TEST',
    1,
    'PENDING',
    1,
    'RUN-11E28-FIXTURE:FAIL_RUN_TEST:1'
);

SELECT
    run_id,
    status,
    current_stage,
    attempt,
    error_code,
    error_message
FROM public.production_run
WHERE run_id = 'RUN-11E28-FIXTURE';

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
WHERE stage_id = 'STG-11E28-FIXTURE';

\echo
\echo === 03. CLAIM ATTEMPT 1 ===

SELECT *
FROM public.claim_stage_for_execution(
    'STG-11E28-FIXTURE'
);

\echo
\echo === 04. FAIL ATTEMPT 1 ===

SELECT *
FROM public.fail_stage_atomically(
    'STG-11E28-FIXTURE',
    'NETWORK_ERROR',
    '11-E28 simulated network failure attempt 1',
    '{"fixture":"11-E28","attempt":1}'::jsonb
);

\echo
\echo === 05. CLAIM RETRY ATTEMPT 2 ===

SELECT *
FROM public.claim_stage_for_execution(
    'STG-11E28-FIXTURE'
);

\echo
\echo === 06. FAIL ATTEMPT 2 ===

SELECT *
FROM public.fail_stage_atomically(
    'STG-11E28-FIXTURE',
    'NETWORK_ERROR',
    '11-E28 simulated network failure attempt 2',
    '{"fixture":"11-E28","attempt":2}'::jsonb
);

\echo
\echo === 07. CLAIM RETRY ATTEMPT 3 ===

SELECT *
FROM public.claim_stage_for_execution(
    'STG-11E28-FIXTURE'
);

\echo
\echo === 08. FAIL ATTEMPT 3 - TERMINAL ===

SELECT *
FROM public.fail_stage_atomically(
    'STG-11E28-FIXTURE',
    'NETWORK_ERROR',
    '11-E28 terminal network failure attempt 3',
    '{"fixture":"11-E28","attempt":3}'::jsonb
);

\echo
\echo === 09. VERIFY TERMINAL STAGE BEFORE RUN ESCALATION ===

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
WHERE stage_id = 'STG-11E28-FIXTURE';

\echo
\echo === 10. CREATE FAIL_RUN_ATOMICALLY TEMPORARILY ===

CREATE OR REPLACE FUNCTION public.fail_run_atomically(
    p_run_id character varying,
    p_stage_id character varying,
    p_event_type character varying DEFAULT 'RUN_ERROR',
    p_event_data jsonb DEFAULT '{}'::jsonb
)
RETURNS TABLE(
    allowed boolean,
    error_code character varying,
    error_message text,
    resulting_status character varying
)
LANGUAGE plpgsql
AS $function$
DECLARE
    v_run_status VARCHAR(32);
    v_stage_run_id VARCHAR(64);
    v_stage_name VARCHAR(64);
    v_stage_status VARCHAR(32);
    v_stage_retryable BOOLEAN;
    v_stage_error_code VARCHAR(128);
    v_stage_error_message TEXT;
    v_attempt INTEGER;
    v_consistency_allowed BOOLEAN;
    v_consistency_error_code VARCHAR(128);
    v_consistency_error_message TEXT;
BEGIN

    -- ========================================================
    -- 1. LOCK RUN FIRST
    -- ========================================================

    SELECT
        pr.status,
        pr.attempt
    INTO
        v_run_status,
        v_attempt
    FROM public.production_run AS pr
    WHERE pr.run_id = p_run_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RETURN QUERY
        SELECT
            FALSE,
            'RUN_NOT_FOUND'::VARCHAR(128),
            ('Run inexistant : ' || p_run_id)::TEXT,
            NULL::VARCHAR(32);
        RETURN;
    END IF;

    -- ========================================================
    -- 2. IDEMPOTENCE
    -- ========================================================

    IF v_run_status = 'ERROR' THEN
        RETURN QUERY
        SELECT
            FALSE,
            'RUN_ALREADY_ERROR'::VARCHAR(128),
            'Run déjà en ERROR. Aucune mutation.'::TEXT,
            v_run_status;
        RETURN;
    END IF;

    IF v_run_status IN ('CANCELLED', 'PUBLISHED') THEN
        RETURN QUERY
        SELECT
            FALSE,
            'RUN_TERMINAL'::VARCHAR(128),
            ('Run terminal : ' || v_run_status)::TEXT,
            v_run_status;
        RETURN;
    END IF;

    -- ========================================================
    -- 3. LOCK STAGE
    -- ========================================================

    SELECT
        ps.run_id,
        ps.stage_name,
        ps.status,
        ps.retryable,
        ps.error_code,
        ps.error_message,
        ps.attempt
    INTO
        v_stage_run_id,
        v_stage_name,
        v_stage_status,
        v_stage_retryable,
        v_stage_error_code,
        v_stage_error_message,
        v_attempt
    FROM public.production_stage AS ps
    WHERE ps.stage_id = p_stage_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RETURN QUERY
        SELECT
            FALSE,
            'STAGE_NOT_FOUND'::VARCHAR(128),
            ('Stage inexistant : ' || p_stage_id)::TEXT,
            v_run_status;
        RETURN;
    END IF;

    -- ========================================================
    -- 4. SAME RUN
    -- ========================================================

    IF v_stage_run_id <> p_run_id THEN
        RETURN QUERY
        SELECT
            FALSE,
            'STAGE_RUN_MISMATCH'::VARCHAR(128),
            'Le Stage n''appartient pas au Run fourni.'::TEXT,
            v_run_status;
        RETURN;
    END IF;

    -- ========================================================
    -- 5. TERMINAL STAGE ERROR REQUIRED
    -- ========================================================

    IF v_stage_status <> 'ERROR' THEN
        RETURN QUERY
        SELECT
            FALSE,
            'STAGE_NOT_ERROR'::VARCHAR(128),
            ('Stage non terminal ERROR : ' || v_stage_status)::TEXT,
            v_run_status;
        RETURN;
    END IF;

    -- ========================================================
    -- 6. RETRY MUST BE EXHAUSTED
    -- ========================================================

    IF v_stage_retryable = TRUE THEN
        RETURN QUERY
        SELECT
            FALSE,
            'STAGE_STILL_RETRYABLE'::VARCHAR(128),
            'Le Stage est encore retryable : escalade Run refusée.'::TEXT,
            v_run_status;
        RETURN;
    END IF;

    -- ========================================================
    -- 7. ERROR DATA REQUIRED
    -- ========================================================

    IF NULLIF(BTRIM(v_stage_error_code), '') IS NULL THEN
        RETURN QUERY
        SELECT
            FALSE,
            'STAGE_ERROR_CODE_MISSING'::VARCHAR(128),
            'Le Stage ERROR ne possède aucun error_code.'::TEXT,
            v_run_status;
        RETURN;
    END IF;

    IF NULLIF(BTRIM(v_stage_error_message), '') IS NULL THEN
        RETURN QUERY
        SELECT
            FALSE,
            'STAGE_ERROR_MESSAGE_MISSING'::VARCHAR(128),
            'Le Stage ERROR ne possède aucun error_message.'::TEXT,
            v_run_status;
        RETURN;
    END IF;

    -- ========================================================
    -- 8. ATOMIC RUN UPDATE
    -- ========================================================

    UPDATE public.production_run AS pr
    SET
        status = 'ERROR',
        current_stage = v_stage_name,
        error_code = v_stage_error_code,
        error_message = v_stage_error_message,
        updated_at = NOW()
    WHERE pr.run_id = p_run_id;

    -- ========================================================
    -- 9. RUN <-> STAGE CONSISTENCY
    -- ========================================================

    SELECT
        v.allowed,
        v.error_code,
        v.error_message
    INTO
        v_consistency_allowed,
        v_consistency_error_code,
        v_consistency_error_message
    FROM public.validate_run_stage_consistency(p_run_id) AS v;

    IF NOT v_consistency_allowed THEN
        RAISE EXCEPTION
            USING
                ERRCODE = 'P0001',
                MESSAGE =
                    'RUN_STAGE_INCONSISTENCY: ' ||
                    v_consistency_error_message;
    END IF;

    -- ========================================================
    -- 10. RUN EVENT
    -- ========================================================

    INSERT INTO public.production_run_event (
        run_id,
        event_type,
        from_status,
        to_status,
        stage,
        attempt,
        event_data
    )
    VALUES (
        p_run_id,
        COALESCE(NULLIF(BTRIM(p_event_type), ''), 'RUN_ERROR'),
        v_run_status,
        'ERROR',
        v_stage_name,
        v_attempt,
        COALESCE(p_event_data, '{}'::jsonb)
        ||
        jsonb_build_object(
            'source_stage_id', p_stage_id,
            'source_error_code', v_stage_error_code,
            'source_stage_attempt', v_attempt
        )
    );

    -- ========================================================
    -- 11. RESULT
    -- ========================================================

    RETURN QUERY
    SELECT
        TRUE,
        NULL::VARCHAR(128),
        ('Run passé en ERROR depuis le Stage ' || p_stage_id)::TEXT,
        'ERROR'::VARCHAR(32);

END;
$function$;

\echo
\echo === 11. VERIFY TEMPORARY FUNCTION ===

SELECT
    n.nspname AS schema_name,
    p.proname,
    pg_get_function_identity_arguments(p.oid) AS arguments
FROM pg_proc p
JOIN pg_namespace n
    ON n.oid = p.pronamespace
WHERE n.nspname = 'public'
  AND p.prokind = 'f'
  AND p.proname = 'fail_run_atomically';

\echo
\echo === 12. EXECUTE RUN ESCALATION ===

SELECT *
FROM public.fail_run_atomically(
    'RUN-11E28-FIXTURE',
    'STG-11E28-FIXTURE',
    'RUN_ERROR',
    '{"fixture":"11-E28","reason":"terminal_stage_failure"}'::jsonb
);

\echo
\echo === 13. VERIFY RUN AFTER ESCALATION ===

SELECT
    run_id,
    status,
    current_stage,
    attempt,
    error_code,
    error_message
FROM public.production_run
WHERE run_id = 'RUN-11E28-FIXTURE';

\echo
\echo === 14. VERIFY STAGE AFTER ESCALATION ===

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
WHERE stage_id = 'STG-11E28-FIXTURE';

\echo
\echo === 15. VERIFY RUN EVENT ===

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
WHERE run_id = 'RUN-11E28-FIXTURE'
ORDER BY id;

\echo
\echo === 16. IDEMPOTENCE - SECOND ESCALATION ===

SELECT *
FROM public.fail_run_atomically(
    'RUN-11E28-FIXTURE',
    'STG-11E28-FIXTURE',
    'RUN_ERROR',
    '{"fixture":"11-E28","second_call":true}'::jsonb
);

\echo
\echo === 17. EVENT COUNT AFTER IDEMPOTENT SECOND CALL ===

SELECT COUNT(*) AS run_error_event_count
FROM public.production_run_event
WHERE run_id = 'RUN-11E28-FIXTURE';

\echo
\echo === 18. CONSISTENCY VALIDATION ===

SELECT *
FROM public.validate_run_stage_consistency(
    'RUN-11E28-FIXTURE'
);

\echo
\echo === 19. NEGATIVE TEST - RETRYABLE STAGE MUST NOT ESCALATE ===

UPDATE public.production_run
SET
    status = 'CREATED',
    current_stage = 'RUN_MANAGER',
    error_code = NULL,
    error_message = NULL
WHERE run_id = 'RUN-11E28-FIXTURE';

UPDATE public.production_stage
SET
    status = 'ERROR',
    retryable = TRUE,
    error_code = 'NETWORK_ERROR',
    error_message = '11-E28 retryable failure'
WHERE stage_id = 'STG-11E28-FIXTURE';

SELECT *
FROM public.fail_run_atomically(
    'RUN-11E28-FIXTURE',
    'STG-11E28-FIXTURE'
);

\echo
\echo === 20. NEGATIVE TEST - NON ERROR STAGE MUST NOT ESCALATE ===

UPDATE public.production_stage
SET
    status = 'RUNNING',
    retryable = FALSE,
    error_code = NULL,
    error_message = NULL
WHERE stage_id = 'STG-11E28-FIXTURE';

SELECT *
FROM public.fail_run_atomically(
    'RUN-11E28-FIXTURE',
    'STG-11E28-FIXTURE'
);

\echo
\echo === 21. NEGATIVE TEST - WRONG RUN MUST NOT ESCALATE ===

UPDATE public.production_stage
SET
    status = 'ERROR',
    retryable = FALSE,
    error_code = 'NETWORK_ERROR',
    error_message = '11-E28 wrong-run test'
WHERE stage_id = 'STG-11E28-FIXTURE';

SELECT *
FROM public.fail_run_atomically(
    'RUN-11E28-OTHER-RUN',
    'STG-11E28-FIXTURE'
);

\echo
\echo === 22. ROLLBACK VERIFICATION ===

ROLLBACK;

SELECT COUNT(*) AS fail_run_function_count_after_rollback
FROM pg_proc p
JOIN pg_namespace n ON n.oid = p.pronamespace
WHERE n.nspname = 'public'
  AND p.prokind = 'f'
  AND p.proname = 'fail_run_atomically';

SELECT COUNT(*) AS fixture_run_count_after_rollback
FROM public.production_run
WHERE run_id = 'RUN-11E28-FIXTURE';

SELECT COUNT(*) AS fixture_stage_count_after_rollback
FROM public.production_stage
WHERE stage_id = 'STG-11E28-FIXTURE';

SELECT COUNT(*) AS fixture_run_event_count_after_rollback
FROM public.production_run_event
WHERE run_id = 'RUN-11E28-FIXTURE';

\echo
\echo ============================================================
\echo 11-E.28 END
\echo TRANSACTION ROLLED BACK
\echo ============================================================
