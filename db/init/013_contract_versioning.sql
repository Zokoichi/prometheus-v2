CREATE TABLE IF NOT EXISTS contract_definition (
    id BIGSERIAL PRIMARY KEY,

    contract_name VARCHAR(128) NOT NULL,
    version INTEGER NOT NULL,

    description TEXT NOT NULL,
    schema_json JSONB NOT NULL,

    producer VARCHAR(128) NOT NULL,
    consumers JSONB NOT NULL DEFAULT '[]'::jsonb,

    enabled BOOLEAN NOT NULL DEFAULT TRUE,

    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    CONSTRAINT contract_definition_version_check
        CHECK (version >= 1),

    CONSTRAINT contract_definition_description_check
        CHECK (length(trim(description)) > 0),

    CONSTRAINT contract_definition_schema_object_check
        CHECK (jsonb_typeof(schema_json) = 'object'),

    CONSTRAINT contract_definition_producer_check
        CHECK (length(trim(producer)) > 0),

    CONSTRAINT contract_definition_consumers_array_check
        CHECK (jsonb_typeof(consumers) = 'array'),

    CONSTRAINT contract_definition_unique_version
        UNIQUE (contract_name, version)
);

CREATE OR REPLACE FUNCTION update_contract_definition_updated_at()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_contract_definition_updated_at
ON contract_definition;

CREATE TRIGGER trg_contract_definition_updated_at
BEFORE UPDATE ON contract_definition
FOR EACH ROW
EXECUTE FUNCTION update_contract_definition_updated_at();

CREATE OR REPLACE FUNCTION register_contract_definition(
    p_contract_name VARCHAR(128),
    p_version INTEGER,
    p_description TEXT,
    p_schema_json JSONB,
    p_producer VARCHAR(128),
    p_consumers JSONB DEFAULT '[]'::jsonb,
    p_enabled BOOLEAN DEFAULT TRUE
)
RETURNS TABLE (
    allowed BOOLEAN,
    error_code VARCHAR(128),
    error_message TEXT,
    resulting_contract_name VARCHAR(128),
    resulting_version INTEGER
)
LANGUAGE plpgsql
AS $$
DECLARE
    existing_record contract_definition%ROWTYPE;
BEGIN

    IF p_contract_name IS NULL
       OR length(trim(p_contract_name)) = 0 THEN

        RETURN QUERY
        SELECT
            FALSE,
            'VALIDATION_ERROR'::VARCHAR(128),
            'contract_name is required'::TEXT,
            NULL::VARCHAR(128),
            NULL::INTEGER;

        RETURN;
    END IF;

    IF p_version IS NULL OR p_version < 1 THEN

        RETURN QUERY
        SELECT
            FALSE,
            'VALIDATION_ERROR'::VARCHAR(128),
            'version must be >= 1'::TEXT,
            NULL::VARCHAR(128),
            NULL::INTEGER;

        RETURN;
    END IF;

    IF p_description IS NULL
       OR length(trim(p_description)) = 0 THEN

        RETURN QUERY
        SELECT
            FALSE,
            'VALIDATION_ERROR'::VARCHAR(128),
            'description is required'::TEXT,
            NULL::VARCHAR(128),
            NULL::INTEGER;

        RETURN;
    END IF;

    IF p_schema_json IS NULL
       OR jsonb_typeof(p_schema_json) <> 'object' THEN

        RETURN QUERY
        SELECT
            FALSE,
            'VALIDATION_ERROR'::VARCHAR(128),
            'schema_json must be a JSON object'::TEXT,
            NULL::VARCHAR(128),
            NULL::INTEGER;

        RETURN;
    END IF;

    IF p_producer IS NULL
       OR length(trim(p_producer)) = 0 THEN

        RETURN QUERY
        SELECT
            FALSE,
            'VALIDATION_ERROR'::VARCHAR(128),
            'producer is required'::TEXT,
            NULL::VARCHAR(128),
            NULL::INTEGER;

        RETURN;
    END IF;

    IF p_consumers IS NULL
       OR jsonb_typeof(p_consumers) <> 'array' THEN

        RETURN QUERY
        SELECT
            FALSE,
            'VALIDATION_ERROR'::VARCHAR(128),
            'consumers must be a JSON array'::TEXT,
            NULL::VARCHAR(128),
            NULL::INTEGER;

        RETURN;
    END IF;

    SELECT *
    INTO existing_record
    FROM contract_definition
    WHERE contract_name = p_contract_name
      AND version = p_version
    FOR UPDATE;

    IF FOUND THEN

        IF existing_record.description = p_description
           AND existing_record.schema_json = p_schema_json
           AND existing_record.producer = p_producer
           AND existing_record.consumers = p_consumers
           AND existing_record.enabled = p_enabled THEN

            RETURN QUERY
            SELECT
                TRUE,
                NULL::VARCHAR(128),
                NULL::TEXT,
                existing_record.contract_name,
                existing_record.version;

            RETURN;

        ELSE

            RETURN QUERY
            SELECT
                FALSE,
                'VERSION_CONFLICT'::VARCHAR(128),
                'Same contract_name and version already exists with different definition'::TEXT,
                existing_record.contract_name,
                existing_record.version;

            RETURN;

        END IF;
    END IF;

    INSERT INTO contract_definition (
        contract_name,
        version,
        description,
        schema_json,
        producer,
        consumers,
        enabled
    )
    VALUES (
        p_contract_name,
        p_version,
        p_description,
        p_schema_json,
        p_producer,
        p_consumers,
        p_enabled
    );

    RETURN QUERY
    SELECT
        TRUE,
        NULL::VARCHAR(128),
        NULL::TEXT,
        p_contract_name,
        p_version;

END;
$$;