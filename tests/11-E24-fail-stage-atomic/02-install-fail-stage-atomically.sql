\set ON_ERROR_STOP on
\pset pager off

\echo ============================================================
\echo 11-E.24-B
\echo PERSISTENT INSTALLATION - fail_stage_atomically()
\echo ============================================================

BEGIN;

\echo
\echo === 01. PRE-INSTALL FUNCTION COUNT ===

SELECT
    COUNT(*) AS fail_stage_function_count
FROM pg_proc p
JOIN pg_namespace n
    ON n.oid = p.pronamespace
WHERE n.nspname = 'public'
  AND p.prokind = 'f'
  AND p.proname = 'fail_stage_atomically';

\echo
\echo === 02. INSTALL FUNCTION ===

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
\echo === 03. VERIFY INSTALLATION ===

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
\echo === 04. VERIFY FUNCTION SOURCE REFERENCES classify_error ===

SELECT
    CASE
        WHEN pg_get_functiondef(p.oid) LIKE '%classify_error%'
        THEN 'PASS'
        ELSE 'FAIL'
    END AS classify_error_wiring
FROM pg_proc p
JOIN pg_namespace n
    ON n.oid = p.pronamespace
WHERE n.nspname = 'public'
  AND p.prokind = 'f'
  AND p.proname = 'fail_stage_atomically';

\echo
\echo === 05. VERIFY WRITER INVENTORY ===

SELECT
    p.proname,
    CASE
        WHEN pg_get_functiondef(p.oid) LIKE '%production_stage_event%'
        THEN 'STAGE_EVENT_WRITER'
        ELSE 'NO_STAGE_EVENT_REFERENCE'
    END AS event_reference
FROM pg_proc p
JOIN pg_namespace n
    ON n.oid = p.pronamespace
WHERE n.nspname = 'public'
  AND p.prokind = 'f'
  AND (
        pg_get_functiondef(p.oid) ILIKE '%UPDATE public.production_stage%'
        OR pg_get_functiondef(p.oid) ILIKE '%INSERT INTO public.production_stage_event%'
      )
ORDER BY p.proname;

\echo
\echo === 06. COMMIT INSTALLATION ===

COMMIT;

\echo
\echo === 07. POST-COMMIT FUNCTION COUNT ===

SELECT
    COUNT(*) AS fail_stage_function_count
FROM pg_proc p
JOIN pg_namespace n
    ON n.oid = p.pronamespace
WHERE n.nspname = 'public'
  AND p.prokind = 'f'
  AND p.proname = 'fail_stage_atomically';

\echo
\echo ============================================================
\echo 11-E.24-B END
\echo ============================================================
