\pset pager off
\pset format aligned
\pset border 1

\echo '============================================================'
\echo '11-E.10 — ENGINE PRIMITIVES READ-ONLY'
\echo '============================================================'

\echo '============================================================'
\echo '1. VALIDATE EXISTING V3 SCENE_PLAN ARTIFACTS'
\echo '============================================================'

SELECT *
FROM validate_stage_artifacts(
    'STAGE-SCENE-PLAN-V3'
);

\echo '============================================================'
\echo '2. VALIDATE EXISTING V3 SCRIPT ARTIFACTS'
\echo '============================================================'

SELECT *
FROM validate_stage_artifacts(
    'STAGE-SCRIPT-GROQ-V3'
);

\echo '============================================================'
\echo '3. RECONCILE EXISTING V3 SCENE_PLAN AS PHYSICALLY PRESENT'
\echo '============================================================'

SELECT *
FROM reconcile_artifact_presence(
    'ART-SCENE-PLAN-V3',
    TRUE
);

\echo '============================================================'
\echo '4. RECONCILE EXISTING V3 SCRIPT AS PHYSICALLY PRESENT'
\echo '============================================================'

SELECT *
FROM reconcile_artifact_presence(
    'ART-SCRIPT-GROQ-V3',
    TRUE
);

\echo '============================================================'
\echo '5. CLAIM ALREADY-SUCCEEDED SCENE_PLAN'
\echo '============================================================'

SELECT *
FROM claim_stage_for_execution(
    'STAGE-SCENE-PLAN-V3'
);

\echo '============================================================'
\echo '6. CLAIM ALREADY-SUCCEEDED SCRIPT'
\echo '============================================================'

SELECT *
FROM claim_stage_for_execution(
    'STAGE-SCRIPT-GROQ-V3'
);

\echo '============================================================'
\echo '7. COMPLETE ALREADY-SUCCEEDED SCENE_PLAN'
\echo '============================================================'

SELECT *
FROM complete_stage_atomically(
    'STAGE-SCENE-PLAN-V3',
    '{"readonly_test":true}'::jsonb
);

\echo '============================================================'
\echo '8. COMPLETE ALREADY-SUCCEEDED SCRIPT'
\echo '============================================================'

SELECT *
FROM complete_stage_atomically(
    'STAGE-SCRIPT-GROQ-V3',
    '{"readonly_test":true}'::jsonb
);

\echo '============================================================'
\echo '9. EXISTING EXECUTION EVENT — BASELINE'
\echo '============================================================'

SELECT
    id,
    event_id,
    run_id,
    stage_id,
    stage_name,
    attempt,
    event_type,
    provider,
    executor_type,
    status,
    started_at,
    completed_at,
    duration_ms,
    input_artifact_ids,
    output_artifact_ids,
    event_data
FROM production_execution_event
WHERE event_id = 'EVT-EXEC-RUN-SCRIPT-GROQ-V2';

\echo '============================================================'
\echo '10. EXECUTION EVENT IDEMPOTENCE TEST'
\echo '============================================================'

SELECT *
FROM record_execution_event(
    'EVT-EXEC-RUN-SCRIPT-GROQ-V2',
    'RUN-SCRIPT-GROQ-V2',
    'STAGE-SCRIPT-GROQ-V2',
    'SCRIPT_GROQ',
    1,
    'STAGE_EXECUTION',
    'GROQ',
    'ORCHESTRATOR_SCRIPT',
    'SUCCEEDED',
    '2026-09-16T01:01:07.702695+00:00'::timestamptz,
    '2026-09-16T01:01:11.933694+00:00'::timestamptz,
    4209,
    NULL,
    NULL,
    '[]'::jsonb,
    '["ART-SCRIPT-GROQ-V2"]'::jsonb,
    '{"model":"openai/gpt-oss-120b","scenes":8}'::jsonb
);

\echo '============================================================'
\echo '11. EXECUTION EVENT COUNT AFTER IDEMPOTENCE TEST'
\echo '============================================================'

SELECT
    COUNT(*) AS execution_event_count
FROM production_execution_event
WHERE event_id = 'EVT-EXEC-RUN-SCRIPT-GROQ-V2';

\echo '============================================================'
\echo '12. FINAL STAGE STATUS'
\echo '============================================================'

SELECT
    stage_id,
    run_id,
    stage_name,
    stage_order,
    status,
    attempt,
    idempotency_key,
    input_artifact_ids,
    output_artifact_ids,
    started_at,
    completed_at,
    error_code,
    error_message,
    retryable
FROM production_stage
WHERE stage_id IN (
    'STAGE-SCRIPT-GROQ-V2',
    'STAGE-SCRIPT-GROQ-V3',
    'STAGE-SCENE-PLAN-V3'
)
ORDER BY stage_order, stage_id;

\echo '============================================================'
\echo '13. FINAL ARTIFACT STATUS'
\echo '============================================================'

SELECT
    artifact_id,
    run_id,
    stage,
    artifact_type,
    object_key,
    size_bytes,
    sha256,
    version,
    status
FROM artifact_registry
WHERE artifact_id IN (
    'ART-SCRIPT-GROQ-V2',
    'ART-SCRIPT-GROQ-V3',
    'ART-SCENE-PLAN-V3'
)
ORDER BY artifact_id;

\echo '============================================================'
\echo '11-E.10 READ-ONLY TEST END'
\echo '============================================================'
