CREATE TABLE IF NOT EXISTS production_stage_dependency (
    id BIGSERIAL PRIMARY KEY,

    stage_id VARCHAR(128) NOT NULL,

    depends_on_stage_id VARCHAR(128) NOT NULL,

    dependency_type VARCHAR(32) NOT NULL DEFAULT 'SUCCESS',

    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    CONSTRAINT production_stage_dependency_stage_fk
        FOREIGN KEY (stage_id)
        REFERENCES production_stage(stage_id)
        ON DELETE CASCADE,

    CONSTRAINT production_stage_dependency_depends_on_fk
        FOREIGN KEY (depends_on_stage_id)
        REFERENCES production_stage(stage_id)
        ON DELETE CASCADE,

    CONSTRAINT production_stage_dependency_self_check
        CHECK (stage_id <> depends_on_stage_id),

    CONSTRAINT production_stage_dependency_type_check
        CHECK (
            dependency_type IN (
                'SUCCESS'
            )
        ),

    CONSTRAINT production_stage_dependency_unique
        UNIQUE (
            stage_id,
            depends_on_stage_id
        )
);

CREATE INDEX IF NOT EXISTS idx_stage_dependency_stage_id
    ON production_stage_dependency(stage_id);

CREATE INDEX IF NOT EXISTS idx_stage_dependency_depends_on_stage_id
    ON production_stage_dependency(depends_on_stage_id);

CREATE INDEX IF NOT EXISTS idx_stage_dependency_type
    ON production_stage_dependency(dependency_type);


COMMENT ON TABLE production_stage_dependency IS
'Explicit dependency graph between Prometheus V2 production stages.';

COMMENT ON COLUMN production_stage_dependency.stage_id IS
'Stage that cannot execute until its dependency condition is satisfied.';

COMMENT ON COLUMN production_stage_dependency.depends_on_stage_id IS
'Upstream stage required by stage_id.';

COMMENT ON COLUMN production_stage_dependency.dependency_type IS
'Required dependency condition. SUCCESS means upstream stage must be SUCCEEDED.';