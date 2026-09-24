\set ON_ERROR_STOP on
\timing off

DO $$
DECLARE
    v_run varchar := 'RUN-11F3B-FIXTURE';
    v_stage varchar := 'STG-11F3B-FIXTURE';
BEGIN
    DELETE FROM public.production_stage_event
    WHERE run_id = v_run;

    DELETE FROM public.production_stage_dependency
    WHERE stage_id = v_stage
       OR depends_on_stage_id = v_stage;

    DELETE FROM public.production_execution_event
    WHERE run_id = v_run;

    DELETE FROM public.production_stage
    WHERE stage_id = v_stage;

    DELETE FROM public.production_run_event
    WHERE run_id = v_run;

    DELETE FROM public.production_run
    WHERE run_id = v_run;

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
        v_run,
        'PROJECT-11F3B',
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
        v_stage,
        v_run,
        '11F3B_CONCURRENCY',
        1,
        'PENDING',
        1,
        'RUN-11F3B-FIXTURE:11F3B_CONCURRENCY:1',
        '[]'::jsonb,
        '[]'::jsonb,
        '{}'::jsonb,
        '{}'::jsonb,
        false
    );

    RAISE NOTICE 'SETUP PASS';
END $$;

SELECT
    'BASELINE' AS test,
    pr.status AS run_status,
    ps.status AS stage_status,
    ps.attempt,
    ps.retryable
FROM public.production_run pr
JOIN public.production_stage ps
  ON ps.run_id = pr.run_id
WHERE pr.run_id = 'RUN-11F3B-FIXTURE'
  AND ps.stage_id = 'STG-11F3B-FIXTURE';

SELECT
    'FUNCTIONS' AS test,
    proname,
    pg_get_function_identity_arguments(oid) AS signature
FROM pg_proc
WHERE pronamespace = 'public'::regnamespace
  AND proname IN
  (
      'claim_stage_for_execution',
      'complete_stage_atomically',
      'fail_stage_atomically',
      'fail_run_atomically'
  )
ORDER BY proname;

DO $$
BEGIN
    RAISE NOTICE 'MATRIX FIXTURE READY';
    RAISE NOTICE 'TEST A: CLAIM <-> FAIL_STAGE';
    RAISE NOTICE 'TEST B: CLAIM <-> FAIL_RUN';
    RAISE NOTICE 'TEST C: CLAIM <-> COMPLETE';
    RAISE NOTICE 'TEST D: COMPLETE <-> FAIL_STAGE';
    RAISE NOTICE 'TEST E: COMPLETE <-> FAIL_RUN';
    RAISE NOTICE 'IMPORTANT: worker races will use separate PostgreSQL sessions.';
END $$;

ROLLBACK;
