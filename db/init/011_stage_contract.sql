CREATE TABLE IF NOT EXISTS stage_definition (
    id BIGSERIAL PRIMARY KEY,
    stage_name VARCHAR(64) NOT NULL,
    version INTEGER NOT NULL,
    description TEXT NOT NULL,
    input_contract JSONB NOT NULL DEFAULT '{}'::jsonb,
    output_contract JSONB NOT NULL DEFAULT '{}'::jsonb,
    dependency_contract JSONB NOT NULL DEFAULT '{}'::jsonb,
    timeout_seconds INTEGER NOT NULL,
    max_attempts INTEGER NOT NULL,
    retry_policy JSONB NOT NULL DEFAULT '{}'::jsonb,
    idempotency_policy JSONB NOT NULL DEFAULT '{}'::jsonb,
    executor_type VARCHAR(64) NOT NULL,
    validation_contract JSONB NOT NULL DEFAULT '{}'::jsonb,
    recovery_policy JSONB NOT NULL DEFAULT '{}'::jsonb,
    enabled BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    CONSTRAINT stage_definition_stage_name_check
        CHECK (length(trim(stage_name)) > 0),

    CONSTRAINT stage_definition_version_check
        CHECK (version >= 1),

    CONSTRAINT stage_definition_description_check
        CHECK (length(trim(description)) > 0),

    CONSTRAINT stage_definition_timeout_check
        CHECK (timeout_seconds > 0),

    CONSTRAINT stage_definition_max_attempts_check
        CHECK (max_attempts >= 1),

    CONSTRAINT stage_definition_executor_check
        CHECK (length(trim(executor_type)) > 0),

    CONSTRAINT stage_definition_unique_version
        UNIQUE (stage_name, version)
);

CREATE INDEX IF NOT EXISTS idx_stage_definition_stage_name
    ON stage_definition(stage_name);

CREATE INDEX IF NOT EXISTS idx_stage_definition_enabled
    ON stage_definition(enabled);

CREATE OR REPLACE FUNCTION update_stage_definition_updated_at()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_stage_definition_updated_at
ON stage_definition;

CREATE TRIGGER trg_stage_definition_updated_at
BEFORE UPDATE ON stage_definition
FOR EACH ROW
EXECUTE FUNCTION update_stage_definition_updated_at();

