\pset pager off
\pset format wrapped
\pset border 1

\echo '============================================================'
\echo '11-E.22 — FINAL FAILURE CONTRACT FORENSICS'
\echo '============================================================'

\echo '============================================================'
\echo '1. PRODUCTION_STAGE — CONSTRAINTS'
\echo '============================================================'

SELECT
    conname,
    contype,
    pg_get_constraintdef(oid) AS definition
FROM pg_constraint
WHERE conrelid = 'public.production_stage'::regclass
ORDER BY conname;

\echo '============================================================'
\echo '2. PRODUCTION_STAGE_EVENT — CONSTRAINTS'
\echo '============================================================'

SELECT
    conname,
    contype,
    pg_get_constraintdef(oid) AS definition
FROM pg_constraint
WHERE conrelid = 'public.production_stage_event'::regclass
ORDER BY conname;

\echo '============================================================'
\echo '3. PRODUCTION_STAGE — TRIGGERS'
\echo '============================================================'

SELECT
    tgname,
    pg_get_triggerdef(oid) AS definition
FROM pg_trigger
WHERE tgrelid = 'public.production_stage'::regclass
  AND NOT tgisinternal
ORDER BY tgname;

\echo '============================================================'
\echo '4. PRODUCTION_STAGE_EVENT — TRIGGERS'
\echo '============================================================'

SELECT
    tgname,
    pg_get_triggerdef(oid) AS definition
FROM pg_trigger
WHERE tgrelid = 'public.production_stage_event'::regclass
  AND NOT tgisinternal
ORDER BY tgname;

\echo '============================================================'
\echo '5. ALL STAGE EVENT TYPES'
\echo '============================================================'

SELECT
    event_type,
    from_status,
    to_status,
    COUNT(*) AS event_count
FROM production_stage_event
GROUP BY
    event_type,
    from_status,
    to_status
ORDER BY
    event_type,
    from_status,
    to_status;

\echo '============================================================'
\echo '6. HISTORICAL STAGE ERROR EVENTS'
\echo '============================================================'

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
WHERE event_type IN ('STAGE_ERROR', 'RETRY')
   OR from_status = 'ERROR'
   OR to_status = 'ERROR'
ORDER BY created_at, id;

\echo '============================================================'
\echo '7. HISTORICAL RUN ERROR / RETRY EVENTS'
\echo '============================================================'

SELECT
    id,
    run_id,
    event_type,
    from_status,
    to_status,
    stage,
    attempt,
    event_data,
    created_at
FROM production_run_event
WHERE event_type IN ('STAGE_ERROR', 'RETRY')
   OR from_status = 'ERROR'
   OR to_status = 'ERROR'
ORDER BY created_at, id;

\echo '============================================================'
\echo '8. STAGE ERROR EVENTS WITHOUT MATCHING ERROR STAGE'
\echo '============================================================'

SELECT
    e.id,
    e.stage_id,
    e.run_id,
    e.event_type,
    e.from_status,
    e.to_status,
    e.attempt,
    s.status AS current_stage_status,
    s.attempt AS current_stage_attempt
FROM production_stage_event e
LEFT JOIN production_stage s
    ON s.stage_id = e.stage_id
WHERE e.event_type = 'STAGE_ERROR'
ORDER BY e.created_at, e.id;

\echo '============================================================'
\echo '9. RETRY EVENTS AND CURRENT STAGE STATE'
\echo '============================================================'

SELECT
    e.id,
    e.stage_id,
    e.run_id,
    e.attempt AS event_attempt,
    e.event_type,
    e.from_status,
    e.to_status,
    s.status AS current_stage_status,
    s.attempt AS current_stage_attempt,
    s.retryable AS current_retryable,
    s.error_code AS current_error_code
FROM production_stage_event e
LEFT JOIN production_stage s
    ON s.stage_id = e.stage_id
WHERE e.event_type = 'RETRY'
ORDER BY e.created_at, e.id;

\echo '============================================================'
\echo '10. CURRENT RUN/STAGE ERROR RELATIONSHIP'
\echo '============================================================'

