\set ON_ERROR_STOP on
\pset pager off

BEGIN;

\echo ============================================================
\echo 11-E.32-FIX-1
\echo VALIDATE_RUN_STAGE_CONSISTENCY
\echo RETRYABLE STAGE ERROR MODEL
\echo ============================================================

\echo
\echo === 01. BASELINE FUNCTION ===

SELECT
    md5(pg_get_functiondef(
        'public.validate_run_stage_consistency(character varying)'::regprocedure
    )) AS baseline_function_md5;

SELECT pg_get_functiondef(
    'public.validate_run_stage_consistency(character varying)'::regprocedure
);

\echo
\echo === 02. REPLACE FUNCTION ===

CREATE OR REPLACE FUNCTION public.validate_run_stage_consistency(
    p_run_id VARCHAR
)
RETURNS TABLE(
    allowed BOOLEAN,
    error_code VARCHAR,
    error_message TEXT
)
LANGUAGE plpgsql
AS $function$
DECLARE
    v_run_status VARCHAR(32);

    v_pending_count INTEGER;
    v_running_count INTEGER;
    v_succeeded_count INTEGER;
    v_error_count INTEGER;
    v_cancelled_count INTEGER;
    v_skipped_count INTEGER;

    v_terminal_error_count INTEGER;
    v_retryable_error_count INTEGER;