CREATE OR REPLACE FUNCTION register_stage_definition(
    p_stage_name VARCHAR(64),
    p_version INTEGER,
    p_description TEXT,
    p_input_contract JSONB DEFAULT '{}'::jsonb,
    p_output_contract JSONB DEFAULT '{}'::jsonb,
    p_dependency_contract JSONB DEFAULT '{}'::jsonb,
    p_timeout_seconds INTEGER DEFAULT 300,
    p_max_attempts INTEGER DEFAULT 3,
    p_retry_policy JSONB DEFAULT '{}'::jsonb,
    p_idempotency_policy JSONB DEFAULT '{}'::jsonb,
    p_executor_type VARCHAR(64) DEFAULT 'N8N',
    p_validation_contract JSONB DEFAULT '{}'::jsonb,
    p_recovery_policy JSONB DEFAULT '{}'::jsonb,
    p_enabled BOOLEAN DEFAULT TRUE
)
RETURNS TABLE (
    allowed BOOLEAN,
    error_code VARCHAR(128),
    error_message TEXT,
    resulting_stage_name VARCHAR(64),
    resulting_version INTEGER
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_existing stage_definition%ROWTYPE;
BEGIN

    IF p_stage_name IS NULL
       OR length(trim(p_stage_name)) = 0 THEN

        RETURN QUERY
        SELECT
            FALSE,
            'INVALID_STAGE_NAME'::VARCHAR(128),
            'stage_name obligatoire.'::TEXT,
            NULL::VARCHAR(64),
            NULL::INTEGER;

        RETURN;
    END IF;

    IF p_version IS NULL OR p_version < 1 THEN

        RETURN QUERY
        SELECT
            FALSE,
            'INVALID_VERSION'::VARCHAR(128),
            'version doit etre >= 1.'::TEXT,
            NULL::VARCHAR(64),
            NULL::INTEGER;

        RETURN;
    END IF;

    IF p_description IS NULL
       OR length(trim(p_description)) = 0 THEN

        RETURN QUERY
        SELECT
            FALSE,
            'INVALID_DESCRIPTION'::VARCHAR(128),
            'description obligatoire.'::TEXT,
            NULL::VARCHAR(64),
            NULL::INTEGER;

        RETURN;
    END IF;

    IF p_timeout_seconds IS NULL
       OR p_timeout_seconds <= 0 THEN

        RETURN QUERY
        SELECT
            FALSE,
            'INVALID_TIMEOUT'::VARCHAR(128),
            'timeout_seconds doit etre > 0.'::TEXT,
            NULL::VARCHAR(64),
            NULL::INTEGER;

        RETURN;
    END IF;

    IF p_max_attempts IS NULL
       OR p_max_attempts < 1 THEN

        RETURN QUERY
        SELECT
            FALSE,
            'INVALID_MAX_ATTEMPTS'::VARCHAR(128),
            'max_attempts doit etre >= 1.'::TEXT,
            NULL::VARCHAR(64),
            NULL::INTEGER;

        RETURN;
    END IF;

    IF p_executor_type IS NULL
       OR length(trim(p_executor_type)) = 0 THEN

        RETURN QUERY
        SELECT
            FALSE,
            'INVALID_EXECUTOR_TYPE'::VARCHAR(128),
            'executor_type obligatoire.'::TEXT,
            NULL::VARCHAR(64),
            NULL::INTEGER;

        RETURN;
    END IF;

    SELECT *
    INTO v_existing
    FROM stage_definition
    WHERE stage_name = p_stage_name
      AND version = p_version;

    IF FOUND THEN

        IF
            v_existing.description = p_description
            AND v_existing.input_contract = p_input_contract
            AND v_existing.output_contract = p_output_contract
            AND v_existing.dependency_contract = p_dependency_contract
            AND v_existing.timeout_seconds = p_timeout_seconds
            AND v_existing.max_attempts = p_max_attempts
            AND v_existing.retry_policy = p_retry_policy
            AND v_existing.idempotency_policy = p_idempotency_policy
            AND v_existing.executor_type = p_executor_type
            AND v_existing.validation_contract = p_validation_contract
            AND v_existing.recovery_policy = p_recovery_policy
            AND v_existing.enabled = p_enabled
        THEN

            RETURN QUERY
            SELECT
                TRUE,
                NULL::VARCHAR(128),
                'Definition deja existante et identique. Operation idempotente.'::TEXT,
                p_stage_name,
                p_version;

            RETURN;
        END IF;

        RETURN QUERY
        SELECT
            FALSE,
            'VERSION_CONFLICT'::VARCHAR(128),
            ('La definition ' || p_stage_name ||
             ' version ' || p_version ||
             ' existe deja avec un contenu different.')::TEXT,
            p_stage_name,
            p_version;

        RETURN;
    END IF;

    INSERT INTO stage_definition (
        stage_name,
        version,
        description,
        input_contract,
        output_contract,
        dependency_contract,
        timeout_seconds,
        max_attempts,
        retry_policy,
        idempotency_policy,
        executor_type,
        validation_contract,
        recovery_policy,
        enabled
    )
    VALUES (
        p_stage_name,
        p_version,
        p_description,
        COALESCE(p_input_contract, '{}'::jsonb),
        COALESCE(p_output_contract, '{}'::jsonb),
        COALESCE(p_dependency_contract, '{}'::jsonb),
        p_timeout_seconds,
        p_max_attempts,
        COALESCE(p_retry_policy, '{}'::jsonb),
        COALESCE(p_idempotency_policy, '{}'::jsonb),
        p_executor_type,
        COALESCE(p_validation_contract, '{}'::jsonb),
        COALESCE(p_recovery_policy, '{}'::jsonb),
        p_enabled
    );

    RETURN QUERY
    SELECT
        TRUE,
        NULL::VARCHAR(128),
        'Definition de stage creee.'::TEXT,
        p_stage_name,
        p_version;

END;
$$;

COMMENT ON TABLE stage_definition IS
'Contrat declaratif versionne de chaque stage Prometheus V2.';

COMMENT ON COLUMN stage_definition.input_contract IS
'Contrat JSON des entrees attendues par le stage.';

COMMENT ON COLUMN stage_definition.output_contract IS
'Contrat JSON des sorties produites par le stage.';

COMMENT ON COLUMN stage_definition.dependency_contract IS
'Contrat declaratif des dependances du stage.';

COMMENT ON COLUMN stage_definition.retry_policy IS
'Politique de retry declarative du stage.';

COMMENT ON COLUMN stage_definition.idempotency_policy IS
'Politique d idempotence du stage.';

COMMENT ON COLUMN stage_definition.validation_contract IS
'Regles declaratives de validation de sortie.';

COMMENT ON COLUMN stage_definition.recovery_policy IS
'Politique declarative de recovery du stage.';