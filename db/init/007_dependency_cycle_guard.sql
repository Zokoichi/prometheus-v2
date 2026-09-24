CREATE OR REPLACE FUNCTION create_stage_dependency(
    p_stage_id VARCHAR(128),
    p_depends_on_stage_id VARCHAR(128),
    p_dependency_type VARCHAR(32) DEFAULT 'SUCCESS'
)
RETURNS TABLE (
    allowed BOOLEAN,
    error_code VARCHAR(128),
    error_message TEXT
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_exists BOOLEAN;
    v_cycle BOOLEAN;
BEGIN
    /*
       Verrou transactionnel unique pour sérialiser les modifications
       du graphe de dépendances.

       Le lock est libéré automatiquement à la fin de la transaction.
    */
    PERFORM pg_advisory_xact_lock(
        hashtext('PROMETHEUS_V2_DEPENDENCY_GRAPH')
    );

    IF p_stage_id IS NULL OR p_depends_on_stage_id IS NULL THEN
        RETURN QUERY
        SELECT
            FALSE,
            'INVALID_STAGE_ID'::VARCHAR(128),
            'Les identifiants de stage sont obligatoires.'::TEXT;
        RETURN;
    END IF;

    IF p_stage_id = p_depends_on_stage_id THEN
        RETURN QUERY
        SELECT
            FALSE,
            'DEPENDENCY_SELF_CYCLE'::VARCHAR(128),
            'Une stage ne peut pas dependre de lui-meme.'::TEXT;
        RETURN;
    END IF;

    IF p_dependency_type <> 'SUCCESS' THEN
        RETURN QUERY
        SELECT
            FALSE,
            'INVALID_DEPENDENCY_TYPE'::VARCHAR(128),
            'Seul le type SUCCESS est actuellement autorise.'::TEXT;
        RETURN;
    END IF;

    SELECT EXISTS (
        SELECT 1
        FROM production_stage
        WHERE stage_id = p_stage_id
    )
    INTO v_exists;

    IF NOT v_exists THEN
        RETURN QUERY
        SELECT
            FALSE,
            'STAGE_NOT_FOUND'::VARCHAR(128),
            ('Stage inexistant : ' || p_stage_id)::TEXT;
        RETURN;
    END IF;

    SELECT EXISTS (
        SELECT 1
        FROM production_stage
        WHERE stage_id = p_depends_on_stage_id
    )
    INTO v_exists;

    IF NOT v_exists THEN
        RETURN QUERY
        SELECT
            FALSE,
            'DEPENDENCY_STAGE_NOT_FOUND'::VARCHAR(128),
            ('Stage de dependance inexistant : ' ||
             p_depends_on_stage_id)::TEXT;
        RETURN;
    END IF;

    IF EXISTS (
        SELECT 1
        FROM production_stage_dependency
        WHERE stage_id = p_stage_id
          AND depends_on_stage_id = p_depends_on_stage_id
    ) THEN
        RETURN QUERY
        SELECT
            TRUE,
            NULL::VARCHAR(128),
            'Dependance deja existante.'::TEXT;
        RETURN;
    END IF;

    /*
       Pour ajouter :
           A -> B

       il faut vérifier qu'il n'existe PAS déjà un chemin :
           B -> ... -> A

       Sinon l'ajout fermerait un cycle.
    */

    WITH RECURSIVE dependency_path AS (
        SELECT
            d.stage_id,
            d.depends_on_stage_id
        FROM production_stage_dependency d
        WHERE d.stage_id = p_depends_on_stage_id

        UNION

        SELECT
            dp.stage_id,
            d.depends_on_stage_id
        FROM dependency_path dp
        JOIN production_stage_dependency d
          ON d.stage_id = dp.depends_on_stage_id
    )
    SELECT EXISTS (
        SELECT 1
        FROM dependency_path
        WHERE depends_on_stage_id = p_stage_id
    )
    INTO v_cycle;

    IF v_cycle THEN
        RETURN QUERY
        SELECT
            FALSE,
            'DEPENDENCY_CYCLE'::VARCHAR(128),
            ('Ajout refuse : la dependance ' ||
             p_stage_id || ' -> ' ||
             p_depends_on_stage_id ||
             ' creerait un cycle.')::TEXT;
        RETURN;
    END IF;

    INSERT INTO production_stage_dependency (
        stage_id,
        depends_on_stage_id,
        dependency_type
    )
    VALUES (
        p_stage_id,
        p_depends_on_stage_id,
        p_dependency_type
    );

    RETURN QUERY
    SELECT
        TRUE,
        NULL::VARCHAR(128),
        ('Dependance creee : ' ||
         p_stage_id || ' -> ' ||
         p_depends_on_stage_id)::TEXT;
END;
$$;

COMMENT ON FUNCTION create_stage_dependency(VARCHAR, VARCHAR, VARCHAR)
IS
'Ajout protege de dependances Prometheus V2. Refuse les auto-cycles et les cycles directs ou indirects. Serialise les modifications du graphe par advisory transaction lock.';