BEGIN

    SELECT pr.status
    INTO v_run_status
    FROM public.production_run AS pr
    WHERE pr.run_id = p_run_id;

    IF NOT FOUND THEN
        RETURN QUERY
        SELECT
            FALSE,
            'RUN_NOT_FOUND'::VARCHAR(128),
            ('Run inexistant : ' || p_run_id)::TEXT;
        RETURN;
    END IF;

    SELECT
        COUNT(*) FILTER (WHERE ps.status = 'PENDING'),
        COUNT(*) FILTER (WHERE ps.status = 'RUNNING'),
        COUNT(*) FILTER (WHERE ps.status = 'SUCCEEDED'),
        COUNT(*) FILTER (WHERE ps.status = 'ERROR'),
        COUNT(*) FILTER (WHERE ps.status = 'CANCELLED'),
        COUNT(*) FILTER (WHERE ps.status = 'SKIPPED'),
        COUNT(*) FILTER (
            WHERE ps.status = 'ERROR'
              AND ps.retryable = FALSE
        ),
        COUNT(*) FILTER (
            WHERE ps.status = 'ERROR'
              AND ps.retryable = TRUE
        )
    INTO
        v_pending_count,
        v_running_count,
        v_succeeded_count,
        v_error_count,
        v_cancelled_count,
        v_skipped_count,
        v_terminal_error_count,
        v_retryable_error_count
    FROM public.production_stage AS ps
    WHERE ps.run_id = p_run_id;

    /*
     * ============================================================
     * CREATED
     *
     * A retryable Stage ERROR is an intermediate recoverable state.
     * It must NOT invalidate the Run because the Stage can still
     * return to RUNNING through claim_stage_for_execution().
     *
     * A terminal Stage ERROR remains incompatible with CREATED and
     * must escalate to Run ERROR through fail_run_atomically().
     * ============================================================
     */
    IF v_run_status = 'CREATED' THEN

        IF v_running_count > 0 THEN
            RETURN QUERY
            SELECT
                FALSE,
                'RUN_STAGE_STATE_MISMATCH'::VARCHAR(128),
                'Run CREATED mais au moins un stage est RUNNING.'::TEXT;
            RETURN;
        END IF;

        IF v_terminal_error_count > 0 THEN
            RETURN QUERY
            SELECT
                FALSE,
                'RUN_STAGE_STATE_MISMATCH'::VARCHAR(128),
                'Run CREATED mais au moins un stage est en ERROR terminal.'::TEXT;
            RETURN;
        END IF;

        IF v_cancelled_count > 0 THEN
            RETURN QUERY
            SELECT
                FALSE,
                'RUN_STAGE_STATE_MISMATCH'::VARCHAR(128),
                'Run CREATED mais au moins un stage est CANCELLED.'::TEXT;
            RETURN;
        END IF;

        IF v_succeeded_count > 0
           AND v_pending_count = 0
           AND v_error_count = 0
           AND v_cancelled_count = 0
           AND v_skipped_count = 0 THEN
            RETURN QUERY
            SELECT
                FALSE,
                'RUN_STAGE_STATE_MISMATCH'::VARCHAR(128),
                'Run CREATED alors que tous les stages sont SUCCEEDED.'::TEXT;
            RETURN;
        END IF;

        RETURN QUERY
        SELECT
            TRUE,
            NULL::VARCHAR(128),
            CASE
                WHEN v_retryable_error_count > 0
                    THEN 'Run CREATED coherent avec un ou plusieurs stages ERROR retryables.'::TEXT
                ELSE
                    'Run CREATED coherent avec ses stages.'::TEXT
            END;
        RETURN;
    END IF;

    /*
     * ============================================================
     * VALIDATED
     * ============================================================
     */
    IF v_run_status = 'VALIDATED' THEN

        IF v_pending_count > 0
           OR v_running_count > 0
           OR v_error_count > 0
           OR v_cancelled_count > 0 THEN
            RETURN QUERY
            SELECT
                FALSE,
                'RUN_STAGE_STATE_MISMATCH'::VARCHAR(128),
                'Run VALIDATED mais des stages ne sont pas dans un état valide.'::TEXT;
            RETURN;
        END IF;

        RETURN QUERY
        SELECT
            TRUE,
            NULL::VARCHAR(128),
            'Run VALIDATED coherent avec ses stages.'::TEXT;
        RETURN;
    END IF;

    /*
     * ============================================================
     * ACTIVE PIPELINE STATES
     * ============================================================
     */
    IF v_run_status IN (
        'ASSET_READY',
        'AUDIO_READY',
        'COMPOSED',
        'RENDERED',
        'QC_PASSED',
        'READY_TO_PUBLISH'
    ) THEN

        IF v_pending_count > 0
           OR v_running_count > 0
           OR v_error_count > 0
           OR v_cancelled_count > 0 THEN
            RETURN QUERY
            SELECT
                FALSE,
                'RUN_STAGE_STATE_MISMATCH'::VARCHAR(128),
                ('Run ' || v_run_status ||
                 ' mais des stages ne sont pas dans un état compatible.')::TEXT;
            RETURN;
        END IF;

        RETURN QUERY
        SELECT
            TRUE,
            NULL::VARCHAR(128),
            ('Run ' || v_run_status ||
             ' coherent avec ses stages.')::TEXT;
        RETURN;
    END IF;

    /*
     * ============================================================
     * ERROR
     *
     * Run ERROR requires at least one terminal Stage ERROR.
     * A retryable Stage ERROR alone must never produce Run ERROR.
     * ============================================================
     */
    IF v_run_status = 'ERROR' THEN

        IF v_terminal_error_count = 0 THEN
            RETURN QUERY
            SELECT
                FALSE,
                'RUN_STAGE_STATE_MISMATCH'::VARCHAR(128),
                'Run ERROR mais aucun stage ERROR terminal.'::TEXT;
            RETURN;
        END IF;

        IF v_running_count > 0 THEN
            RETURN QUERY
            SELECT
                FALSE,
                'RUN_STAGE_STATE_MISMATCH'::VARCHAR(128),
                'Run ERROR mais au moins un stage est RUNNING.'::TEXT;
            RETURN;
        END IF;

        RETURN QUERY
        SELECT
            TRUE,
            NULL::VARCHAR(128),
            'Run ERROR coherent avec au moins un stage ERROR terminal.'::TEXT;
        RETURN;
    END IF;

    /*
     * ============================================================
     * CANCELLED
     * ============================================================
     */
    IF v_run_status = 'CANCELLED' THEN

        IF v_running_count > 0 THEN
            RETURN QUERY
            SELECT
                FALSE,
                'RUN_STAGE_STATE_MISMATCH'::VARCHAR(128),
                'Run CANCELLED mais au moins un stage est RUNNING.'::TEXT;
            RETURN;
        END IF;

        RETURN QUERY
        SELECT
            TRUE,
            NULL::VARCHAR(128),
            'Run CANCELLED coherent avec ses stages.'::TEXT;
        RETURN;
    END IF;

    /*
     * Etat Run inconnu.
     *
     * La contrainte SQL actuelle devrait deja l'interdire,
     * mais le guard reste defensif.
     */
    RETURN QUERY
    SELECT
        FALSE,
        'UNSUPPORTED_RUN_STATUS'::VARCHAR(128),
        ('Statut Run non gere par le guard : ' || v_run_status)::TEXT;

