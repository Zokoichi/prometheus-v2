CREATE OR REPLACE FUNCTION reconcile_artifact_presence(
    p_artifact_id VARCHAR(128),
    p_physical_exists BOOLEAN
)
RETURNS TABLE (
    allowed BOOLEAN,
    error_code VARCHAR(128),
    error_message TEXT,
    resulting_status VARCHAR(32)
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_status VARCHAR(32);
BEGIN

    SELECT status
    INTO v_status
    FROM artifact_registry
    WHERE artifact_id = p_artifact_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RETURN QUERY
        SELECT
            FALSE,
            'ARTIFACT_NOT_FOUND'::VARCHAR(128),
            ('Artifact inexistant : ' || p_artifact_id)::TEXT,
            NULL::VARCHAR(32);
        RETURN;
    END IF;

    /*
     * Objet physique present.
     *
     * Un artifact INVALID peut etre restaure a VALIDATED
     * uniquement si la presence physique a ete verifiee
     * par la couche appelante.
     */
    IF p_physical_exists THEN

        IF v_status = 'DELETED' THEN
            RETURN QUERY
            SELECT
                FALSE,
                'ARTIFACT_ALREADY_DELETED'::VARCHAR(128),
                ('Artifact deja marque DELETED : ' ||
                 p_artifact_id)::TEXT,
                v_status;
            RETURN;
        END IF;

        IF v_status = 'INVALID' THEN

            UPDATE artifact_registry
            SET
                status = 'VALIDATED',
                metadata_json =
                    COALESCE(metadata_json, '{}'::jsonb)
                    || jsonb_build_object(
                        'recovery_reason',
                        'PHYSICAL_OBJECT_RESTORED',
                        'reconciled_at',
                        NOW()
                    )
            WHERE artifact_id = p_artifact_id;

            RETURN QUERY
            SELECT
                TRUE,
                NULL::VARCHAR(128),
                'Artifact physique retrouve et etat restaure a VALIDATED.'::TEXT,
                'VALIDATED'::VARCHAR(32);
            RETURN;
        END IF;

        RETURN QUERY
        SELECT
            TRUE,
            NULL::VARCHAR(128),
            'Presence physique confirmee.'::TEXT,
            v_status;
        RETURN;
    END IF;

    /*
     * Objet physique absent.
     *
     * Tous les etats actifs de stockage deviennent INVALID.
     * L'enregistrement PostgreSQL est conserve pour la tracabilite.
     */
    IF v_status IN (
        'REGISTERED',
        'STORED',
        'VALIDATING',
        'VALIDATED'
    ) THEN

        UPDATE artifact_registry
        SET
            status = 'INVALID',
            metadata_json =
                COALESCE(metadata_json, '{}'::jsonb)
                || jsonb_build_object(
                    'recovery_reason',
                    'PHYSICAL_OBJECT_MISSING',
                    'reconciled_at',
                    NOW()
                )
        WHERE artifact_id = p_artifact_id;

        RETURN QUERY
        SELECT
            FALSE,
            'PHYSICAL_OBJECT_MISSING'::VARCHAR(128),
            ('Artifact marque INVALID : objet physique absent : ' ||
             p_artifact_id)::TEXT,
            'INVALID'::VARCHAR(32);
        RETURN;
    END IF;

    /*
     * Reconciliation repetee.
     *
     * Aucun UPDATE inutile : operation idempotente.
     */
    IF v_status = 'INVALID' THEN

        RETURN QUERY
        SELECT
            FALSE,
            'PHYSICAL_OBJECT_MISSING'::VARCHAR(128),
            'Artifact deja INVALID ; reconciliation idempotente.'::TEXT,
            'INVALID'::VARCHAR(32);
        RETURN;
    END IF;

    IF v_status = 'DELETED' THEN

        RETURN QUERY
        SELECT
            FALSE,
            'ARTIFACT_DELETED'::VARCHAR(128),
            'Artifact deja DELETED.'::TEXT,
            'DELETED'::VARCHAR(32);
        RETURN;
    END IF;

    RETURN QUERY
    SELECT
        FALSE,
        'UNSUPPORTED_ARTIFACT_STATE'::VARCHAR(128),
        ('Etat artifact non gere : ' || v_status)::TEXT,
        v_status;

END;
$$;

COMMENT ON FUNCTION reconcile_artifact_presence(VARCHAR, BOOLEAN)
IS
'Reconciliation idempotente entre le registry PostgreSQL et la presence physique S3. Un artifact actif sans objet physique devient INVALID ; un INVALID retrouve physiquement peut redevenir VALIDATED.';