SELECT
    pr.run_id,
    pr.status AS run_status,
    COUNT(ps.stage_id) AS stage_count,
    COUNT(*) FILTER (WHERE ps.status = 'ERROR') AS error_stage_count,
    COUNT(*) FILTER (WHERE ps.status = 'RUNNING') AS running_stage_count,
    COUNT(*) FILTER (WHERE ps.status = 'PENDING') AS pending_stage_count,
    COUNT(*) FILTER (WHERE ps.status = 'SUCCEEDED') AS succeeded_stage_count
FROM production_run pr
LEFT JOIN production_stage ps
    ON ps.run_id = pr.run_id
GROUP BY
    pr.run_id,
    pr.status
ORDER BY pr.run_id;

\echo '============================================================'
\echo '11. REQUEST_RUN_TRANSITION — FULL SOURCE'
\echo '============================================================'

SELECT pg_get_functiondef(p.oid)
FROM pg_proc p
JOIN pg_namespace n
  ON n.oid = p.pronamespace
WHERE n.nspname = 'public'
  AND p.proname = 'request_run_transition';

\echo '============================================================'
\echo '12. CLAIM_STAGE_FOR_EXECUTION — FULL SOURCE'
\echo '============================================================'

SELECT pg_get_functiondef(p.oid)
FROM pg_proc p
JOIN pg_namespace n
  ON n.oid = p.pronamespace
WHERE n.nspname = 'public'
  AND p.proname = 'claim_stage_for_execution';

\echo '============================================================'
\echo '13. COMPLETE_STAGE_ATOMICALLY — FULL SOURCE'
\echo '============================================================'

SELECT pg_get_functiondef(p.oid)
FROM pg_proc p
JOIN pg_namespace n
  ON n.oid = p.pronamespace
WHERE n.nspname = 'public'
  AND p.proname = 'complete_stage_atomically';

\echo '============================================================'
\echo '14. CLASSIFY_ERROR — FULL SOURCE'
\echo '============================================================'

SELECT pg_get_functiondef(p.oid)
FROM pg_proc p
JOIN pg_namespace n
  ON n.oid = p.pronamespace
WHERE n.nspname = 'public'
  AND p.proname = 'classify_error';

\echo '============================================================'
\echo '15. FAILURE-RELATED ROUTINE CALL GRAPH'
\echo '============================================================'

SELECT
    p.proname,
    pg_get_function_identity_arguments(p.oid) AS arguments,
    CASE
        WHEN pg_get_functiondef(p.oid) ILIKE '%classify_error(%'
            THEN 'CALLS classify_error'
        ELSE ''
    END AS classify_reference,
    CASE
        WHEN pg_get_functiondef(p.oid) ILIKE '%production_stage_event%'
            THEN 'REFERENCES production_stage_event'
        ELSE ''
    END AS event_reference,
    CASE
        WHEN pg_get_functiondef(p.oid) ILIKE '%status = ''ERROR''%'
          OR pg_get_functiondef(p.oid) ILIKE '%status := ''ERROR''%'
          OR pg_get_functiondef(p.oid) ILIKE '%''ERROR''%'
            THEN 'REFERENCES ERROR'
        ELSE ''
    END AS error_reference
FROM pg_proc p
JOIN pg_namespace n
  ON n.oid = p.pronamespace
WHERE n.nspname = 'public'
ORDER BY p.proname;

\echo '============================================================'
\echo '16. FINAL FAILURE CONTRACT CHECK'
\echo '============================================================'

SELECT
    COUNT(*) FILTER (
        WHERE status = 'ERROR'
    ) AS current_error_stages,
    COUNT(*) FILTER (
        WHERE status = 'ERROR'
          AND retryable = TRUE
    ) AS current_retryable_error_stages,
    COUNT(*) FILTER (
        WHERE status = 'ERROR'
          AND retryable = FALSE
    ) AS current_terminal_error_stages
FROM production_stage;

\echo '============================================================'
\echo '11-E.22 END'
\echo '============================================================'
