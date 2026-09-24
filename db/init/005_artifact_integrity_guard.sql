CREATE OR REPLACE FUNCTION validate_stage_artifacts(
    p_stage_id VARCHAR(128)
)
RETURNS TABLE (
    allowed BOOLEAN,
    error_code VARCHAR(128),
    error_message TEXT
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_run_id VARCHAR(64);
    v_artifact_id VARCHAR(128);
    v_artifact_run_id VARCHAR(64);
    v_artifact_status VARCHAR(32);
BEGIN

    /*
     * 1. Le stage doit exister.
     */
    SELECT ps.run_id
    INTO v_run_id
    FROM production_stage ps
    WHERE ps.stage_id = p_stage_id;

    IF NOT FOUND THEN
        RETURN QUERY
        SELECT
            FALSE,
            'STAGE_NOT_FOUND'::VARCHAR(128),
            'Stage inexistant.'::TEXT;
        RETURN;
    END IF;


    /*
     * 2. Vérification des INPUT artifacts.
     */
    FOR v_artifact_id IN
        SELECT jsonb_array_elements_text(
            COALESCE(
                (
                    SELECT input_artifact_ids
                    FROM production_stage
                    WHERE stage_id = p_stage_id
                ),
                '[]'::jsonb
            )
        )
    LOOP

        SELECT
            ar.run_id,
            ar.status
        INTO
            v_artifact_run_id,
            v_artifact_status
        FROM artifact_registry ar
        WHERE ar.artifact_id = v_artifact_id;

        IF NOT FOUND THEN
            RETURN QUERY
            SELECT
                FALSE,
                'ARTIFACT_NOT_FOUND'::VARCHAR(128),
                ('Input artifact inexistant : ' || v_artifact_id)::TEXT;
            RETURN;
        END IF;

        IF v_artifact_run_id <> v_run_id THEN
            RETURN QUERY
            SELECT
                FALSE,
                'ARTIFACT_RUN_MISMATCH'::VARCHAR(128),
                (
                    'Input artifact ' || v_artifact_id ||
                    ' appartient au run ' || v_artifact_run_id ||
                    ', attendu ' || v_run_id || '.'
                )::TEXT;
            RETURN;
        END IF;

        IF v_artifact_status <> 'VALIDATED' THEN
            RETURN QUERY
            SELECT
                FALSE,
                'ARTIFACT_NOT_VALIDATED'::VARCHAR(128),
                (
                    'Input artifact ' || v_artifact_id ||
                    ' est dans le statut ' || v_artifact_status ||
                    ', attendu VALIDATED.'
                )::TEXT;
            RETURN;
        END IF;

    END LOOP;


    /*
     * 3. Vérification des OUTPUT artifacts.
     */
    FOR v_artifact_id IN
        SELECT jsonb_array_elements_text(
            COALESCE(
                (
                    SELECT output_artifact_ids
                    FROM production_stage
                    WHERE stage_id = p_stage_id
                ),
                '[]'::jsonb
            )
        )
    LOOP

        SELECT
            ar.run_id,
            ar.status
        INTO
            v_artifact_run_id,
            v_artifact_status
        FROM artifact_registry ar
        WHERE ar.artifact_id = v_artifact_id;

        IF NOT FOUND THEN
            RETURN QUERY
            SELECT
                FALSE,
                'ARTIFACT_NOT_FOUND'::VARCHAR(128),
                ('Output artifact inexistant : ' || v_artifact_id)::TEXT;
            RETURN;
        END IF;

        IF v_artifact_run_id <> v_run_id THEN
            RETURN QUERY
            SELECT
                FALSE,
                'ARTIFACT_RUN_MISMATCH'::VARCHAR(128),
                (
                    'Output artifact ' || v_artifact_id ||
                    ' appartient au run ' || v_artifact_run_id ||
                    ', attendu ' || v_run_id || '.'
                )::TEXT;
            RETURN;
        END IF;

        IF v_artifact_status <> 'VALIDATED' THEN
            RETURN QUERY
            SELECT
                FALSE,
                'ARTIFACT_NOT_VALIDATED'::VARCHAR(128),
                (
                    'Output artifact ' || v_artifact_id ||
                    ' est dans le statut ' || v_artifact_status ||
                    ', attendu VALIDATED.'
                )::TEXT;
            RETURN;
        END IF;

    END LOOP;


    /*
     * 4. Cohérence PostgreSQL validée.
     *
     * La présence physique S3 est volontairement vérifiée
     * par la couche orchestrateur et non par PostgreSQL.
     */
    RETURN QUERY
    SELECT
        TRUE,
        NULL::VARCHAR(128),
        'Cohérence PostgreSQL des artifacts validée.'::TEXT;

END;
$$;


COMMENT ON FUNCTION validate_stage_artifacts(VARCHAR)
IS
'Guard logique Stage <-> Artifact. Vérifie existence, run_id et statut VALIDATED des artifacts référencés. La présence physique S3 est vérifiée par la couche orchestrateur.';