\echo '=== PREUVE REELLE SCENE_PLAN ==='
SELECT
    stage_id,
    run_id,
    stage_name,
    status,
    attempt,
    output_artifact_ids,
    output_json
FROM production_stage
WHERE stage_name = 'SCENE_PLAN';

\echo ''
\echo '=== ARTIFACT SCENE_PLAN ==='
SELECT
    artifact_id,
    run_id,
    stage,
    artifact_type,
    object_key,
    status,
    sha256,
    size_bytes
FROM artifact_registry
WHERE stage = 'SCENE_PLAN';

\echo ''
\echo '=== DEPENDANCE REELLE ENREGISTREE ==='
SELECT
    id,
    stage_id,
    depends_on_stage_id,
    dependency_type,
    created_at
FROM production_stage_dependency
WHERE stage_id IN (
    SELECT stage_id
    FROM production_stage
    WHERE stage_name = 'SCENE_PLAN'
);

\echo ''
\echo '=== STAGE DEFINITION SCENE_PLAN ==='
SELECT
    id,
    stage_name,
    version,
    executor_type,
    enabled,
    input_contract,
    output_contract,
    validation_contract
FROM stage_definition
WHERE stage_name = 'SCENE_PLAN'
ORDER BY version DESC;