END;
$function$;

\echo
\echo === 03. FUNCTION INSTALLED ===

SELECT
    COUNT(*) AS function_count
FROM pg_proc p
JOIN pg_namespace n
  ON n.oid = p.pronamespace
WHERE n.nspname = 'public'
  AND p.proname = 'validate_run_stage_consistency'
  AND p.prokind = 'f';

\echo
\echo === 04. SOURCE MARKERS ===

WITH src AS (
    SELECT pg_get_functiondef(
        'public.validate_run_stage_consistency(character varying)'::regprocedure
    ) AS s
)
SELECT
    position('v_terminal_error_count' in s) > 0
        AS terminal_error_guard,
    position('v_retryable_error_count' in s) > 0
        AS retryable_error_guard,
    position('Run CREATED coherent avec un ou plusieurs stages ERROR retryables.' in s) > 0
        AS created_retryable_message,
    position('Run CREATED mais au moins un stage est en ERROR terminal.' in s) > 0
        AS created_terminal_guard,
    position('Run ERROR mais aucun stage ERROR terminal.' in s) > 0
        AS run_error_terminal_guard
FROM src;

\echo
\echo ============================================================
\echo TESTS
\echo ============================================================

\echo
\echo === 05. FIXTURE SETUP ===

INSERT INTO public.production_run (
    run_id,
    project_id,
    status,
    current_stage,
    attempt,
    input_json,
    output_json
)
VALUES
(
    'RUN-11E32-FIX-CONSISTENCY',
    'PROJECT-11E32-FIX',
    'CREATED',
    'RUN_MANAGER',
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
VALUES
(
    'STG-11E32-FIX-CONSISTENCY',
    'RUN-11E32-FIX-CONSISTENCY',
    'TEST_RETRY',
    1,
    'ERROR',
    1,
    TRUE,
    'RUN-11E32-FIX-CONSISTENCY:TEST_RETRY:1',
    '[]'::jsonb,
    '[]'::jsonb,
    '{}'::jsonb,
    '{}'::jsonb
);

\echo
\echo === 06. CREATED + RETRYABLE ERROR MUST BE COHERENT ===

SELECT *
FROM validate_run_stage_consistency(
    'RUN-11E32-FIX-CONSISTENCY'
);

DO $$
DECLARE
    v_allowed BOOLEAN;
    v_code VARCHAR;
BEGIN
    SELECT allowed, error_code
    INTO v_allowed, v_code
    FROM validate_run_stage_consistency(
        'RUN-11E32-FIX-CONSISTENCY'
    );

    IF v_allowed IS DISTINCT FROM TRUE THEN
        RAISE EXCEPTION
            'TEST FAILED: CREATED + retryable ERROR must be coherent. code=%',
            v_code;
    END IF;
END
$$;

\echo PASS: CREATED + retryable ERROR

\echo
\echo === 07. CREATED + TERMINAL ERROR MUST BE INCOHERENT ===

UPDATE public.production_stage
SET retryable = FALSE
WHERE stage_id = 'STG-11E32-FIX-CONSISTENCY';

SELECT *
FROM validate_run_stage_consistency(
    'RUN-11E32-FIX-CONSISTENCY'
);

DO $$
DECLARE
    v_allowed BOOLEAN;
    v_code VARCHAR;
BEGIN
    SELECT allowed, error_code
    INTO v_allowed, v_code
    FROM validate_run_stage_consistency(
        'RUN-11E32-FIX-CONSISTENCY'
    );

    IF v_allowed IS DISTINCT FROM FALSE
       OR v_code IS DISTINCT FROM 'RUN_STAGE_STATE_MISMATCH' THEN
        RAISE EXCEPTION
            'TEST FAILED: CREATED + terminal ERROR must be rejected. allowed=% code=%',
            v_allowed,
            v_code;
    END IF;
END
$$;

\echo PASS: CREATED + terminal ERROR rejected

\echo
\echo === 08. ERROR + TERMINAL ERROR MUST BE COHERENT ===

UPDATE public.production_run
SET status = 'ERROR',
    current_stage = 'TEST_RETRY',
    error_code = 'NETWORK_ERROR',
    error_message = 'terminal test'
WHERE run_id = 'RUN-11E32-FIX-CONSISTENCY';

SELECT *
FROM validate_run_stage_consistency(
    'RUN-11E32-FIX-CONSISTENCY'
);

DO $$
DECLARE
    v_allowed BOOLEAN;
BEGIN
    SELECT allowed
    INTO v_allowed
    FROM validate_run_stage_consistency(
        'RUN-11E32-FIX-CONSISTENCY'
    );

    IF v_allowed IS DISTINCT FROM TRUE THEN
        RAISE EXCEPTION
            'TEST FAILED: ERROR + terminal stage ERROR must be coherent';
    END IF;
END
$$;

\echo PASS: ERROR + terminal ERROR

\echo
\echo === 09. ERROR + ONLY RETRYABLE ERROR MUST BE INCOHERENT ===

UPDATE public.production_stage
SET retryable = TRUE
WHERE stage_id = 'STG-11E32-FIX-CONSISTENCY';

SELECT *
FROM validate_run_stage_consistency(
    'RUN-11E32-FIX-CONSISTENCY'
);

DO $$
DECLARE
    v_allowed BOOLEAN;
BEGIN
    SELECT allowed
    INTO v_allowed
    FROM validate_run_stage_consistency(
        'RUN-11E32-FIX-CONSISTENCY'
    );

    IF v_allowed IS DISTINCT FROM FALSE THEN
        RAISE EXCEPTION
            'TEST FAILED: ERROR + only retryable ERROR must be rejected';
    END IF;
END
$$;

\echo PASS: ERROR + only retryable ERROR rejected

\echo
\echo === 10. CLEANUP FIXTURE ===

DELETE FROM public.production_stage_event
WHERE run_id = 'RUN-11E32-FIX-CONSISTENCY';

DELETE FROM public.production_run_event
WHERE run_id = 'RUN-11E32-FIX-CONSISTENCY';

DELETE FROM public.production_stage
WHERE run_id = 'RUN-11E32-FIX-CONSISTENCY';

DELETE FROM public.production_run
WHERE run_id = 'RUN-11E32-FIX-CONSISTENCY';

\echo
\echo === 11. DATABASE CLEAN CHECK ===

SELECT COUNT(*) AS fixture_runs
FROM public.production_run
WHERE run_id = 'RUN-11E32-FIX-CONSISTENCY';

SELECT COUNT(*) AS fixture_stages
FROM public.production_stage
WHERE run_id = 'RUN-11E32-FIX-CONSISTENCY';

\echo
\echo ============================================================
\echo 11-E.32-FIX-1
\echo ALL TESTS PASSED
\echo ============================================================

COMMIT;

\echo
\echo ============================================================
\echo 11-E.32-FIX-1 COMMITTED
\echo ============================================================
