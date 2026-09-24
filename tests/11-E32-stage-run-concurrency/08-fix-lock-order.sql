\set ON_ERROR_STOP on
\pset pager off

BEGIN;

\echo ============================================================
\echo 11-E.32-FIX
\echo LOCK ORDER: RUN -> STAGE
\echo ============================================================

\echo
\echo === 01. BASELINE FUNCTION COUNT ===

SELECT COUNT(*) AS fail_stage_function_count
FROM pg_proc p
JOIN pg_namespace n ON n.oid = p.pronamespace
WHERE n.nspname = 'public'
  AND p.proname = 'fail_stage_atomically';

\echo
\echo === 02. REPLACE fail_stage_atomically ===

CREATE OR REPLACE FUNCTION public.fail_stage_atomically(
    p_stage_id character varying,
    p_error_code character varying,
    p_error_message text,
    p_event_data jsonb DEFAULT '{}'::jsonb
)
RETURNS TABLE(
    allowed boolean,
    message text,
    stage_id character varying,
    stage_status character varying,
    attempt integer,
    retryable boolean,
    error_code character varying
)
LANGUAGE plpgsql
AS $function$
DECLARE
    v_run_id VARCHAR(64);
    v_stage public.production_stage%ROWTYPE;
    v_classification RECORD;
    v_event_data jsonb;
BEGIN

    /*
     * ------------------------------------------------------------
     * 1. Resolve immutable stage -> run relationship WITHOUT
     *    taking the stage lock.
     * ------------------------------------------------------------
     */
    SELECT ps.run_id
    INTO v_run_id
    FROM public.production_stage ps
    WHERE ps.stage_id = p_stage_id;

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
     * ------------------------------------------------------------
     * 2. LOCK RUN FIRST.
     *
     *    This establishes the same lock order as fail_run_atomically:
     *
     *        RUN -> STAGE
     * ------------------------------------------------------------
     */
    PERFORM 1
    FROM public.production_run pr
    WHERE pr.run_id = v_run_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RETURN QUERY
        SELECT
            false,
            'RUN_NOT_FOUND'::text,
            p_stage_id,
            NULL::varchar,
            NULL::integer,
            NULL::boolean,
            NULL::varchar;
        RETURN;
    END IF;

    /*
     * ------------------------------------------------------------
     * 3. NOW LOCK STAGE.
     * ------------------------------------------------------------
     */
    SELECT *
    INTO v_stage
    FROM public.production_stage ps
    WHERE ps.stage_id = p_stage_id
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
     * ------------------------------------------------------------
     * 4. Defensive relationship check.
     * ------------------------------------------------------------
     */
    IF v_stage.run_id <> v_run_id THEN
        RAISE EXCEPTION
            'FAIL_STAGE_RUN_RELATION_CHANGED';
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

    /*
     * ------------------------------------------------------------
     * 5. Classify error.
     * ------------------------------------------------------------
     */
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

    /*
     * ------------------------------------------------------------
     * 6. Atomic Stage transition.
     * ------------------------------------------------------------
     */
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

    /*
     * ------------------------------------------------------------
     * 7. Immutable stage error event.
     * ------------------------------------------------------------
     */
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
\echo === 03. FUNCTION EXISTS ===

SELECT COUNT(*) AS installed_function_count
FROM pg_proc p
JOIN pg_namespace n ON n.oid = p.pronamespace
WHERE n.nspname = 'public'
  AND p.proname = 'fail_stage_atomically';

\echo
\echo === 04. LOCK ORDER PROOF ===

WITH f AS (
    SELECT pg_get_functiondef(p.oid) AS definition
    FROM pg_proc p
    JOIN pg_namespace n ON n.oid = p.pronamespace
    WHERE n.nspname = 'public'
      AND p.proname = 'fail_stage_atomically'
)
SELECT
    CASE
        WHEN definition ~* 'production_run.*FOR UPDATE'
         AND definition ~* 'production_stage.*FOR UPDATE'
         AND position('production_run' IN definition)
             < position('production_stage' IN definition)
        THEN 'PASS'
        ELSE 'FAIL'
    END AS run_before_stage
FROM f;

\echo
\echo === 05. REQUIRED SOURCE MARKERS ===

WITH f AS (
    SELECT pg_get_functiondef(p.oid) AS definition
    FROM pg_proc p
    JOIN pg_namespace n ON n.oid = p.pronamespace
    WHERE n.nspname = 'public'
      AND p.proname = 'fail_stage_atomically'
)
SELECT
    CASE WHEN definition LIKE '%classify_error%' THEN 'PASS' ELSE 'FAIL' END
        AS classify_error,
    CASE WHEN definition LIKE '%STAGE_ERROR%' THEN 'PASS' ELSE 'FAIL' END
        AS stage_error_event,
    CASE WHEN definition LIKE '%STAGE_NOT_RUNNING%' THEN 'PASS' ELSE 'FAIL' END
        AS running_guard,
    CASE WHEN definition LIKE '%FAIL_STAGE_CONCURRENT_STATE_CHANGE%' THEN 'PASS' ELSE 'FAIL' END
        AS concurrent_guard
FROM f;

\echo
\echo === 06. CLEAN PRODUCTION ERROR STATE ===

SELECT
    COUNT(*) FILTER (WHERE status = 'ERROR') AS error_stages,
    COUNT(*) FILTER (
        WHERE status = 'ERROR'
          AND retryable = TRUE
    ) AS retryable_error_stages,
    COUNT(*) FILTER (
        WHERE status = 'ERROR'
          AND retryable = FALSE
    ) AS terminal_error_stages
FROM production_stage;

SELECT
    COUNT(*) FILTER (WHERE status = 'ERROR') AS error_runs
FROM production_run;

\echo
\echo === 07. FIXTURE CLEANLINESS ===

SELECT COUNT(*) AS fixture_runs
FROM production_run
WHERE run_id = 'RUN-11E32-FIXTURE';

SELECT COUNT(*) AS fixture_stages
FROM production_stage
WHERE stage_id = 'STG-11E32-FIXTURE';

COMMIT;

\echo
\echo ============================================================
\echo 11-E.32-FIX INSTALLATION COMMITTED
\echo ============================================================
