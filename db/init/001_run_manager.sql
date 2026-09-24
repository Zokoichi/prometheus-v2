CREATE TABLE IF NOT EXISTS production_run (
    id BIGSERIAL PRIMARY KEY,

    run_id VARCHAR(64) NOT NULL UNIQUE,
    project_id VARCHAR(128) NOT NULL,

    status VARCHAR(32) NOT NULL DEFAULT 'CREATED',
    current_stage VARCHAR(64) NOT NULL DEFAULT 'RUN_MANAGER',

    attempt INTEGER NOT NULL DEFAULT 1,

    input_json JSONB NOT NULL DEFAULT '{}'::jsonb,
    output_json JSONB NOT NULL DEFAULT '{}'::jsonb,

    error_code VARCHAR(128),
    error_message TEXT,

    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    CONSTRAINT production_run_status_check
        CHECK (
            status IN (
                'CREATED',
                'VALIDATED',
                'ASSET_READY',
                'AUDIO_READY',
                'COMPOSED',
                'RENDERED',
                'QC_PASSED',
                'READY_TO_PUBLISH',
                'PUBLISHED',
                'ERROR',
                'CANCELLED'
            )
        ),

    CONSTRAINT production_run_attempt_check
        CHECK (attempt >= 1)
);

CREATE INDEX IF NOT EXISTS idx_production_run_project_id
    ON production_run(project_id);

CREATE INDEX IF NOT EXISTS idx_production_run_status
    ON production_run(status);

CREATE INDEX IF NOT EXISTS idx_production_run_current_stage
    ON production_run(current_stage);

CREATE INDEX IF NOT EXISTS idx_production_run_created_at
    ON production_run(created_at DESC);


CREATE TABLE IF NOT EXISTS production_run_event (
    id BIGSERIAL PRIMARY KEY,

    run_id VARCHAR(64) NOT NULL,

    event_type VARCHAR(64) NOT NULL,
    from_status VARCHAR(32),
    to_status VARCHAR(32),

    stage VARCHAR(64) NOT NULL,
    attempt INTEGER NOT NULL,

    event_data JSONB NOT NULL DEFAULT '{}'::jsonb,

    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    CONSTRAINT production_run_event_run_fk
        FOREIGN KEY (run_id)
        REFERENCES production_run(run_id)
        ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS idx_production_run_event_run_id
    ON production_run_event(run_id);

CREATE INDEX IF NOT EXISTS idx_production_run_event_created_at
    ON production_run_event(created_at DESC);


CREATE OR REPLACE FUNCTION update_production_run_updated_at()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$;


DROP TRIGGER IF EXISTS trg_production_run_updated_at
ON production_run;

CREATE TRIGGER trg_production_run_updated_at
BEFORE UPDATE ON production_run
FOR EACH ROW
EXECUTE FUNCTION update_production_run_updated_at();
