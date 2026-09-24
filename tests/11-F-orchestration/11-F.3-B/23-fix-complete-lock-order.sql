\set ON_ERROR_STOP on

BEGIN;

CREATE OR REPLACE FUNCTION public.complete_stage_atomically(
    p_stage_id character varying,
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
    v_run_id VARCHAR(64);
    v_locked_run_id VARCHAR(64);
    v_stage_status VARCHAR(32);
    v_artifact_id VARCHAR(128);
    v_artifact_status VARCHAR(32);
    v_artifact_run_id VARCHAR(64);
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
            FALSE,
            'STAGE_NOT_FOUND'::VARCHAR(128),
            'Stage inexistant.'::TEXT,
            NULL::VARCHAR(32);
        RETURN;
    END IF;

    /*
     * ------------------------------------------------------------
     * 2. GLOBAL LOCK ORDER:
     *
     *        RUN -> STAGE
     *
     *    This matches fail_stage_atomically and fail_run_atomically.
     * ------------------------------------------------------------
     */
    SELECT pr.run_id
    INTO v_locked_run_id
    FROM public.production_run pr
    WHERE pr.run_id = v_run_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RETURN QUERY
        SELECT
            FALSE,
            'RUN_NOT_FOUND'::VARCHAR(128),
            'Run inexistant.'::TEXT,
            NULL::VARCHAR(32);
        RETURN;
    END IF;

    /*
     * ------------------------------------------------------------
     * 3. Lock STAGE after RUN.
     * ------------------------------------------------------------
     */
    SELECT
        ps.status,
        ps.output_artifact_ids ->> 0,
        ps.run_id
    INTO
        v_stage_status,
        v_artifact_id,
        v_run_id
    FROM public.production_stage ps
    WHERE ps.stage_id = p_stage_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RETURN QUERY
        SELECT
            FALSE,
            'STAGE_NOT_FOUND'::VARCHAR(128),
            'Stage inexistant apres verrouillage du run.'::TEXT,
            NULL::VARCHAR(32);
        RETURN;
    END IF;

    /*
     * ------------------------------------------------------------
     * 4. Defensive relationship check.
     * ------------------------------------------------------------
     */
    IF v_run_id <> v_locked_run_id THEN
        RAISE EXCEPTION
            'COMPLETE_STAGE_RUN_RELATION_CHANGED';
    END IF;

    IF v_stage_status <> 'RUNNING' THEN
        RETURN QUERY
        SELECT
            FALSE,
            'STAGE_NOT_RUNNING'::VARCHAR(128),
            ('Stage dans l''etat ' || v_stage_status ||
             ', RUNNING attendu.')::TEXT,
            v_stage_status;
        RETURN;
    END IF;

    /*
     * ------------------------------------------------------------
     * 5. Output artifact required.
     * ------------------------------------------------------------
     */
    IF v_artifact_id IS NULL OR v_artifact_id = '' THEN
        RETURN QUERY
        SELECT
            FALSE,
            'OUTPUT_ARTIFACT_REQUIRED'::VARCHAR(128),
            'Aucun output artifact declare.'::TEXT,
            v_stage_status;
        RETURN;
    END IF;

    /*
     * ------------------------------------------------------------
     * 6. Validate output artifact.
     *
     *    RUN is already locked.
     *    STAGE is already locked.
     * ------------------------------------------------------------
     */
    SELECT
        ar.run_id,
        ar.status
    INTO
        v_artifact_run_id,
        v_artifact_status
    FROM public.artifact_registry ar
    WHERE ar.artifact_id = v_artifact_id
    FOR SHARE;

    IF NOT FOUND THEN
        RETURN QUERY
        SELECT
            FALSE,
            'OUTPUT_ARTIFACT_NOT_FOUND'::VARCHAR(128),
            ('Output artifact inexistant : ' || v_artifact_id)::TEXT,
            v_stage_status;
        RETURN;
    END IF;

    IF v_artifact_run_id <> v_locked_run_id THEN
        RETURN QUERY
        SELECT
            FALSE,
            'OUTPUT_ARTIFACT_RUN_MISMATCH'::VARCHAR(128),
            'Output artifact appartenant a un autre run.'::TEXT,
            v_stage_status;
        RETURN;
    END IF;

    IF v_artifact_status <> 'VALIDATED' THEN
        RETURN QUERY
        SELECT
            FALSE,
            'OUTPUT_ARTIFACT_NOT_VALIDATED'::VARCHAR(128),
            ('Output artifact dans le statut ' ||
             v_artifact_status ||
             ', VALIDATED attendu.')::TEXT,
            v_stage_status;
        RETURN;
    END IF;

    /*
     * ------------------------------------------------------------
     * 7. Atomic Stage transition.
     * ------------------------------------------------------------
     */
    UPDATE public.production_stage
    SET
        status = 'SUCCEEDED',
        output_json =
            COALESCE(output_json, '{}'::jsonb)
            ||
            jsonb_build_object(
                'completed_atomically',
                true,
                'completed_at',
                NOW()
            ),
        completed_at = NOW()
    WHERE stage_id = p_stage_id;

    /*
     * ------------------------------------------------------------
     * 8. Immutable Stage event.
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
    SELECT
        ps.stage_id,
        ps.run_id,
        'STATE_CHANGE',
        'RUNNING',
        'SUCCEEDED',
        ps.stage_name,
        ps.attempt,
        COALESCE(p_event_data, '{}'::jsonb)
    FROM public.production_stage ps
    WHERE ps.stage_id = p_stage_id;

    RETURN QUERY
    SELECT
        TRUE,
        NULL::VARCHAR(128),
        'Stage complete atomiquement avec artifact valide.'::TEXT,
        'SUCCEEDED'::VARCHAR(32);

EXCEPTION
    WHEN OTHERS THEN
        RAISE;
END;
$function$;

COMMIT;
