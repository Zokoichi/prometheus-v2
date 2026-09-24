\echo '=== EVENTS SCENE_PLAN V3 ==='
SELECT
    id,
    stage_id,
    run_id,
    event_type,
    from_status,
    to_status,
    stage_name,
    attempt,
    event_data,
    created_at
FROM production_stage_event
WHERE stage_id = 'STAGE-SCENE-PLAN-V3'
ORDER BY id;

\echo ''
\echo '=== EVENTS SCRIPT V3 ==='
SELECT
    id,
    stage_id,
    run_id,
    event_type,
    from_status,
    to_status,
    stage_name,
    attempt,
    event_data,
    created_at
FROM production_stage_event
WHERE stage_id = 'STAGE-SCRIPT-GROQ-V3'
ORDER BY id;
