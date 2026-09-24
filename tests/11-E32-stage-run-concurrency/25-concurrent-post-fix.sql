\set ON_ERROR_STOP on
\timing off

\echo ============================================================
\echo 11-E.32-CONCURRENT-POST-FIX
\echo STAGE FAILURE <-> RUN ESCALATION
\echo ============================================================

BEGIN;

\echo
\echo === 01. CLEAN PRECHECK ===

DELETE FROM public.production_stage_event
WHERE stage_id = 'STG-11E32-CONCURRENT-POST-FIX';

DELETE FROM public.production_run_event
WHERE run_id = 'RUN-11E32-CONCURRENT-POST-FIX';

DELETE FROM public.production_stage
WHERE stage_id = 'STG-11E32-CONCURRENT-POST-FIX';

DELETE FROM public.production_run
WHERE run_id = 'RUN-11E32-CONCURRENT-POST-FIX';

DO $$
BEGIN
    IF EXISTS (
        SELECT 1
        FROM public.production_run
        WHERE run_id = 'RUN-11E32-CONCURRENT-POST-FIX'
    )
    OR EXISTS (
        SELECT 1
        FROM public.production_stage
        WHERE stage_id = 'STG-11E32-CONCURRENT-POST-FIX'
    ) THEN
        RAISE EXCEPTION 'CLEAN_PRECHECK_FAILED';
    END IF;
END $$;

\echo PASS: clean precheck

\echo
\echo === 02. FIXTURE SETUP ===

INSERT INTO public.production_run
(
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
    'RUN-11E32-CONCURRENT-POST-FIX',
    'PROJECT-11E32-CONCURRENT-POST-FIX',
    'CREATED',
    'RUN_MANAGER',
    1,
    '{}'::jsonb,
    '{}'::jsonb
);

INSERT INTO public.production_stage
(
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
VALUES
(
    'STG-11E32-CONCURRENT-POST-FIX',
    'RUN-11E32-CONCURRENT-POST-FIX',
    'TEST_CONCURRENT',
    1,
    'PENDING',
    1,
    'RUN-11E32-CONCURRENT-POST-FIX:TEST_CONCURRENT:1',
    '[]'::jsonb,
    '[]'::jsonb,
    '{}'::jsonb,
    '{}'::jsonb,
    false
);

COMMIT;

\echo PASS: fixture created

\echo
\echo === 03. CLAIM STAGE ===

SELECT *
FROM public.claim_stage_for_execution(
    'STG-11E32-CONCURRENT-POST-FIX'
);

DO $$
DECLARE
    v_status text;
BEGIN
    SELECT status
    INTO v_status
    FROM public.production_stage
    WHERE stage_id = 'STG-11E32-CONCURRENT-POST-FIX';

    IF v_status <> 'RUNNING' THEN
        RAISE EXCEPTION 'CLAIM_FAILED: %', v_status;
    END IF;
END $$;

\echo PASS: Stage RUNNING

COMMIT;

\echo
\echo ============================================================
\echo SETUP COMPLETE
\echo ============================================================
