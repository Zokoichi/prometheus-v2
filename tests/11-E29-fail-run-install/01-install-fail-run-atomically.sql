\set ON_ERROR_STOP on
\pset pager off

\echo ============================================================
\echo 11-E.29
\echo INSTALL FAIL_RUN_ATOMICALLY
\echo PERSISTENT INSTALLATION
\echo ============================================================

\echo
\echo === 01. PRE-INSTALL COUNT ===

SELECT COUNT(*) AS fail_run_function_count
FROM pg_proc p
JOIN pg_namespace n ON n.oid = p.pronamespace
WHERE n.nspname = 'public'
  AND p.prokind = 'f'
  AND p.proname = 'fail_run_atomically';

\echo
\echo === 02. CREATE FUNCTION ===

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
    v_stage_attempt INTEGER;
    v_run_attempt INTEGER;
    v_consistency_allowed BOOLEAN;
    v_consistency_error_code VARCHAR(128);
    v_consistency_error_message TEXT;
BEGIN

    SELECT
        pr.status,
        pr.attempt
    INTO
        v_run_status,
        v_run_attempt
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
        v_stage_attempt
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

    IF v_stage_run_id <> p_run_id THEN
        RETURN QUERY
        SELECT
            FALSE,
            'STAGE_RUN_MISMATCH'::VARCHAR(128),
            'Le Stage n''appartient pas au Run fourni.'::TEXT,
            v_run_status;
        RETURN;
    END IF;

    IF v_stage_status <> 'ERROR' THEN
        RETURN QUERY
        SELECT
            FALSE,
            'STAGE_NOT_ERROR'::VARCHAR(128),
            ('Stage non terminal ERROR : ' || v_stage_status)::TEXT,
            v_run_status;
        RETURN;
    END IF;

    IF v_stage_retryable = TRUE THEN
        RETURN QUERY
        SELECT
            FALSE,
            'STAGE_STILL_RETRYABLE'::VARCHAR(128),
            'Le Stage est encore retryable : escalade Run refusée.'::TEXT,
            v_run_status;
        RETURN;
    END IF;

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

    UPDATE public.production_run AS pr
    SET
        status = 'ERROR',
        current_stage = v_stage_name,
        error_code = v_stage_error_code,
        error_message = v_stage_error_message,
        updated_at = NOW()
    WHERE pr.run_id = p_run_id;

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
        v_stage_attempt,
        COALESCE(p_event_data, '{}'::jsonb)
        ||
        jsonb_build_object(
            'source_stage_id', p_stage_id,
            'source_error_code', v_stage_error_code,
            'source_stage_attempt', v_stage_attempt
        )
    );

    RETURN QUERY
    SELECT
        TRUE,
        NULL::VARCHAR(128),
        ('Run passé en ERROR depuis le Stage ' || p_stage_id)::TEXT,
        'ERROR'::VARCHAR(32);

END;
$function$;

\echo
\echo === 03. FUNCTION SIGNATURE ===

SELECT
    n.nspname AS schema_name,
    p.proname,
    pg_get_function_identity_arguments(p.oid) AS arguments,
    pg_get_function_result(p.oid) AS result_type
FROM pg_proc p
JOIN pg_namespace n ON n.oid = p.pronamespace
WHERE n.nspname = 'public'
  AND p.prokind = 'f'
  AND p.proname = 'fail_run_atomically';

\echo
\echo === 04. SOURCE INTEGRITY CHECKS ===

SELECT
    CASE
        WHEN pg_get_functiondef(p.oid) ILIKE '%FOR UPDATE%'
        THEN 'LOCK_RUN=PASS'
        ELSE 'LOCK_RUN=FAIL'
    END AS lock_run,

    CASE
        WHEN pg_get_functiondef(p.oid) ILIKE '%RUN_ALREADY_ERROR%'
        THEN 'IDEMPOTENCE=PASS'
        ELSE 'IDEMPOTENCE=FAIL'
    END AS idempotence,

    CASE
        WHEN pg_get_functiondef(p.oid) ILIKE '%STAGE_STILL_RETRYABLE%'
        THEN 'TERMINAL_STAGE_GUARD=PASS'
        ELSE 'TERMINAL_STAGE_GUARD=FAIL'
    END AS terminal_stage_guard,

    CASE
        WHEN pg_get_functiondef(p.oid) ILIKE '%error_code = v_stage_error_code%'
        THEN 'ERROR_PROPAGATION=PASS'
        ELSE 'ERROR_PROPAGATION=FAIL'
    END AS error_propagation,

    CASE
        WHEN pg_get_functiondef(p.oid) ILIKE '%validate_run_stage_consistency%'
        THEN 'CONSISTENCY_GUARD=PASS'
        ELSE 'CONSISTENCY_GUARD=FAIL'
    END AS consistency_guard,

    CASE
        WHEN pg_get_functiondef(p.oid) ILIKE '%INSERT INTO public.production_run_event%'
        THEN 'RUN_EVENT=PASS'
        ELSE 'RUN_EVENT=FAIL'
    END AS run_event;

FROM pg_proc p
JOIN pg_namespace n ON n.oid = p.pronamespace
WHERE n.nspname = 'public'
  AND p.prokind = 'f'
  AND p.proname = 'fail_run_atomically';

\echo
\echo === 05. POST-INSTALL COUNT ===

SELECT COUNT(*) AS fail_run_function_count
FROM pg_proc p
JOIN pg_namespace n ON n.oid = p.pronamespace
WHERE n.nspname = 'public'
  AND p.prokind = 'f'
  AND p.proname = 'fail_run_atomically';

\echo
\echo === 06. CURRENT ERROR STATE ===

SELECT
    (
        SELECT COUNT(*)
        FROM public.production_run
        WHERE status = 'ERROR'
    ) AS current_error_runs,

    (
        SELECT COUNT(*)
        FROM public.production_stage
        WHERE status = 'ERROR'
    ) AS current_error_stages;

\echo
\echo ============================================================
\echo 11-E.29 END
\echo ============================================================
