CREATE TABLE IF NOT EXISTS artifact_registry (
    id BIGSERIAL PRIMARY KEY,

    artifact_id VARCHAR(128) NOT NULL UNIQUE,

    run_id VARCHAR(64) NOT NULL,

    stage VARCHAR(64) NOT NULL,

    artifact_type VARCHAR(64) NOT NULL,

    object_key VARCHAR(1024) NOT NULL UNIQUE,

    content_type VARCHAR(255),

    size_bytes BIGINT NOT NULL DEFAULT 0,

    sha256 CHAR(64),

    version INTEGER NOT NULL DEFAULT 1,

    status VARCHAR(32) NOT NULL DEFAULT 'REGISTERED',

    metadata_json JSONB NOT NULL DEFAULT '{}'::jsonb,

    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    CONSTRAINT artifact_registry_run_fk
        FOREIGN KEY (run_id)
        REFERENCES production_run(run_id)
        ON DELETE CASCADE,

    CONSTRAINT artifact_registry_size_check
        CHECK (size_bytes >= 0),

    CONSTRAINT artifact_registry_version_check
        CHECK (version >= 1),

    CONSTRAINT artifact_registry_sha256_check
        CHECK (
            sha256 IS NULL
            OR sha256 ~ '^[0-9A-Fa-f]{64}$'
        ),

    CONSTRAINT artifact_registry_status_check
        CHECK (
            status IN (
                'REGISTERED',
                'UPLOADING',
                'STORED',
                'VALIDATING',
                'VALIDATED',
                'INVALID',
                'ERROR',
                'DELETED'
            )
        )
);

CREATE INDEX IF NOT EXISTS idx_artifact_registry_run_id
    ON artifact_registry(run_id);

CREATE INDEX IF NOT EXISTS idx_artifact_registry_stage
    ON artifact_registry(stage);

CREATE INDEX IF NOT EXISTS idx_artifact_registry_status
    ON artifact_registry(status);

CREATE INDEX IF NOT EXISTS idx_artifact_registry_artifact_type
    ON artifact_registry(artifact_type);

CREATE INDEX IF NOT EXISTS idx_artifact_registry_created_at
    ON artifact_registry(created_at DESC);


CREATE OR REPLACE FUNCTION update_artifact_registry_updated_at()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$;


DROP TRIGGER IF EXISTS trg_artifact_registry_updated_at
ON artifact_registry;

CREATE TRIGGER trg_artifact_registry_updated_at
BEFORE UPDATE ON artifact_registry
FOR EACH ROW
EXECUTE FUNCTION update_artifact_registry_updated_at();


COMMENT ON TABLE artifact_registry IS
'Registry central des artefacts Prometheus V2 stockés dans SeaweedFS/S3.';

COMMENT ON COLUMN artifact_registry.artifact_id IS
'Identifiant logique unique de l artefact.';

COMMENT ON COLUMN artifact_registry.object_key IS
'Clé exacte de stockage S3.';

COMMENT ON COLUMN artifact_registry.sha256 IS
'Empreinte SHA-256 du contenu réellement stocké.';

COMMENT ON COLUMN artifact_registry.version IS
'Version logique de l artefact.';

COMMENT ON COLUMN artifact_registry.status IS
'Etat de validation de l artefact.';
